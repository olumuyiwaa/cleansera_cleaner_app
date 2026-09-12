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

  // /checklists/:bookingId (get/put/delete) and
  // /checklists/:bookingId/items/:itemId/complete (mark one item done).
  static const String jobChecklist = '/checklists';

  static const String notifications = '/notifications';
  static const String registerFcm = '/notifications/fcm-token';
  // The backend mounts the messaging module at '/messaging' itself (see
  // cleansera_sass/src/routes/index.js: router.use('/messaging', ...)) —
  // there is no '/conversations' sub-path. This constant pointed at a path
  // that doesn't exist on the server, which is why no messaging feature in
  // this app has ever been able to load a thread.
  static const String conversations = '/messaging';
  static const String messagesReadPath = '/messaging/messages'; // + /:id/read
}
