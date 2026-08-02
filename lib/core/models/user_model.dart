import 'package:cloud_firestore/cloud_firestore.dart';

/// A single user (one half of a couple).
class UserModel {
  final String uid;
  final String name;
  final String email;
  final String? photoUrl;
  final String? coupleId; // null until paired with a partner
  final String? partnerUid;
  final bool isPremium;
  final DateTime createdAt;
  final String? fcmToken;

  UserModel({
    required this.uid,
    required this.name,
    required this.email,
    this.photoUrl,
    this.coupleId,
    this.partnerUid,
    this.isPremium = false,
    required this.createdAt,
    this.fcmToken,
  });

  factory UserModel.fromMap(Map<String, dynamic> map, String uid) {
    return UserModel(
      uid: uid,
      name: map['name'] ?? '',
      email: map['email'] ?? '',
      photoUrl: map['photoUrl'],
      coupleId: map['coupleId'],
      partnerUid: map['partnerUid'],
      isPremium: map['isPremium'] ?? false,
      createdAt: (map['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      fcmToken: map['fcmToken'],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'email': email,
      'photoUrl': photoUrl,
      'coupleId': coupleId,
      'partnerUid': partnerUid,
      'isPremium': isPremium,
      'createdAt': Timestamp.fromDate(createdAt),
      'fcmToken': fcmToken,
    };
  }

  UserModel copyWith({
    String? name,
    String? photoUrl,
    String? coupleId,
    String? partnerUid,
    bool? isPremium,
    String? fcmToken,
  }) {
    return UserModel(
      uid: uid,
      name: name ?? this.name,
      email: email,
      photoUrl: photoUrl ?? this.photoUrl,
      coupleId: coupleId ?? this.coupleId,
      partnerUid: partnerUid ?? this.partnerUid,
      isPremium: isPremium ?? this.isPremium,
      createdAt: createdAt,
      fcmToken: fcmToken ?? this.fcmToken,
    );
  }
}
