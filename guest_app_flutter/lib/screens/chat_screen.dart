import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'expired_screen.dart';

enum _MsgType { ai, guest, system, emergency }

class _Message {
  final String text;
  final _MsgType type;
  final DateTime time;
  _Message({required this.text, required this.type})
      : time = DateTime.now();
}

class ChatScreen extends StatefulWidget {
  final String sessionToken;
  final String zoneName;
  final String zoneId;
  final String locationStatus;
  final String backendUrl;

  const ChatScreen({
    super.key,
    required this.sessionToken,
    required this.zoneName,
    required this.zoneId,
    required this.locationStatus,
    required this.backendUrl,
  });

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final List<_Message> _messages = [];
  final TextEditingController _input = TextEditingController();
  final ScrollController _scroll = ScrollController();
  bool _sending = false;
  bool _expired = false;

  // 15-minute countdown
  static const int _sessionSecs = 15 * 60;
  int _secsLeft = _sessionSecs;
  Timer? _timer;

  @override
  void initState() {
    super.initState();

    // Initial greeting
    _addMsg(
        'Hello! I\'m the AI assistant for ${widget.zoneName}.\n\n'
        'You can ask me any question or report an emergency. How can I help you today?',
        _MsgType.ai);
    _addMsg('Session started for ${widget.zoneName}', _MsgType.system);
    _addMsg(_locationMsg(), _MsgType.system);

    // Start countdown
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) {
        t.cancel();
        return;
      }
      setState(() => _secsLeft--);
      if (_secsLeft <= 0) {
        t.cancel();
        setState(() => _expired = true);
        Future.delayed(const Duration(seconds: 1), () {
          if (mounted) {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(builder: (_) => const ExpiredScreen()),
            );
          }
        });
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _input.dispose();
    _scroll.dispose();
    super.dispose();
  }

  String _locationMsg() {
    switch (widget.locationStatus) {
      case 'verified':
        return '📍 Location verified — you are inside the property';
      case 'outside':
        return '⚠️ You appear to be outside the property. Session continues with reduced trust.';
      case 'denied':
        return '📍 Location not shared. Session continues.';
      default:
        return '📍 GPS unavailable. Session continues.';
    }
  }

  void _addMsg(String text, _MsgType type) {
    setState(() {
      _messages.add(_Message(text: text, type: type));
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scroll.hasClients) {
        _scroll.animateTo(
          _scroll.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _sendMessage(String msg) async {
    if (msg.trim().isEmpty || _sending || _expired) return;
    _input.clear();
    _addMsg(msg, _MsgType.guest);
    setState(() => _sending = true);

    // Show typing indicator
    final typingIdx = _messages.length;
    _addMsg('Processing...', _MsgType.system);

    try {
      final res = await http.post(
        Uri.parse('${widget.backendUrl}/guest/message'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'sessionToken': widget.sessionToken,
          'message': msg,
        }),
      );

      final data = jsonDecode(res.body) as Map<String, dynamic>;

      // Remove typing indicator
      setState(() {
        if (typingIdx < _messages.length) _messages.removeAt(typingIdx);
        _sending = false;
      });

      if (data['error'] != null) {
        final errCode = data['error'] as String;
        if (errCode == 'SESSION_EXPIRED') {
          setState(() => _expired = true);
          _addMsg('Your session has expired. Please re-scan the QR code.',
              _MsgType.system);
        } else if (errCode == 'RATE_LIMITED') {
          _addMsg(
              '⚠️ Too many messages. Please wait a moment.', _MsgType.system);
        } else {
          _addMsg(data['message'] as String? ?? 'An error occurred.',
              _MsgType.system);
        }
      } else {
        final classification = data['classification'] as String? ?? 'info';
        final aiReply = data['aiReply'] as String? ?? '';
        final type =
            classification == 'critical' ? _MsgType.emergency : _MsgType.ai;
        _addMsg(aiReply, type);
      }
    } catch (_) {
      setState(() {
        if (typingIdx < _messages.length) _messages.removeAt(typingIdx);
        _sending = false;
      });
      _addMsg('Connection error. Please try again or find a staff member.',
          _MsgType.system);
    }
  }

  void _sendSOS() {
    _sendMessage('🚨 EMERGENCY! I need immediate help!');
  }

  String get _timerStr {
    final m = (_secsLeft ~/ 60).toString().padLeft(2, '0');
    final s = (_secsLeft % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0B1120),
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(),
            _buildTimerBar(),
            Expanded(child: _buildMessages()),
            if (!_expired) _buildInput(),
            if (_expired)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                color: const Color(0xFF7F1D1D),
                child: const Text(
                  '⏰ Session expired — please re-scan the QR code',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF0E7490), Color(0xFF0891B2)],
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
        ),
      ),
      child: Row(
        children: [
          const Text(
            '⚡ CrisisSync',
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w900,
              fontSize: 20,
              letterSpacing: 1,
            ),
          ),
          const Spacer(),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(children: [
              const Icon(Icons.location_on, color: Colors.white, size: 12),
              const SizedBox(width: 5),
              Text(
                widget.zoneName,
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w600),
              ),
            ]),
          ),
        ],
      ),
    );
  }

  Widget _buildTimerBar() {
    final isLow = _secsLeft < 60;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      color: const Color(0xFF1A2332),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: isLow ? const Color(0xFFEF4444) : const Color(0xFF22C55E),
            ),
          ),
          const SizedBox(width: 8),
          Text(
            'Secure session • Expires in $_timerStr',
            style: TextStyle(
              color: isLow ? const Color(0xFFEF4444) : const Color(0xFF94A3B8),
              fontSize: 12,
              fontWeight: isLow ? FontWeight.bold : FontWeight.normal,
            ),
          ),
          if (widget.locationStatus == 'verified') ...[
            const SizedBox(width: 12),
            const Text('📍 Verified',
                style:
                    TextStyle(color: Color(0xFF22C55E), fontSize: 11)),
          ],
        ],
      ),
    );
  }

  Widget _buildMessages() {
    return ListView.builder(
      controller: _scroll,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      itemCount: _messages.length,
      itemBuilder: (_, i) => _buildBubble(_messages[i]),
    );
  }

  Widget _buildBubble(_Message msg) {
    switch (msg.type) {
      case _MsgType.system:
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 5),
          child: Center(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
              decoration: BoxDecoration(
                color: const Color(0xFF1A2332),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: const Color(0xFF2A3548)),
              ),
              child: Text(msg.text,
                  style: const TextStyle(
                      color: Color(0xFF64748B), fontSize: 11)),
            ),
          ),
        );

      case _MsgType.guest:
        return Align(
          alignment: Alignment.centerRight,
          child: Container(
            margin: const EdgeInsets.symmetric(vertical: 5),
            padding: const EdgeInsets.all(14),
            constraints:
                const BoxConstraints(maxWidth: 300),
            decoration: BoxDecoration(
              color: const Color(0xFF0E7490),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(16),
                topRight: Radius.circular(4),
                bottomLeft: Radius.circular(16),
                bottomRight: Radius.circular(16),
              ),
            ),
            child: Text(msg.text,
                style: const TextStyle(color: Colors.white, fontSize: 14)),
          ),
        );

      case _MsgType.emergency:
        return Align(
          alignment: Alignment.centerLeft,
          child: Container(
            margin: const EdgeInsets.symmetric(vertical: 5),
            padding: const EdgeInsets.all(14),
            constraints: const BoxConstraints(maxWidth: 320),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF991B1B), Color(0xFF7F1D1D)],
              ),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(4),
                topRight: Radius.circular(16),
                bottomLeft: Radius.circular(16),
                bottomRight: Radius.circular(16),
              ),
              border: Border.all(
                  color: const Color(0xFFEF4444).withValues(alpha: 0.4)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('🚨 EMERGENCY RESPONSE',
                    style: TextStyle(
                        color: Color(0xFFFCA5A5),
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1)),
                const SizedBox(height: 6),
                Text(msg.text,
                    style: const TextStyle(
                        color: Colors.white, fontSize: 14, height: 1.4)),
              ],
            ),
          ),
        );

      case _MsgType.ai:
        return Align(
          alignment: Alignment.centerLeft,
          child: Container(
            margin: const EdgeInsets.symmetric(vertical: 5),
            padding: const EdgeInsets.all(14),
            constraints: const BoxConstraints(maxWidth: 320),
            decoration: BoxDecoration(
              color: const Color(0xFF1A2332),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(4),
                topRight: Radius.circular(16),
                bottomLeft: Radius.circular(16),
                bottomRight: Radius.circular(16),
              ),
              border: Border.all(
                  color: const Color(0xFF22D3EE).withValues(alpha: 0.2)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('✦ CrisisSync AI',
                    style: TextStyle(
                        color: Color(0xFF22D3EE),
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1)),
                const SizedBox(height: 6),
                Text(msg.text,
                    style: const TextStyle(
                        color: Color(0xFFF1F5F9),
                        fontSize: 14,
                        height: 1.4)),
              ],
            ),
          ),
        );
    }
  }

  Widget _buildInput() {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 10, 14, 20),
      decoration: const BoxDecoration(
        color: Color(0xFF111827),
        border: Border(top: BorderSide(color: Color(0xFF2A3548))),
      ),
      child: Column(
        children: [
          // SOS Button
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _expired ? null : _sendSOS,
              icon: const Icon(Icons.warning_amber, size: 18),
              label: const Text(
                '🚨  EMERGENCY — TAP HERE',
                style: TextStyle(
                    fontWeight: FontWeight.w900,
                    fontSize: 14,
                    letterSpacing: 1),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFEF4444),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
                elevation: 0,
              ),
            ),
          ),
          const SizedBox(height: 10),
          // Message input
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _input,
                  maxLines: 3,
                  minLines: 1,
                  onSubmitted: (v) => _sendMessage(v),
                  style: const TextStyle(
                      color: Color(0xFFF1F5F9), fontSize: 14),
                  decoration: InputDecoration(
                    hintText: 'Type your message or question...',
                    hintStyle:
                        const TextStyle(color: Color(0xFF4B5563)),
                    filled: true,
                    fillColor: const Color(0xFF1A2332),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(
                          color: Color(0xFF2A3548)),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(
                          color: Color(0xFF2A3548)),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(
                          color: Color(0xFF22D3EE)),
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 12),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              GestureDetector(
                onTap: _sending || _expired
                    ? null
                    : () => _sendMessage(_input.text),
                child: Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    gradient: _sending || _expired
                        ? null
                        : const LinearGradient(
                            colors: [
                              Color(0xFF0891B2),
                              Color(0xFF0E7490)
                            ],
                          ),
                    color: _sending || _expired
                        ? const Color(0xFF1A2332)
                        : null,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: _sending
                      ? const Center(
                          child: SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              color: Color(0xFF22D3EE),
                              strokeWidth: 2,
                            ),
                          ),
                        )
                      : const Icon(Icons.send,
                          color: Colors.white, size: 20),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
