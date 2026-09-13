import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/theme/app_theme.dart';
import '../../../models/job.dart';
import '../../../providers/jobs_provider.dart';

/// Before/after photo proof. AFTER photos are required before a job can be
/// marked complete (enforced server-side too — see bookings.service.js
/// completeBookingByCleaner), so this section doubles as the explanation
/// for why "Complete job" is disabled until at least one is added.
class JobPhotosSection extends ConsumerStatefulWidget {
  const JobPhotosSection({super.key, required this.job});

  final Job job;

  @override
  ConsumerState<JobPhotosSection> createState() => _JobPhotosSectionState();
}

class _JobPhotosSectionState extends ConsumerState<JobPhotosSection> {
  bool _capturing = false;

  Future<void> _capture(String stage) async {
    final picker = ImagePicker();
    final XFile? shot = await picker.pickImage(
      source: ImageSource.camera,
      maxWidth: 1600,
      imageQuality: 82,
    );
    if (shot == null) return;

    setState(() => _capturing = true);
    try {
      final bytes = await shot.readAsBytes();
      final ok = await ref.read(jobActionsProvider.notifier).uploadJobPhoto(
            widget.job.id,
            stage: stage,
            bytes: bytes,
            filename: shot.name,
          );
      if (!ok && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Photo upload failed — check your connection and try again.')),
        );
      }
    } finally {
      if (mounted) setState(() => _capturing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final before = widget.job.photos.where((p) => p.stage == 'BEFORE').toList();
    final after = widget.job.photos.where((p) => p.stage == 'AFTER').toList();

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Photo proof',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 4),
            Text(
              'Add at least one after-photo before you can mark this job complete.',
              style: const TextStyle(color: AppColors.textSecondary, fontSize: 12),
            ),
            const SizedBox(height: 12),
            _StageRow(
              label: 'Before',
              count: before.length,
              busy: _capturing,
              onAdd: () => _capture('BEFORE'),
            ),
            const SizedBox(height: 8),
            _StageRow(
              label: 'After',
              count: after.length,
              required: true,
              busy: _capturing,
              onAdd: () => _capture('AFTER'),
            ),
          ],
        ),
      ),
    );
  }
}

class _StageRow extends StatelessWidget {
  const _StageRow({
    required this.label,
    required this.count,
    required this.busy,
    required this.onAdd,
    this.required = false,
  });

  final String label;
  final int count;
  final bool busy;
  final bool required;
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    final satisfied = !required || count > 0;
    return Row(
      children: [
        Icon(
          satisfied ? Icons.check_circle : Icons.radio_button_unchecked,
          size: 18,
          color: satisfied ? AppColors.success : AppColors.textSecondary,
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            count == 0 ? '$label photo' : '$label photo · $count added',
            style: const TextStyle(fontSize: 14),
          ),
        ),
        TextButton.icon(
          onPressed: busy ? null : onAdd,
          icon: const Icon(Icons.camera_alt_outlined, size: 18),
          label: Text(count == 0 ? 'Add' : 'Add another'),
        ),
      ],
    );
  }
}
