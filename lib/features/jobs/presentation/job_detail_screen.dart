import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/theme/app_theme.dart';
import '../../../models/job.dart';
import '../../../providers/jobs_provider.dart';
import '../../checklist/checklist_section.dart';
import 'job_photos_section.dart';

class JobDetailScreen extends ConsumerWidget {
  const JobDetailScreen({super.key, required this.jobId});

  final String jobId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final jobAsync = ref.watch(jobDetailProvider(jobId));
    final actions = ref.watch(jobActionsProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Job details')),
      body: jobAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text('Failed to load job'),
              TextButton(
                onPressed: () => ref.invalidate(jobDetailProvider(jobId)),
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
        data: (job) => _JobBody(job: job, actionsState: actions),
      ),
    );
  }
}

class _JobBody extends ConsumerWidget {
  const _JobBody({required this.job, required this.actionsState});

  final Job job;
  final AsyncValue<void> actionsState;

  Future<void> _checkIn(WidgetRef ref) async {
    double? lat;
    double? lng;
    try {
      final permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        await Geolocator.requestPermission();
      }
      final pos = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.medium,
      );
      lat = pos.latitude;
      lng = pos.longitude;
    } catch (_) {
      // continue without location
    }
    await ref.read(jobActionsProvider.notifier).checkIn(
          job.id,
          lat: lat,
          lng: lng,
        );
  }

  Future<void> _openMaps() async {
    final addr = job.address;
    if (addr == null) return;
    final query = Uri.encodeComponent(addr.fullAddress);
    final uri = Uri.parse('https://www.google.com/maps/search/?api=1&query=$query');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  Future<void> _callCustomer() async {
    final phone = job.customer?.phone;
    if (phone == null || phone.isEmpty) return;
    final uri = Uri.parse('tel:$phone');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final timeFmt = DateFormat('EEE, MMM d · h:mm a');
    final busy = actionsState.isLoading;

    return Column(
      children: [
        Expanded(
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Text(
                job.service?.name ?? 'Cleaning job',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
              ),
              const SizedBox(height: 8),
              Text(
                timeFmt.format(job.scheduledStart),
                style: const TextStyle(color: AppColors.textSecondary),
              ),
              const SizedBox(height: 16),
              if (job.customer != null)
                Card(
                  child: ListTile(
                    leading: const CircleAvatar(
                      child: Icon(Icons.person),
                    ),
                    title: Text(job.customer!.fullName),
                    subtitle: Text(job.customer!.phone ?? ''),
                    trailing: job.customer!.phone != null
                        ? IconButton(
                            icon: const Icon(Icons.phone, color: AppColors.primary),
                            onPressed: _callCustomer,
                          )
                        : null,
                  ),
                ),
              if (job.address != null) ...[
                const SizedBox(height: 12),
                Card(
                  child: ListTile(
                    leading: const Icon(Icons.location_on_outlined,
                        color: AppColors.primary),
                    title: const Text('Address'),
                    subtitle: Text(job.address!.fullAddress),
                    trailing: IconButton(
                      icon: const Icon(Icons.map_outlined),
                      onPressed: _openMaps,
                    ),
                  ),
                ),
              ],
              if (job.hasSiteNotes) ...[
                const SizedBox(height: 12),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Property notes',
                          style: Theme.of(context).textTheme.titleSmall,
                        ),
                        const SizedBox(height: 10),
                        if (job.accessCode != null && job.accessCode!.isNotEmpty)
                          _PropertyNoteRow(
                            icon: Icons.pin_outlined,
                            label: 'Access code',
                            value: job.accessCode!,
                          ),
                        if (job.keyLocation != null && job.keyLocation!.isNotEmpty)
                          _PropertyNoteRow(
                            icon: Icons.key_outlined,
                            label: 'Key location',
                            value: job.keyLocation!,
                          ),
                        if (job.parkingInstructions != null &&
                            job.parkingInstructions!.isNotEmpty)
                          _PropertyNoteRow(
                            icon: Icons.local_parking_outlined,
                            label: 'Parking',
                            value: job.parkingInstructions!,
                          ),
                        if (job.petNotes != null && job.petNotes!.isNotEmpty)
                          _PropertyNoteRow(
                            icon: Icons.pets_outlined,
                            label: 'Pets',
                            value: job.petNotes!,
                          ),
                        if (job.notes != null && job.notes!.isNotEmpty)
                          _PropertyNoteRow(
                            icon: Icons.notes_outlined,
                            label: 'Notes',
                            value: job.notes!,
                          ),
                      ],
                    ),
                  ),
                ),
              ],
              const SizedBox(height: 16),
              ChecklistSection(bookingId: job.id),
              const SizedBox(height: 12),
              JobPhotosSection(job: job),
            ],
          ),
        ),
        SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
            child: Column(
              children: [
                if (actionsState.hasError)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Text(
                      'Action failed. Please try again.',
                      style: TextStyle(color: AppColors.error),
                    ),
                  ),
                if (job.canSendOnMyWay)
                  OutlinedButton.icon(
                    onPressed: busy
                        ? null
                        : () async {
                            final ok = await ref
                                .read(jobActionsProvider.notifier)
                                .sendOnMyWay(job.id);
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(
                                    ok
                                        ? "Customer notified you're on your way"
                                        : "Couldn't send notification. Try again.",
                                  ),
                                ),
                              );
                            }
                          },
                    icon: const Icon(Icons.directions_car_outlined),
                    label: Text(busy ? 'Working…' : "On my way"),
                  ),
                if (job.canSendOnMyWay) const SizedBox(height: 8),
                if (job.canCheckIn)
                  ElevatedButton.icon(
                    onPressed: busy ? null : () => _checkIn(ref),
                    icon: const Icon(Icons.login),
                    label: Text(busy ? 'Working…' : 'Check in'),
                  ),
                if (job.canStart && !job.canCheckIn)
                  ElevatedButton.icon(
                    onPressed: busy
                        ? null
                        : () => ref.read(jobActionsProvider.notifier).start(job.id),
                    icon: const Icon(Icons.play_arrow),
                    label: Text(busy ? 'Working…' : 'Start job'),
                  ),
                if (job.canComplete) ...[
                  const SizedBox(height: 8),
                  if (!job.hasAfterPhoto)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Text(
                        'Add an after-photo above to finish this job.',
                        style: const TextStyle(color: AppColors.textSecondary, fontSize: 12),
                      ),
                    ),
                  ElevatedButton.icon(
                    onPressed: busy || !job.hasAfterPhoto
                        ? null
                        : () => ref
                            .read(jobActionsProvider.notifier)
                            .complete(job.id),
                    icon: const Icon(Icons.check_circle_outline),
                    label: Text(busy ? 'Working…' : 'Complete job'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.success,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _PropertyNoteRow extends StatelessWidget {
  const _PropertyNoteRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: AppColors.primary),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.textSecondary,
                  ),
                ),
                Text(value),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
