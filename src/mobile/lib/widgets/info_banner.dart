import 'package:flutter/material.dart';
import 'dart:async';

/// A temporary information banner that appears at the top of the screen
/// 
/// Shows informational messages with automatic dismiss after a specified duration.
/// Supports different styles for success, error, and info states.
class InfoBanner extends StatefulWidget {
  final String message;
  final InfoBannerType type;
  final Duration duration;
  final VoidCallback? onDismiss;

  const InfoBanner({
    super.key,
    required this.message,
    this.type = InfoBannerType.info,
    this.duration = const Duration(seconds: 2),
    this.onDismiss,
  });

  @override
  State<InfoBanner> createState() => _InfoBannerState();
}

class _InfoBannerState extends State<InfoBanner>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<Offset> _slideAnimation;
  Timer? _dismissTimer;

  @override
  void initState() {
    super.initState();
    
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    
    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, -1),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeOutCubic,
    ));

    // Start the entrance animation
    _animationController.forward();

    // Set up auto-dismiss timer
    _dismissTimer = Timer(widget.duration, _dismiss);
  }

  @override
  void dispose() {
    _dismissTimer?.cancel();
    _animationController.dispose();
    super.dispose();
  }

  void _dismiss() async {
    if (mounted) {
      await _animationController.reverse();
      if (mounted) {
        widget.onDismiss?.call();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return SlideTransition(
      position: _slideAnimation,
      child: Material(
        elevation: 4,
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: _getBackgroundColor(),
            border: Border(
              bottom: BorderSide(
                color: _getBorderColor(),
                width: 2,
              ),
            ),
          ),
          child: SafeArea(
            bottom: false,
            child: Row(
              children: [
                Icon(
                  _getIcon(),
                  color: _getIconColor(),
                  size: 20,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    widget.message,
                    style: TextStyle(
                      color: _getTextColor(),
                      fontWeight: FontWeight.w500,
                      fontSize: 14,
                    ),
                  ),
                ),
                GestureDetector(
                  onTap: _dismiss,
                  child: Icon(
                    Icons.close,
                    color: _getIconColor().withValues(alpha: 0.7),
                    size: 18,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Color _getBackgroundColor() {
    switch (widget.type) {
      case InfoBannerType.success:
        return const Color(0xFFE8F5E8);
      case InfoBannerType.error:
        return const Color(0xFFFFEBEE);
      case InfoBannerType.warning:
        return const Color(0xFFFFF3E0);
      case InfoBannerType.info:
        return const Color(0xFFE3F2FD);
    }
  }

  Color _getBorderColor() {
    switch (widget.type) {
      case InfoBannerType.success:
        return const Color(0xFF4CAF50);
      case InfoBannerType.error:
        return const Color(0xFFF44336);
      case InfoBannerType.warning:
        return const Color(0xFFFF9800);
      case InfoBannerType.info:
        return const Color(0xFF2196F3);
    }
  }

  Color _getTextColor() {
    switch (widget.type) {
      case InfoBannerType.success:
        return const Color(0xFF2E7D32);
      case InfoBannerType.error:
        return const Color(0xFFC62828);
      case InfoBannerType.warning:
        return const Color(0xFFF57C00);
      case InfoBannerType.info:
        return const Color(0xFF1565C0);
    }
  }

  Color _getIconColor() {
    return _getTextColor();
  }

  IconData _getIcon() {
    switch (widget.type) {
      case InfoBannerType.success:
        return Icons.check_circle_outline;
      case InfoBannerType.error:
        return Icons.error_outline;
      case InfoBannerType.warning:
        return Icons.warning_amber_outlined;
      case InfoBannerType.info:
        return Icons.info_outline;
    }
  }
}

/// Types of info banners with different visual styles
enum InfoBannerType {
  info,
  success,
  warning,
  error,
}

/// Service for showing info banners using overlay
/// 
/// Manages the display and dismissal of info banners globally
class InfoBannerService {
  static OverlayEntry? _currentEntry;

  /// Show an info banner at the top of the screen
  static void show({
    required BuildContext context,
    required String message,
    InfoBannerType type = InfoBannerType.info,
    Duration duration = const Duration(seconds: 2),
  }) {
    // Remove any existing banner
    dismiss();

    final overlay = Overlay.of(context);
    _currentEntry = OverlayEntry(
      builder: (context) => Positioned(
        top: 0,
        left: 0,
        right: 0,
        child: InfoBanner(
          message: message,
          type: type,
          duration: duration,
          onDismiss: dismiss,
        ),
      ),
    );

    overlay.insert(_currentEntry!);
  }

  /// Dismiss the current info banner
  static void dismiss() {
    _currentEntry?.remove();
    _currentEntry = null;
  }

  /// Show location detection started message
  static void showLocationDetecting(BuildContext context) {
    show(
      context: context,
      message: 'Detecting your location...',
      type: InfoBannerType.info,
    );
  }

  /// Show location detection success message
  static void showLocationFound(BuildContext context) {
    show(
      context: context,
      message: 'Location found',
      type: InfoBannerType.success,
    );
  }

  /// Show location detection failure message
  static void showLocationFailed(BuildContext context) {
    show(
      context: context,
      message: 'Failed to detect location',
      type: InfoBannerType.error,
    );
  }
}