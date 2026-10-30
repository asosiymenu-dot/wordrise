class ApiConfig {
  const ApiConfig._();

  static const baseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'https://69a7b993deaa3.goldxost.ru/wordrise-api/api',
  );
}
