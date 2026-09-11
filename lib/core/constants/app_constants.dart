class AppConstants {
  AppConstants._();

  static const String appName = 'CleanSera Cleaner';
  static const String storageAccessToken = 'access_token';
  static const String storageRefreshToken = 'refresh_token';
  static const String storageUser = 'user_json';
  static const String storageCleanerProfile = 'cleaner_profile_json';

  static const Duration accessTokenLeeway = Duration(seconds: 60);
  static const Duration defaultTimeout = Duration(seconds: 30);
  static const int earlyCheckInMinutes = 30;
}
