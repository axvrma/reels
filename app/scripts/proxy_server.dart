import 'package:shelf/shelf.dart';
import 'package:shelf/shelf_io.dart' as shelf_io;
import 'package:shelf_proxy/shelf_proxy.dart';

Future<void> main() async {
  // The URL of your actual backend API
  final backendUrl = 'http://localhost:3000';
  
  // Create a shelf handler that proxies requests to the backend
  final proxy = proxyHandler(backendUrl);

  // Enable CORS on the proxy server
  final handler = const Pipeline()
      .addMiddleware(corsHeaders())
      .addHandler(proxy);

  // Serve the proxy on localhost:8080
  final server = await shelf_io.serve(handler, 'localhost', 8080);
  
  print('Proxying from http://${server.address.host}:${server.port} to $backendUrl');
}

Middleware corsHeaders() {
  return (Handler innerHandler) {
    return (Request request) async {
      if (request.method == 'OPTIONS') {
        return Response.ok('', headers: {
          'Access-Control-Allow-Origin': '*',
          'Access-Control-Allow-Methods': 'GET, POST, PUT, DELETE, OPTIONS',
          'Access-Control-Allow-Headers': 'Origin, Content-Type, Accept, Authorization, Range',
          'Access-Control-Expose-Headers': 'Content-Length, Content-Range, Accept-Ranges',
        });
      }
      
      final response = await innerHandler(request);
      
      // Strip CORP and COOP headers from the backend response which block cross-origin video playback
      final filteredHeaders = <String, String>{};
      for (final entry in response.headers.entries) {
        final keyLower = entry.key.toLowerCase();
        if (keyLower != 'cross-origin-resource-policy' && keyLower != 'cross-origin-opener-policy') {
          filteredHeaders[entry.key] = entry.value;
        }
      }
      
      // Merge with our permissive CORS headers
      final newHeaders = {
        ...filteredHeaders,
        'Access-Control-Allow-Origin': '*',
        'Access-Control-Allow-Methods': 'GET, POST, PUT, DELETE, OPTIONS',
        'Access-Control-Allow-Headers': 'Origin, Content-Type, Accept, Authorization, Range',
        'Access-Control-Expose-Headers': 'Content-Length, Content-Range, Accept-Ranges',
      };
      
      return Response(
        response.statusCode,
        body: response.read(),
        headers: newHeaders,
        context: response.context,
      );
    };
  };
}
