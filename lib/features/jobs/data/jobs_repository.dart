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

    final list = res.data is List
        ? res.data as List
        : (res.data['data'] as List? ?? res.data['bookings'] as List? ?? []);

    return list
        .map((e) => Job.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<Job> fetchJob(String id) async {
    final res = await _dio.get('${ApiConstants.jobById}/$id');
    final data = res.data is Map && res.data['data'] != null
        ? res.data['data'] as Map<String, dynamic>
        : res.data as Map<String, dynamic>;
    return Job.fromJson(data);
  }

  Future<Job> checkIn(String jobId, {double? lat, double? lng}) async {
    final res = await _dio.post(
      '${ApiConstants.checkIn}/$jobId/check-in',
      data: {
        if (lat != null) 'latitude': lat,
        if (lng != null) 'longitude': lng,
      },
    );
    return Job.fromJson(_unwrap(res.data));
  }

  Future<Job> startJob(String jobId) async {
    final res = await _dio.post('${ApiConstants.startJob}/$jobId/start');
    return Job.fromJson(_unwrap(res.data));
  }

  Future<Job> completeJob(
    String jobId, {
    String? notes,
    List<String>? photoKeys,
  }) async {
    final res = await _dio.post(
      '${ApiConstants.completeJob}/$jobId/complete',
      data: {
        if (notes != null) 'notes': notes,
        if (photoKeys != null) 'photoKeys': photoKeys,
      },
    );
    return Job.fromJson(_unwrap(res.data));
  }

  Future<Job> updateStatus(String jobId, String status) async {
    final res = await _dio.patch(
      '${ApiConstants.updateStatus}/$jobId/status',
      data: {'status': status},
    );
    return Job.fromJson(_unwrap(res.data));
  }

  Future<JobChecklist> fetchChecklist(String bookingId) async {
    final res =
        await _dio.get('${ApiConstants.jobChecklist}/booking/$bookingId');
    return JobChecklist.fromJson(_unwrap(res.data));
  }

  Future<ChecklistItem> completeChecklistItem(String itemId) async {
    final res = await _dio.post(
      '${ApiConstants.completeChecklistItem}/$itemId/complete',
    );
    return ChecklistItem.fromJson(_unwrap(res.data));
  }

  Map<String, dynamic> _unwrap(dynamic data) {
    if (data is Map<String, dynamic> && data['data'] is Map<String, dynamic>) {
      return data['data'] as Map<String, dynamic>;
    }
    return data as Map<String, dynamic>;
  }
}

final jobsRepositoryProvider = Provider<JobsRepository>((ref) {
  return JobsRepository(ref.watch(dioProvider));
});
