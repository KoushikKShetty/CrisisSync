import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:http/http.dart' as http;
import 'package:web_socket_channel/web_socket_channel.dart';
import '../theme/app_theme.dart';

class ChatScreen extends StatefulWidget {
  const ChatScreen({super.key});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen>
    with SingleTickerProviderStateMixin {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  WebSocketChannel? _channel;
  bool _isLive = false;
  late AnimationController _pulseController;

  String _activeIncidentId = '';
  String _activeIncidentTitle = 'No active incident';
  bool _hasIncident = false;

  final List<Map<String, dynamic>> _messages = [];

  static const String _baseUrl = 'http://localhost:8080';
  static const String _wsUrl = 'ws://localhost:8080/ws';

  // Simulated staff identity for demo
  static const String _myAvatar = 'AR';
  static const String _myName = 'Alex Rivera';

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);
    _connectWs();
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _messageController.dispose();
    _scrollController.dispose();
    _channel?.sink.close();
    super.dispose();
  }

  // ── WebSocket ────────────────────────────────────────────────────

  void _connectWs() {
    try {
      _channel = WebSocketChannel.connect(Uri.parse(_wsUrl));
      if (mounted) setState(() => _isLive = true);

      _channel!.stream.listen(
        (raw) {
          if (!mounted) return;
          try {
            final data = jsonDecode(raw as String) as Map<String, dynamic>;
            _handleEvent(data['event'] as String? ?? '', data);
          } catch (_) {}
        },
        onError: (_) {
          if (mounted) setState(() => _isLive = false);
        },
        onDone: () {
          if (mounted) setState(() => _isLive = false);
          Future.delayed(const Duration(seconds: 3), () {
            if (mounted) _connectWs();
          });
        },
        cancelOnError: true,
      );
    } catch (_) {
      if (mounted) setState(() => _isLive = false);
    }
  }

  void _handleEvent(String event, Map<String, dynamic> data) {
    setState(() {
      if (event == 'hardware_alert' || event == 'zone_alert') {
        _hasIncident = true;
        _activeIncidentId = data['incidentId'] as String? ?? '';
        _activeIncidentTitle =
            data['title'] as String? ?? 'Active Incident';
        // Inject a system message
        _messages.insert(0, {
          'type': 'system',
          'message':
              '🚨 INCIDENT CHANNEL OPENED — ${data['zone'] ?? 'Unknown Zone'}',
          'time': DateTime.now().millisecondsSinceEpoch,
        });
      } else if (event == 'staff_message') {
        _messages.add({
          'type': data['sender'] == _myName ? 'me' : 'other',
          'sender': data['sender'] ?? 'Staff',
          'avatar': data['avatar'] ?? '??',
          'message': data['message'] ?? '',
          'time': data['time'] ?? DateTime.now().millisecondsSinceEpoch,
        });
        _scrollToBottom();
      } else if (event == 'responders_dispatched') {
        _messages.add({
          'type': 'system',
          'message':
              '🚨 First responders dispatched — ETA ${data['eta'] ?? '?'}',
          'time': DateTime.now().millisecondsSinceEpoch,
        });
        _scrollToBottom();
      }
    });
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _sendMessage() async {
    final text = _messageController.text.trim();
    if (text.isEmpty) return;
    _messageController.clear();

    try {
      await http.post(
        Uri.parse('$_baseUrl/incidents/staff-broadcast'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'sender': _myName,
          'avatar': _myAvatar,
          'message': text,
          'incidentId': _activeIncidentId,
        }),
      );
    } catch (_) {
      // Offline — show locally anyway
      setState(() {
        _messages.add({
          'type': 'me',
          'sender': _myName,
          'avatar': _myAvatar,
          'message': text,
          'time': DateTime.now().millisecondsSinceEpoch,
        });
      });
      _scrollToBottom();
    }
  }

  Future<void> _escalate() async {
    if (_activeIncidentId.isEmpty) return;
    try {
      await http.post(
          Uri.parse('$_baseUrl/incidents/$_activeIncidentId/escalate'));
      setState(() {
        _messages.add({
          'type': 'system',
          'message': '⬆️ Incident escalated to supervisor by $_myName',
          'time': DateTime.now().millisecondsSinceEpoch,
        });
      });
      _scrollToBottom();
    } catch (_) {}
  }

  // ── Build ────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.bgPrimary,
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(),
            if (_messages.isEmpty) _buildIdleState() else _buildMessages(),
            if (_hasIncident) _buildEscalateBar(),
            _buildInputArea(),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: _hasIncident ? AppTheme.criticalRedBg : AppTheme.bgSecondary,
        border: Border(
          bottom: BorderSide(
            color: _hasIncident
                ? AppTheme.criticalRed.withValues(alpha: 0.3)
                : AppTheme.borderDefault,
          ),
        ),
      ),
      child: Row(
        children: [
          AnimatedBuilder(
            animation: _pulseController,
            builder: (_, __) => Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: _isLive
                    ? (_hasIncident ? AppTheme.criticalRed : AppTheme.successGreen)
                    : AppTheme.textMuted,
                boxShadow: _isLive
                    ? [
                        BoxShadow(
                          color: (_hasIncident
                                  ? AppTheme.criticalRed
                                  : AppTheme.successGreen)
                              .withValues(alpha: _pulseController.value * 0.6),
                          blurRadius: 8,
                          spreadRadius: 2,
                        )
                      ]
                    : null,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _hasIncident ? 'ACTIVE INCIDENT CHANNEL' : 'STAFF COMMS',
                  style: TextStyle(
                      color: _hasIncident
                          ? AppTheme.criticalRed
                          : AppTheme.accentCyan,
                      fontWeight: FontWeight.bold,
                      fontSize: 11,
                      letterSpacing: 1.5),
                ),
                const SizedBox(height: 2),
                Text(
                  _activeIncidentTitle,
                  style: const TextStyle(
                      color: AppTheme.textPrimary, fontSize: 13),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: (_isLive ? AppTheme.successGreen : AppTheme.textMuted)
                  .withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(AppTheme.radiusPill),
            ),
            child: Text(
              _isLive ? 'LIVE' : 'OFFLINE',
              style: TextStyle(
                color: _isLive ? AppTheme.successGreen : AppTheme.textMuted,
                fontSize: 10,
                fontWeight: FontWeight.bold,
                letterSpacing: 1,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildIdleState() {
    return Expanded(
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                color: AppTheme.accentCyan.withValues(alpha: 0.08),
                shape: BoxShape.circle,
              ),
              child: const Icon(LucideIcons.radio,
                  color: AppTheme.accentCyan, size: 36),
            ),
            const SizedBox(height: 20),
            const Text('Incident Channel Ready',
                style: TextStyle(
                    color: AppTheme.textPrimary,
                    fontSize: 18,
                    fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            const Text(
              'Messages appear here when an incident\nis detected by CrisisSync.',
              textAlign: TextAlign.center,
              style: TextStyle(
                  color: AppTheme.textMuted, fontSize: 13, height: 1.5),
            ),
            const SizedBox(height: 24),
            const Text('Or type a message below to broadcast to all staff.',
                style: TextStyle(color: AppTheme.textMuted, fontSize: 12)),
          ],
        ),
      ),
    );
  }

  Widget _buildMessages() {
    return Expanded(
      child: ListView.builder(
        controller: _scrollController,
        padding: const EdgeInsets.all(16),
        itemCount: _messages.length,
        itemBuilder: (_, i) => _buildMessage(_messages[i]),
      ),
    );
  }

  Widget _buildMessage(Map<String, dynamic> msg) {
    switch (msg['type']) {
      case 'system':
        return _buildSystemMsg(msg);
      case 'ai':
        return _buildAiMsg(msg);
      case 'me':
        return _buildUserMsg(msg, isMe: true);
      default:
        return _buildUserMsg(msg, isMe: false);
    }
  }

  Widget _buildSystemMsg(Map<String, dynamic> msg) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Center(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
          decoration: BoxDecoration(
            color: AppTheme.bgSurface,
            borderRadius: BorderRadius.circular(AppTheme.radiusPill),
            border: Border.all(color: AppTheme.borderDefault),
          ),
          child: Text(msg['message'],
              style: const TextStyle(
                  color: AppTheme.textMuted,
                  fontSize: 11,
                  fontWeight: FontWeight.w500)),
        ),
      ),
    );
  }

  Widget _buildAiMsg(Map<String, dynamic> msg) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              gradient: AppTheme.cyanGradient,
              borderRadius: BorderRadius.circular(10),
            ),
            alignment: Alignment.center,
            child: const Text('✦',
                style: TextStyle(fontSize: 16, color: AppTheme.white)),
          ),
          const SizedBox(width: 10),
          Flexible(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Gemma AI',
                    style: TextStyle(
                        color: AppTheme.accentCyan,
                        fontWeight: FontWeight.bold,
                        fontSize: 12)),
                const SizedBox(height: 6),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppTheme.accentCyanBg,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                        color: AppTheme.accentCyan.withValues(alpha: 0.2)),
                  ),
                  child: Text(msg['message'],
                      style: const TextStyle(
                          color: AppTheme.textPrimary,
                          fontSize: 13,
                          height: 1.5)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildUserMsg(Map<String, dynamic> msg, {required bool isMe}) {
    final avatarColor = isMe ? AppTheme.accentCyan : AppTheme.warningAmber;
    final avatar = msg['avatar'] as String? ?? '??';
    final sender = msg['sender'] as String? ?? 'Staff';

    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment:
            isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
        children: [
          if (!isMe) ...[
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: avatarColor.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: avatarColor.withValues(alpha: 0.3)),
              ),
              alignment: Alignment.center,
              child: Text(avatar,
                  style: TextStyle(
                      color: avatarColor,
                      fontWeight: FontWeight.bold,
                      fontSize: 12)),
            ),
            const SizedBox(width: 10),
          ],
          Flexible(
            child: Column(
              crossAxisAlignment:
                  isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
              children: [
                Text(sender,
                    style: TextStyle(
                        color:
                            isMe ? AppTheme.accentCyan : AppTheme.textPrimary,
                        fontWeight: FontWeight.bold,
                        fontSize: 12)),
                const SizedBox(height: 6),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: isMe ? AppTheme.accentCyanBg : AppTheme.bgCard,
                    borderRadius: BorderRadius.circular(12).copyWith(
                      topLeft: isMe ? null : const Radius.circular(4),
                      topRight: isMe ? const Radius.circular(4) : null,
                    ),
                    border: Border.all(
                      color: isMe
                          ? AppTheme.accentCyan.withValues(alpha: 0.2)
                          : AppTheme.borderDefault,
                    ),
                  ),
                  child: Text(msg['message'],
                      style: const TextStyle(
                          color: AppTheme.textPrimary,
                          fontSize: 13,
                          height: 1.5)),
                ),
              ],
            ),
          ),
          if (isMe) ...[
            const SizedBox(width: 10),
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: AppTheme.accentCyan.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                    color: AppTheme.accentCyan.withValues(alpha: 0.3)),
              ),
              alignment: Alignment.center,
              child: Text(avatar,
                  style: const TextStyle(
                      color: AppTheme.accentCyan,
                      fontWeight: FontWeight.bold,
                      fontSize: 12)),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildEscalateBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: ElevatedButton.icon(
        onPressed: _escalate,
        icon: const Icon(LucideIcons.alertTriangle,
            color: AppTheme.white, size: 16),
        label: const Text('ESCALATE TO SUPERVISOR',
            style: TextStyle(
                color: AppTheme.white,
                fontWeight: FontWeight.bold,
                fontSize: 12,
                letterSpacing: 1)),
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF991B1B),
          minimumSize: const Size.fromHeight(44),
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppTheme.radiusButton)),
          elevation: 0,
        ),
      ),
    );
  }

  Widget _buildInputArea() {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 20),
      decoration: const BoxDecoration(
        color: AppTheme.bgSecondary,
        border: Border(top: BorderSide(color: AppTheme.borderDefault)),
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _messageController,
              style: const TextStyle(color: AppTheme.textPrimary, fontSize: 14),
              onSubmitted: (_) => _sendMessage(),
              decoration: InputDecoration(
                hintText: _hasIncident
                    ? 'Broadcast to all responders...'
                    : 'Broadcast to all staff...',
                hintStyle: const TextStyle(color: AppTheme.textMuted),
                filled: true,
                fillColor: AppTheme.bgCard,
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(AppTheme.radiusPill),
                  borderSide: const BorderSide(color: AppTheme.borderDefault),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(AppTheme.radiusPill),
                  borderSide: const BorderSide(color: AppTheme.borderDefault),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(AppTheme.radiusPill),
                  borderSide: const BorderSide(color: AppTheme.accentCyan),
                ),
              ),
            ),
          ),
          const SizedBox(width: 10),
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              gradient: AppTheme.cyanGradient,
              borderRadius: BorderRadius.circular(12),
            ),
            child: IconButton(
              icon: const Icon(LucideIcons.send,
                  color: AppTheme.white, size: 18),
              onPressed: _sendMessage,
            ),
          ),
        ],
      ),
    );
  }
}
