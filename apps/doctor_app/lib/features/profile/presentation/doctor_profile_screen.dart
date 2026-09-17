import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:go_router/go_router.dart';
import '../../../core/network/api_client.dart';

final _profileProvider =
    FutureProvider.autoDispose<Map<String, dynamic>>((ref) async {
  final response =
      await ref.watch(dioProvider).get('/doctors/me/profile');
  return Map<String, dynamic>.from(response.data['data'] as Map);
});

class DoctorProfileScreen extends ConsumerWidget {
  const DoctorProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profileAsync = ref.watch(_profileProvider);
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('My Profile'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            onPressed: () => ref.invalidate(_profileProvider),
          ),
        ],
      ),
      body: profileAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, size: 48, color: Colors.red),
              const SizedBox(height: 12),
              Text('Failed to load profile\n$e', textAlign: TextAlign.center),
              const SizedBox(height: 16),
              FilledButton(
                onPressed: () => ref.invalidate(_profileProvider),
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
        data: (doc) => _ProfileContent(doctor: doc),
      ),
    );
  }
}

class _ProfileContent extends ConsumerStatefulWidget {
  const _ProfileContent({required this.doctor});
  final Map<String, dynamic> doctor;

  @override
  ConsumerState<_ProfileContent> createState() => _ProfileContentState();
}

class _ProfileContentState extends ConsumerState<_ProfileContent> {
  bool _editing = false;
  late final TextEditingController _aboutCtrl;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _aboutCtrl = TextEditingController(
        text: widget.doctor['about'] as String? ?? '');
  }

  @override
  void dispose() {
    _aboutCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      await ref.read(dioProvider).patch('/doctors/me/profile', data: {
        'about': _aboutCtrl.text.trim(),
      });
      ref.invalidate(_profileProvider);
      if (mounted) setState(() => _editing = false);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final doc = widget.doctor;
    final theme = Theme.of(context);

    final categories = (doc['categories'] as List? ?? [])
        .map((c) => (c['category'] as Map?)?['name'] as String? ?? '')
        .where((s) => s.isNotEmpty)
        .toList();

    final clinics = (doc['clinics'] as List? ?? [])
        .map((c) => (c['clinic'] as Map?)?['name'] as String? ?? '')
        .where((s) => s.isNotEmpty)
        .toList();

    final languages = (doc['languages'] as List? ?? [])
        .map((l) => l.toString())
        .toList();

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Center(
            child: Column(
              children: [
                CircleAvatar(
                  radius: 48,
                  backgroundColor: theme.colorScheme.primaryContainer,
                  backgroundImage: (doc['avatarUrl'] as String?) != null
                      ? NetworkImage(doc['avatarUrl'] as String)
                      : null,
                  child: (doc['avatarUrl'] as String?) == null
                      ? Text(
                          (doc['name'] as String? ?? 'D')
                              .substring(0, 1)
                              .toUpperCase(),
                          style: const TextStyle(fontSize: 36, fontWeight: FontWeight.bold),
                        )
                      : null,
                ),
                const SizedBox(height: 12),
                Text(
                  'Dr. ${doc['name'] as String? ?? ''}',
                  style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w700),
                ),
                if ((doc['email'] as String?) != null)
                  Text(doc['email'] as String,
                      style: theme.textTheme.bodyMedium?.copyWith(color: Colors.grey)),
                if ((doc['phone'] as String?) != null)
                  Text(doc['phone'] as String,
                      style: theme.textTheme.bodyMedium?.copyWith(color: Colors.grey)),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // Status chip
          Center(
            child: Chip(
              label: Text(
                (doc['verificationStatus'] as String? ?? 'PENDING')
                    .replaceAll('_', ' '),
                style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12),
              ),
              backgroundColor: switch (doc['verificationStatus'] as String? ?? '') {
                'VERIFIED' => Colors.green.withOpacity(0.15),
                'REJECTED' => Colors.red.withOpacity(0.15),
                _ => Colors.orange.withOpacity(0.15),
              },
            ),
          ),
          const SizedBox(height: 24),

          // Specialties
          if (categories.isNotEmpty) ...[
            _SectionTitle('Specialties'),
            Wrap(
              spacing: 8,
              runSpacing: 4,
              children: categories
                  .map((c) => Chip(label: Text(c, style: const TextStyle(fontSize: 12))))
                  .toList(),
            ),
            const SizedBox(height: 16),
          ],

          // Clinics
          if (clinics.isNotEmpty) ...[
            _SectionTitle('Clinics'),
            ...clinics.map((c) => Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Row(children: [
                    const Icon(Icons.location_on_outlined, size: 16, color: Colors.grey),
                    const SizedBox(width: 6),
                    Text(c),
                  ]),
                )),
            const SizedBox(height: 16),
          ],

          // Languages
          if (languages.isNotEmpty) ...[
            _SectionTitle('Languages'),
            Wrap(
              spacing: 8,
              runSpacing: 4,
              children: languages
                  .map((l) => Chip(label: Text(l, style: const TextStyle(fontSize: 12))))
                  .toList(),
            ),
            const SizedBox(height: 16),
          ],

          // About
          Row(
            children: [
              _SectionTitle('About'),
              const Spacer(),
              if (!_editing)
                TextButton.icon(
                  onPressed: () => setState(() => _editing = true),
                  icon: const Icon(Icons.edit_outlined, size: 16),
                  label: const Text('Edit'),
                ),
            ],
          ),
          if (_editing) ...[
            TextField(
              controller: _aboutCtrl,
              maxLines: 5,
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                hintText: 'Write something about yourself…',
              ),
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                    onPressed: _saving ? null : () => setState(() => _editing = false),
                    child: const Text('Cancel')),
                const SizedBox(width: 8),
                FilledButton(
                    onPressed: _saving ? null : _save,
                    child: _saving
                        ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                        : const Text('Save')),
              ],
            ),
          ] else ...[
            Text(
              (doc['about'] as String?) ?? 'No bio added yet.',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: (doc['about'] as String?) == null ? Colors.grey : null,
              ),
            ),
          ],
          const SizedBox(height: 32),

          // Logout
          OutlinedButton.icon(
            onPressed: () async {
              const storage = FlutterSecureStorage(
                aOptions: AndroidOptions(encryptedSharedPreferences: true),
              );
              await storage.deleteAll();
              if (context.mounted) context.go('/login');
            },
            icon: const Icon(Icons.logout_rounded, color: Colors.red),
            label: const Text('Sign Out', style: TextStyle(color: Colors.red)),
            style: OutlinedButton.styleFrom(
              side: const BorderSide(color: Colors.red),
              minimumSize: const Size(double.infinity, 52),
            ),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        text,
        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Colors.grey),
      ),
    );
  }
}
