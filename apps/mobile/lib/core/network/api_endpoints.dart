/// Central registry of backend API endpoints.
///
/// Keeping endpoint paths in one place prevents URL strings from being
/// duplicated throughout the application.
///
/// For example, instead of writing:
///
///     dio.post('/auth/login')
///
/// directly inside an authentication repository, the repository will
/// eventually use:
///
///     ApiEndpoints.login
///
/// This gives us a single source of truth for the Flutter application's
/// knowledge of Mage's HTTP API.
///
/// IMPORTANT:
/// These are only endpoint paths. The API base URL belongs to AppConfig.
/// The two concerns are intentionally kept separate:
///
///     AppConfig
///         └── http://10.0.2.2:8000
///
///     ApiEndpoints
///         └── /auth/login
///
/// Dio combines them when making a request.
class ApiEndpoints {
  /// Private constructor.
  ///
  /// This class is a collection of constants and should never be
  /// instantiated.
  const ApiEndpoints._();

  // ---------------------------------------------------------------------------
  // Health
  // ---------------------------------------------------------------------------

  /// Backend health-check endpoint.
  ///
  /// Used to verify that the FastAPI service is reachable and healthy.
  static const String health = '/health';

  // ---------------------------------------------------------------------------
  // Authentication
  // ---------------------------------------------------------------------------

  /// Registers a new user account.
  static const String register = '/auth/register';

  /// Authenticates an existing user and obtains authentication tokens.
  static const String login = '/auth/login';

  /// Logs the current session out.
  static const String logout = '/auth/logout';

  /// Exchanges a refresh token for a new access token.
  static const String refresh = '/auth/refresh';

  /// Returns the currently authenticated user's information.
  static const String me = '/auth/me';

  /// Verifies a user's email address.
  ///
  /// The verification token is expected to be supplied as a query parameter
  /// when the request is made.
  static const String verifyEmail = '/auth/verify-email';

  /// Starts the password-reset process.
  static const String forgotPassword = '/auth/forgot-password';

  /// Completes a password reset using the supplied reset token.
  static const String resetPassword = '/auth/reset-password';

  // ---------------------------------------------------------------------------
  // Organizations
  // ---------------------------------------------------------------------------

  /// Creates a new organization.
  static const String organizations = '/organizations';

  /// Builds the endpoint for retrieving a specific organization.
  ///
  /// An organization ID is supplied at runtime because this endpoint refers
  /// to a particular organization.
  static String organization(String organizationId) {
    return '/organizations/$organizationId';
  }

  /// Builds the endpoint for updating a specific organization.
  ///
  /// The same resource path is used for both retrieving and updating the
  /// organization; the HTTP method determines the operation.
  static String organizationUpdate(String organizationId) {
    return '/organizations/$organizationId';
  }

  /// Builds the endpoint for retrieving members of an organization.
  static String organizationMembers(String organizationId) {
    return '/organizations/$organizationId/members';
  }

  /// Builds the endpoint for adding a member to an organization.
  static String addOrganizationMember(String organizationId) {
    return '/organizations/$organizationId/members';
  }

  /// Builds the endpoint for removing a specific organization member.
  static String removeOrganizationMember(String organizationId, String userId) {
    return '/organizations/$organizationId/members/$userId';
  }

  /// Builds the endpoint for retrieving providers belonging to an
  /// organization.
  static String organizationProviders(String organizationId) {
    return '/organizations/$organizationId/providers';
  }

  // ---------------------------------------------------------------------------
  // Providers
  // ---------------------------------------------------------------------------

  /// Retrieves the marketplace provider list.
  ///
  /// Pagination and filtering parameters will be supplied separately through
  /// Dio's queryParameters rather than being embedded in this path.
  static const String providers = '/providers';

  /// Creates the authenticated provider's profile.
  static const String providerProfile = '/providers/profile';

  /// Builds the endpoint for retrieving a specific provider profile.
  static String provider(String providerId) {
    return '/providers/$providerId';
  }

  /// Builds the endpoint for updating a specific provider profile.
  ///
  /// The HTTP method will determine whether the operation is a read or update.
  static String providerUpdate(String providerId) {
    return '/providers/$providerId';
  }
}
