import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../features/profile/data/profile_repository.dart';
import '../models/availability_slot.dart';
import '../models/cleaner_document.dart';
import '../models/cleaner_profile.dart';
import 'auth_provider.dart';

final cleanerProfileProvider =
    FutureProvider.autoDispose<CleanerProfile>((ref) async {
  final repo = ref.watch(profileRepositoryProvider);
  return repo.fetchProfile();
});

final availabilityProvider =
    FutureProvider.autoDispose<List<AvailabilitySlot>>((ref) async {
  final repo = ref.watch(profileRepositoryProvider);
  return repo.fetchAvailability();
});

final documentsProvider =
    FutureProvider.autoDispose<List<CleanerDocument>>((ref) async {
  final repo = ref.watch(profileRepositoryProvider);
  return repo.fetchDocuments();
});

class ProfileActionsNotifier extends StateNotifier<AsyncValue<void>> {
  ProfileActionsNotifier(this._repo, this._ref) : super(const AsyncData(null));

  final ProfileRepository _repo;
  final Ref _ref;

  Future<bool> updateProfile({String? phone, File? avatarFile}) async {
    state = const AsyncLoading();
    try {
      String? avatarKey;
      if (avatarFile != null) {
        avatarKey = await _repo.uploadAvatar(avatarFile);
      }
      await _repo.updateProfile(phone: phone, avatarKey: avatarKey);
      _ref.invalidate(cleanerProfileProvider);
      // Keep the cached auth profile (used for the bottom-nav tab) in sync
      // too, rather than only updating the dedicated profile screen's copy.
      await _ref.read(authProvider.notifier).refreshCleanerProfile();
      state = const AsyncData(null);
      return true;
    } catch (e, st) {
      state = AsyncError(e, st);
      return false;
    }
  }

  Future<bool> updateAvailability(List<AvailabilitySlot> slots) async {
    state = const AsyncLoading();
    try {
      await _repo.updateAvailability(slots);
      _ref.invalidate(availabilityProvider);
      state = const AsyncData(null);
      return true;
    } catch (e, st) {
      state = AsyncError(e, st);
      return false;
    }
  }

  Future<bool> uploadDocument({
    required File file,
    required String title,
    required String type,
    DateTime? expiresAt,
    String? notes,
  }) async {
    state = const AsyncLoading();
    try {
      await _repo.uploadDocument(
        file: file,
        title: title,
        type: type,
        expiresAt: expiresAt,
        notes: notes,
      );
      _ref.invalidate(documentsProvider);
      state = const AsyncData(null);
      return true;
    } catch (e, st) {
      state = AsyncError(e, st);
      return false;
    }
  }
}

final profileActionsProvider =
    StateNotifierProvider<ProfileActionsNotifier, AsyncValue<void>>((ref) {
  return ProfileActionsNotifier(ref.watch(profileRepositoryProvider), ref);
});
