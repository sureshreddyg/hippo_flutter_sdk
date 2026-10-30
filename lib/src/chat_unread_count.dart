/// The unread message count of one peer chat, as the native SDKs report it.
class ChatUnreadCount {
  const ChatUnreadCount(this.transactionId, this.count);

  /// The chat's `transactionId`: the one `openPeerChat` opens it with.
  final String transactionId;

  /// Unread messages in that chat.
  final int count;

  /// A count as the native side sends it: `{"transactionId": "…", "count": 2}`.
  factory ChatUnreadCount.fromEvent(Object? event) {
    final map = event as Map;
    return ChatUnreadCount('${map['transactionId']}', (map['count'] as num).toInt());
  }

  @override
  bool operator ==(Object other) =>
      other is ChatUnreadCount && other.transactionId == transactionId && other.count == count;

  @override
  int get hashCode => Object.hash(transactionId, count);

  @override
  String toString() => 'ChatUnreadCount($transactionId: $count)';
}
