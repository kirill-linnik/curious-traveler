import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';
import '../l10n/app_localizations.dart';
import '../services/azure_maps_service.dart';
import '../models/itinerary_models.dart';

/// Azure Maps WebView widget for displaying interactive maps
class AzureMapsWidget extends StatefulWidget {
  final List<ItineraryLocation> locations;
  final Function(ItineraryLocation)? onLocationTapped;

  const AzureMapsWidget({
    super.key,
    required this.locations,
    this.onLocationTapped,
  });

  @override
  State<AzureMapsWidget> createState() => _AzureMapsWidgetState();
}

class _AzureMapsWidgetState extends State<AzureMapsWidget> {
  late final WebViewController _controller;
  AzureMapsToken? _accessToken;
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _initializeMap();
  }

  Future<void> _initializeMap() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      // Try to get access token (AAD mode)
      try {
        _accessToken = await AzureMapsService.getAccessToken();
      } catch (e) {
        // Token request failed, continue without token (KEY mode or development)
        debugPrint('Access token request failed: $e');
        _accessToken = null;
      }

      // Calculate bounds for all locations
      final bounds = _calculateBounds(widget.locations);

      // Convert locations to markers
      final markers = widget.locations.map((location) {
        return MapMarker(
          latitude: location.location.latitude,
          longitude: location.location.longitude,
          title: location.name,
          description: location.description,
        );
      }).toList();

      // Generate HTML content
      final htmlContent = AzureMapsService.generateMapHtml(
        markers: markers,
        bounds: bounds,
        token: _accessToken,
      );

      // Initialize WebView controller
      _controller = WebViewController()
        ..setJavaScriptMode(JavaScriptMode.unrestricted)
        ..setBackgroundColor(const Color(0x00000000))
        ..setNavigationDelegate(
          NavigationDelegate(
            onProgress: (int progress) {
              debugPrint('Azure Maps loading progress: $progress%');
            },
            onPageStarted: (String url) {
              debugPrint('Azure Maps page started loading: $url');
            },
            onPageFinished: (String url) {
              debugPrint('Azure Maps page finished loading: $url');
              setState(() {
                _isLoading = false;
              });
            },
            onWebResourceError: (WebResourceError error) {
              debugPrint('Azure Maps WebView error: ${error.description}');
              setState(() {
                _isLoading = false;
                _errorMessage = 'Failed to load map: ${error.description}';
              });
            },
          ),
        )
        ..addJavaScriptChannel(
          'FlutterInterface',
          onMessageReceived: (JavaScriptMessage message) {
            _handleMapMessage(message.message);
          },
        )
        ..loadHtmlString(htmlContent);

      setState(() {
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
        _errorMessage = 'Failed to initialize map: $e';
      });
    }
  }

  void _handleMapMessage(String message) {
    try {
      // Handle messages from the map (e.g., marker clicks)
      debugPrint('Message from Azure Maps: $message');
      
      // Example: Parse marker click events
      if (message.startsWith('marker_clicked:')) {
        final locationIndex = int.tryParse(message.split(':')[1]);
        if (locationIndex != null && 
            locationIndex >= 0 && 
            locationIndex < widget.locations.length) {
          widget.onLocationTapped?.call(widget.locations[locationIndex]);
        }
      }
    } catch (e) {
      debugPrint('Error handling map message: $e');
    }
  }

  MapBounds _calculateBounds(List<ItineraryLocation> locations) {
    if (locations.isEmpty) {
      // Default bounds for empty location list
      return MapBounds(
        centerLat: 40.7128,
        centerLon: -74.0060,
        northLat: 40.8128,
        southLat: 40.6128,
        eastLon: -73.9060,
        westLon: -74.1060,
      );
    }

    double minLat = locations.first.location.latitude;
    double maxLat = locations.first.location.latitude;
    double minLon = locations.first.location.longitude;
    double maxLon = locations.first.location.longitude;

    for (final location in locations) {
      minLat = minLat < location.location.latitude ? minLat : location.location.latitude;
      maxLat = maxLat > location.location.latitude ? maxLat : location.location.latitude;
      minLon = minLon < location.location.longitude ? minLon : location.location.longitude;
      maxLon = maxLon > location.location.longitude ? maxLon : location.location.longitude;
    }

    // Add padding
    const padding = 0.01;
    minLat -= padding;
    maxLat += padding;
    minLon -= padding;
    maxLon += padding;

    return MapBounds(
      centerLat: (minLat + maxLat) / 2,
      centerLon: (minLon + maxLon) / 2,
      northLat: maxLat,
      southLat: minLat,
      eastLon: maxLon,
      westLon: minLon,
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const CircularProgressIndicator(),
            const SizedBox(height: 16),
            Text(AppLocalizations.of(context)!.mapLoadingText),
          ],
        ),
      );
    }

    if (_errorMessage != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.error_outline,
              size: 64,
              color: Colors.red,
            ),
            const SizedBox(height: 16),
            Text(
              'Map Error',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 8),
            Text(
              _errorMessage!,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _initializeMap,
              child: Text(AppLocalizations.of(context)!.retry),
            ),
          ],
        ),
      );
    }

    return WebViewWidget(controller: _controller);
  }

  @override
  void didUpdateWidget(AzureMapsWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    
    // Reload map if locations changed
    if (oldWidget.locations != widget.locations) {
      _initializeMap();
    }
  }
}