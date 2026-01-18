import 'package:flutter/material.dart';
import 'package:laundry_app/widgets/glass/LiquidBackground.dart';
import 'package:laundry_app/widgets/glass/GlassContainer.dart';
import 'package:laundry_app/theme/app_theme.dart';
import 'package:laundry_app/services/content_service.dart';
import 'package:laundry_app/models/app_content_model.dart';
import 'package:laundry_app/utils/currency_formatter.dart';
import 'package:laundry_app/utils/toast_utils.dart';
import 'package:laundry_app/widgets/toast/top_toast.dart';
class AdminCMSPromotionsScreen extends StatefulWidget {
  const AdminCMSPromotionsScreen({super.key});

  @override
  State<AdminCMSPromotionsScreen> createState() => _AdminCMSPromotionsScreenState();
}

class _AdminCMSPromotionsScreenState extends State<AdminCMSPromotionsScreen> {
  final ContentService _contentService = ContentService();
  AppContentModel? _content;
  bool _isLoading = true;
  bool _isSaving = false;

  final TextEditingController _shippingThresholdCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _fetchContent();
  }

  Future<void> _fetchContent() async {
    try {
      final content = await _contentService.getAppContent();
      if (mounted && content != null) {
        setState(() {
          _content = content;
          _shippingThresholdCtrl.text = content.freeShippingThreshold.toInt().toString();
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _save() async {
    if (_content == null) return;

    double? threshold = double.tryParse(_shippingThresholdCtrl.text);
    if (threshold == null) {
      ToastUtils.show(context, "Invalid threshold amount", type: ToastType.info);
      return;
    }

    setState(() => _isSaving = true);

    _content!.freeShippingThreshold = threshold;
    
    // Construct update payload
    final updateData = _content!.toJson();
    // Ensure lists are clean (though toJSON handles it)
    
    final success = await _contentService.updateAppContent(updateData);

    if (mounted) {
      setState(() => _isSaving = false);
      if (success) {
        ToastUtils.show(context, "Promotions updated successfully!", type: ToastType.success);
      } else {
        ToastUtils.show(context, "Failed to update promotions", type: ToastType.error);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: const Text("Promotions Config", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          if (_isSaving)
            const Padding(padding: EdgeInsets.all(10), child: Center(child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))))
          else
            IconButton(
              icon: const Icon(Icons.save, color: AppTheme.secondaryColor), 
              onPressed: _save,
            )
        ],
      ),
      body: LiquidBackground(
        child: _isLoading 
            ? const Center(child: CircularProgressIndicator()) 
            : Padding(
                padding: const EdgeInsets.only(top: 100, left: 20, right: 20),
                child: Column(
                  children: [
                    GlassContainer(
                      opacity: 0.1,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text("Free Shipping Settings", style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                          const SizedBox(height: 15),
                          const Text("Free Shipping Threshold (₦)", style: TextStyle(color: Colors.white70, fontSize: 12)),
                          const SizedBox(height: 5),
                          TextField(
                            controller: _shippingThresholdCtrl,
                            keyboardType: TextInputType.number,
                            style: const TextStyle(color: Colors.white),
                            decoration: InputDecoration(
                              filled: true,
                              fillColor: Colors.white10,
                              prefixText: "₦ ",
                              prefixStyle: const TextStyle(color: Colors.white70),
                              hintText: "e.g. 25000",
                              hintStyle: const TextStyle(color: Colors.white24),
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
                            ),
                          ),
                          const SizedBox(height: 10),
                          const Text(
                            "Customers will see 'Free Shipping for orders above ₦...' on product pages.",
                            style: TextStyle(color: Colors.white54, fontSize: 11, fontStyle: FontStyle.italic),
                          )
                        ],
                      ),
                    )
                  ],
                ),
              ),
      ),
    );
  }
}
