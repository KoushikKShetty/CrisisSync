/// WebSocket broadcast service — replaces Socket.IO
/// Clients connect to ws://host:8080/ws
library;

import 'dart:convert';
import 'package:web_socket_channel/web_socket_channel.dart';

// ── Connected client registry ──────────────────────────────────────
final List<WebSocketChannel> _clients = [];

void registerClient(WebSocketChannel channel) {
  _clients.add(channel);
  channel.stream.listen(
    (_) {}, // ignore incoming from clients for now
    onDone: () => _clients.remove(channel),
    onError: (_) => _clients.remove(channel),
    cancelOnError: true,
  );
}

// ── Broadcast to all connected clients ────────────────────────────
void broadcast(String event, Map<String, dynamic> data) {
  final payload = jsonEncode({'event': event, ...data});
  final dead = <WebSocketChannel>[];
  for (final client in _clients) {
    try {
      client.sink.add(payload);
    } catch (_) {
      dead.add(client);
    }
  }
  for (final c in dead) {
    _clients.remove(c);
  }
}

int get connectedClients => _clients.length;
