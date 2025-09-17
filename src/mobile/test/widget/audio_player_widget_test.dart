import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:mocktail/mocktail.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:curious_traveler/widgets/audio_player_widget.dart';
import 'package:curious_traveler/providers/audio_provider.dart';
import 'package:curious_traveler/l10n/app_localizations.dart';

class MockAudioProvider extends Mock implements AudioProvider {}

void main() {
  group('AudioPlayerWidget Tests', () {
    late MockAudioProvider mockAudioProvider;

    setUp(() {
      mockAudioProvider = MockAudioProvider();
    });

    Widget createTestWidget() {
      return MaterialApp(
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: const [Locale('en', 'US')],
        home: Scaffold(
          body: ChangeNotifierProvider<AudioProvider>.value(
            value: mockAudioProvider,
            child: const AudioPlayerWidget(),
          ),
        ),
      );
    }

    testWidgets('should not display when no audio is playing and not loading', (WidgetTester tester) async {
      // Arrange
      when(() => mockAudioProvider.isPlaying).thenReturn(false);
      when(() => mockAudioProvider.isLoading).thenReturn(false);
      when(() => mockAudioProvider.currentLocationId).thenReturn(null);
      when(() => mockAudioProvider.progress).thenReturn(0.0);
      when(() => mockAudioProvider.position).thenReturn(Duration.zero);
      when(() => mockAudioProvider.duration).thenReturn(Duration.zero);
      when(() => mockAudioProvider.error).thenReturn(null);

      // Act
      await tester.pumpWidget(createTestWidget());

      // Assert
      expect(find.byType(AudioPlayerWidget), findsOneWidget);
      expect(find.byType(SizedBox), findsOneWidget); // Should show SizedBox.shrink()
    });

    testWidgets('should display player when currently playing', (WidgetTester tester) async {
      // Arrange
      when(() => mockAudioProvider.isPlaying).thenReturn(true);
      when(() => mockAudioProvider.isLoading).thenReturn(false);
      when(() => mockAudioProvider.currentLocationId).thenReturn('location_1');
      when(() => mockAudioProvider.progress).thenReturn(0.3);
      when(() => mockAudioProvider.position).thenReturn(const Duration(seconds: 30));
      when(() => mockAudioProvider.duration).thenReturn(const Duration(minutes: 2));
      when(() => mockAudioProvider.error).thenReturn(null);
      when(() => mockAudioProvider.pauseAudio()).thenAnswer((_) async {});

      // Act
      await tester.pumpWidget(createTestWidget());

      // Assert
      expect(find.byType(Container), findsAtLeast(1)); // Player container should be visible
      expect(find.byIcon(Icons.pause), findsOneWidget);
      expect(find.byType(LinearProgressIndicator), findsOneWidget);
      expect(find.text('00:30'), findsOneWidget); // Position
      expect(find.text('02:00'), findsOneWidget); // Duration
    });

    testWidgets('should display player when loading', (WidgetTester tester) async {
      // Arrange
      when(() => mockAudioProvider.isPlaying).thenReturn(false);
      when(() => mockAudioProvider.isLoading).thenReturn(true);
      when(() => mockAudioProvider.currentLocationId).thenReturn('location_1');
      when(() => mockAudioProvider.progress).thenReturn(0.0);
      when(() => mockAudioProvider.position).thenReturn(Duration.zero);
      when(() => mockAudioProvider.duration).thenReturn(Duration.zero);
      when(() => mockAudioProvider.error).thenReturn(null);

      // Act
      await tester.pumpWidget(createTestWidget());

      // Assert
      expect(find.byType(Container), findsAtLeast(1)); // Player container should be visible
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
    });

    testWidgets('should show play button when paused', (WidgetTester tester) async {
      // Arrange
      when(() => mockAudioProvider.isPlaying).thenReturn(false);
      when(() => mockAudioProvider.isLoading).thenReturn(false);
      when(() => mockAudioProvider.currentLocationId).thenReturn('location_1');
      when(() => mockAudioProvider.progress).thenReturn(0.5);
      when(() => mockAudioProvider.position).thenReturn(const Duration(minutes: 1));
      when(() => mockAudioProvider.duration).thenReturn(const Duration(minutes: 2));
      when(() => mockAudioProvider.error).thenReturn(null);
      when(() => mockAudioProvider.resumeAudio()).thenAnswer((_) async {});

      // Act
      await tester.pumpWidget(createTestWidget());

      // Assert
      expect(find.byIcon(Icons.play_arrow), findsOneWidget);
      expect(find.byIcon(Icons.pause), findsNothing);
    });

    testWidgets('should call pauseAudio when pause button is tapped', (WidgetTester tester) async {
      // Arrange
      when(() => mockAudioProvider.isPlaying).thenReturn(true);
      when(() => mockAudioProvider.isLoading).thenReturn(false);
      when(() => mockAudioProvider.currentLocationId).thenReturn('location_1');
      when(() => mockAudioProvider.progress).thenReturn(0.3);
      when(() => mockAudioProvider.position).thenReturn(const Duration(seconds: 30));
      when(() => mockAudioProvider.duration).thenReturn(const Duration(minutes: 2));
      when(() => mockAudioProvider.error).thenReturn(null);
      when(() => mockAudioProvider.pauseAudio()).thenAnswer((_) async {});

      // Act
      await tester.pumpWidget(createTestWidget());
      
      final pauseButton = find.byIcon(Icons.pause);
      await tester.tap(pauseButton);

      // Assert
      verify(() => mockAudioProvider.pauseAudio()).called(1);
    });

    testWidgets('should call resumeAudio when play button is tapped', (WidgetTester tester) async {
      // Arrange
      when(() => mockAudioProvider.isPlaying).thenReturn(false);
      when(() => mockAudioProvider.isLoading).thenReturn(false);
      when(() => mockAudioProvider.currentLocationId).thenReturn('location_1');
      when(() => mockAudioProvider.progress).thenReturn(0.3);
      when(() => mockAudioProvider.position).thenReturn(const Duration(seconds: 30));
      when(() => mockAudioProvider.duration).thenReturn(const Duration(minutes: 2));
      when(() => mockAudioProvider.error).thenReturn(null);
      when(() => mockAudioProvider.resumeAudio()).thenAnswer((_) async {});

      // Act
      await tester.pumpWidget(createTestWidget());
      
      final playButton = find.byIcon(Icons.play_arrow);
      await tester.tap(playButton);

      // Assert
      verify(() => mockAudioProvider.resumeAudio()).called(1);
    });

    testWidgets('should call stopAudio when stop button is tapped', (WidgetTester tester) async {
      // Arrange
      when(() => mockAudioProvider.isPlaying).thenReturn(true);
      when(() => mockAudioProvider.isLoading).thenReturn(false);
      when(() => mockAudioProvider.currentLocationId).thenReturn('location_1');
      when(() => mockAudioProvider.progress).thenReturn(0.3);
      when(() => mockAudioProvider.position).thenReturn(const Duration(seconds: 30));
      when(() => mockAudioProvider.duration).thenReturn(const Duration(minutes: 2));
      when(() => mockAudioProvider.error).thenReturn(null);
      when(() => mockAudioProvider.stopAudio()).thenAnswer((_) async {});

      // Act
      await tester.pumpWidget(createTestWidget());
      
      final stopButton = find.byIcon(Icons.stop);
      await tester.tap(stopButton);

      // Assert
      verify(() => mockAudioProvider.stopAudio()).called(1);
    });

    testWidgets('should display error message when error exists', (WidgetTester tester) async {
      // Arrange
      when(() => mockAudioProvider.isPlaying).thenReturn(false);
      when(() => mockAudioProvider.isLoading).thenReturn(false);
      when(() => mockAudioProvider.currentLocationId).thenReturn('location_1');
      when(() => mockAudioProvider.progress).thenReturn(0.0);
      when(() => mockAudioProvider.position).thenReturn(Duration.zero);
      when(() => mockAudioProvider.duration).thenReturn(Duration.zero);
      when(() => mockAudioProvider.error).thenReturn('Failed to load audio');
      when(() => mockAudioProvider.clearError()).thenReturn(null);

      // Act
      await tester.pumpWidget(createTestWidget());

      // Assert
      expect(find.text('Failed to load audio'), findsOneWidget);
      expect(find.text('Dismiss'), findsOneWidget);
      expect(find.byIcon(Icons.error), findsOneWidget);
    });

    testWidgets('should call clearError when dismiss button is tapped', (WidgetTester tester) async {
      // Arrange
      when(() => mockAudioProvider.isPlaying).thenReturn(false);
      when(() => mockAudioProvider.isLoading).thenReturn(false);
      when(() => mockAudioProvider.currentLocationId).thenReturn('location_1');
      when(() => mockAudioProvider.progress).thenReturn(0.0);
      when(() => mockAudioProvider.position).thenReturn(Duration.zero);
      when(() => mockAudioProvider.duration).thenReturn(Duration.zero);
      when(() => mockAudioProvider.error).thenReturn('Failed to load audio');
      when(() => mockAudioProvider.clearError()).thenReturn(null);

      // Act
      await tester.pumpWidget(createTestWidget());
      
      final dismissButton = find.text('Dismiss');
      await tester.tap(dismissButton);

      // Assert
      verify(() => mockAudioProvider.clearError()).called(1);
    });

    testWidgets('should format time correctly for different durations', (WidgetTester tester) async {
      // Arrange
      when(() => mockAudioProvider.isPlaying).thenReturn(false);
      when(() => mockAudioProvider.isLoading).thenReturn(false);
      when(() => mockAudioProvider.currentLocationId).thenReturn('location_1');
      when(() => mockAudioProvider.progress).thenReturn(0.0);
      when(() => mockAudioProvider.position).thenReturn(const Duration(minutes: 1, seconds: 23));
      when(() => mockAudioProvider.duration).thenReturn(const Duration(minutes: 10, seconds: 45));
      when(() => mockAudioProvider.error).thenReturn(null);

      // Act
      await tester.pumpWidget(createTestWidget());

      // Assert
      expect(find.text('01:23'), findsOneWidget); // Position formatted
      expect(find.text('10:45'), findsOneWidget); // Duration formatted
    });

    testWidgets('should show correct progress value', (WidgetTester tester) async {
      // Arrange
      when(() => mockAudioProvider.isPlaying).thenReturn(false);
      when(() => mockAudioProvider.isLoading).thenReturn(false);
      when(() => mockAudioProvider.currentLocationId).thenReturn('location_1');
      when(() => mockAudioProvider.progress).thenReturn(0.75); // 75% progress
      when(() => mockAudioProvider.position).thenReturn(const Duration(minutes: 1, seconds: 30));
      when(() => mockAudioProvider.duration).thenReturn(const Duration(minutes: 2));
      when(() => mockAudioProvider.error).thenReturn(null);

      // Act
      await tester.pumpWidget(createTestWidget());

      // Assert
      final progressIndicator = tester.widget<LinearProgressIndicator>(
        find.byType(LinearProgressIndicator)
      );
      expect(progressIndicator.value, 0.75);
    });

    testWidgets('should disable buttons when loading', (WidgetTester tester) async {
      // Arrange
      when(() => mockAudioProvider.isPlaying).thenReturn(false);
      when(() => mockAudioProvider.isLoading).thenReturn(true);
      when(() => mockAudioProvider.currentLocationId).thenReturn('location_1');
      when(() => mockAudioProvider.progress).thenReturn(0.0);
      when(() => mockAudioProvider.position).thenReturn(Duration.zero);
      when(() => mockAudioProvider.duration).thenReturn(Duration.zero);
      when(() => mockAudioProvider.error).thenReturn(null);

      // Act
      await tester.pumpWidget(createTestWidget());

      // Assert
      final playPauseButton = tester.widget<IconButton>(
        find.descendant(
          of: find.byType(Container),
          matching: find.byType(IconButton),
        ).at(1), // The main play/pause button (middle button)
      );
      expect(playPauseButton.onPressed, isNull);
    });
  });
}