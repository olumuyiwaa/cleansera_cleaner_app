class ApiConstants {
  ApiConstants._();

  static const String baseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://localhost:8000/api/v1',
  );

  static const String login = '/auth/login';
  static const String refresh = '/auth/refresh';
  static const String me = '/auth/me';
  static const String logout = '/auth/logout';

  static const String cleanerMe = '/cleaners/me';
  static const String cleanerAvailability = '/cleaners/me/availability';
  static const String cleanerDocuments = '/cleaners/me/documents';

  static const String myJobs = '/cleaner/bookings/my';
  static const String jobById = '/cleaner/bookings';
  static const String startJob = '/cleaner/bookings';
  static const String completeJob = '/cleaner/bookings';
  static const String checkIn = '/cleaner/bookings';
  static const String checkOut = '/cleaner/bookings';
  static const String updateStatus = '/cleaner/bookings';

  static const String jobChecklist = '/checklists';
  static const String completeChecklistItem = '/checklists/items';

  static const String notifications = '/notifications';
  static const String registerFcm = '/notifications/fcm-token';
  static const String conversations = '/messaging/conversations';
}
