// models/finance_request.dart
import 'dart:convert';

class FinanceRequest {
  final int id;
  final String employeeId;
  final String employeeName;
  final String? avatarUrl;
  final String submissionDate;
  final double amount;
  final String description;
  final List<dynamic> payments;
  final List<dynamic> attachments;
  final String requestType;
  final String status;
  final String? approvedBy;
  final String? approvalDate;
  final String? projectId;
  final String? projectName;
  final String? reimbursementDate;
  final String? requestDate;
  final String? projectDate;
  final String? paymentDate;
  final String? rejectionReason;
  final bool approvedByCeo;
  final bool approvedByFinance;

  FinanceRequest({
    required this.id,
    required this.employeeId,
    required this.employeeName,
    required this.submissionDate,
    required this.amount,
    required this.description,
    required this.payments,
    required this.attachments,
    required this.requestType,
    required this.status,
    this.avatarUrl,
    this.approvedBy,
    this.approvalDate,
    this.projectId,
    this.projectName,
    this.reimbursementDate,
    this.requestDate,
    this.projectDate,
    this.paymentDate,
    this.rejectionReason,
    this.approvedByCeo = false,
    this.approvedByFinance = false,
  });

  factory FinanceRequest.fromJson(Map<String, dynamic> json) {
    return FinanceRequest(
      id: json['id'] ?? 0,
      employeeId: json['employee_id']?.toString() ?? 'Unknown',
      employeeName: json['employee_name']?.toString() ?? 'Unknown',
      avatarUrl: json['employee_avatar'],
      submissionDate: json['submitted_date']?.toString() ??
          json['created_at']?.toString() ??
          'Unknown',
      amount: (json['amount'] ?? 0).toDouble(),
      description: json['description']?.toString() ?? '',
      payments: _parsePayments(json['payments']),
      attachments: _parseAttachments(json['attachments']),
      requestType: json['request_type']?.toString() ?? 'Unknown',
      status: json['status'] ?? 'pending',
      approvedBy: json['approved_by'] ?? json['final_approver'],
      approvalDate: json['approval_date'],
      projectId: json['project_id'] ?? json['projectId'],
      projectName: json['project_name'] ?? json['projectName'],
      reimbursementDate:
          json['reimbursement_date'] ?? json['reimbursementDate'],
      requestDate: json['request_date'] ?? json['requestDate'],
      projectDate: json['project_date'] ?? json['projectDate'],
      paymentDate: json['payment_date'],
      rejectionReason: json['rejection_reason'],
      approvedByCeo: json['approved_by_ceo'] ?? false,
      approvedByFinance: json['approved_by_finance'] ?? false,
    );
  }

  static List<dynamic> _parsePayments(dynamic paymentsData) {
    if (paymentsData == null) return [];

    if (paymentsData is List) return paymentsData;

    if (paymentsData is String) {
      try {
        return jsonDecode(paymentsData);
      } catch (e) {
        print('Error parsing payments JSON: $e');
        return [];
      }
    }

    return [];
  }

  static List<dynamic> _parseAttachments(dynamic attachmentsData) {
    if (attachmentsData == null) return [];

    if (attachmentsData is List) return attachmentsData;

    if (attachmentsData is String) {
      try {
        return jsonDecode(attachmentsData);
      } catch (e) {
        // Agar JSON parse na ho sake, toh single attachment ki list bana de
        return [attachmentsData];
      }
    }

    return [];
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'employee_id': employeeId,
      'employee_name': employeeName,
      'employee_avatar': avatarUrl,
      'submitted_date': submissionDate,
      'amount': amount,
      'description': description,
      'payments': payments,
      'attachments': attachments,
      'request_type': requestType,
      'status': status,
      'approved_by': approvedBy,
      'approval_date': approvalDate,
      'project_id': projectId,
      'project_name': projectName,
      'reimbursement_date': reimbursementDate,
      'request_date': requestDate,
      'project_date': projectDate,
      'payment_date': paymentDate,
      'rejection_reason': rejectionReason,
      'approved_by_ceo': approvedByCeo,
      'approved_by_finance': approvedByFinance,
    };
  }

  // Helper method to check if request is ready for payment
  bool get isReadyForPayment {
    return approvedByCeo && status.toLowerCase() == 'approved';
  }

  // Helper method to check if request is paid
  bool get isPaid {
    return status.toLowerCase() == 'paid';
  }

  // Helper method to get display status
  String get displayStatus {
    if (isPaid) return 'Paid';
    if (approvedByCeo) return 'Approved by CEO';
    if (approvedByFinance) return 'Approved by Finance';
    if (rejectionReason != null && rejectionReason!.isNotEmpty)
      return 'Rejected';
    return 'Pending';
  }
}
