import 'package:cloud_firestore/cloud_firestore.dart';

class HelpRequestModel {
  final String id;
  final String victimId;
  final String emergencyType;
  final String specificAction;
  String status; // pending, accepted, completed
  final GeoPoint? location;
  final List<GeoPoint> locationTrail;
  final DateTime timestamp;
  final String? assignedVolunteerId;
  final bool isOffline;
  final GeoPoint? lastKnownLocation;

  HelpRequestModel({
    required this.id,
    required this.victimId,
    required this.emergencyType,
    required this.specificAction,
    this.status = 'pending',
    this.location,
    this.locationTrail = const [],
    required this.timestamp,
    this.assignedVolunteerId,
    this.isOffline = false,
    this.lastKnownLocation,
  });

  factory HelpRequestModel.fromMap(Map<String, dynamic> map, String docId) {
    return HelpRequestModel(
      id: docId,
      victimId: map['victimId'] ?? '',
      emergencyType: map['emergencyType'] ?? '',
      specificAction: map['specificAction'] ?? '',
      status: map['status'] ?? 'pending',
      location: map['location'] as GeoPoint?,
      locationTrail: List<GeoPoint>.from(map['locationTrail'] ?? []),
      timestamp: (map['timestamp'] as Timestamp?)?.toDate() ?? DateTime.now(),
      assignedVolunteerId: map['assignedVolunteerId'],
      isOffline: map['isOffline'] ?? false,
      lastKnownLocation: map['lastKnownLocation'] as GeoPoint?,
    );
  }

  Map<String, dynamic> toMap() => {
        'victimId': victimId,
        'emergencyType': emergencyType,
        'specificAction': specificAction,
        'status': status,
        'location': location,
        'locationTrail': locationTrail,
        'timestamp': Timestamp.fromDate(timestamp),
        'assignedVolunteerId': assignedVolunteerId,
        'isOffline': isOffline,
        'lastKnownLocation': lastKnownLocation,
      };
}
