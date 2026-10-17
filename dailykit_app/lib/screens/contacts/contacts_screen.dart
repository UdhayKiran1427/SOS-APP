import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/contacts_provider.dart';
import '../../models/contact_model.dart';
import '../../widgets/contact_tile.dart';
import 'add_edit_contact_dialog.dart';

class ContactsScreen extends StatelessWidget {
  const ContactsScreen({super.key});

  void _showAddDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => const AddEditContactDialog(),
    );
  }

  void _showEditDialog(BuildContext context, ContactModel contact) {
    showDialog(
      context: context,
      builder: (context) => AddEditContactDialog(contact: contact),
    );
  }

  void _confirmDelete(BuildContext context, ContactModel contact) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Contact?'),
        content: Text('Are you sure you want to remove "${contact.name}" from your emergency contacts?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red.shade700,
              foregroundColor: Colors.white,
            ),
            onPressed: () async {
              Navigator.of(ctx).pop();
              if (contact.id != null) {
                await context.read<ContactsProvider>().deleteContact(contact.id!);
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Removed "${contact.name}"')),
                  );
                }
              }
            },
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final contactsProvider = context.watch<ContactsProvider>();
    final contacts = contactsProvider.contacts;
    final activeCount = contactsProvider.activeCount;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Emergency Contacts', style: TextStyle(fontWeight: FontWeight.bold)),
        actions: [
          IconButton(
            tooltip: 'Sync with Cloud',
            icon: contactsProvider.isLoading
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.sync),
            onPressed: contactsProvider.isLoading
                ? null
                : () async {
                    await contactsProvider.syncWithCloud();
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Contacts synced with cloud!')),
                      );
                    }
                  },
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showAddDialog(context),
        icon: const Icon(Icons.person_add),
        label: const Text('Add Contact'),
      ),
      body: Column(
        children: [
          // Status banner
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            color: activeCount > 0
                ? theme.colorScheme.primaryContainer.withAlpha(100)
                : Colors.amber.shade100,
            child: Row(
              children: [
                Icon(
                  activeCount > 0 ? Icons.check_circle_outline : Icons.warning_amber_rounded,
                  color: activeCount > 0 ? theme.colorScheme.primary : Colors.amber.shade900,
                  size: 20,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    activeCount > 0
                        ? '$activeCount contact${activeCount > 1 ? 's' : ''} ready to receive SOS alert'
                        : 'No active emergency contacts! SOS SMS cannot be sent.',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: activeCount > 0 ? theme.colorScheme.onPrimaryContainer : Colors.amber.shade900,
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Contacts list
          Expanded(
            child: RefreshIndicator(
              onRefresh: () => contactsProvider.syncWithCloud(),
              child: contacts.isEmpty
                  ? Center(
                      child: SingleChildScrollView(
                        physics: const AlwaysScrollableScrollPhysics(),
                        padding: const EdgeInsets.all(32),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.contact_phone_outlined,
                              size: 80,
                              color: theme.colorScheme.primary.withAlpha(100),
                            ),
                            const SizedBox(height: 16),
                            Text(
                              'No Emergency Contacts Yet',
                              style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Add trusted contacts who should receive your GPS location when you trigger an SOS.',
                              textAlign: TextAlign.center,
                              style: TextStyle(color: Colors.grey.shade600),
                            ),
                            const SizedBox(height: 24),
                            ElevatedButton.icon(
                              onPressed: () => _showAddDialog(context),
                              icon: const Icon(Icons.add),
                              label: const Text('Add First Contact'),
                              style: ElevatedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                              ),
                            ),
                          ],
                        ),
                      ),
                    )
                  : ListView.builder(
                      itemCount: contacts.length,
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      itemBuilder: (context, index) {
                        final contact = contacts[index];
                        return ContactTile(
                          contact: contact,
                          onToggleActive: (_) => contactsProvider.toggleActive(contact),
                          onEdit: () => _showEditDialog(context, contact),
                          onDelete: () => _confirmDelete(context, contact),
                        );
                      },
                    ),
            ),
          ),
        ],
      ),
    );
  }
}

