import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:web_socket_channel/web_socket_channel.dart';

import '../core/app_config.dart';
import 'models/chat_message.dart';

/// Client WebSocket minimal parlant le protocole Pusher utilise par Reverb.
///
/// Le canal est prive : l'abonnement est autorise par l'endpoint Laravel
/// `/broadcasting/auth` avec le jeton Sanctum de l'utilisateur.
class ChatSocket {
  ChatSocket({
    required this.matchId,
    required this.token,
    required this.currentUserId,
    required this.onMessage,
    this.onMessagesRead,
    this.onStateChanged,
  });

  final String matchId;
  final String? token;
  final int? currentUserId;
  final void Function(ChatMessage message) onMessage;
  final void Function(Set<String> messageIds, DateTime readAt)? onMessagesRead;
  final void Function(bool connected)? onStateChanged;

  WebSocketChannel? _channel;
  StreamSubscription<dynamic>? _subscription;
  Timer? _reconnectTimer;
  Timer? _pingTimer;
  String? _socketId;
  bool _connected = false;
  bool _disposed = false;
  int _reconnectAttempts = 0;

  bool get isConnected => _connected;

  String get _channelName => 'private-match.$matchId';

  Future<void> connect() async {
    if (_disposed || token == null || token!.isEmpty) {
      return;
    }

    await _closeChannel();

    final uri = Uri(
      scheme: AppConfig.reverbScheme == 'https' ? 'wss' : 'ws',
      host: AppConfig.reverbHost,
      port: AppConfig.reverbPort,
      path: '/app/${AppConfig.reverbAppKey}',
      queryParameters: const {
        'protocol': '7',
        'client': 'flutter',
        'version': '1.0',
      },
    );

    try {
      final channel = WebSocketChannel.connect(uri);
      _channel = channel;
      _subscription = channel.stream.listen(
        _handleFrame,
        onError: (_) => _scheduleReconnect(),
        onDone: _scheduleReconnect,
        cancelOnError: true,
      );
    } catch (_) {
      _scheduleReconnect();
    }
  }

  void _handleFrame(dynamic raw) {
    if (_disposed) return;

    Object? decoded;
    try {
      decoded = jsonDecode(raw as String);
    } catch (_) {
      return;
    }
    if (decoded is! Map<String, dynamic>) return;

    final event = decoded['event'] as String?;
    final data = decoded['data'];

    switch (event) {
      case 'pusher:connection_established':
        final payload = _decodeData(data);
        _socketId = payload['socket_id'] as String?;
        unawaited(_subscribe());
      case 'pusher_internal:subscription_succeeded':
        _connected = true;
        _reconnectAttempts = 0;
        onStateChanged?.call(true);
        _startPing();
      case 'pusher:ping':
        _send({'event': 'pusher:pong', 'data': {}});
      case 'message.sent':
        final payload = _decodeData(data);
        onMessage(ChatMessage.fromJson(payload, currentUserId: currentUserId));
      case 'message.read':
        final payload = _decodeData(data);
        final ids = (payload['message_ids'] as List<dynamic>? ?? const [])
            .whereType<String>()
            .toSet();
        final readAt = DateTime.tryParse(payload['read_at'] as String? ?? '');
        if (ids.isNotEmpty && readAt != null) {
          onMessagesRead?.call(ids, readAt);
        }
      case 'pusher:error':
        _scheduleReconnect();
    }
  }

  Future<void> _subscribe() async {
    final socketId = _socketId;
    if (socketId == null) return;

    final auth = await _authorize(socketId);
    if (auth == null) {
      _scheduleReconnect();
      return;
    }

    _send({
      'event': 'pusher:subscribe',
      'data': {'auth': auth, 'channel': _channelName},
    });
  }

  Future<String?> _authorize(String socketId) async {
    try {
      final response = await http
          .post(
            Uri.parse('${AppConfig.apiOrigin}/broadcasting/auth'),
            headers: {
              'Accept': 'application/json',
              'Authorization': 'Bearer $token',
            },
            body: {'socket_id': socketId, 'channel_name': _channelName},
          )
          .timeout(const Duration(seconds: 10));

      if (response.statusCode != 200) return null;

      final json = jsonDecode(response.body) as Map<String, dynamic>;
      return json['auth'] as String?;
    } catch (_) {
      return null;
    }
  }

  void _send(Map<String, dynamic> payload) {
    _channel?.sink.add(jsonEncode(payload));
  }

  Map<String, dynamic> _decodeData(dynamic data) {
    if (data is Map<String, dynamic>) return data;
    if (data is String) {
      final decoded = jsonDecode(data);
      if (decoded is Map<String, dynamic>) return decoded;
    }
    return const {};
  }

  void _startPing() {
    _pingTimer?.cancel();
    _pingTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      _send({'event': 'pusher:ping', 'data': {}});
    });
  }

  void _scheduleReconnect() {
    if (_disposed) return;

    _connected = false;
    onStateChanged?.call(false);
    _reconnectTimer?.cancel();

    // Retente vite au debut, puis espace progressivement (plafond 30 s) pour
    // ne pas marteler Reverb quand le serveur est arrete.
    final index = _reconnectAttempts < 4 ? _reconnectAttempts : 3;
    final delaySeconds = const <int>[4, 8, 15, 30][index];
    _reconnectAttempts = index >= 3 ? 3 : index + 1;
    _reconnectTimer = Timer(Duration(seconds: delaySeconds), () {
      if (!_disposed) connect();
    });
  }

  Future<void> _closeChannel() async {
    _pingTimer?.cancel();
    _pingTimer = null;
    try {
      await _subscription?.cancel();
    } catch (_) {
      // Le flux peut deja etre ferme apres une erreur reseau.
    }
    _subscription = null;
    try {
      await _channel?.sink.close();
    } catch (_) {
      // Idem : fermer un socket deja casse ne doit pas faire echouer dispose.
    }
    _channel = null;
  }

  Future<void> dispose() async {
    _disposed = true;
    _reconnectTimer?.cancel();
    await _closeChannel();
  }
}
