import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'dart:io';
import '../services/api_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ReimbursementFormScreen extends StatefulWidget {
  final Function(Map<String, dynamic>) onSubmit;

  const ReimbursementFormScreen({super.key, required this.onSubmit});

  @override
  State<ReimbursementFormScreen> createState() =>
      _ReimbursementFormScreenState();
}

class PaymentEntry {
  DateTime? paymentDate;
  final TextEditingController descriptionController = TextEditingController();
  final TextEditingController amountController = TextEditingController();
  String claimType = "Travel";
  String? customClaimType;
  List<String> attachmentPaths = [];
  String? attachmentError;

  void dispose() {
    descriptionController.dispose();
    amountController.dispose();
  }
}

class _ReimbursementFormScreenState extends State<ReimbursementFormScreen> {
  final _formKey = GlobalKey<FormState>();
  DateTime? reimbursementDate;
  final projectIdController = TextEditingController();
  List<PaymentEntry> payments = [];
  final ApiService apiService = ApiService();
  bool _isSubmitting = false;
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    reimbursementDate = DateTime.now();
    payments.add(PaymentEntry());
  }

  @override
  void dispose() {
    projectIdController.dispose();
    _scrollController.dispose();
    for (var entry in payments) {
      entry.dispose();
    }
    super.dispose();
  }

  void _addPayment() {
    setState(() {
      payments.add(PaymentEntry());
    });
    // Scroll to bottom after adding new payment
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    });
  }

  void _removePayment(int index) {
    setState(() {
      payments[index].dispose();
      payments.removeAt(index);
    });
  }

  Future<void> _pickPaymentDate(
    BuildContext context,
    PaymentEntry entry,
  ) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: entry.paymentDate ?? DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime.now(),
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
        entry.paymentDate = picked;
        entry.attachmentError = null;
      });
    }
  }

  Future<void> _pickAttachments(PaymentEntry entry) async {
    try {
      final result = await FilePicker.platform.pickFiles(
        allowMultiple: true,
        type: FileType.custom,
        allowedExtensions: [
          'pdf',
          'doc',
          'docx',
          'xls',
          'xlsx',
          'jpg',
          'jpeg',
          'png'
        ],
      );

      if (result != null && result.files.isNotEmpty) {
        setState(() {
          for (var file in result.files) {
            if (file.path != null) {
              entry.attachmentPaths.add(file.path!);
            }
          }
          entry.attachmentError = null;
        });
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Error picking files: $e"),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _removeAttachment(PaymentEntry entry, int attachmentIndex) {
    setState(() {
      entry.attachmentPaths.removeAt(attachmentIndex);
      if (entry.attachmentPaths.isEmpty) {
        entry.attachmentError = "At least one attachment is required";
      }
    });
  }

  bool _validateAttachments() {
    bool isValid = true;
    for (var payment in payments) {
      if (payment.attachmentPaths.isEmpty) {
        setState(() {
          payment.attachmentError = "At least one attachment is required";
        });
        isValid = false;
      } else {
        setState(() {
          payment.attachmentError = null;
        });
      }
    }
    return isValid;
  }

  Future<void> _submitForm() async {
    if (!_validateAttachments()) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Please add attachments for all payments!"),
          backgroundColor: Colors.orange,
          duration: Duration(seconds: 3),
        ),
      );
      return;
    }

    if (!_formKey.currentState!.validate()) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Please fill all required fields!"),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    for (var payment in payments) {
      if (payment.paymentDate == null ||
          payment.amountController.text.isEmpty ||
          payment.descriptionController.text.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Please fill all payment fields!"),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }

      if (payment.claimType == "Other" &&
          (payment.customClaimType == null ||
              payment.customClaimType!.isEmpty)) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content:
                Text("Please specify the claim type for 'Other' category!"),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }

      if (payment.paymentDate!.isAfter(DateTime.now())) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Payment date cannot be in future!"),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }
    }

    setState(() {
      _isSubmitting = true;
    });

    try {
      SharedPreferences prefs = await SharedPreferences.getInstance();
      String? authToken = prefs.getString('authToken');

      if (authToken == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Auth token missing!"),
            backgroundColor: Colors.red,
          ),
        );
        setState(() {
          _isSubmitting = false;
        });
        return;
      }

      double totalAmount = 0;
      for (var payment in payments) {
        totalAmount += double.tryParse(payment.amountController.text) ?? 0;
      }

      List<Map<String, dynamic>> paymentData = payments.map((p) {
        String finalClaimType =
            p.claimType == "Other" ? p.customClaimType! : p.claimType;

        return {
          "date": p.paymentDate!.toIso8601String().split("T")[0],
          "amount": p.amountController.text,
          "description": p.descriptionController.text,
          "claimType": finalClaimType,
          "attachmentPaths": p.attachmentPaths,
        };
      }).toList();

      List<File> allAttachments = [];
      for (var payment in payments) {
        for (var path in payment.attachmentPaths) {
          allAttachments.add(File(path));
        }
      }

      String combinedDescription =
          payments.map((p) => p.descriptionController.text).join('; ');

      String result = await apiService.submitReimbursement(
        authToken: authToken,
        amount: totalAmount.toString(),
        description: combinedDescription,
        attachments: allAttachments,
        date: reimbursementDate!.toIso8601String().split("T")[0],
        payments: paymentData,
        projectId: projectIdController.text,
      );

      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(result)));
      // ✅ ADD THIS ONE LINE:
      if (result.toLowerCase().contains("success")) Navigator.pop(context);

      Map<String, dynamic> reimbursementData = {
        "reimbursementDate": reimbursementDate,
        "projectId": projectIdController.text,
        "payments": paymentData,
        "status":
            result.toLowerCase().contains("success") ? "Pending" : "Error",
      };

      widget.onSubmit(reimbursementData);

      // Reset form
      // setState(() {
      //   reimbursementDate = DateTime.now();
      //   projectIdController.clear();
      //   for (var entry in payments) entry.dispose();
      //    payments = [PaymentEntry()];
      //  _isSubmitting = false;
      //    });
      // ✅ INSTEAD JUST DO THIS:
      setState(() {
        _isSubmitting = false;
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Submission failed: $e"),
          backgroundColor: Colors.red,
        ),
      );
      setState(() {
        _isSubmitting = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final isSmallScreen = MediaQuery.of(context).size.width < 600;
    final isVerySmallScreen = MediaQuery.of(context).size.width < 400;

    return Scaffold(
      backgroundColor: const Color.fromARGB(255, 33, 33, 33),
      appBar: AppBar(
        title: const Text("Reimbursement Form"),
        backgroundColor: const Color.fromARGB(255, 148, 99, 233),
        elevation: 2,
      ),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              // Header with payment count
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                color: Colors.grey[900],
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      "Total Payments: ${payments.length}",
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    if (payments.length > 1)
                      TextButton(
                        onPressed: _addPayment,
                        style: TextButton.styleFrom(
                          foregroundColor: Colors.deepPurple,
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.add, size: 16),
                            SizedBox(width: 4),
                            Text("Add More"),
                          ],
                        ),
                      ),
                  ],
                ),
              ),

              // Main content
              Expanded(
                child: SingleChildScrollView(
                  controller: _scrollController,
                  padding: EdgeInsets.all(isVerySmallScreen ? 12 : 16),
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                      minHeight: MediaQuery.of(context).size.height,
                    ),
                    child: Column(
                      children: [
                        // PROJECT ID
                        TextFormField(
                          controller: projectIdController,
                          style: const TextStyle(color: Colors.white),
                          decoration: InputDecoration(
                            labelText: "Project Code *",
                            labelStyle: const TextStyle(color: Colors.white70),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            filled: true,
                            fillColor: const Color.fromARGB(255, 33, 33, 33),
                          ),
                          validator: (value) => value == null || value.isEmpty
                              ? "Enter Project Code"
                              : null,
                        ),
                        const SizedBox(height: 16),

                        // REIMBURSEMENT DATE - FIXED
                        Container(
                          width: double.infinity,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Colors.grey.shade700),
                            color: Colors.grey[900],
                          ),
                          padding: EdgeInsets.all(isVerySmallScreen ? 12 : 16),
                          child: Row(
                            children: [
                              Icon(
                                Icons.calendar_today,
                                color: Colors.white70,
                                size: isVerySmallScreen ? 18 : 20,
                              ),
                              SizedBox(width: isVerySmallScreen ? 8 : 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      "Reimbursement Date",
                                      style: TextStyle(
                                        color: Colors.white70,
                                        fontSize: isVerySmallScreen ? 11 : 12,
                                      ),
                                    ),
                                    Text(
                                      "${reimbursementDate.toString().split(" ")[0]} (Today)",
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontSize: isVerySmallScreen ? 14 : 16,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.deepPurple.withOpacity(0.3),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  "Fixed",
                                  style: TextStyle(
                                    color: Colors.white70,
                                    fontSize: isVerySmallScreen ? 10 : 12,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 20),

                        // PAYMENTS LIST
                        ListView.builder(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: payments.length,
                          itemBuilder: (context, index) {
                            PaymentEntry entry = payments[index];
                            return _buildPaymentCard(
                                entry, index, isSmallScreen, isVerySmallScreen);
                          },
                        ),
                        const SizedBox(height: 16),

                        // ADD PAYMENT BUTTON
                        if (payments.length <= 10) // Limit to prevent abuse
                          SizedBox(
                            width: isSmallScreen ? double.infinity : null,
                            child: ElevatedButton.icon(
                              onPressed: _addPayment,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.deepPurple,
                                padding: EdgeInsets.symmetric(
                                  vertical: isVerySmallScreen ? 12 : 14,
                                  horizontal: isVerySmallScreen ? 16 : 24,
                                ),
                              ),
                              icon: const Icon(Icons.add, color: Colors.white),
                              label: Text(
                                "Add Payment",
                                style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: isVerySmallScreen ? 14 : 16,
                                ),
                              ),
                            ),
                          ),
                        const SizedBox(height: 20),

                        // SUBMIT BUTTON
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.deepPurple,
                              padding: EdgeInsets.symmetric(
                                vertical: isVerySmallScreen ? 14 : 16,
                              ),
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
                                : Text(
                                    "Submit Reimbursement",
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: isVerySmallScreen ? 14 : 16,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                          ),
                        ),
                        const SizedBox(height: 20),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPaymentCard(PaymentEntry entry, int index, bool isSmallScreen,
      bool isVerySmallScreen) {
    return Card(
      color: Colors.grey[850],
      shadowColor: Colors.black54,
      elevation: 4,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      margin: const EdgeInsets.symmetric(vertical: 8),
      child: Padding(
        padding: EdgeInsets.all(isVerySmallScreen ? 12 : 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Payment Header
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Flexible(
                  child: Text(
                    "Payment ${index + 1} *",
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: isVerySmallScreen ? 14 : 16,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (entry.paymentDate != null &&
                    entry.paymentDate!.isAfter(DateTime.now()))
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                    decoration: BoxDecoration(
                      color: Colors.red,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      "Future Date!",
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: isVerySmallScreen ? 8 : 10,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 12),

            // PAYMENT DATE
            GestureDetector(
              onTap: () => _pickPaymentDate(context, entry),
              child: AbsorbPointer(
                child: TextFormField(
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    labelText: entry.paymentDate == null
                        ? "Select Payment Date *"
                        : entry.paymentDate!.isAfter(DateTime.now())
                            ? "⚠️ Future date not allowed!"
                            : entry.paymentDate.toString().split(" ")[0],
                    labelStyle: TextStyle(
                      color: entry.paymentDate != null &&
                              entry.paymentDate!.isAfter(DateTime.now())
                          ? Colors.red
                          : Colors.white70,
                      fontSize: isVerySmallScreen ? 12 : 14,
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    filled: true,
                    fillColor: entry.paymentDate != null &&
                            entry.paymentDate!.isAfter(DateTime.now())
                        ? Colors.red.withOpacity(0.1)
                        : Colors.grey[900],
                    contentPadding: EdgeInsets.symmetric(
                      vertical: isVerySmallScreen ? 12 : 16,
                      horizontal: 12,
                    ),
                  ),
                  validator: (_) {
                    if (entry.paymentDate == null) {
                      return "Pick a payment date";
                    }
                    if (entry.paymentDate!.isAfter(DateTime.now())) {
                      return "Payment date cannot be in future!";
                    }
                    return null;
                  },
                ),
              ),
            ),
            const SizedBox(height: 12),

            // AMOUNT
            TextFormField(
              controller: entry.amountController,
              keyboardType: TextInputType.number,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                labelText: "Amount *",
                labelStyle: TextStyle(
                  color: Colors.white70,
                  fontSize: isVerySmallScreen ? 12 : 14,
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                filled: true,
                fillColor: Colors.grey[900],
                contentPadding: EdgeInsets.symmetric(
                  vertical: isVerySmallScreen ? 12 : 16,
                  horizontal: 12,
                ),
              ),
              validator: (value) =>
                  value == null || value.isEmpty ? "Enter amount" : null,
            ),
            const SizedBox(height: 12),

            // DESCRIPTION
            TextFormField(
              controller: entry.descriptionController,
              style: const TextStyle(color: Colors.white),
              maxLines: 2,
              decoration: InputDecoration(
                labelText: "Description *",
                labelStyle: TextStyle(
                  color: Colors.white70,
                  fontSize: isVerySmallScreen ? 12 : 14,
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                filled: true,
                fillColor: Colors.grey[900],
                contentPadding: EdgeInsets.symmetric(
                  vertical: isVerySmallScreen ? 12 : 16,
                  horizontal: 12,
                ),
              ),
              validator: (value) =>
                  value == null || value.isEmpty ? "Enter description" : null,
            ),
            const SizedBox(height: 12),

            // CLAIM TYPE
            DropdownButtonFormField<String>(
              value: entry.claimType,
              dropdownColor: Colors.grey[900],
              style: TextStyle(
                color: Colors.white,
                fontSize: isVerySmallScreen ? 12 : 14,
              ),
              items: const [
                DropdownMenuItem(
                  value: "Travel",
                  child: Text("Travel"),
                ),
                DropdownMenuItem(
                  value: "Food",
                  child: Text("Food"),
                ),
                DropdownMenuItem(
                  value: "Other",
                  child: Text("Other"),
                ),
              ],
              onChanged: (val) {
                if (val != null) {
                  setState(() {
                    entry.claimType = val;
                    if (val != "Other") {
                      entry.customClaimType = null;
                    }
                  });
                }
              },
              decoration: InputDecoration(
                labelText: "Claim Type *",
                labelStyle: TextStyle(
                  color: Colors.white70,
                  fontSize: isVerySmallScreen ? 12 : 14,
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                filled: true,
                fillColor: Colors.grey[900],
                contentPadding: EdgeInsets.symmetric(
                  vertical: isVerySmallScreen ? 12 : 16,
                  horizontal: 12,
                ),
              ),
            ),

            // CUSTOM CLAIM TYPE
            if (entry.claimType == "Other") ...[
              const SizedBox(height: 12),
              TextFormField(
                onChanged: (value) {
                  setState(() {
                    entry.customClaimType = value;
                  });
                },
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  labelText: "Specify Claim Type *",
                  hintText: "Enter your custom claim category...",
                  labelStyle: TextStyle(
                    color: Colors.white70,
                    fontSize: isVerySmallScreen ? 12 : 14,
                  ),
                  hintStyle: const TextStyle(color: Colors.white54),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  filled: true,
                  fillColor: Colors.grey[900],
                  contentPadding: EdgeInsets.symmetric(
                    vertical: isVerySmallScreen ? 12 : 16,
                    horizontal: 12,
                  ),
                ),
                validator: (value) {
                  if (entry.claimType == "Other" &&
                      (value == null || value.isEmpty)) {
                    return "Please specify the claim type";
                  }
                  return null;
                },
              ),
            ],
            const SizedBox(height: 12),

            // ATTACHMENTS SECTION
            _buildAttachmentsSection(entry, isVerySmallScreen),
            const SizedBox(height: 12),

            // REMOVE PAYMENT BUTTON
            if (payments.length > 1)
              Align(
                alignment: Alignment.centerRight,
                child: TextButton.icon(
                  onPressed: () => _removePayment(index),
                  icon: Icon(
                    Icons.delete,
                    color: Colors.red,
                    size: isVerySmallScreen ? 14 : 16,
                  ),
                  label: Text(
                    "Remove Payment",
                    style: TextStyle(
                      color: Colors.red,
                      fontSize: isVerySmallScreen ? 11 : 12,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildAttachmentsSection(PaymentEntry entry, bool isVerySmallScreen) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ATTACHMENT BUTTON
        SizedBox(
          width: double.infinity,
          child: InkWell(
            onTap: () => _pickAttachments(entry),
            borderRadius: BorderRadius.circular(12),
            child: Container(
              padding: EdgeInsets.symmetric(
                vertical: isVerySmallScreen ? 10 : 12,
                horizontal: isVerySmallScreen ? 12 : 16,
              ),
              decoration: BoxDecoration(
                color: entry.attachmentPaths.isEmpty
                    ? Colors.orange
                    : Colors.green,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: entry.attachmentError != null
                      ? Colors.red
                      : Colors.transparent,
                  width: 2,
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    entry.attachmentPaths.isEmpty
                        ? Icons.warning
                        : Icons.check_circle,
                    color: Colors.white,
                    size: isVerySmallScreen ? 18 : 20,
                  ),
                  SizedBox(width: isVerySmallScreen ? 6 : 8),
                  Flexible(
                    child: Text(
                      entry.attachmentPaths.isEmpty
                          ? "Add Attachments * (PDF, Excel, Docx, Images)"
                          : "Attachments Added (${entry.attachmentPaths.length})",
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: isVerySmallScreen ? 12 : 14,
                      ),
                      textAlign: TextAlign.center,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),

        // ERROR MESSAGE
        if (entry.attachmentError != null) ...[
          const SizedBox(height: 8),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.red.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: Colors.red.withOpacity(0.3),
              ),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.error_outline,
                  color: Colors.red,
                  size: isVerySmallScreen ? 14 : 16,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    entry.attachmentError!,
                    style: TextStyle(
                      color: Colors.red,
                      fontSize: isVerySmallScreen ? 11 : 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],

        const SizedBox(height: 8),

        // ATTACHED FILES
        if (entry.attachmentPaths.isNotEmpty) ...[
          Text(
            "Attached Files:",
            style: TextStyle(
              color: Colors.white70,
              fontSize: isVerySmallScreen ? 12 : 14,
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: entry.attachmentPaths.asMap().entries.map((file) {
              final fileName = file.value.split('/').last;
              return Container(
                constraints: BoxConstraints(
                  maxWidth: isVerySmallScreen ? 120 : 150,
                ),
                child: Chip(
                  backgroundColor: Colors.green.withOpacity(0.3),
                  label: Text(
                    fileName.length > 20
                        ? '${fileName.substring(0, 17)}...'
                        : fileName,
                    style: TextStyle(
                      color: Colors.white70,
                      fontSize: isVerySmallScreen ? 10 : 12,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                  deleteIcon: Icon(
                    Icons.close,
                    color: Colors.white70,
                    size: isVerySmallScreen ? 14 : 16,
                  ),
                  onDeleted: () => _removeAttachment(entry, file.key),
                ),
              );
            }).toList(),
          ),
        ],
      ],
    );
  }
}
