import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';

class PrivacyPolicyDialog extends StatefulWidget {
  const PrivacyPolicyDialog({super.key});

  static Future<void> show(BuildContext context) {
    return showDialog<void>(
      context: context,
      builder: (ctx) => const PrivacyPolicyDialog(),
    );
  }

  @override
  State<PrivacyPolicyDialog> createState() => _PrivacyPolicyDialogState();
}

class _PrivacyPolicyDialogState extends State<PrivacyPolicyDialog> {
  bool _isKannada = false;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      titlePadding: const EdgeInsets.fromLTRB(20, 20, 20, 10),
      contentPadding: const EdgeInsets.symmetric(horizontal: 20),
      actionsPadding: const EdgeInsets.fromLTRB(20, 10, 20, 16),
      title: Row(
        children: [
          const Icon(Icons.privacy_tip_outlined, color: AppColors.financialTeal, size: 26),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              _isKannada ? 'ಗೌಪ್ಯತಾ ನೀತಿ (Privacy Policy)' : 'Privacy Policy',
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
          ),
          TextButton(
            onPressed: () => setState(() => _isKannada = !_isKannada),
            child: Text(
              _isKannada ? 'English' : 'ಕನ್ನಡ',
              style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.primaryNavy),
            ),
          ),
        ],
      ),
      content: SizedBox(
        width: double.maxFinite,
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppColors.financialTeal.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppColors.financialTeal.withValues(alpha: 0.3)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.shield_outlined, color: AppColors.financialTeal, size: 20),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _isKannada
                            ? 'ಸಂಘ ಲೆಡ್ಜರ್ 100% ಆಫ್‌ಲೈನ್ ಅಪ್ಲಿಕೇಶನ್ ಆಗಿದೆ. ನಿಮ್ಮ ಹಣಕಾಸಿನ ಮಾಹಿತಿ ನಿಮ್ಮ ಸಾಧನದಲ್ಲೇ ಇರುತ್ತದೆ.'
                            : 'Sangh Ledger is a 100% offline-first app. Your financial data stays exclusively on your device.',
                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              if (_isKannada) ..._buildKannadaContent() else ..._buildEnglishContent(),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(_isKannada ? 'ಮುಚ್ಚಿ (Close)' : 'Close'),
        ),
      ],
    );
  }

  List<Widget> _buildEnglishContent() {
    return [
      _sectionHeader('1. Offline-First Architecture & Local Storage'),
      _sectionBody(
        'Sangh Ledger is an offline-first community ledger application. All member profiles, savings balances, loans, daily reducing-balance interest records, and double-entry balanced accounting entries are processed and stored exclusively inside an encrypted SQLCipher database locally on your Android device. Sangh Ledger operates without any external application servers, databases, or analytics trackers.',
      ),
      _sectionHeader('2. Google Drive API Usage & Limited Use Compliance'),
      _sectionBody(
        'The app requests only the narrow per-file scope:\n'
        '• https://www.googleapis.com/auth/drive.file\n\n'
        '• Dedicated Folder: Encrypted backups are stored exclusively in your own Google Drive under "SanghLedger_Backups".\n'
        '• Zero Access to Other Files: The app cannot read, modify, or delete any other files in your personal Google Drive.\n'
        '• Pre-Upload Encryption: Backups are encrypted using AES-256-GCM before leaving the device using a key derived from the admin password.\n'
        '• Limited Use Policy: Sangh Ledger complies strictly with the Google API Services User Data Policy. User data is never sold, transferred to third parties, or used for advertising.',
      ),
      _sectionHeader('3. Cryptography & Data Protection'),
      _sectionBody(
        '• SQLCipher 256-bit AES encryption for the primary database.\n'
        '• Database keys secured in Android Keystore (Hardware-backed).\n'
        '• Admin password & PIN protected with Argon2id / PBKDF2 hashing.\n'
        '• Automated 2-day rolling backup retention to protect phone & cloud storage.',
      ),
      _sectionHeader('4. Device Permissions & Biometrics'),
      _sectionBody(
        '• Biometrics: Fingerprint unlock uses Android BiometricPrompt locally. The app never accesses or stores biometric templates.\n'
        '• Storage / Folder Picker: Used solely when you choose a folder to export reports or save zip backups.\n'
        '• Sharing: Used only when explicitly tapping Share to send receipts via WhatsApp/SMS.',
      ),
      _sectionHeader('5. Data Control & Deletion'),
      _sectionBody(
        'Administrators maintain full control. Uninstalling the app permanently deletes local encrypted databases. Cloud backups can be deleted at any time directly in Google Drive, and Google permissions can be revoked anytime at: https://myaccount.google.com/permissions',
      ),
      _sectionHeader('6. Developer Contact'),
      _sectionBody(
        'Operated by OZONE\n'
        'Package: in.sanghledger.app\n'
        'Contact: ozoneadi170@gmail.com\n'
        'Repository: https://github.com/ozone170/sangh-ledger',
      ),
    ];
  }

  List<Widget> _buildKannadaContent() {
    return [
      _sectionHeader('1. ಆಫ್‌ಲೈನ್ ಪ್ರಥಮ ಆರ್ಕಿಟೆಕ್ಚರ್ ಮತ್ತು ಸ್ಥಳೀಯ ಸಂಗ್ರಹಣೆ'),
      _sectionBody(
        'ಸಂಘ ಲೆಡ್ಜರ್ ಸಂಪೂರ್ಣ ಆಫ್‌ಲೈನ್ ಅಪ್ಲಿಕೇಶನ್ ಆಗಿದೆ. ಸದಸ್ಯರ ವಿವರಗಳು, ಉಳಿತಾಯ ಠೇವಣಿಗಳು, ಸಾಲಗಳು, ದೈನಂದಿನ ಬಡ್ಡಿ ಲೆಕ್ಕಾಚಾರಗಳು ಮತ್ತು ಜರ್ನಲ್ ನಮೂದುಗಳು ನಿಮ್ಮ ಆಂಡ್ರಾಯ್ಡ್ ಸಾಧನದಲ್ಲಿಯೇ SQLCipher ಎನ್‌ಕ್ರಿಪ್ಟ್ ಮಾಡಲಾದ ಡೇಟಾಬೇಸ್‌ನಲ್ಲಿ ಉಳಿಯುತ್ತವೆ. ಯಾವುದೇ ಬಾಹ್ಯ ಸರ್ವರ್‌ಗಳಿಗೆ ಡೇಟಾ ಕಳುಹಿಸಲಾಗುವುದಿಲ್ಲ.',
      ),
      _sectionHeader('2. ಗೂಗಲ್ ಡ್ರೈವ್ API ಬಳಕೆ ಮತ್ತು ಗೂಗಲ್ ನಿಯಮಾವಳಿ ಪಾಲನೆ'),
      _sectionBody(
        'ಆ್ಯಪ್ ಕೇವಲ ಸೀಮಿತ drive.file ಅನುಮತಿಯನ್ನು ಮಾತ್ರ ಪಡೆಯುತ್ತದೆ:\n'
        '• ನಿಮ್ಮ ಗೂಗಲ್ ಡ್ರೈವ್‌ನಲ್ಲಿ "SanghLedger_Backups" ಫೋಲ್ಡರ್‌ನಲ್ಲಿ ಮಾತ್ರ ಬ್ಯಾಕಪ್ ಉಳಿಯುತ್ತದೆ.\n'
        '• ನಿಮ್ಮ ಡ್ರೈವ್‌ನಲ್ಲಿರುವ ಇತರ ಯಾವುದೇ ಫೈಲ್‌ಗಳನ್ನು ಓದಲು ಅಥವಾ ಬದಲಾಯಿಸಲು ಆ್ಯಪ್‌ಗೆ ಅಧಿಕಾರವಿರುವುದಿಲ್ಲ.\n'
        '• ಎಲ್ಲಾ ಬ್ಯಾಕಪ್‌ಗಳು ಅಪ್‌ಲೋಡ್ ಆಗುವ ಮುನ್ನ AES-256-GCM ಮೂಲಕ ಎನ್‌ಕ್ರಿಪ್ಟ್ ಆಗುತ್ತವೆ.\n'
        '• ಗೂಗಲ್ ಲಿಮಿಟೆಡ್ ಯೂಸ್ ಪಾಲಿಸಿಗೆ ಬದ್ಧವಾಗಿದ್ದು, ನಿಮ್ಮ ಡೇಟಾವನ್ನು ಮಾರಾಟ ಮಾಡುವುದಿಲ್ಲ ಅಥವಾ ಜಾಹೀರಾತುಗಳಿಗೆ ಬಳಸುವುದಿಲ್ಲ.',
      ),
      _sectionHeader('3. ಗೂಢಲಿಪೀಕರಣ ಮತ್ತು ಭದ್ರತೆ'),
      _sectionBody(
        '• 256-ಬಿಟ್ SQLCipher ಎನ್‌ಕ್ರಿಪ್ಶನ್.\n'
        '• ಆಂಡ್ರಾಯ್ಡ್ ಕೀಸ್ಟೋರ್‌ನಲ್ಲಿ ಸುರಕ್ಷಿತ ಕೀಲಿಗಳು.\n'
        '• ಅಡ್ಮಿನ್ ಪಾಸ್‌ವರ್ಡ್ Argon2id/PBKDF2 ಹ್ಯಾಶ್ ಮೂಲಕ ರಕ್ಷಿತವಾಗಿದೆ.\n'
        '• ಹಳೆಯ ಬ್ಯಾಕಪ್‌ಗಳ ಸ್ವಯಂಚಾಲಿತ 2-ದಿನದ ರೋಲಿಂಗ್ ನಿರ್ವಹಣೆ.',
      ),
      _sectionHeader('4. ಸಾಧನದ ಅನುಮತಿಗಳು ಮತ್ತು ಬಯೋಮೆಟ್ರಿಕ್'),
      _sectionBody(
        '• ಬಯೋಮೆಟ್ರಿಕ್ ಫಿಂಗರ್‌ಪ್ರಿಂಟ್ ಆಂಡ್ರಾಯ್ಡ್ BiometricPrompt ಮೂಲಕ ಸ್ಥಳೀಯವಾಗಿ ಮಾತ್ರ ನಡೆಯುತ್ತದೆ. ಆ್ಯಪ್ ಫಿಂಗರ್‌ಪ್ರಿಂಟ್ ಡೇಟಾವನ್ನು ಸಂಗ್ರಹಿಸುವುದಿಲ್ಲ.\n'
        '• ಬ್ಯಾಕಪ್ ಮತ್ತು ರಶೀದಿಗಳನ್ನು ವಾಟ್ಸಾಪ್/SMS ಮೂಲಕ ಹಂಚಿಕೊಳ್ಳಲು ಮಾತ್ರ ಅನುಮತಿ ಬಳಸಲಾಗುತ್ತದೆ.',
      ),
      _sectionHeader('5. ಡೇಟಾ ನಿಯಂತ್ರಣ ಮತ್ತು ರದ್ದತಿ'),
      _sectionBody(
        'ಅಡ್ಮಿನ್‌ಗೆ ಸಂಪೂರ್ಣ ನಿಯಂತ್ರಣವಿದೆ. ಗೂಗಲ್ ಖಾತೆ ಅನುಮತಿಯನ್ನು ಯಾವುದೇ ಸಮಯದಲ್ಲಿ https://myaccount.google.com/permissions ಮೂಲಕ ಹಿಂಪಡೆಯಬಹುದು.',
      ),
      _sectionHeader('6. ಡೆವಲಪರ್ ಸಂಪರ್ಕ'),
      _sectionBody(
        'ಡೆವಲಪರ್: OZONE\n'
        'ಪ್ಯಾಕೇಜ್: in.sanghledger.app\n'
        'ಇಮೇಲ್: ozoneadi170@gmail.com\n'
        'GitHub: https://github.com/ozone170/sangh-ledger',
      ),
    ];
  }

  Widget _sectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(top: 12, bottom: 4),
      child: Text(
        title,
        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppColors.primaryNavy),
      ),
    );
  }

  Widget _sectionBody(String body) {
    return Text(
      body,
      style: const TextStyle(fontSize: 12, color: AppColors.textPrimary, height: 1.4),
    );
  }
}
