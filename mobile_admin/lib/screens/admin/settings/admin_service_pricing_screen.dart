import 'package:flutter/material.dart';
import 'package:clotheline_core/clotheline_core.dart';
import 'package:clotheline_admin/widgets/glass/LiquidBackground.dart';
import 'package:clotheline_admin/widgets/glass/GlassContainer.dart';
import 'package:provider/provider.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:share_plus/share_plus.dart';

class AdminServicePricingScreen extends StatelessWidget {
  const AdminServicePricingScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Theme(
      data: AppTheme.darkTheme,
      child: Scaffold(
        extendBodyBehindAppBar: true,
        appBar: AppBar(
          title: const Text("Service Pricing QR", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          backgroundColor: Colors.transparent,
          elevation: 0,
        ),
        body: LiquidBackground(
          child: Consumer<BranchProvider>(
            builder: (context, bp, _) {
              return ListView(
                padding: const EdgeInsets.fromLTRB(20, 100, 20, 100),
                children: [
                  const Text(
                    "Select a branch to generate its public price list QR code. This allows customers to see live prices by scanning in-store.",
                    style: TextStyle(color: Colors.white70, fontSize: 14),
                  ),
                  const SizedBox(height: 30),
                  ...bp.branches.map((branch) => _buildBranchCard(context, branch)),
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _buildBranchCard(BuildContext context, Branch branch) {
    return Padding(
      padding: const EdgeInsets.bottom(15),
      child: GlassContainer(
        opacity: 0.1,
        child: ListTile(
          contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
          title: Text(branch.name, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18)),
          subtitle: const Text("Generate and Share price list", style: TextStyle(color: Colors.white54, fontSize: 12)),
          trailing: const Icon(Icons.qr_code_2_rounded, color: AppTheme.secondaryColor, size: 30),
          onTap: () => _showQRDialog(context, branch),
        ),
      ),
    );
  }

  void _showQRDialog(BuildContext context, Branch branch) {
    final String branchSlug = branch.name.toLowerCase().replaceAll(' ', '-');
    final String url = "https://clotheline-admin.vercel.app/pricelist/$branchSlug";

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E293B),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Column(
          children: [
            const Text("Branch Price List QR", style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 4),
            Text(branch.name, style: const TextStyle(color: Colors.white54, fontSize: 12)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(15),
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(15)),
              child: QrImageView(
                data: url,
                version: QrVersions.auto,
                size: 200.0,
                backgroundColor: Colors.white,
              ),
            ),
            const SizedBox(height: 20),
            Text(url, style: const TextStyle(color: AppTheme.secondaryColor, fontSize: 10), textAlign: TextAlign.center),
            const SizedBox(height: 10),
            const Text("Customers can scan this to see live prices.", style: TextStyle(color: Colors.white38, fontSize: 11), textAlign: TextAlign.center),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("CLOSE")),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.secondaryColor, foregroundColor: Colors.black),
            onPressed: () {
              Share.share("Check out our live service prices at ${branch.name}: $url");
            },
            icon: const Icon(Icons.share, size: 16),
            label: const Text("SHARE LINK"),
          ),
        ],
      ),
    );
  }
}
