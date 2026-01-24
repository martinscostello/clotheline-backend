import 'package:flutter/material.dart';
import 'package:laundry_app/widgets/glass/LaundryGlassBackground.dart';

class FaqsScreen extends StatelessWidget {
  const FaqsScreen({super.key});

  final List<Map<String, String>> _faqs = const [
    {
      "q": "How long does laundry take?",
      "a": "Standard orders are typically processed within 24-48 hours. Express service is available for same-day delivery if booked before 10 AM."
    },
    {
      "q": "Do you separate colors?",
      "a": "Yes, we meticulously separate lights, darks, and delicate fabrics to ensure your clothes are treated with care."
    },
    {
      "q": "What detailed areas do you cover?",
      "a": "We currently serve major areas in Benin and Abuja. You can check specific coverage by entering your address at checkout."
    },
    {
      "q": "Do you offer subscription plans?",
      "a": "Not yet, but we are working on exciting monthly bundles. Stay tuned for updates!"
    },
    {
      "q": "Can I schedule a recurring pickup?",
      "a": "Not directly through the app yet, but you can chat with our support team to arrange a custom schedule."
    },
    {
      "q": "What if an item is damaged?",
      "a": "In the rare event of damage, please report it immediately via the Support Chat or Feedback page within 24 hours of delivery."
    },
    {
      "q": "How do I pay?",
      "a": "We accept payments via card, bank transfer, and USSD through our secure payment partner (Paystack)."
    }
  ];

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: Colors.transparent, // Global Background Consistency
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: Text("FAQs", style: TextStyle(color: isDark ? Colors.white : Colors.black)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: const BackButton(),
        iconTheme: IconThemeData(color: isDark ? Colors.white : Colors.black),
      ),
      body: LaundryGlassBackground(
        child: ListView.builder(
          padding: EdgeInsets.only(top: MediaQuery.of(context).padding.top + 70, left: 16, right: 16, bottom: 40),
          itemCount: _faqs.length,
        itemBuilder: (context, index) {
          return Container(
            margin: const EdgeInsets.only(bottom: 12),
            decoration: BoxDecoration(
              color: isDark ? Colors.white.withOpacity(0.05) : Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: isDark ? Colors.white10 : Colors.black.withOpacity(0.05)),
              boxShadow: isDark ? [] : [
                BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 5, offset: const Offset(0, 2))
              ]
            ),
            child: Theme(
              data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
              child: ExpansionTile(
                title: Text(
                  _faqs[index]['q']!,
                  style: TextStyle(fontWeight: FontWeight.w600, color: isDark ? Colors.white : Colors.black87),
                ),
                iconColor: const Color(0xFF4A80F0),
                collapsedIconColor: isDark ? Colors.white54 : Colors.grey,
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                    child: Text(
                      _faqs[index]['a']!,
                      style: TextStyle(color: isDark ? Colors.white70 : Colors.black54, height: 1.5),
                    ),
                  )
                ],
              ),
            ),
            );
          },
        ),
      ),
    );
  }
}
