import 'package:cloud_firestore/cloud_firestore.dart';

/// Represents the shared relationship between two users.
/// Almost every feature (memories, countdowns, journal) is scoped
/// under coupleId so both partners see the same shared data.
class CoupleModel {
  final String coupleId;
  final List<String> memberUids; // exactly 2
  final String inviteCode; // 6-char code partner enters to pair
  final DateTime? relationshipStartDate; // for "days together"
  final DateTime? anniversaryDate;
  final DateTime createdAt;
  final String themeId; // couple theme (premium)
  final bool isPremium;

  CoupleModel({
    required this.coupleId,
    required this.memberUids,
    required this.inviteCode,
    this.relationshipStartDate,
    this.anniversaryDate,
    required this.createdAt,
    this.themeId = 'default',
    this.isPremium = false,
  });

  factory CoupleModel.fromMap(Map<String, dynamic> map, String id) {
    return CoupleModel(
      coupleId: id,
      memberUids: List<String>.from(map['memberUids'] ?? []),
      inviteCode: map['inviteCode'] ?? '',
      relationshipStartDate:
          (map['relationshipStartDate'] as Timestamp?)?.toDate(),
      anniversaryDate: (map['anniversaryDate'] as Timestamp?)?.toDate(),
      createdAt: (map['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      themeId: map['themeId'] ?? 'default',
      isPremium: map['isPremium'] ?? false,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'memberUids': memberUids,
      'inviteCode': inviteCode,
      'relationshipStartDate': relationshipStartDate != null
          ? Timestamp.fromDate(relationshipStartDate!)
          : null,
      'anniversaryDate':
          anniversaryDate != null ? Timestamp.fromDate(anniversaryDate!) : null,
      'createdAt': Timestamp.fromDate(createdAt),
      'themeId': themeId,
      'isPremium': isPremium,
    };
  }

  int get daysTogether {
    if (relationshipStartDate == null) return 0;
    return DateTime.now().difference(relationshipStartDate!).inDays;
  }

  int? get daysUntilAnniversary {
    if (anniversaryDate == null) return null;
    final now = DateTime.now();
    var next = DateTime(now.year, anniversaryDate!.month, anniversaryDate!.day);
    if (next.isBefore(DateTime(now.year, now.month, now.day))) {
      next =
          DateTime(now.year + 1, anniversaryDate!.month, anniversaryDate!.day);
    }
    return next.difference(DateTime(now.year, now.month, now.day)).inDays;
  }
}
