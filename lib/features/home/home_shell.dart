import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../core/theme/app_theme.dart';
import '../../l10n/generated/app_localizations.dart';
import '../../models/job.dart';
import '../../providers/auth_provider.dart';
import '../../providers/jobs_provider.dart';
import '../../widgets/business_switcher_sheet.dart';
import '../../widgets/language_switcher.dart';
import '../jobs/presentation/job_card.dart';
import '../messaging/presentation/messages_screen.dart';

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
    final l10n = AppLocalizations.of(context);
    final tabTitles = [l10n.tabToday, l10n.tabSchedule, l10n.tabMessages, l10n.tabProfile];

    return Scaffold(
      body: IndexedStack(
        index: _index,
        children: const [
          _TodayTab(),
          _ScheduleTab(),
          MessagesScreen(),
          _ProfileTab(),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (i) => setState(() => _index = i),
        destinations: [
          NavigationDestination(
            icon: const Icon(Icons.today_outlined),
            selectedIcon: const Icon(Icons.today),
            label: l10n.tabToday,
          ),
          NavigationDestination(
            icon: const Icon(Icons.calendar_month_outlined),
            selectedIcon: const Icon(Icons.calendar_month),
            label: l10n.tabSchedule,
          ),
          NavigationDestination(
            icon: const Icon(Icons.message_outlined),
            selectedIcon: const Icon(Icons.message),
            label: l10n.tabMessages,
          ),
          NavigationDestination(
            icon: const Icon(Icons.person_outline),
            selectedIcon: const Icon(Icons.person),
            label: l10n.tabProfile,
          ),
        ],
      ),
      appBar: AppBar(
        title: Text(tabTitles[_index]),
        actions: [
          const Padding(
            padding: EdgeInsets.only(right: 4),
            child: Center(child: LanguageSwitcher()),
          ),
          if (auth.profile?.businessName != null)
            Padding(
              padding: const EdgeInsets.only(right: 4),
              child: Center(
                child: InkWell(
                  borderRadius: BorderRadius.circular(8),
                  onTap: () => showBusinessSwitcherSheet(context),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 6),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          auth.profile!.businessName!,
                          style: const TextStyle(
                            fontSize: 12,
                            color: AppColors.textSecondary,
                          ),
                        ),
                        const SizedBox(width: 2),
                        const Icon(Icons.unfold_more,
                            size: 14, color: AppColors.textSecondary),
                      ],
                    ),
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
    final l10n = AppLocalizations.of(context);
    final now = DateTime.now();
    final dateLabel = DateFormat('EEEE, MMM d', l10n.localeName).format(now);

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
                  Text(l10n.couldNotLoadJobs,
                      style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 8),
                  TextButton(
                    onPressed: () => ref.invalidate(todayJobsProvider),
                    child: Text(l10n.retry),
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
                l10n.jobsTodayCount(jobs.length),
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
              ),
              if (active.isNotEmpty) ...[
                const SizedBox(height: 20),
                _SectionHeader(title: l10n.sectionInProgress, color: AppColors.primary),
                ...active.map((j) => Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: JobCard(job: j),
                    )),
              ],
              if (upcoming.isNotEmpty) ...[
                const SizedBox(height: 12),
                _SectionHeader(title: l10n.sectionUpcoming, color: AppColors.info),
                ...upcoming.map((j) => Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: JobCard(job: j),
                    )),
              ],
              if (done.isNotEmpty) ...[
                const SizedBox(height: 12),
                _SectionHeader(
                    title: l10n.sectionCompletedCancelled, color: AppColors.textSecondary),
                ...done.map((j) => Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: JobCard(job: j),
                    )),
              ],
              if (jobs.isEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 60),
                  child: Center(
                    child: Column(
                      children: [
                        const Icon(Icons.event_available,
                            size: 56, color: AppColors.textSecondary),
                        const SizedBox(height: 12),
                        Text(l10n.noJobsScheduledToday),
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
    final l10n = AppLocalizations.of(context);

    return RefreshIndicator(
      onRefresh: () async => ref.invalidate(upcomingJobsProvider),
      child: jobsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
          child: TextButton(
            onPressed: () => ref.invalidate(upcomingJobsProvider),
            child: Text(l10n.retry),
          ),
        ),
        data: (jobs) {
          if (jobs.isEmpty) {
            return ListView(
              children: [
                const SizedBox(height: 80),
                Center(child: Text(l10n.noUpcomingJobs)),
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
              final label = DateFormat('EEEE, MMM d', l10n.localeName).format(date);

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
    final l10n = AppLocalizations.of(context);

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
                        user?.fullName ?? l10n.cleanerFallbackName,
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
                title: Text(l10n.status),
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
                title: Text(l10n.phone),
                subtitle: Text(user?.phone ?? l10n.notSet),
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
                title: Text(l10n.editProfileTitle),
                subtitle: Text(l10n.photoAndPhoneNumber),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => context.push('/home/profile'),
              ),
              const Divider(height: 1),
              ListTile(
                leading: const Icon(Icons.calendar_month_outlined, color: AppColors.primary),
                title: Text(l10n.availabilityTitle),
                subtitle: Text(l10n.availabilitySubtitle),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => context.push('/home/profile/availability'),
              ),
              const Divider(height: 1),
              ListTile(
                leading: const Icon(Icons.folder_outlined, color: AppColors.primary),
                title: Text(l10n.documentsTitle),
                subtitle: Text(l10n.documentsSubtitle),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => context.push('/home/profile/documents'),
              ),
              const Divider(height: 1),
              ListTile(
                leading: const Icon(Icons.payments_outlined, color: AppColors.primary),
                title: Text(l10n.earningsTitle),
                subtitle: Text(l10n.valueOfCompletedJobs),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => context.push('/home/profile/earnings'),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        Card(
          child: ListTile(
            leading: const Icon(Icons.swap_horiz, color: AppColors.primary),
            title: Text(l10n.switchBusiness),
            subtitle: Text(l10n.switchBusinessSubtitle),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => showBusinessSwitcherSheet(context),
          ),
        ),
        const SizedBox(height: 24),
        OutlinedButton.icon(
          onPressed: () async {
            await ref.read(authProvider.notifier).logout();
            if (context.mounted) context.go('/login');
          },
          icon: const Icon(Icons.logout),
          label: Text(l10n.signOut),
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
