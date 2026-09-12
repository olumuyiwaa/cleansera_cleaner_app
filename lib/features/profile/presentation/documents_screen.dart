import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/theme/app_theme.dart';
import '../../../models/cleaner_document.dart';
import '../../../providers/profile_provider.dart';
import '../data/profile_repository.dart';

class DocumentsScreen extends ConsumerWidget {
  const DocumentsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final documentsAsync = ref.watch(documentsProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Documents')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showUploadSheet(context, ref),
        icon: const Icon(Icons.add),
        label: const Text('Add document'),
      ),
      body: documentsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text('Failed to load documents'),
              TextButton(
                onPressed: () => ref.invalidate(documentsProvider),
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
        data: (docs) {
          if (docs.isEmpty) {
            return Center(
              child: Text(
                'No documents yet.\nTap "Add document" to upload your ID, a\ncertification, or proof of insurance.',
                textAlign: TextAlign.center,
                style: TextStyle(color: AppColors.textSecondary),
              ),
            );
          }
          return ListView.builder(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
            itemCount: docs.length,
            itemBuilder: (context, i) => _DocumentTile(document: docs[i]),
          );
        },
      ),
    );
  }

  void _showUploadSheet(BuildContext context, WidgetRef ref) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (_) => const _UploadDocumentSheet(),
    );
  }
}

class _DocumentTile extends ConsumerWidget {
  const _DocumentTile({required this.document});

  final CleanerDocument document;

  Future<void> _open(BuildContext context, WidgetRef ref) async {
    try {
      final url = await ref
          .read(profileRepositoryProvider)
          .getDocumentDownloadUrl(document.id);
      final uri = Uri.parse(url);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      }
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not open document')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dateFmt = DateFormat('MMM d, yyyy');
    Color statusColor = AppColors.textSecondary;
    String? statusLabel;
    if (document.isExpired) {
      statusColor = AppColors.error;
      statusLabel = 'Expired';
    } else if (document.isExpiringSoon) {
      statusColor = AppColors.warning;
      statusLabel = 'Expiring soon';
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: ListTile(
        leading: const Icon(Icons.description_outlined, color: AppColors.primary),
        title: Text(document.title),
        subtitle: Text(
          [
            docTypeLabel(document.type),
            if (document.expiresAt != null)
              'Expires ${dateFmt.format(document.expiresAt!)}',
          ].join(' · '),
        ),
        trailing: statusLabel != null
            ? Chip(
                label: Text(statusLabel, style: const TextStyle(fontSize: 11)),
                backgroundColor: statusColor.withOpacity(0.12),
                labelStyle: TextStyle(color: statusColor),
                visualDensity: VisualDensity.compact,
              )
            : const Icon(Icons.chevron_right),
        onTap: () => _open(context, ref),
      ),
    );
  }
}

class _UploadDocumentSheet extends ConsumerStatefulWidget {
  const _UploadDocumentSheet();

  @override
  ConsumerState<_UploadDocumentSheet> createState() =>
      _UploadDocumentSheetState();
}

class _UploadDocumentSheetState extends ConsumerState<_UploadDocumentSheet> {
  final _titleController = TextEditingController();
  String _type = selfServiceDocTypes.first;
  File? _file;
  DateTime? _expiresAt;

  @override
  void dispose() {
    _titleController.dispose();
    super.dispose();
  }

  Future<void> _pickFile() async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(source: ImageSource.camera, imageQuality: 85);
    final fallback = picked ??
        await picker.pickImage(source: ImageSource.gallery, imageQuality: 85);
    if (fallback != null) {
      setState(() => _file = File(fallback.path));
    }
  }

  Future<void> _pickExpiry() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now().add(const Duration(days: 365)),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 3650)),
    );
    if (picked != null) setState(() => _expiresAt = picked);
  }

  Future<void> _submit() async {
    if (_file == null || _titleController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Add a title and a photo of the document')),
      );
      return;
    }
    final ok = await ref.read(profileActionsProvider.notifier).uploadDocument(
          file: _file!,
          title: _titleController.text.trim(),
          type: _type,
          expiresAt: _expiresAt,
        );
    if (!mounted) return;
    if (ok) {
      Navigator.of(context).pop();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Upload failed. Try again.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final actionsState = ref.watch(profileActionsProvider);
    final busy = actionsState.isLoading;

    return Padding(
      padding: EdgeInsets.fromLTRB(
        16,
        16,
        16,
        16 + MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Add document', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 16),
          DropdownButtonFormField<String>(
            value: _type,
            decoration: const InputDecoration(labelText: 'Type', border: OutlineInputBorder()),
            items: selfServiceDocTypes
                .map((t) => DropdownMenuItem(value: t, child: Text(docTypeLabel(t))))
                .toList(),
            onChanged: (v) => setState(() => _type = v ?? _type),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _titleController,
            decoration: const InputDecoration(labelText: 'Title', border: OutlineInputBorder()),
          ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: _pickExpiry,
            icon: const Icon(Icons.event_outlined),
            label: Text(_expiresAt == null
                ? 'Set expiry date (optional)'
                : 'Expires ${DateFormat('MMM d, yyyy').format(_expiresAt!)}'),
          ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: _pickFile,
            icon: const Icon(Icons.camera_alt_outlined),
            label: Text(_file == null ? 'Take or choose a photo' : 'Photo selected'),
          ),
          const SizedBox(height: 20),
          ElevatedButton(
            onPressed: busy ? null : _submit,
            child: Text(busy ? 'Uploading…' : 'Upload'),
          ),
        ],
      ),
    );
  }
}
