import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';

class ProviderChatPage extends StatelessWidget {
  const ProviderChatPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.s20,
            vertical: AppSpacing.s16,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'PROVIDER MODE',
                style: TextStyle(
                  color: AppColors.primary,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.1,
                ),
              ),
              const SizedBox(height: 4),
              const Text(
                'Customer Messages',
                style: TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textPrimary,
                  letterSpacing: -0.5,
                ),
              ),
              const SizedBox(height: 16),
              Expanded(
                child: ListView(
                  children: [
                    _ChatTile(
                      name: 'Saman Jayasinghe',
                      lastMessage: 'Are you available to check the leak at 2 PM today?',
                      time: '10:45 AM',
                      unread: 1,
                    ),
                    const Divider(),
                    _ChatTile(
                      name: 'Nilmini Perera',
                      lastMessage: 'Thank you! The tap replacement works great.',
                      time: 'Yesterday',
                      unread: 0,
                    ),
                    const Divider(),
                    _ChatTile(
                      name: 'Rohan Silva',
                      lastMessage: 'Can you bring extra 1/2 inch copper fittings?',
                      time: 'Thu',
                      unread: 0,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ChatTile extends StatelessWidget {
  final String name;
  final String lastMessage;
  final String time;
  final int unread;

  const _ChatTile({
    required this.name,
    required this.lastMessage,
    required this.time,
    required this.unread,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: CircleAvatar(
        backgroundColor: AppColors.primaryLight,
        child: Text(
          name.isNotEmpty ? name[0] : 'U',
          style: const TextStyle(fontWeight: FontWeight.w700, color: AppColors.primary),
        ),
      ),
      title: Text(name, style: const TextStyle(fontWeight: FontWeight.w700)),
      subtitle: Text(
        lastMessage,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          color: unread > 0 ? AppColors.textPrimary : AppColors.textSecondary,
          fontWeight: unread > 0 ? FontWeight.w600 : FontWeight.w400,
        ),
      ),
      trailing: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Text(time, style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
          if (unread > 0) ...[
            const SizedBox(height: 4),
            CircleAvatar(
              radius: 9,
              backgroundColor: AppColors.primary,
              child: Text(
                '$unread',
                style: const TextStyle(fontSize: 10, color: Colors.white, fontWeight: FontWeight.w700),
              ),
            ),
          ],
        ],
      ),
      onTap: () {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Chat with $name opened.')),
        );
      },
    );
  }
}
