import 'package:flutter_test/flutter_test.dart';
import 'package:lost_found_ai/data/models/chat_message.dart';

void main() {
  test('fromJson marks the message as mine when the sender matches', () {
    final message = ChatMessage.fromJson({
      'id': 'msg-1',
      'match_id': 'match-1',
      'body': 'Bonjour',
      'status': 'APPROVED',
      'created_at': '2026-11-04T10:00:00+00:00',
      'read_at': null,
      'sender': {'id': 7, 'name': 'Amine', 'initials': 'AM'},
    }, currentUserId: 7);

    expect(message.isMine, isTrue);
    expect(message.senderId, 7);
    expect(message.senderName, 'Amine');
    expect(message.senderInitials, 'AM');
    expect(message.readAt, isNull);
  });

  test('fromJson prefers the explicit is_mine flag and parses read_at', () {
    final message = ChatMessage.fromJson({
      'id': 'msg-2',
      'match_id': 'match-1',
      'body': 'Merci',
      'status': 'APPROVED',
      'created_at': '2026-11-04T10:05:00+00:00',
      'read_at': '2026-11-04T10:06:00+00:00',
      'is_mine': false,
      'sender': {'id': 9, 'name': 'Sara', 'initials': 'SA'},
    }, currentUserId: 7);

    expect(message.isMine, isFalse);
    expect(message.readAt, DateTime.parse('2026-11-04T10:06:00+00:00'));
  });

  test('copyWith keeps the original values when readAt is omitted', () {
    final original = ChatMessage.fromJson({
      'id': 'msg-3',
      'match_id': 'match-1',
      'body': 'A bientot',
      'status': 'APPROVED',
      'created_at': '2026-11-04T10:10:00+00:00',
      'read_at': '2026-11-04T10:11:00+00:00',
      'sender': {'id': 7, 'name': 'Amine', 'initials': 'AM'},
    }, currentUserId: 7);

    final copy = original.copyWith();

    expect(copy.id, original.id);
    expect(copy.body, original.body);
    expect(copy.readAt, original.readAt);
  });
}
