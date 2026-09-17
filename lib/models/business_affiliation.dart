/// One workspace a user can act within — mirrors the shape returned by the
/// backend's `listAffiliations` (see
/// cleansera_sass/src/modules/auth/auth.service.js). Used only for the
/// "which business is this?" picker shown when a cleaner account is active
/// at more than one business.
class BusinessAffiliation {
  const BusinessAffiliation({
    required this.businessId,
    required this.businessName,
    required this.subdomain,
    required this.role,
  });

  final String businessId;
  final String businessName;
  final String? subdomain;
  final String role;

  factory BusinessAffiliation.fromJson(Map<String, dynamic> json) {
    return BusinessAffiliation(
      businessId: json['businessId'] as String,
      businessName: json['businessName'] as String? ?? 'Unnamed business',
      subdomain: json['subdomain'] as String?,
      role: json['role'] as String? ?? 'CLEANER',
    );
  }
}

/// Thrown by [AuthRepository.login] when the credentials were correct but
/// the account is affiliated with more than one business, so the backend
/// returned `{ requiresBusinessSelection: true, affiliations: [...] }`
/// instead of tokens. No accessToken/refreshToken exists yet at this point
/// — nothing is written to storage — the caller must show [affiliations]
/// and re-submit login with a chosen businessId.
///
/// Previously nothing checked for this response shape, so the code went
/// straight to `data['accessToken'] as String`, got null, and threw an
/// unhandled type-cast error — which is why a cleaner working for two
/// businesses couldn't log in at all instead of seeing a picker.
class BusinessSelectionRequiredException implements Exception {
  const BusinessSelectionRequiredException(this.affiliations);
  final List<BusinessAffiliation> affiliations;

  @override
  String toString() => 'BusinessSelectionRequiredException';
}
