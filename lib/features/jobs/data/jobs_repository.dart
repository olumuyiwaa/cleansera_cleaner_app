import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/api_constants.dart';
import '../../../core/network/dio_client.dart';
import '../../../models/checklist.dart';
import '../../../models/job.dart';

class JobsRepository {
  JobsRepository(this._dio);

  final Dio _dio;

  Future<List<Job>> fetchMyJobs({
    String? status,
    DateTime? from,
    DateTime? to,
  }) async {
    final query = <String, dynamic>{};
    if (status != null) query['status'] = status;
    if (from != null) query['from'] = from.toUtc().toIso8601String();
    if (to != null) query['to'] = to.toUtc().toIso8601String();

    final res = await _dio.get(
      ApiConstants.myJobs,
      queryParameters: query.isEmpty ? null : query,
    );

    final list = unwrapListEnvelope(res.data);

    return list
        .map((e) => Job.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<Job> fetchJob(String id) async {
    final res = await _dio.get('${ApiConstants.jobById}/$id');
    return Job.fromJson(unwrapEnvelope(res.data));
  }

  /// lat/lng match the backend's check-in contract exactly (it records them
  /// as checkInLat/checkInLng and geofences against the booking address).
  Future<Job> checkIn(String jobId, {double? lat, double? lng}) async {
    final res = await _dio.post(
      '${ApiConstants.checkIn}/$jobId/check-in',
      data: {
        if (lat != null) 'lat': lat,
        if (lng != null) 'lng': lng,
      },
    );
    return Job.fromJson(unwrapEnvelope(res.data));
  }

  Future<Job> startJob(String jobId) async {
    final res = await _dio.post('${ApiConstants.startJob}/$jobId/start');
    return Job.fromJson(unwrapEnvelope(res.data));
  }

  Future<Job> completeJob(
    String jobId, {
    String? notes,
    double? lat,
    double? lng,
  }) async {
    final res = await _dio.post(
      '${ApiConstants.completeJob}/$jobId/complete',
      data: {
        if (notes != null) 'notes': notes,
        if (lat != null) 'lat': lat,
        if (lng != null) 'lng': lng,
      },
    );
    return Job.fromJson(unwrapEnvelope(res.data));
  }

  Future<JobChecklist> fetchChecklist(String bookingId) async {
    final res = await _dio.get('${ApiConstants.jobChecklist}/$bookingId');
    return JobChecklist.fromJson(unwrapEnvelope(res.data));
  }

  Future<ChecklistItem> completeChecklistItem(
    String bookingId,
    String itemId, {
    bool done = true,
  }) async {
    final res = await _dio.post(
      '${ApiConstants.jobChecklist}/$bookingId/items/$itemId/complete',
      data: {'done': done},
    );
    final data = unwrapEnvelope(res.data);
    // Backend returns { checklist, item } for this endpoint.
    return ChecklistItem.fromJson(data['item'] as Map<String, dynamic>);
  }

  /// Notifies the customer (SMS/email — there's no customer app to push to)
  /// that the cleaner is on the way. Only valid before check-in; the
  /// backend returns 409 if this booking is already checked in.
  Future<void> sendOnMyWay(String jobId) async {
    await _dio.post('${ApiConstants.onMyWay}/$jobId/on-my-way');
  }

  /// Step 1 of photo proof: ask the backend for a presigned upload URL.
  Future<({String uploadUrl, String storageKey})> getPhotoUploadUrl(
    String jobId, {
    required String stage,
    String contentType = 'image/jpeg',
    String? filename,
  }) async {
    final res = await _dio.post(
      '${ApiConstants.jobPhotoUploadUrl}/$jobId/photos/upload-url',
      data: {
        'stage': stage,
        'contentType': contentType,
        if (filename != null) 'filename': filename,
      },
    );
    final data = unwrapEnvelope(res.data);
    return (
      uploadUrl: data['uploadUrl'] as String,
      storageKey: data['storageKey'] as String,
    );
  }

  /// Step 2: PUT the raw image bytes straight to storage. Deliberately uses
  /// a bare Dio() rather than the app's shared client — the presigned URL
  /// already carries its own auth in the query string, so it shouldn't get
  /// this app's Bearer token or run through the 401-refresh interceptor
  /// meant for our own API.
  Future<void> uploadPhotoBytes(
    String uploadUrl,
    List<int> bytes, {
    String contentType = 'image/jpeg',
  }) async {
    final plainDio = Dio();
    await plainDio.put(
      uploadUrl,
      data: Stream.fromIterable([bytes]),
      options: Options(
        headers: {
          'Content-Type': contentType,
          Headers.contentLengthHeader: bytes.length,
        },
      ),
    );
  }

  /// Step 3: register the uploaded photo against the booking.
  Future<JobPhoto> createJobPhoto(
    String jobId, {
    required String stage,
    required String storageKey,
  }) async {
    final res = await _dio.post(
      '${ApiConstants.jobPhotos}/$jobId/photos',
      data: {'stage': stage, 'storageKey': storageKey},
    );
    return JobPhoto.fromJson(unwrapEnvelope(res.data));
  }
}

final jobsRepositoryProvider = Provider<JobsRepository>((ref) {
  return JobsRepository(ref.watch(dioProvider));
});
