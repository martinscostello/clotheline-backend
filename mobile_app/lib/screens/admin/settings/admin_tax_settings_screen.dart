import 'package:flutter/material.dart';
import '../../../../theme/app_theme.dart';
import '../../../../widgets/glass/GlassContainer.dart';
import '../../../../widgets/glass/LiquidBackground.dart';
import '../../../../services/api_service.dart';

class AdminTaxSettingsScreen extends StatefulWidget {
  const AdminTaxSettingsScreen({super.key});

  @override
  State<AdminTaxSettingsScreen> createState() => _AdminTaxSettingsScreenState();
}

class _AdminTaxSettingsScreenState extends State<AdminTaxSettingsScreen> {
  final ApiService _api = ApiService();
  bool _isLoading = true;
  bool _isSaving = false;
  
  bool _taxEnabled = true;
  double _taxRate = 7.5;
  final TextEditingController _rateController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _fetchSettings();
  }

  Future<void> _fetchSettings() async {
    try {
      final response = await _api.client.get('/settings');
      // If default/empty, fallback
      final data = response.data ?? {};
      
      setState(() {
        _taxEnabled = data['taxEnabled'] ?? true;
        _taxRate = (data['taxRate'] ?? 7.5).toDouble();
        _rateController.text = _taxRate.toString();
        _isLoading = false;
      });
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        // Maybe first time, no settings yet. Ignore error or show snackbar.
      }
    }
  }

  Future<void> _saveSettings() async {
    setState(() => _isSaving = true);
    try {
      final rate = double.tryParse(_rateController.text) ?? 7.5;
      
      await _api.client.post('/settings', data: {
        'taxEnabled': _taxEnabled,
        'taxRate': rate,
        'taxName': 'VAT' // Fixed for now
      });

      if (mounted) {
        setState(() {
           _taxRate = rate;
           _isSaving = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Tax Settings Saved")));
        Navigator.pop(context); // Optional: close screen on save
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSaving = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error saving settings: $e")));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: const Text("Tax Configuration", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: const BackButton(color: Colors.white),
      ),
      body: LiquidBackground(
        child: _isLoading 
          ? const Center(child: CircularProgressIndicator(color: AppTheme.primaryColor))
          : SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 100, 20, 20),
              child: Column(
                children: [
                   // Notice Card
                   GlassContainer(
                     opacity: 0.1,
                     padding: const EdgeInsets.all(16),
                     child: Row(
                       children: const [
                         Icon(Icons.info_outline, color: Colors.blueAccent),
                         SizedBox(width: 15),
                         Expanded(
                           child: Text(
                             "Changes to tax settings will only apply to future orders. Past financial records will remain unchanged.",
                             style: TextStyle(color: Colors.white70, fontSize: 13)
                           ),
                         )
                       ],
                     ),
                   ),
                   const SizedBox(height: 30),

                   // Settings Form
                   GlassContainer(
                     opacity: 0.1,
                     padding: const EdgeInsets.all(20),
                     child: Column(
                       crossAxisAlignment: CrossAxisAlignment.start,
                       children: [
                         SwitchListTile(
                           title: const Text("Enable VAT", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                           subtitle: const Text("Apply Value Added Tax to all orders", style: TextStyle(color: Colors.white54)),
                           value: _taxEnabled,
                           activeColor: AppTheme.primaryColor,
                           onChanged: (val) => setState(() => _taxEnabled = val),
                         ),
                         
                         const Divider(color: Colors.white10),
                         const SizedBox(height: 15),
                         
                         const Text("VAT Rate (%)", style: TextStyle(color: Colors.white70)),
                         const SizedBox(height: 10),
                         TextField(
                           controller: _rateController,
                           style: const TextStyle(color: Colors.white),
                           keyboardType: const TextInputType.numberWithOptions(decimal: true),
                           enabled: _taxEnabled,
                           decoration: InputDecoration(
                             suffixText: "%",
                             suffixStyle: const TextStyle(color: Colors.white70),
                             filled: true,
                             fillColor: Colors.white.withOpacity(0.05),
                             border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
                           ),
                         ),
                       ],
                     ),
                   ),

                   const SizedBox(height: 50),
                   
                   SizedBox(
                     width: double.infinity,
                     height: 55,
                     child: ElevatedButton(
                       onPressed: _isSaving ? null : _saveSettings,
                       style: ElevatedButton.styleFrom(
                         backgroundColor: AppTheme.primaryColor,
                         shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                       ),
                       child: _isSaving 
                         ? const CircularProgressIndicator(color: Colors.white)
                         : const Text("SAVE CHANGES", style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 16)),
                     ),
                   )
                ],
              ),
            ),
      ),
    );
  }
}
