import 'dart:io';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:share_plus/share_plus.dart';
import 'package:open_file/open_file.dart';
import '../services/api_service.dart';
import 'common_dashboard.dart';

class ApproverRequestDetails extends StatefulWidget {
  final Request request;
  final String authToken;

  const ApproverRequestDetails({
    super.key,
    required this.request,
    required this.authToken,
  });

  @override
  State<ApproverRequestDetails> createState() => _ApproverRequestDetailsState();
}

class _ApproverRequestDetailsState extends State<ApproverRequestDetails> {
  final ApiService apiService = ApiService();
  bool _isProcessing = false;

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

// Get all attachment paths from a payment (handles local paths and URLs)
  List<String> _getAttachmentPaths(Map<String, dynamic> payment) {
    List<String> attachmentPaths = [];

    // 1. First check for multiple attachments (URLs from server)
    if (payment["attachments"] is List) {
      final attachments = List<dynamic>.from(payment["attachments"] ?? []);
      for (var attachment in attachments) {
        if (attachment is String && attachment.isNotEmpty) {
          attachmentPaths.add(attachment);
        }
      }
    }

    // 2. Check for single attachment URL from server
    if (payment["attachment"] is String &&
        payment["attachment"].toString().isNotEmpty &&
        payment["attachment"].toString().startsWith('http')) {
      final attachment = payment["attachment"].toString();
      if (!attachmentPaths.contains(attachment)) {
        attachmentPaths.add(attachment);
      }
    }

    // 3. Fallback to legacy attachmentPath field (local paths)
    else if (payment["attachmentPath"] is String &&
        payment["attachmentPath"].toString().isNotEmpty) {
      final path = payment["attachmentPath"].toString();
      // If it's a local path and starts with file:// or /data, convert to URL if possible
      if (path.startsWith('http')) {
        attachmentPaths.add(path);
      } else {
        // Local path - handle carefully
        attachmentPaths.add(path);
      }
    }

    // 4. Check for payments with multiple attachment paths
    if (payment["attachmentPaths"] is List) {
      final paths = List<String>.from(payment["attachmentPaths"] ?? []);
      for (var path in paths) {
        if (path.isNotEmpty && !attachmentPaths.contains(path)) {
          attachmentPaths.add(path);
        }
      }
    }

    return attachmentPaths;
  }

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
                    ? Image.network(
                        imagePath,
                        fit: BoxFit.contain,
                        headers: {
                          'Authorization': 'Token ${widget.authToken}',
                        },
                        errorBuilder: (context, error, stackTrace) {
                          return Container(
                            color: Colors.grey[800],
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Icon(Icons.broken_image,
                                    color: Colors.grey, size: 40),
                                const SizedBox(height: 8),
                                Text(
                                  'Failed to load image',
                                  style: TextStyle(color: Colors.grey[400]),
                                ),
                                const SizedBox(height: 8),
                                ElevatedButton(
                                  onPressed: () =>
                                      _downloadAndOpenFile(imagePath),
                                  child: const Text('Download Instead'),
                                ),
                              ],
                            ),
                          );
                        },
                        loadingBuilder: (context, child, loadingProgress) {
                          if (loadingProgress == null) return child;
                          return Center(
                            child: CircularProgressIndicator(
                              value: loadingProgress.expectedTotalBytes != null
                                  ? loadingProgress.cumulativeBytesLoaded /
                                      loadingProgress.expectedTotalBytes!
                                  : null,
                            ),
                          );
                        },
                      )
                    : Image.file(
                        File(imagePath),
                        fit: BoxFit.contain,
                        errorBuilder: (context, error, stackTrace) {
                          return Container(
                            color: Colors.grey[800],
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Icon(Icons.broken_image,
                                    color: Colors.grey, size: 40),
                                const SizedBox(height: 8),
                                Text(
                                  'Local file not found',
                                  style: TextStyle(color: Colors.grey[400]),
                                ),
                                const SizedBox(height: 8),
                                if (imagePath.contains('file_picker'))
                                  ElevatedButton(
                                    onPressed: () =>
                                        ScaffoldMessenger.of(context)
                                            .showSnackBar(
                                      const SnackBar(
                                        content: Text(
                                            'File was temporary and has been cleared. Please ask the employee to resubmit.'),
                                        backgroundColor: Colors.orange,
                                      ),
                                    ),
                                    child: const Text('File Cleared'),
                                  ),
                              ],
                            ),
                          );
                        },
                      ),
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

  // Add this method for network requests
  Map<String, String> _getHeaders() {
    return {
      'Authorization': 'Token ${widget.authToken}',
      'Content-Type': 'application/json',
    };
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
      print('📥 Downloading file: $filePath');

      // Check if it's a URL
      if (filePath.startsWith('http')) {
        print('🌐 Downloading from URL...');
        final response = await http.get(
          Uri.parse(filePath),
          headers: {
            'Authorization': 'Token ${widget.authToken}',
          },
        ).timeout(const Duration(seconds: 30));

        if (response.statusCode == 200) {
          // Get downloads directory
          final downloadsDir = await getDownloadsDirectory();
          if (downloadsDir == null) {
            throw Exception('Could not access downloads directory');
          }

          // Create filename
          String fileName = _getFileName(filePath);
          // Handle URL query parameters
          if (fileName.contains('?')) {
            fileName = fileName.split('?').first;
          }

          // Create file
          final file = File('${downloadsDir.path}/$fileName');

          // Handle duplicate filenames
          if (await file.exists()) {
            final timestamp = DateTime.now().millisecondsSinceEpoch;
            final newFileName =
                '${fileName.split('.').first}_$timestamp.${_getFileExtension(fileName)}';
            final newFile = File('${downloadsDir.path}/$newFileName');
            await newFile.writeAsBytes(response.bodyBytes);
            print('✅ File downloaded: ${newFile.path}');
            return newFile.path;
          } else {
            await file.writeAsBytes(response.bodyBytes);
            print('✅ File downloaded: ${file.path}');
            return file.path;
          }
        } else {
          throw Exception(
              'HTTP ${response.statusCode}: ${response.reasonPhrase}');
        }
      }
      // Handle local paths
      else {
        print('📁 Checking local file...');
        final file = File(filePath);
        if (await file.exists()) {
          print('✅ Local file exists');
          return filePath;
        } else {
          throw Exception(
              'Local file not found: $filePath. File may have been moved or deleted.');
        }
      }
    } catch (e) {
      print('❌ Error in _downloadFile: $e');
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

  Widget _buildFileActions(String filePath) {
    final isImage = _isImageFile(filePath);

    if (isImage) {
      return Row(
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
              onPressed: () => _downloadOnly(filePath),
              style: OutlinedButton.styleFrom(
                foregroundColor: const Color(0xFF388E3C),
                side: const BorderSide(color: Color(0xFF388E3C)),
                padding: const EdgeInsets.symmetric(vertical: 10),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              icon: const Icon(Icons.download, size: 18),
              label: const Text('Download'),
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
              onPressed: () => _downloadOnly(filePath),
              style: OutlinedButton.styleFrom(
                foregroundColor: const Color(0xFF1976D2),
                side: const BorderSide(color: Color(0xFF1976D2)),
                padding: const EdgeInsets.symmetric(vertical: 10),
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
    final isImage = _isImageFile(attachmentPath);

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
                  _getFileIcon(attachmentPath),
                  color: _getFileIconColor(attachmentPath),
                  size: 24,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _getFileName(attachmentPath),
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w500,
                        ),
                        overflow: TextOverflow.ellipsis,
                        maxLines: 1,
                      ),
                      Text(
                        _getFileExtension(attachmentPath).toUpperCase(),
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
                  child: attachmentPath.startsWith('http')
                      ? Image.network(
                          attachmentPath,
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
                          File(attachmentPath),
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

  Widget _buildDetailCard(String title, List<Widget> children) {
    return Card(
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
            Text(
              title,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            ...children,
          ],
        ),
      ),
    );
  }

  Widget _detailItem(String label, String value, {bool isImportant = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 140,
            child: Text(
              '$label:',
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
              value,
              style: TextStyle(
                color: isImportant ? const Color(0xFF00E5FF) : Colors.white,
                fontWeight: isImportant ? FontWeight.bold : FontWeight.normal,
                fontSize: 14,
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final request = widget.request;
    final isReimbursement =
        request.requestType.toLowerCase().contains("reimbursement");
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

    // Better project info detection
    bool hasProjectInfo = false;
    String? projectId;
    String? projectName;

    if (request.payments.isNotEmpty) {
      final firstPayment = request.payments[0];

      // Try different field names for project ID
      projectId = firstPayment['projectId'] ??
          firstPayment['project_id'] ??
          firstPayment['projectID'];

      // Try different field names for project name
      projectName = firstPayment['projectName'] ?? firstPayment['project_name'];

      hasProjectInfo = projectId != null || projectName != null;
    }

    return Scaffold(
      backgroundColor: const Color(0xFF121212),
      appBar: AppBar(
        title: const Text(
          'Request Details',
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
                    _buildDetailCard('Request Overview', [
                      _detailItem('Employee', request.employeeName,
                          isImportant: true),
                      _detailItem('Request Type', request.requestType),
                      _detailItem('Date', request.submissionDate),
                      _detailItem(
                          'Amount', '₹${request.amount.toStringAsFixed(2)}',
                          isImportant: true),
                    ]),

                    // Project Information Card with flexible field detection
                    if (hasProjectInfo)
                      _buildDetailCard('Project Information', [
                        if (projectId != null)
                          _detailItem('Project ID', projectId!),
                        if (!isReimbursement && projectName != null)
                          _detailItem('Project Name', projectName!),
                      ]),

                    // Payment Details Card
                    _buildDetailCard('Payment Details', [
                      if (request.payments.isNotEmpty)
                        ...request.payments.asMap().entries.map((entry) {
                          final index = entry.key;
                          final payment = entry.value;
                          final attachmentPaths = _getAttachmentPaths(payment);

                          return Container(
                            margin: EdgeInsets.only(top: index > 0 ? 12 : 0),
                            padding: EdgeInsets.all(cardPadding),
                            decoration: BoxDecoration(
                              color: const Color(0xFF1A1A1A),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: Colors.grey[800]!),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
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

                                // Common fields for both types
                                _detailItem(
                                    'Amount', '₹${payment['amount'] ?? '0'}'),

                                // REIMBURSEMENT SPECIFIC FIELDS
                                if (isReimbursement) ...[
                                  // Try multiple field names for payment date
                                  if (_getFieldValue(payment, [
                                        'paymentDate',
                                        'payment_date',
                                        'date'
                                      ]) !=
                                      null)
                                    _detailItem(
                                        'Payment Date',
                                        _getFieldValue(payment, [
                                          'paymentDate',
                                          'payment_date',
                                          'date'
                                        ])!),

                                  // Try multiple field names for claim type
                                  if (_getFieldValue(payment, [
                                        'claimType',
                                        'claim_type',
                                        'type'
                                      ]) !=
                                      null)
                                    _detailItem(
                                        'Claim Type',
                                        _getFieldValue(payment, [
                                          'claimType',
                                          'claim_type',
                                          'type'
                                        ])!),

                                  // Try multiple field names for description
                                  if (_getFieldValue(payment, [
                                        'description',
                                        'Description',
                                        'desc'
                                      ]) !=
                                      null)
                                    _detailItem(
                                        'Description',
                                        _getFieldValue(payment, [
                                          'description',
                                          'Description',
                                          'desc'
                                        ])!),

                                  // Custom Claim Type for "Other" category
                                  if (_getFieldValue(payment, [
                                        'customClaimType',
                                        'custom_claim_type',
                                        'otherType'
                                      ]) !=
                                      null)
                                    _detailItem(
                                        'Custom Claim Type',
                                        _getFieldValue(payment, [
                                          'customClaimType',
                                          'custom_claim_type',
                                          'otherType'
                                        ])!),
                                ]
                                // ADVANCE REQUEST SPECIFIC FIELDS
                                else ...[
                                  // Try multiple field names for request date
                                  if (_getFieldValue(payment, [
                                        'requestDate',
                                        'request_date',
                                        'date'
                                      ]) !=
                                      null)
                                    _detailItem(
                                        'Request Date',
                                        _getFieldValue(payment, [
                                          'requestDate',
                                          'request_date',
                                          'date'
                                        ])!),

                                  // Try multiple field names for project date
                                  if (_getFieldValue(payment,
                                          ['projectDate', 'project_date']) !=
                                      null)
                                    _detailItem(
                                        'Project Date',
                                        _getFieldValue(payment,
                                            ['projectDate', 'project_date'])!),

                                  // Try multiple field names for particulars
                                  if (_getFieldValue(payment, [
                                        'particulars',
                                        'Particulars',
                                        'description'
                                      ]) !=
                                      null)
                                    _detailItem(
                                        'Particulars',
                                        _getFieldValue(payment, [
                                          'particulars',
                                          'Particulars',
                                          'description'
                                        ])!),
                                ],

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
                    ]),

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
                              'Take Action',
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

  // Helper method to get field value with multiple possible keys
  String? _getFieldValue(Map<String, dynamic> data, List<String> possibleKeys) {
    for (String key in possibleKeys) {
      if (data[key] != null && data[key].toString().isNotEmpty) {
        return data[key].toString();
      }
    }
    return null;
  }
}
