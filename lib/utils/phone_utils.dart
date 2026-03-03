import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

class PhoneUtils {
  /// Normalizes phone number for API requests
  /// Removes all spaces, parentheses, and hyphens
  /// Example: "+7 (967) 673-12-00" -> "+79676731200"
  static String normalizePhoneForApi(String phoneNumber) {
    // Remove all non-digit characters except +
    String normalized = phoneNumber.replaceAll(RegExp(r'[^\d+]'), '');
    
    // Ensure the number starts with +
    if (!normalized.startsWith('+')) {
      normalized = '+$normalized';
    }
    
    return normalized;
  }

  /// Makes a phone call to the specified number
  static Future<void> makePhoneCall(String phoneNumber) async {
    // Remove any non-digit characters except + and -
    String cleanNumber = phoneNumber.replaceAll(RegExp(r'[^\d+\-]'), '');
    
    // Ensure the number starts with +
    if (!cleanNumber.startsWith('+')) {
      cleanNumber = '+$cleanNumber';
    }
    
    final Uri phoneUri = Uri(scheme: 'tel', path: cleanNumber);
    
    try {
      if (await canLaunchUrl(phoneUri)) {
        await launchUrl(phoneUri);
      } else {
        throw Exception('Could not launch phone call');
      }
    } catch (e) {
      throw Exception('Failed to make phone call: $e');
    }
  }
  
  /// Shows a dialog with the phone number and options to call
  static Future<void> showPhoneNumberDialog(
    BuildContext context, 
    String clubName, 
    String phoneNumber
  ) async {
    return showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('Позвонить в $clubName'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Номер телефона:',
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey[600],
                ),
              ),
              const SizedBox(height: 8),
              Text(
                phoneNumber,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Отмена'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.of(context).pop();
                makePhoneCall(phoneNumber);
              },
              child: const Text('Позвонить'),
            ),
          ],
        );
      },
    );
  }
} 