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
  List<String> attachmentPaths = []; // ✅ MULTIPLE ATTACHMENTS
  String? attachmentError; // ✅ ADD ERROR TRACKING

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

  @override
  void initState() {
    super.initState();
    // ✅ AUTOMATICALLY SET REIMBURSEMENT DATE TO TODAY AND MAKE IT FIXED
    reimbursementDate = DateTime.now();
    payments.add(PaymentEntry());
  }

  @override
  void dispose() {
    projectIdController.dispose();
    for (var entry in payments) {
      entry.dispose();
    }
    super.dispose();
  }

  void _addPayment() {
    setState(() {
      payments.add(PaymentEntry());
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
      lastDate: DateTime.now(), // ✅ CANNOT SELECT FUTURE DATES FOR PAYMENT
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
        entry.attachmentError = null; // Clear error when date is selected
      });
    }
  }

  Future<void> _pickAttachments(PaymentEntry entry) async {
    final result = await FilePicker.platform.pickFiles(
      allowMultiple: true, // ✅ ALLOW MULTIPLE FILES
    );

    if (result != null && result.files.isNotEmpty) {
      setState(() {
        // ✅ ADD MULTIPLE FILES TO LIST
        for (var file in result.files) {
          if (file.path != null) {
            entry.attachmentPaths.add(file.path!);
          }
        }
        // ✅ CLEAR ATTACHMENT ERROR WHEN FILES ARE ADDED
        entry.attachmentError = null;
      });
    }
  }

  void _removeAttachment(PaymentEntry entry, int attachmentIndex) {
    setState(() {
      entry.attachmentPaths.removeAt(attachmentIndex);
      // ✅ SET ERROR IF NO ATTACHMENTS LEFT
      if (entry.attachmentPaths.isEmpty) {
        entry.attachmentError = "At least one attachment is required";
      }
    });
  }

  // ✅ NEW METHOD: VALIDATE ALL ATTACHMENTS
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
    // ✅ FIRST VALIDATE ATTACHMENTS - THIS IS COMPULSORY
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

    // ✅ THEN VALIDATE FORM FIELDS
    if (!_formKey.currentState!.validate()) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Please fill all required fields!"),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    // ✅ COMPULSORY VALIDATION - CHECK ALL PAYMENTS
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

      // ✅ COMPULSORY VALIDATION - CUSTOM CLAIM TYPE
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

      // ✅ COMPULSORY VALIDATION - FUTURE DATE CHECK
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

    // Calculate total amount
    double totalAmount = 0;
    for (var payment in payments) {
      totalAmount += double.tryParse(payment.amountController.text) ?? 0;
    }

    // Prepare payments data for JSON
    List<Map<String, dynamic>> paymentData = payments.map((p) {
      // Use custom claim type if "Other" is selected, otherwise use the selected claim type
      String finalClaimType =
          p.claimType == "Other" ? p.customClaimType! : p.claimType;

      return {
        "date": p.paymentDate!.toIso8601String().split("T")[0],
        "amount": p.amountController.text,
        "description": p.descriptionController.text,
        "claimType": finalClaimType,
        "attachmentPaths": p.attachmentPaths, // ✅ SEND MULTIPLE ATTACHMENTS
      };
    }).toList();

    // ✅ FIXED: Get ALL attachments from ALL payments
    List<File> allAttachments = [];
    for (var payment in payments) {
      for (var path in payment.attachmentPaths) {
        allAttachments.add(File(path));
      }
    }
    // ✅ FIXED: Use first payment description or combine them
    String combinedDescription =
        payments.map((p) => p.descriptionController.text).join('; ');

    String result = await apiService.submitReimbursement(
      authToken: authToken,
      amount: totalAmount.toString(),
      description: combinedDescription, // ✅ Use combined description
      attachments: allAttachments, // ✅ Send ALL attachments
      date: reimbursementDate!.toIso8601String().split("T")[0],
      payments: paymentData,
      projectId: projectIdController.text, // ✅ ADD PROJECT ID
    );

    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(result)));

    // Prepare data for callback
    Map<String, dynamic> reimbursementData = {
      "reimbursementDate": reimbursementDate,
      "projectId": projectIdController.text,
      "payments": paymentData,
      "status": result.toLowerCase().contains("success") ? "Pending" : "Error",
    };

    widget.onSubmit(reimbursementData);

    // Reset form
    setState(() {
      reimbursementDate = DateTime.now(); // ✅ RESET TO TODAY'S DATE
      projectIdController.clear();
      for (var entry in payments) entry.dispose();
      payments = [PaymentEntry()];
      _isSubmitting = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color.fromARGB(255, 33, 33, 33),
      appBar: AppBar(
        title: const Text("Reimbursement Form"),
        backgroundColor: const Color.fromARGB(255, 148, 99, 233),
        elevation: 2,
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // ✅ PROJECT ID - COMPULSORY
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
              validator: (value) =>
                  value == null || value.isEmpty ? "Enter Project Code" : null,
            ),
            const SizedBox(height: 16),

            // ✅ REIMBURSEMENT DATE - FIXED & NON-EDITABLE
            Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey.shade700),
                color: Colors.grey[900],
              ),
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  const Icon(
                    Icons.calendar_today,
                    color: Colors.white70,
                    size: 20,
                  ),
                  const SizedBox(width: 12),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        "Reimbursement Date",
                        style: TextStyle(
                          color: Colors.white70,
                          fontSize: 12,
                        ),
                      ),
                      Text(
                        "${reimbursementDate.toString().split(" ")[0]} (Today)",
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  const Spacer(),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.deepPurple.withOpacity(0.3),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: const Text(
                      "Fixed",
                      style: TextStyle(
                        color: Colors.white70,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // ✅ PAYMENTS LIST
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: payments.length,
              itemBuilder: (context, index) {
                PaymentEntry entry = payments[index];
                return Card(
                  color: Colors.grey[850],
                  shadowColor: Colors.black54,
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
                            if (entry.paymentDate != null &&
                                entry.paymentDate!.isAfter(DateTime.now()))
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: Colors.red,
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: const Text(
                                  "Future Date!",
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                          ],
                        ),
                        const SizedBox(height: 12),

                        // ✅ PAYMENT DATE - COMPULSORY
                        GestureDetector(
                          onTap: () => _pickPaymentDate(context, entry),
                          child: AbsorbPointer(
                            child: TextFormField(
                              style: const TextStyle(color: Colors.white),
                              decoration: InputDecoration(
                                labelText: entry.paymentDate == null
                                    ? "Select Payment Date * (Today or Before)"
                                    : entry.paymentDate!.isAfter(DateTime.now())
                                        ? "⚠️ Future date not allowed!"
                                        : entry.paymentDate
                                            .toString()
                                            .split(" ")[0],
                                labelStyle: TextStyle(
                                  color: entry.paymentDate != null &&
                                          entry.paymentDate!
                                              .isAfter(DateTime.now())
                                      ? Colors.red
                                      : Colors.white70,
                                ),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(14),
                                ),
                                filled: true,
                                fillColor: entry.paymentDate != null &&
                                        entry.paymentDate!
                                            .isAfter(DateTime.now())
                                    ? Colors.red.withOpacity(0.1)
                                    : Colors.grey[900],
                              ),
                              validator: (_) {
                                if (entry.paymentDate == null) {
                                  return "Pick a payment date";
                                }
                                if (entry.paymentDate!
                                    .isAfter(DateTime.now())) {
                                  return "Payment date cannot be in future!";
                                }
                                return null;
                              },
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),

                        // ✅ AMOUNT - COMPULSORY
                        TextFormField(
                          controller: entry.amountController,
                          keyboardType: TextInputType.number,
                          style: const TextStyle(color: Colors.white),
                          decoration: InputDecoration(
                            labelText: "Amount *",
                            labelStyle: const TextStyle(color: Colors.white70),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                            filled: true,
                            fillColor: Colors.grey[900],
                          ),
                          validator: (value) => value == null || value.isEmpty
                              ? "Enter amount"
                              : null,
                        ),
                        const SizedBox(height: 12),

                        // ✅ DESCRIPTION - COMPULSORY
                        TextFormField(
                          controller: entry.descriptionController,
                          style: const TextStyle(color: Colors.white),
                          decoration: InputDecoration(
                            labelText: "Description *",
                            labelStyle: const TextStyle(color: Colors.white70),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                            filled: true,
                            fillColor: Colors.grey[900],
                          ),
                          validator: (value) => value == null || value.isEmpty
                              ? "Enter description"
                              : null,
                        ),
                        const SizedBox(height: 12),

                        // ✅ CLAIM TYPE - COMPULSORY
                        DropdownButtonFormField<String>(
                          value: entry.claimType,
                          dropdownColor: Colors.grey[900],
                          style: const TextStyle(color: Colors.white),
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
                            labelStyle: const TextStyle(color: Colors.white70),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                            filled: true,
                            fillColor: Colors.grey[900],
                          ),
                        ),

                        // ✅ CUSTOM CLAIM TYPE - CONDITIONALLY COMPULSORY
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
                              labelStyle:
                                  const TextStyle(color: Colors.white70),
                              hintStyle: const TextStyle(color: Colors.white54),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(14),
                              ),
                              filled: true,
                              fillColor: Colors.grey[900],
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

                        // ✅ MULTIPLE ATTACHMENTS - NOW TRULY COMPULSORY
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // ATTACHMENT BUTTON WITH ERROR INDICATOR
                            InkWell(
                              onTap: () => _pickAttachments(entry),
                              borderRadius: BorderRadius.circular(12),
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  vertical: 12,
                                  horizontal: 16,
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
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      entry.attachmentPaths.isEmpty
                                          ? Icons.warning
                                          : Icons.check_circle,
                                      color: Colors.white,
                                      size: 20,
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      entry.attachmentPaths.isEmpty
                                          ? "Add Attachments *"
                                          : "Attachments Added (${entry.attachmentPaths.length})",
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),

                            // ✅ SHOW ERROR MESSAGE IF ATTACHMENTS ARE MISSING
                            if (entry.attachmentError != null) ...[
                              const SizedBox(height: 8),
                              Container(
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
                                      size: 16,
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        entry.attachmentError!,
                                        style: TextStyle(
                                          color: Colors.red,
                                          fontSize: 12,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],

                            const SizedBox(height: 8),

                            // ✅ SHOW ALL ATTACHED FILES
                            if (entry.attachmentPaths.isNotEmpty) ...[
                              const Text(
                                "Attached Files:",
                                style: TextStyle(
                                  color: Colors.white70,
                                  fontSize: 14,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Wrap(
                                spacing: 8,
                                runSpacing: 8,
                                children: entry.attachmentPaths
                                    .asMap()
                                    .entries
                                    .map((file) {
                                  return Chip(
                                    backgroundColor:
                                        Colors.green.withOpacity(0.3),
                                    label: Text(
                                      file.value.split('/').last,
                                      style: const TextStyle(
                                        color: Colors.white70,
                                        fontSize: 12,
                                      ),
                                    ),
                                    deleteIcon: const Icon(
                                      Icons.close,
                                      color: Colors.white70,
                                      size: 16,
                                    ),
                                    onDeleted: () =>
                                        _removeAttachment(entry, file.key),
                                  );
                                }).toList(),
                              ),
                            ],

                            const SizedBox(height: 8),

                            // REMOVE PAYMENT BUTTON
                            if (payments.length > 1)
                              Align(
                                alignment: Alignment.centerRight,
                                child: TextButton.icon(
                                  onPressed: () => _removePayment(index),
                                  icon: const Icon(
                                    Icons.delete,
                                    color: Colors.red,
                                    size: 16,
                                  ),
                                  label: const Text(
                                    "Remove Payment",
                                    style: TextStyle(
                                      color: Colors.red,
                                      fontSize: 12,
                                    ),
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
            const SizedBox(height: 16),

            // ✅ ADD MORE PAYMENT BUTTON
            ElevatedButton(
              onPressed: _addPayment,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.deepPurple,
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
              child: const Text(
                "Add More Payment",
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            const SizedBox(height: 20),

            // ✅ SUBMIT BUTTON - ONLY ENABLED WHEN ALL COMPULSORY FIELDS FILLED
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.deepPurple,
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
              onPressed: _isSubmitting ? null : _submitForm,
              child: _isSubmitting
                  ? const CircularProgressIndicator(color: Colors.white)
                  : const Text(
                      "Submit Reimbursement",
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
