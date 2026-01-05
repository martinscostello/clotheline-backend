import 'dart:io';
import 'package:flutter/material.dart';
import 'package:laundry_app/widgets/glass/LiquidBackground.dart';
import 'package:laundry_app/widgets/glass/GlassContainer.dart';
import 'package:laundry_app/theme/app_theme.dart';
import 'package:laundry_app/services/content_service.dart';
import 'package:laundry_app/models/app_content_model.dart';
import 'package:image_picker/image_picker.dart';
import 'package:image_cropper/image_cropper.dart';

class AdminCMSContentScreen extends StatefulWidget {
  final String section; // 'home', 'ads', 'branding'
  const AdminCMSContentScreen({super.key, required this.section});

  @override
  State<AdminCMSContentScreen> createState() => _AdminCMSContentScreenState();
}

class _AdminCMSContentScreenState extends State<AdminCMSContentScreen> {
  final ContentService _contentService = ContentService();
  AppContentModel? _content;
  bool _isLoading = true;
  bool _isUploading = false;
  final _formKey = GlobalKey<FormState>();

  // Controllers
  final TextEditingController _brandTextController = TextEditingController();
  final TextEditingController _contactAddressCtrl = TextEditingController();
  final TextEditingController _contactPhoneCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _fetchContent();
  }

  Future<void> _fetchContent() async {
    final content = await _contentService.getAppContent();
    if (mounted) {
      if (content != null) {
        // Ensure minimum items for placeholders
        while (content.heroCarousel.length < 3) {
          content.heroCarousel.add(HeroCarouselItem(imageUrl: ""));
        }
        while (content.productAds.length < 2) {
          content.productAds.add(ProductAd(imageUrl: "", active: true));
        }

        _brandTextController.text = content.brandText;
        _contactAddressCtrl.text = content.contactAddress;
        _contactPhoneCtrl.text = content.contactPhone;
      }
      setState(() {
        _content = content;
        _isLoading = false;
      });
    }
  }

  Future<void> _saveContent() async {
    if (_content == null) return;
    
    _content!.brandText = _brandTextController.text;
    
    // Filter out invalid items before saving (e.g. placeholders with empty images)
    // We create a temporary copy to send to backend, but usually updateAppContent takes Map.
    // So we can manipulate the _content object but we must be careful not to break the UI state 
    // if the save fails?
    // Actually, if we filter them out, they will be gone from the UI too after fetch?
    // Let's filter them in the toJson call or create a clean list.

    final cleanCarousel = _content!.heroCarousel.where((i) => i.imageUrl.isNotEmpty).toList();
    final cleanAds = _content!.productAds.where((i) => i.imageUrl.isNotEmpty).toList();

    // Create a map manually or use a copy? 
    // Easiest is to temporarily set them, get json, then restore? 
    // Or just construct the JSON manually.
    
    final updateData = {
      'heroCarousel': cleanCarousel.map((e) => e.toJson()).toList(),
      'productAds': cleanAds.map((e) => e.toJson()).toList(),
      'brandText': _content!.brandText,
      'contactAddress': _contactAddressCtrl.text,
      'contactPhone': _contactPhoneCtrl.text,
      // Grid services usually not edited here yet but if they were:
      'homeGridServices': _content!.homeGridServices.map((e) => e.id).toList(), 
    };
    
    setState(() => _isUploading = true);
    
    final success = await _contentService.updateAppContent(updateData);
    
    if (mounted) {
      setState(() => _isUploading = false);
      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Saved Successfully")));
        _fetchContent(); // Refresh to restore placeholders if needed
      } else {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Failed to save")));
      }
    }
  }

  Future<void> _pickAndUploadImage(Function(String) onUrlReady, {required CropAspectRatioPreset preset}) async {
    final picker = ImagePicker();
    final XFile? image = await picker.pickImage(source: ImageSource.gallery);
    
    if (image == null) return;

    // Crop
    CroppedFile? croppedFile = await ImageCropper().cropImage(
      sourcePath: image.path,
      uiSettings: [
        AndroidUiSettings(
            toolbarTitle: 'Crop Image',
            toolbarColor: Colors.deepOrange,
            toolbarWidgetColor: Colors.white,
            initAspectRatio: preset,
            lockAspectRatio: true),
        IOSUiSettings(
          title: 'Crop Image',
        ),
      ],
    );

    if (croppedFile == null) return;

    setState(() => _isUploading = true);
    
    // Upload
    String? url = await _contentService.uploadImage(croppedFile.path);
    
    setState(() => _isUploading = false);
    
    if (url != null) {
      onUrlReady(url);
    } else {
      if(mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Upload Failed")));
    }
  }

  @override
  Widget build(BuildContext context) {
    String title = "Edit Content";
    if (widget.section == 'home') title = "Home Config";
    if (widget.section == 'ads') title = "Ads & Banners";
    if (widget.section == 'branding') title = "Branding";

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: Text(title, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          if (_isUploading)
            const Padding(padding: EdgeInsets.all(10), child: Center(child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))))
          else
            IconButton(
              icon: const Icon(Icons.save, color: AppTheme.secondaryColor), 
              onPressed: _saveContent,
            )
        ],
      ),
      body: LiquidBackground(
        child: _isLoading 
            ? const Center(child: CircularProgressIndicator()) 
            : SingleChildScrollView(
                padding: const EdgeInsets.only(top: 100, bottom: 100, left: 20, right: 20),
                child: _buildSectionContent(),
              ),
      ),
    );
  }

  Widget _buildSectionContent() {
    if (_content == null) return const Center(child: Text("Failed to load content", style: TextStyle(color: Colors.white)));

    switch(widget.section) {
      case 'home': return _buildHomeConfig();
      case 'ads': return _buildAdsConfig();
      case 'branding': return _buildBrandingConfig();
      default: return const SizedBox();
    }
  }

  Widget _buildBrandingConfig() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text("Main Branding", style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
        const SizedBox(height: 15),
        GlassContainer(
          opacity: 0.1,
          child: Column(
            children: [
              _buildTextField("Brand Slogan / Product Banner", _brandTextController),
              const SizedBox(height: 15),
              _buildTextField("Office Address", _contactAddressCtrl),
              const SizedBox(height: 15),
              _buildTextField("Contact Phone Number", _contactPhoneCtrl),
            ],
          ),
        )
      ],
    );
  }

  Widget _buildHomeConfig() {
    // Only show the first 3 placeholders
    final items = _content!.heroCarousel.take(3).toList();
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text("Hero Carousel (Max 3)", style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
        Text("Tap image to change", style: TextStyle(color: Colors.white.withOpacity(0.7), fontSize: 12)),
        const SizedBox(height: 15),
        ...items.asMap().entries.map((entry) {
          int idx = entry.key;
          var item = entry.value;
          return Padding(
            padding: const EdgeInsets.only(bottom: 15),
            child: GestureDetector(
              onTap: () {
                _pickAndUploadImage((url) {
                  setState(() {
                    _content!.heroCarousel[idx].imageUrl = url;
                  });
                }, preset: CropAspectRatioPreset.ratio16x9);
              },
              child: GlassContainer(
                opacity: 0.1,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text("Slide ${idx + 1}", style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 10),
                    AspectRatio(
                      aspectRatio: 16/9,
                      child: Container(
                        decoration: BoxDecoration(
                          color: Colors.black26,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.white24),
                          image: item.imageUrl.isNotEmpty 
                              ? DecorationImage(image: NetworkImage(item.imageUrl), fit: BoxFit.cover)
                              : null
                        ),
                        child: item.imageUrl.isEmpty 
                            ? const Center(child: Icon(Icons.add_a_photo, color: Colors.white54, size: 40))
                            : null,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        }),
      ],
    );
  }

  Widget _buildAdsConfig() {
    var items = _content!.productAds;
    if (items.isEmpty) return const SizedBox();

    return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text("Product Page Banners", style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 15),
          
          // 1. Store Top Banner
          _buildBannerConfigItem(
            title: "Store Top Banner",
            item: items[0],
            aspectRatio: 16/9,
            onImageTap: () {
               _pickAndUploadImage((url) {
                  setState(() {
                    items[0].imageUrl = url;
                  });
                }, preset: CropAspectRatioPreset.ratio16x9);
            },
            onActiveChanged: (val) {
               setState(() => items[0].active = val);
            }
          ),

          const SizedBox(height: 15),

          // 2. Secondary Banner
          if (items.length > 1)
             _buildBannerConfigItem(
              title: "Secondary Banner (Small)",
              item: items[1],
              aspectRatio: 3/1, // More horizontal?
              onImageTap: () {
                 _pickAndUploadImage((url) {
                    setState(() {
                      items[1].imageUrl = url;
                    });
                  }, preset: CropAspectRatioPreset.ratio3x2);
              },
              onActiveChanged: (val) {
                 setState(() => items[1].active = val);
              }
            ),
        ],
      );
  }

  Widget _buildBannerConfigItem({
    required String title, 
    required ProductAd item, 
    required double aspectRatio,
    required VoidCallback onImageTap,
    required Function(bool) onActiveChanged
  }) {
    return GlassContainer(
      opacity: 0.1,
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(title, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              Switch(value: item.active, onChanged: onActiveChanged, activeColor: AppTheme.secondaryColor)
            ],
          ),
          if (item.active) ...[
            const SizedBox(height: 10),
            GestureDetector(
              onTap: onImageTap,
              child: AspectRatio(
                aspectRatio: aspectRatio,
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.black26,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.white24),
                    image: item.imageUrl.isNotEmpty 
                        ? DecorationImage(image: NetworkImage(item.imageUrl), fit: BoxFit.cover)
                        : null
                  ),
                  child: item.imageUrl.isEmpty 
                      ? const Center(child: Icon(Icons.add_a_photo, color: Colors.white54, size: 40))
                      : null,
                ),
              ),
            ),
          ] else 
            const Padding(
              padding: EdgeInsets.all(10.0),
              child: Text("Banner disabled (Hidden in App)", style: TextStyle(color: Colors.white54, fontStyle: FontStyle.italic)),
            )
        ],
      ),
    );
  }

  Widget _buildTextField(String label, TextEditingController controller) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(color: Colors.white70, fontSize: 12)),
        const SizedBox(height: 5),
        TextField(
          controller: controller,
          style: const TextStyle(color: Colors.white),
          decoration: InputDecoration(
            filled: true,
            fillColor: Colors.white10,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
          ),
        ),
      ],
    );
  }
}
