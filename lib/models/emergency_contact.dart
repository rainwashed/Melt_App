import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

/// Represents an emergency contact who will be notified when user is in danger
class EmergencyContact {
  final String id;
  final String name;
  final String phoneNumber;
  final bool isEnabled;
  final DateTime createdAt;

  EmergencyContact({
    String? id,
    required this.name,
    required this.phoneNumber,
    this.isEnabled = true,
    DateTime? createdAt,
  }) : id = id ?? const Uuid().v4(),
       createdAt = createdAt ?? DateTime.now();

  /// Convert to JSON for storage
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'phoneNumber': phoneNumber,
      'isEnabled': isEnabled,
      'createdAt': createdAt.toIso8601String(),
    };
  }

  /// Create from JSON
  factory EmergencyContact.fromJson(Map<String, dynamic> json) {
    return EmergencyContact(
      id: json['id'] as String,
      name: json['name'] as String,
      phoneNumber: json['phoneNumber'] as String,
      isEnabled: json['isEnabled'] as bool? ?? true,
      createdAt: DateTime.parse(json['createdAt'] as String),
    );
  }

  /// Save this contact to SharedPreferences
  Future<void> save() async {
    final prefs = await SharedPreferences.getInstance();
    final contacts = await loadAll();

    // Remove existing contact with same ID if exists
    contacts.removeWhere((c) => c.id == id);

    // Add this contact
    contacts.add(this);

    // Save all contacts
    final jsonList = contacts.map((c) => c.toJson()).toList();
    await prefs.setString('emergency_contacts_list', jsonEncode(jsonList));
  }

  /// Delete this contact from SharedPreferences
  Future<void> delete() async {
    final prefs = await SharedPreferences.getInstance();
    final contacts = await loadAll();

    // Remove this contact
    contacts.removeWhere((c) => c.id == id);

    // Save remaining contacts
    final jsonList = contacts.map((c) => c.toJson()).toList();
    await prefs.setString('emergency_contacts_list', jsonEncode(jsonList));
  }

  /// Load all emergency contacts from SharedPreferences
  static Future<List<EmergencyContact>> loadAll() async {
    final prefs = await SharedPreferences.getInstance();
    final jsonString = prefs.getString('emergency_contacts_list');

    if (jsonString == null || jsonString.isEmpty) {
      return [];
    }

    try {
      final List<dynamic> jsonList = jsonDecode(jsonString);
      return jsonList
          .map(
            (json) => EmergencyContact.fromJson(json as Map<String, dynamic>),
          )
          .toList();
    } catch (e) {
      print('Error loading emergency contacts: $e');
      return [];
    }
  }

  /// Create a copy with updated fields
  EmergencyContact copyWith({
    String? name,
    String? phoneNumber,
    bool? isEnabled,
  }) {
    return EmergencyContact(
      id: id,
      name: name ?? this.name,
      phoneNumber: phoneNumber ?? this.phoneNumber,
      isEnabled: isEnabled ?? this.isEnabled,
      createdAt: createdAt,
    );
  }

  @override
  String toString() {
    return 'EmergencyContact(name: $name, phone: $phoneNumber, enabled: $isEnabled)';
  }
}
