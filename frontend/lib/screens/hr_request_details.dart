import 'dart:io';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:open_file/open_file.dart';
import '../services/api_service.dart';
import 'common_dashboard.dart';

class HrRequestDetails extends StatefulWidget {
  final Request request;
  final String authToken;

  const HrRequestDetails({
    super.key,
    required this.request,
    required this.authToken,
  });

  @override
  State<HrRequestDetails> createState() => _HrRequestDetailsState();
}

class _HrRequestDetailsState extends State<HrRequestDetails> {
  final ApiService apiService = ApiService();
  bool _isProcessing = false;
  final Map<String, bool> _downloadingFiles = {};

  // Helper methods for attachments
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

  // Get all attachment paths from a payment
  List<String> _getAttachmentPaths(Map<String, dynamic> payment) {
    final List<String> paths = [];

    // Check for multiple attachmentPaths
    if (payment["attachmentPaths"] is List) {
      for (var path in payment["attachmentPaths"] ?? []) {
        if (path != null && path.toString().isNotEmpty) {
          paths.add(path.toString());
        }
      }
    }
    // Fallback to single attachmentPath
    else if (payment["attachmentPath"] is String &&
        payment["attachmentPath"].toString().isNotEmpty) {
      paths.add(payment["attachmentPath"].toString());
    }

    return paths;
  }

  // Fix: Convert relative paths to full URLs
  String _getFullFilePath(String path) {
    if (path.startsWith('http')) {
      return path;
    } else if (path.startsWith('advance_attachments/') ||
        path.startsWith('reimbursement_attachments/')) {
      // Convert relative path to full URL
      return 'http://10.0.2.2:8000/media/$path';
    } else if (path.startsWith('media/')) {
      return 'http://10.0.2.2:8000/$path';
    }
    return path;
  }

  void _showImageDialog(String imagePath) {
    final fullPath = _getFullFilePath(imagePath);

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
                child: fullPath.startsWith('http')
                    ? Image.network(fullPath, fit: BoxFit.contain)
                    : Image.file(File(fullPath), fit: BoxFit.contain),
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
                onPressed: () => _downloadOnly(fullPath),
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
      final fullPath = _getFullFilePath(filePath);

      setState(() {
        _downloadingFiles[fullPath] = true;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Opening ${_getFileName(fullPath)}...'),
          backgroundColor: const Color(0xFF1A237E),
          duration: const Duration(seconds: 2),
        ),
      );

      String localPath;
      if (fullPath.startsWith('http')) {
        // Download from network
        final response = await http.get(Uri.parse(fullPath));
        final tempDir = await getTemporaryDirectory();
        final fileName = _getFileName(fullPath);
        localPath = '${tempDir.path}/$fileName';

        final file = File(localPath);
        await file.writeAsBytes(response.bodyBytes);
      } else {
        localPath = fullPath;
      }

      setState(() {
        _downloadingFiles[fullPath] = false;
      });

      // Open with system default app
      final result = await OpenFile.open(localPath);
      _handleOpenFileResult(result, filePath);
    } catch (e) {
      setState(() {
        _downloadingFiles[filePath] = false;
      });
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
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('File opened successfully'),
            backgroundColor: Color(0xFF1E8C3E),
          ),
        );
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

  Future<void> _downloadOnly(String filePath) async {
    try {
      final fullPath = _getFullFilePath(filePath);

      if (_downloadingFiles[fullPath] == true) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Already downloading this file'),
            backgroundColor: Colors.orange,
          ),
        );
        return;
      }

      setState(() {
        _downloadingFiles[fullPath] = true;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Downloading ${_getFileName(fullPath)}...'),
          backgroundColor: const Color(0xFF1A237E),
          duration: const Duration(seconds: 2),
        ),
      );

      String downloadedPath;

      if (fullPath.startsWith('http')) {
        // Download from network
        final response = await http.get(Uri.parse(fullPath));

        // Get downloads directory
        final directory = await getExternalStorageDirectory();
        if (directory == null) {
          throw Exception('Could not access downloads directory');
        }

        final fileName = _getFileName(fullPath);
        final downloadDir = Directory('${directory.path}/Xpensure_Downloads');
        if (!await downloadDir.exists()) {
          await downloadDir.create(recursive: true);
        }

        final file = File('${downloadDir.path}/$fileName');
        await file.writeAsBytes(response.bodyBytes);
        downloadedPath = file.path;
      } else {
        // For local files
        final originalFile = File(fullPath);
        final directory = await getExternalStorageDirectory();
        if (directory == null) {
          throw Exception('Could not access downloads directory');
        }

        final fileName = _getFileName(fullPath);
        final downloadDir = Directory('${directory.path}/Xpensure_Downloads');
        if (!await downloadDir.exists()) {
          await downloadDir.create(recursive: true);
        }

        final newFile = File('${downloadDir.path}/$fileName');
        await originalFile.copy(newFile.path);
        downloadedPath = newFile.path;
      }

      setState(() {
        _downloadingFiles[fullPath] = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('File downloaded successfully!'),
              Text(
                'Saved to: Xpensure_Downloads/${_getFileName(downloadedPath)}',
                style: const TextStyle(fontSize: 12, color: Colors.white70),
              ),
            ],
          ),
          backgroundColor: const Color(0xFF1E8C3E),
          duration: const Duration(seconds: 4),
          action: SnackBarAction(
            label: 'OPEN',
            textColor: Colors.white,
            onPressed: () => _openFileWithDialog(fullPath),
          ),
        ),
      );
    } catch (e) {
      print('Error downloading file: $e');
      setState(() {
        _downloadingFiles[filePath] = false;
      });
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
      final fullPath = _getFullFilePath(filePath);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Preparing ${_getFileName(fullPath)} for sharing...'),
          backgroundColor: const Color(0xFF1A237E),
          duration: const Duration(seconds: 2),
        ),
      );

      String localPath;
      if (fullPath.startsWith('http')) {
        // Download to temp directory first
        final response = await http.get(Uri.parse(fullPath));
        final tempDir = await getTemporaryDirectory();
        final fileName = _getFileName(fullPath);
        localPath = '${tempDir.path}/$fileName';

        final file = File(localPath);
        await file.writeAsBytes(response.bodyBytes);
      } else {
        localPath = fullPath;
      }

      final file = File(localPath);
      if (await file.exists()) {
        await Share.shareXFiles(
          [XFile(localPath)],
          text: 'Check out this file: ${_getFileName(fullPath)}',
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

  Widget _buildFileActions(String filePath) {
    final fullPath = _getFullFilePath(filePath);
    final isImage = _isImageFile(fullPath);
    final isDownloading = _downloadingFiles[fullPath] == true;

    if (isImage) {
      return Row(
        children: [
          Expanded(
            child: ElevatedButton.icon(
              onPressed: () => _showImageDialog(fullPath),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF7B1FA2),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 10),
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
              onPressed: () => _openFileWithDialog(fullPath),
              style: OutlinedButton.styleFrom(
                foregroundColor: const Color(0xFF1976D2),
                side: const BorderSide(color: Color(0xFF1976D2)),
                padding: const EdgeInsets.symmetric(vertical: 10),
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
              onPressed: isDownloading ? null : () => _downloadOnly(fullPath),
              style: OutlinedButton.styleFrom(
                foregroundColor: const Color(0xFF388E3C),
                side: const BorderSide(color: Color(0xFF388E3C)),
                padding: const EdgeInsets.symmetric(vertical: 10),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              icon: isDownloading
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Color(0xFF388E3C),
                      ),
                    )
                  : const Icon(Icons.download, size: 18),
              label: Text(isDownloading ? 'Downloading...' : 'Download'),
            ),
          ),
        ],
      );
    } else {
      return Row(
        children: [
          Expanded(
            child: ElevatedButton.icon(
              onPressed: () => _openFileWithDialog(fullPath),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFC62828),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 10),
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
              onPressed: isDownloading ? null : () => _downloadOnly(fullPath),
              style: OutlinedButton.styleFrom(
                foregroundColor: const Color(0xFF1976D2),
                side: const BorderSide(color: Color(0xFF1976D2)),
                padding: const EdgeInsets.symmetric(vertical: 10),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              icon: isDownloading
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Color(0xFF1976D2),
                      ),
                    )
                  : const Icon(Icons.download, size: 18),
              label: Text(isDownloading ? 'Downloading...' : 'Download'),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: OutlinedButton.icon(
              onPressed: () => _shareFile(fullPath),
              style: OutlinedButton.styleFrom(
                foregroundColor: const Color(0xFF388E3C),
                side: const BorderSide(color: Color(0xFF388E3C)),
                padding: const EdgeInsets.symmetric(vertical: 10),
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

  Widget _buildSingleAttachmentPreview(String attachmentPath) {
    final fullPath = _getFullFilePath(attachmentPath);
    final isImage = _isImageFile(fullPath);

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8),
      color: const Color(0xFF0D0D0D),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.grey[800]!, width: 1),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  _getFileIcon(fullPath),
                  color: _getFileIconColor(fullPath),
                  size: 24,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _getFileName(fullPath),
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w500,
                        ),
                        overflow: TextOverflow.ellipsis,
                        maxLines: 1,
                      ),
                      Text(
                        _getFileExtension(fullPath).toUpperCase(),
                        style: TextStyle(
                          color: Colors.grey[400],
                          fontSize: 12,
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
                height: 150,
                width: double.infinity,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.grey[700]!),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: fullPath.startsWith('http')
                      ? Image.network(
                          fullPath,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) {
                            return Container(
                              color: Colors.grey[800],
                              child: const Icon(
                                Icons.broken_image,
                                color: Colors.grey,
                                size: 40,
                              ),
                            );
                          },
                        )
                      : Image.file(
                          File(fullPath),
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) {
                            return Container(
                              color: Colors.grey[800],
                              child: const Icon(
                                Icons.broken_image,
                                color: Colors.grey,
                                size: 40,
                              ),
                            );
                          },
                        ),
                ),
              ),
            if (isImage) const SizedBox(height: 12),
            _buildFileActions(attachmentPath),
          ],
        ),
      ),
    );
  }

  Widget _buildAttachmentsSection(List<String> attachmentPaths) {
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
        const Text(
          'Attachments:',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 16,
          ),
        ),
        const SizedBox(height: 8),
        ...attachmentPaths
            .map((path) => _buildSingleAttachmentPreview(path))
            .toList(),
      ],
    );
  }

  void _approveRequest() async {
    setState(() => _isProcessing = true);

    final success = await apiService.approveRequest(
      authToken: widget.authToken,
      requestId: widget.request.id,
      requestType: widget.request.requestType.toLowerCase(),
    );

    setState(() => _isProcessing = false);

    if (success) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Request Approved Successfully'),
          backgroundColor: const Color(0xFF1E8C3E),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
        ),
      );
      Navigator.pop(context, true);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Failed to approve request'),
          backgroundColor: const Color(0xFFB71C1C),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
        ),
      );
    }
  }

  void _rejectRequest() {
    final TextEditingController reasonController = TextEditingController();
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: const Color(0xFF0D0D0D),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: Colors.grey[800]!, width: 1),
        ),
        title: Row(
          children: [
            Icon(Icons.warning_amber, color: Colors.orange[700]),
            const SizedBox(width: 8),
            const Text('Reject Request',
                style: TextStyle(
                    color: Colors.white, fontWeight: FontWeight.bold)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Please provide a reason for rejection:',
              style: TextStyle(color: Colors.grey),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: reasonController,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                hintText: 'Enter rejection reason...',
                hintStyle: const TextStyle(color: Colors.grey),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(color: Colors.grey[700]!),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(color: Colors.grey[700]!),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: const BorderSide(color: Colors.redAccent),
                ),
                filled: true,
                fillColor: const Color(0xFF1A1A1A),
              ),
              maxLines: 3,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            style: TextButton.styleFrom(
              foregroundColor: Colors.grey,
            ),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
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
              setState(() => _isProcessing = true);

              final success = await apiService.rejectRequest(
                authToken: widget.authToken,
                requestId: widget.request.id,
                requestType: widget.request.requestType.toLowerCase(),
                reason: reason,
              );

              setState(() => _isProcessing = false);

              if (success) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: const Text('Request Rejected'),
                    backgroundColor: const Color(0xFFB71C1C),
                    behavior: SnackBarBehavior.floating,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                );
                Navigator.pop(context, true);
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFC62828),
              foregroundColor: Colors.white,
            ),
            child: const Text('Reject'),
          ),
        ],
      ),
    );
  }

  // Helper method to safely format amount
  String _formatAmount(dynamic amount) {
    try {
      if (amount == null) return '0.00';

      if (amount is String) {
        final parsed = double.tryParse(amount) ?? 0.0;
        return parsed.toStringAsFixed(2);
      } else if (amount is int) {
        return amount.toDouble().toStringAsFixed(2);
      } else if (amount is double) {
        return amount.toStringAsFixed(2);
      }
      return '0.00';
    } catch (e) {
      return '0.00';
    }
  }

  // Helper method to format date for display
  String _formatDateForDisplay(String dateString) {
    if (dateString.isEmpty) return 'Not specified';

    try {
      DateTime date;
      if (dateString.contains('T')) {
        date = DateTime.parse(dateString);
      } else {
        final parts = dateString.split('-');
        if (parts.length >= 3) {
          date = DateTime(
              int.parse(parts[0]), int.parse(parts[1]), int.parse(parts[2]));
        } else {
          return dateString;
        }
      }

      return '${date.day}/${date.month}/${date.year}';
    } catch (e) {
      return dateString;
    }
  }

  // Helper method to get field value with multiple possible keys
  String? _getFieldValue(Map<String, dynamic> data, List<String> possibleKeys) {
    for (String key in possibleKeys) {
      if (data[key] != null && data[key].toString().isNotEmpty) {
        return data[key].toString();
      }
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final request = widget.request;
    final screenWidth = MediaQuery.of(context).size.width;
    final isMobile = screenWidth < 600;
    final isTablet = screenWidth >= 600 && screenWidth < 1024;
    final isDesktop = screenWidth >= 1024;

    // Responsive sizing
    final double cardPadding = isMobile
        ? 12.0
        : isTablet
            ? 16.0
            : 20.0;
    final double buttonHeight = isMobile
        ? 45.0
        : isTablet
            ? 50.0
            : 55.0;

    return Scaffold(
      backgroundColor: const Color(0xFF121212),
      appBar: AppBar(
        title: const Text(
          'HR Request Details',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        backgroundColor: const Color(0xFF0D0D0D),
        iconTheme: const IconThemeData(color: Colors.white),
        elevation: 0,
      ),
      body: _isProcessing
          ? const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(color: Color(0xFF00E5FF)),
                  SizedBox(height: 16),
                  Text(
                    'Processing...',
                    style: TextStyle(color: Colors.grey),
                  ),
                ],
              ),
            )
          : SingleChildScrollView(
              padding: EdgeInsets.all(isMobile ? 12.0 : 16.0),
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  minHeight: MediaQuery.of(context).size.height,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Request Overview Card
                    Card(
                      margin: const EdgeInsets.only(bottom: 16),
                      color: const Color(0xFF0D0D0D),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                        side: BorderSide(color: Colors.grey[800]!, width: 1),
                      ),
                      elevation: 4,
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Request Overview',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 12),
                            Padding(
                              padding: const EdgeInsets.symmetric(vertical: 6),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  SizedBox(
                                    width: 140,
                                    child: Text(
                                      'Employee:',
                                      style: TextStyle(
                                        color: Colors.grey[400],
                                        fontWeight: FontWeight.w500,
                                        fontSize: 14,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      request.employeeName,
                                      style: const TextStyle(
                                        color: Color(0xFF00E5FF),
                                        fontWeight: FontWeight.bold,
                                        fontSize: 14,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Padding(
                              padding: const EdgeInsets.symmetric(vertical: 6),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  SizedBox(
                                    width: 140,
                                    child: Text(
                                      'Employee ID:',
                                      style: TextStyle(
                                        color: Colors.grey[400],
                                        fontWeight: FontWeight.w500,
                                        fontSize: 14,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      request.employeeId,
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 14,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Padding(
                              padding: const EdgeInsets.symmetric(vertical: 6),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  SizedBox(
                                    width: 140,
                                    child: Text(
                                      'Date:',
                                      style: TextStyle(
                                        color: Colors.grey[400],
                                        fontWeight: FontWeight.w500,
                                        fontSize: 14,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      request.submissionDate,
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 14,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Padding(
                              padding: const EdgeInsets.symmetric(vertical: 6),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  SizedBox(
                                    width: 140,
                                    child: Text(
                                      'Total Amount:',
                                      style: TextStyle(
                                        color: Colors.grey[400],
                                        fontWeight: FontWeight.w500,
                                        fontSize: 14,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      '₹${_formatAmount(request.amount)}',
                                      style: const TextStyle(
                                        color: Color(0xFF00E5FF),
                                        fontWeight: FontWeight.bold,
                                        fontSize: 14,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                    // Payment Details Card - Show only specific fields
                    Card(
                      margin: const EdgeInsets.only(bottom: 16),
                      color: const Color(0xFF0D0D0D),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                        side: BorderSide(color: Colors.grey[800]!, width: 1),
                      ),
                      elevation: 4,
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Payment Details',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 12),
                            if (request.payments.isNotEmpty)
                              ...request.payments.asMap().entries.map((entry) {
                                final index = entry.key;
                                final payment = entry.value;
                                final attachmentPaths =
                                    _getAttachmentPaths(payment);

                                return Container(
                                  margin:
                                      EdgeInsets.only(top: index > 0 ? 12 : 0),
                                  padding: EdgeInsets.all(cardPadding),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF1A1A1A),
                                    borderRadius: BorderRadius.circular(8),
                                    border:
                                        Border.all(color: Colors.grey[800]!),
                                  ),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'Payment ${index + 1}',
                                        style: const TextStyle(
                                          color: Color(0xFF00E5FF),
                                          fontWeight: FontWeight.bold,
                                          fontSize: 16,
                                        ),
                                      ),
                                      const SizedBox(height: 8),

                                      // Show only specific fields
                                      // 1. Project ID
                                      if (_getFieldValue(payment,
                                              ['projectId', 'project_id']) !=
                                          null)
                                        Padding(
                                          padding: const EdgeInsets.symmetric(
                                              vertical: 6),
                                          child: Row(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              SizedBox(
                                                width: 140,
                                                child: Text(
                                                  'Project ID:',
                                                  style: TextStyle(
                                                    color: Colors.grey[400],
                                                    fontWeight: FontWeight.w500,
                                                    fontSize: 14,
                                                  ),
                                                ),
                                              ),
                                              const SizedBox(width: 8),
                                              Expanded(
                                                child: Text(
                                                  _getFieldValue(payment, [
                                                    'projectId',
                                                    'project_id'
                                                  ])!,
                                                  style: const TextStyle(
                                                    color: Colors.white,
                                                    fontSize: 14,
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),

                                      // 2. Project Name
                                      if (_getFieldValue(payment, [
                                            'projectName',
                                            'project_name'
                                          ]) !=
                                          null)
                                        Padding(
                                          padding: const EdgeInsets.symmetric(
                                              vertical: 6),
                                          child: Row(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              SizedBox(
                                                width: 140,
                                                child: Text(
                                                  'Project Name:',
                                                  style: TextStyle(
                                                    color: Colors.grey[400],
                                                    fontWeight: FontWeight.w500,
                                                    fontSize: 14,
                                                  ),
                                                ),
                                              ),
                                              const SizedBox(width: 8),
                                              Expanded(
                                                child: Text(
                                                  _getFieldValue(payment, [
                                                    'projectName',
                                                    'project_name'
                                                  ])!,
                                                  style: const TextStyle(
                                                    color: Colors.white,
                                                    fontSize: 14,
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),

                                      // 3. Particulars
                                      if (_getFieldValue(payment,
                                              ['particulars', 'Particulars']) !=
                                          null)
                                        Padding(
                                          padding: const EdgeInsets.symmetric(
                                              vertical: 6),
                                          child: Row(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              SizedBox(
                                                width: 140,
                                                child: Text(
                                                  'Particulars:',
                                                  style: TextStyle(
                                                    color: Colors.grey[400],
                                                    fontWeight: FontWeight.w500,
                                                    fontSize: 14,
                                                  ),
                                                ),
                                              ),
                                              const SizedBox(width: 8),
                                              Expanded(
                                                child: Text(
                                                  _getFieldValue(payment, [
                                                    'particulars',
                                                    'Particulars'
                                                  ])!,
                                                  style: const TextStyle(
                                                    color: Colors.white,
                                                    fontSize: 14,
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),

                                      // 4. Amount
                                      if (payment['amount'] != null)
                                        Padding(
                                          padding: const EdgeInsets.symmetric(
                                              vertical: 6),
                                          child: Row(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              SizedBox(
                                                width: 140,
                                                child: Text(
                                                  'Amount:',
                                                  style: TextStyle(
                                                    color: Colors.grey[400],
                                                    fontWeight: FontWeight.w500,
                                                    fontSize: 14,
                                                  ),
                                                ),
                                              ),
                                              const SizedBox(width: 8),
                                              Expanded(
                                                child: Text(
                                                  '₹${_formatAmount(payment['amount'])}',
                                                  style: const TextStyle(
                                                    color: Color(0xFF00E5FF),
                                                    fontWeight: FontWeight.bold,
                                                    fontSize: 14,
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),

                                      // 5. Request Date
                                      if (_getFieldValue(payment, [
                                            'requestDate',
                                            'request_date'
                                          ]) !=
                                          null)
                                        Padding(
                                          padding: const EdgeInsets.symmetric(
                                              vertical: 6),
                                          child: Row(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              SizedBox(
                                                width: 140,
                                                child: Text(
                                                  'Request Date:',
                                                  style: TextStyle(
                                                    color: Colors.grey[400],
                                                    fontWeight: FontWeight.w500,
                                                    fontSize: 14,
                                                  ),
                                                ),
                                              ),
                                              const SizedBox(width: 8),
                                              Expanded(
                                                child: Text(
                                                  _formatDateForDisplay(
                                                      _getFieldValue(payment, [
                                                    'requestDate',
                                                    'request_date'
                                                  ])!),
                                                  style: const TextStyle(
                                                    color: Colors.white,
                                                    fontSize: 14,
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),

                                      // 6. Project Date
                                      if (_getFieldValue(payment, [
                                            'projectDate',
                                            'project_date'
                                          ]) !=
                                          null)
                                        Padding(
                                          padding: const EdgeInsets.symmetric(
                                              vertical: 6),
                                          child: Row(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              SizedBox(
                                                width: 140,
                                                child: Text(
                                                  'Project Date:',
                                                  style: TextStyle(
                                                    color: Colors.grey[400],
                                                    fontWeight: FontWeight.w500,
                                                    fontSize: 14,
                                                  ),
                                                ),
                                              ),
                                              const SizedBox(width: 8),
                                              Expanded(
                                                child: Text(
                                                  _formatDateForDisplay(
                                                      _getFieldValue(payment, [
                                                    'projectDate',
                                                    'project_date'
                                                  ])!),
                                                  style: const TextStyle(
                                                    color: Colors.white,
                                                    fontSize: 14,
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),

                                      // Attachments section
                                      _buildAttachmentsSection(attachmentPaths),
                                    ],
                                  ),
                                );
                              }).toList()
                            else
                              const Text(
                                'No payment details available',
                                style: TextStyle(color: Colors.grey),
                              ),
                          ],
                        ),
                      ),
                    ),

                    // Action Buttons - Responsive layout
                    Card(
                      color: const Color.fromARGB(255, 24, 24, 24),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                        side: BorderSide(color: Colors.grey[800]!, width: 1),
                      ),
                      elevation: 4,
                      child: Padding(
                        padding: EdgeInsets.all(cardPadding),
                        child: Column(
                          children: [
                            const Text(
                              'HR Action',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 16),
                            if (isMobile)
                              Column(
                                children: [
                                  SizedBox(
                                    width: double.infinity,
                                    height: buttonHeight,
                                    child: ElevatedButton.icon(
                                      onPressed: _isProcessing
                                          ? null
                                          : _approveRequest,
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor:
                                            const Color(0xFF1E8C3E),
                                        foregroundColor: Colors.white,
                                        shape: RoundedRectangleBorder(
                                          borderRadius:
                                              BorderRadius.circular(8),
                                        ),
                                      ),
                                      icon: const Icon(Icons.check_circle),
                                      label: const Text(
                                        'Approve',
                                        style: TextStyle(
                                            fontWeight: FontWeight.bold),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 12),
                                  SizedBox(
                                    width: double.infinity,
                                    height: buttonHeight,
                                    child: ElevatedButton.icon(
                                      onPressed:
                                          _isProcessing ? null : _rejectRequest,
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor:
                                            const Color(0xFFC62828),
                                        foregroundColor: Colors.white,
                                        shape: RoundedRectangleBorder(
                                          borderRadius:
                                              BorderRadius.circular(8),
                                        ),
                                      ),
                                      icon: const Icon(Icons.cancel),
                                      label: const Text(
                                        'Reject',
                                        style: TextStyle(
                                            fontWeight: FontWeight.bold),
                                      ),
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
                                      child: ElevatedButton.icon(
                                        onPressed: _isProcessing
                                            ? null
                                            : _approveRequest,
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor:
                                              const Color(0xFF1E8C3E),
                                          foregroundColor: Colors.white,
                                          shape: RoundedRectangleBorder(
                                            borderRadius:
                                                BorderRadius.circular(8),
                                          ),
                                        ),
                                        icon: const Icon(Icons.check_circle),
                                        label: const Text(
                                          'Approve',
                                          style: TextStyle(
                                              fontWeight: FontWeight.bold),
                                        ),
                                      ),
                                    ),
                                  ),
                                  SizedBox(width: isTablet ? 12 : 16),
                                  Expanded(
                                    child: SizedBox(
                                      height: buttonHeight,
                                      child: ElevatedButton.icon(
                                        onPressed: _isProcessing
                                            ? null
                                            : _rejectRequest,
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor:
                                              const Color(0xFFC62828),
                                          foregroundColor: Colors.white,
                                          shape: RoundedRectangleBorder(
                                            borderRadius:
                                                BorderRadius.circular(8),
                                          ),
                                        ),
                                        icon: const Icon(Icons.cancel),
                                        label: const Text(
                                          'Reject',
                                          style: TextStyle(
                                              fontWeight: FontWeight.bold),
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            if (_isProcessing) ...[
                              const SizedBox(height: 16),
                              const CircularProgressIndicator(
                                  color: Color(0xFF00E5FF)),
                              const SizedBox(height: 8),
                              const Text(
                                'Processing your request...',
                                style: TextStyle(color: Colors.grey),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                  ],
                ),
              ),
            ),
    );
  }
}
