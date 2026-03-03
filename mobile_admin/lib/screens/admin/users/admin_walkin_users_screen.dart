import 'package:flutter/material.dart';
import 'package:clotheline_admin/widgets/glass/LiquidBackground.dart';
import 'package:clotheline_admin/widgets/glass/GlassContainer.dart';
import 'package:clotheline_core/clotheline_core.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:csv/csv.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io';
import 'package:share_plus/share_plus.dart';

class AdminWalkInUsersScreen extends StatefulWidget {
  const AdminWalkInUsersScreen({super.key});

  @override
  State<AdminWalkInUsersScreen> createState() => _AdminWalkInUsersScreenState();
}

class _AdminWalkInUsersScreenState extends State<AdminWalkInUsersScreen> {
  bool _isLoading = true;
  List<dynamic> _walkInUsers = [];
  String? _error;

  @override
  void initState() {
    super.initState();
    _fetchWalkInUsers();
  }

  Future<void> _fetchWalkInUsers() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final api = ApiService();
      final response = await api.client.get('/orders/admin/walk-in-users');
      
      if (response.statusCode == 200) {
        setState(() {
          _walkInUsers = response.data;
          _isLoading = false;
        });
      } else {
        setState(() {
          _error = 'Failed to load users: ${response.statusCode}';
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = 'An error occurred. Check your connection.';
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _launchWhatsApp(String phone) async {
    // Basic sanitization
    String cleanPhone = phone.replaceAll(RegExp(r'[^0-9+]'), '');
    
    // Auto-prepend country code if local standard format (e.g. Nigerian 080...)
    if (cleanPhone.startsWith('0') && cleanPhone.length == 11) {
      cleanPhone = '+234${cleanPhone.substring(1)}';
    }

    final String url = "https://wa.me/$cleanPhone";
    final Uri uri = Uri.parse(url);

    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else {
      if (!mounted) return;
      ToastUtils.show(context, "Could not launch WhatsApp. Is it installed?", type: ToastType.error);
    }
  }

  Future<void> _exportToCsv() async {
    if (_walkInUsers.isEmpty) {
      ToastUtils.show(context, "No users to export", type: ToastType.warning);
      return;
    }

    ToastUtils.show(context, "Generating CSV...", type: ToastType.info);

    try {
      // 1. Prepare Data
      List<List<dynamic>> rows = [];
      // Headers
      rows.add(["Name", "Phone", "Email", "Branch", "Last Order Date", "Total Orders"]);
      
      // Rows
      for (var user in _walkInUsers) {
        rows.add([
          user['name'] ?? 'Unknown',
          user['phone'] ?? 'N/A',
          user['email'] ?? 'N/A',
          user['branchName'] ?? 'Unknown',
          user['lastOrderDate'] ?? '',
          user['totalOrders'] ?? 0,
        ]);
      }

      // 2. Generate CSV String
      String csvData = const ListToCsvConverter().convert(rows);

      // 3. Save to Temp File
      final directory = await getTemporaryDirectory();
      final path = "${directory.path}/WalkInUsers_Export_${DateTime.now().millisecondsSinceEpoch}.csv";
      final file = File(path);
      await file.writeAsString(csvData);

      // 4. Share File
      await Share.shareXFiles(
          [XFile(path)], 
          text: 'Clotheline Walk-In Users Export'
      );

    } catch (e) {
      if (!mounted) return;
      ToastUtils.show(context, "Export failed: $e", type: ToastType.error);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: const Text("Walk-In Users", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          IconButton(
            icon: const Icon(Icons.file_download, color: Colors.greenAccent),
            tooltip: "Export to CSV",
            onPressed: () => _exportToCsv(),
          ),
          IconButton(
            icon: const Icon(Icons.refresh, color: AppTheme.secondaryColor),
            onPressed: _fetchWalkInUsers,
          ),
        ],
      ),
      body: LiquidBackground(
        child: SafeArea(
          child: _buildBody(),
        ),
      ),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator(color: AppTheme.secondaryColor));
    }

    if (_error != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, color: Colors.redAccent, size: 50),
            const SizedBox(height: 10),
            Text(_error!, style: const TextStyle(color: Colors.white70)),
            const SizedBox(height: 20),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: AppTheme.secondaryColor),
              onPressed: _fetchWalkInUsers,
              child: const Text("Retry", style: TextStyle(color: Colors.black)),
            ),
          ],
        ),
      );
    }

    if (_walkInUsers.isEmpty) {
      return const Center(child: Text("No Walk-In Users found.", style: TextStyle(color: Colors.white54, fontSize: 16)));
    }

    return ListView.builder(
      padding: const EdgeInsets.all(15),
      itemCount: _walkInUsers.length,
      itemBuilder: (context, index) {
        final user = _walkInUsers[index];
        final String name = user['name'] ?? 'Unknown Guest';
        final String phone = user['phone'] ?? 'N/A';
        final String email = user['email'] ?? '';
        final String branchName = user['branchName'] ?? 'Unknown Branch';
        final int totalOrders = user['totalOrders'] ?? 0;

        return Padding(
          padding: const EdgeInsets.only(bottom: 12.0),
          child: GlassContainer(
            opacity: 0.1,
            padding: const EdgeInsets.all(15),
            child: Row(
              children: [
                CircleAvatar(
                  backgroundColor: AppTheme.secondaryColor.withValues(alpha: 0.2),
                  child: Text(
                    name.isNotEmpty ? name[0].toUpperCase() : '?',
                    style: const TextStyle(color: AppTheme.secondaryColor, fontWeight: FontWeight.bold),
                  ),
                ),
                const SizedBox(width: 15),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(name, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          const Icon(Icons.store, color: Colors.white54, size: 14),
                          const SizedBox(width: 4),
                          Text(branchName, style: const TextStyle(color: Colors.white54, fontSize: 12)),
                        ],
                      ),
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          const Icon(Icons.phone, color: Colors.white54, size: 14),
                          const SizedBox(width: 4),
                          Text(phone, style: const TextStyle(color: Colors.white54, fontSize: 12)),
                          if (email.isNotEmpty) ...[
                            const SizedBox(width: 10),
                            const Icon(Icons.email, color: Colors.white54, size: 14),
                            const SizedBox(width: 4),
                            Expanded(child: Text(email, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white54, fontSize: 12))),
                          ],
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text("Orders: $totalOrders", style: const TextStyle(color: AppTheme.secondaryColor, fontSize: 11, fontWeight: FontWeight.bold)),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.wechat, color: Colors.greenAccent, size: 30),
                  tooltip: "Chat on WhatsApp",
                  onPressed: () => _launchWhatsApp(phone),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
