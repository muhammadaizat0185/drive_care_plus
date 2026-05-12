import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class DocumentVaultScreen extends StatefulWidget {
  const DocumentVaultScreen({super.key});

  static const routeName = '/document-vault';

  @override
  State<DocumentVaultScreen> createState() => _DocumentVaultScreenState();
}

class _DocumentVaultScreenState extends State<DocumentVaultScreen> {
  final List<_VaultDocument> _documents = [
    const _VaultDocument(
      title: 'Insurance Policy',
      category: 'Insurance',
      note: 'Expires 18 Dec 2026',
    ),
    const _VaultDocument(
      title: 'Oil Service Receipt',
      category: 'Receipt',
      note: 'Saved after 30,000 km service',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Document Vault')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Vehicle Documents',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Upload receipts, insurance policies, and road tax photos.',
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton.icon(
                    onPressed: _addDummyDocument,
                    icon: const Icon(Icons.add_a_photo_outlined),
                    label: const Text('Add Document Photo'),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Firebase point: use image_picker for photos and Firebase Storage for uploads.',
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          for (final document in _documents)
            Card(
              child: ListTile(
                leading: const Icon(Icons.description_outlined),
                title: Text(document.title),
                subtitle: Text('${document.category} • ${document.note}'),
                trailing: const Icon(Icons.chevron_right),
              ),
            ),
        ],
      ),
    );
  }

  void _addDummyDocument() {
    final titleController = TextEditingController();
    final categoryController = TextEditingController(text: 'Receipt');
    final noteController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Add Document details'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: titleController,
                decoration: const InputDecoration(
                  labelText: 'Document Title',
                  hintText: 'e.g. Engine Oil Service',
                ),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: categoryController,
                decoration: const InputDecoration(
                  labelText: 'Category',
                  hintText: 'e.g. Receipt, Insurance, Tax',
                ),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: noteController,
                decoration: const InputDecoration(
                  labelText: 'Note',
                  hintText: 'e.g. Checked at 40,000 km',
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                final title = titleController.text.trim();
                final category = categoryController.text.trim();
                final note = noteController.text.trim();

                if (title.isEmpty || category.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Please fill in title and category.')),
                  );
                  return;
                }

                setState(() {
                  _documents.insert(
                    0,
                    _VaultDocument(
                      title: title,
                      category: category,
                      note: note.isEmpty ? 'No extra notes' : note,
                    ),
                  );
                });

                Navigator.pop(context);

                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Document successfully logged!')),
                );

                // Save to Firestore under users/{uid}/documents
                final user = FirebaseAuth.instance.currentUser;
                if (user != null) {
                  try {
                    await FirebaseFirestore.instance
                        .collection('users')
                        .doc(user.uid)
                        .collection('documents')
                        .add({
                      'title': title,
                      'category': category,
                      'note': note,
                      'timestamp': FieldValue.serverTimestamp(),
                    });
                  } catch (e) {
                    debugPrint('Firestore document log error: $e');
                  }
                }
              },
              child: const Text('Add'),
            ),
          ],
        );
      },
    );
  }
}

class _VaultDocument {
  const _VaultDocument({
    required this.title,
    required this.category,
    required this.note,
  });

  final String title;
  final String category;
  final String note;
}
