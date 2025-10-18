import 'package:flutter/material.dart';
import 'dart:io';
import '../services/api_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:file_picker/file_picker.dart';

class AdvanceRequestFormScreen extends StatefulWidget {
  final Function(Map<String, dynamic>) onSubmit;

  const AdvanceRequestFormScreen({super.key, required this.onSubmit});

  @override
  State<AdvanceRequestFormScreen> createState() =>
      _AdvanceRequestFormScreenState();
}

class PaymentEntry {
  DateTime requestDate = DateTime.now();
  DateTime? projectDate;
  TextEditingController particularsController = TextEditingController();
  TextEditingController amountController = TextEditingController();
  TextEditingController requestDateController = TextEditingController();
  TextEditingController projectDateController =
      TextEditingController(); // ✅ NEW CONTROLLER FOR PROJECT DATE
  List<String> attachmentPaths = [];

  PaymentEntry() {
    // ✅ AUTOMATICALLY SET REQUEST DATE
    requestDateController.text = _formatDate(requestDate);
  }

  String _formatDate(DateTime date) {
    return "${date.toLocal()}".split(' ')[0];
  }

  void updateProjectDate(DateTime date) {
    projectDate = date;
    projectDateController.text =
        _formatDate(date); // ✅ UPDATE CONTROLLER WHEN DATE CHANGES
  }

  void dispose() {
    particularsController.dispose();
    amountController.dispose();
    requestDateController.dispose();
    projectDateController.dispose(); // ✅ DISPOSE PROJECT DATE CONTROLLER
  }
}

class _AdvanceRequestFormScreenState extends State<AdvanceRequestFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final projectIdController = TextEditingController();
  final projectNameController = TextEditingController();
  List<PaymentEntry> payments = [];
  final ApiService apiService = ApiService();
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    payments.add(PaymentEntry());
  }

  @override
  void dispose() {
    projectIdController.dispose();
    projectNameController.dispose();
    for (var entry in payments) entry.dispose();
    super.dispose();
  }

  void _addPayment() {
    setState(() {
      payments.add(PaymentEntry());
    });
  }

  void _removePayment(int index) {
    if (payments.length <= 1) return;
    setState(() {
      payments[index].dispose();
      payments.removeAt(index);
    });
  }

  Future<void> _pickProjectDate(
      BuildContext context, PaymentEntry entry) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: entry.projectDate ?? DateTime.now(),
      firstDate: DateTime.now(), // ✅ ONLY TODAY OR FUTURE DATES
      lastDate: DateTime(2100),
      builder: (context, child) => Theme(
        data: ThemeData.dark().copyWith(
          colorScheme: const ColorScheme.dark(
            primary: Colors.deepPurple,
            onPrimary: Colors.white,
            surface: Colors.black,
            onSurface: Colors.white,
          ),
          dialogBackgroundColor: Colors.black,
        ),
        child: child!,
      ),
    );
    if (picked != null) {
      setState(() {
        entry.updateProjectDate(picked); // ✅ USE UPDATED METHOD
      });
    }
  }

  Future<void> _pickAttachments(PaymentEntry entry) async {
    final result = await FilePicker.platform.pickFiles(
      allowMultiple: true,
      type: FileType.custom,
      allowedExtensions: ['pdf', 'doc', 'docx', 'jpg', 'jpeg', 'png'],
    );

    if (result != null && result.files.isNotEmpty) {
      setState(() {
        for (var file in result.files) {
          if (file.path != null) {
            entry.attachmentPaths.add(file.path!);
          }
        }
      });
    }
  }

  void _removeAttachment(PaymentEntry entry, int index) {
    setState(() {
      entry.attachmentPaths.removeAt(index);
    });
  }

  String _getFileName(String path) {
    return path.split('/').last;
  }

  Future<void> _submitForm() async {
    if (!_formKey.currentState!.validate()) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Please fill all required fields!")));
      return;
    }

    for (var payment in payments) {
      if (payment.projectDate == null ||
          payment.amountController.text.isEmpty ||
          payment.particularsController.text.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("Please fill all payment fields!")));
        return;
      }

      final today = DateTime.now();
      final projectDate = payment.projectDate!;
      if (projectDate.isBefore(DateTime(today.year, today.month, today.day))) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text("Project date must be today or after today!")));
        return;
      }

      final amount = double.tryParse(payment.amountController.text);
      if (amount == null || amount <= 0) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text("Please enter a valid positive amount!")));
        return;
      }
    }

    setState(() => _isSubmitting = true);

    SharedPreferences prefs = await SharedPreferences.getInstance();
    String? authToken = prefs.getString('authToken');
    if (authToken == null) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text("Auth token missing!")));
      setState(() => _isSubmitting = false);
      return;
    }

    try {
      double totalAmount = 0;
      for (var payment in payments) {
        totalAmount += double.tryParse(payment.amountController.text) ?? 0;
      }

      List<Map<String, dynamic>> paymentData = payments.map((p) {
        return {
          "requestDate": p.requestDate.toIso8601String().split("T")[0],
          "projectDate": p.projectDate!.toIso8601String().split("T")[0],
          "amount": p.amountController.text,
          "particulars": p.particularsController.text,
          "attachmentPaths": p.attachmentPaths,
        };
      }).toList();

      List<File> allAttachments = [];
      for (var payment in payments) {
        for (var path in payment.attachmentPaths) {
          allAttachments.add(File(path));
        }
      }

      String result = await apiService.submitAdvanceRequest(
        authToken: authToken,
        projectId: projectIdController.text, // ✅ ADD PROJECT ID
        projectName: projectNameController.text, // ✅ ADD PROJECT NAME

        amount: totalAmount.toString(),
        description: payments.first.particularsController.text,
        requestDate: payments.first.requestDate.toIso8601String().split("T")[0],
        projectDate:
            payments.first.projectDate!.toIso8601String().split("T")[0],
        attachments: allAttachments,
        payments: paymentData,
      );

      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(result)));

      Map<String, dynamic> advanceData = {
        "projectId": projectIdController.text,
        "projectName": projectNameController.text,
        "totalAmount": totalAmount,
        "payments": paymentData,
        "status":
            result.toLowerCase().contains("success") ? "Pending" : "Error",
        "submissionDate": DateTime.now().toIso8601String(),
      };

      widget.onSubmit(advanceData);

      if (result.toLowerCase().contains("success")) {
        setState(() {
          projectIdController.clear();
          projectNameController.clear();
          for (var entry in payments) entry.dispose();
          payments = [PaymentEntry()];
        });
      }
    } catch (e) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text("Error submitting form: $e")));
    } finally {
      setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF181A20),
      appBar: AppBar(
        title: const Text("Advance Request Form"),
        backgroundColor: const Color.fromARGB(255, 148, 99, 233),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // Project Information Section
            Card(
              color: const Color(0xFF1F1F1F),
              elevation: 6,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              margin: const EdgeInsets.only(bottom: 16),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      "Project Information",
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 18,
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: projectIdController,
                      style: const TextStyle(color: Colors.white),
                      decoration: InputDecoration(
                        labelText: "Project ID *",
                        labelStyle: const TextStyle(color: Colors.white70),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        filled: true,
                        fillColor: const Color(0xFF2A2A2A),
                      ),
                      validator: (value) => value == null || value.isEmpty
                          ? "Enter Project ID"
                          : null,
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: projectNameController,
                      style: const TextStyle(color: Colors.white),
                      decoration: InputDecoration(
                        labelText: "Project Name *",
                        labelStyle: const TextStyle(color: Colors.white70),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        filled: true,
                        fillColor: const Color(0xFF2A2A2A),
                      ),
                      validator: (value) => value == null || value.isEmpty
                          ? "Enter Project Name"
                          : null,
                    ),
                  ],
                ),
              ),
            ),

            // Payments Section
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: payments.length,
              itemBuilder: (context, index) {
                PaymentEntry entry = payments[index];
                return Card(
                  color: const Color(0xFF1F1F1F),
                  elevation: 6,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  margin: const EdgeInsets.symmetric(vertical: 10),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              "Payment ${index + 1} *",
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
                            if (entry.projectDate != null &&
                                entry.projectDate!.isBefore(DateTime.now()))
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: Colors.red,
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: const Text(
                                  "Past Date!",
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            if (payments.length > 1)
                              IconButton(
                                onPressed: () => _removePayment(index),
                                icon: const Icon(
                                  Icons.delete,
                                  color: Colors.redAccent,
                                ),
                                tooltip: "Remove Payment",
                              ),
                          ],
                        ),
                        const SizedBox(height: 12),

                        // ✅ REQUEST DATE - AUTO SHOWS
                        TextFormField(
                          controller: entry.requestDateController,
                          enabled: false,
                          style: const TextStyle(color: Colors.white),
                          decoration: InputDecoration(
                            labelText: "Request Date *",
                            labelStyle: const TextStyle(color: Colors.white70),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                            filled: true,
                            fillColor: const Color(0xFF2A2A2A).withOpacity(0.7),
                          ),
                        ),
                        const SizedBox(height: 12),

                        // ✅ PROJECT DATE - NOW SHOWS PROPERLY
                        GestureDetector(
                          onTap: () => _pickProjectDate(context, entry),
                          child: AbsorbPointer(
                            child: TextFormField(
                              controller: entry
                                  .projectDateController, // ✅ CONTROLLER ADDED
                              style: const TextStyle(color: Colors.white),
                              decoration: InputDecoration(
                                labelText: "Project Date *",
                                hintText:
                                    "Select project date (Today or future)",
                                labelStyle:
                                    const TextStyle(color: Colors.white70),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(14),
                                ),
                                filled: true,
                                fillColor: const Color(0xFF2A2A2A),
                                suffixIcon: const Icon(Icons.calendar_today,
                                    color: Colors.white70),
                              ),
                              validator: (_) {
                                if (entry.projectDate == null) {
                                  return "Pick a project date";
                                }
                                if (entry.projectDate!
                                    .isBefore(DateTime.now())) {
                                  return "Project date must be today or future!";
                                }
                                return null;
                              },
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),

                        // Amount Field
                        TextFormField(
                          controller: entry.amountController,
                          keyboardType:
                              TextInputType.numberWithOptions(decimal: true),
                          style: const TextStyle(color: Colors.white),
                          decoration: InputDecoration(
                            labelText: "Amount *",
                            labelStyle: const TextStyle(color: Colors.white70),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                            filled: true,
                            fillColor: const Color(0xFF2A2A2A),
                            prefixText: "₹ ",
                            prefixStyle: const TextStyle(color: Colors.white),
                          ),
                          validator: (value) => value == null || value.isEmpty
                              ? "Enter amount"
                              : null,
                        ),
                        const SizedBox(height: 12),

                        // Particulars Field
                        TextFormField(
                          controller: entry.particularsController,
                          style: const TextStyle(color: Colors.white),
                          maxLines: 2,
                          decoration: InputDecoration(
                            labelText: "Particulars *",
                            labelStyle: const TextStyle(color: Colors.white70),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                            filled: true,
                            fillColor: const Color(0xFF2A2A2A),
                          ),
                          validator: (value) => value == null || value.isEmpty
                              ? "Enter particulars"
                              : null,
                        ),
                        const SizedBox(height: 12),

                        // Attachments Section
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              "Attachments (Optional)",
                              style: TextStyle(
                                color: Colors.white70,
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 8),
                            if (entry.attachmentPaths.isNotEmpty) ...[
                              ...entry.attachmentPaths
                                  .asMap()
                                  .entries
                                  .map((fileEntry) {
                                return Container(
                                  margin: const EdgeInsets.only(bottom: 8),
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF2A2A2A),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Row(
                                    children: [
                                      const Icon(Icons.attach_file,
                                          color: Colors.white70, size: 16),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: Text(
                                          _getFileName(fileEntry.value),
                                          style: const TextStyle(
                                            color: Colors.white70,
                                            fontSize: 12,
                                          ),
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                      IconButton(
                                        onPressed: () => _removeAttachment(
                                            entry, fileEntry.key),
                                        icon: const Icon(Icons.close,
                                            color: Colors.redAccent, size: 16),
                                        padding: EdgeInsets.zero,
                                        constraints: const BoxConstraints(),
                                      ),
                                    ],
                                  ),
                                );
                              }),
                              const SizedBox(height: 8),
                            ],
                            InkWell(
                              onTap: () => _pickAttachments(entry),
                              borderRadius: BorderRadius.circular(12),
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  vertical: 12,
                                  horizontal: 16,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.deepPurple,
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: const [
                                    Icon(Icons.attach_file,
                                        color: Colors.white, size: 18),
                                    SizedBox(width: 8),
                                    Text(
                                      "Add Attachments",
                                      style: TextStyle(color: Colors.white),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),

            // Add Another Payment Button
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _addPayment,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.deepPurple,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.add, color: Colors.white),
                  SizedBox(width: 8),
                  Text(
                    "Add Another Payment",
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),

            // Submit Button
            const SizedBox(height: 24),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.deepPurple,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              onPressed: _isSubmitting ? null : _submitForm,
              child: _isSubmitting
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 2,
                      ),
                    )
                  : const Text(
                      "Submit Advance Request",
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }
}
