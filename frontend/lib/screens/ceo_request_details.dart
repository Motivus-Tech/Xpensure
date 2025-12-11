import 'dart:io';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:share_plus/share_plus.dart';
import 'package:open_file/open_file.dart';
import '../services/api_service.dart';
import '../utils/date_formatter.dart';

class CeoRequestDetails extends StatefulWidget {
  final dynamic request;
  final Map<String, dynamic>? requestData;
  final String authToken;

  const CeoRequestDetails({
    super.key,
    this.request,
    this.requestData,
    required this.authToken,
  }) : assert(request != null || requestData != null,
            'Either request or requestData must be provided');

  dynamic getRequestData(String key) {
    if (requestData != null) {
      return requestData![key];
    } else {
      switch (key) {
        case 'id':
          return request.id;
        case 'employeeName':
          return request.employeeName;
        case 'employeeId':
          return request.employeeId;
        case 'amount':
          return request.amount;
        case 'date':
          return request.date;
        case 'submitted_date':
          return request.submittedDate;
        case 'description':
          return request.description;
        case 'status':
          return request.status;
        case 'type':
          return request.type;
        case 'requestType':
          return request.requestType;
        case 'payments':
          return request.payments;
        case 'attachments':
          return request.attachments;
        case 'employeeAvatar':
          return request.employeeAvatar;
        case 'project_id':
          return request.projectId;
        case 'project_name':
          return request.projectName;
        case 'reimbursement_date':
          return request.reimbursementDate;
        case 'request_date':
          return request.requestDate;
        case 'project_date':
          return request.projectDate;
        case 'approved_by':
          return request.approvedBy;
        case 'approval_date':
          return request.approvalDate;
        case 'payment_date':
          return request.paymentDate;
        case 'rejection_reason':
          return request.rejectionReason;
        case 'rawData':
          return request.rawData;
        case 'claimType':
          return request.claimType;
        case 'particulars':
          return request.particulars;
        case 'project_code':
          return request.projectCode;
        case 'projectCode':
          return request.projectCode;
        default:
          return null;
      }
    }
  }

  int get requestId => getRequestData('id');
  String get requestType => (getRequestData('requestType') ?? 'reimbursement')
      .toString()
      .toLowerCase();

  @override
  State<CeoRequestDetails> createState() => _CeoRequestDetailsState();
}

class _CeoRequestDetailsState extends State<CeoRequestDetails> {
  final ApiService apiService = ApiService();
  bool _isProcessing = false;
  final String baseUrl = "http://3.110.215.143";

  // Helper methods for amount handling
  double _parseAmount(dynamic amount) {
    if (amount is double) return amount;
    if (amount is int) return amount.toDouble();
    if (amount is String) return double.tryParse(amount) ?? 0.0;
    return 0.0;
  }

  // ✅ UTILITY FUNCTION FOR CAPITALIZING REQUEST TYPES
  String capitalizeRequestType(String requestType) {
    if (requestType.toLowerCase().contains('reimbursement')) {
      return 'Reimbursement';
    } else if (requestType.toLowerCase().contains('advance')) {
      return 'Advance';
    } else {
      return requestType[0].toUpperCase() + requestType.substring(1);
    }
  }

  String _formatAmount(dynamic amount) {
    final parsedAmount = _parseAmount(amount);
    return parsedAmount.toStringAsFixed(2);
  }

  // ENHANCED ATTACHMENT HANDLING METHODS
  String _getFileName(String path) {
    try {
      return path.split('/').last;
    } catch (e) {
      return 'Unknown file';
    }
  }

  String _getFileExtension(String path) {
    try {
      return path.toLowerCase().split('.').last;
    } catch (e) {
      return '';
    }
  }

  bool _isImageFile(String path) {
    final ext = _getFileExtension(path);
    return ['jpg', 'jpeg', 'png', 'gif', 'bmp', 'webp'].contains(ext);
  }

  bool _isPdfFile(String path) {
    return _getFileExtension(path) == 'pdf';
  }

  bool _isDocumentFile(String path) {
    final ext = _getFileExtension(path);
    return ['doc', 'docx'].contains(ext);
  }

  bool _isExcelFile(String path) {
    final ext = _getFileExtension(path);
    return ['xls', 'xlsx'].contains(ext);
  }

  bool _isTextFile(String path) {
    final ext = _getFileExtension(path);
    return ['txt', 'rtf'].contains(ext);
  }

  IconData _getFileIcon(String path) {
    if (_isImageFile(path)) return Icons.image;
    if (_isPdfFile(path)) return Icons.picture_as_pdf;
    if (_isDocumentFile(path)) return Icons.description;
    if (_isExcelFile(path)) return Icons.table_chart;
    if (_isTextFile(path)) return Icons.text_snippet;
    return Icons.insert_drive_file;
  }

  Color _getFileIconColor(String path) {
    if (_isImageFile(path)) return Colors.amber;
    if (_isPdfFile(path)) return Colors.red;
    if (_isDocumentFile(path)) return Colors.blue;
    if (_isExcelFile(path)) return Colors.green;
    if (_isTextFile(path)) return Colors.orange;
    return Colors.grey;
  }

  // ENHANCED PROJECT INFORMATION EXTRACTION - FIXED FOR REIMBURSEMENT AND ADVANCE
  Map<String, dynamic> _getProjectInfo() {
    Map<String, dynamic> projectInfo = {};

    // Try multiple possible keys for project information
    final possibleProjectIdKeys = [
      'project_id',
      'projectId',
      'project_code',
      'projectCode',
      'projectID',
      'projectid'
    ];

    final possibleProjectNameKeys = [
      'project_name',
      'projectName',
      'project_title',
      'projectTitle',
      'projectname'
    ];

    // Extract project ID - CHECK BOTH REQUEST DATA AND RAW DATA
    for (String key in possibleProjectIdKeys) {
      final value = widget.getRequestData(key);
      if (value != null && value.toString().isNotEmpty) {
        projectInfo['id'] = value.toString();
        break;
      }
    }

    // Extract project name - CHECK BOTH REQUEST DATA AND RAW DATA
    for (String key in possibleProjectNameKeys) {
      final value = widget.getRequestData(key);
      if (value != null && value.toString().isNotEmpty) {
        projectInfo['name'] = value.toString();
        break;
      }
    }

    // CRITICAL FIX: Also check in raw data if available (this is where project data often is)
    final rawData = widget.getRequestData('rawData');
    if (rawData != null && rawData is Map) {
      print("🔍 Checking rawData for project info: $rawData");

      for (String key in possibleProjectIdKeys) {
        if (rawData.containsKey(key) &&
            rawData[key] != null &&
            rawData[key].toString().isNotEmpty) {
          projectInfo['id'] = rawData[key].toString();
          print("✅ Found project ID in rawData: ${rawData[key]}");
          break;
        }
      }
      for (String key in possibleProjectNameKeys) {
        if (rawData.containsKey(key) &&
            rawData[key] != null &&
            rawData[key].toString().isNotEmpty) {
          projectInfo['name'] = rawData[key].toString();
          print("✅ Found project name in rawData: ${rawData[key]}");
          break;
        }
      }
    }

    // Check payments array for project info
    final payments = widget.getRequestData('payments');
    if (payments != null && payments is List && payments.isNotEmpty) {
      for (var payment in payments) {
        if (payment is Map) {
          for (String key in possibleProjectIdKeys) {
            if (payment.containsKey(key) &&
                payment[key] != null &&
                payment[key].toString().isNotEmpty) {
              projectInfo['id'] = payment[key].toString();
              break;
            }
          }
          for (String key in possibleProjectNameKeys) {
            if (payment.containsKey(key) &&
                payment[key] != null &&
                payment[key].toString().isNotEmpty) {
              projectInfo['name'] = payment[key].toString();
              break;
            }
          }
        }
      }
    }

    print("📊 Final project info extracted: $projectInfo");
    return projectInfo;
  }

  // ENHANCED ATTACHMENT EXTRACTION
  List<String> _getAttachmentPaths(Map<String, dynamic> payment) {
    List<String> attachmentPaths = [];

    // Priority 1: Check attachmentPaths array
    if (payment['attachmentPaths'] is List) {
      final paths = payment['attachmentPaths'] as List;
      for (var path in paths) {
        if (path is String && path.isNotEmpty) {
          attachmentPaths.add(path);
        }
      }
    }

    // Priority 2: Check for single attachmentPath
    if (payment['attachmentPath'] is String &&
        payment['attachmentPath'].toString().isNotEmpty) {
      attachmentPaths.add(payment['attachmentPath'].toString());
    }

    // Priority 3: Check direct attachment fields
    final directFields = ['attachment', 'file', 'receipt', 'document'];
    for (String field in directFields) {
      if (payment[field] is String && payment[field].toString().isNotEmpty) {
        attachmentPaths.add(payment[field].toString());
        break;
      }
    }

    // Priority 4: Check for any URLs or file paths
    if (attachmentPaths.isEmpty) {
      payment.forEach((key, value) {
        if (value is String && value.isNotEmpty) {
          if (value.startsWith('http') ||
              value.startsWith('/') ||
              value.contains('.jpg') ||
              value.contains('.png') ||
              value.contains('.pdf')) {
            attachmentPaths.add(value);
          }
        }
      });
    }

    return attachmentPaths;
  }

  // ENHANCED FILE VIEWING AND DOWNLOADING METHODS
  void _showImageDialog(String imagePath) {
    showDialog(
      context: context,
      builder: (_) => Dialog(
        backgroundColor: const Color.fromARGB(255, 28, 28, 28),
        insetPadding: const EdgeInsets.all(20),
        child: Stack(
          children: [
            InteractiveViewer(
              panEnabled: true,
              minScale: 0.5,
              maxScale: 3.0,
              child: Center(
                child: imagePath.startsWith('http')
                    ? Image.network(imagePath, fit: BoxFit.contain)
                    : Image.file(File(imagePath), fit: BoxFit.contain),
              ),
            ),
            Positioned(
              top: 10,
              right: 10,
              child: IconButton(
                icon: const Icon(Icons.close, color: Colors.white, size: 30),
                onPressed: () => Navigator.pop(context),
              ),
            ),
            Positioned(
              bottom: 10,
              right: 10,
              child: ElevatedButton.icon(
                onPressed: () => _downloadAndOpenFile(imagePath),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blueAccent,
                  foregroundColor: Colors.white,
                ),
                icon: const Icon(Icons.download),
                label: const Text('Download'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _openFileWithDialog(String filePath) async {
    try {
      // First download the file if it's from network
      String localPath;
      if (filePath.startsWith('http')) {
        localPath = await _downloadFile(filePath);
      } else {
        localPath = filePath;
      }

      // Use open_file to show the "Open With" dialog
      final result = await OpenFile.open(localPath);

      // Handle the result
      _handleOpenFileResult(result, filePath);
    } catch (e) {
      print('Error opening file: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error opening file: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _handleOpenFileResult(OpenResult result, String originalPath) {
    switch (result.type) {
      case ResultType.done:
        print("File opened successfully");
        break;
      case ResultType.noAppToOpen:
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('No app found to open this file'),
            backgroundColor: Colors.orange,
          ),
        );
        break;
      case ResultType.fileNotFound:
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('File not found'),
            backgroundColor: Colors.red,
          ),
        );
        break;
      case ResultType.permissionDenied:
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Permission denied to open file'),
            backgroundColor: Colors.red,
          ),
        );
        break;
      case ResultType.error:
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: ${result.message}'),
            backgroundColor: Colors.red,
          ),
        );
        break;
    }
  }

  Future<String> _downloadFile(String filePath) async {
    try {
      if (filePath.startsWith('http')) {
        final response = await http.get(Uri.parse(filePath));
        final tempDir = await getTemporaryDirectory();
        final fileName = _getFileName(filePath);
        final file = File('${tempDir.path}/$fileName');

        await file.writeAsBytes(response.bodyBytes);
        return file.path;
      } else {
        return filePath;
      }
    } catch (e) {
      throw Exception('Download failed: $e');
    }
  }

  Future<void> _downloadAndOpenFile(String filePath) async {
    try {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Downloading ${_getFileName(filePath)}...'),
          backgroundColor: const Color(0xFF1A237E),
          duration: const Duration(seconds: 2),
        ),
      );

      final downloadedPath = await _downloadFile(filePath);
      final file = File(downloadedPath);

      if (await file.exists()) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('File downloaded successfully!'),
            backgroundColor: const Color(0xFF1E8C3E),
            duration: const Duration(seconds: 2),
          ),
        );

        // Auto-open the file with "Open With" dialog
        await _openFileWithDialog(downloadedPath);
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error downloading file: $e'),
          backgroundColor: const Color(0xFFB71C1C),
        ),
      );
    }
  }

  Future<void> _downloadOnly(String filePath) async {
    try {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Downloading ${_getFileName(filePath)}...'),
          backgroundColor: const Color(0xFF1A237E),
          duration: const Duration(seconds: 2),
        ),
      );

      String downloadedPath;

      if (filePath.startsWith('http')) {
        // Download from network
        final response = await http.get(Uri.parse(filePath));

        // Use Downloads directory for user-accessible storage
        final downloadsDir = await getDownloadsDirectory();
        if (downloadsDir == null) {
          throw Exception('Could not access downloads directory');
        }

        final fileName = _getFileName(filePath);
        final file = File('${downloadsDir.path}/$fileName');

        await file.writeAsBytes(response.bodyBytes);
        downloadedPath = file.path;
      } else {
        // For local files, copy to downloads directory
        final originalFile = File(filePath);
        final downloadsDir = await getDownloadsDirectory();
        if (downloadsDir == null) {
          throw Exception('Could not access downloads directory');
        }

        final fileName = _getFileName(filePath);
        final newFile = File('${downloadsDir.path}/$fileName');

        await originalFile.copy(newFile.path);
        downloadedPath = newFile.path;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('File downloaded successfully!'),
              Text(
                'Location: ${downloadedPath.split('/').last}',
                style: TextStyle(fontSize: 12, color: Colors.white70),
              ),
            ],
          ),
          backgroundColor: const Color(0xFF1E8C3E),
          duration: const Duration(seconds: 4),
          action: SnackBarAction(
            label: 'OPEN',
            textColor: Colors.white,
            onPressed: () => _openFileWithDialog(downloadedPath),
          ),
        ),
      );

      print('File downloaded to: $downloadedPath');
    } catch (e) {
      print('Error downloading file: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error downloading file: $e'),
          backgroundColor: const Color(0xFFB71C1C),
          duration: const Duration(seconds: 4),
        ),
      );
    }
  }

  Future<void> _shareFile(String filePath) async {
    try {
      final downloadedPath = await _downloadFile(filePath);
      final file = File(downloadedPath);

      if (await file.exists()) {
        await Share.shareXFiles(
          [XFile(downloadedPath)],
          text: 'Check out this file: ${_getFileName(filePath)}',
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error sharing file: $e'),
          backgroundColor: const Color(0xFFB71C1C),
        ),
      );
    }
  }

  // ENHANCED ATTACHMENT PREVIEW WIDGET WITH RESPONSIVE DESIGN
  Widget _buildSingleAttachmentPreview(String attachmentPath, bool isMobile) {
    final isImage = _isImageFile(attachmentPath);

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8),
      color: const Color(0xFF0D0D0D),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.grey[800]!, width: 1),
      ),
      child: Padding(
        padding: EdgeInsets.all(isMobile ? 12 : 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  _getFileIcon(attachmentPath),
                  color: _getFileIconColor(attachmentPath),
                  size: isMobile ? 20 : 24,
                ),
                SizedBox(width: isMobile ? 8 : 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _getFileName(attachmentPath),
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w500,
                          fontSize: isMobile ? 13 : 14,
                        ),
                        overflow: TextOverflow.ellipsis,
                        maxLines: 1,
                      ),
                      Text(
                        _getFileExtension(attachmentPath).toUpperCase(),
                        style: TextStyle(
                          color: Colors.grey[400],
                          fontSize: isMobile ? 10 : 12,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (isImage)
              Container(
                height: isMobile ? 120 : 150,
                width: double.infinity,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.grey[700]!),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: attachmentPath.startsWith('http')
                      ? Image.network(
                          attachmentPath,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) {
                            return Container(
                              color: Colors.grey[800],
                              child: Icon(
                                Icons.broken_image,
                                color: Colors.grey,
                                size: isMobile ? 30 : 40,
                              ),
                            );
                          },
                        )
                      : Image.file(
                          File(attachmentPath),
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) {
                            return Container(
                              color: Colors.grey[800],
                              child: Icon(
                                Icons.broken_image,
                                color: Colors.grey,
                                size: isMobile ? 30 : 40,
                              ),
                            );
                          },
                        ),
                ),
              ),
            if (isImage) const SizedBox(height: 12),
            _buildFileActions(attachmentPath, isMobile),
          ],
        ),
      ),
    );
  }

  Widget _buildFileActions(String filePath, bool isMobile) {
    final isImage = _isImageFile(filePath);

    if (isMobile) {
      if (isImage) {
        return Column(
          children: [
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () => _showImageDialog(filePath),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF7B1FA2),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    icon: const Icon(Icons.visibility, size: 16),
                    label: const Text('View'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _openFileWithDialog(filePath),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFF1976D2),
                      side: const BorderSide(color: Color(0xFF1976D2)),
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    icon: const Icon(Icons.open_in_new, size: 16),
                    label: const Text('Open'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _downloadOnly(filePath),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFF388E3C),
                      side: const BorderSide(color: Color(0xFF388E3C)),
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    icon: const Icon(Icons.download, size: 16),
                    label: const Text('Download'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _shareFile(filePath),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFF9C27B0),
                      side: const BorderSide(color: Color(0xFF9C27B0)),
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    icon: const Icon(Icons.share, size: 16),
                    label: const Text('Share'),
                  ),
                ),
              ],
            ),
          ],
        );
      } else {
        return Column(
          children: [
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () => _openFileWithDialog(filePath),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFC62828),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    icon: const Icon(Icons.open_in_new, size: 16),
                    label: const Text('Open'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _downloadOnly(filePath),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFF1976D2),
                      side: const BorderSide(color: Color(0xFF1976D2)),
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    icon: const Icon(Icons.download, size: 16),
                    label: const Text('Download'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () => _shareFile(filePath),
                style: OutlinedButton.styleFrom(
                  foregroundColor: const Color(0xFF388E3C),
                  side: const BorderSide(color: Color(0xFF388E3C)),
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                icon: const Icon(Icons.share, size: 16),
                label: const Text('Share File'),
              ),
            ),
          ],
        );
      }
    } else {
      // Desktop/Tablet layout
      if (isImage) {
        return Row(
          children: [
            Expanded(
              child: ElevatedButton.icon(
                onPressed: () => _showImageDialog(filePath),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF7B1FA2),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                icon: const Icon(Icons.visibility, size: 18),
                label: const Text('View'),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () => _openFileWithDialog(filePath),
                style: OutlinedButton.styleFrom(
                  foregroundColor: const Color(0xFF1976D2),
                  side: const BorderSide(color: Color(0xFF1976D2)),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                icon: const Icon(Icons.open_in_new, size: 18),
                label: const Text('Open'),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () => _downloadOnly(filePath),
                style: OutlinedButton.styleFrom(
                  foregroundColor: const Color(0xFF388E3C),
                  side: const BorderSide(color: Color(0xFF388E3C)),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                icon: const Icon(Icons.download, size: 18),
                label: const Text('Download'),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () => _shareFile(filePath),
                style: OutlinedButton.styleFrom(
                  foregroundColor: const Color(0xFF9C27B0),
                  side: const BorderSide(color: Color(0xFF9C27B0)),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                icon: const Icon(Icons.share, size: 18),
                label: const Text('Share'),
              ),
            ),
          ],
        );
      } else {
        return Row(
          children: [
            Expanded(
              child: ElevatedButton.icon(
                onPressed: () => _openFileWithDialog(filePath),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFC62828),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                icon: const Icon(Icons.open_in_new, size: 18),
                label: const Text('Open'),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () => _downloadOnly(filePath),
                style: OutlinedButton.styleFrom(
                  foregroundColor: const Color(0xFF1976D2),
                  side: const BorderSide(color: Color(0xFF1976D2)),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                icon: const Icon(Icons.download, size: 18),
                label: const Text('Download'),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () => _shareFile(filePath),
                style: OutlinedButton.styleFrom(
                  foregroundColor: const Color(0xFF388E3C),
                  side: const BorderSide(color: Color(0xFF388E3C)),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                icon: const Icon(Icons.share, size: 18),
                label: const Text('Share'),
              ),
            ),
          ],
        );
      }
    }
  }

  Widget _buildAttachmentsSection(List<String> attachmentPaths, bool isMobile) {
    if (attachmentPaths.isEmpty) {
      return const Padding(
        padding: EdgeInsets.only(top: 8),
        child: Text(
          'No attachments',
          style: TextStyle(color: Colors.grey),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 8),
        Text(
          'Attachments:',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: isMobile ? 14 : 16,
          ),
        ),
        const SizedBox(height: 8),
        ...attachmentPaths
            .map((path) => _buildSingleAttachmentPreview(path, isMobile))
            .toList(),
      ],
    );
  }

  // ENHANCED DETAIL CARD WITH RESPONSIVE DESIGN
  Widget _buildDetailCard(String title, IconData icon, List<Widget> children,
      {Color? headerColor, bool isMobile = true}) {
    return Container(
      margin: EdgeInsets.only(bottom: isMobile ? 12 : 16),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A1A),
        borderRadius: BorderRadius.circular(isMobile ? 12 : 16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.3),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(isMobile ? 12 : 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header with icon
            Container(
              width: double.infinity,
              padding: EdgeInsets.all(isMobile ? 12 : 16),
              decoration: BoxDecoration(
                color: headerColor ?? const Color(0xFF252525),
                border: Border(
                  bottom: BorderSide(color: Colors.grey[700]!, width: 1),
                ),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: (headerColor ?? Colors.blue).withOpacity(0.2),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(icon,
                        size: isMobile ? 16 : 18,
                        color: headerColor ?? Colors.blue),
                  ),
                  SizedBox(width: isMobile ? 8 : 12),
                  Text(
                    title,
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: isMobile ? 14 : 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
            // Content
            Padding(
              padding: EdgeInsets.all(isMobile ? 12 : 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: children,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ENHANCED DETAIL ITEM WITH RESPONSIVE DESIGN
  Widget _detailItem(String label, String value,
      {bool isImportant = false, Color? valueColor, bool isMobile = true}) {
    return Container(
      padding: EdgeInsets.symmetric(vertical: isMobile ? 6 : 8),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(color: Colors.grey[800]!, width: 0.5),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: isMobile ? 100 : 140,
            child: Text(
              label,
              style: TextStyle(
                color: Colors.grey[400],
                fontWeight: FontWeight.w500,
                fontSize: isMobile ? 12 : 14,
              ),
            ),
          ),
          SizedBox(width: isMobile ? 8 : 12),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                color: valueColor ??
                    (isImportant ? const Color(0xFF00E5FF) : Colors.white),
                fontWeight: isImportant ? FontWeight.w600 : FontWeight.normal,
                fontSize: isMobile ? 12 : 14,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // DATE FIELD HANDLING
  Widget _detailItemWithDate(String label, String? backendDate,
      {bool isImportant = false, bool isMobile = true}) {
    String displayDate = 'Not specified';

    if (backendDate != null && backendDate.isNotEmpty) {
      displayDate = DateFormatter.formatBackendDate(backendDate);
    }

    return _detailItem(label, displayDate,
        isImportant: isImportant, isMobile: isMobile);
  }

  // ENHANCED STATUS BADGE WITH RESPONSIVE DESIGN
  Widget _buildStatusBadge(bool isMobile) {
    final status =
        widget.getRequestData('status')?.toString().toLowerCase() ?? 'pending';
    final rejectionReason = widget.getRequestData('rejection_reason');

    Color statusColor = Colors.orange;
    IconData statusIcon = Icons.pending_actions;
    String statusText = 'PENDING CEO APPROVAL';
    String description = 'Waiting for CEO approval';

    if (status.contains('paid')) {
      statusColor = Colors.green;
      statusIcon = Icons.verified;
      statusText = 'PAID';
      description = 'Payment has been processed successfully';
    } else if (status.contains('approved') || status.contains('ceo_approved')) {
      statusColor = Colors.blue;
      statusIcon = Icons.assignment_turned_in;
      statusText = 'APPROVED BY CEO';
      description = 'Ready for payment processing';
    } else if (status.contains('finance_approved')) {
      statusColor = Colors.teal;
      statusIcon = Icons.verified_user;
      statusText = 'APPROVED BY FINANCE';
      description = 'Waiting for CEO approval';
    } else if (status.contains('rejected') || rejectionReason != null) {
      statusColor = Colors.red;
      statusIcon = Icons.cancel;
      statusText = 'REJECTED';
      description = 'Request has been rejected';
    }

    return Container(
      width: double.infinity,
      margin: EdgeInsets.only(bottom: isMobile ? 16 : 20),
      padding: EdgeInsets.all(isMobile ? 16 : 20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
          colors: [
            statusColor.withOpacity(0.15),
            statusColor.withOpacity(0.05),
          ],
        ),
        borderRadius: BorderRadius.circular(isMobile ? 12 : 16),
        border: Border.all(color: statusColor.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          Container(
            padding: EdgeInsets.all(isMobile ? 10 : 12),
            decoration: BoxDecoration(
              color: statusColor.withOpacity(0.2),
              shape: BoxShape.circle,
            ),
            child:
                Icon(statusIcon, color: statusColor, size: isMobile ? 24 : 28),
          ),
          SizedBox(width: isMobile ? 12 : 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  statusText,
                  style: TextStyle(
                    color: statusColor,
                    fontWeight: FontWeight.bold,
                    fontSize: isMobile ? 14 : 16,
                  ),
                ),
                SizedBox(height: isMobile ? 2 : 4),
                Text(
                  description,
                  style: TextStyle(
                    color: statusColor.withOpacity(0.8),
                    fontSize: isMobile ? 11 : 13,
                  ),
                ),
                if (rejectionReason != null && rejectionReason.isNotEmpty) ...[
                  SizedBox(height: isMobile ? 4 : 8),
                  Text(
                    'Reason: $rejectionReason',
                    style: TextStyle(
                      color: statusColor.withOpacity(0.8),
                      fontSize: isMobile ? 10 : 12,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  // UPDATED QUICK SUMMARY CARD WITH RESPONSIVE DESIGN
  Widget _buildQuickSummary(bool isMobile) {
    final isReimbursement =
        widget.requestType.toLowerCase().contains('reimbursement');
    final projectInfo = _getProjectInfo();

    return _buildDetailCard(
      'Quick Summary',
      Icons.description,
      [
        _buildSummaryItem('Request Type', widget.requestType.toUpperCase(),
            Icons.category, Colors.purple, isMobile),
        _buildSummaryItem(
            'Employee',
            widget.getRequestData('employeeName') ?? 'Unknown',
            Icons.person,
            Colors.blue,
            isMobile),
        _buildSummaryItem(
            'Amount',
            '₹${_formatAmount(widget.getRequestData('amount'))}',
            Icons.attach_money,
            Colors.green,
            isMobile),
        if (projectInfo['id'] != null)
          _buildSummaryItem('Project Code', projectInfo['id']!, Icons.code,
              Colors.orange, isMobile),
        if (projectInfo['name'] != null)
          _buildSummaryItem('Project Name', projectInfo['name']!,
              Icons.business, Colors.teal, isMobile),
        if (isReimbursement &&
            widget.getRequestData('reimbursement_date') != null)
          _buildSummaryItem(
              'Reimbursement Date',
              DateFormatter.formatBackendDate(
                  widget.getRequestData('reimbursement_date')),
              Icons.calendar_today,
              Colors.teal,
              isMobile),
      ],
      isMobile: isMobile,
    );
  }

  Widget _buildSummaryItem(
      String label, String value, IconData icon, Color color, bool isMobile) {
    return Container(
      padding: EdgeInsets.symmetric(vertical: isMobile ? 8 : 12),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(color: Colors.grey[800]!, width: 0.5),
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: color.withOpacity(0.2),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, size: isMobile ? 16 : 18, color: color),
          ),
          SizedBox(width: isMobile ? 8 : 12),
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                color: Colors.grey[400],
                fontSize: isMobile ? 12 : 14,
              ),
            ),
          ),
          Text(
            value,
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.w600,
              fontSize: isMobile ? 12 : 14,
            ),
          ),
        ],
      ),
    );
  }

  // ENHANCED PAYMENT BREAKDOWN CARD WITH ATTACHMENTS AND RESPONSIVE DESIGN
  Widget _buildPaymentBreakdown(bool isMobile) {
    final paymentsData = widget.getRequestData('payments');

    return _buildDetailCard(
      'Payment Breakdown',
      Icons.payment,
      [
        if (paymentsData != null &&
            (paymentsData is List && paymentsData.isNotEmpty ||
                paymentsData is Map))
          ..._buildPaymentItemsList(isMobile)
        else
          Center(
            child: Padding(
              padding: EdgeInsets.all(isMobile ? 12.0 : 16.0),
              child: Text(
                'No payment details available',
                style: TextStyle(color: Colors.white70),
              ),
            ),
          ),
      ],
      isMobile: isMobile,
    );
  }

  List<Widget> _buildPaymentItemsList(bool isMobile) {
    final paymentsData = widget.getRequestData('payments');
    List<dynamic> payments = [];

    // Convert payments to list
    if (paymentsData is List) {
      payments = paymentsData;
    } else if (paymentsData is Map) {
      payments = [paymentsData];
    }

    return payments.asMap().entries.map((entry) {
      final index = entry.key;
      final payment = entry.value;
      return _buildPaymentItemWithAttachments(payment, index, isMobile);
    }).toList();
  }

  // UPDATED PAYMENT ITEM WITH ATTACHMENTS INCLUDED AND RESPONSIVE DESIGN
  Widget _buildPaymentItemWithAttachments(
      dynamic payment, int index, bool isMobile) {
    Map<String, dynamic> paymentData = {};
    if (payment is Map<String, dynamic>) {
      paymentData = payment;
    } else if (payment is String) {
      try {
        paymentData = json.decode(payment);
      } catch (e) {
        paymentData = {'amount': 0, 'description': 'Invalid payment data'};
      }
    }

    final amount = paymentData['amount'] ?? 0;
    final parsedAmount = _parseAmount(amount);
    final description = paymentData['description'] ??
        paymentData['particulars'] ??
        'No description';
    final claimType = paymentData['claimType'] ?? 'Not specified';
    final paymentDate = paymentData['date'] ?? paymentData['paymentDate'];
    final requestDate = paymentData['requestDate'];
    final projectDate = paymentData['projectDate'];
    final attachmentPaths = _getAttachmentPaths(paymentData);

    return Container(
      margin: EdgeInsets.only(top: index > 0 ? (isMobile ? 12 : 16) : 0),
      decoration: BoxDecoration(
        color: const Color(0xFF252525),
        borderRadius: BorderRadius.circular(isMobile ? 8 : 12),
        border: Border.all(color: Colors.grey[700]!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Payment header and basic info
          Padding(
            padding: EdgeInsets.all(isMobile ? 12 : 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            color: Colors.green.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            '${index + 1}',
                            style: TextStyle(
                              color: Colors.green,
                              fontWeight: FontWeight.bold,
                              fontSize: isMobile ? 10 : 12,
                            ),
                          ),
                        ),
                        SizedBox(width: isMobile ? 8 : 12),
                        Text(
                          'Payment Entry',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w600,
                            fontSize: isMobile ? 13 : 14,
                          ),
                        ),
                      ],
                    ),
                    Text(
                      '₹${parsedAmount.toStringAsFixed(2)}',
                      style: TextStyle(
                        color: Colors.green,
                        fontWeight: FontWeight.bold,
                        fontSize: isMobile ? 14 : 16,
                      ),
                    ),
                  ],
                ),
                SizedBox(height: isMobile ? 8 : 12),

                // Payment details in a structured way
                _buildPaymentDetailRow('Description:', description, isMobile),
                if (claimType != 'Not specified')
                  _buildPaymentDetailRow('Claim Type:', claimType, isMobile),
                if (paymentDate != null)
                  _buildPaymentDetailRow(
                      'Payment Date:',
                      DateFormatter.formatBackendDate(paymentDate.toString()),
                      isMobile),
                if (requestDate != null)
                  _buildPaymentDetailRow(
                      'Request Date:',
                      DateFormatter.formatBackendDate(requestDate.toString()),
                      isMobile),
                if (projectDate != null)
                  _buildPaymentDetailRow(
                      'Project Date:',
                      DateFormatter.formatBackendDate(projectDate.toString()),
                      isMobile),
              ],
            ),
          ),

          // Attachments section for this payment
          if (attachmentPaths.isNotEmpty) ...[
            Divider(color: Colors.grey, height: 1),
            Padding(
              padding: EdgeInsets.all(isMobile ? 12 : 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          color: Colors.blue.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Icon(Icons.attachment,
                            size: isMobile ? 12 : 14, color: Colors.blue),
                      ),
                      SizedBox(width: isMobile ? 6 : 8),
                      Text(
                        'Payment Attachments:',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                          fontSize: isMobile ? 13 : 14,
                        ),
                      ),
                      SizedBox(width: isMobile ? 6 : 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.blue[800],
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          '${attachmentPaths.length}',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: isMobile ? 10 : 11,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: isMobile ? 8 : 12),
                  ...attachmentPaths
                      .map((path) =>
                          _buildSingleAttachmentPreview(path, isMobile))
                      .toList(),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildPaymentDetailRow(String label, String value, bool isMobile) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: isMobile ? 2 : 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: isMobile ? 80 : 100,
            child: Text(
              label,
              style: TextStyle(
                color: Colors.grey[400],
                fontSize: isMobile ? 11 : 13,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          SizedBox(width: isMobile ? 6 : 8),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                color: Colors.white,
                fontSize: isMobile ? 11 : 13,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ENHANCED ACTION BUTTONS WITH RESPONSIVE DESIGN
  Widget _buildActionButtons(bool isMobile) {
    final status =
        widget.getRequestData('status')?.toString().toLowerCase() ?? '';

    // Don't show action buttons if already approved or rejected
    if (status.contains('approved') ||
        status.contains('rejected') ||
        status.contains('paid')) {
      return Container();
    }

    final buttonHeight = isMobile ? 45.0 : 50.0;

    return Container(
      margin: EdgeInsets.only(bottom: isMobile ? 16 : 20),
      padding: EdgeInsets.all(isMobile ? 16 : 20),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A1A),
        borderRadius: BorderRadius.circular(isMobile ? 12 : 16),
        border: Border.all(color: Colors.grey[700]!),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Colors.deepPurple.withOpacity(0.1),
            Colors.blue.withOpacity(0.1),
          ],
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.quickreply,
                  color: Colors.white, size: isMobile ? 18 : 20),
              SizedBox(width: isMobile ? 6 : 8),
              Text(
                'CEO Actions',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: isMobile ? 15 : 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          SizedBox(height: isMobile ? 12 : 16),
          Text(
            'Review and take action on this request:',
            style: TextStyle(
              color: Colors.white70,
              fontSize: isMobile ? 13 : 14,
            ),
          ),
          SizedBox(height: isMobile ? 12 : 16),
          if (isMobile)
            Column(
              children: [
                SizedBox(
                  width: double.infinity,
                  height: buttonHeight,
                  child: _buildActionButton(
                    'Approve',
                    Icons.check_circle,
                    Colors.green,
                    _isProcessing ? null : _approveRequest,
                    isMobile,
                  ),
                ),
                SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  height: buttonHeight,
                  child: _buildActionButton(
                    'Reject',
                    Icons.cancel,
                    Colors.redAccent,
                    _isProcessing ? null : _showRejectDialog,
                    isMobile,
                  ),
                ),
              ],
            )
          else
            Row(
              children: [
                Expanded(
                  child: SizedBox(
                    height: buttonHeight,
                    child: _buildActionButton(
                      'Approve',
                      Icons.check_circle,
                      Colors.green,
                      _isProcessing ? null : _approveRequest,
                      isMobile,
                    ),
                  ),
                ),
                SizedBox(width: 12),
                Expanded(
                  child: SizedBox(
                    height: buttonHeight,
                    child: _buildActionButton(
                      'Reject',
                      Icons.cancel,
                      Colors.redAccent,
                      _isProcessing ? null : _showRejectDialog,
                      isMobile,
                    ),
                  ),
                ),
              ],
            ),
          if (_isProcessing) ...[
            SizedBox(height: isMobile ? 12 : 16),
            Center(
              child: Column(
                children: [
                  CircularProgressIndicator(color: Colors.tealAccent),
                  SizedBox(height: 8),
                  Text(
                    'Processing your request...',
                    style: TextStyle(color: Colors.white70),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildActionButton(String text, IconData icon, Color color,
      VoidCallback? onPressed, bool isMobile) {
    return ElevatedButton.icon(
      onPressed: onPressed,
      style: ElevatedButton.styleFrom(
        backgroundColor: color.withOpacity(0.9),
        foregroundColor: Colors.white,
        padding:
            EdgeInsets.symmetric(vertical: isMobile ? 14 : 16, horizontal: 8),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(isMobile ? 10 : 12),
        ),
        elevation: 2,
      ),
      icon: Icon(icon, size: isMobile ? 18 : 20),
      label: Text(
        text,
        style: TextStyle(
          fontWeight: FontWeight.w600,
          fontSize: isMobile ? 13 : 14,
        ),
      ),
    );
  }

  // APPROVE/REJECT METHODS - UPDATED URLs
  Future<void> _approveRequest() async {
    setState(() => _isProcessing = true);

    try {
      final response = await http.post(
        Uri.parse('$baseUrl/api/ceo/approve-request/'),
        headers: {
          'Authorization': 'Token ${widget.authToken}',
          'Content-Type': 'application/json',
        },
        body: json.encode({
          'request_id': widget.requestId,
          'request_type': widget.requestType,
        }),
      );

      setState(() => _isProcessing = false);

      if (response.statusCode == 200) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Request Approved by CEO'),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.pop(context, true);
      } else {
        final errorData = json.decode(response.body);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
                'Failed to approve request: ${errorData['error'] ?? 'Unknown error'}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      setState(() => _isProcessing = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _showRejectDialog() {
    final TextEditingController reasonController = TextEditingController();
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E1E),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Icon(Icons.warning_amber, color: Colors.orange),
            SizedBox(width: 8),
            Text('Reject Request', style: TextStyle(color: Colors.white)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Please provide a reason for rejection:',
              style: TextStyle(color: Colors.white70),
            ),
            SizedBox(height: 16),
            TextField(
              controller: reasonController,
              style: TextStyle(color: Colors.white),
              decoration: InputDecoration(
                hintText: 'Enter rejection reason...',
                hintStyle: TextStyle(color: Colors.white54),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(color: Colors.redAccent),
                ),
              ),
              maxLines: 3,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancel', style: TextStyle(color: Colors.white70)),
          ),
          ElevatedButton(
            onPressed: () {
              final reason = reasonController.text.trim();
              if (reason.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Please enter a rejection reason'),
                    backgroundColor: Colors.orange,
                  ),
                );
                return;
              }
              Navigator.pop(context);
              _ceoRejectRequest(reason);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.redAccent,
              foregroundColor: Colors.white,
            ),
            child: Text('Reject'),
          ),
        ],
      ),
    );
  }

  Future<void> _ceoRejectRequest(String reason) async {
    setState(() => _isProcessing = true);

    try {
      final response = await http.post(
        Uri.parse('$baseUrl/api/ceo/reject-request/'),
        headers: {
          'Authorization': 'Token ${widget.authToken}',
          'Content-Type': 'application/json',
        },
        body: json.encode({
          'request_id': widget.requestId,
          'request_type': widget.requestType,
          'reason': reason,
        }),
      );

      setState(() => _isProcessing = false);

      if (response.statusCode == 200) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Request Rejected by CEO'),
            backgroundColor: Colors.red,
          ),
        );
        Navigator.pop(context, true);
      } else {
        final errorData = json.decode(response.body);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
                'Failed to reject request: ${errorData['error'] ?? 'Unknown error'}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      setState(() => _isProcessing = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  // ENHANCED PROJECT INFORMATION SECTION WITH RESPONSIVE DESIGN
  Widget _buildProjectInformation(bool isMobile) {
    final projectInfo = _getProjectInfo();

    // Only show if we have at least one piece of project information
    if (projectInfo.isEmpty) {
      return Container();
    }

    List<Widget> projectDetails = [];

    if (projectInfo['id'] != null) {
      projectDetails.add(_detailItem('Project Code', projectInfo['id']!,
          isImportant: true, isMobile: isMobile));
    }

    if (projectInfo['name'] != null) {
      projectDetails.add(_detailItem('Project Name', projectInfo['name']!,
          isMobile: isMobile));
    }

    return _buildDetailCard(
      'Project Information',
      Icons.business_center,
      projectDetails,
      headerColor: Colors.orange,
      isMobile: isMobile,
    );
  }

  // REIMBURSEMENT SPECIFIC DETAILS WITH RESPONSIVE DESIGN
  Widget _buildReimbursementDetails(bool isMobile) {
    final isReimbursement =
        widget.requestType.toLowerCase().contains('reimbursement');
    if (!isReimbursement) return Container();

    List<Widget> reimbursementDetails = [];

    if (widget.getRequestData('reimbursement_date') != null)
      reimbursementDetails.add(_detailItemWithDate(
          'Reimbursement Date', widget.getRequestData('reimbursement_date'),
          isImportant: true, isMobile: isMobile));

    if (widget.getRequestData('payment_date') != null)
      reimbursementDetails.add(_detailItemWithDate(
          'Payment Date', widget.getRequestData('payment_date'),
          isMobile: isMobile));

    return reimbursementDetails.isNotEmpty
        ? _buildDetailCard(
            'Reimbursement Details',
            Icons.receipt_long,
            reimbursementDetails,
            headerColor: Colors.green,
            isMobile: isMobile,
          )
        : Container();
  }

  // ADVANCE SPECIFIC DETAILS WITH RESPONSIVE DESIGN
  Widget _buildAdvanceDetails(bool isMobile) {
    final isAdvance = widget.requestType.toLowerCase().contains('advance');
    if (!isAdvance) return Container();

    List<Widget> advanceDetails = [];

    if (widget.getRequestData('request_date') != null)
      advanceDetails.add(_detailItemWithDate(
          'Request Date', widget.getRequestData('request_date'),
          isImportant: true, isMobile: isMobile));

    if (widget.getRequestData('project_date') != null)
      advanceDetails.add(_detailItemWithDate(
          'Project Date', widget.getRequestData('project_date'),
          isMobile: isMobile));

    if (widget.getRequestData('payment_date') != null)
      advanceDetails.add(_detailItemWithDate(
          'Payment Date', widget.getRequestData('payment_date'),
          isMobile: isMobile));

    return advanceDetails.isNotEmpty
        ? _buildDetailCard(
            'Advance Details',
            Icons.forward,
            advanceDetails,
            headerColor: Colors.purple,
            isMobile: isMobile,
          )
        : Container();
  }

  // APPROVAL HISTORY SECTION WITH RESPONSIVE DESIGN
  Widget _buildApprovalHistory(bool isMobile) {
    final approvedBy = widget.getRequestData('approved_by');
    final approvalDate = widget.getRequestData('approval_date');

    if (approvedBy == null && approvalDate == null) {
      return Container();
    }

    List<Widget> approvalDetails = [];

    if (approvedBy != null)
      approvalDetails.add(_detailItem('Approved By', approvedBy.toString(),
          isImportant: true, isMobile: isMobile));

    if (approvalDate != null)
      approvalDetails.add(_detailItemWithDate('Approval Date', approvalDate,
          isMobile: isMobile));

    return _buildDetailCard(
      'Approval History',
      Icons.verified_user,
      approvalDetails,
      headerColor: Colors.blue,
      isMobile: isMobile,
    );
  }

  // REJECTION DETAILS SECTION WITH RESPONSIVE DESIGN
  Widget _buildRejectionDetails(bool isMobile) {
    final rejectionReason = widget.getRequestData('rejection_reason');

    if (rejectionReason == null || rejectionReason.toString().isEmpty) {
      return Container();
    }

    return _buildDetailCard(
      'Rejection Details',
      Icons.warning,
      [
        _detailItem(
          'Rejection Reason',
          rejectionReason.toString(),
          isImportant: true,
          valueColor: Colors.red,
          isMobile: isMobile,
        ),
      ],
      headerColor: Colors.red,
      isMobile: isMobile,
    );
  }

  // MAIN BUILD METHOD - COMPLETELY UPDATED WITH RESPONSIVE DESIGN
  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isMobile = screenWidth < 600;
    final isTablet = screenWidth >= 600 && screenWidth < 1024;
    final isDesktop = screenWidth >= 1024;

    // Responsive padding
    final double contentPadding = isMobile
        ? 12.0
        : isTablet
            ? 16.0
            : 20.0;

    return Scaffold(
      backgroundColor: const Color(0xFF121212),
      appBar: AppBar(
        title: Text(
          '${capitalizeRequestType(widget.requestType)} Details',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: Colors.white,
            fontSize: isMobile ? 16 : 18,
          ),
        ),
        backgroundColor: const Color(0xFF1A1A1A),
        iconTheme: const IconThemeData(color: Colors.white),
        elevation: 0,
        actions: [
          IconButton(
            icon: Icon(Icons.info_outline,
                color: Colors.white, size: isMobile ? 20 : 24),
            onPressed: () {
              final projectInfo = _getProjectInfo();
              showDialog(
                context: context,
                builder: (_) => AlertDialog(
                  backgroundColor: const Color(0xFF1E1E1E),
                  title: Text('Request Information',
                      style: TextStyle(color: Colors.white)),
                  content: Text(
                    'Request ID: ${widget.requestId}\n'
                    'Type: ${capitalizeRequestType(widget.requestType)}\n'
                    'Status: ${widget.getRequestData('status') ?? 'Unknown'}\n'
                    'Total Amount: ₹${_formatAmount(widget.getRequestData('amount'))}\n'
                    'Project Code: ${projectInfo['id'] ?? 'Not specified'}\n'
                    'Project Name: ${projectInfo['name'] ?? 'Not specified'}',
                    style: TextStyle(color: Colors.white70),
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child:
                          Text('Close', style: TextStyle(color: Colors.white)),
                    ),
                  ],
                ),
              );
            },
          ),
        ],
      ),
      body: _isProcessing
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(color: Colors.tealAccent),
                  SizedBox(height: 16),
                  Text(
                    'Processing...',
                    style: TextStyle(color: Colors.white70),
                  ),
                ],
              ),
            )
          : SingleChildScrollView(
              padding: EdgeInsets.all(contentPadding),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Enhanced Status Badge
                  _buildStatusBadge(isMobile),

                  // Quick Summary (now includes project code and name)
                  _buildQuickSummary(isMobile),

                  // 1. BASIC INFORMATION
                  _buildDetailCard(
                    'Basic Information',
                    Icons.person,
                    [
                      _detailItem('Employee Name',
                          widget.getRequestData('employeeName') ?? 'Unknown',
                          isImportant: true, isMobile: isMobile),
                      _detailItem('Employee ID',
                          widget.getRequestData('employeeId') ?? 'Unknown',
                          isMobile: isMobile),
                      _detailItemWithDate(
                          'Submission Date',
                          widget.getRequestData('submitted_date') ??
                              widget.getRequestData('date'),
                          isMobile: isMobile),
                      _detailItem(
                          'Request Type',
                          capitalizeRequestType(widget.requestType)
                              .toUpperCase(),
                          isImportant: true,
                          isMobile: isMobile),
                      _detailItem('Total Amount',
                          '₹${_formatAmount(widget.getRequestData('amount'))}',
                          isImportant: true, isMobile: isMobile),
                    ],
                    isMobile: isMobile,
                  ),

                  // 2. PROJECT INFORMATION (ENHANCED) - NOW SHOWS BOTH CODE AND NAME
                  _buildProjectInformation(isMobile),

                  // 3. TYPE-SPECIFIC DETAILS
                  _buildReimbursementDetails(isMobile),
                  _buildAdvanceDetails(isMobile),

                  // 4. PAYMENT BREAKDOWN WITH ATTACHMENTS (ATTACHMENTS SHOWN PER PAYMENT)
                  _buildPaymentBreakdown(isMobile),

                  // 5. APPROVAL INFORMATION
                  _buildApprovalHistory(isMobile),

                  // 6. REJECTION INFORMATION
                  _buildRejectionDetails(isMobile),

                  // 7. ACTION BUTTONS
                  _buildActionButtons(isMobile),

                  SizedBox(height: isMobile ? 16 : 20),
                ],
              ),
            ),
    );
  }
}
