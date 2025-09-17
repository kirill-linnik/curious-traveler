import 'dart:convert';
import 'package:http/http.dart' as http;
import '../config/app_config.dart';

/// Service for Azure Maps integration
class AzureMapsService {
  static final String _baseUrl = AppConfig.apiBaseUrl;

  /// Get an access token for Azure Maps
  static Future<AzureMapsToken?> getAccessToken() async {
    try {
      final uri = Uri.parse('$_baseUrl/maps/token');
      final response = await http.get(
        uri,
        headers: AppConfig.defaultHeaders,
      );

      if (response.statusCode == 200) {
        final jsonData = jsonDecode(response.body) as Map<String, dynamic>;
        return AzureMapsToken.fromJson(jsonData);
      } else if (response.statusCode == 400) {
        // Token endpoint not available (likely KEY mode)
        return null;
      } else {
        throw Exception('Failed to get access token: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Access token error: $e');
    }
  }

  /// Generate Azure Maps Web SDK initialization HTML
  static String generateMapHtml({
    required List<MapMarker> markers,
    required MapBounds bounds,
    AzureMapsToken? token,
  }) {
    final markersJson = jsonEncode(markers.map((m) => m.toJson()).toList());
    final boundsJson = jsonEncode(bounds.toJson());
    
    // Use token if available (AAD mode), otherwise use fallback tiles
    final authConfig = token != null 
        ? '''
        authOptions: {
          authType: 'aad',
          aadAppId: '${token.accessToken}',
          aadTenant: 'common'
        }'''
        : '''
        authOptions: {
          authType: 'subscriptionKey',
          subscriptionKey: 'demo-key' // Will be handled by tile proxy in production
        }''';

    return '''
    <!DOCTYPE html>
    <html>
    <head>
        <meta charset="utf-8">
        <meta name="viewport" content="width=device-width, initial-scale=1">
        <title>Azure Maps</title>
        <link rel="stylesheet" href="https://atlas.microsoft.com/sdk/javascript/mapcontrol/3/atlas.min.css" type="text/css">
        <script src="https://atlas.microsoft.com/sdk/javascript/mapcontrol/3/atlas.min.js"></script>
        <style>
            body { margin: 0; padding: 0; }
            #map { width: 100vw; height: 100vh; }
        </style>
    </head>
    <body>
        <div id="map"></div>
        <script>
            let map;
            let markers = $markersJson;
            let bounds = $boundsJson;

            function initializeMap() {
                map = new atlas.Map('map', {
                    center: [bounds.centerLon, bounds.centerLat],
                    zoom: 10,
                    language: 'en-US',
                    $authConfig
                });

                map.events.add('ready', function () {
                    // Create data source for markers
                    var dataSource = new atlas.source.DataSource();
                    map.sources.add(dataSource);

                    // Add markers to data source
                    markers.forEach(function(marker, index) {
                        var point = new atlas.data.Point([marker.longitude, marker.latitude]);
                        var feature = new atlas.data.Feature(point, {
                            title: marker.title,
                            description: marker.description,
                            index: index + 1
                        });
                        dataSource.add(feature);
                    });

                    // Create symbol layer for markers
                    var symbolLayer = new atlas.layer.SymbolLayer(dataSource, null, {
                        iconOptions: {
                            image: 'pin-round-blue',
                            allowOverlap: true,
                            anchor: 'center',
                            size: 0.8
                        },
                        textOptions: {
                            textField: ['get', 'index'],
                            color: 'white',
                            offset: [0, 0],
                            size: 12
                        }
                    });
                    map.layers.add(symbolLayer);

                    // Add popup for marker details
                    var popup = new atlas.Popup();
                    map.events.add('click', symbolLayer, function (e) {
                        if (e.shapes && e.shapes.length > 0) {
                            var properties = e.shapes[0].getProperties();
                            popup.setOptions({
                                content: '<div style="padding:10px"><h4>' + properties.title + '</h4><p>' + properties.description + '</p></div>',
                                position: e.shapes[0].getCoordinates(),
                                pixelOffset: [0, -18]
                            });
                            popup.open(map);
                        }
                    });

                    // Fit map to show all markers
                    if (markers.length > 0) {
                        var coordinates = markers.map(m => [m.longitude, m.latitude]);
                        var bbox = atlas.data.BoundingBox.fromData(coordinates);
                        map.setCamera({
                            bounds: bbox,
                            padding: 50
                        });
                    }
                });
            }

            // Initialize when page loads
            window.addEventListener('load', initializeMap);

            // Handle messages from Flutter
            window.addEventListener('message', function(event) {
                var data = JSON.parse(event.data);
                if (data.type === 'updateMarkers') {
                    // Update markers logic here
                    markers = data.markers;
                    // Refresh map markers
                }
            });
        </script>
    </body>
    </html>
    ''';
  }
}

/// Azure Maps access token model
class AzureMapsToken {
  final String accessToken;
  final int expiresIn;
  final String tokenType;

  AzureMapsToken({
    required this.accessToken,
    required this.expiresIn,
    required this.tokenType,
  });

  factory AzureMapsToken.fromJson(Map<String, dynamic> json) {
    return AzureMapsToken(
      accessToken: json['accessToken'] as String,
      expiresIn: json['expiresIn'] as int,
      tokenType: json['tokenType'] as String,
    );
  }

  bool get isExpired => DateTime.now().millisecondsSinceEpoch >= 
      DateTime.now().add(Duration(seconds: expiresIn)).millisecondsSinceEpoch;
}

/// Map marker model
class MapMarker {
  final double latitude;
  final double longitude;
  final String title;
  final String description;

  MapMarker({
    required this.latitude,
    required this.longitude,
    required this.title,
    required this.description,
  });

  Map<String, dynamic> toJson() => {
    'latitude': latitude,
    'longitude': longitude,
    'title': title,
    'description': description,
  };
}

/// Map bounds model
class MapBounds {
  final double centerLat;
  final double centerLon;
  final double northLat;
  final double southLat;
  final double eastLon;
  final double westLon;

  MapBounds({
    required this.centerLat,
    required this.centerLon,
    required this.northLat,
    required this.southLat,
    required this.eastLon,
    required this.westLon,
  });

  Map<String, dynamic> toJson() => {
    'centerLat': centerLat,
    'centerLon': centerLon,
    'northLat': northLat,
    'southLat': southLat,
    'eastLon': eastLon,
    'westLon': westLon,
  };
}