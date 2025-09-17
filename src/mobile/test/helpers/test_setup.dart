import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Sets up test environment with proper plugin mocking
void setupTestEnvironment() {
  TestWidgetsFlutterBinding.ensureInitialized();
  
  // Mock SharedPreferences plugin
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMethodCallHandler(
    const MethodChannel('plugins.flutter.io/shared_preferences'),
    (MethodCall methodCall) async {
      switch (methodCall.method) {
        case 'getAll':
          return <String, Object>{}; // Empty preferences
        case 'setBool':
        case 'setDouble':
        case 'setInt':
        case 'setString':
        case 'setStringList':
          return true; // Success
        case 'remove':
        case 'clear':
          return true; // Success
        default:
          return null;
      }
    },
  );

  // Mock location services plugin
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMethodCallHandler(
    const MethodChannel('flutter.baseflow.com/geolocator'),
    (MethodCall methodCall) async {
      switch (methodCall.method) {
        case 'checkPermission':
          return 3; // LocationPermission.whileInUse
        case 'requestPermission':
          return 3; // LocationPermission.whileInUse
        case 'getCurrentPosition':
          return {
            'latitude': 37.7749,
            'longitude': -122.4194,
            'timestamp': DateTime.now().millisecondsSinceEpoch,
            'accuracy': 5.0,
            'altitude': 0.0,
            'heading': 0.0,
            'speed': 0.0,
            'speed_accuracy': 0.0
          };
        default:
          return null;
      }
    },
  );

  // Mock audio players plugin
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMethodCallHandler(
    const MethodChannel('xyz.luan/audioplayers'),
    (MethodCall methodCall) async {
      switch (methodCall.method) {
        case 'create':
          return 'test_player_id';
        case 'setUrl':
        case 'resume':
        case 'pause':
        case 'stop':
        case 'seek':
        case 'setVolume':
        case 'setPlaybackRate':
          return 1; // Success
        case 'getCurrentPosition':
          return 0; // 0 seconds
        case 'getDuration':
          return 30000; // 30 seconds in milliseconds
        default:
          return null;
      }
    },
  );

  // Mock URL launcher plugin
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMethodCallHandler(
    const MethodChannel('plugins.flutter.io/url_launcher'),
    (MethodCall methodCall) async {
      switch (methodCall.method) {
        case 'canLaunch':
          return true;
        case 'launch':
          return true;
        default:
          return null;
      }
    },
  );
}

/// Initializes shared preferences for testing
Future<void> initializeSharedPreferencesForTests() async {
  SharedPreferences.setMockInitialValues({});
}