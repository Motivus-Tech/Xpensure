import 'package:flutter/material.dart';
import 'package:open_file/open_file.dart';
import 'dart:io';
import 'package:url_launcher/url_launcher.dart';
import 'package:path_provider/path_provider.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

class RequestHistoryScreen extends StatefulWidget {
  final String employeeName;
  final String requestTitle;
  final List<Map<String, dynamic>> payments;
  final int currentStep;
  final String? status;
  final String? rejectionReason;
  final String requestId;
  final String requestType; // "reimbursement" or "advance"
  final String authToken;

  const RequestHistoryScreen({
    super.key,
    required this.employeeName,
    required this.requestTitle,
    required this.payments,
    this.currentStep = 0,
    this.status,
    this.rejectionReason,
    required this.requestId,
    required this.requestType,
    required this.authToken,
  });

  @override
  State<RequestHistoryScreen> createState() => _RequestHistoryScreenState();
}

class _RequestHistoryScreenState extends State<RequestHistoryScreen> {
  List<ApprovalTimelineItem> _timelineItems = [];
  bool _isLoadingTimeline = true;
  Map<String, dynamic>? _nextApprover;

  @override
  void initState() {
    super.initState();
    _loadApprovalTimeline();
  }

  Future<void> _loadApprovalTimeline() async {
    print("🎯 ===== LOADING TIMELINE DEBUG =====");
    print("🎯 Request ID: ${widget.requestId}");
    print("🎯 Request Type: ${widget.requestType}");
    print("🎯 Auth Token Present: ${widget.authToken.isNotEmpty}");
    print(
        "🎯 Full URL: http://3.110.215.143/api/approval-timeline/${widget.requestId}/?request_type=${widget.requestType}");

    try {
      final response = await http.get(
        Uri.parse(
            'http://3.110.215.143/api/approval-timeline/${widget.requestId}/?request_type=${widget.requestType}'),
        headers: {
          'Authorization': 'Token ${widget.authToken}',
          'Accept': 'application/json',
        },
      );

      print("🎯 API RESPONSE STATUS: ${response.statusCode}");

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        print("🎯 TIMELINE DATA RECEIVED: ${data['timeline']}");
        final timelineData = data['timeline'] as List;

        setState(() {
          _timelineItems = timelineData
              .map((item) => ApprovalTimelineItem.fromJson(item))
              .toList();
          _nextApprover = data['next_approver'];
          _isLoadingTimeline = false;
        });

        print("🎯 NEXT APPROVER DATA: $_nextApprover");
        print("🎯 TIMELINE LOADED SUCCESSFULLY!");
      } else {
        print("❌ API ERROR: Status ${response.statusCode}");
        print("❌ Error Body: ${response.body}");
        _createFallbackTimeline();
      }
    } catch (e) {
      print("❌ EXCEPTION loading timeline: $e");
      _createFallbackTimeline();
    }
  }

  void _createFallbackTimeline() {
    final payment = widget.payments.isNotEmpty ? widget.payments[0] : {};

    List<ApprovalTimelineItem> fallbackItems = [];

    // Step 1: Request Submitted
    fallbackItems.add(ApprovalTimelineItem(
        step: "Request Submitted",
        approverName: widget.employeeName,
        approverId: "",
        timestamp: _parseDate(payment["created_at"] ?? DateTime.now()),
        status: "completed",
        action: "submitted",
        stepType: "submission",
        comments: "Request submitted"));

    // Add steps based on current status
    if (widget.status == "Rejected") {
      fallbackItems.add(ApprovalTimelineItem(
          step: "Request Rejected",
          approverName: "System",
          approverId: "",
          timestamp: DateTime.now(),
          status: "rejected",
          action: "rejected",
          stepType: "rejection",
          comments: widget.rejectionReason ?? "Request rejected"));
    } else if (widget.status == "Approved" || widget.status == "Paid") {
      // Add completed steps
      fallbackItems.add(ApprovalTimelineItem(
          step: "Approved by Manager",
          approverName: "Manager",
          approverId: "",
          timestamp: DateTime.now().subtract(Duration(days: 1)),
          status: "completed",
          action: "approved",
          stepType: "reporting_manager",
          comments: "Approved"));

      if (widget.status == "Paid") {
        fallbackItems.add(ApprovalTimelineItem(
            step: "Payment Processed",
            approverName: "Finance",
            approverId: "",
            timestamp: DateTime.now(),
            status: "paid",
            action: "paid",
            stepType: "payment",
            comments: "Payment completed"));
      }
    } else {
      // Pending - show current step
      fallbackItems.add(ApprovalTimelineItem(
          step: "Pending Approval",
          approverName: "Manager",
          approverId: "",
          timestamp: null,
          status: "pending",
          action: "pending",
          stepType: "reporting_manager",
          comments: "Waiting for approval"));
    }

    setState(() {
      _timelineItems = fallbackItems;
      _isLoadingTimeline = false;
    });
  }

  List<StepperItem> getStepperItems() {
    if (_isLoadingTimeline) {
      return _getLoadingStepperItems();
    }

    return _timelineItems.map((timelineItem) {
      return StepperItem(
        title: timelineItem.step,
        completed: timelineItem.status == "completed" ||
            timelineItem.status == "paid" ||
            timelineItem.status == "approved",
        date: timelineItem.timestamp,
        personName: timelineItem.approverName,
        isRejected: timelineItem.status == "rejected",
        statusText: _getStatusText(timelineItem),
        description: _getCleanStepDescription(timelineItem),
        isNextApprover: timelineItem.isNextApprover ?? false,
        approverRole: timelineItem.approverRole,
      );
    }).toList();
  }

  List<StepperItem> _getLoadingStepperItems() {
    return [
      StepperItem(
        title: "Loading Timeline...",
        completed: false,
        date: null,
        personName: "System",
        isRejected: false,
        statusText: "Loading",
        description: "Loading approval timeline",
        isNextApprover: false,
        approverRole: null,
      ),
    ];
  }

  String _getStatusText(ApprovalTimelineItem item) {
    switch (item.status) {
      case "completed":
      case "paid":
        return "Completed";
      case "rejected":
        return "Rejected";
      case "pending":
        return "Pending";
      default:
        return "Pending";
    }
  }

  // ✅ CLEAN STEP DESCRIPTION WITHOUT "PROCESSING" AND SIMPLIFIED
  String _getCleanStepDescription(ApprovalTimelineItem item) {
    switch (item.stepType) {
      case "submission":
        return "Request submitted for approval";
      case "reporting_manager":
        if (item.status == "completed") {
          return "Approved";
        } else if (item.status == "rejected") {
          return "Rejected";
        } else {
          return "Pending approval";
        }
      case "finance":
        if (item.status == "completed") {
          return "Finance verification done";
        } else {
          return "Finance verification pending";
        }
      case "ceo":
        if (item.status == "completed") {
          return "CEO approval done";
        } else {
          return "CEO approval pending";
        }
      case "payment":
        if (item.status == "paid") {
          return "Payment processed";
        } else {
          return "Payment pending";
        }
      case "rejection":
        return "Request rejected";
      default:
        // Remove "Processing..." and show empty or simple text
        return "";
    }
  }

  double get totalAmount {
    double sum = 0;
    for (var p in widget.payments) {
      sum += double.tryParse(p["amount"]?.toString() ?? "0") ?? 0;
    }
    return sum;
  }

  String get earliestRequestDate {
    if (widget.payments.isEmpty) return "-";
    List<DateTime> dates = widget.payments.map((p) {
      final d = p["requestDate"] ?? p["Submittion Date"];
      return _parseDate(d);
    }).toList();
    dates.sort((a, b) => a.compareTo(b));
    DateTime earliest = dates.first;
    return "${earliest.year}-${earliest.month.toString().padLeft(2, '0')}-${earliest.day.toString().padLeft(2, '0')}";
  }

  @override
  Widget build(BuildContext context) {
    final stepperItems = getStepperItems();
    final isRejected = widget.status?.toLowerCase() == "rejected";

    return Scaffold(
      backgroundColor: const Color(0xFF181A20),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1F222B),
        title: Text(
          widget.requestTitle,
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
        iconTheme: IconThemeData(color: Colors.white),
        actions: [
          IconButton(
            icon: Icon(Icons.refresh),
            onPressed: _loadApprovalTimeline,
            tooltip: "Refresh Timeline",
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Amazon-style Tracking Card
          Card(
            color: const Color(0xFF1F1F1F),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            elevation: 6,
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Header
                  Row(
                    children: [
                      const Icon(Icons.local_shipping,
                          color: Colors.blueAccent, size: 24),
                      const SizedBox(width: 12),
                      const Expanded(
                        child: Text(
                          "Request Tracking",
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      _buildStatusBadge(widget.status),
                    ],
                  ),
                  const SizedBox(height: 8),

                  // Current Status
                  Text(
                    _getCurrentStatus(),
                    style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Tracking Steps - CLEAN VERSION WITHOUT SUMMARY BOXES
                  _isLoadingTimeline
                      ? _buildLoadingStepper()
                      : _buildCleanStepper(stepperItems),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Rejection Reason
          if (isRejected &&
              widget.rejectionReason != null &&
              widget.rejectionReason!.isNotEmpty)
            _buildRejectionCard(),

          const SizedBox(height: 16),

          // Summary Card
          Card(
            color: const Color(0xFF1F1F1F),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            elevation: 6,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    "Request Summary",
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 12),
                  _summaryRow("Total Payments", "${widget.payments.length}"),
                  _summaryRow(
                      "Total Amount", "₹${totalAmount.toStringAsFixed(2)}"),
                  _summaryRow("Date of Submission", earliestRequestDate),
                  _summaryRow("Current Status", widget.status ?? "Pending"),
                  _summaryRow("Request ID", widget.requestId),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Payment Details
          ...widget.payments.map((payment) {
            final isReimbursement =
                widget.requestTitle.toLowerCase().contains("reimbursement");

            if (isReimbursement) {
              // REIMBURSEMENT FIELDS
              final paymentDate =
                  _parseDate(payment["paymentDate"] ?? payment["date"]);
              final amountStr = payment["amount"]?.toString() ?? "0";
              final descriptionStr = payment["description"] ?? "-";
              final claimType = payment["claimType"] ?? "Not specified";
              final projectId = payment["projectId"] ?? "Not specified";
              final List<String> attachmentPaths = _getAttachmentPaths(payment);

              return Card(
                color: const Color(0xFF1F1F1F),
                elevation: 4,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                margin: const EdgeInsets.symmetric(vertical: 8),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        "Payment Details",
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      const SizedBox(height: 8),
                      _detailText("Project ID", projectId),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          Expanded(
                            child: _detailText(
                              "Payment Date",
                              "${paymentDate.year}-${paymentDate.month.toString().padLeft(2, '0')}-${paymentDate.day.toString().padLeft(2, '0')}",
                            ),
                          ),
                          Expanded(
                            child: _detailText("Claim Type", claimType),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      _detailText("Amount", "₹$amountStr"),
                      const SizedBox(height: 6),
                      _detailText("Description", descriptionStr),
                      if (attachmentPaths.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 10),
                          child: _buildAttachmentsPreview(
                              context, attachmentPaths),
                        ),
                    ],
                  ),
                ),
              );
            } else {
              // ADVANCE REQUEST FIELDS
              final requestDate =
                  _parseDate(payment["requestDate"] ?? payment["date"]);
              final projectDate = _parseDate(payment["projectDate"]);
              final amountStr = payment["amount"]?.toString() ?? "0";
              final particularsStr = payment["particulars"] ?? "-";
              final projectId = payment["projectId"] ?? "Not specified";
              final projectName = payment["projectName"] ?? "Not specified";
              final List<String> attachmentPaths = _getAttachmentPaths(payment);

              return Card(
                color: const Color(0xFF1F1F1F),
                elevation: 4,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                margin: const EdgeInsets.symmetric(vertical: 8),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        "Payment Details",
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      const SizedBox(height: 8),
                      _detailText("Project ID", projectId),
                      _detailText("Project Name", projectName),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          Expanded(
                            child: _detailText(
                              "Request Date",
                              "${requestDate.year}-${requestDate.month.toString().padLeft(2, '0')}-${requestDate.day.toString().padLeft(2, '0')}",
                            ),
                          ),
                          Expanded(
                            child: _detailText(
                              "Project Date",
                              "${projectDate.year}-${projectDate.month.toString().padLeft(2, '0')}-${projectDate.day.toString().padLeft(2, '0')}",
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      _detailText("Amount", "₹$amountStr"),
                      const SizedBox(height: 6),
                      _detailText("Particulars", particularsStr),
                      if (attachmentPaths.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 10),
                          child: _buildAttachmentsPreview(
                              context, attachmentPaths),
                        ),
                    ],
                  ),
                ),
              );
            }
          }).toList(),
        ],
      ),
    );
  }

  // ✅ CLEAN STEPPER WITHOUT SUMMARY BOXES AND PROCESSING TEXT
  Widget _buildCleanStepper(List<StepperItem> items) {
    return Column(
      children: items.asMap().entries.map((entry) {
        final index = entry.key;
        final item = entry.value;
        final isLast = index == items.length - 1;
        final isNextApproverStep = item.isNextApprover;

        return Container(
          margin: const EdgeInsets.only(bottom: 16),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Timeline with connector
              Column(
                children: [
                  // Top connector
                  if (index > 0)
                    Container(
                      width: 2,
                      height: 20,
                      color: items[index - 1].completed
                          ? Colors.green
                          : Colors.grey,
                    ),

                  // Step icon
                  Container(
                    width: 28,
                    height: 28,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: item.isRejected
                          ? Colors.red
                          : item.completed
                              ? Colors.green
                              : isNextApproverStep
                                  ? Colors.blue
                                  : Colors.grey[700],
                      border: Border.all(
                        color: item.isRejected
                            ? Colors.redAccent
                            : item.completed
                                ? Colors.greenAccent
                                : isNextApproverStep
                                    ? Colors.blueAccent
                                    : Colors.grey,
                        width: isNextApproverStep ? 2 : 1,
                      ),
                    ),
                    child: Icon(
                      item.isRejected
                          ? Icons.close
                          : item.completed
                              ? Icons.check
                              : isNextApproverStep
                                  ? Icons.person
                                  : Icons.access_time,
                      color: Colors.white,
                      size: 14,
                    ),
                  ),

                  // Bottom connector
                  if (!isLast)
                    Container(
                      width: 2,
                      height: 20,
                      color: item.completed ? Colors.green : Colors.grey,
                    ),
                ],
              ),
              const SizedBox(width: 12),

              // Content - SIMPLIFIED WITHOUT SUMMARY BOXES
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.title,
                      style: TextStyle(
                        color: item.isRejected
                            ? Colors.redAccent
                            : item.completed
                                ? Colors.greenAccent
                                : isNextApproverStep
                                    ? Colors.blueAccent
                                    : Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 2),

                    // Person name only (no role badge)
                    if (item.personName.isNotEmpty)
                      Text(
                        item.personName,
                        style: TextStyle(
                          color: item.completed
                              ? Colors.greenAccent
                              : isNextApproverStep
                                  ? Colors.blueAccent
                                  : Colors.white70,
                          fontSize: 12,
                        ),
                      ),

                    // Date
                    if (item.date != null)
                      Text(
                        _formatDate(item.date!),
                        style: TextStyle(
                          color: Colors.grey,
                          fontSize: 10,
                        ),
                      ),

                    // Status and description - SIMPLIFIED (NO SUMMARY BOX)
                    if (item.description.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: item.isRejected
                                    ? Colors.red.withOpacity(0.2)
                                    : item.completed
                                        ? Colors.green.withOpacity(0.2)
                                        : isNextApproverStep
                                            ? Colors.blue.withOpacity(0.2)
                                            : Colors.orange.withOpacity(0.2),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                isNextApproverStep ? "NEXT" : item.statusText,
                                style: TextStyle(
                                  color: item.isRejected
                                      ? Colors.redAccent
                                      : item.completed
                                          ? Colors.greenAccent
                                          : isNextApproverStep
                                              ? Colors.blueAccent
                                              : Colors.orangeAccent,
                                  fontSize: 9,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                            SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                item.description,
                                style: TextStyle(
                                  color: Colors.white70,
                                  fontSize: 11,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  int _getCompletedStepsCount() {
    return _timelineItems
        .where((item) =>
            item.status == "completed" ||
            item.status == "paid" ||
            item.status == "approved")
        .length;
  }

  String _getCurrentStatus() {
    switch (widget.status?.toLowerCase()) {
      case "pending":
        return "Request is in approval process";
      case "approved":
        return "Request approved - Waiting for payment";
      case "paid":
        return "Payment processed successfully";
      case "rejected":
        return "Request was rejected";
      default:
        return "Tracking request...";
    }
  }

  Widget _buildLoadingStepper() {
    return Column(
      children: [
        CircularProgressIndicator(),
        SizedBox(height: 16),
        Text(
          "Loading timeline...",
          style: TextStyle(color: Colors.white70),
        ),
      ],
    );
  }

  Widget _buildStatusBadge(String? status) {
    final statusLower = status?.toLowerCase() ?? 'pending';

    Map<String, dynamic> statusConfig = {
      'rejected': {
        'color': Colors.red,
        'text': 'REJECTED',
        'icon': Icons.cancel
      },
      'paid': {
        'color': Colors.green,
        'text': 'PAID',
        'icon': Icons.check_circle
      },
      'approved': {
        'color': Colors.blue,
        'text': 'APPROVED',
        'icon': Icons.verified
      },
      'pending': {
        'color': Colors.orange,
        'text': 'PENDING',
        'icon': Icons.pending
      },
    };

    final config = statusConfig[statusLower] ?? statusConfig['pending']!;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: config['color'].withOpacity(0.3),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: config['color']),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(config['icon'], color: config['color'], size: 14),
          const SizedBox(width: 4),
          Text(
            config['text'],
            style: TextStyle(
              color: config['color'],
              fontSize: 10,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRejectionCard() {
    return Card(
      color: Colors.red.withOpacity(0.2),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      elevation: 6,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(Icons.cancel, color: Colors.redAccent),
                SizedBox(width: 8),
                Text(
                  "Request Rejected",
                  style: TextStyle(
                    color: Colors.redAccent,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              widget.rejectionReason!,
              style: const TextStyle(color: Colors.white70, fontSize: 14),
            ),
          ],
        ),
      ),
    );
  }

  Widget _summaryRow(String title, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          Expanded(
            child: Text(
              "$title:",
              style: const TextStyle(color: Colors.white70, fontSize: 14),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 14,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _detailText(String label, String value) {
    return Text(
      "$label: $value",
      style: const TextStyle(color: Colors.white70, fontSize: 14),
    );
  }

  List<String> _getAttachmentPaths(Map<String, dynamic> payment) {
    if (payment["attachmentPaths"] is List) {
      return List<String>.from(payment["attachmentPaths"] ?? []);
    } else if (payment["attachmentPath"] is String &&
        payment["attachmentPath"].toString().isNotEmpty) {
      return [payment["attachmentPath"].toString()];
    }
    return [];
  }

  Widget _buildAttachmentsPreview(BuildContext context, List<String> paths) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          "Attachments:",
          style: TextStyle(
            color: Colors.white70,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: paths
              .map((path) => _buildSingleAttachment(context, path))
              .toList(),
        ),
      ],
    );
  }

  Widget _buildSingleAttachment(BuildContext context, String path) {
    final fileName = path.split('/').last;
    final ext = fileName.split('.').last.toLowerCase();

    // Helper functions for styling
    Color getFileColor(String ext) {
      switch (ext) {
        case 'pdf':
          return Colors.red.withOpacity(0.3);
        case 'doc':
        case 'docx':
          return Colors.blue.withOpacity(0.3);
        case 'xls':
        case 'xlsx':
          return Colors.green.withOpacity(0.3);
        default:
          return Colors.purple.withOpacity(0.3);
      }
    }

    Color getFileBorderColor(String ext) {
      switch (ext) {
        case 'pdf':
          return Colors.red;
        case 'doc':
        case 'docx':
          return Colors.blue;
        case 'xls':
        case 'xlsx':
          return Colors.green;
        default:
          return Colors.purple;
      }
    }

    IconData getFileIcon(String ext) {
      switch (ext) {
        case 'pdf':
          return Icons.picture_as_pdf;
        case 'doc':
        case 'docx':
          return Icons.description;
        case 'xls':
        case 'xlsx':
          return Icons.table_chart;
        default:
          return Icons.insert_drive_file;
      }
    }

    // Function to handle file opening
    Future<void> openAttachment() async {
      try {
        final file = File(path);
        if (await file.exists()) {
          await OpenFile.open(file.path);
        } else if (path.startsWith('http')) {
          // If it's a URL, download first
          try {
            final response = await http.get(Uri.parse(path));
            final appDocDir = await getApplicationDocumentsDirectory();
            final localFile = File('${appDocDir.path}/$fileName');
            await localFile.writeAsBytes(response.bodyBytes);
            await OpenFile.open(localFile.path);
          } catch (e) {
            print('Error downloading file: $e');
            if (context.mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text("Error downloading file")),
              );
            }
          }
        } else {
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text("File not found: $fileName")),
            );
          }
        }
      } catch (e) {
        print('Error opening file: $e');
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("Error opening file")),
          );
        }
      }
    }

    // For image files
    if (["jpg", "jpeg", "png", "gif"].contains(ext)) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          InkWell(
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => FullImageViewer(file: File(path)),
                ),
              );
            },
            child: Container(
              width: 100,
              height: 80,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.white30),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Image.file(
                  File(path),
                  width: 100,
                  height: 80,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => Center(
                    child: Icon(Icons.insert_drive_file, color: Colors.white70),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 4),
          SizedBox(
            width: 100,
            child: Text(
              fileName,
              style: const TextStyle(
                color: Colors.white54,
                fontSize: 10,
              ),
              overflow: TextOverflow.ellipsis,
              maxLines: 1,
            ),
          ),
        ],
      );
    } else {
      // For other file types
      return InkWell(
        onTap: openAttachment,
        child: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: getFileColor(ext),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: getFileBorderColor(ext)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(getFileIcon(ext), color: Colors.white, size: 16),
              const SizedBox(width: 4),
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 80),
                child: Text(
                  fileName.length > 10
                      ? '${fileName.substring(0, 10)}...'
                      : fileName,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 10,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
      );
    }
  }

  String _formatDate(DateTime date) {
    return "${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}";
  }

  DateTime _parseDate(dynamic d) {
    if (d is DateTime) return d;
    if (d is String) {
      try {
        return DateTime.parse(d);
      } catch (_) {
        return DateTime.now();
      }
    }
    return DateTime.now();
  }
}

class StepperItem {
  final String title;
  final bool completed;
  final DateTime? date;
  final String personName;
  final bool isRejected;
  final String statusText;
  final String description;
  final bool isNextApprover;
  final String? approverRole;

  StepperItem({
    required this.title,
    required this.completed,
    required this.date,
    required this.personName,
    required this.isRejected,
    required this.statusText,
    required this.description,
    required this.isNextApprover,
    this.approverRole,
  });
}

class ApprovalTimelineItem {
  final String step;
  final String approverName;
  final String approverId;
  final DateTime? timestamp;
  final String status;
  final String action;
  final String stepType;
  final String? comments;
  final int? stepNumber;
  final bool? isNextApprover;
  final String? approverRole;

  ApprovalTimelineItem({
    required this.step,
    required this.approverName,
    required this.approverId,
    required this.timestamp,
    required this.status,
    required this.action,
    required this.stepType,
    this.comments,
    this.stepNumber,
    this.isNextApprover,
    this.approverRole,
  });

  factory ApprovalTimelineItem.fromJson(Map<String, dynamic> json) {
    return ApprovalTimelineItem(
      step: json['step'] ?? '',
      approverName: json['approver_name'] ?? '',
      approverId: json['approver_id'] ?? '',
      timestamp:
          json['timestamp'] != null ? DateTime.parse(json['timestamp']) : null,
      status: json['status'] ?? 'pending',
      action: json['action'] ?? '',
      stepType: json['step_type'] ?? '',
      comments: json['comments'],
      stepNumber: json['step_number'],
      isNextApprover: json['is_next_approver'] ?? false,
      approverRole: json['approver_role'],
    );
  }
}

class FullImageViewer extends StatelessWidget {
  final File file;

  const FullImageViewer({super.key, required this.file});

  Future<void> _downloadFile(BuildContext context) async {
    try {
      final downloadsDir = await getApplicationDocumentsDirectory();
      final newFile =
          await file.copy("${downloadsDir.path}/${file.uri.pathSegments.last}");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Saved as ${newFile.uri.pathSegments.last}"),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Download failed: $e"),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        actions: [
          IconButton(
            icon: const Icon(Icons.download),
            onPressed: () => _downloadFile(context),
          ),
        ],
      ),
      body: Center(
        child: InteractiveViewer(
          child: Image.file(
            file,
            fit: BoxFit.contain,
            errorBuilder: (_, __, ___) => const Text("Error loading image",
                style: TextStyle(color: Colors.white)),
          ),
        ),
      ),
    );
  }
}
