import 'package:flutter/material.dart';
import 'package:dalali/config/app_theme.dart';

/// ═══════════════════════════════════════════════════════════════
/// LEGAL SCREENS — Terms & Conditions, Privacy Policy
/// ═══════════════════════════════════════════════════════════════
///
/// In-app legal documents, linked from the registration screen's
/// acceptance notice. Review with legal counsel before launch;
/// keep in sync with the Play Console privacy policy URL.
///
class TermsScreen extends StatelessWidget {
  const TermsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const _LegalDocumentScreen(
      title: 'Terms and Conditions',
      sections: [
        _LegalSection('1. About Dalali',
            'Dalali ("the App") connects house seekers, landlords, agents and influencers in Tanzania. '
            'The App provides property listings, search, viewing scheduling, tenancy lifecycle tools, '
            'an in-app wallet, and a referral programme. Dalali is a marketplace facilitator, not a '
            'real estate agency, and is not a party to any tenancy agreement between users.'),
        _LegalSection('2. Accounts',
            'You must provide accurate information when creating an account and keep your credentials '
            'confidential. You must be at least 18 years old. You are responsible for all activity '
            'under your account. We may suspend accounts that violate these terms.'),
        _LegalSection('3. Listings and Content',
            'Landlords and agents must only list properties they are authorized to advertise and must '
            'keep details accurate. All listings are subject to admin moderation and may be removed at '
            'our discretion. Users must not post fraudulent, misleading or unlawful content.'),
        _LegalSection('4. Fees and Payments',
            'A fixed agency fee of TZS 20,000 applies per confirmed tenancy, payable through the App '
            'via supported mobile money channels. Other services (premium listings, promotions) are '
            'priced as shown in the App. Payments are processed by third-party providers; Dalali does '
            'not store your mobile money PIN or card details.'),
        _LegalSection('5. Wallet and Withdrawals',
            'Earnings accrue in your in-app wallet. Withdrawals require a verified account (KYC) and '
            'are subject to minimum amounts and processing times shown in the App. Dalali may delay or '
            'decline withdrawals suspected of fraud or abuse.'),
        _LegalSection('6. Referral Programme',
            'Influencers earn commissions on qualifying payments made by referred users at the rates '
            'published in the App. Self-referrals, fake accounts, and other manipulation are prohibited '
            'and may result in forfeiture of earnings and account suspension.'),
        _LegalSection('7. Acceptable Use',
            'You agree not to misuse the App, including scraping, reverse engineering, interfering '
            'with the service, harassing other users, or using the App for any unlawful purpose.'),
        _LegalSection('8. Liability',
            'The App is provided "as is". To the maximum extent permitted by law, Dalali is not liable '
            'for losses arising from user listings, offline interactions between users, or third-party '
            'payment services. Always inspect a property and verify its owner before paying.'),
        _LegalSection('9. Changes',
            'We may update these terms from time to time. Continued use of the App after changes '
            'constitutes acceptance. The current version is always available in the App.'),
        _LegalSection('10. Contact',
            'Questions about these terms: support@dalaliapp.com'),
      ],
    );
  }
}

class PrivacyPolicyScreen extends StatelessWidget {
  const PrivacyPolicyScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const _LegalDocumentScreen(
      title: 'Privacy Policy',
      sections: [
        _LegalSection('1. Data We Collect',
            '• Account data: name, email, phone number, role.\n'
            '• Identity data (KYC): photos of your National ID, voter\u2019s card or driver\u2019s licence, '
            'and a live selfie for proof of life, used solely to verify your account.\n'
            '• Location data: your approximate location, only with your explicit permission, to show '
            'nearby listings.\n'
            '• Usage data: messages you send in in-app chats, listings you view, transactions, and '
            'referral activity.'),
        _LegalSection('2. How We Use It',
            'We use your data to operate the marketplace (listings, chat, appointments, tenancies), '
            'process payments and withdrawals, verify identities, prevent fraud, and improve the App. '
            'We do not sell your personal data.'),
        _LegalSection('3. Legal Basis (PDPA 2022)',
            'We process personal data in accordance with the Tanzania Personal Data Protection Act, '
            '2022, based on your consent (which you may withdraw), the performance of our contract '
            'with you, and our legitimate interest in operating a safe marketplace.'),
        _LegalSection('4. Sharing',
            'We share data only as needed to provide the service: payment processors (to execute '
            'payments), identity verification providers (to verify documents), and other users (your '
            'public profile, listings, and chat messages you send them). We may disclose data where '
            'required by law.'),
        _LegalSection('5. Retention',
            'Account and transaction records are kept while your account is active and as required by '
            'law (financial records up to 7 years). Identity documents are retained only as long as '
            'needed for verification and fraud prevention.'),
        _LegalSection('6. Your Rights',
            'You may access, correct, or delete your personal data, and withdraw consent for optional '
            'processing (such as location), via the App settings or by contacting us. Deleting your '
            'account removes your profile; some records are retained where the law requires.'),
        _LegalSection('7. Security',
            'We use encryption in transit, row-level access controls, and server-side verification for '
            'sensitive operations. No method is 100% secure; please protect your account credentials.'),
        _LegalSection('8. Contact',
            'Privacy questions or requests: privacy@dalaliapp.com'),
      ],
    );
  }
}

class _LegalSection {
  final String heading;
  final String body;
  const _LegalSection(this.heading, this.body);
}

class _LegalDocumentScreen extends StatelessWidget {
  final String title;
  final List<_LegalSection> sections;

  const _LegalDocumentScreen({required this.title, required this.sections});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(title),
        backgroundColor: AppTheme.primary,
        foregroundColor: Colors.white,
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          for (final s in sections) ...[
            Text(s.heading, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 6),
            Text(s.body, style: TextStyle(fontSize: 14, height: 1.5, color: Colors.grey[800])),
            const SizedBox(height: 20),
          ],
          Text('Last updated: July 2026', style: TextStyle(fontSize: 12, color: Colors.grey[500])),
        ],
      ),
    );
  }
}
