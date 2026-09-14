import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/storage/auth_storage.dart';
import '../../../../core/network/api_client.dart';

final _profileProvider = FutureProvider.autoDispose<Map<String, dynamic>>((ref) async {
  final response = await ref.watch(dioProvider).get('/users/me');
  return response.data['data'] as Map<String, dynamic>;
});

final _themeModeProvider = StateProvider<ThemeMode>((ref) => ThemeMode.system);

Future<void> _showEditProfile(BuildContext context, WidgetRef ref) async {
  final profileAsync = ref.read(_profileProvider);
  final user = profileAsync.valueOrNull ?? {};

  final nameCtrl = TextEditingController(text: user['name'] as String? ?? '');
  String? gender = user['gender'] as String?;
  final ageCtrl = TextEditingController(
    text: user['age'] != null ? '${user['age']}' : '',
  );
  bool saving = false;

  await showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setModal) => Padding(
        padding: EdgeInsets.only(
          left: 20,
          right: 20,
          top: 20,
          bottom: MediaQuery.of(ctx).viewInsets.bottom + 24,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Edit Profile', style: AppTextStyles.titleMedium),
            const SizedBox(height: 16),
            TextField(
              controller: nameCtrl,
              decoration: const InputDecoration(labelText: 'Name', border: OutlineInputBorder()),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              initialValue: gender,
              decoration: const InputDecoration(labelText: 'Gender', border: OutlineInputBorder()),
              items: const [
                DropdownMenuItem(value: 'MALE', child: Text('Male')),
                DropdownMenuItem(value: 'FEMALE', child: Text('Female')),
                DropdownMenuItem(value: 'OTHER', child: Text('Other')),
              ],
              onChanged: (v) => setModal(() => gender = v),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: ageCtrl,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'Age', border: OutlineInputBorder()),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: saving
                    ? null
                    : () async {
                        setModal(() => saving = true);
                        try {
                          await ref.read(dioProvider).patch('/users/me', data: {
                            if (nameCtrl.text.trim().isNotEmpty) 'name': nameCtrl.text.trim(),
                            if (gender != null) 'gender': gender,
                            if (ageCtrl.text.trim().isNotEmpty)
                              'age': int.tryParse(ageCtrl.text.trim()),
                          });
                          ref.invalidate(_profileProvider);
                          if (ctx.mounted) Navigator.pop(ctx);
                        } catch (e) {
                          if (ctx.mounted) {
                            ScaffoldMessenger.of(ctx).showSnackBar(
                              SnackBar(content: Text('Failed to save: $e')),
                            );
                          }
                        } finally {
                          setModal(() => saving = false);
                        }
                      },
                child: saving
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      )
                    : const Text('Save'),
              ),
            ),
          ],
        ),
      ),
    ),
  );
  nameCtrl.dispose();
  ageCtrl.dispose();
}

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profileAsync = ref.watch(_profileProvider);
    final themeMode = ref.watch(_themeModeProvider);

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            title: const Text('Profile'),
            floating: true,
          ),
          SliverToBoxAdapter(
            child: profileAsync.when(
              loading: () => const LinearProgressIndicator(),
              error: (_, __) => const SizedBox.shrink(),
              data: (user) => _ProfileHeader(
                user: user,
                onEdit: () => _showEditProfile(context, ref),
              ),
            ),
          ),
          SliverList(
            delegate: SliverChildListDelegate([
              const SizedBox(height: 16),
              _Section(
                title: 'Account',
                items: [
                  _SettingItem(
                    icon: Icons.person_outline_rounded,
                    label: 'Edit Profile',
                    onTap: () => _showEditProfile(context, ref),
                  ),
                  _SettingItem(
                    icon: Icons.favorite_outline_rounded,
                    label: 'Saved Doctors',
                    onTap: () => context.pushNamed('search'),
                  ),
                  _SettingItem(
                    icon: Icons.notifications_outlined,
                    label: 'Notifications',
                    onTap: () => context.pushNamed('notifications'),
                  ),
                  // Phase 2
                  _SettingItem(
                    icon: Icons.medical_information_outlined,
                    label: 'Medical History',
                    onTap: () => context.pushNamed('medicalHistory'),
                  ),
                ],
              ),
              _Section(
                title: 'Preferences',
                items: [
                  _ThemeToggle(themeMode: themeMode, onChanged: (mode) {
                    ref.read(_themeModeProvider.notifier).state = mode;
                  }),
                ],
              ),
              _Section(
                title: 'About',
                items: [
                  _SettingItem(icon: Icons.privacy_tip_outlined, label: 'Privacy Policy', onTap: () {}),
                  _SettingItem(icon: Icons.description_outlined, label: 'Terms of Service', onTap: () {}),
                  _SettingItem(icon: Icons.support_agent_outlined, label: 'Contact Support', onTap: () {}),
                ],
              ),
              Padding(
                padding: const EdgeInsets.all(16),
                child: OutlinedButton.icon(
                  onPressed: () async {
                    await ref.read(authStorageProvider).clear();
                    if (context.mounted) context.goNamed('phoneInput');
                  },
                  icon: const Icon(Icons.logout_rounded, color: AppColors.error),
                  label: const Text('Sign Out', style: TextStyle(color: AppColors.error)),
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: AppColors.error),
                    minimumSize: const Size(double.infinity, 52),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                ),
              ),
              const SizedBox(height: 24),
            ]),
          ),
        ],
      ),
    );
  }
}

class _ProfileHeader extends StatelessWidget {
  const _ProfileHeader({required this.user, required this.onEdit});
  final Map<String, dynamic> user;
  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      child: Row(
        children: [
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [AppColors.primary, AppColors.primaryLight],
              ),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Center(
              child: Text(
                ((user['name'] as String?) ?? 'U').substring(0, 1).toUpperCase(),
                style: AppTextStyles.headlineMedium.copyWith(color: Colors.white),
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(user['name'] as String? ?? '', style: AppTextStyles.titleMedium),
                const SizedBox(height: 4),
                Text(user['phone'] as String? ?? '', style: AppTextStyles.bodySmall),
                if (user['email'] != null) ...[
                  const SizedBox(height: 2),
                  Text(user['email'] as String, style: AppTextStyles.bodySmall),
                ],
              ],
            ),
          ),
          IconButton(
            onPressed: onEdit,
            icon: const Icon(Icons.edit_outlined),
          ),
        ],
      ),
    );
  }
}

class _Section extends StatelessWidget {
  const _Section({required this.title, required this.items});
  final String title;
  final List<Widget> items;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
          child: Text(
            title,
            style: AppTextStyles.labelMedium.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        ),
        Container(
          margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(children: items),
        ),
      ],
    );
  }
}

class _SettingItem extends StatelessWidget {
  const _SettingItem({required this.icon, required this.label, required this.onTap});
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(icon, color: Theme.of(context).colorScheme.onSurface),
      title: Text(label, style: AppTextStyles.bodyMedium),
      trailing: const Icon(Icons.chevron_right_rounded, size: 20),
      onTap: onTap,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    );
  }
}

class _ThemeToggle extends StatelessWidget {
  const _ThemeToggle({required this.themeMode, required this.onChanged});
  final ThemeMode themeMode;
  final void Function(ThemeMode) onChanged;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: const Icon(Icons.dark_mode_outlined),
      title: Text('Dark Mode', style: AppTextStyles.bodyMedium),
      trailing: Switch(
        value: themeMode == ThemeMode.dark,
        onChanged: (v) => onChanged(v ? ThemeMode.dark : ThemeMode.light),
      ),
    );
  }
}
