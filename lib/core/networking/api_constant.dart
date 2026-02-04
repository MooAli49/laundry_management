class ApiConstant {
  static const String baseUrl = 'https://api.laundryapp.com';

  // Authentication
  static const String loginEp = '/auth/login';
  static const String registerEp = '/auth/register';
  static const String verifyRegisterOtpEP = '/auth/verify-register-otp';
  static const String forgotPasswordEmailEP = '/auth/forgot-password-email';
  static const String verifyPasswordRestOtpEP =
      '/auth/verify-password-reset-otp';
  static const String restPasswordEP = '/auth/reset-password';
  static const String generateNewTokenEp = '/auth/refresh-token';
}
