import 'package:cloud_firestore/cloud_firestore.dart';

class EmergencyModel {
  final String id;
  final String type;
  final double userLat;
  final double userLng;
  final DateTime timestamp;
  String status; // pending, accepted, completed
  final String? assignedVolunteerId;
  
  // Keep some legacy fields for UI compatibility if needed, 
  // but prioritize user requested fields in constructor/toMap
  final String victimId;
  final String specificAction;

  EmergencyModel({
    required this.id,
    required this.type,
    required this.userLat,
    required this.userLng,
    required this.timestamp,
    this.status = 'pending',
    this.assignedVolunteerId,
    this.victimId = '',
    this.specificAction = '',
  });

  factory EmergencyModel.fromMap(Map<String, dynamic> map, String docId) {
    return EmergencyModel(
      id: docId,
      type: map['type'] ?? map['emergencyType'] ?? 'general_emergency',
      userLat: (map['userLat'] ?? (map['location'] as GeoPoint?)?.latitude ?? 0.0).toDouble(),
      userLng: (map['userLng'] ?? (map['location'] as GeoPoint?)?.longitude ?? 0.0).toDouble(),
      timestamp: (map['timestamp'] as Timestamp?)?.toDate() ?? DateTime.now(),
      status: map['status'] ?? 'pending',
      assignedVolunteerId: map['assignedVolunteerId'],
      victimId: map['victimId'] ?? '',
      specificAction: map['specificAction'] ?? map['action'] ?? '',
    );
  }

  Map<String, dynamic> toMap() => {
        'type': type,
        'userLat': userLat,
        'userLng': userLng,
        'timestamp': Timestamp.fromDate(timestamp),
        'status': status,
        'assignedVolunteerId': assignedVolunteerId,
        'victimId': victimId,
        'specificAction': specificAction,
      };
}
