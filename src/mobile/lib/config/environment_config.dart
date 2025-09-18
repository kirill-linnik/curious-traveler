/// Environment-specific configuration
/// 
/// This file configures different environments (development, production) 
/// with their respective ASP.NET Core Web API URLs and settings.

enum Environment {
  development,
  production,
}

class EnvironmentConfig {
  // Private constructor to prevent instantiation
  EnvironmentConfig._();

  // Current environment - change this to switch environments
  // Environment.development: for local development with ASP.NET Core Web API running locally
  // Environment.production: for production deployment
  static const Environment currentEnvironment = Environment.production;

  // Environment-specific configurations
  static const Map<Environment, Map<String, dynamic>> _configurations = {
    Environment.development: {
      'apiBaseUrl': 'http://localhost:5000/api', // ASP.NET Core Web API
      'enableLogging': true,
      'httpTimeout': 30, // seconds
    },
    Environment.production: {
      'apiBaseUrl': 'https://[ADJUSTED-WITH-AZD-UP-SCRIPT]/api', // Will be updated by azd post-deploy hook
      'enableLogging': false,
      'httpTimeout': 30,
    },
  };

  // Get current environment configuration
  static Map<String, dynamic> get current => _configurations[currentEnvironment]!;

  // Specific getters for easy access
  static String get apiBaseUrl => current['apiBaseUrl'] as String;
  static bool get enableLogging => current['enableLogging'] as bool;
  static Duration get httpTimeout => Duration(seconds: current['httpTimeout'] as int);
  
  // Environment checks
  static bool get isDevelopment => currentEnvironment == Environment.development;
  static bool get isProduction => currentEnvironment == Environment.production;
}