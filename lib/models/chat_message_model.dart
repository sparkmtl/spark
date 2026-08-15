/// A single message within a conversation.
class ChatMessageModel {
  const ChatMessageModel({
    required this.id,
    required this.conversationId,
    required this.content,
    required this.createdAt,
    required this.mine,
  });

  final String id;
  final String conversationId;
  final String content;
  final DateTime createdAt;
  final bool mine;

  factory ChatMessageModel.fromJson(Map<String, dynamic> json) {
    return ChatMessageModel(
      id: '${json['id']}',
      conversationId: '${json['conversationId']}',
      content: json['content'] as String? ?? '',
      createdAt: DateTime.tryParse('${json['createdAt']}') ?? DateTime.now(),
      mine: json['mine'] as bool? ?? false,
    );
  }
}
