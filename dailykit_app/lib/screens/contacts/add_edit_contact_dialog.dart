import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/contact_model.dart';
import '../../providers/contacts_provider.dart';

class AddEditContactDialog extends StatefulWidget {
  final ContactModel? contact;

  const AddEditContactDialog({super.key, this.contact});

  @override
  State<AddEditContactDialog> createState() => _AddEditContactDialogState();
}

class _AddEditContactDialogState extends State<AddEditContactDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late final TextEditingController _phoneController;
  late final TextEditingController _priorityController;
  bool _isActive = true;
  final String _countryCode = '+91';

  @override
  void initState() {
    super.initState();
    final c = widget.contact;
    _nameController = TextEditingController(text: c?.name ?? '');
    _phoneController = TextEditingController(text: c?.phoneE164 ?? '');
    _priorityController = TextEditingController(text: (c?.priority ?? 1).toString());
    _isActive = c?.isActive ?? true;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _priorityController.dispose();
    super.dispose();
  }

  Future<void> _pickFromPhone() async {
    final provider = context.read<ContactsProvider>();
    final picked = await provider.pickDeviceContact();
    if (picked != null) {
      setState(() {
        if (picked['name']?.isNotEmpty == true) {
          _nameController.text = picked['name']!;
        }
        if (picked['phone']?.isNotEmpty == true) {
          _phoneController.text = picked['phone']!;
        }
      });
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    final provider = context.read<ContactsProvider>();
    final name = _nameController.text.trim();
    final phone = _phoneController.text.trim();
    final priority = int.tryParse(_priorityController.text.trim()) ?? 1;

    bool success;
    if (widget.contact == null) {
      success = await provider.addContact(
        name: name,
        rawPhone: phone,
        defaultCountryCode: _countryCode,
        priority: priority,
        isActive: _isActive,
      );
    } else {
      final normalized = ContactModel.normalizePhone(phone, defaultCountryCode: _countryCode);
      final updated = widget.contact!.copyWith(
        name: name,
        phoneE164: normalized,
        priority: priority,
        isActive: _isActive,
      );
      success = await provider.updateContact(updated);
    }

    if (mounted) {
      if (success) {
        Navigator.of(context).pop();
      } else if (provider.errorMessage != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(provider.errorMessage!),
            backgroundColor: Colors.red.shade700,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isEdit = widget.contact != null;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Header
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    isEdit ? 'Edit Contact' : 'Add Emergency Contact',
                    style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Pick from device contacts button
              OutlinedButton.icon(
                onPressed: _pickFromPhone,
                icon: const Icon(Icons.contacts_rounded),
                label: const Text('Pick from Phone Contacts'),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
              const SizedBox(height: 16),

              // Divider with 'OR'
              Row(
                children: [
                  const Expanded(child: Divider()),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    child: Text('OR ENTER MANUALLY', style: theme.textTheme.labelSmall?.copyWith(color: Colors.grey)),
                  ),
                  const Expanded(child: Divider()),
                ],
              ),
              const SizedBox(height: 16),

              // Name Field
              TextFormField(
                controller: _nameController,
                decoration: InputDecoration(
                  labelText: 'Contact Name *',
                  prefixIcon: const Icon(Icons.person_outline),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
                textCapitalization: TextCapitalization.words,
                validator: (val) {
                  if (val == null || val.trim().isEmpty) {
                    return 'Please enter a contact name';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),

              // Phone Field
              TextFormField(
                controller: _phoneController,
                keyboardType: TextInputType.phone,
                decoration: InputDecoration(
                  labelText: 'Phone Number *',
                  hintText: '+919876543210 or 9876543210',
                  prefixIcon: const Icon(Icons.phone_outlined),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
                validator: (val) {
                  if (val == null || val.trim().isEmpty) {
                    return 'Please enter phone number';
                  }
                  final cleaned = val.replaceAll(RegExp(r'[\s\-\(\)\.]'), '');
                  if (cleaned.length < 7) {
                    return 'Phone number too short';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),

              // Priority Field
              TextFormField(
                controller: _priorityController,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  labelText: 'Alert Priority (1 = Highest)',
                  prefixIcon: const Icon(Icons.format_list_numbered),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
                validator: (val) {
                  if (val != null && val.isNotEmpty) {
                    final num = int.tryParse(val);
                    if (num == null || num < 1) {
                      return 'Priority must be at least 1';
                    }
                  }
                  return null;
                },
              ),
              const SizedBox(height: 12),

              // Active switch
              SwitchListTile(
                title: const Text('Send SOS to this contact'),
                subtitle: const Text('Toggle to include/exclude from SOS SMS'),
                value: _isActive,
                onChanged: (val) => setState(() => _isActive = val),
                contentPadding: EdgeInsets.zero,
              ),
              const SizedBox(height: 20),

              // Submit Button
              ElevatedButton(
                onPressed: _submit,
                style: ElevatedButton.styleFrom(
                  backgroundColor: theme.colorScheme.primary,
                  foregroundColor: theme.colorScheme.onPrimary,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: Text(
                  isEdit ? 'Update Contact' : 'Save Emergency Contact',
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

