<?php

require_once __DIR__ . '/../config/google_oauth.php';

final class GoogleTokenValidationException extends RuntimeException
{
}

final class GoogleOAuthConfigurationException extends RuntimeException
{
}

final class GoogleIdTokenVerifier
{
    private $clientIds;
    private $certificateProvider;
    private $clock;
    private $signatureVerifier;

    public function __construct(
        ?array $clientIds = null,
        ?Closure $certificateProvider = null,
        ?Closure $clock = null,
        ?Closure $signatureVerifier = null
    ) {
        $this->clientIds = array_values(array_unique(array_filter(array_map(
            static function ($value): string {
                return trim((string)$value);
            },
            $clientIds ?? GOOGLE_WEB_CLIENT_IDS
        ))));
        $this->certificateProvider = $certificateProvider
            ?? function (bool $forceRefresh): array {
                return $this->loadCertificates($forceRefresh);
            };
        $this->clock = $clock ?? static function (): int {
            return time();
        };
        $this->signatureVerifier = $signatureVerifier
            ?? static function (string $data, string $signature, string $certificate): bool {
                if (!function_exists('openssl_verify')) {
                    throw new GoogleOAuthConfigurationException(
                        'The OpenSSL PHP extension is required.'
                    );
                }
                return openssl_verify(
                    $data,
                    $signature,
                    $certificate,
                    OPENSSL_ALGO_SHA256
                ) === 1;
            };
    }

    public function verify(string $idToken): array
    {
        if ($this->clientIds === []) {
            throw new GoogleOAuthConfigurationException('Google OAuth client ID is not configured.');
        }
        if ($idToken === '' || strlen($idToken) > 16384) {
            throw new GoogleTokenValidationException('Invalid Google ID token.');
        }

        $parts = explode('.', $idToken);
        if (count($parts) !== 3) {
            throw new GoogleTokenValidationException('Invalid Google ID token.');
        }

        $header = $this->decodeJsonPart($parts[0]);
        $claims = $this->decodeJsonPart($parts[1]);
        $signature = $this->decodeBase64Url($parts[2]);
        $kid = trim((string)($header['kid'] ?? ''));
        if (($header['alg'] ?? null) !== 'RS256' || $kid === '' || $signature === '') {
            throw new GoogleTokenValidationException('Invalid Google ID token.');
        }

        $certificates = ($this->certificateProvider)(false);
        if (!isset($certificates[$kid])) {
            $certificates = ($this->certificateProvider)(true);
        }
        $certificate = $certificates[$kid] ?? null;
        if (!is_string($certificate) || $certificate === '') {
            throw new GoogleTokenValidationException('Google signing key is unavailable.');
        }
        $verified = ($this->signatureVerifier)(
            $parts[0] . '.' . $parts[1],
            $signature,
            $certificate
        );
        if (!$verified) {
            throw new GoogleTokenValidationException('Invalid Google ID token signature.');
        }

        $this->validateClaims($claims);
        $email = strtolower(trim((string)$claims['email']));
        $hostedDomain = strtolower(trim((string)($claims['hd'] ?? '')));
        $picture = trim((string)($claims['picture'] ?? ''));
        if (!$this->isSafePictureUrl($picture)) {
            $picture = '';
        }
        $name = trim((string)($claims['name'] ?? ''));
        if ($name === '') {
            $name = strstr($email, '@', true) ?: 'WordRise User';
        }

        return [
            'sub' => (string)$claims['sub'],
            'email' => $email,
            'name' => $this->truncate($name, 120),
            'picture' => $picture !== '' ? $picture : null,
            'hosted_domain' => $hostedDomain !== '' ? $hostedDomain : null,
            'authoritative_email' => substr($email, -10) === '@gmail.com'
                || $hostedDomain !== '',
        ];
    }

    private function validateClaims(array $claims): void
    {
        $issuer = (string)($claims['iss'] ?? '');
        if ($issuer !== 'accounts.google.com' && $issuer !== 'https://accounts.google.com') {
            throw new GoogleTokenValidationException('Invalid Google token issuer.');
        }

        $audiences = $claims['aud'] ?? [];
        if (is_string($audiences)) {
            $audiences = [$audiences];
        }
        if (!is_array($audiences) || array_intersect($this->clientIds, $audiences) === []) {
            throw new GoogleTokenValidationException('Invalid Google token audience.');
        }

        $now = ($this->clock)();
        $expiresAt = $this->numericClaim($claims, 'exp');
        $issuedAt = $this->numericClaim($claims, 'iat');
        if ($expiresAt < $now - 60 || $issuedAt > $now + 300) {
            throw new GoogleTokenValidationException('Expired Google ID token.');
        }
        if (isset($claims['nbf']) && $this->numericClaim($claims, 'nbf') > $now + 60) {
            throw new GoogleTokenValidationException('Google ID token is not active.');
        }

        $subject = trim((string)($claims['sub'] ?? ''));
        $email = strtolower(trim((string)($claims['email'] ?? '')));
        $emailVerified = $claims['email_verified'] ?? false;
        $verified = $emailVerified === true
            || $emailVerified === 1
            || $emailVerified === '1'
            || $emailVerified === 'true';
        if ($subject === '' || strlen($subject) > 255) {
            throw new GoogleTokenValidationException('Invalid Google account identifier.');
        }
        if (!$verified || !filter_var($email, FILTER_VALIDATE_EMAIL)) {
            throw new GoogleTokenValidationException('Google email is not verified.');
        }
    }

    private function numericClaim(array $claims, string $key): int
    {
        $value = $claims[$key] ?? null;
        if (!is_int($value) && !(is_string($value) && ctype_digit($value))) {
            throw new GoogleTokenValidationException("Invalid Google token {$key} claim.");
        }
        return (int)$value;
    }

    private function decodeJsonPart(string $part): array
    {
        $decoded = $this->decodeBase64Url($part);
        try {
            $value = json_decode($decoded, true, 32, JSON_THROW_ON_ERROR);
        } catch (JsonException $error) {
            throw new GoogleTokenValidationException('Invalid Google ID token.');
        }
        if (!is_array($value)) {
            throw new GoogleTokenValidationException('Invalid Google ID token.');
        }
        return $value;
    }

    private function decodeBase64Url(string $value): string
    {
        $normalized = strtr($value, '-_', '+/');
        $padding = strlen($normalized) % 4;
        if ($padding !== 0) {
            $normalized .= str_repeat('=', 4 - $padding);
        }
        $decoded = base64_decode($normalized, true);
        if ($decoded === false) {
            throw new GoogleTokenValidationException('Invalid Google ID token.');
        }
        return $decoded;
    }

    private function loadCertificates(bool $forceRefresh): array
    {
        $cached = $this->readCertificateCache();
        $now = time();
        if (!$forceRefresh && $cached !== null && (int)$cached['expires_at'] > $now) {
            return $cached['certificates'];
        }

        try {
            [$body, $maxAge] = $this->fetchCertificateDocument();
            $decoded = json_decode($body, true, 16, JSON_THROW_ON_ERROR);
            if (!is_array($decoded) || $decoded === []) {
                throw new RuntimeException('Google returned no signing certificates.');
            }
            $certificates = [];
            foreach ($decoded as $kid => $certificate) {
                if (is_string($kid) && $kid !== '' && is_string($certificate)
                    && strpos($certificate, 'BEGIN CERTIFICATE') !== false) {
                    $certificates[$kid] = $certificate;
                }
            }
            if ($certificates === []) {
                throw new RuntimeException('Google signing certificates are invalid.');
            }
            $payload = [
                'fetched_at' => $now,
                'expires_at' => $now + max(300, min($maxAge, 86400)),
                'certificates' => $certificates,
            ];
            $this->writeCertificateCache($payload);
            return $certificates;
        } catch (Throwable $error) {
            if ($cached !== null && (int)$cached['fetched_at'] > $now - 604800) {
                return $cached['certificates'];
            }
            throw new GoogleOAuthConfigurationException(
                'Google signing certificates could not be loaded.',
                0,
                $error
            );
        }
    }

    private function fetchCertificateDocument(): array
    {
        if (function_exists('curl_init')) {
            return $this->fetchWithCurl();
        }

        $context = stream_context_create([
            'http' => [
                'method' => 'GET',
                'timeout' => 8,
                'ignore_errors' => true,
                'header' => "Accept: application/json\r\nUser-Agent: WordRise-API/1.0\r\n",
            ],
            'ssl' => [
                'verify_peer' => true,
                'verify_peer_name' => true,
            ],
        ]);
        $body = @file_get_contents(GOOGLE_OAUTH_CERTS_URL, false, $context);
        $headers = $http_response_header ?? [];
        if (!is_string($body) || $body === '' || strlen($body) > 262144
            || !$this->isSuccessfulResponse($headers)) {
            throw new RuntimeException('Google certificate request failed.');
        }
        return [$body, $this->cacheMaxAge($headers)];
    }

    private function fetchWithCurl(): array
    {
        $headers = [];
        $curl = curl_init(GOOGLE_OAUTH_CERTS_URL);
        if ($curl === false) {
            throw new RuntimeException('Google certificate request failed.');
        }
        curl_setopt_array($curl, [
            CURLOPT_RETURNTRANSFER => true,
            CURLOPT_FOLLOWLOCATION => false,
            CURLOPT_CONNECTTIMEOUT => 4,
            CURLOPT_TIMEOUT => 8,
            CURLOPT_SSL_VERIFYPEER => true,
            CURLOPT_SSL_VERIFYHOST => 2,
            CURLOPT_HTTPHEADER => ['Accept: application/json'],
            CURLOPT_USERAGENT => 'WordRise-API/1.0',
            CURLOPT_HEADERFUNCTION => static function ($handle, string $line) use (&$headers): int {
                $headers[] = trim($line);
                return strlen($line);
            },
        ]);
        $body = curl_exec($curl);
        $status = (int)curl_getinfo($curl, CURLINFO_RESPONSE_CODE);
        $error = curl_error($curl);
        curl_close($curl);
        if ($status !== 200 || !is_string($body) || $body === '' || strlen($body) > 262144) {
            throw new RuntimeException('Google certificate request failed: ' . $error);
        }
        return [$body, $this->cacheMaxAge($headers)];
    }

    private function isSuccessfulResponse(array $headers): bool
    {
        foreach ($headers as $header) {
            if (preg_match('/^HTTP\/\S+\s+(\d{3})/', (string)$header, $matches)) {
                return (int)$matches[1] === 200;
            }
        }
        return false;
    }

    private function cacheMaxAge(array $headers): int
    {
        foreach ($headers as $header) {
            if (preg_match('/^Cache-Control:\s*.*max-age=(\d+)/i', (string)$header, $matches)) {
                return (int)$matches[1];
            }
        }
        return 3600;
    }

    private function readCertificateCache(): ?array
    {
        $path = $this->certificateCachePath();
        if (!is_file($path) || is_link($path)) {
            return null;
        }
        $raw = @file_get_contents($path);
        if (!is_string($raw) || $raw === '') {
            return null;
        }
        try {
            $decoded = json_decode($raw, true, 16, JSON_THROW_ON_ERROR);
        } catch (JsonException $error) {
            return null;
        }
        if (!is_array($decoded)
            || !isset($decoded['fetched_at'], $decoded['expires_at'], $decoded['certificates'])
            || !is_array($decoded['certificates'])
            || $decoded['certificates'] === []) {
            return null;
        }
        return $decoded;
    }

    private function writeCertificateCache(array $payload): void
    {
        $path = $this->certificateCachePath();
        $directory = dirname($path);
        if (!is_dir($directory) && !@mkdir($directory, 0700, true) && !is_dir($directory)) {
            return;
        }
        try {
            $suffix = bin2hex(random_bytes(6));
        } catch (Throwable $error) {
            $suffix = (string)getmypid();
        }
        $temporary = $path . '.' . $suffix . '.tmp';
        $json = json_encode($payload, JSON_UNESCAPED_SLASHES);
        if (!is_string($json) || @file_put_contents($temporary, $json, LOCK_EX) === false) {
            return;
        }
        @chmod($temporary, 0600);
        if (!@rename($temporary, $path)) {
            @unlink($temporary);
        }
    }

    private function certificateCachePath(): string
    {
        $configured = trim((string)(getenv('GOOGLE_CERT_CACHE_FILE') ?: ''));
        if ($configured !== '') {
            return $configured;
        }
        return rtrim(sys_get_temp_dir(), DIRECTORY_SEPARATOR)
            . DIRECTORY_SEPARATOR
            . 'wordrise-google-certs-'
            . substr(hash('sha256', __DIR__), 0, 16)
            . '.json';
    }

    private function isSafePictureUrl(string $url): bool
    {
        if ($url === '' || strlen($url) > 500 || !filter_var($url, FILTER_VALIDATE_URL)) {
            return false;
        }
        return strtolower((string)parse_url($url, PHP_URL_SCHEME)) === 'https';
    }

    private function truncate(string $value, int $length): string
    {
        if (function_exists('mb_substr')) {
            return mb_substr($value, 0, $length, 'UTF-8');
        }
        return substr($value, 0, $length);
    }
}
