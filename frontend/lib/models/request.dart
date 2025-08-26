import 'package:flutter/foundation.dart';

/// Represents either a Reimbursement or Advance request
class Request {
  final String type; // "Reimbursement" or "Advance"
  final String projectId;
  final DateTime dateSubmitted;
  final List<Map<String, dynamic>> payments;
  String status; // "Pending", "Approved", "Rejected"

  Request({
    required this.type,
    required this.projectId,
    required this.dateSubmitted,
    required this.payments,
    this.status = "Pending",
  });

  /// Factory to build a Request from Reimbursement form data
  factory Request.fromReimbursement(Map<String, dynamic> data) {
    return Request(
      type: "Reimbursement",
      projectId: data["projectId"] ?? "",
      dateSubmitted: DateTime.now(),
      payments: List<Map<String, dynamic>>.from(data["payments"] ?? []),
      status: data["status"] ?? "Pending",
    );
  }

  /// Factory to build a Request from Advance form data
  factory Request.fromAdvance(Map<String, dynamic> data) {
    return Request(
      type: "Advance",
      projectId: data["projectId"] ?? "",
      dateSubmitted: DateTime.now(),
      payments: List<Map<String, dynamic>>.from(data["payments"] ?? []),
      status: data["status"] ?? "Pending",
    );
  }

  /// Total amount across all payments
  double get totalAmount {
    try {
      return payments.fold<double>(
        0,
        (sum, p) =>
            sum + (p["amount"] is num ? (p["amount"] as num).toDouble() : 0.0),
      );
    } catch (e) {
      if (kDebugMode) {
        print("Error calculating total amount: $e");
      }
      return 0.0;
    }
  }
}
