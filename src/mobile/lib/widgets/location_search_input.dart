import 'package:flutter/material.dart';
import '../l10n/app_localizations.dart';
import '../models/location_models.dart';
import '../viewmodels/journey_endpoint_state.dart';

/// Location search input widget that works with JourneyEndPointState
/// Each endpoint has its own instance of this widget with independent state
class LocationSearchInput extends StatefulWidget {
  final JourneyEndPointState endpointState;
  final bool enabled;
  final Future<List<LocationSelection>> Function(String) onSearch;
  final Function(LocationSelection, BuildContext) onSuggestionTap;

  const LocationSearchInput({
    super.key,
    required this.endpointState,
    this.enabled = true,
    required this.onSearch,
    required this.onSuggestionTap,
  });

  @override
  State<LocationSearchInput> createState() => _LocationSearchInputState();
}

class _LocationSearchInputState extends State<LocationSearchInput> {
  @override
  void initState() {
    super.initState();
    
    // Set up search functionality
    widget.endpointState.addListener(_onEndpointStateChanged);
    widget.endpointState.focusNode.addListener(_onFocusChanged);
    
    // Set up text change listener
    widget.endpointState.controller.addListener(_onTextChanged);
  }

  @override
  void dispose() {
    widget.endpointState.removeListener(_onEndpointStateChanged);
    widget.endpointState.focusNode.removeListener(_onFocusChanged);
    widget.endpointState.controller.removeListener(_onTextChanged);
    super.dispose();
  }

  void _onEndpointStateChanged() {
    if (mounted) {
      setState(() {
        // Update UI to reflect endpoint state changes
      });
      
      // Update overlay visibility
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          widget.endpointState.updateOverlay(context);
        }
      });
    }
  }

  void _onFocusChanged() {
    if (mounted) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          widget.endpointState.updateOverlay(context);
        }
      });
    }
  }

  void _onTextChanged() {
    final text = widget.endpointState.controller.text;
    widget.endpointState.onChanged(text, widget.onSearch);
  }

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context)!;
    
    return CompositedTransformTarget(
      link: widget.endpointState.layerLink,
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: widget.endpointState.focusNode.hasFocus
                ? Theme.of(context).colorScheme.primary
                : Theme.of(context).dividerColor,
          ),
        ),
        child: TextField(
          controller: widget.endpointState.controller,
          focusNode: widget.endpointState.focusNode,
          enabled: widget.enabled,
          decoration: InputDecoration(
            hintText: localizations.homeInputPlaceholder,
            prefixIcon: Icon(
              widget.endpointState.mode == LocationMode.currentLocation
                  ? Icons.my_location
                  : Icons.search,
            ),
            border: InputBorder.none,
            contentPadding: const EdgeInsets.all(16),
          ),
          style: Theme.of(context).textTheme.bodyMedium,
          readOnly: !widget.enabled || widget.endpointState.mode == LocationMode.currentLocation,
        ),
      ),
    );
  }
}