import '../models/emergency_contact.dart';

/// Manages emergency contacts
class EmergencyContactManager {
  /// Load all emergency contacts
  Future<List<EmergencyContact>> loadContacts() async {
    return await EmergencyContact.loadAll();
  }

  /// Save an emergency contact
  Future<void> saveContact(EmergencyContact contact) async {
    await contact.save();
  }

  /// Delete an emergency contact
  Future<void> deleteContact(String contactId) async {
    final contacts = await loadContacts();
    final contact = contacts.firstWhere((c) => c.id == contactId);
    await contact.delete();
  }

  /// Validate phone number format
  static bool isValidPhoneNumber(String phone) {
    // Remove spaces, dashes, parentheses
    final cleaned = phone.replaceAll(RegExp(r'[\s\-\(\)]'), '');

    // Check if it starts with + and has 10-15 digits
    if (cleaned.startsWith('+')) {
      return RegExp(r'^\+\d{10,15}$').hasMatch(cleaned);
    }

    // Check if it's a 10-11 digit number
    return RegExp(r'^\d{10,11}$').hasMatch(cleaned);
  }

  /// Format phone number for display
  static String formatPhoneNumber(String phone) {
    final cleaned = phone.replaceAll(RegExp(r'[\s\-\(\)]'), '');

    if (cleaned.length == 10) {
      return '(${cleaned.substring(0, 3)}) ${cleaned.substring(3, 6)}-${cleaned.substring(6)}';
    } else if (cleaned.length == 11 && cleaned.startsWith('1')) {
      return '+1 (${cleaned.substring(1, 4)}) ${cleaned.substring(4, 7)}-${cleaned.substring(7)}';
    } else if (cleaned.startsWith('+') && cleaned.length >= 11) {
      return cleaned;
    }

    return phone;
  }
}
