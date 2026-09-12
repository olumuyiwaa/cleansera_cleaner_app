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
}

final jobsRepositoryProvider = Provider<JobsRepository>((ref) {
  return JobsRepository(ref.watch(dioProvider));
});
