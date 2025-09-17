import 'dart:async';
import 'package:flutter/material.dart';
import '../models/location_models.dart';

/// Individual state for one journey endpoint (start or end)
/// Contains independent controller, focus node, and overlay management
class JourneyEndPointState with ChangeNotifier {
  final String id; // "start" | "end"
  final TextEditingController controller = TextEditingController();
  final FocusNode focusNode = FocusNode();
  
  bool _suppressOnChanged = false;
  Timer? _debounce;
  int _requestEpoch = 0;

  LocationMode mode = LocationMode.currentLocation; // default for both
  String queryText = '';   // typed/search text
  String displayText = ''; // last programmatically set shown text
  LocationSelection? selection;
  
  // Search suggestions
  List<LocationSelection> suggestions = [];
  bool showSuggestions = false;
  
  // Overlay management
  final LayerLink layerLink = LayerLink();
  OverlayEntry? overlayEntry;
  bool _tapInProgress = false; // Track if a tap is currently happening

  JourneyEndPointState(this.id);

  @override
  void dispose() {
    controller.dispose();
    focusNode.dispose();
    _debounce?.cancel();
    _removeOverlay();
    super.dispose();
  }

  /// Composition-safe, double-frame setter (reuse proven implementation)
  void setTextProgrammatically(String text) {
    _suppressOnChanged = true;
    
    void write() {
      controller.value = TextEditingValue(
        text: text,
        selection: TextSelection.collapsed(offset: text.length),
        composing: TextRange.empty,
      );
    }
    
    // 1) Immediate write
    write();
    
    // 2) Microtask write (beats immediate onChanged/overlay)
    scheduleMicrotask(write);
    
    // 3) Next frame write (beats rebuild & IME composition)
    WidgetsBinding.instance.addPostFrameCallback((_) {
      write();
      _suppressOnChanged = false;
    });
  }

  /// Handle text changes with debouncing and search
  void onChanged(String value, Future<List<LocationSelection>> Function(String) fetch) {
    if (_suppressOnChanged) {
      return;
    }
    if (mode != LocationMode.anotherLocation) {
      return;
    }
    
    queryText = value;
    
    _debounce?.cancel();
    if (value.trim().length < 2) {
      suggestions.clear();
      showSuggestions = false;
      _removeOverlay();
      notifyListeners();
      return;
    }
    
    final epoch = ++_requestEpoch;
    _debounce = Timer(const Duration(milliseconds: 300), () async {
      try {
        final results = await fetch(value);
        if (epoch != _requestEpoch) {
          return; // ignore stale responses
        }
        
        suggestions = results;
        showSuggestions = results.isNotEmpty;
        notifyListeners();
      } catch (e) {
        if (epoch != _requestEpoch) return;
        suggestions.clear();
        showSuggestions = false;
        notifyListeners();
      }
    });
  }

  /// Handle suggestion selection
  void onSuggestionSelected(LocationSelection sel, BuildContext context) {
    final display = (sel.fullAddress?.isNotEmpty == true) ? sel.fullAddress! : sel.name;
    
    // Cancel any pending searches and debounce
    _debounce?.cancel();
    _requestEpoch++;

    // Set text programmatically using the proven approach from original HomeLocationVm
    setTextProgrammatically(display);
    
    // Update both query and display text to prevent overwrites  
    displayText = display;
    queryText = display;
    selection = sel;
    
    // Clear suggestions and close overlay
    suggestions.clear();
    showSuggestions = false;
    _tapInProgress = false; // Ensure tap state is reset
    _removeOverlay();

    // Close keyboard immediately, not in post-frame callback
    try {
      focusNode.unfocus();
    } catch (e) {
      // Ignore unfocus errors
    }
    
    notifyListeners();
  }

  /// Set mode and handle text updates
  void setMode(LocationMode nextMode, {LocationSnapshot? currentSnapshot}) {
    if (mode == nextMode) return;
    
    mode = nextMode;
    if (mode == LocationMode.currentLocation) {
      final snap = currentSnapshot?.displayText ?? '';
      setTextProgrammatically(snap);   // ALWAYS override when switching to Current
      displayText = snap;
      queryText = snap;
      selection = null;                // current location has no "selection"
      suggestions.clear();
      showSuggestions = false;
      _removeOverlay();
    } else {
      // Switching to another location - clear the field
      setTextProgrammatically('');
      displayText = '';
      queryText = '';
      selection = null;
      suggestions.clear();
      showSuggestions = false;
    }
    
    notifyListeners();
  }

  /// Show suggestions overlay
  void showOverlay(BuildContext context) {
    if (!showSuggestions || suggestions.isEmpty) {
      _removeOverlay();
      return;
    }
    
    // If overlay already exists, remove and recreate with new suggestions
    if (overlayEntry != null) {
      _removeOverlay();
    }
    
    overlayEntry = OverlayEntry(
      builder: (context) => _SuggestionsOverlay(
        endpoint: this,
        layerLink: layerLink,
        onSuggestionTap: (sel) {
          onSuggestionSelected(sel, context);
        },
      ),
    );
    
    Overlay.of(context).insert(overlayEntry!);
  }

  /// Remove suggestions overlay
  void _removeOverlay() {
    if (overlayEntry != null) {
      overlayEntry!.remove();
      overlayEntry = null;
    }
  }

  /// Delayed overlay removal to allow taps to complete
  void _removeOverlayDelayed() {
    if (_tapInProgress) {
      // If a tap is in progress, wait a bit longer
      Future.delayed(const Duration(milliseconds: 100), () {
        if (!_tapInProgress) {
          _removeOverlay();
        }
      });
    } else {
      _removeOverlay();
    }
  }

  /// Update overlay visibility
  void updateOverlay(BuildContext context) {
    if (showSuggestions && suggestions.isNotEmpty && focusNode.hasFocus) {
      showOverlay(context);
    } else {
      // Use delayed removal to handle tap-in-progress scenarios
      _removeOverlayDelayed();
    }
  }
}

/// Suggestions overlay widget
class _SuggestionsOverlay extends StatelessWidget {
  final JourneyEndPointState endpoint;
  final LayerLink layerLink;
  final Function(LocationSelection) onSuggestionTap;

  const _SuggestionsOverlay({
    required this.endpoint,
    required this.layerLink,
    required this.onSuggestionTap,
  });

  @override
  Widget build(BuildContext context) {
    return Positioned(
      width: MediaQuery.of(context).size.width - 32, // Account for padding
      child: CompositedTransformFollower(
        link: layerLink,
        showWhenUnlinked: false,
        offset: const Offset(0, 60), // Position below input field
        child: Material(
          elevation: 4,
          borderRadius: BorderRadius.circular(8),
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Theme.of(context).dividerColor),
            ),
            constraints: const BoxConstraints(maxHeight: 200),
            child: ListView.separated(
              shrinkWrap: true,
              padding: EdgeInsets.zero,
              itemCount: endpoint.suggestions.length,
              separatorBuilder: (_, __) => const Divider(height: 1),
              itemBuilder: (context, index) {
                final suggestion = endpoint.suggestions[index];
                
                return Container( // Web-compatible tap container
                  decoration: BoxDecoration(
                    color: Colors.transparent,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: GestureDetector(
                    key: ValueKey('sugg_${suggestion.id}'),
                    behavior: HitTestBehavior.opaque, // Ensures the entire area is tappable
                    onTapDown: (details) {
                      endpoint._tapInProgress = true; // Mark tap as starting
                    },
                    onTapCancel: () {
                      endpoint._tapInProgress = false; // Reset on cancel
                    },
                    onTap: () {
                      try {
                        onSuggestionTap(suggestion);
                      } finally {
                        endpoint._tapInProgress = false; // Reset tap state
                      }
                    },
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      child: Row(
                        children: [
                          Icon(_getIconForType(suggestion.type), size: 20),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  suggestion.name,
                                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                                if (suggestion.fullAddress != null && suggestion.fullAddress != suggestion.name)
                                  Text(
                                    suggestion.fullAddress!,
                                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                      color: Colors.black54,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ),
      ),
    );
  }

  IconData _getIconForType(String type) {
    switch (type.toLowerCase()) {
      case 'locality':
        return Icons.location_city;
      case 'address':
        return Icons.home;
      case 'poi':
        return Icons.place;
      default:
        return Icons.location_on;
    }
  }
}