import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

enum LegalType { privacyPolicy, termsOfUse }

class LegalScreen extends StatelessWidget {
  final LegalType type;

  const LegalScreen({super.key, required this.type});

  String get _title => type == LegalType.privacyPolicy ? "Privacy Policy" : "Terms of Use";

  String get _content {
    if (type == LegalType.privacyPolicy) {
      return """
Effective Date: 29 December 2025
Last Updated: 12 January 2026

1. Introduction

Clotheline (“we”, “our”, “us”) respects your privacy and is committed to protecting your personal information.
This Privacy Policy explains how we collect, use, store, and protect your data when you use the Clotheline mobile application and related services.

By using our app, you agree to the practices described in this policy.

⸻

2. Information We Collect

2.1 Personal Information

We may collect:
• Full name
• Email address
• Phone number
• Delivery address
• Account login credentials
• Branch selection (e.g. Benin or Abuja)

⸻

2.2 Order & Payment Information

We collect:
• Order details
• Service selections
• Delivery preferences
• Payment status and references

⚠️ We do NOT store card or bank details.
All payments are processed securely through third-party payment providers.

⸻

2.3 Chat & Support Data

When you use in-app support chat:
• Messages are stored to provide customer support
• Chats are linked to your account and selected branch

⸻

2.4 Device & Usage Information

We may collect:
• App usage data
• Crash reports
• Device type and OS version
• Push notification tokens

This data helps us improve performance and reliability.

⸻

3. How We Use Your Information

We use your information to:
• Create and manage your account
• Process orders and payments
• Provide delivery and pickup services
• Communicate order updates
• Provide customer support
• Send notifications (orders, chat replies, announcements)
• Improve app performance and security

⸻

4. Branch-Based Data Handling

Clotheline operates multiple branches.
Your orders, chats, and services are associated with the branch you select.

Data is not shared across branches except where required for administration and system operation.

⸻

5. Sharing of Information

We do not sell or rent your personal data.

We may share information only with:
• Payment providers (for payment processing)
• Delivery personnel (for order fulfillment)
• Service providers supporting app functionality
• Legal authorities when required by law

⸻

6. Data Storage & Security
• We store data securely using industry-standard practices
• Access is restricted to authorized personnel
• We regularly review security measures

Despite our efforts, no system is 100% secure.

⸻

7. Push Notifications

We send notifications for:
• Order updates
• Chat messages
• Admin announcements

You may manage notification preferences in your device settings.

⸻

8. Your Rights

You may:
• Access your personal data
• Request corrections
• Request account deletion (subject to legal obligations)

To make a request, contact us at:
📧 support@brimarcglobal.com

⸻

9. Data Retention

We retain your data:
• As long as your account is active
• As required for legal, accounting, or operational purposes

⸻

10. Changes to This Policy

We may update this Privacy Policy from time to time.
Updates will be posted in the app.

⸻

11. Contact Us

If you have questions about this policy:

Clotheline Support
📧 Email: support@brimarcglobal.com
📍 Nigeria
""";
    } else {
      return """
Effective Date: 29 December 2025
Last Updated: 12 January 2026

1. Acceptance of Terms

By accessing or using the Clotheline app, you agree to these Terms of Use.
If you do not agree, please do not use the app.

⸻

2. Eligibility

You must:
• Be at least 18 years old
• Provide accurate account information
• Use the app for lawful purposes only

⸻

3. Account Responsibility

You are responsible for:
• Maintaining the confidentiality of your login details
• All activities under your account

We are not responsible for unauthorized access caused by user negligence.

⸻

4. Services

Clotheline provides:
• Laundry and cleaning services
• Product purchases
• Pickup and delivery options
• Customer support chat

Service availability may vary by branch and location.

⸻

5. Orders & Payments
• Orders are confirmed only after successful payment
• Prices are branch-specific and may change
• Payments are processed by third-party providers

Clotheline is not responsible for payment provider downtime.

⸻

6. Cancellations & Refunds
• Order cancellations are subject to service status
• Refunds, if applicable, follow our refund policy
• Completed services are not refundable

⸻

7. User Conduct

You agree NOT to:
• Abuse support staff
• Submit false orders
• Attempt to bypass payment systems
• Use the app for fraudulent activity

Violations may result in account suspension or termination.

⸻

8. Support Chat Usage
• Chat is for service-related communication only
• Abuse or harassment may lead to restricted access
• Broadcast messages from admins are informational

⸻

9. Limitation of Liability

Clotheline is not liable for:
• Delays caused by traffic, weather, or third parties
• Losses beyond the value of the service paid
• Indirect or consequential damages

⸻

10. Termination

We reserve the right to:
• Suspend or terminate accounts
• Refuse service for policy violations

⸻

11. Intellectual Property

All content, logos, and designs belong to Clotheline.
You may not copy or reuse them without permission.

⸻

12. Governing Law

These Terms are governed by the laws of the Federal Republic of Nigeria.

⸻

13. Changes to Terms

We may update these Terms at any time.
Continued use of the app means you accept the changes.

⸻

14. Contact Information

Clotheline Support
📧 Email: support@brimarcglobal.com
📍 Nigeria
""";
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Scaffold(
      backgroundColor: isDark ? Colors.black : Colors.white,
      appBar: AppBar(
        title: Text(_title, style: TextStyle(color: isDark ? Colors.white : Colors.black)),
        backgroundColor: isDark ? Colors.black : Colors.white,
        elevation: 0,
        leading: const BackButton(),
        systemOverlayStyle: isDark ? SystemUiOverlayStyle.light : SystemUiOverlayStyle.dark,
      ),
      body: Scrollbar(
        thumbVisibility: true,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Text(
            _content,
            style: TextStyle(
              fontSize: 15,
              height: 1.6,
              color: isDark ? Colors.white70 : Colors.black87,
              fontFamily: 'SF Pro Text', // Or default
            ),
          ),
        ),
      ),
    );
  }
}
