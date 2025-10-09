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
  DateTime? requestDate;
  DateTime? projectDate;
  TextEditingController particularsController = TextEditingController();
  TextEditingController amountController = TextEditingController();
  String? attachmentPath;

  void dispose() {
    particularsController.dispose();
    amountController.dispose();
  }
}

class _AdvanceRequestFormScreenState extends State<AdvanceRequestFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final projectIdController = TextEditingController();
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
    for (var entry in payments) entry.dispose();
    super.dispose();
  }

  void _addPayment() {
    setState(() => payments.add(PaymentEntry()));
  }

  void _removePayment(int index) {
    if (payments.length <= 1) return;
    setState(() {
      payments[index].dispose();
      payments.removeAt(index);
    });
  }

  Future<void> _pickRequestDate(
      BuildContext context, PaymentEntry entry) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: entry.requestDate ?? DateTime.now(),
      firstDate: DateTime(2000),
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
        entry.requestDate = picked;
      });
    }
  }

  Future<void> _pickProjectDate(
      BuildContext context, PaymentEntry entry) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: entry.projectDate ?? DateTime.now(),
      firstDate: DateTime(2000),
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
        entry.projectDate = picked;
      });
    }
  }

  Future<void> _pickAttachment(PaymentEntry entry) async {
    final result = await FilePicker.platform.pickFiles();
    if (result != null && result.files.single.path != null) {
      setState(() {
        entry.attachmentPath = result.files.single.path!;
      });
    }
  }

  Future<void> _submitForm() async {
    if (!_formKey.currentState!.validate()) return;

    // Validate all payments first
    for (var payment in payments) {
      if (payment.requestDate == null ||
          payment.projectDate == null ||
          payment.amountController.text.isEmpty ||
          payment.particularsController.text.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("Please fill all payment fields!")));
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

    // Calculate total amount
    double totalAmount = 0;
    for (var payment in payments) {
      totalAmount += double.tryParse(payment.amountController.text) ?? 0;
    }

    // Prepare payments data for JSON
    List<Map<String, dynamic>> paymentData = payments.map((p) {
      return {
        "requestDate": p.requestDate!.toIso8601String().split("T")[0],
        "projectDate": p.projectDate!.toIso8601String().split("T")[0],
        "amount": p.amountController.text,
        "particulars": p.particularsController.text,
        "attachmentPath": p.attachmentPath,
      };
    }).toList();

    // Get the main attachment (use first payment's attachment or null)
    File? mainAttachment =
        payments.isNotEmpty && payments[0].attachmentPath != null
            ? File(payments[0].attachmentPath!)
            : null;

    // ✅ FIXED: Send ONE API call with all payments
    String result = await apiService.submitAdvanceRequest(
      authToken: authToken,
      amount: totalAmount.toString(),
      description: payments.first.particularsController.text,
      requestDate: payments.first.requestDate!.toIso8601String().split("T")[0],
      projectDate: payments.first.projectDate!.toIso8601String().split("T")[0],
      attachment: mainAttachment,
      payments: paymentData, // ✅ Send all payments in one request
    );

    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(result)));

    Map<String, dynamic> advanceData = {
      "projectId": projectIdController.text,
      "payments": paymentData,
      "status": result.toLowerCase().contains("success") ? "Pending" : "Error",
    };

    widget.onSubmit(advanceData);

    setState(() {
      projectIdController.clear();
      for (var entry in payments) entry.dispose();
      payments = [PaymentEntry()];
      _isSubmitting = false;
    });
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
            TextFormField(
              controller: projectIdController,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                labelText: "Project ID",
                labelStyle: const TextStyle(color: Colors.white70),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                filled: true,
                fillColor: const Color(0xFF1F1F1F),
              ),
              validator: (value) =>
                  value == null || value.isEmpty ? "Enter Project ID" : null,
            ),
            const SizedBox(height: 16),
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
                        Text(
                          "Payment ${index + 1}",
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                        const SizedBox(height: 12),
                        GestureDetector(
                          onTap: () => _pickRequestDate(context, entry),
                          child: AbsorbPointer(
                            child: TextFormField(
                              style: const TextStyle(color: Colors.white),
                              decoration: InputDecoration(
                                labelText: entry.requestDate == null
                                    ? "Request Date"
                                    : entry.requestDate
                                        .toString()
                                        .split(" ")[0],
                                labelStyle:
                                    const TextStyle(color: Colors.white70),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(14),
                                ),
                                filled: true,
                                fillColor: const Color(0xFF2A2A2A),
                              ),
                              validator: (_) => entry.requestDate == null
                                  ? "Pick a request date"
                                  : null,
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                        GestureDetector(
                          onTap: () => _pickProjectDate(context, entry),
                          child: AbsorbPointer(
                            child: TextFormField(
                              style: const TextStyle(color: Colors.white),
                              decoration: InputDecoration(
                                labelText: entry.projectDate == null
                                    ? "Project Date"
                                    : entry.projectDate
                                        .toString()
                                        .split(" ")[0],
                                labelStyle:
                                    const TextStyle(color: Colors.white70),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(14),
                                ),
                                filled: true,
                                fillColor: const Color(0xFF2A2A2A),
                              ),
                              validator: (_) => entry.projectDate == null
                                  ? "Pick a project date"
                                  : null,
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: entry.amountController,
                          keyboardType: TextInputType.number,
                          style: const TextStyle(color: Colors.white),
                          decoration: InputDecoration(
                            labelText: "Amount",
                            labelStyle: const TextStyle(color: Colors.white70),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                            filled: true,
                            fillColor: const Color(0xFF2A2A2A),
                          ),
                          validator: (value) => value == null || value.isEmpty
                              ? "Enter amount"
                              : null,
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: entry.particularsController,
                          style: const TextStyle(color: Colors.white),
                          decoration: InputDecoration(
                            labelText: "Particulars",
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
                        Row(
                          children: [
                            InkWell(
                              onTap: () => _pickAttachment(entry),
                              borderRadius: BorderRadius.circular(12),
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  vertical: 10,
                                  horizontal: 14,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.deepPurple,
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: const Text(
                                  "Attach File",
                                  style: TextStyle(color: Colors.white),
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Flexible(
                              child: Text(
                                entry.attachmentPath ?? "No file selected",
                                style: const TextStyle(
                                  color: Colors.white70,
                                  fontSize: 13,
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
                              ),
                          ],
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _addPayment,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.deepPurple,
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
              child: const Text(
                "Add More",
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.deepPurple,
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
              onPressed: _isSubmitting ? null : _submitForm,
              child: _isSubmitting
                  ? const CircularProgressIndicator(color: Colors.white)
                  : const Text(
                      "Submit Advance Request",
                      style: TextStyle(
                        color: Color.fromARGB(255, 203, 196, 196),
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
