// common_dashboard.dart
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

class CommonDashboard extends StatefulWidget {
  final Map<String, dynamic> userData;

  const CommonDashboard({Key? key, required this.userData}) : super(key: key);

  @override
  _CommonDashboardState createState() => _CommonDashboardState();
}

class _CommonDashboardState extends State<CommonDashboard>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  List<Request> _reimbursementRequests = [];
  List<Request> _advanceRequests = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadRequests();
  }

  // Fetch requests where current user is in report_to field
  Future<void> _loadRequests() async {
    try {
      // API call to get requests for this approver
      final response = await http.get(
        Uri.parse(
            "http://10.0.2.2:8000/api/requests/approver/${widget.userData['id']}"),
        headers: {"Content-Type": "application/json"},
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);

        if (data['success'] == true) {
          List<Request> allRequests = (data['requests'] as List)
              .map((requestData) => Request.fromJson(requestData))
              .toList();

          setState(() {
            _reimbursementRequests = allRequests
                .where((request) => request.type == 'Reimbursement')
                .toList();

            _advanceRequests = allRequests
                .where((request) => request.type == 'Advance')
                .toList();

            _isLoading = false;
          });
        } else {
          setState(() {
            _isLoading = false;
          });
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
                content: Text(data['message'] ?? 'Error loading requests')),
          );
        }
      } else {
        setState(() {
          _isLoading = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Server error: ${response.statusCode}')),
        );
      }
    } catch (error) {
      print('Error loading requests: $error');
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error connecting to server')),
      );
    }
  }

  Future<void> _approveRequest(Request request) async {
    try {
      final response = await http.post(
        Uri.parse("http://10.0.2.2:8000/api/requests/approve/${request.id}"),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({
          "approver_id": widget.userData['id'],
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success'] == true) {
          setState(() {
            request.status = 'Approved';
          });
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Request approved successfully'),
              backgroundColor: Colors.green,
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
                content: Text(data['message'] ?? 'Error approving request')),
          );
        }
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Server error: ${response.statusCode}')),
        );
      }
    } catch (error) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error approving request: $error')),
      );
    }
  }

  Future<void> _rejectRequest(Request request, String reason) async {
    try {
      final response = await http.post(
        Uri.parse("http://10.0.2.2:8000/api/requests/reject/${request.id}"),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({
          "approver_id": widget.userData['id'],
          "reason": reason,
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success'] == true) {
          setState(() {
            request.status = 'Rejected';
            request.rejectionReason = reason;
          });
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Request rejected'),
              backgroundColor: Colors.red,
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
                content: Text(data['message'] ?? 'Error rejecting request')),
          );
        }
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Server error: ${response.statusCode}')),
        );
      }
    } catch (error) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error rejecting request: $error')),
      );
    }
  }

  void _showRejectionDialog(Request request) {
    TextEditingController reasonController = TextEditingController();

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('Reason for Rejection'),
          content: TextField(
            controller: reasonController,
            decoration: InputDecoration(
              hintText: 'Enter reason for rejection',
              border: OutlineInputBorder(),
            ),
            maxLines: 3,
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                if (reasonController.text.isNotEmpty) {
                  _rejectRequest(request, reasonController.text);
                  Navigator.of(context).pop();
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                        content: Text('Please enter a reason for rejection')),
                  );
                }
              },
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
              child: Text('Submit Reject'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Expense Approval Dashboard'),
        bottom: TabBar(
          controller: _tabController,
          tabs: [
            Tab(
              icon: Icon(Icons.receipt),
              text: 'Reimbursement (${_reimbursementRequests.length})',
            ),
            Tab(
              icon: Icon(Icons.attach_money),
              text: 'Advance (${_advanceRequests.length})',
            ),
          ],
        ),
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator())
          : TabBarView(
              controller: _tabController,
              children: [
                _buildRequestList(_reimbursementRequests),
                _buildRequestList(_advanceRequests),
              ],
            ),
    );
  }

  Widget _buildRequestList(List<Request> requests) {
    if (requests.isEmpty) {
      return Center(
        child: Text(
          'No requests found',
          style: TextStyle(fontSize: 18),
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadRequests,
      child: ListView.builder(
        itemCount: requests.length,
        itemBuilder: (context, index) {
          return RequestTile(
            request: requests[index],
            onApprove: _approveRequest,
            onReject: _showRejectionDialog,
          );
        },
      ),
    );
  }
}

class Request {
  final String id;
  final String requesterName;
  final String requesterId;
  final DateTime date;
  final double amount;
  final String type;
  final List<ExpenseItem> items;
  final List<String> attachments;
  String status;
  String? rejectionReason;

  Request({
    required this.id,
    required this.requesterName,
    required this.requesterId,
    required this.date,
    required this.amount,
    required this.type,
    required this.items,
    required this.attachments,
    this.status = 'Pending',
    this.rejectionReason,
  });

  factory Request.fromJson(Map<String, dynamic> json) {
    return Request(
      id: json['id'],
      requesterName: json['requester_name'],
      requesterId: json['requester_id'],
      date: DateTime.parse(json['date']),
      amount: json['amount'].toDouble(),
      type: json['type'],
      items: (json['items'] as List)
          .map((item) => ExpenseItem.fromJson(item))
          .toList(),
      attachments: List<String>.from(json['attachments']),
      status: json['status'],
      rejectionReason: json['rejection_reason'],
    );
  }
}

class ExpenseItem {
  final String category;
  final double amount;

  ExpenseItem({required this.category, required this.amount});

  factory ExpenseItem.fromJson(Map<String, dynamic> json) {
    return ExpenseItem(
      category: json['category'],
      amount: json['amount'].toDouble(),
    );
  }
}

class RequestTile extends StatefulWidget {
  final Request request;
  final Function(Request) onApprove;
  final Function(Request) onReject;

  const RequestTile({
    required this.request,
    required this.onApprove,
    required this.onReject,
  });

  @override
  _RequestTileState createState() => _RequestTileState();
}

class _RequestTileState extends State<RequestTile> {
  bool _isExpanded = false;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      child: ExpansionTile(
        leading: Icon(
          widget.request.type == 'Reimbursement'
              ? Icons.receipt
              : Icons.attach_money,
          color: _getStatusColor(),
        ),
        title: Row(
          children: [
            Expanded(
              flex: 2,
              child: Text(
                widget.request.requesterName,
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
            Expanded(
              flex: 2,
              child: Text(
                DateFormat('dd-MMM-yyyy').format(widget.request.date),
              ),
            ),
            Expanded(
              flex: 2,
              child: Text(
                '₹${widget.request.amount.toStringAsFixed(0)}',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
            Expanded(
              flex: 3,
              child: Container(
                padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: _getStatusColor().withOpacity(0.2),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  widget.request.status,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: _getStatusColor(),
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ],
        ),
        trailing: Icon(
          _isExpanded ? Icons.expand_less : Icons.expand_more,
          color: Colors.grey[400],
        ),
        onExpansionChanged: (expanded) {
          setState(() {
            _isExpanded = expanded;
          });
        },
        children: [
          Padding(
            padding: EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildDetailRow('Requester:', widget.request.requesterName),
                _buildDetailRow('Date:',
                    DateFormat('dd-MMM-yyyy').format(widget.request.date)),
                _buildDetailRow('Type:', widget.request.type),
                _buildDetailRow(
                    'Amount:', '₹${widget.request.amount.toStringAsFixed(0)}'),
                SizedBox(height: 10),
                Text('Items:', style: TextStyle(fontWeight: FontWeight.bold)),
                ...widget.request.items
                    .map((item) => Padding(
                          padding: EdgeInsets.only(left: 16, top: 4),
                          child: Text(
                              '• ${item.category}: ₹${item.amount.toStringAsFixed(0)}'),
                        ))
                    .toList(),
                SizedBox(height: 10),
                Text('Attachments:',
                    style: TextStyle(fontWeight: FontWeight.bold)),
                Wrap(
                  spacing: 8,
                  children: widget.request.attachments
                      .map((attachment) => Chip(
                            label: Text(attachment),
                            backgroundColor: Colors.blueGrey[700],
                          ))
                      .toList(),
                ),
                if (widget.request.rejectionReason != null) ...[
                  SizedBox(height: 10),
                  Text('Rejection Reason:',
                      style: TextStyle(
                          fontWeight: FontWeight.bold, color: Colors.red)),
                  Text(widget.request.rejectionReason!,
                      style: TextStyle(color: Colors.red[300])),
                ],
                if (widget.request.status == 'Pending') ...[
                  SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      ElevatedButton(
                        onPressed: () => widget.onApprove(widget.request),
                        style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.green),
                        child: Text('Approve'),
                      ),
                      SizedBox(width: 10),
                      ElevatedButton(
                        onPressed: () => widget.onReject(widget.request),
                        style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.red),
                        child: Text('Reject'),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Text(label, style: TextStyle(fontWeight: FontWeight.bold)),
          SizedBox(width: 8),
          Text(value),
        ],
      ),
    );
  }

  Color _getStatusColor() {
    switch (widget.request.status) {
      case 'Approved':
        return Colors.green;
      case 'Rejected':
        return Colors.red;
      default:
        return Colors.orange;
    }
  }
}
