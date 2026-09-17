import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/network/api_client.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';

// Backend wraps list response as { data: [...], total, unreadCount }
final _notificationsProvider =
    FutureProvider.autoDispose<Map<String, dynamic>>((ref) async {
  final response =
      await ref.watch(dioProvider).get('/users/me/notifications');
  return response.data['data'] as Map<String, dynamic>;
});

class NotificationsScreen extends ConsumerWidget {
  const NotificationsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notifs = ref.watch(_notificationsProvider);
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Notifications'),
        actions: [
          notifs.maybeWhen(
            data: (wrapper) {
              final unread = wrapper['unreadCount'] as int? ?? 0;
              if (unread == 0) return const SizedBox.shrink();
              return TextButton(
                onPressed: () async {
                  await ref
                      .read(dioProvider)
                      .patch('/users/me/notifications/read');
                  ref.invalidate(_notificationsProvider);
                },
                child: Text('Mark all read ($unread)'),
              );
            },
            orElse: () => const SizedBox.shrink(),
          ),
        ],
      ),
      body: notifs.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.error_outline,
                  size: 48, color: theme.colorScheme.error),
              const SizedBox(height: 12),
              Text('Could not load notifications',
                  style: AppTextStyles.bodyMedium),
              const SizedBox(height: 8),
              TextButton(
                onPressed: () => ref.invalidate(_notificationsProvider),
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
        data: (wrapper) {
          final list = List<Map<String, dynamic>>.from(
              wrapper['data'] as List? ?? []);

          if (list.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.notifications_off_outlined,
                    size: 64,
                    color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.35),
                  ),
                  const SizedBox(height: 16),
                  Text('No notifications yet',
                      style: AppTextStyles.titleMedium),
                  const SizedBox(height: 8),
                  Text(
                    'Appointment updates and reminders\nwill appear here.',
                    textAlign: TextAlign.center,
                    style: AppTextStyles.bodySmall.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            );
          }

          return RefreshIndicator(
            onRefresh: () => ref.refresh(_notificationsProvider.future),
            child: ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: list.length,
              separatorBuilder: (_, __) => const SizedBox(height: 8),
              itemBuilder: (_, i) =>
                  _NotificationTile(notification: list[i]),
            ),
          );
        },
      ),
    );
  }
}

class _NotificationTile extends StatelessWidget {
  const _NotificationTile({required this.notification});
  final Map<String, dynamic> notification;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isRead = notification['isRead'] == true;
    final type = notification['type'] as String? ?? 'INFO';
    final createdAt = notification['createdAt'] as String?;
    final timeLabel = _formatTime(createdAt);

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isRead
            ? theme.colorScheme.surface
            : theme.colorScheme.primaryContainer.withValues(alpha: 0.25),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isRead
              ? theme.colorScheme.outlineVariant
              : theme.colorScheme.primary.withValues(alpha: 0.3),
          width: 1,
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: theme.colorScheme.primaryContainer,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              _typeIcon(type),
              size: 20,
              color: theme.colorScheme.primary,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        notification['title'] as String? ?? '',
                        style: AppTextStyles.titleSmall.copyWith(
                          fontWeight:
                              isRead ? FontWeight.w500 : FontWeight.w700,
                        ),
                      ),
                    ),
                    if (!isRead)
                      Container(
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(
                          color: theme.colorScheme.primary,
                          shape: BoxShape.circle,
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  notification['body'] as String? ?? '',
                  style: AppTextStyles.bodySmall.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                if (timeLabel != null) ...[
                  const SizedBox(height: 6),
                  Text(
                    timeLabel,
                    style: AppTextStyles.labelSmall.copyWith(
                      color: theme.colorScheme.onSurfaceVariant
                          .withValues(alpha: 0.7),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  String? _formatTime(String? iso) {
    if (iso == null) return null;
    try {
      final dt = DateTime.parse(iso).toLocal();
      final now = DateTime.now();
      final diff = now.difference(dt);
      if (diff.inMinutes < 1) return 'Just now';
      if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
      if (diff.inHours < 24) return '${diff.inHours}h ago';
      if (diff.inDays == 1) return 'Yesterday';
      return '${diff.inDays}d ago';
    } catch (_) {
      return null;
    }
  }

  IconData _typeIcon(String type) {
    switch (type) {
      case 'APPOINTMENT_CONFIRMED': return Icons.check_circle_outline_rounded;
      case 'APPOINTMENT_CANCELLED': return Icons.cancel_outlined;
      case 'APPOINTMENT_REMINDER': return Icons.alarm_rounded;
      case 'PRESCRIPTION': return Icons.medication_outlined;
      default: return Icons.notifications_outlined;
    }
  }
}
