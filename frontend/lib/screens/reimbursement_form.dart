import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';

class ReimbursementForm extends StatefulWidget {
  final Function(Map<String, dynamic>) onSubmit;

  const ReimbursementForm({super.key, required this.onSubmit});

  @override
  State<ReimbursementForm> createState() => _ReimbursementFormState();
}

class _ReimbursementFormState extends State<ReimbursementForm> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _amountController = TextEditingController();
  final TextEditingController _projectController = TextEditingController();
  final TextEditingController _descController = TextEditingController();
  DateTime? _selectedDate;
  String? _attachmentName;
  String? _attachmentPath;

  @override
  void dispose() {
    _amountController.dispose();
    _projectController.dispose();
    _descController.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: now,
      firstDate: DateTime(now.year - 5),
      lastDate: DateTime(now.year + 5),
      builder: (context, child) {
        return Theme(
          data: ThemeData.dark().copyWith(
            colorScheme: ColorScheme.dark(
              primary: const Color(0xFF849CFC),
              onPrimary: Colors.white,
              surface: const Color(0xFF1F222B),
              onSurface: Colors.white,
            ),
            dialogBackgroundColor: const Color(0xFF1F222B),
          ),
          child: child!,
        );
      },
    );
    if (picked != null) setState(() => _selectedDate = picked);
  }

  Future<void> _pickAttachment() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['jpg', 'jpeg', 'pdf'],
    );
    if (result != null && result.files.isNotEmpty) {
      setState(() {
        _attachmentName = result.files.first.name;
        _attachmentPath = result.files.first.path;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: const Color(0xFF1F222B),
      title: const Text(
        "New Reimbursement",
        style: TextStyle(color: Colors.white),
      ),
      content: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Date
              InkWell(
                onTap: _pickDate,
                child: InputDecorator(
                  decoration: const InputDecoration(
                    labelText: "Date",
                    labelStyle: TextStyle(color: Colors.white70),
                    enabledBorder: UnderlineInputBorder(
                      borderSide: BorderSide(color: Colors.white24),
                    ),
                  ),
                  child: Text(
                    _selectedDate == null
                        ? "Select Date"
                        : "${_selectedDate!.day}-${_selectedDate!.month}-${_selectedDate!.year}",
                    style: const TextStyle(color: Colors.white),
                  ),
                ),
              ),
              const SizedBox(height: 12),

              // Amount
              TextFormField(
                controller: _amountController,
                keyboardType: TextInputType.number,
                style: const TextStyle(color: Colors.white),
                decoration: const InputDecoration(
                  labelText: "Amount",
                  labelStyle: TextStyle(color: Colors.white70),
                  enabledBorder: UnderlineInputBorder(
                    borderSide: BorderSide(color: Colors.white24),
                  ),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) return "Enter amount";
                  if (int.tryParse(value) == null) return "Enter valid number";
                  return null;
                },
              ),
              const SizedBox(height: 12),

              // Project ID
              TextFormField(
                controller: _projectController,
                style: const TextStyle(color: Colors.white),
                decoration: const InputDecoration(
                  labelText: "Project ID",
                  labelStyle: TextStyle(color: Colors.white70),
                  enabledBorder: UnderlineInputBorder(
                    borderSide: BorderSide(color: Colors.white24),
                  ),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) return "Enter Project ID";
                  return null;
                },
              ),
              const SizedBox(height: 12),

              // Description
              TextFormField(
                controller: _descController,
                style: const TextStyle(color: Colors.white),
                decoration: const InputDecoration(
                  labelText: "Description",
                  labelStyle: TextStyle(color: Colors.white70),
                  enabledBorder: UnderlineInputBorder(
                    borderSide: BorderSide(color: Colors.white24),
                  ),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty)
                    return "Enter description";
                  return null;
                },
              ),
              const SizedBox(height: 12),

              // Attachment
              Row(
                children: [
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF849CFC),
                    ),
                    onPressed: _pickAttachment,
                    child: const Text("Pick Attachment (JPG/PDF)"),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _attachmentName ?? "No file selected",
                      style: const TextStyle(color: Colors.white70),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text("Cancel", style: TextStyle(color: Colors.white70)),
        ),
        ElevatedButton(
          onPressed: () {
            if (_formKey.currentState!.validate()) {
              if (_selectedDate == null) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text("Please select a date")),
                );
                return;
              }
              widget.onSubmit({
                "date": _selectedDate,
                "amount": int.parse(_amountController.text),
                "projectId": _projectController.text,
                "description": _descController.text,
                "attachment": _attachmentPath,
              });
              Navigator.pop(context);
            }
          },
          child: const Text("Submit"),
        ),
      ],
    );
  }
}
