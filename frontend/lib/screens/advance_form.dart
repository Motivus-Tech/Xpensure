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
  TextEditingController projectDateController = TextEditingController();
  List<String> attachmentPaths = [];
  String? attachmentError;

  PaymentEntry() {
    requestDateController.text = _formatDate(requestDate);
  }

  String _formatDate(DateTime date) {
    return "${date.toLocal()}".split(' ')[0];
  }

  void updateProjectDate(DateTime date) {
    projectDate = date;
    projectDateController.text = _formatDate(date);
  }

  void dispose() {
    particularsController.dispose();
    amountController.dispose();
    requestDateController.dispose();
    projectDateController.dispose();
  }
}

class _AdvanceRequestFormScreenState extends State<AdvanceRequestFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final projectIdController = TextEditingController();
  final projectNameController = TextEditingController();
  List<PaymentEntry> payments = [];
  final ApiService apiService = ApiService();
  bool _isSubmitting = false;
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    payments.add(PaymentEntry());
  }

  @override
  void dispose() {
    projectIdController.dispose();
    projectNameController.dispose();
    _scrollController.dispose();
    for (var entry in payments) entry.dispose();
    super.dispose();
  }

  void _addPayment() {
    setState(() {
      payments.add(PaymentEntry());
    });
    // Auto-scroll to new payment
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
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
      firstDate: DateTime.now(),
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
        entry.updateProjectDate(picked);
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

  void _removeAttachment(PaymentEntry entry, int index) {
    setState(() {
      entry.attachmentPaths.removeAt(index);
    });
  }

  String _getFileName(String path) {
    return path.split('/').last;
  }

  bool _validateAttachments() {
    bool isValid = true;
    for (var payment in payments) {
      if (payment.attachmentPaths.isEmpty) {
        setState(() {
          payment.attachmentError = "Attachments are recommended";
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
    if (!_formKey.currentState!.validate()) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text("Please fill all required fields!"),
        backgroundColor: Colors.red,
      ));
      return;
    }

    // Validate attachments (show warning but allow submission)
    _validateAttachments();

    for (var payment in payments) {
      if (payment.projectDate == null ||
          payment.amountController.text.isEmpty ||
          payment.particularsController.text.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text("Please fill all payment fields!"),
          backgroundColor: Colors.red,
        ));
        return;
      }

      final today = DateTime.now();
      final projectDate = payment.projectDate!;
      if (projectDate.isBefore(DateTime(today.year, today.month, today.day))) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text("Project date must be today or after today!"),
          backgroundColor: Colors.red,
        ));
        return;
      }

      final amount = double.tryParse(payment.amountController.text);
      if (amount == null || amount <= 0) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text("Please enter a valid positive amount!"),
          backgroundColor: Colors.red,
        ));
        return;
      }
    }

    setState(() => _isSubmitting = true);

    SharedPreferences prefs = await SharedPreferences.getInstance();
    String? authToken = prefs.getString('authToken');
    if (authToken == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text("Auth token missing!"),
        backgroundColor: Colors.red,
      ));
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
        projectId: projectIdController.text,
        projectName: projectNameController.text,
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
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text("Error submitting form: $e"),
        backgroundColor: Colors.red,
      ));
    } finally {
      setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isSmallScreen = MediaQuery.of(context).size.width < 600;
    final isVerySmallScreen = MediaQuery.of(context).size.width < 400;

    return Scaffold(
      backgroundColor: const Color(0xFF181A20),
      appBar: AppBar(
        title: const Text("Advance Request Form"),
        backgroundColor: const Color.fromARGB(255, 148, 99, 233),
      ),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              // Header with payment count
              Container(
                width: double.infinity,
                padding: EdgeInsets.all(isVerySmallScreen ? 12 : 16),
                color: Colors.grey[900],
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      "Total Payments: ${payments.length}",
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: isVerySmallScreen ? 14 : 16,
                      ),
                    ),
                    if (payments.length > 1)
                      TextButton(
                        onPressed: _addPayment,
                        style: TextButton.styleFrom(
                          foregroundColor: Colors.deepPurple,
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.add, size: isVerySmallScreen ? 14 : 16),
                            SizedBox(width: isVerySmallScreen ? 4 : 8),
                            Text(
                              "Add More",
                              style: TextStyle(
                                fontSize: isVerySmallScreen ? 12 : 14,
                              ),
                            ),
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
                        // Project Information Section
                        Card(
                          color: const Color(0xFF1F1F1F),
                          elevation: 4,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                          margin: const EdgeInsets.only(bottom: 16),
                          child: Padding(
                            padding:
                                EdgeInsets.all(isVerySmallScreen ? 12 : 16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  "Project Information",
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                    fontSize: isVerySmallScreen ? 16 : 18,
                                  ),
                                ),
                                const SizedBox(height: 16),
                                TextFormField(
                                  controller: projectIdController,
                                  style: const TextStyle(color: Colors.white),
                                  decoration: InputDecoration(
                                    labelText: "Project ID *",
                                    labelStyle: TextStyle(
                                      color: Colors.white70,
                                      fontSize: isVerySmallScreen ? 12 : 14,
                                    ),
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    filled: true,
                                    fillColor: const Color(0xFF2A2A2A),
                                    contentPadding: EdgeInsets.symmetric(
                                      vertical: isVerySmallScreen ? 12 : 16,
                                      horizontal: 12,
                                    ),
                                  ),
                                  validator: (value) =>
                                      value == null || value.isEmpty
                                          ? "Enter Project ID"
                                          : null,
                                ),
                                const SizedBox(height: 12),
                                TextFormField(
                                  controller: projectNameController,
                                  style: const TextStyle(color: Colors.white),
                                  decoration: InputDecoration(
                                    labelText: "Project Name *",
                                    labelStyle: TextStyle(
                                      color: Colors.white70,
                                      fontSize: isVerySmallScreen ? 12 : 14,
                                    ),
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    filled: true,
                                    fillColor: const Color(0xFF2A2A2A),
                                    contentPadding: EdgeInsets.symmetric(
                                      vertical: isVerySmallScreen ? 12 : 16,
                                      horizontal: 12,
                                    ),
                                  ),
                                  validator: (value) =>
                                      value == null || value.isEmpty
                                          ? "Enter Project Name"
                                          : null,
                                ),
                              ],
                            ),
                          ),
                        ),

                        // Payments List
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

                        // Add Payment Button
                        if (payments.length <= 10) // Reasonable limit
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
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                              icon: Icon(
                                Icons.add,
                                color: Colors.white,
                                size: isVerySmallScreen ? 16 : 18,
                              ),
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

                        // Submit Button
                        const SizedBox(height: 24),
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
                                ? SizedBox(
                                    height: 20,
                                    width: 20,
                                    child: CircularProgressIndicator(
                                      color: Colors.white,
                                      strokeWidth: 2,
                                    ),
                                  )
                                : Text(
                                    "Submit Advance Request",
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
      color: const Color(0xFF1F1F1F),
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
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (entry.projectDate != null &&
                        entry.projectDate!.isBefore(DateTime.now()))
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 3),
                        decoration: BoxDecoration(
                          color: Colors.red,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          "Past Date!",
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: isVerySmallScreen ? 8 : 10,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    if (payments.length > 1)
                      IconButton(
                        onPressed: () => _removePayment(index),
                        icon: Icon(
                          Icons.delete,
                          color: Colors.redAccent,
                          size: isVerySmallScreen ? 18 : 20,
                        ),
                        tooltip: "Remove Payment",
                        padding: EdgeInsets.zero,
                        constraints: BoxConstraints(
                          maxWidth: isVerySmallScreen ? 32 : 40,
                          maxHeight: isVerySmallScreen ? 32 : 40,
                        ),
                      ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Request Date
            TextFormField(
              controller: entry.requestDateController,
              enabled: false,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                labelText: "Request Date *",
                labelStyle: TextStyle(
                  color: Colors.white70,
                  fontSize: isVerySmallScreen ? 12 : 14,
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                filled: true,
                fillColor: const Color(0xFF2A2A2A).withOpacity(0.7),
                contentPadding: EdgeInsets.symmetric(
                  vertical: isVerySmallScreen ? 12 : 16,
                  horizontal: 12,
                ),
              ),
            ),
            const SizedBox(height: 12),

            // Project Date
            GestureDetector(
              onTap: () => _pickProjectDate(context, entry),
              child: AbsorbPointer(
                child: TextFormField(
                  controller: entry.projectDateController,
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    labelText: "Project Date *",
                    hintText: "Select project date (Today or future)",
                    labelStyle: TextStyle(
                      color: Colors.white70,
                      fontSize: isVerySmallScreen ? 12 : 14,
                    ),
                    hintStyle: const TextStyle(color: Colors.white54),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    filled: true,
                    fillColor: const Color(0xFF2A2A2A),
                    contentPadding: EdgeInsets.symmetric(
                      vertical: isVerySmallScreen ? 12 : 16,
                      horizontal: 12,
                    ),
                    suffixIcon: Icon(
                      Icons.calendar_today,
                      color: Colors.white70,
                      size: isVerySmallScreen ? 18 : 20,
                    ),
                  ),
                  validator: (_) {
                    if (entry.projectDate == null) {
                      return "Pick a project date";
                    }
                    if (entry.projectDate!.isBefore(DateTime.now())) {
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
              keyboardType: TextInputType.numberWithOptions(decimal: true),
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
                fillColor: const Color(0xFF2A2A2A),
                prefixText: "₹ ",
                prefixStyle: const TextStyle(color: Colors.white),
                contentPadding: EdgeInsets.symmetric(
                  vertical: isVerySmallScreen ? 12 : 16,
                  horizontal: 12,
                ),
              ),
              validator: (value) =>
                  value == null || value.isEmpty ? "Enter amount" : null,
            ),
            const SizedBox(height: 12),

            // Particulars Field
            TextFormField(
              controller: entry.particularsController,
              style: const TextStyle(color: Colors.white),
              maxLines: 2,
              decoration: InputDecoration(
                labelText: "Particulars *",
                labelStyle: TextStyle(
                  color: Colors.white70,
                  fontSize: isVerySmallScreen ? 12 : 14,
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                filled: true,
                fillColor: const Color(0xFF2A2A2A),
                contentPadding: EdgeInsets.symmetric(
                  vertical: isVerySmallScreen ? 12 : 16,
                  horizontal: 12,
                ),
              ),
              validator: (value) =>
                  value == null || value.isEmpty ? "Enter particulars" : null,
            ),
            const SizedBox(height: 12),

            // Attachments Section
            _buildAttachmentsSection(entry, isVerySmallScreen),
          ],
        ),
      ),
    );
  }

  Widget _buildAttachmentsSection(PaymentEntry entry, bool isVerySmallScreen) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          "Attachments",
          style: TextStyle(
            color: Colors.white70,
            fontSize: isVerySmallScreen ? 12 : 14,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 8),

        // Attachment button with error indicator
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
                    ? Colors.orange.withOpacity(0.8)
                    : Colors.green,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: entry.attachmentError != null
                      ? Colors.orange
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
                    size: isVerySmallScreen ? 16 : 18,
                  ),
                  SizedBox(width: isVerySmallScreen ? 6 : 8),
                  Flexible(
                    child: Text(
                      entry.attachmentPaths.isEmpty
                          ? "Add Attachments (Recommended)"
                          : "Attachments (${entry.attachmentPaths.length})",
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

        // Warning message for attachments
        if (entry.attachmentError != null) ...[
          const SizedBox(height: 8),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.orange.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: Colors.orange.withOpacity(0.3),
              ),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.warning_amber,
                  color: Colors.orange,
                  size: isVerySmallScreen ? 14 : 16,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    entry.attachmentError!,
                    style: TextStyle(
                      color: Colors.orange,
                      fontSize: isVerySmallScreen ? 11 : 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],

        // Attached files list
        if (entry.attachmentPaths.isNotEmpty) ...[
          const SizedBox(height: 8),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: entry.attachmentPaths.asMap().entries.map((fileEntry) {
              final fileName = _getFileName(fileEntry.value);
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
                  onDeleted: () => _removeAttachment(entry, fileEntry.key),
                ),
              );
            }).toList(),
          ),
        ],
      ],
    );
  }
}
