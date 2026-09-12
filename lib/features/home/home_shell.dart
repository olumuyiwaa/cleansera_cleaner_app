import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../core/theme/app_theme.dart';
import '../../models/job.dart';
import '../../providers/auth_provider.dart';
import '../../providers/jobs_provider.dart';
import '../jobs/presentation/job_card.dart';

class HomeShell extends ConsumerStatefulWidget {
  const HomeShell({super.key});

  @override
  ConsumerState<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends ConsumerState<HomeShell> {
  int _index = 0;

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(authProvider);

    return Scaffold(
      body: IndexedStack(
        index: _index,
        children: const [
          _TodayTab(),
          _ScheduleTab(),
          _ProfileTab(),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (i) => setState(() => _index = i),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.today_outlined),
            selectedIcon: Icon(Icons.today),
            label: 'Today',
          ),
          NavigationDestination(
            icon: Icon(Icons.calendar_month_outlined),
            selectedIcon: Icon(Icons.calendar_month),
            label: 'Schedule',
          ),
          NavigationDestination(
            icon: Icon(Icons.person_outline),
            selectedIcon: Icon(Icons.person),
            label: 'Profile',
          ),
        ],
      ),
      appBar: AppBar(
        title: Text(
          _index == 0
              ? 'Today'
              : _index == 1
                  ? 'Schedule'
                  : 'Profile',
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.forum_outlined),
            tooltip: 'Messages',
            onPressed: () => context.push('/home/messages'),
          ),
          if (auth.profile?.businessName != null)
            Padding(
              padding: const EdgeInsets.only(right: 12),
              child: Center(
                child: Text(
                  auth.profile!.businessName!,
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.textSecondary,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _TodayTab extends ConsumerWidget {
  const _TodayTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final jobsAsync = ref.watch(todayJobsProvider);
    final now = DateTime.now();
    final dateLabel = DateFormat('EEEE, MMM d').format(now);

    return RefreshIndicator(
      onRefresh: () async => ref.invalidate(todayJobsProvider),
      child: jobsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => ListView(
          children: [
            const SizedBox(height: 80),
            Center(
              child: Column(
                children: [
                  const Icon(Icons.error_outline,
                      size: 48, color: AppColors.error),
                  const SizedBox(height: 12),
                  Text('Could not load jobs',
                      style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 8),
                  TextButton(
                    onPressed: () => ref.invalidate(todayJobsProvider),
                    child: const Text('Retry'),
                  ),
                ],
              ),
            ),
          ],
        ),
        data: (jobs) {
          final active = jobs.where((j) => j.isActive).toList();
          final upcoming = jobs
              .where((j) =>
                  j.status != JobStatus.completed &&
                  j.status != JobStatus.cancelled &&
                  !j.isActive)
              .toList();
          final done = jobs
              .where((j) =>
                  j.status == JobStatus.completed ||
                  j.status == JobStatus.cancelled)
              .toList();

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Text(
                dateLabel,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: AppColors.textSecondary,
                    ),
              ),
              const SizedBox(height: 8),
              Text(
                '${jobs.length} job${jobs.length == 1 ? '' : 's'} today',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
              ),
              if (active.isNotEmpty) ...[
                const SizedBox(height: 20),
                const _SectionHeader(title: 'In progress', color: AppColors.primary),
                ...active.map((j) => Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: JobCard(job: j),
                    )),
              ],
              if (upcoming.isNotEmpty) ...[
                const SizedBox(height: 12),
                const _SectionHeader(title: 'Upcoming', color: AppColors.info),
                ...upcoming.map((j) => Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: JobCard(job: j),
                    )),
              ],
              if (done.isNotEmpty) ...[
                const SizedBox(height: 12),
                const _SectionHeader(
                    title: 'Completed / cancelled', color: AppColors.textSecondary),
                ...done.map((j) => Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: JobCard(job: j),
                    )),
              ],
              if (jobs.isEmpty)
                const Padding(
                  padding: EdgeInsets.only(top: 60),
                  child: Center(
                    child: Column(
                      children: [
                        Icon(Icons.event_available,
                            size: 56, color: AppColors.textSecondary),
                        SizedBox(height: 12),
                        Text('No jobs scheduled for today'),
                      ],
                    ),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}

class _ScheduleTab extends ConsumerWidget {
  const _ScheduleTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final jobsAsync = ref.watch(upcomingJobsProvider);

    return RefreshIndicator(
      onRefresh: () async => ref.invalidate(upcomingJobsProvider),
      child: jobsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
          child: TextButton(
            onPressed: () => ref.invalidate(upcomingJobsProvider),
            child: const Text('Retry'),
          ),
        ),
        data: (jobs) {
          if (jobs.isEmpty) {
            return ListView(
              children: const [
                SizedBox(height: 80),
                Center(child: Text('No upcoming jobs')),
              ],
            );
          }

          // Group by day
          final Map<String, List<Job>> byDay = {};
          for (final j in jobs) {
            final key = DateFormat('yyyy-MM-dd').format(j.scheduledStart);
            byDay.putIfAbsent(key, () => []).add(j);
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: byDay.length,
            itemBuilder: (context, index) {
              final key = byDay.keys.elementAt(index);
              final dayJobs = byDay[key]!;
              final date = DateTime.parse(key);
              final label = DateFormat('EEEE, MMM d').format(date);

              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Text(
                      label,
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.w600,
                            color: AppColors.textSecondary,
                          ),
                    ),
                  ),
                  ...dayJobs.map((j) => Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: JobCard(job: j),
                      )),
                ],
              );
            },
          );
        },
      ),
    );
  }
}

class _ProfileTab extends ConsumerWidget {
  const _ProfileTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final auth = ref.watch(authProvider);
    final user = auth.user;
    final profile = auth.profile;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 32,
                  backgroundColor: AppColors.primary.withValues(alpha: 0.15),
                  child: Text(
                    user?.initials ?? '?',
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: AppColors.primary,
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        user?.fullName ?? 'Cleaner',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                      ),
                      if (user?.email != null)
                        Text(
                          user!.email,
                          style: const TextStyle(color: AppColors.textSecondary),
                        ),
                      if (profile?.businessName != null) ...[
                        const SizedBox(height: 4),
                        Text(
                          profile!.businessName!,
                          style: const TextStyle(
                            color: AppColors.primary,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        Card(
          child: Column(
            children: [
              ListTile(
                leading: const Icon(Icons.badge_outlined),
                title: const Text('Status'),
                trailing: Chip(
                  label: Text(
                    profile?.status.name.toUpperCase() ?? '—',
                    style: const TextStyle(fontSize: 12),
                  ),
                  backgroundColor: profile?.isActive == true
                      ? AppColors.success.withValues(alpha: 0.15)
                      : AppColors.warning.withValues(alpha: 0.15),
                ),
              ),
              const Divider(height: 1),
              ListTile(
                leading: const Icon(Icons.phone_outlined),
                title: const Text('Phone'),
                subtitle: Text(user?.phone ?? 'Not set'),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        Card(
          child: Column(
            children: [
              ListTile(
                leading: const Icon(Icons.edit_outlined, color: AppColors.primary),
                title: const Text('Edit profile'),
                subtitle: const Text('Photo and phone number'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => context.push('/home/profile'),
              ),
              const Divider(height: 1),
              ListTile(
                leading: const Icon(Icons.calendar_month_outlined, color: AppColors.primary),
                title: const Text('Availability'),
                subtitle: const Text('Set the hours you can be booked'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => context.push('/home/profile/availability'),
              ),
              const Divider(height: 1),
              ListTile(
                leading: const Icon(Icons.folder_outlined, color: AppColors.primary),
                title: const Text('Documents'),
                subtitle: const Text('ID, certifications, and insurance'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => context.push('/home/profile/documents'),
              ),
              const Divider(height: 1),
              ListTile(
                leading: const Icon(Icons.payments_outlined, color: AppColors.primary),
                title: const Text('Earnings'),
                subtitle: const Text('Value of jobs you\'ve completed'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => context.push('/home/profile/earnings'),
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),
        OutlinedButton.icon(
          onPressed: () async {
            await ref.read(authProvider.notifier).logout();
            if (context.mounted) context.go('/login');
          },
          icon: const Icon(Icons.logout),
          label: const Text('Sign out'),
          style: OutlinedButton.styleFrom(
            foregroundColor: AppColors.error,
            side: const BorderSide(color: AppColors.error),
          ),
        ),
      ],
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title, required this.color});

  final String title;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Container(
            width: 4,
            height: 16,
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(width: 8),
          Text(
            title,
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: color,
                ),
          ),
        ],
      ),
    );
  }
}
