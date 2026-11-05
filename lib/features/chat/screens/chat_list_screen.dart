import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../core/db/database_service.dart';
import '../../../shared/theme/app_theme.dart';
import '../../radar/providers/radar_provider.dart';
import '../providers/chat_provider.dart';
import 'chat_screen.dart';

class ChatListScreen extends ConsumerWidget {
  final VoidCallback onNavigateToRadar;

  const ChatListScreen({super.key, required this.onNavigateToRadar});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final db = ref.watch(databaseServiceProvider);
    final contacts = db.getAllContacts();
    final radarPeers = ref.watch(radarProvider).activePeers;
    final chatState = ref.watch(chatProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text("Chats"),
        actions: [
          IconButton(
            onPressed: onNavigateToRadar,
            icon: const Icon(Icons.radar, color: AppColors.radarCyan),
            tooltip: "Radar Scanner",
          ),
        ],
      ),
      body: contacts.isEmpty
          ? Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: AppColors.radarCyan.withOpacity(0.1),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.chat_bubble_outline, color: AppColors.radarCyan, size: 48),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    "No offline chats yet",
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    "Discover nearby peers on the radar to start chatting",
                    style: TextStyle(color: AppColors.textMuted, fontSize: 13),
                  ),
                  const SizedBox(height: 20),
                  ElevatedButton.icon(
                    onPressed: onNavigateToRadar,
                    icon: const Icon(Icons.radar, size: 18),
                    label: const Text("Open Radar"),
                  ),
                ],
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              itemCount: contacts.length,
              itemBuilder: (context, index) {
                final contact = contacts[index];
                final isInRange = radarPeers.any((p) => p.deviceId == contact.id);

                final messages = chatState.messagesByConversation[contact.id] ??
                    db.getMessagesForConversation(contact.id);
                final lastMsg = messages.isNotEmpty ? messages.last : null;

                final lastTime = lastMsg != null
                    ? DateFormat.jm().format(lastMsg.timestamp)
                    : DateFormat.MMMd().format(contact.lastSeenAt);

                return Card(
                  margin: const EdgeInsets.only(bottom: 8),
                  child: ListTile(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                    onTap: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => ChatScreen(contact: contact),
                        ),
                      );
                    },
                    leading: Stack(
                      children: [
                        CircleAvatar(
                          radius: 26,
                          backgroundColor: AppColors.surfaceElevated,
                          child: contact.avatarBytes != null
                              ? ClipOval(child: Image.memory(contact.avatarBytes!, fit: BoxFit.cover))
                              : Text(
                                  contact.displayName.isNotEmpty ? contact.displayName[0].toUpperCase() : 'C',
                                  style: const TextStyle(
                                    color: AppColors.radarCyan,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 18,
                                  ),
                                ),
                        ),
                        // Online / in-range beacon dot
                        Positioned(
                          right: 0,
                          bottom: 0,
                          child: Container(
                            width: 14,
                            height: 14,
                            decoration: BoxDecoration(
                              color: isInRange ? AppColors.radarGreen : AppColors.textMuted,
                              shape: BoxShape.circle,
                              border: Border.all(color: AppColors.surface, width: 2.5),
                              boxShadow: isInRange
                                  ? [
                                      BoxShadow(
                                        color: AppColors.radarGreen.withOpacity(0.6),
                                        blurRadius: 6,
                                        spreadRadius: 1,
                                      ),
                                    ]
                                  : null,
                            ),
                          ),
                        ),
                      ],
                    ),
                    title: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Text(
                            contact.displayName,
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              color: AppColors.textPrimary,
                              fontSize: 16,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        Text(
                          lastTime,
                          style: const TextStyle(color: AppColors.textMuted, fontSize: 11),
                        ),
                      ],
                    ),
                    subtitle: Row(
                      children: [
                        Expanded(
                          child: Text(
                            lastMsg != null ? lastMsg.content : "Tap to open conversation",
                            style: TextStyle(
                              color: lastMsg != null ? AppColors.textSecondary : AppColors.textMuted,
                              fontSize: 13,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (isInRange)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: AppColors.radarGreen.withOpacity(0.15),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: const Text(
                              "IN RANGE",
                              style: TextStyle(
                                color: AppColors.radarGreen,
                                fontSize: 9,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                );
              },
            ),
    );
  }
}
