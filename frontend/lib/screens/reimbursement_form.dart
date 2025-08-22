import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';

class ReimbursementFormScreen extends StatefulWidget {
  final Function(Map<String, dynamic>) onSubmit; // required callback

  const ReimbursementFormScreen({super.key, required this.onSubmit});

  @override
  State<ReimbursementFormScreen> createState() =>
      _ReimbursementFormScreenState();
}

class PaymentEntry {
  DateTime? paymentDate;
  TextEditingController descriptionController = TextEditingController();
  TextEditingController amountController = TextEditingController();
  String claimType = "Travel";
  String? attachmentPath;
}

class _ReimbursementFormScreenState extends State<ReimbursementFormScreen> {
  final _formKey = GlobalKey<FormState>();
  DateTime? reimbursementDate;
  final projectIdController = TextEditingController();
  List<PaymentEntry> payments = [];

  @override
  void initState() {
    super.initState();
    payments.add(PaymentEntry());
  }

  void _addPayment() {
    setState(() {
      payments.add(PaymentEntry());
    });
  }

  void _removePayment(int index) {
    setState(() {
      payments.removeAt(index);
    });
  }

  Future<void> _pickReimbursementDate(BuildContext context) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: reimbursementDate ?? DateTime.now(),
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
        reimbursementDate = picked;
      });
    }
  }

  Future<void> _pickPaymentDate(
    BuildContext context,
    PaymentEntry entry,
  ) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: entry.paymentDate ?? DateTime.now(),
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
        entry.paymentDate = picked;
      });
    }
  }

  Future<void> _pickAttachment(PaymentEntry entry) async {
    final result = await FilePicker.platform.pickFiles();
    if (result != null) {
      setState(() {
        entry.attachmentPath = result.files.single.path;
      });
    }
  }

  void _submitForm() {
    if (_formKey.currentState!.validate()) {
      List<Map<String, dynamic>> paymentData = payments.map((p) {
        return {
          "paymentDate": p.paymentDate,
          "amount": p.amountController.text,
          "description": p.descriptionController.text,
          "claimType": p.claimType,
          "attachmentPath": p.attachmentPath,
        };
      }).toList();

      Map<String, dynamic> reimbursementData = {
        "reimbursementDate": reimbursementDate,
        "projectId": projectIdController.text,
        "payments": paymentData,
        "status": "Pending",
      };

      // Send data to EmployeeDashboard via callback
      widget.onSubmit(reimbursementData);

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Reimbursement submitted!"),
          backgroundColor: Color.fromARGB(255, 179, 170, 195),
        ),
      );

      // Reset form
      setState(() {
        reimbursementDate = null;
        projectIdController.clear();
        payments = [PaymentEntry()];
      });
    }
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
            // Project ID
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
                fillColor: const Color.fromARGB(255, 33, 33, 33),
              ),
              validator: (value) =>
                  value == null || value.isEmpty ? "Enter Project ID" : null,
            ),
            const SizedBox(height: 16),

            // Reimbursement Date
            GestureDetector(
              onTap: () => _pickReimbursementDate(context),
              child: AbsorbPointer(
                child: TextFormField(
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    labelText: reimbursementDate == null
                        ? "Select Reimbursement Date"
                        : reimbursementDate.toString().split(" ")[0],
                    labelStyle: const TextStyle(color: Colors.white70),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    filled: true,
                    fillColor: Colors.grey[900],
                  ),
                  validator: (_) =>
                      reimbursementDate == null ? "Pick a date" : null,
                ),
              ),
            ),
            const SizedBox(height: 20),

            // Payments
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
                        // Payment Date
                        GestureDetector(
                          onTap: () => _pickPaymentDate(context, entry),
                          child: AbsorbPointer(
                            child: TextFormField(
                              style: const TextStyle(color: Colors.white),
                              decoration: InputDecoration(
                                labelText: entry.paymentDate == null
                                    ? "Payment Date"
                                    : entry.paymentDate.toString().split(
                                        " ",
                                      )[0],
                                labelStyle: const TextStyle(
                                  color: Colors.white70,
                                ),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(14),
                                ),
                                filled: true,
                                fillColor: Colors.grey[900],
                              ),
                              validator: (_) => entry.paymentDate == null
                                  ? "Pick a payment date"
                                  : null,
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),

                        // Amount
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
                            fillColor: Colors.grey[900],
                          ),
                          validator: (value) => value == null || value.isEmpty
                              ? "Enter amount"
                              : null,
                        ),
                        const SizedBox(height: 12),

                        // Description
                        TextFormField(
                          controller: entry.descriptionController,
                          style: const TextStyle(color: Colors.white),
                          decoration: InputDecoration(
                            labelText: "Description",
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

                        // Claim Type
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
                              });
                            }
                          },
                          decoration: InputDecoration(
                            labelText: "Claim Type",
                            labelStyle: const TextStyle(color: Colors.white70),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                            filled: true,
                            fillColor: Colors.grey[900],
                          ),
                        ),
                        const SizedBox(height: 12),

                        // Attach File + Delete
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
                                child: Row(
                                  children: const [
                                    Icon(
                                      Icons.attach_file,
                                      color: Colors.white,
                                      size: 18,
                                    ),
                                    SizedBox(width: 6),
                                    Text(
                                      "Attach File",
                                      style: TextStyle(color: Colors.white),
                                    ),
                                  ],
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
                            IconButton(
                              onPressed: () => _removePayment(index),
                              icon: const Icon(
                                Icons.delete,
                                color: Color.fromARGB(255, 161, 53, 45),
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

            // Add More Payment
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

            // Submit Button
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.deepPurple,
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
              onPressed: _submitForm,
              child: const Text(
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
