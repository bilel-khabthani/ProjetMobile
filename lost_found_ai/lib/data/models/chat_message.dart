/// Message du chat securise lie a une correspondance.
class ChatMessage {
  const ChatMessage({
    required this.id,
    required this.matchId,
    required this.senderId,
    required this.senderName,
    required this.body,
    required this.createdAt,
    this.readAt,
    this.reportedAt,
    this.reportReason,
  });

  final String id;
  final String matchId;
  final int senderId;
  final String senderName;
  final String body;
  final DateTime createdAt;
  final DateTime? readAt;
  final DateTime? reportedAt;
  final String? reportReason;

  bool get isReported => reportedAt != null;

  factory ChatMessage.fromJson(Map<String, dynamic> json) {
    final sender = json['sender'] as Map<String, dynamic>?;

    return ChatMessage(
      id: json['id']?.toString() ?? '',
      matchId: json['match_id']?.toString() ?? '',
      senderId: (json['sender_id'] as num?)?.toInt() ??
          (sender?['id'] as num?)?.toInt() ??
          0,
      senderName: sender?['name'] as String? ?? 'Membre',
      body: json['body'] as String? ?? '',
      createdAt: DateTime.tryParse(json['created_at']?.toString() ?? '') ??
          DateTime.now(),
      readAt: DateTime.tryParse(json['read_at']?.toString() ?? ''),
      reportedAt: DateTime.tryParse(json['reported_at']?.toString() ?? ''),
      reportReason: json['report_reason'] as String?,
    );
  }
}
