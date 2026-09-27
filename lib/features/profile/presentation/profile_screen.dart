import 'dart:io';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/theme/app_theme.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../../../models/cleaner_profile.dart';
import '../../../providers/profile_provider.dart';

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profileAsync = ref.watch(cleanerProfileProvider);
    final l10n = AppLocalizations.of(context);

    return Scaffold(
      appBar: AppBar(title: Text(l10n.editProfileTitle)),
      body: profileAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(l10n.failedToLoadProfile),
              TextButton(
                onPressed: () => ref.invalidate(cleanerProfileProvider),
                child: Text(l10n.retry),
              ),
            ],
          ),
        ),
        data: (profile) => _ProfileForm(profile: profile),
      ),
    );
  }
}

class _ProfileForm extends ConsumerStatefulWidget {
  const _ProfileForm({required this.profile});

  final CleanerProfile profile;

  @override
  ConsumerState<_ProfileForm> createState() => _ProfileFormState();
}

class _ProfileFormState extends ConsumerState<_ProfileForm> {
  late final TextEditingController _phoneController;
  File? _pendingAvatar;

  @override
  void initState() {
    super.initState();
    _phoneController = TextEditingController(text: widget.profile.user?.phone ?? '');
  }

  @override
  void dispose() {
    _phoneController.dispose();
    super.dispose();
  }

  Future<void> _pickAvatar() async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 800,
      imageQuality: 85,
    );
    if (picked != null) {
      setState(() => _pendingAvatar = File(picked.path));
    }
  }

  Future<void> _save() async {
    final l10n = AppLocalizations.of(context);
    final ok = await ref.read(profileActionsProvider.notifier).updateProfile(
          phone: _phoneController.text.trim(),
          avatarFile: _pendingAvatar,
        );
    if (!mounted) return;
    if (ok) {
      setState(() => _pendingAvatar = null);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.profileUpdated)),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.profileUpdateFailed)),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final profile = widget.profile;
    final user = profile.user;
    final actionsState = ref.watch(profileActionsProvider);
    final busy = actionsState.isLoading;
    final l10n = AppLocalizations.of(context);

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Center(
          child: Stack(
            children: [
              CircleAvatar(
                radius: 48,
                backgroundColor: AppColors.primaryLight,
                backgroundImage: _pendingAvatar != null
                    ? FileImage(_pendingAvatar!) as ImageProvider
                    : (user?.avatarUrl != null
                        ? CachedNetworkImageProvider(user!.avatarUrl!)
                        : null),
                child: _pendingAvatar == null && user?.avatarUrl == null
                    ? Text(
                        user?.initials ?? '?',
                        style: const TextStyle(fontSize: 28, color: Colors.white),
                      )
                    : null,
              ),
              Positioned(
                bottom: 0,
                right: 0,
                child: InkWell(
                  onTap: _pickAvatar,
                  child: Container(
                    padding: const EdgeInsets.all(6),
                    decoration: const BoxDecoration(
                      color: AppColors.primary,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.camera_alt, size: 16, color: Colors.white),
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),
        _ReadOnlyField(label: l10n.name, value: user?.fullName ?? '—'),
        const SizedBox(height: 12),
        _ReadOnlyField(label: l10n.email, value: user?.email ?? '—'),
        const SizedBox(height: 12),
        _ReadOnlyField(label: l10n.business, value: profile.businessName ?? '—'),
        const SizedBox(height: 20),
        Text(l10n.phone, style: Theme.of(context).textTheme.labelLarge),
        const SizedBox(height: 6),
        TextField(
          controller: _phoneController,
          keyboardType: TextInputType.phone,
          decoration: InputDecoration(
            border: const OutlineInputBorder(),
            hintText: l10n.phoneHint,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          l10n.nameEmailManagedByBusiness,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: AppColors.textSecondary,
              ),
        ),
        const SizedBox(height: 24),
        ElevatedButton(
          onPressed: busy ? null : _save,
          child: Text(busy ? l10n.saving : l10n.saveChanges),
        ),
        const SizedBox(height: 24),
        const Divider(),
        ListTile(
          leading: const Icon(Icons.calendar_month_outlined, color: AppColors.primary),
          title: Text(l10n.availabilityTitle),
          subtitle: Text(l10n.availabilitySubtitle),
          trailing: const Icon(Icons.chevron_right),
          onTap: () => context.push('/home/profile/availability'),
        ),
        ListTile(
          leading: const Icon(Icons.folder_outlined, color: AppColors.primary),
          title: Text(l10n.documentsTitle),
          subtitle: Text(l10n.documentsSubtitle),
          trailing: const Icon(Icons.chevron_right),
          onTap: () => context.push('/home/profile/documents'),
        ),
      ],
    );
  }
}

class _ReadOnlyField extends StatelessWidget {
  const _ReadOnlyField({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: Theme.of(context).textTheme.labelLarge),
        const SizedBox(height: 4),
        Text(
          value,
          style: const TextStyle(color: AppColors.textSecondary),
        ),
      ],
    );
  }
}
