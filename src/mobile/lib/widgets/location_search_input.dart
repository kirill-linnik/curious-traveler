import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../models/location_models.dart';
import '../l10n/app_localizations.dart';
import '../viewmodels/home_location_vm.dart';

class LocationSearchInput extends StatefulWidget {
  final HomeLocationVm viewModel;
  final List<LocationSearchResult> searchResults;
  final LocationStatus status;
  final String? error;
  final bool enabled;
  final FocusNode? focusNode;

  const LocationSearchInput({
    super.key,
    required this.viewModel,
    required this.searchResults,
    required this.status,
    this.error,
    this.enabled = true,
    this.focusNode,
  });

  @override
  State<LocationSearchInput> createState() => _LocationSearchInputState();
}

class _LocationSearchInputState extends State<LocationSearchInput> {
  final LayerLink _layerLink = LayerLink();
  OverlayEntry? _overlayEntry;
  late final FocusNode _focusNode;
  Timer? _delayTimer;

  @override
  void initState() {
    super.initState();
    
    // Use provided focus node or create our own
    _focusNode = widget.focusNode ?? FocusNode();
    _focusNode.addListener(_onFocusChanged);
    
    // Set the close suggestions callback in the view model
    widget.viewModel.setCloseSuggestionsCallback(_removeSuggestions);
  }

  @override
  void didUpdateWidget(LocationSearchInput oldWidget) {
    super.didUpdateWidget(oldWidget);
    
    // Update overlay when search results change
    if (widget.searchResults != oldWidget.searchResults) {
      // Defer overlay update until after build to avoid setState during build
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _updateSuggestions();
      });
    }
  }

  @override
  void dispose() {
    _delayTimer?.cancel();
    _removeSuggestions();
    // Only dispose focus node if we created it
    if (widget.focusNode == null) {
      _focusNode.dispose();
    }
    super.dispose();
  }

  void _onFocusChanged() {
    _delayTimer?.cancel(); // Cancel any existing timer
    
    if (_focusNode.hasFocus && widget.enabled && widget.searchResults.isNotEmpty) {
      _showSuggestions();
    } else {
      // Delay overlay removal to allow tap gestures to complete
      _delayTimer = Timer(const Duration(milliseconds: 100), () {
        if (!_focusNode.hasFocus) {
          _removeSuggestions();
        }
      });
    }
  }

  void _handleTextChanged(String value) {
    widget.viewModel.handleTextChanged(value);
  }

  void _updateSuggestions() {
    if (_focusNode.hasFocus && widget.enabled) {
      if (widget.searchResults.isNotEmpty) {
        _showSuggestions();
      } else {
        _removeSuggestions();
      }
    }
  }

  void _showSuggestions() {
    _removeSuggestions();
    
    _overlayEntry = _createSuggestionsOverlay();
    // Insert as last overlay to be on top
    Overlay.of(context, rootOverlay: true).insert(_overlayEntry!);
  }

  void _removeSuggestions() {
    if (_overlayEntry != null) {
      _overlayEntry!.remove();
      _overlayEntry = null;
    }
  }

  OverlayEntry _createSuggestionsOverlay() {
    final renderBox = context.findRenderObject() as RenderBox;
    final size = renderBox.size;

    return OverlayEntry(
      builder: (context) {
        // Calculate the needed height based on content
        final itemCount = widget.searchResults.length;
        final hasResults = itemCount > 0;
        
        double overlayHeight;
        if (!hasResults) {
          // "No results" text with padding
          overlayHeight = 48.0; 
        } else {
          // Each item: ~60px, plus dividers between items
          overlayHeight = (itemCount * 60.0) + ((itemCount - 1) * 1.0);
          // Cap at reasonable maximum
          overlayHeight = overlayHeight.clamp(60.0, 200.0);
        }
        
        return Positioned(
          left: renderBox.localToGlobal(Offset.zero).dx,
          top: renderBox.localToGlobal(Offset.zero).dy + size.height + 5,
          width: size.width,
          height: overlayHeight,
          child: Material(
            elevation: 6,
            borderRadius: BorderRadius.circular(8),
            child: _SuggestionsList(
              searchResults: widget.searchResults,
              viewModel: widget.viewModel,
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context)!;

    return CompositedTransformTarget(
      link: _layerLink,
      child: TextFormField(
        key: const Key('location_input'),
        controller: widget.viewModel.locationController,
        focusNode: _focusNode,
        enabled: widget.enabled,
        onChanged: _handleTextChanged,
        decoration: InputDecoration(
          labelText: localizations.homeInputLabel,
          hintText: widget.enabled ? localizations.homeInputPlaceholder : null,
          border: const OutlineInputBorder(),
          prefixIcon: const Icon(Icons.location_on),
          suffixIcon: widget.status == LocationStatus.searching
              ? const Padding(
                  padding: EdgeInsets.all(12),
                  child: SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                )
              : widget.viewModel.locationController.text.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear),
                      onPressed: () {
                        // Use onClear callback if provided, otherwise fall back to onChanged
                        widget.viewModel.clearText();
                      },
                    )
                  : null,
        ),
      ),
    );
  }
}

class _SuggestionsList extends StatelessWidget {
  final HomeLocationVm viewModel;
  final List<LocationSearchResult> searchResults;
  
  const _SuggestionsList({
    required this.viewModel,
    required this.searchResults,
  });

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context)!;

    // Simplified structure without Listener interference
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Theme.of(context).dividerColor),
      ),
      child: _buildContent(context, localizations),
    );
  }

  Widget _buildContent(BuildContext context, AppLocalizations localizations) {
    // Handle different states
    if (searchResults.isEmpty) {
      return Padding(
        padding: const EdgeInsets.all(16),
        child: Text(localizations.homeSearchNoResults),
      );
    }

    return ListView.separated(
      padding: EdgeInsets.zero,
      shrinkWrap: true,
      itemCount: searchResults.length,
      separatorBuilder: (_, __) => const Divider(height: 1),
      itemBuilder: (_, i) {
        final sel = searchResults[i];
        
        return Container( // Web-compatible tap container
          decoration: BoxDecoration(
            color: Colors.transparent,
            borderRadius: BorderRadius.circular(4),
          ),
          child: GestureDetector(
            key: ValueKey('sugg_${sel.id}'),
            behavior: HitTestBehavior.opaque, // Ensures the entire area is tappable
            onTapDown: (details) {
              // Tap down detected
            },
            onTapUp: (details) {
              // Tap up detected
            },
            onTap: () {
              viewModel.handleLocationSelected(sel, context); // will set the controller
            },
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              child: Row(
                children: [
                  Icon(sel.icon, size: 20),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          sel.name, 
                          style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        if (sel.formattedAddress.isNotEmpty && sel.formattedAddress != sel.name)
                          Text(
                            sel.formattedAddress,
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
    );
  }
}