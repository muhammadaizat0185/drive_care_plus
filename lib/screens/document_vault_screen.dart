import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../services/vehicle_insights.dart';

class DocumentVaultScreen extends StatefulWidget {
  const DocumentVaultScreen({super.key});

  static const routeName = '/document-vault';

  @override
  State<DocumentVaultScreen> createState() => _DocumentVaultScreenState();
}

class _DocumentVaultScreenState extends State<DocumentVaultScreen> {
  String _selectedFilter = 'All';
  final List<String> _filters = ['All', 'Receipt', 'Insurance', 'Tax'];
  final _scrollController = ScrollController();

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  DateTime? _parseDate(String dateStr) {
    if (dateStr.isEmpty) return null;
    try {
      final parts = dateStr.split('/');
      if (parts.length != 3) return null;
      return DateTime(int.parse(parts[2]), int.parse(parts[1]), int.parse(parts[0]));
    } catch (_) {
      return null;
    }
  }

  int? _daysRemaining(String dateStr) {
    final date = _parseDate(dateStr);
    if (date == null) return null;
    final today = DateTime(DateTime.now().year, DateTime.now().month, DateTime.now().day);
    final diff = date.difference(today);
    return diff.inDays;
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: isDark
              ? [
                  const Color(0xFF0F172A), // Deep Slate Dark
                  const Color(0xFF022C22), // Deep Obsidian Dark Green
                ]
              : [
                  const Color(0xFFEFFDF5), // Soft pastel mint
                  const Color(0xFFF9FAFB), // Soft premium grey
                ],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
      ),
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(title: const Text('Document Vault', style: TextStyle(fontWeight: FontWeight.bold))),
        body: ListenableBuilder(
          listenable: VehicleInsights.instance,
          builder: (context, child) {
            final allDocuments = VehicleInsights.instance.documents;
  
            final filteredDocs = _selectedFilter == 'All'
                ? allDocuments
                : allDocuments.where((doc) => doc['category'] == _selectedFilter).toList();
  
            return Scrollbar(
              controller: _scrollController,
              thumbVisibility: true,
              child: ListView(
                controller: _scrollController,
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 110),
                children: [
                  Card(
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(24),
                      side: BorderSide(
                        color: Theme.of(context).brightness == Brightness.dark ? Colors.white.withOpacity(0.08) : Colors.black.withOpacity(0.05),
                      ),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Vehicle Documents',
                            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: -0.5,
                                ),
                          ),
                          const SizedBox(height: 8),
                          const Text(
                            'Upload receipts, insurance policies, and road tax photos for offline persistence.',
                            style: TextStyle(color: Colors.grey, fontSize: 13),
                          ),
                          const SizedBox(height: 16),
                          ElevatedButton.icon(
                            onPressed: _addDocumentDialog,
                            icon: const Icon(Icons.add_a_photo_outlined),
                            label: const Text('Add Document Photo'),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
  
                  // Filter Tag Row
                  SizedBox(
                    height: 40,
                    child: ListView.builder(
                      scrollDirection: Axis.horizontal,
                      itemCount: _filters.length,
                      itemBuilder: (context, index) {
                        final filter = _filters[index];
                        final isSelected = _selectedFilter == filter;
  
                        return Padding(
                          padding: const EdgeInsets.only(right: 8.0),
                          child: FilterChip(
                            selected: isSelected,
                            label: Text(filter),
                            onSelected: (selected) {
                              setState(() {
                                _selectedFilter = filter;
                              });
                            },
                          ),
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 12),
  
                  if (filteredDocs.isEmpty)
                    Center(
                      child: Padding(
                        padding: const EdgeInsets.all(32),
                        child: Column(
                          children: [
                            const Icon(Icons.folder_open, size: 48, color: Colors.grey),
                            const SizedBox(height: 12),
                            Text(
                              'No documents in Category "$_selectedFilter"',
                              style: const TextStyle(color: Colors.grey, fontWeight: FontWeight.bold),
                            ),
                          ],
                        ),
                      ),
                    )
                  else
                    for (int i = 0; i < filteredDocs.length; i++)
                      _documentCard(filteredDocs[i], allDocuments.indexOf(filteredDocs[i])),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _documentCard(Map<String, dynamic> doc, int globalIndex) {
    final expiryStr = doc['expiryDate'] as String? ?? '';
    final daysLeft = _daysRemaining(expiryStr);

    Color? warningColor;
    String? warningText;
    if (daysLeft != null) {
      if (daysLeft < 0) {
        warningColor = Colors.red.shade700;
        warningText = 'EXPIRED';
      } else if (daysLeft <= 30) {
        warningColor = Colors.amber.shade800;
        warningText = 'Expires in $daysLeft days';
      } else {
        warningColor = Colors.green.shade700;
        warningText = 'Expires in $daysLeft days';
      }
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: const CircleAvatar(
          child: Icon(Icons.description_outlined),
        ),
        title: Text(
          doc['title'] ?? 'Document',
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
            Text('${doc['category']} • ${doc['note'] ?? 'No notes'}'),
            if (warningText != null && warningColor != null) ...[
              const SizedBox(height: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: warningColor.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: warningColor.withOpacity(0.25)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      daysLeft != null && daysLeft < 0 ? Icons.error_outline : Icons.warning_amber_rounded,
                      size: 14,
                      color: warningColor,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      warningText,
                      style: TextStyle(
                        color: warningColor,
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: const Icon(Icons.edit_note, color: Colors.blue),
              tooltip: 'Edit Document',
              onPressed: () => _editDocumentDialog(doc, globalIndex),
            ),
            IconButton(
              icon: const Icon(Icons.delete_outline, color: Colors.red),
              tooltip: 'Delete Document',
              onPressed: () => _confirmDeleteDocument(globalIndex),
            ),
          ],
        ),
      ),
    );
  }

  void _confirmDeleteDocument(int index) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Text('Delete Document?'),
          content: const Text('Are you sure you want to permanently delete this document? This action is offline persistent.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
              onPressed: () async {
                await VehicleInsights.instance.deleteDocument(index);
                if (mounted) {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Document successfully deleted!')),
                  );
                }
              },
              child: const Text('Delete', style: TextStyle(color: Colors.white)),
            ),
          ],
        );
      },
    );
  }

  void _editDocumentDialog(Map<String, dynamic> doc, int index) {
    final titleController = TextEditingController(text: doc['title']);
    String category = doc['category'] ?? 'Receipt';
    final noteController = TextEditingController(text: doc['note'] == 'No notes' ? '' : doc['note']);
    DateTime? expiryDate = _parseDate(doc['expiryDate'] as String? ?? '');
    final stateSetter = ValueNotifier<String>(expiryDate != null ? 'Expires: ${doc['expiryDate']}' : 'Select Expiry Date');

    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (context) {
        final isDark = Theme.of(context).brightness == Brightness.dark;
        final primaryColor = Theme.of(context).colorScheme.primary;

        return StatefulBuilder(
          builder: (context, setDialogState) {
            return Dialog(
              backgroundColor: Colors.transparent,
              elevation: 0,
              child: Container(
                constraints: const BoxConstraints(maxWidth: 400),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF1E293B) : Colors.white,
                  borderRadius: BorderRadius.circular(28),
                  border: Border.all(color: isDark ? Colors.white.withOpacity(0.08) : Colors.black.withOpacity(0.05)),
                ),
                child: SingleChildScrollView(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Edit Document Details',
                          style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: isDark ? Colors.white : const Color(0xFF1F2937)),
                        ),
                        const SizedBox(height: 20),
                        TextField(
                          controller: titleController,
                          style: TextStyle(color: isDark ? Colors.white : Colors.black87),
                          decoration: const InputDecoration(labelText: 'Document Title', prefixIcon: Icon(Icons.title)),
                        ),
                        const SizedBox(height: 16),
                        InputDecorator(
                          decoration: const InputDecoration(labelText: 'Category', prefixIcon: Icon(Icons.category_outlined)),
                          child: DropdownButtonHideUnderline(
                            child: DropdownButton<String>(
                              value: category,
                              dropdownColor: isDark ? const Color(0xFF1E293B) : Colors.white,
                              style: TextStyle(color: isDark ? Colors.white : Colors.black87, fontWeight: FontWeight.w600),
                              isExpanded: true,
                              items: _filters
                                  .where((f) => f != 'All')
                                  .map((f) => DropdownMenuItem(value: f, child: Text(f)))
                                  .toList(),
                              onChanged: (val) {
                                if (val != null) {
                                  setDialogState(() => category = val);
                                }
                              },
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                        TextField(
                          controller: noteController,
                          style: TextStyle(color: isDark ? Colors.white : Colors.black87),
                          decoration: const InputDecoration(labelText: 'Note', prefixIcon: Icon(Icons.notes)),
                        ),
                        const SizedBox(height: 20),
                        ValueListenableBuilder<String>(
                          valueListenable: stateSetter,
                          builder: (context, label, _) {
                            final isPicked = expiryDate != null;
                            return SizedBox(
                              width: double.infinity,
                              height: 48,
                              child: OutlinedButton.icon(
                                style: OutlinedButton.styleFrom(
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                                  foregroundColor: isPicked ? primaryColor : (isDark ? Colors.white70 : Colors.black54),
                                ),
                                onPressed: () async {
                                  final now = DateTime.now();
                                  final picked = await showDatePicker(
                                    context: context,
                                    initialDate: expiryDate ?? now.add(const Duration(days: 30)),
                                    firstDate: now.subtract(const Duration(days: 365)),
                                    lastDate: now.add(const Duration(days: 3650)),
                                  );
                                  if (picked != null) {
                                    expiryDate = picked;
                                    stateSetter.value = 'Expires: ${picked.day}/${picked.month}/${picked.year}';
                                  }
                                },
                                icon: Icon(Icons.calendar_today_outlined, size: 18, color: isPicked ? primaryColor : Colors.grey),
                                label: Text(label, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                              ),
                            );
                          },
                        ),
                        const SizedBox(height: 24),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            TextButton(
                              onPressed: () => Navigator.pop(context),
                              child: const Text('Cancel', style: TextStyle(fontWeight: FontWeight.bold)),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Container(
                                height: 48,
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(colors: [primaryColor, primaryColor.withBlue(120)]),
                                  borderRadius: BorderRadius.circular(16),
                                ),
                                child: ElevatedButton(
                                  style: ElevatedButton.styleFrom(backgroundColor: Colors.transparent, shadowColor: Colors.transparent),
                                  onPressed: () async {
                                    final title = titleController.text.trim();
                                    final note = noteController.text.trim();

                                    if (title.isEmpty) {
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        const SnackBar(content: Text('Please enter a document title.')),
                                      );
                                      return;
                                    }

                                    final expiryStr = expiryDate != null
                                        ? '${expiryDate!.day}/${expiryDate!.month}/${expiryDate!.year}'
                                        : '';

                                    final updatedDoc = {
                                      'title': title,
                                      'category': category,
                                      'note': note.isEmpty ? 'No notes' : note,
                                      'expiryDate': expiryStr,
                                    };

                                    await VehicleInsights.instance.updateDocument(index, updatedDoc);

                                    if (context.mounted) {
                                      Navigator.pop(context);
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        const SnackBar(content: Text('Document successfully updated!')),
                                      );
                                    }
                                  },
                                  child: const Text(
                                    'Save',
                                    style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  void _addDocumentDialog() {
    final titleController = TextEditingController();
    String category = 'Receipt';
    final noteController = TextEditingController();
    DateTime? expiryDate;
    final stateSetter = ValueNotifier<String>('Select Expiry Date');

    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (context) {
        final isDark = Theme.of(context).brightness == Brightness.dark;
        final primaryColor = Theme.of(context).colorScheme.primary;

        return StatefulBuilder(
          builder: (context, setDialogState) {
            return Dialog(
              backgroundColor: Colors.transparent,
              elevation: 0,
              child: Container(
                constraints: const BoxConstraints(maxWidth: 400),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF1E293B) : Colors.white,
                  borderRadius: BorderRadius.circular(28),
                  border: Border.all(color: isDark ? Colors.white.withOpacity(0.08) : Colors.black.withOpacity(0.05)),
                ),
                child: SingleChildScrollView(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Add Document Details',
                          style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: isDark ? Colors.white : const Color(0xFF1F2937)),
                        ),
                        const SizedBox(height: 20),
                        TextField(
                          controller: titleController,
                          style: TextStyle(color: isDark ? Colors.white : Colors.black87),
                          decoration: const InputDecoration(labelText: 'Document Title', prefixIcon: Icon(Icons.title)),
                        ),
                        const SizedBox(height: 16),
                        InputDecorator(
                          decoration: const InputDecoration(labelText: 'Category', prefixIcon: Icon(Icons.category_outlined)),
                          child: DropdownButtonHideUnderline(
                            child: DropdownButton<String>(
                              value: category,
                              dropdownColor: isDark ? const Color(0xFF1E293B) : Colors.white,
                              style: TextStyle(color: isDark ? Colors.white : Colors.black87, fontWeight: FontWeight.w600),
                              isExpanded: true,
                              items: _filters
                                  .where((f) => f != 'All')
                                  .map((f) => DropdownMenuItem(value: f, child: Text(f)))
                                  .toList(),
                              onChanged: (val) {
                                if (val != null) {
                                  setDialogState(() => category = val);
                                }
                              },
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                        TextField(
                          controller: noteController,
                          style: TextStyle(color: isDark ? Colors.white : Colors.black87),
                          decoration: const InputDecoration(labelText: 'Note', prefixIcon: Icon(Icons.notes)),
                        ),
                        const SizedBox(height: 20),
                        ValueListenableBuilder<String>(
                          valueListenable: stateSetter,
                          builder: (context, label, _) {
                            final isPicked = expiryDate != null;
                            return SizedBox(
                              width: double.infinity,
                              height: 48,
                              child: OutlinedButton.icon(
                                style: OutlinedButton.styleFrom(
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                                  foregroundColor: isPicked ? primaryColor : (isDark ? Colors.white70 : Colors.black54),
                                ),
                                onPressed: () async {
                                  final now = DateTime.now();
                                  final picked = await showDatePicker(
                                    context: context,
                                    initialDate: now.add(const Duration(days: 30)),
                                    firstDate: now.subtract(const Duration(days: 365)),
                                    lastDate: now.add(const Duration(days: 3650)),
                                  );
                                  if (picked != null) {
                                    expiryDate = picked;
                                    stateSetter.value = 'Expires: ${picked.day}/${picked.month}/${picked.year}';
                                  }
                                },
                                icon: Icon(Icons.calendar_today_outlined, size: 18, color: isPicked ? primaryColor : Colors.grey),
                                label: Text(label, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                              ),
                            );
                          },
                        ),
                        const SizedBox(height: 24),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            TextButton(
                              onPressed: () => Navigator.pop(context),
                              child: const Text('Cancel', style: TextStyle(fontWeight: FontWeight.bold)),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Container(
                                height: 48,
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(colors: [primaryColor, primaryColor.withBlue(120)]),
                                  borderRadius: BorderRadius.circular(16),
                                ),
                                child: ElevatedButton(
                                  style: ElevatedButton.styleFrom(backgroundColor: Colors.transparent, shadowColor: Colors.transparent),
                                  onPressed: () async {
                                    final title = titleController.text.trim();
                                    final note = noteController.text.trim();

                                    if (title.isEmpty) {
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        const SnackBar(content: Text('Please fill in a document title.')),
                                      );
                                      return;
                                    }

                                    final expiryStr = expiryDate != null
                                        ? '${expiryDate!.day}/${expiryDate!.month}/${expiryDate!.year}'
                                        : '';

                                    final newDoc = {
                                      'title': title,
                                      'category': category,
                                      'note': note.isEmpty ? 'No notes' : note,
                                      'expiryDate': expiryStr,
                                    };

                                    await VehicleInsights.instance.addDocument(newDoc);

                                    if (context.mounted) {
                                      Navigator.pop(context);
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        const SnackBar(content: Text('Document successfully logged!')),
                                      );
                                    }

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
                                          'expiryDate': expiryStr,
                                          'timestamp': FieldValue.serverTimestamp(),
                                        });
                                      } catch (e) {
                                        debugPrint('Firestore document log error: $e');
                                      }
                                    }
                                  },
                                  child: const Text(
                                    'Add',
                                    style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }
}
