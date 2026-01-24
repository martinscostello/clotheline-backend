import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../auth/login_screen.dart';
import '../common/legal_screen.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final PageController _pageController = PageController();
  int _currentPage = 0;
  bool _agreedToTerms = false;

  final List<Map<String, String>> _slides = [
    {
      "title": "Premium Laundry Service",
      "desc": "Experience top-tier fabric care delivered right to your doorstep. We treat your clothes with the respect they deserve.",
      "image": "assets/images/onboarding_1.png"
    },
    {
      "title": "Shop Essentials",
      "desc": "From detergents to fabric softeners, browse our curated store for all your laundry needs.",
      "image": "assets/images/onboarding_2.png"
    },
    {
      "title": "Track in Real-Time",
      "desc": "Stay updated with live status tracking. Know exactly when your laundry is picked up, cleaned, and ready for delivery.",
      "image": "assets/images/onboarding_3.png"
    },
     {
      "title": "Welcome to Clotheline",
      "desc": "Please review and agree to our terms to continue.",
      "image": "assets/images/laundry_light.png" // Placeholder or Logo
    },
  ];

  Future<void> _finishOnboarding() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('seen_onboarding', true);

    if (mounted) {
      Navigator.pushReplacement(
        context, 
        PageRouteBuilder(
          transitionDuration: const Duration(milliseconds: 800),
          pageBuilder: (_, __, ___) => const LoginScreen(),
          transitionsBuilder: (_, animation, __, child) {
            return FadeTransition(opacity: animation, child: child);
          }
        )
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    const primaryColor = Color(0xFF4A80F0);

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0F172A) : Colors.white,
      body: Stack(
        children: [
          // Slides
          PageView.builder(
            controller: _pageController,
            onPageChanged: (index) => setState(() => _currentPage = index),
            itemCount: _slides.length,
            itemBuilder: (context, index) {
              final slide = _slides[index];
              final isLegalSlide = index == 3;

              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 40),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // Graphic (Placeholder)
                    // Ideally use SVGs or Images here
                    Container(
                      height: 250,
                      decoration: BoxDecoration(
                        color: isDark ? Colors.white10 : Colors.grey.shade100,
                        shape: BoxShape.circle,
                      ),
                      child: Center(
                         child: Icon(
                           // Using icon placeholders for now if images missing
                           index == 0 ? Icons.local_laundry_service_outlined :
                           index == 1 ? Icons.shopping_bag_outlined :
                           index == 2 ? Icons.timeline : Icons.verified_user_outlined,
                           size: 80,
                           color: primaryColor,
                         )
                      )
                      // If images exist: Image.asset(slide['image']!, height: 300)
                    ),
                    const SizedBox(height: 48),
                    Text(
                      slide['title']!,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                        color: isDark ? Colors.white : const Color(0xFF1E293B),
                        height: 1.2,
                        letterSpacing: -0.5
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      slide['desc']!,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 16,
                        color: isDark ? Colors.white70 : const Color(0xFF64748B),
                        height: 1.5,
                      ),
                    ),

                    if (isLegalSlide) ...[
                      const SizedBox(height: 32),
                      _buildLegalSection(isDark, primaryColor),
                    ]
                  ],
                ),
              );
            },
          ),

          // Bottom Controls
          Positioned(
            bottom: 50,
            left: 0,
            right: 0,
            child: Column(
              children: [
                // Indicators
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(_slides.length, (index) {
                    final isActive = index == _currentPage;
                    return AnimatedContainer(
                      duration: const Duration(milliseconds: 300),
                      margin: const EdgeInsets.symmetric(horizontal: 4),
                      height: 8,
                      width: isActive ? 24 : 8,
                      decoration: BoxDecoration(
                        color: isActive ? primaryColor : (isDark ? Colors.white24 : Colors.black12),
                        borderRadius: BorderRadius.circular(4),
                      ),
                    );
                  }),
                ),
                const SizedBox(height: 32),
                
                // Next / Agree Button
                if (_currentPage == 3)
                   Padding(
                     padding: const EdgeInsets.symmetric(horizontal: 40),
                     child: SizedBox(
                       width: double.infinity,
                       height: 56,
                       child: ElevatedButton(
                         onPressed: _agreedToTerms ? _finishOnboarding : null,
                         style: ElevatedButton.styleFrom(
                           backgroundColor: primaryColor,
                           disabledBackgroundColor: isDark ? Colors.white10 : Colors.grey.shade300,
                           shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                           elevation: _agreedToTerms ? 4 : 0,
                         ),
                         child: const Text("Agree & Continue", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white)),
                       ),
                     ),
                   )
                else
                   Padding(
                     padding: const EdgeInsets.symmetric(horizontal: 40),
                     child: Row(
                       mainAxisAlignment: MainAxisAlignment.spaceBetween,
                       children: [
                         TextButton(
                           onPressed: () => _pageController.jumpToPage(3),
                           child: Text("Skip", style: TextStyle(color: isDark ? Colors.white70 : Colors.grey.shade600)),
                         ),
                         ElevatedButton(
                           onPressed: () {
                             _pageController.nextPage(duration: const Duration(milliseconds: 400), curve: Curves.easeInOut);
                           },
                           style: ElevatedButton.styleFrom(
                             shape: const CircleBorder(),
                             padding: const EdgeInsets.all(20),
                             backgroundColor: primaryColor,
                           ),
                           child: const Icon(Icons.arrow_forward, color: Colors.white),
                         ),
                       ],
                     ),
                   )
              ],
            ),
          )
        ],
      ),
    );
  }

  Widget _buildLegalSection(bool isDark, Color primaryColor) {
    return Column(
      children: [
        Row(
           mainAxisAlignment: MainAxisAlignment.center,
           children: [
             Checkbox(
               value: _agreedToTerms, 
               activeColor: primaryColor,
               onChanged: (val) => setState(() => _agreedToTerms = val ?? false),
               shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
             ),
             const SizedBox(width: 8),
             const Text("I agree to the", style: TextStyle(fontSize: 14)),
           ],
        ),
        Wrap(
          alignment: WrapAlignment.center,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            GestureDetector(
              onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const LegalScreen(type: LegalType.privacyPolicy))),
              child: Text("Privacy Policy", style: TextStyle(color: primaryColor, fontWeight: FontWeight.bold, decoration: TextDecoration.underline))
            ),
            const Text("  and  "),
            GestureDetector(
              onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const LegalScreen(type: LegalType.termsOfUse))),
              child: Text("Terms of Use", style: TextStyle(color: primaryColor, fontWeight: FontWeight.bold, decoration: TextDecoration.underline))
            ),
          ],
        )
      ],
    );
  }
}
