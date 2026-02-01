import 'package:flutter/material.dart';
import '../models/emergency_contact.dart';
import '../services/emergency_contact_manager.dart';

class EmergencyContactsScreen extends StatefulWidget {
  const EmergencyContactsScreen({super.key});

  @override
  State<EmergencyContactsScreen> createState() =>
      _EmergencyContactsScreenState();
}

class _EmergencyContactsScreenState extends State<EmergencyContactsScreen> {
  final EmergencyContactManager _manager = EmergencyContactManager();
  List<EmergencyContact> _contacts = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadContacts();
  }

  Future<void> _loadContacts() async {
    setState(() => _isLoading = true);
    try {
      final contacts = await _manager.loadContacts();
      setState(() {
        _contacts = contacts;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to load contacts: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _showAddEditDialog({EmergencyContact? contact}) async {
    final isEditing = contact != null;
    final nameController = TextEditingController(text: contact?.name ?? '');
    final phoneController = TextEditingController(
      text: contact?.phoneNumber ?? '',
    );

    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1D1E33),
        title: Text(
          isEditing ? 'Edit Emergency Contact' : 'Add Emergency Contact',
          style: const TextStyle(color: Colors.white),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameController,
              style: const TextStyle(color: Colors.white),
              decoration: const InputDecoration(
                labelText: 'Name',
                labelStyle: TextStyle(color: Color(0xFF8D8E98)),
                enabledBorder: UnderlineInputBorder(
                  borderSide: BorderSide(color: Color(0xFF8D8E98)),
                ),
                focusedBorder: UnderlineInputBorder(
                  borderSide: BorderSide(color: Color(0xFF00D9FF)),
                ),
              ),
              textCapitalization: TextCapitalization.words,
            ),
            const SizedBox(height: 16),
            TextField(
              controller: phoneController,
              style: const TextStyle(color: Colors.white),
              decoration: const InputDecoration(
                labelText: 'Phone Number',
                labelStyle: TextStyle(color: Color(0xFF8D8E98)),
                hintText: '+1 (555) 123-4567',
                hintStyle: TextStyle(color: Color(0xFF8D8E98)),
                enabledBorder: UnderlineInputBorder(
                  borderSide: BorderSide(color: Color(0xFF8D8E98)),
                ),
                focusedBorder: UnderlineInputBorder(
                  borderSide: BorderSide(color: Color(0xFF00D9FF)),
                ),
              ),
              keyboardType: TextInputType.phone,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text(
              'Cancel',
              style: TextStyle(color: Color(0xFF8D8E98)),
            ),
          ),
          TextButton(
            onPressed: () {
              final name = nameController.text.trim();
              final phone = phoneController.text.trim();

              if (name.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Please enter a name'),
                    backgroundColor: Colors.red,
                  ),
                );
                return;
              }

              if (phone.isEmpty ||
                  !EmergencyContactManager.isValidPhoneNumber(phone)) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Please enter a valid phone number'),
                    backgroundColor: Colors.red,
                  ),
                );
                return;
              }

              Navigator.pop(context, true);
            },
            child: const Text(
              'Save',
              style: TextStyle(
                color: Color(0xFF00D9FF),
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );

    if (result == true) {
      final name = nameController.text.trim();
      final phone = phoneController.text.trim();

      try {
        final newContact = isEditing
            ? contact!.copyWith(name: name, phoneNumber: phone)
            : EmergencyContact(name: name, phoneNumber: phone);

        await _manager.saveContact(newContact);
        await _loadContacts();

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(isEditing ? 'Contact updated' : 'Contact added'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Failed to save contact: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  Future<void> _deleteContact(EmergencyContact contact) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1D1E33),
        title: const Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: Colors.amber),
            SizedBox(width: 12),
            Text('Remove Contact?', style: TextStyle(color: Colors.white)),
          ],
        ),
        content: Text(
          'Are you sure you want to remove ${contact.name} from your emergency contacts?\n\nThey will no longer receive alerts.',
          style: const TextStyle(color: Colors.white),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text(
              'Cancel',
              style: TextStyle(color: Color(0xFF8D8E98)),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text(
              'Remove',
              style: TextStyle(color: Color(0xFFEB1555)),
            ),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await _manager.deleteContact(contact.id);
        await _loadContacts();

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Contact removed'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Failed to delete contact: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  Future<void> _toggleContact(EmergencyContact contact) async {
    try {
      final updated = contact.copyWith(isEnabled: !contact.isEnabled);
      await _manager.saveContact(updated);
      await _loadContacts();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to update contact: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0E21),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1D1E33),
        title: const Text(
          'Emergency Contacts',
          style: TextStyle(color: Colors.white),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF00D9FF)),
              ),
            )
          : Column(
              children: [
                // Info banner
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  color: const Color(0xFF1D1E33),
                  child: Row(
                    children: const [
                      Icon(Icons.info_outline, color: Color(0xFF00D9FF)),
                      SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'These contacts will be notified when you\'re in danger',
                          style: TextStyle(
                            color: Color(0xFF8D8E98),
                            fontSize: 14,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                // Contacts list
                Expanded(
                  child: _contacts.isEmpty
                      ? _buildEmptyState()
                      : ListView.builder(
                          padding: const EdgeInsets.all(16),
                          itemCount: _contacts.length,
                          itemBuilder: (context, index) {
                            final contact = _contacts[index];
                            return _buildContactCard(contact);
                          },
                        ),
                ),
              ],
            ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showAddEditDialog(),
        backgroundColor: const Color(0xFF00D9FF),
        child: const Icon(Icons.add, color: Colors.white),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.group_outlined, size: 80, color: Color(0xFF8D8E98)),
          const SizedBox(height: 24),
          const Text(
            'No Emergency Contacts Yet',
            style: TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 40),
            child: Text(
              'Add trusted contacts who will be notified if you\'re in danger.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Color(0xFF8D8E98), fontSize: 14),
            ),
          ),
          const SizedBox(height: 32),
          ElevatedButton.icon(
            onPressed: () => _showAddEditDialog(),
            icon: const Icon(Icons.add),
            label: const Text('Add First Contact'),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF00D9FF),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildContactCard(EmergencyContact contact) {
    return Card(
      color: const Color(0xFF1D1E33),
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            // Avatar
            CircleAvatar(
              backgroundColor: contact.isEnabled
                  ? const Color(0xFF00D9FF)
                  : const Color(0xFF8D8E98),
              child: Icon(
                Icons.person,
                color: contact.isEnabled
                    ? Colors.white
                    : const Color(0xFF1D1E33),
              ),
            ),
            const SizedBox(width: 16),

            // Name and phone
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    contact.name,
                    style: TextStyle(
                      color: contact.isEnabled
                          ? Colors.white
                          : const Color(0xFF8D8E98),
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    EmergencyContactManager.formatPhoneNumber(
                      contact.phoneNumber,
                    ),
                    style: TextStyle(
                      color: contact.isEnabled
                          ? const Color(0xFF8D8E98)
                          : const Color(0xFF8D8E98).withOpacity(0.5),
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ),

            // Toggle switch
            Switch(
              value: contact.isEnabled,
              onChanged: (_) => _toggleContact(contact),
              activeColor: const Color(0xFF00D9FF),
            ),

            // Edit button
            IconButton(
              icon: const Icon(Icons.edit, color: Color(0xFF00D9FF)),
              onPressed: () => _showAddEditDialog(contact: contact),
            ),

            // Delete button
            IconButton(
              icon: const Icon(Icons.delete, color: Color(0xFFEB1555)),
              onPressed: () => _deleteContact(contact),
            ),
          ],
        ),
      ),
    );
  }
}
