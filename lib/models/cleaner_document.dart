import 'package:equatable/equatable.dart';

class CleanerDocument extends Equatable {
  const CleanerDocument({
    required this.id,
    required this.type,
    required this.title,
    required this.storageKey,
    this.mimeType,
    this.fileSize,
    this.expiresAt,
    this.notes,
    this.createdAt,
  });

  final String id;
  final String type;
  final String title;
  final String storageKey;
  final String? mimeType;
  final int? fileSize;
  final DateTime? expiresAt;
  final String? notes;
  final DateTime? createdAt;

  bool get isExpired =>
      expiresAt != null && expiresAt!.isBefore(DateTime.now());

  bool get isExpiringSoon =>
      expiresAt != null &&
      !isExpired &&
      expiresAt!.difference(DateTime.now()).inDays <= 30;

  factory CleanerDocument.fromJson(Map<String, dynamic> json) {
    return CleanerDocument(
      id: json['id'] as String,
      type: json['type'] as String? ?? 'OTHER',
      title: json['title'] as String? ?? 'Document',
      storageKey: json['storageKey'] as String? ?? '',
      mimeType: json['mimeType'] as String?,
      fileSize: json['fileSize'] as int?,
      expiresAt: json['expiresAt'] != null
          ? DateTime.tryParse(json['expiresAt'] as String)
          : null,
      notes: json['notes'] as String?,
      createdAt: json['createdAt'] != null
          ? DateTime.tryParse(json['createdAt'] as String)
          : null,
    );
  }

  @override
  List<Object?> get props =>
      [id, type, title, storageKey, mimeType, fileSize, expiresAt, notes];
}

/// Document types a cleaner may submit about themselves — must mirror the
/// backend's SELF_SERVICE_DOC_TYPES. Business-issued types (background
/// check, contract) aren't offered here since a cleaner can't create those.
const List<String> selfServiceDocTypes = [
  'ID_CARD',
  'CERTIFICATION',
  'INSURANCE',
  'OTHER',
];

String docTypeLabel(String type) {
  switch (type) {
    case 'ID_CARD':
      return 'ID card';
    case 'CERTIFICATION':
      return 'Certification';
    case 'INSURANCE':
      return 'Insurance';
    case 'BACKGROUND_CHECK':
      return 'Background check';
    case 'CONTRACT':
      return 'Contract';
    default:
      return 'Other';
  }
}
