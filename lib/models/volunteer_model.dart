import 'package:cloud_firestore/cloud_firestore.dart';

class VolunteerModel {
  final String id;
  final String name;
  final String phone;
  final List<String> skills;
  bool isAvailable;
  final int tasksCompleted;
  final double responseRate; // 0.0 - 1.0
  final double reliabilityScore; // computed
  final GeoPoint? location;
  final DateTime? lastActive;

  VolunteerModel({
    required this.id,
    required this.name,
    required this.phone,
    required this.skills,
    this.isAvailable = false,
    this.tasksCompleted = 0,
    this.responseRate = 0.0,
    this.location,
    this.lastActive,
  }) : reliabilityScore = _computeScore(tasksCompleted, responseRate);

  static double _computeScore(int tasks, double rate) {
    final taskScore = (tasks / 50).clamp(0.0, 1.0);
    return (taskScore * 0.6 + rate * 0.4) * 100;
  }

  factory VolunteerModel.fromMap(Map<String, dynamic> map, String docId) {
    return VolunteerModel(
      id: docId,
      name: map['name'] ?? '',
      phone: map['phone'] ?? '',
      skills: List<String>.from(map['skills'] ?? []),
      isAvailable: map['isAvailable'] ?? false,
      tasksCompleted: map['tasksCompleted'] ?? 0,
      responseRate: (map['responseRate'] ?? 0.0).toDouble(),
      location: map['location'] as GeoPoint?,
      lastActive: (map['lastActive'] as Timestamp?)?.toDate(),
    );
  }

  Map<String, dynamic> toMap() => {
        'name': name,
        'phone': phone,
        'skills': skills,
        'isAvailable': isAvailable,
        'tasksCompleted': tasksCompleted,
        'responseRate': responseRate,
        'location': location,
        'lastActive': lastActive != null ? Timestamp.fromDate(lastActive!) : null,
      };

  VolunteerModel copyWith({bool? isAvailable}) => VolunteerModel(
        id: id,
        name: name,
        phone: phone,
        skills: skills,
        isAvailable: isAvailable ?? this.isAvailable,
        tasksCompleted: tasksCompleted,
        responseRate: responseRate,
        location: location,
        lastActive: lastActive,
      );
}
