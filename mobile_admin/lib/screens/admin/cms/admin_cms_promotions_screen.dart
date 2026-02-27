import 'package:flutter/material.dart';
import 'package:clotheline_admin/widgets/glass/LiquidBackground.dart';
import 'package:clotheline_admin/widgets/glass/GlassContainer.dart';
import 'package:clotheline_core/clotheline_core.dart';
import 'package:clotheline_core/clotheline_core.dart';
import 'package:clotheline_core/clotheline_core.dart';
import 'package:clotheline_core/clotheline_core.dart';
import '../promotions/admin_promotions_screen.dart'; // [New] Import
class AdminCMSPromotionsScreen extends StatelessWidget {
  const AdminCMSPromotionsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Theme(
      data: AppTheme.darkTheme,
      child: Scaffold(
        extendBodyBehindAppBar: true,
        appBar: AppBar(
          title: const Text("Promotions Config", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          backgroundColor: Colors.transparent,
          elevation: 0,
        ),
        body: const LiquidBackground(
          child: AdminCMSPromotionsBody(),
        ),
      ),
    );
  }
}

class AdminCMSPromotionsBody extends StatefulWidget {
  final bool isEmbedded;
  final ValueNotifier<VoidCallback?>? saveTrigger;
  final Function(String)? onNavigate;

  const AdminCMSPromotionsBody({
    super.key, 
    this.isEmbedded = false,
    this.saveTrigger,
    this.onNavigate,
  });

  @override
  State<AdminCMSPromotionsBody> createState() => _AdminCMSPromotionsBodyState();
}

class _AdminCMSPromotionsBodyState extends State<AdminCMSPromotionsBody> {
  final ContentService _contentService = ContentService();
  AppContentModel? _content;
  bool _isLoading = true;
  bool _isSaving = false;

  final TextEditingController _shippingThresholdCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _fetchContent();
    if (widget.isEmbedded && widget.saveTrigger != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) widget.saveTrigger!.value = _save;
      });
    }
  }

  @override
  void dispose() {
    if (widget.isEmbedded && widget.saveTrigger != null && widget.saveTrigger!.value == _save) {
      widget.saveTrigger!.value = null;
    }
    _shippingThresholdCtrl.dispose();
    super.dispose();
  }

  Future<void> _fetchContent() async {
    try {
      final content = await _contentService.getAppContent();
      if (mounted) {
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
    
    final success = await _contentService.updateAppContent(_content!.toJson());

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
    return Stack(
      children: [
        if (_isLoading)
          const Center(child: CircularProgressIndicator())
        else
          SingleChildScrollView(
            padding: EdgeInsets.fromLTRB(20, widget.isEmbedded ? 20 : 100, 20, 20),
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
                      ),
                      const SizedBox(height: 20),
                      const Divider(color: Colors.white10),
                      const SizedBox(height: 10),
                      
                      ListTile(
                         contentPadding: EdgeInsets.zero,
                         title: const Text("Manage Promocodes", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                         subtitle: const Text("Create discount codes and coupons.", style: TextStyle(color: Colors.white54, fontSize: 12)),
                         leading: Container(
                           padding: const EdgeInsets.all(8),
                           decoration: const BoxDecoration(color: Colors.pinkAccent, shape: BoxShape.circle),
                           child: const Icon(Icons.local_offer, color: Colors.white, size: 16),
                         ),
                         trailing: const Icon(Icons.arrow_forward_ios, color: Colors.white54, size: 16),
                         onTap: () {
                           if (widget.isEmbedded && widget.onNavigate != null) {
                             widget.onNavigate!('promocodes');
                           } else {
                             Navigator.push(context, MaterialPageRoute(builder: (_) => const AdminPromotionsScreen()));
                           }
                         },
                      )
                    ],
                  ),
                )
              ],
            ),
          ),
        
        if (!widget.isEmbedded)
          Positioned(
            top: MediaQuery.of(context).padding.top + 10,
            right: 20,
            child: _isSaving
              ? const Center(child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)))
              : IconButton(
                  icon: const Icon(Icons.save, color: AppTheme.secondaryColor), 
                  onPressed: _save,
                ),
          ),
      ],
    );
  }
}
