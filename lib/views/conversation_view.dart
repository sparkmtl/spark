import 'dart:async';

import 'package:flutter/material.dart';

import '../models/chat_message_model.dart';
import '../services/chat_api.dart';
import '../theme/spark_colors.dart';
import '../widgets/spark_text_field.dart';

/// A single 1:1 conversation thread, opened from the Map (or, later, from a
/// Chat inbox). Self-contained so it can be reused from anywhere a
/// [ConversationModel] id + the other user's name are available.
class ConversationView extends StatefulWidget {
  ConversationView({
    super.key,
    required this.conversationId,
    required this.otherUserName,
    ChatApi? chatApi,
  }) : chatApi = chatApi ?? ChatApi();

  final String conversationId;
  final String otherUserName;
  final ChatApi chatApi;

  @override
  State<ConversationView> createState() => _ConversationViewState();
}

class _ConversationViewState extends State<ConversationView> {
  ChatApi get _chatApi => widget.chatApi;
  final TextEditingController _inputController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  List<ChatMessageModel> _messages = [];
  bool _isLoading = true;
  bool _isSending = false;
  String? _errorMessage;
  Timer? _refreshTimer;

  @override
  void initState() {
    super.initState();
    _loadMessages(showSpinner: true);
    // Lightweight polling so both sides see new messages without needing
    // sockets — acceptable for a 1:1 thread at this scale.
    _refreshTimer = Timer.periodic(
      const Duration(seconds: 4),
      (_) => _loadMessages(),
    );
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    _inputController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _loadMessages({bool showSpinner = false}) async {
    if (showSpinner) setState(() => _isLoading = true);
    try {
      final messages = await _chatApi.getMessages(widget.conversationId);
      if (!mounted) return;
      final hadFewerMessages = messages.length != _messages.length;
      setState(() {
        _messages = messages;
        _isLoading = false;
        _errorMessage = null;
      });
      if (hadFewerMessages) _scrollToBottom();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _errorMessage = showSpinner ? "Couldn't load messages." : _errorMessage;
      });
    }
  }

  Future<void> _sendMessage() async {
    final content = _inputController.text.trim();
    if (content.isEmpty || _isSending) return;

    setState(() => _isSending = true);
    try {
      final message = await _chatApi.sendMessage(widget.conversationId, content);
      if (!mounted) return;
      setState(() {
        _messages = [..._messages, message];
        _inputController.clear();
      });
      _scrollToBottom();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Couldn't send message. Try again.")),
      );
    } finally {
      if (mounted) setState(() => _isSending = false);
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollController.hasClients) return;
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOut,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.otherUserName),
        titleTextStyle: const TextStyle(
          color: SparkColors.title,
          fontSize: 17,
          fontWeight: FontWeight.w700,
        ),
        iconTheme: const IconThemeData(color: SparkColors.title),
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(child: _buildMessageList()),
            _buildComposer(),
          ],
        ),
      ),
    );
  }

  Widget _buildMessageList() {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(color: SparkColors.accent),
      );
    }

    if (_errorMessage != null && _messages.isEmpty) {
      return Center(
        child: Text(
          _errorMessage!,
          style: const TextStyle(color: SparkColors.placeholder),
        ),
      );
    }

    if (_messages.isEmpty) {
      return Center(
        child: Text(
          'Say hi to ${widget.otherUserName}!',
          style: const TextStyle(color: SparkColors.placeholder),
        ),
      );
    }

    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      itemCount: _messages.length,
      itemBuilder: (context, index) => _MessageBubble(message: _messages[index]),
    );
  }

  Widget _buildComposer() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Expanded(
            child: SparkTextField(
              hint: 'Message',
              controller: _inputController,
              onChanged: (_) {},
              textInputAction: TextInputAction.send,
              onSubmitted: (_) => _sendMessage(),
              maxLines: 4,
              minLines: 1,
            ),
          ),
          const SizedBox(width: 8),
          Material(
            color: SparkColors.accent,
            shape: const CircleBorder(),
            child: InkWell(
              onTap: _isSending ? null : _sendMessage,
              customBorder: const CircleBorder(),
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: _isSending
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: SparkColors.onAccent,
                        ),
                      )
                    : const Icon(
                        Icons.send_rounded,
                        size: 18,
                        color: SparkColors.onAccent,
                      ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _MessageBubble extends StatelessWidget {
  const _MessageBubble({required this.message});

  final ChatMessageModel message;

  @override
  Widget build(BuildContext context) {
    final isMine = message.mine;
    return Align(
      alignment: isMine ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 4),
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.75,
        ),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: isMine ? SparkColors.accent : SparkColors.surfaceElevated,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(16),
            topRight: const Radius.circular(16),
            bottomLeft: Radius.circular(isMine ? 16 : 4),
            bottomRight: Radius.circular(isMine ? 4 : 16),
          ),
        ),
        child: Text(
          message.content,
          style: TextStyle(
            color: isMine ? SparkColors.onAccent : SparkColors.fieldText,
            fontSize: 15,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
    );
  }
}
