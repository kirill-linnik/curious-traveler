/// Application configuration constants
/// 
/// This file contains all configuration values used throughout the app,
/// including API endpoints, environment-specific settings, and other constants.
import 'environment_config.dart';

class AppConfig {
  // Private constructor to prevent instantiation
  AppConfig._();

  // ASP.NET Core Web API Configuration (environment-specific)
  static String get apiBaseUrl => EnvironmentConfig.apiBaseUrl;
  
  // API Endpoints (Note: Only geocoding endpoints are currently implemented)
  static const String generateItineraryEndpoint = '/itinerary/generate';
  static const String updateItineraryEndpoint = '/itinerary/update';
  static const String getLocationNarrationEndpoint = '/location';
  static const String generateAudioEndpoint = '/speech/generate';
  static const String getSupportedVoicesEndpoint = '/speech/voices';
  
  // HTTP Configuration (environment-specific)
  static Duration get httpTimeout => EnvironmentConfig.httpTimeout;
  static const Map<String, String> defaultHeaders = {
    'Content-Type': 'application/json',
  };
  
  // App Information
  static const String appName = 'Curious Traveler';
  static const String appVersion = '1.0.0';
  
  // Environment (environment-specific)
  static bool get isProduction => EnvironmentConfig.isProduction;
  static bool get enableLogging => EnvironmentConfig.enableLogging;
}