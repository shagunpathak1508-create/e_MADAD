import 'package:url_launcher/url_launcher.dart';

class SmsService {
  static String buildMessage({
    required String emergencyType,
    required String action,
    required double? lat,
    required double? lng,
  }) {
    final locationText = (lat != null && lng != null)
        ? 'Location: https://maps.google.com/?q=$lat,$lng'
        : 'Location: Unknown';

    final templates = {
      'Medical':
          '🚨 MEDICAL EMERGENCY 🚨\nI need immediate medical help. $action.\n$locationText\nPlease respond ASAP. - Sent via eMADAD',
      'Accident':
          '🚨 ACCIDENT EMERGENCY 🚨\nI have been in an accident. $action.\n$locationText\nPlease respond ASAP. - Sent via eMADAD',
      'Fire':
          '🚨 FIRE EMERGENCY 🚨\nFire reported near my location. $action.\n$locationText\nPlease respond ASAP. - Sent via eMADAD',
      'Safety':
          '🚨 SAFETY EMERGENCY 🚨\nI am in danger and need help. $action.\n$locationText\nPlease respond ASAP. - Sent via eMADAD',
      'Disaster':
          '🚨 DISASTER EMERGENCY 🚨\nI need rescue/shelter assistance. $action.\n$locationText\nPlease respond ASAP. - Sent via eMADAD',
      'Help Request':
          '🚨 HELP NEEDED 🚨\nI need immediate assistance. $action.\n$locationText\nPlease respond ASAP. - Sent via eMADAD',
    };

    return templates[emergencyType] ?? '🚨 EMERGENCY 🚨\n$action\n$locationText\n- Sent via eMADAD';
  }

  static Future<void> sendEmergencySMS({
    required String emergencyType,
    required String action,
    required double? lat,
    required double? lng,
    List<String> recipients = const ['112'],
  }) async {
    final message = buildMessage(
      emergencyType: emergencyType,
      action: action,
      lat: lat,
      lng: lng,
    );
    final recipientStr = recipients.join(';');
    final uri = Uri(
      scheme: 'sms',
      path: recipientStr,
      queryParameters: {'body': message},
    );
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    }
  }

  static Future<void> callNumber(String number) async {
    final uri = Uri(scheme: 'tel', path: number);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    }
  }
}
