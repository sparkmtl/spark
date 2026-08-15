/// A 1:1 conversation with another user, as returned by
/// `POST /api/chat/conversations`.
class ConversationModel {
  const ConversationModel({
    required this.id,
    required this.otherUserId,
    required this.otherUserName,
  });

  final String id;
  final String otherUserId;
  final String otherUserName;

  factory ConversationModel.fromJson(Map<String, dynamic> json) {
    return ConversationModel(
      id: '${json['id']}',
      otherUserId: '${json['otherUserId']}',
      otherUserName: json['otherUserName'] as String? ?? '',
    );
  }
}
