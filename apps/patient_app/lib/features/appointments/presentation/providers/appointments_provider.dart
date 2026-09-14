import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/network/api_client.dart';

typedef SlotKey = ({String doctorId, String clinicId, String date});

final slotsProvider = FutureProvider.autoDispose.family<List<Map<String, dynamic>>, SlotKey>(
  (ref, key) async {
    final dio = ref.watch(dioProvider);
    final response = await dio.get(
      '/appointments/slots/${key.doctorId}/${key.clinicId}',
      queryParameters: {'date': key.date},
    );
    return List<Map<String, dynamic>>.from(response.data['data'] as List);
  },
);

class AppointmentService {
  final Dio _dio;

  AppointmentService(this._dio);

  Future<void> lockSlot(String slotId) async {
    await _dio.post('/appointments/slots/lock', data: {'slotId': slotId});
  }

  Future<void> releaseSlot(String slotId) async {
    try {
      await _dio.post('/appointments/slots/release', data: {'slotId': slotId});
    } catch (_) {}
  }

  Future<Map<String, dynamic>> bookAppointment({
    required String doctorId,
    required String clinicId,
    required String slotId,
    String? notes,
  }) async {
    final response = await _dio.post('/appointments', data: {
      'doctorId': doctorId,
      'clinicId': clinicId,
      'slotId': slotId,
      if (notes != null) 'notes': notes,
    });
    return response.data['data'] as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> getAppointments({
    String? status,
    int page = 1,
    int limit = 20,
  }) async {
    final response = await _dio.get('/appointments/my', queryParameters: {
      if (status != null) 'status': status,
      'page': page,
      'limit': limit,
    });
    return response.data as Map<String, dynamic>;
  }

  Future<void> cancelAppointment(String appointmentId, String reason) async {
    await _dio.post('/appointments/$appointmentId/cancel', data: {'reason': reason});
  }
}

final appointmentServiceProvider = Provider<AppointmentService>(
  (ref) => AppointmentService(ref.watch(dioProvider)),
);

final patientAppointmentsProvider = FutureProvider.autoDispose.family<List<Map<String, dynamic>>, String?>(
  (ref, status) async {
    final service = ref.watch(appointmentServiceProvider);
    final result = await service.getAppointments(status: status);
    return List<Map<String, dynamic>>.from((result['data'] as List?) ?? []);
  },
);
