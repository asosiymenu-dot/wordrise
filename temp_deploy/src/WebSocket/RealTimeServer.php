<?php

namespace WordRise\WebSocket;

use Ratchet\MessageComponentInterface;
use Ratchet\ConnectionInterface;

class RealTimeServer implements MessageComponentInterface
{
    protected $clients;
    protected $users; // Map of ConnectionInterface => user info

    public function __construct()
    {
        $this->clients = new \SplObjectStorage;
        $this->users = new \SplObjectStorage;
    }

    public function onOpen(ConnectionInterface $conn)
    {
        $this->clients->attach($conn);
        echo "New connection! ({$conn->resourceId})\n";
    }

    public function onMessage(ConnectionInterface $from, $msg)
    {
        $data = json_decode($msg, true);
        if (!$data || !isset($data['type'])) {
            return;
        }

        // Handle Authentication
        if ($data['type'] === 'auth') {
            $token = $data['token'] ?? '';
            $user = $this->authenticateToken($token);
            if ($user) {
                $this->users[$from] = $user;
                $from->send(json_encode(['type' => 'auth_success', 'user_id' => $user['id']]));
                
                // Broadcast presence status
                $this->broadcast([
                    'type' => 'user_status_changed',
                    'data' => ['user_id' => $user['id'], 'status' => 'online']
                ]);
            } else {
                $from->send(json_encode(['type' => 'auth_error', 'message' => 'Invalid token']));
                $from->close();
            }
            return;
        }

        // Client-to-server messages (e.g. typing indicators) can be handled here
        if ($data['type'] === 'typing') {
            $user = $this->getUser($from);
            if ($user && isset($data['target_user_id'])) {
                $this->sendToUser((int)$data['target_user_id'], [
                    'type' => 'typing',
                    'data' => ['user_id' => $user['id']]
                ]);
            }
        }
    }

    public function onClose(ConnectionInterface $conn)
    {
        $user = $this->getUser($conn);
        $this->clients->detach($conn);
        
        if ($this->users->contains($conn)) {
            $this->users->detach($conn);
        }

        if ($user) {
            $this->broadcast([
                'type' => 'user_status_changed',
                'data' => ['user_id' => $user['id'], 'status' => 'offline']
            ]);
        }
        
        echo "Connection {$conn->resourceId} has disconnected\n";
    }

    public function onError(ConnectionInterface $conn, \Exception $e)
    {
        echo "An error has occurred: {$e->getMessage()}\n";
        $conn->close();
    }

    /**
     * Broadcasts an event internally from the REST API to clients
     */
    public function handleInternalBroadcast($msg)
    {
        $payload = json_decode($msg, true);
        if (!$payload) return;

        $targetUserId = $payload['target_user_id'] ?? null;
        $excludeUserId = $payload['exclude_user_id'] ?? null;
        $event = [
            'type' => $payload['event'],
            'data' => $payload['data']
        ];

        if ($targetUserId !== null) {
            $this->sendToUser((int)$targetUserId, $event);
        } else {
            $this->broadcast($event, $excludeUserId ? (int)$excludeUserId : null);
        }
    }

    protected function sendToUser(int $userId, array $event)
    {
        $msg = json_encode($event);
        foreach ($this->clients as $client) {
            $user = $this->getUser($client);
            if ($user && $user['id'] === $userId) {
                $client->send($msg);
            }
        }
    }

    protected function broadcast(array $event, ?int $excludeUserId = null)
    {
        $msg = json_encode($event);
        foreach ($this->clients as $client) {
            $user = $this->getUser($client);
            if ($user && $excludeUserId !== null && $user['id'] === $excludeUserId) {
                continue;
            }
            if ($user) {
                $client->send($msg);
            }
        }
    }

    protected function getUser(ConnectionInterface $conn)
    {
        return $this->users->contains($conn) ? $this->users[$conn] : null;
    }

    protected function authenticateToken(string $token): ?array
    {
        // Require the token parsing logic from the existing auth_middleware
        // We simulate a request token check
        require_once __DIR__ . '/../../middleware/auth_middleware.php';
        try {
            // jwt_verify from helpers/jwt.php (which should be required by auth_middleware)
            if (!function_exists('jwt_verify')) {
                require_once __DIR__ . '/../../helpers/jwt.php';
            }
            $payload = jwt_verify($token);
            if ($payload && isset($payload['id'])) {
                // Verify user exists
                require_once __DIR__ . '/../../models/User.php';
                $user = \User::findById((int)$payload['id']);
                return $user ?: null;
            }
        } catch (\Throwable $e) {
            return null;
        }
        return null;
    }
}
