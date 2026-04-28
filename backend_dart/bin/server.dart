/// CrisisSync Dart Backend — main server entry point
/// Runs on http://localhost:8080
library;

import 'dart:io';
import 'dart:convert';
import 'package:shelf/shelf.dart';
import 'package:shelf/shelf_io.dart' as io;
import 'package:shelf_router/shelf_router.dart';
import 'package:shelf_web_socket/shelf_web_socket.dart';
import 'package:shelf_cors_headers/shelf_cors_headers.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

import 'package:backend_dart/config.dart';
import 'package:backend_dart/firebase_service.dart';
import 'package:backend_dart/gemini_service.dart';
import 'package:backend_dart/websocket_service.dart';
import 'package:backend_dart/handlers/auth_handler.dart';
import 'package:backend_dart/handlers/incidents_handler.dart';
import 'package:backend_dart/handlers/guest_handler.dart';
import 'package:backend_dart/handlers/mock_handler.dart';

void main() async {
  // ── 1. Load config ──────────────────────────────────────────────
  loadEnv();

  // ── 2. Init Firebase ────────────────────────────────────────────
  initFirebase();

  // ── 3. Init Gemini ──────────────────────────────────────────────
  initGemini();

  // ── 4. Build router ─────────────────────────────────────────────
  final app = Router();

  // Health check
  app.get('/health', (Request req) => Response.ok(
        jsonEncode({
          'status': 'ok',
          'timestamp': DateTime.now().toIso8601String(),
          'engine': 'Dart shelf',
          'wsClients': connectedClients,
        }),
        headers: {'Content-Type': 'application/json'},
      ));

  // Sub-routers
  app.mount('/auth/', buildAuthRouter().call);
  app.mount('/incidents/', buildIncidentsRouter().call);
  app.mount('/guest/', buildGuestRouter().call);
  app.mount('/mock/', buildMockRouter().call);

  // ── WebSocket endpoint (ws://host:8080/ws) ──────────────────────
  final wsHandler = webSocketHandler(
    (WebSocketChannel channel, String? protocol) {
      registerClient(channel);
      print('🔌 WS client connected (total: $connectedClients)');
    },
  );
  app.get('/ws', wsHandler);

  // ── 5. Add middleware ───────────────────────────────────────────
  final handler = Pipeline()
      .addMiddleware(corsHeaders())
      .addMiddleware(logRequests())
      .addHandler(app.call);

  // ── 6. Start server ─────────────────────────────────────────────
  final port = int.tryParse(Platform.environment['PORT'] ?? '8080') ?? 8080;
  final server =
      await io.serve(handler, InternetAddress.anyIPv4, port);

  print('🚀 CrisisSync Dart Backend running on http://0.0.0.0:${server.port}');
  print('   Health: http://localhost:${server.port}/health');
  print('   WebSocket: ws://localhost:${server.port}/ws');
}
