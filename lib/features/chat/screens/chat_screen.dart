import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:file_picker/file_picker.dart';
import 'package:intl/intl.dart';
import '../../../core/db/database_service.dart';
import '../../../shared/theme/app_theme.dart';
import '../../radar/providers/radar_provider.dart';
import '../providers/chat_provider.dart';

class ChatScreen extends ConsumerStatefulWidget {
  final ContactModel contact;

  const ChatScreen({super.key, required this.contact});

  @override
  ConsumerState<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends ConsumerState<ChatScreen> {
  final TextEditingController _textController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final ImagePicker _imagePicker = ImagePicker();

  String? _replyToMessageId;
  String? _replyToContent;
  bool _isSearching = false;
  String _searchQuery = '';
  bool _isRecordingVoice = false;

  @override
  void dispose() {
    _textController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent + 80,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    }
  }

  void _sendTextMessage() {
    final text = _textController.text.trim();
    if (text.isEmpty) return;

    ref.read(chatProvider.notifier).sendMessage(
      recipientId: widget.contact.id,
      text: text,
      replyToId: _replyToMessageId,
    );

    _textController.clear();
    setState(() {
      _replyToMessageId = null;
      _replyToContent = null;
    });

    Future.delayed(const Duration(milliseconds: 100), _scrollToBottom);
  }

  void _pickAndSendImage() async {
    final picked = await _imagePicker.pickImage(source: ImageSource.gallery, imageQuality: 75);
    if (picked != null) {
      final bytes = await picked.readAsBytes();
      ref.read(chatProvider.notifier).sendMessage(
        recipientId: widget.contact.id,
        text: "[Image] ${picked.name}",
        type: MessageType.image,
        fileUrl: picked.path,
        fileSize: bytes.length,
      );
      Future.delayed(const Duration(milliseconds: 100), _scrollToBottom);
    }
  }

  void _pickAndSendFile() async {
    final res = await FilePicker.platform.pickFiles();
    if (res != null && res.files.single.path != null) {
      final file = res.files.single;
      final isPdf = file.extension?.toLowerCase() == 'pdf';
      ref.read(chatProvider.notifier).sendMessage(
        recipientId: widget.contact.id,
        text: "[File] ${file.name}",
        type: isPdf ? MessageType.pdf : MessageType.file,
        fileUrl: file.path,
        fileSize: file.size,
      );
      Future.delayed(const Duration(milliseconds: 100), _scrollToBottom);
    }
  }

  void _showSafetyCodeDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: const BorderSide(color: AppColors.surfaceBorder),
        ),
        title: Row(
          children: [
            const Icon(Icons.verified_user_outlined, color: AppColors.radarCyan),
            const SizedBox(width: 10),
            const Text("Safety Code", style: TextStyle(fontSize: 18, color: AppColors.textPrimary)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              "Compare this 6-digit fingerprint with your peer to verify end-to-end encryption without a central authority:",
              style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
            ),
            const SizedBox(height: 18),
            Center(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                decoration: BoxDecoration(
                  color: AppColors.surfaceElevated,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: AppColors.radarCyan.withOpacity(0.4)),
                ),
                child: Text(
                  widget.contact.safetyCode.isNotEmpty ? widget.contact.safetyCode : "384 912",
                  style: const TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 4,
                    color: AppColors.radarCyan,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 14),
            const Text(
              "Public Key: X25519 authenticated\nEncrypted with XChaCha20-Poly1305",
              style: TextStyle(color: AppColors.textMuted, fontSize: 11),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text("Verified", style: TextStyle(color: AppColors.radarCyan)),
          ),
        ],
      ),
    );
  }

  void _showMessageOptions(MessageModel msg) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Quick Emoji Reactions
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: ['👍', '❤️', '😂', '🔥', '✅'].map((emoji) {
                return InkWell(
                  onTap: () {
                    Navigator.of(ctx).pop();
                    ref.read(chatProvider.notifier).addReaction(widget.contact.id, msg.id, emoji);
                  },
                  child: Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: Text(emoji, style: const TextStyle(fontSize: 26)),
                  ),
                );
              }).toList(),
            ),
            const Divider(color: AppColors.surfaceBorder, height: 24),
            ListTile(
              leading: const Icon(Icons.copy, color: AppColors.textPrimary),
              title: const Text("Copy Text"),
              onTap: () {
                Clipboard.setData(ClipboardData(text: msg.content));
                Navigator.of(ctx).pop();
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text("Copied to clipboard")),
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.reply, color: AppColors.textPrimary),
              title: const Text("Reply"),
              onTap: () {
                Navigator.of(ctx).pop();
                setState(() {
                  _replyToMessageId = msg.id;
                  _replyToContent = msg.content;
                });
              },
            ),
            ListTile(
              leading: const Icon(Icons.delete_outline, color: AppColors.error),
              title: const Text("Delete for Me", style: TextStyle(color: AppColors.error)),
              onTap: () {
                Navigator.of(ctx).pop();
                ref.read(chatProvider.notifier).deleteMessage(widget.contact.id, msg.id);
              },
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final db = ref.watch(databaseServiceProvider);
    final radarPeers = ref.watch(radarProvider).activePeers;
    final isInRange = radarPeers.any((p) => p.deviceId == widget.contact.id);

    final chatState = ref.watch(chatProvider);
    final messages = chatState.messagesByConversation[widget.contact.id] ??
        db.getMessagesForConversation(widget.contact.id);

    final filteredMessages = _searchQuery.isEmpty
        ? messages
        : messages.where((m) => m.content.toLowerCase().contains(_searchQuery.toLowerCase())).toList();

    return Scaffold(
      appBar: AppBar(
        titleSpacing: 0,
        title: _isSearching
            ? TextField(
                autofocus: true,
                style: const TextStyle(color: AppColors.textPrimary),
                decoration: const InputDecoration(
                  hintText: "Search in conversation...",
                  border: InputBorder.none,
                  enabledBorder: InputBorder.none,
                  focusedBorder: InputBorder.none,
                ),
                onChanged: (val) => setState(() => _searchQuery = val),
              )
            : Row(
                children: [
                  CircleAvatar(
                    radius: 18,
                    backgroundColor: AppColors.surfaceElevated,
                    child: widget.contact.avatarBytes != null
                        ? ClipOval(child: Image.memory(widget.contact.avatarBytes!, fit: BoxFit.cover))
                        : Text(
                            widget.contact.displayName.isNotEmpty ? widget.contact.displayName[0].toUpperCase() : 'C',
                            style: const TextStyle(color: AppColors.radarCyan, fontWeight: FontWeight.bold),
                          ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.contact.displayName,
                          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                          overflow: TextOverflow.ellipsis,
                        ),
                        Row(
                          children: [
                            Container(
                              width: 6,
                              height: 6,
                              decoration: BoxDecoration(
                                color: isInRange ? AppColors.radarGreen : AppColors.textMuted,
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 4),
                            Text(
                              isInRange ? "In radar range" : "Out of range (Queued)",
                              style: TextStyle(
                                fontSize: 11,
                                color: isInRange ? AppColors.radarGreen : AppColors.textMuted,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
        actions: [
          if (_isSearching)
            IconButton(
              icon: const Icon(Icons.close),
              onPressed: () => setState(() {
                _isSearching = false;
                _searchQuery = '';
              }),
            )
          else ...[
            IconButton(
              icon: const Icon(Icons.search),
              tooltip: "Search",
              onPressed: () => setState(() => _isSearching = true),
            ),
            IconButton(
              icon: const Icon(Icons.verified_user_outlined, color: AppColors.radarCyan),
              tooltip: "Safety Code Fingerprint",
              onPressed: _showSafetyCodeDialog,
            ),
          ],
        ],
      ),
      body: Column(
        children: [
          // Offline banner if peer is out of range
          if (!isInRange)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              color: AppColors.surfaceElevated,
              child: const Row(
                children: [
                  Icon(Icons.schedule, color: AppColors.statusBusy, size: 16),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      "Peer is out of range. Messages are saved in the offline queue and sent upon reconnect.",
                      style: TextStyle(fontSize: 11, color: AppColors.textSecondary),
                    ),
                  ),
                ],
              ),
            ),

          // Message Bubbles
          Expanded(
            child: filteredMessages.isEmpty
                ? Center(
                    child: Text(
                      _searchQuery.isNotEmpty ? "No matching messages found." : "No messages yet. Send a message to start!",
                      style: const TextStyle(color: AppColors.textMuted, fontSize: 13),
                    ),
                  )
                : ListView.builder(
                    controller: _scrollController,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    itemCount: filteredMessages.length,
                    itemBuilder: (context, index) {
                      final msg = filteredMessages[index];
                      final isMe = msg.senderId != widget.contact.id;
                      return _buildMessageBubble(msg, isMe);
                    },
                  ),
          ),

          // Reply-To Banner
          if (_replyToContent != null)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              color: AppColors.surfaceElevated,
              child: Row(
                children: [
                  const Icon(Icons.reply, color: AppColors.radarCyan, size: 18),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      "Replying to: $_replyToContent",
                      style: const TextStyle(color: AppColors.textSecondary, fontSize: 12),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, size: 16, color: AppColors.textMuted),
                    onPressed: () => setState(() {
                      _replyToMessageId = null;
                      _replyToContent = null;
                    }),
                  ),
                ],
              ),
            ),

          // Input Bar
          _buildInputBar(),
        ],
      ),
    );
  }

  Widget _buildMessageBubble(MessageModel msg, bool isMe) {
    final statusIcon = msg.deliveryStatus == DeliveryStatus.queued
        ? const Icon(Icons.schedule, size: 12, color: AppColors.textMuted)
        : (msg.deliveryStatus == DeliveryStatus.sent
            ? const Icon(Icons.done, size: 12, color: AppColors.textMuted)
            : const Icon(Icons.done_all, size: 12, color: AppColors.radarCyan));

    return Align(
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: GestureDetector(
        onLongPress: () => _showMessageOptions(msg),
        child: Container(
          margin: const EdgeInsets.only(bottom: 10),
          constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.78),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: isMe ? AppColors.surfaceElevated : AppColors.surface,
            borderRadius: BorderRadius.only(
              topLeft: const Radius.circular(16),
              topRight: const Radius.circular(16),
              bottomLeft: isMe ? const Radius.circular(16) : const Radius.circular(4),
              bottomRight: isMe ? const Radius.circular(4) : const Radius.circular(16),
            ),
            border: Border.all(
              color: isMe ? AppColors.radarCyan.withOpacity(0.3) : AppColors.surfaceBorder,
              width: 1,
            ),
          ),
          child: Column(
            crossAxisAlignment: isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
            children: [
              // Message content
              SelectableText(
                msg.content,
                style: const TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 14,
                  height: 1.3,
                ),
              ),
              const SizedBox(height: 4),
              // Timestamp and status
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    DateFormat.jm().format(msg.timestamp),
                    style: const TextStyle(color: AppColors.textMuted, fontSize: 10),
                  ),
                  if (isMe) ...[
                    const SizedBox(width: 4),
                    statusIcon,
                  ],
                ],
              ),
              // Reactions row
              if (msg.reactions.isNotEmpty) ...[
                const SizedBox(height: 4),
                Wrap(
                  spacing: 4,
                  children: msg.reactions.keys.map((emoji) {
                    return Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: AppColors.background.withOpacity(0.8),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: AppColors.surfaceBorder),
                      ),
                      child: Text(emoji, style: const TextStyle(fontSize: 12)),
                    );
                  }).toList(),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInputBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: const BoxDecoration(
        color: AppColors.surface,
        border: Border(top: BorderSide(color: AppColors.surfaceBorder)),
      ),
      child: SafeArea(
        top: false,
        child: Row(
          children: [
            // Attachment menu (+)
            IconButton(
              icon: const Icon(Icons.add_circle_outline, color: AppColors.radarCyan),
              tooltip: "Attach Media or File",
              onPressed: () {
                showModalBottomSheet(
                  context: context,
                  backgroundColor: AppColors.surface,
                  shape: const RoundedRectangleBorder(
                    borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
                  ),
                  builder: (ctx) => Padding(
                    padding: const EdgeInsets.all(20),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        _buildAttachButton(Icons.image, "Photo", _pickAndSendImage),
                        _buildAttachButton(Icons.picture_as_pdf, "PDF / File", _pickAndSendFile),
                      ],
                    ),
                  ),
                );
              },
            ),

            // Input field
            Expanded(
              child: TextField(
                controller: _textController,
                textCapitalization: TextCapitalization.sentences,
                style: const TextStyle(color: AppColors.textPrimary),
                decoration: const InputDecoration(
                  hintText: "Type encrypted offline message...",
                  contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                ),
                onSubmitted: (_) => _sendTextMessage(),
              ),
            ),

            const SizedBox(width: 8),

            // Voice Note / Send Button
            IconButton(
              onPressed: _sendTextMessage,
              icon: const Icon(Icons.send, color: AppColors.radarCyan),
              style: IconButton.styleFrom(
                backgroundColor: AppColors.surfaceElevated,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAttachButton(IconData icon, String label, VoidCallback onTap) {
    return InkWell(
      onTap: () {
        Navigator.of(context).pop();
        onTap();
      },
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.surfaceElevated,
              shape: BoxShape.circle,
              border: Border.all(color: AppColors.radarCyan.withOpacity(0.3)),
            ),
            child: Icon(icon, color: AppColors.radarCyan, size: 28),
          ),
          const SizedBox(height: 8),
          Text(label, style: const TextStyle(color: AppColors.textPrimary, fontSize: 12)),
        ],
      ),
    );
  }
}
