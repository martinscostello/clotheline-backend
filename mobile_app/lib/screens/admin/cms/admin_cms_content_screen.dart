import 'package:flutter/material.dart';
import 'package:laundry_app/widgets/glass/LiquidBackground.dart';
import 'package:laundry_app/widgets/glass/GlassContainer.dart';
import 'package:laundry_app/theme/app_theme.dart';
import 'package:laundry_app/services/content_service.dart';
import 'package:laundry_app/models/app_content_model.dart';
import 'package:image_picker/image_picker.dart';
import 'package:image_cropper/image_cropper.dart';
import 'package:laundry_app/widgets/common/color_picker_sheet.dart';
import '../../../../widgets/custom_cached_image.dart';
import 'package:laundry_app/utils/toast_utils.dart';
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
  double _uploadProgress = 0.0;
  final _formKey = GlobalKey<FormState>();

  // Controllers
  final TextEditingController _brandTextController = TextEditingController();
  final TextEditingController _contactAddressCtrl = TextEditingController();
  final TextEditingController _contactPhoneCtrl = TextEditingController();
  final TextEditingController _deliveryTextCtrl = TextEditingController(); // [NEW]

  // Dynamic Controllers
  final List<TextEditingController> _heroTitleControllers = [];
  final List<TextEditingController> _heroTagControllers = [];
  
  String _deliveryIcon = "van"; // [NEW]
  bool _deliveryActive = true; // [NEW]

  @override
  void initState() {
    super.initState();
    _fetchContent();
  }

  @override
  void dispose() {
    _brandTextController.dispose();
    _contactAddressCtrl.dispose();
    _contactPhoneCtrl.dispose();
    _deliveryTextCtrl.dispose();
    for (var c in _heroTitleControllers) {
      c.dispose();
    }
    for (var c in _heroTagControllers) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _fetchContent() async {
    try {
      final content = await _contentService.getAppContent();
      if (mounted) {
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

        // Delivery Assurance
        if (content.deliveryAssurance != null) {
           _deliveryTextCtrl.text = content.deliveryAssurance!.text;
           _deliveryIcon = content.deliveryAssurance!.icon;
           _deliveryActive = content.deliveryAssurance!.active;
        }

        // Init Controllers
        _heroTitleControllers.clear();
        _heroTagControllers.clear();
        for (var item in content.heroCarousel) {
          _heroTitleControllers.add(TextEditingController(text: item.title));
          _heroTagControllers.add(TextEditingController(text: item.tagLine));
        }
              setState(() {
          _content = content;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint("Error fetching content: $e");
      if (mounted) {
         setState(() => _isLoading = false);
         ScaffoldMessenger.of(context).hideCurrentSnackBar(); // Clean up if any
         ToastUtils.show(context, "Error: $e", type: ToastType.error);
      }
    }
  }

  Future<void> _saveContent() async {
    if (_content == null) return;
    
    _content!.brandText = _brandTextController.text;
    _content!.contactAddress = _contactAddressCtrl.text;
    _content!.contactPhone = _contactPhoneCtrl.text;

    // Sync controllers back to model
    for(int i=0; i< _content!.heroCarousel.length; i++) {
       if (i < _heroTitleControllers.length) {
         _content!.heroCarousel[i].title = _heroTitleControllers[i].text;
         _content!.heroCarousel[i].tagLine = _heroTagControllers[i].text;
       }
    }
    
    final cleanCarousel = _content!.heroCarousel.where((i) => i.imageUrl.isNotEmpty).toList();
    final cleanAds = _content!.productAds.where((i) => i.imageUrl.isNotEmpty).toList();

    final updateData = {
      'heroCarousel': cleanCarousel.map((e) => e.toJson()).toList(),
      'productAds': cleanAds.map((e) => e.toJson()).toList(),
      'brandText': _content!.brandText,
      'contactAddress': _content!.contactAddress,
      'contactPhone': _content!.contactPhone,
      'homeGridServices': _content!.homeGridServices.map((e) => e.id).toList(), 
      'deliveryAssurance': {
         'text': _deliveryTextCtrl.text,
         'icon': _deliveryIcon,
         'active': _deliveryActive
      }
    };
    
    setState(() => _isUploading = true);
    
    final success = await _contentService.updateAppContent(updateData);
    
    if (mounted) {
      setState(() => _isUploading = false);
      if (success) {
        ToastUtils.show(context, "Saved Successfully", type: ToastType.success);
        await _contentService.refreshAppContent(); // Force update cache from server
        _fetchContent();
      } else {
        ToastUtils.show(context, "Failed to save", type: ToastType.error);
      }
    }
  }

  // ... _pickAndUploadImage, _pickAndUploadVideo intentionally omitted from replacement to match range
  // Wait, I need to match EXACT LINES. 
  // The provided text covers _saveContent and _fetchContent fully.
  // But my Range (StartLine 28) covers _saveContent and `_pickAndUploadImage` isn't in my replacement content?
  // Be careful. I'll include ALL OF THEM or just do multiple edits.
  // I'll do multiple edits to be safe.
  // Edit 1: State variables and _fetchContent (Lines 28-93)
  // Edit 2: _saveContent (Lines 95-136)
  // Edit 3: _buildSectionContent (Lines 268-276) + Add _buildBrandingConfig

  // Let's do Edit 1: State Variables.

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

    setState(() {
      _isUploading = true;
      _uploadProgress = 0.0;
    });
    
    // Upload
    String? url = await _contentService.uploadImage(
      croppedFile.path,
      onProgress: (sent, total) {
        if (total > 0) {
          setState(() => _uploadProgress = sent / total);
        }
      }
    );
    
    setState(() => _isUploading = false);
    
    if (url != null) {
      onUrlReady(url);
    } else {
      if(mounted) ToastUtils.show(context, "Upload Failed", type: ToastType.error);
    }
  }

  Future<void> _pickAndUploadVideo(Function(String) onUrlReady) async {
    final picker = ImagePicker();
    final XFile? video = await picker.pickVideo(source: ImageSource.gallery);
    
    if (video == null) return;

    setState(() {
      _isUploading = true;
      _uploadProgress = 0.0;
    });
    
    // Upload (Same endpoint handles videos now)
    String? url = await _contentService.uploadImage(
      video.path,
      onProgress: (sent, total) {
        if (total > 0) {
          setState(() => _uploadProgress = sent / total);
        }
      }
    );
    
    setState(() => _isUploading = false);
    
    if (url != null) {
      onUrlReady(url);
    } else {
      if(mounted) ToastUtils.show(context, "Video Upload Failed", type: ToastType.error);
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
        bottom: _isUploading 
          ? PreferredSize(
              preferredSize: const Size.fromHeight(4),
              child: LinearProgressIndicator(
                value: _uploadProgress, 
                backgroundColor: Colors.white12,
                valueColor: const AlwaysStoppedAnimation<Color>(AppTheme.secondaryColor),
              ),
            )
          : null,
        actions: [
          if (_isUploading)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Center(
                child: Text(
                  "${(_uploadProgress * 100).toInt()}%", 
                  style: const TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.bold)
                )
              ),
            )
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
        const Text("General Branding", style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
        const SizedBox(height: 15),
        _buildTextField("Brand Name", _brandTextController),
        const SizedBox(height: 15),
        _buildTextField("Contact Address", _contactAddressCtrl),
        const SizedBox(height: 15),
        _buildTextField("Contact Phone", _contactPhoneCtrl),
        const SizedBox(height: 40),
        
        const Text("Delivery Assurance", style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
        Text("Shown on Product Details Page. Wrap text in [] to highlight in green.", style: TextStyle(color: Colors.white70, fontSize: 12)),
        const SizedBox(height: 15),
        
        GlassContainer(
          opacity: 0.1,
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
               Row(
                 mainAxisAlignment: MainAxisAlignment.spaceBetween,
                 children: [
                   const Text("Show Delivery Assurance", style: TextStyle(color: Colors.white)),
                   Switch(value: _deliveryActive, onChanged: (v) => setState(() => _deliveryActive = v), activeColor: AppTheme.secondaryColor),
                 ],
               ),
               if (_deliveryActive) ...[
                 const SizedBox(height: 15),
                 _buildTextField("Assurance Text", _deliveryTextCtrl),
                 const SizedBox(height: 20),
                 const Text("Select Icon", style: TextStyle(color: Colors.white70)),
                 const SizedBox(height: 10),
                 Row(
                   mainAxisAlignment: MainAxisAlignment.spaceAround,
                   children: [
                     _buildIconOption("van", Icons.local_shipping),
                     _buildIconOption("bike", Icons.motorcycle),
                     _buildIconOption("clock", Icons.access_time),
                   ],
                 )
               ]
            ],
          ),
        )
      ],
    );
  }
  
  Widget _buildIconOption(String value, IconData icon) {
     bool isSelected = _deliveryIcon == value;
     return GestureDetector(
       onTap: () => setState(() => _deliveryIcon = value),
       child: Container(
         padding: const EdgeInsets.all(12),
         decoration: BoxDecoration(
           color: isSelected ? AppTheme.secondaryColor.withOpacity(0.2) : Colors.transparent,
           border: Border.all(color: isSelected ? AppTheme.secondaryColor : Colors.white24),
           borderRadius: BorderRadius.circular(10)
         ),
         child: Column(
           children: [
             Icon(icon, color: isSelected ? AppTheme.secondaryColor : Colors.white, size: 30),
             const SizedBox(height: 8),
             Text(value.toUpperCase(), style: TextStyle(color: isSelected ? AppTheme.secondaryColor : Colors.white70, fontSize: 10))
           ],
         ),
       ),
     );
  }



  Widget _buildHomeConfig() {
    final items = _content!.heroCarousel.take(3).toList();
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text("Hero Carousel (Max 3)", style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
        Text("Tap image to change. Recommended Size: 800x600", style: TextStyle(color: Colors.white.withOpacity(0.7), fontSize: 12)),
        const SizedBox(height: 15),
        ...items.asMap().entries.map((entry) {
          int idx = entry.key;
          var item = entry.value;
          return Padding(
            padding: const EdgeInsets.only(bottom: 25),
            child: GlassContainer(
              opacity: 0.1,
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text("Slide ${idx + 1}", style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 10),
                  
                  // Image/Video & Dimension Tag
                  GestureDetector(
                    onTap: () {
                      showModalBottomSheet(
                        context: context,
                        backgroundColor: const Color(0xFF1A1A1A), // [DARK UI FIX]
                        shape: const RoundedRectangleBorder(
                          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
                        ),
                        builder: (ctx) => Container(
                          padding: const EdgeInsets.symmetric(vertical: 20),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              ListTile(
                                leading: const Icon(Icons.image, color: Colors.white),
                                title: const Text("Upload Image", style: TextStyle(color: Colors.white)),
                                onTap: () {
                                  Navigator.pop(ctx);
                                  _pickAndUploadImage((url) {
                                    setState(() {
                                      _content!.heroCarousel[idx].imageUrl = url;
                                      _content!.heroCarousel[idx].mediaType = 'image';
                                    });
                                  }, preset: CropAspectRatioPreset.ratio16x9);
                                },
                              ),
                              ListTile(
                                leading: const Icon(Icons.videocam, color: Colors.white),
                                title: const Text("Upload Video (Short)", style: TextStyle(color: Colors.white)),
                                onTap: () {
                                  Navigator.pop(ctx);
                                  _pickAndUploadVideo((url) {
                                    setState(() {
                                      _content!.heroCarousel[idx].imageUrl = url;
                                      _content!.heroCarousel[idx].mediaType = 'video';
                                    });
                                  });
                                },
                              ),
                              const SizedBox(height: 20),
                            ],
                          ),
                        )
                      );
                    },
                    child: Stack(
                      children: [
                        AspectRatio(
                          aspectRatio: 16/9,
                          child: Container(
                            color: Colors.black12,
                            child: Stack(
                              fit: StackFit.expand,
                              children: [
                                if (item.imageUrl.isNotEmpty && item.mediaType == 'image')
                                  Positioned.fill(
                                    child: CustomCachedImage(
                                      imageUrl: item.imageUrl,
                                      fit: BoxFit.cover,
                                      borderRadius: 8,
                                    ),
                                  ),
                                if (item.imageUrl.isNotEmpty && item.mediaType == 'video')
                                  const Center(child: Icon(Icons.play_circle_fill, color: Colors.white, size: 50)),
                                
                                if (item.imageUrl.isEmpty)
                                  const Center(child: Icon(Icons.add_a_photo, color: Colors.white54, size: 40)),
                              ],
                            ),
                          ),
                        ),
                        // Dimension Tag (Top Right)
                        Positioned(
                          top: 8,
                          right: 8,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(color: Colors.black54, borderRadius: BorderRadius.circular(4)),
                            child: Text(item.mediaType == 'video' ? "VIDEO" : "800x600", style: const TextStyle(color: Colors.white, fontSize: 10)),
                          ),
                        )
                      ],
                    ),
                  ),

                  const SizedBox(height: 15),
                  
                  // Captions
                  // Captions
                  _buildCaptionField(
                    "Bold Title", 
                    _heroTitleControllers.length > idx ? _heroTitleControllers[idx] : TextEditingController(), 
                    color: item.titleColor ?? "0xFFFFFFFF",
                    onColorChanged: (val) => setState(() => item.titleColor = val)
                  ),
                  const SizedBox(height: 10),
                  _buildCaptionField(
                    "Tag Line", 
                    _heroTagControllers.length > idx ? _heroTagControllers[idx] : TextEditingController(),
                    color: item.tagLineColor ?? "0xFFFFFFFF",
                    onColorChanged: (val) => setState(() => item.tagLineColor = val)
                  ),
                ],
              ),
            ),
          );
        }),
      ],
    );
  }

  Widget _buildCaptionField(String label, TextEditingController controller, {required String color, required Function(String) onColorChanged}) {
    Color displayColor = Colors.white;
    try {
      if (color.startsWith("0x")) {
        displayColor = Color(int.parse(color.substring(2), radix: 16));
      }
    } catch (_) {}

     return Row(
       children: [
         Expanded(
           flex: 2,
           child: Column(
             crossAxisAlignment: CrossAxisAlignment.start,
             children: [
               Text(label, style: const TextStyle(color: Colors.white70, fontSize: 11)),
               const SizedBox(height: 4),
               TextFormField(
                 controller: controller,
                 style: const TextStyle(color: Colors.white, fontSize: 13),
                 decoration: InputDecoration(
                   isDense: true,
                   contentPadding: const EdgeInsets.all(8),
                   filled: true,
                   fillColor: Colors.white10,
                   border: OutlineInputBorder(borderRadius: BorderRadius.circular(6), borderSide: BorderSide.none),
                 ),
               ),
             ],
           ),
         ),
         const SizedBox(width: 10),
         Expanded(
           flex: 1,
           child: Column(
             crossAxisAlignment: CrossAxisAlignment.start,
             children: [
               const Text("Color", style: TextStyle(color: Colors.white70, fontSize: 11)),
               const SizedBox(height: 4),
               GestureDetector(
                onTap: () {
                   showModalBottomSheet(
                     context: context, 
                     backgroundColor: Colors.transparent,
                     builder: (ctx) => ColorPickerSheet(
                       initialColor: color, 
                       onColorSelected: onColorChanged
                     )
                   );
                },
                child: Container(
                  height: 38,
                  decoration: BoxDecoration(
                    color: displayColor,
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: Colors.white24)
                  ),
                  child: Center(
                    child: Text(
                      color.replaceAll("0xFF", "#").replaceAll("0x", "#"), 
                      style: TextStyle(
                        fontSize: 12, 
                        color: displayColor.computeLuminance() > 0.5 ? Colors.black : Colors.white,
                        fontWeight: FontWeight.bold
                      )
                    ),
                  ),
                ),
              )
             ],
           ),
         ),
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
    String dimText = aspectRatio == 16/9 ? "800x450" : "800x200";
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
              child: Stack(
                children: [
                  AspectRatio(
                    aspectRatio: aspectRatio,
                    child: Container(
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                          if (item.imageUrl.isNotEmpty)
                            Positioned.fill(
                              child: CustomCachedImage(
                                imageUrl: item.imageUrl,
                                fit: BoxFit.cover,
                                borderRadius: 8,
                              ),
                            ),
                          if (item.imageUrl.isEmpty)
                            const Center(child: Icon(Icons.add_a_photo, color: Colors.white54, size: 40)),
                        ],
                      ),
                    ),
                  ),
                   Positioned(
                      top: 8,
                      right: 8,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(color: Colors.black54, borderRadius: BorderRadius.circular(4)),
                        child: Text(dimText, style: const TextStyle(color: Colors.white, fontSize: 10)),
                      ),
                    )
                ],
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
