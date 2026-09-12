import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/api_constants.dart';
import '../../../core/network/dio_client.dart';
import '../../../models/availability_slot.dart';
import '../../../models/cleaner_document.dart';
import '../../../models/cleaner_profile.dart';

class ProfileRepository {
  ProfileRepository(this._dio);

  final Dio _dio;

  Future<CleanerProfile> fetchProfile() async {
    final res = await _dio.get(ApiConstants.cleanerMe);
    return CleanerProfile.fromJson(unwrapEnvelope(res.data));
  }

  Future<CleanerProfile> updateProfile({String? phone, String? avatarKey}) async {
    final res = await _dio.put(
      ApiConstants.cleanerMe,
      data: {
        if (phone != null) 'phone': phone,
        if (avatarKey != null) 'avatarKey': avatarKey,
      },
    );
    return CleanerProfile.fromJson(unwrapEnvelope(res.data));
  }

  /// Uploads [file] directly to the presigned URL the backend hands back,
  /// then returns the storage key so the caller can save it onto the
  /// profile (or a document record) in a second call.
  Future<String> uploadAvatar(File file) async {
    final upload = unwrapEnvelope(
      (await _dio.post(
        '${ApiConstants.cleanerMe}/avatar-upload-url',
        data: {'contentType': 'image/jpeg', 'filename': file.path.split('/').last},
      ))
          .data,
    );
    final uploadUrl = upload['uploadUrl'] as String;
    final avatarKey = upload['avatarKey'] as String;

    await Dio().put(
      uploadUrl,
      data: file.openRead(),
      options: Options(
        headers: {
          'Content-Type': 'image/jpeg',
          Headers.contentLengthHeader: await file.length(),
        },
      ),
    );

    return avatarKey;
  }

  Future<List<AvailabilitySlot>> fetchAvailability() async {
    final res = await _dio.get(ApiConstants.cleanerAvailability);
    final list = unwrapListEnvelope(res.data);
    return list
        .map((e) => AvailabilitySlot.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<List<AvailabilitySlot>> updateAvailability(
      List<AvailabilitySlot> slots) async {
    final res = await _dio.put(
      ApiConstants.cleanerAvailability,
      data: {'slots': slots.map((s) => s.toJson()).toList()},
    );
    final list = unwrapListEnvelope(res.data);
    return list
        .map((e) => AvailabilitySlot.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<List<CleanerDocument>> fetchDocuments() async {
    final res = await _dio.get(ApiConstants.cleanerDocuments);
    final list = unwrapListEnvelope(res.data);
    return list
        .map((e) => CleanerDocument.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<CleanerDocument> uploadDocument({
    required File file,
    required String title,
    required String type,
    String? mimeType,
    DateTime? expiresAt,
    String? notes,
  }) async {
    final upload = unwrapEnvelope(
      (await _dio.post(
        '${ApiConstants.cleanerDocuments}/upload-url',
        data: {
          'contentType': mimeType ?? 'image/jpeg',
          'filename': file.path.split('/').last,
        },
      ))
          .data,
    );
    final uploadUrl = upload['uploadUrl'] as String;
    final storageKey = upload['storageKey'] as String;
    final fileSize = await file.length();

    await Dio().put(
      uploadUrl,
      data: file.openRead(),
      options: Options(
        headers: {
          'Content-Type': mimeType ?? 'image/jpeg',
          Headers.contentLengthHeader: fileSize,
        },
      ),
    );

    final res = await _dio.post(
      ApiConstants.cleanerDocuments,
      data: {
        'title': title,
        'storageKey': storageKey,
        'type': type,
        'mimeType': mimeType ?? 'image/jpeg',
        'fileSize': fileSize,
        if (expiresAt != null) 'expiresAt': expiresAt.toIso8601String(),
        if (notes != null) 'notes': notes,
      },
    );
    return CleanerDocument.fromJson(unwrapEnvelope(res.data));
  }

  Future<String> getDocumentDownloadUrl(String id) async {
    final res =
        await _dio.get('${ApiConstants.cleanerDocuments}/$id/download-url');
    final data = unwrapEnvelope(res.data);
    return data['downloadUrl'] as String;
  }
}

final profileRepositoryProvider = Provider<ProfileRepository>((ref) {
  return ProfileRepository(ref.watch(dioProvider));
});
