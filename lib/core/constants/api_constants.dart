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
  // Multi-business affiliation: list the workspaces this account can act
  // within, and switch the active one mid-session without a full re-login
  // (see cleansera_sass/src/modules/auth/auth.routes.js). Both require only
  // the current access token — no password re-entry, unlike the picker
  // shown during login itself.
  static const String affiliations = '/auth/affiliations';
  static const String selectBusiness = '/auth/select-business';

  static const String cleanerMe = '/cleaners/me';
  static const String cleanerAvailability = '/cleaners/me/availability';
  static const String cleanerDocuments = '/cleaners/me/documents';
  static const String cleanerEarnings = '/cleaners/me/earnings';
  static const String cleanerStripeStatus = '/cleaners/me/stripe/status';
  static const String cleanerStripeOnboardingLink = '/cleaners/me/stripe/onboarding-link';

  static const String myJobs = '/cleaner/bookings/my';
  static const String jobById = '/cleaner/bookings';
  static const String startJob = '/cleaner/bookings';
  static const String completeJob = '/cleaner/bookings';
  static const String checkIn = '/cleaner/bookings';
  static const String onMyWay = '/cleaner/bookings';
  static const String jobPhotoUploadUrl = '/cleaner/bookings';
  static const String jobPhotos = '/cleaner/bookings';

  // /checklists/:bookingId (get/put/delete) and
  // /checklists/:bookingId/items/:itemId/complete (mark one item done).
  static const String jobChecklist = '/checklists';

  static const String notifications = '/notifications';
  // Registers/unregisters this device's FCM token. Nested under /cleaners/me
  // (not /notifications) because the backend's device-token registration
  // lives in the cleanerSelf module: see
  // cleansera_sass/src/modules/cleanerSelf/cleanerSelf.routes.js
  // (POST/DELETE /cleaners/me/device-token). A previous version of this
  // constant pointed at '/notifications/fcm-token', which doesn't exist on
  // the server — same class of bug as the conversations path fixed below.
  static const String registerFcm = '/cleaners/me/device-token';
  // The backend mounts the messaging module at '/messaging' itself (see
  // cleansera_sass/src/routes/index.js: router.use('/messaging', ...)) —
  // there is no '/conversations' sub-path. This constant pointed at a path
  // that doesn't exist on the server, which is why no messaging feature in
  // this app has ever been able to load a thread.
  static const String conversations = '/messaging';
  static const String messagesReadPath = '/messaging/messages'; // + /:id/read
}
