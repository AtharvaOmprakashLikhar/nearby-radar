import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../features/chat/screens/chat_list_screen.dart';
import '../../../features/connections/providers/connection_provider.dart';
import '../../../features/profile/screens/profile_screen.dart';
import '../../../features/radar/screens/radar_screen.dart';
import '../../../features/settings/screens/settings_screen.dart';
import '../theme/app_theme.dart';

class MainScaffold extends ConsumerStatefulWidget {
  const MainScaffold({super.key});

  @override
  ConsumerState<MainScaffold> createState() => _MainScaffoldState();
}

class _MainScaffoldState extends ConsumerState<MainScaffold> {
  int _currentIndex = 0;

  @override
  Widget build(BuildContext context) {
    // Listen for incoming connection requests to show the modal
    final connectionState = ref.watch(connectionProvider);
    final pending = connectionState.pendingIncomingRequest;

    return Scaffold(
      body: Stack(
        children: [
          IndexedStack(
            index: _currentIndex,
            children: [
              const RadarScreen(),
              ChatListScreen(onNavigateToRadar: () => setState(() => _currentIndex = 0)),
              const ProfileScreen(),
              const SettingsScreen(),
            ],
          ),

          // In-App Incoming Connection Request Alert Banner
          if (pending != null)
            Positioned(
              top: 16,
              left: 16,
              right: 16,
              child: SafeArea(
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceElevated,
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: AppColors.radarCyan, width: 1.5),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.5),
                        blurRadius: 16,
                        spreadRadius: 4,
                      ),
                    ],
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.radar, color: AppColors.radarCyan, size: 22),
                          const SizedBox(width: 8),
                          const Text(
                            "Incoming Connection Request",
                            style: TextStyle(
                              color: AppColors.radarCyan,
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          CircleAvatar(
                            radius: 20,
                            backgroundColor: AppColors.surface,
                            child: pending.payload.senderProfile.avatarBytes != null
                                ? ClipOval(child: Image.memory(pending.payload.senderProfile.avatarBytes!, fit: BoxFit.cover))
                                : Text(
                                    pending.payload.senderProfile.displayName.isNotEmpty
                                        ? pending.payload.senderProfile.displayName[0].toUpperCase()
                                        : 'P',
                                    style: const TextStyle(color: AppColors.radarCyan, fontWeight: FontWeight.bold),
                                  ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  pending.payload.senderProfile.displayName,
                                  style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                                ),
                                Text(
                                  pending.payload.senderProfile.bio.isNotEmpty
                                      ? pending.payload.senderProfile.bio
                                      : "Peer wants to connect with you",
                                  style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          TextButton(
                            onPressed: () => ref.read(connectionProvider.notifier).declineIncomingRequest(),
                            child: const Text("Decline", style: TextStyle(color: AppColors.textMuted)),
                          ),
                          const SizedBox(width: 8),
                          ElevatedButton(
                            onPressed: () {
                              ref.read(connectionProvider.notifier).acceptIncomingRequest();
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text("Connected! Encrypted channel established."),
                                  backgroundColor: AppColors.surfaceElevated,
                                ),
                              );
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.radarCyan,
                              foregroundColor: Colors.black,
                              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
                            ),
                            child: const Text("Accept", style: TextStyle(fontWeight: FontWeight.bold)),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentIndex,
        onDestinationSelected: (index) => setState(() => _currentIndex = index),
        backgroundColor: AppColors.surface,
        indicatorColor: AppColors.radarCyan.withOpacity(0.18),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.radar_outlined, color: AppColors.textMuted),
            selectedIcon: Icon(Icons.radar, color: AppColors.radarCyan),
            label: "Radar",
          ),
          NavigationDestination(
            icon: Icon(Icons.chat_bubble_outline, color: AppColors.textMuted),
            selectedIcon: Icon(Icons.chat_bubble, color: AppColors.radarCyan),
            label: "Chats",
          ),
          NavigationDestination(
            icon: Icon(Icons.person_outline, color: AppColors.textMuted),
            selectedIcon: Icon(Icons.person, color: AppColors.radarCyan),
            label: "Profile",
          ),
          NavigationDestination(
            icon: Icon(Icons.settings_outlined, color: AppColors.textMuted),
            selectedIcon: Icon(Icons.settings, color: AppColors.radarCyan),
            label: "Settings",
          ),
        ],
      ),
    );
  }
}
