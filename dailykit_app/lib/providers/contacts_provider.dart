import 'package:flutter/material.dart';
import 'package:flutter_contacts/flutter_contacts.dart';
import '../models/contact_model.dart';
import '../services/database_helper.dart';

class ContactsProvider extends ChangeNotifier {
  final DatabaseHelper _db = DatabaseHelper.instance;

  List<ContactModel> _contacts = [];
  bool _isLoading = false;
  String? _errorMessage;

  List<ContactModel> get contacts => _contacts;
  List<ContactModel> get activeContacts => _contacts.where((c) => c.isActive).toList();
  int get activeCount => activeContacts.length;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  ContactsProvider() {
    loadContacts();
  }

  Future<void> loadContacts() async {
    _isLoading = true;
    notifyListeners();

    try {
      _contacts = await _db.getContacts();
      _errorMessage = null;
    } catch (e) {
      _errorMessage = 'Failed to load local contacts: $e';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> addContact({
    required String name,
    required String rawPhone,
    String defaultCountryCode = '+91',
    int priority = 1,
    bool isActive = true,
  }) async {
    try {
      final normalized = ContactModel.normalizePhone(
        rawPhone,
        defaultCountryCode: defaultCountryCode,
      );

      // Check if duplicate exists in local list
      if (_contacts.any((c) => c.phoneE164 == normalized)) {
        _errorMessage = 'This phone number already exists in your emergency contacts.';
        notifyListeners();
        return false;
      }

      final newContact = ContactModel(
        name: name.trim(),
        phoneE164: normalized,
        isActive: isActive,
        priority: priority,
        isSynced: false,
        updatedAt: DateTime.now(),
      );

      final id = await _db.insertContact(newContact);
      final createdContact = newContact.copyWith(id: id);
      _contacts.add(createdContact);
      _contacts.sort((a, b) => a.priority.compareTo(b.priority));
      _errorMessage = null;
      notifyListeners();
      return true;
    } catch (e) {
      _errorMessage = 'Error adding contact: $e';
      notifyListeners();
      return false;
    }
  }

  Future<bool> updateContact(ContactModel contact) async {
    try {
      await _db.updateContact(contact.copyWith(
        isSynced: false,
        updatedAt: DateTime.now(),
      ));

      final index = _contacts.indexWhere((c) => c.id == contact.id);
      if (index != -1) {
        _contacts[index] = contact;
        _contacts.sort((a, b) => a.priority.compareTo(b.priority));
      }
      _errorMessage = null;
      notifyListeners();
      return true;
    } catch (e) {
      _errorMessage = 'Error updating contact: $e';
      notifyListeners();
      return false;
    }
  }

  Future<bool> deleteContact(int id) async {
    try {
      await _db.deleteContact(id);
      _contacts.removeWhere((c) => c.id == id);
      _errorMessage = null;
      notifyListeners();
      return true;
    } catch (e) {
      _errorMessage = 'Error deleting contact: $e';
      notifyListeners();
      return false;
    }
  }

  Future<void> toggleActive(ContactModel contact) async {
    final updated = contact.copyWith(isActive: !contact.isActive);
    await updateContact(updated);
  }

  /// Opens the native phone address book and allows user to select a contact
  Future<Map<String, String>?> pickDeviceContact() async {
    final permission = await FlutterContacts.requestPermission(readonly: true);
    if (!permission) {
      _errorMessage = 'Contacts read permission denied by user.';
      notifyListeners();
      return null;
    }

    final contact = await FlutterContacts.openExternalPick();
    if (contact != null) {
      final fullContact = await FlutterContacts.getContact(contact.id);
      final name = fullContact?.displayName ?? contact.displayName;
      final phone = (fullContact?.phones.isNotEmpty == true)
          ? fullContact!.phones.first.number
          : (contact.phones.isNotEmpty ? contact.phones.first.number : '');

      return {
        'name': name,
        'phone': phone,
      };
    }
    return null;
  }

  Future<void> syncWithCloud() async {
    await loadContacts();
  }
}

