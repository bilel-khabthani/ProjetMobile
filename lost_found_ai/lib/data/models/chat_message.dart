/// Message du chat securise, tel que renvoye par l'API Laravel.
class ChatMessage {
  const ChatMessage({
    required this.id,
    required this.matchId,
    required this.body,
    required this.status,
    required this.createdAt,
    required this.isMine,
    required this.senderId,
    required this.senderName,
    required this.senderInitials,
    this.readAt,
  });

  factory ChatMessage.fromJson(
    Map<String, dynamic> json, {
    int? currentUserId,
  }) {
    final sender = json['sender'] as Map<String, dynamic>? ?? const {};
    final senderId = (sender['id'] as num?)?.toInt();
    final explicitMine = json['is_mine'] as bool?;

    return ChatMessage(
      id: json['id'] as String? ?? '',
      matchId: json['match_id'] as String? ?? '',
      body: json['body'] as String? ?? '',
      status: json['status'] as String? ?? 'APPROVED',
      createdAt:
          DateTime.tryParse(json['created_at'] as String? ?? '') ??
          DateTime.now(),
      readAt: DateTime.tryParse(json['read_at'] as String? ?? ''),
      isMine:
          explicitMine ?? (currentUserId != null && senderId == currentUserId),
      senderId: senderId,
      senderName: sender['name'] as String? ?? 'Utilisateur',
      senderInitials: sender['initials'] as String? ?? 'LF',
    );
  }

  final String id;
  final String matchId;
  final String body;
  final String status;
  final DateTime createdAt;
  final DateTime? readAt;
  final bool isMine;
  final int? senderId;
  final String senderName;
  final String senderInitials;

  ChatMessage copyWith({DateTime? readAt}) {
    return ChatMessage(
      id: id,
      matchId: matchId,
      body: body,
      status: status,
      createdAt: createdAt,
      readAt: readAt ?? this.readAt,
      isMine: isMine,
      senderId: senderId,
      senderName: senderName,
      senderInitials: senderInitials,
    );
  }
}
