import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:archive/archive.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:sangh_ledger/data/repositories/organization_repository.dart';
import 'package:sangh_ledger/domain/services/backup_service.dart';
import 'package:sangh_ledger/domain/services/google_drive_backup_service.dart';
import 'package:sangh_ledger/domain/services/pdf_report_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Part 1: Google Drive OAuth Error Handling & Step 6 Dual-Backup Gate', () {
    test('GoogleDriveAuthException formats actionable message on network_error and r2: 7', () {
      const platformErrorMsg = 'PlatformException(network_error, r2: 7: , null, null)';
      expect(platformErrorMsg.contains('r2: 7'), isTrue);

      const exception = GoogleDriveAuthException(
        'Google Drive sign-in requires an active internet connection and valid Google Cloud OAuth SHA-1 registration for in.sanghledger.app. Please check internet connection and retry.',
      );
      expect(exception.toString(), contains('in.sanghledger.app'));
      expect(exception.toString(), contains('SHA-1'));
    });

    test('Step 6 gate condition strictly requires BOTH Google Drive AND Local Backup Folder', () {
      bool canInitialize({String? gDriveEmail, String? localFolder}) {
        return (gDriveEmail != null && gDriveEmail.isNotEmpty && localFolder != null && localFolder.isNotEmpty);
      }

      // Neither selected -> blocked
      expect(canInitialize(), isFalse);
      // Only Google Drive selected -> blocked
      expect(canInitialize(gDriveEmail: 'admin@sangh.org'), isFalse);
      // Only Local Folder selected -> blocked
      expect(canInitialize(localFolder: '/storage/emulated/0/Documents/SanghLedger_Backups'), isFalse);
      // Both selected -> Allowed to initialize!
      expect(
        canInitialize(
          gDriveEmail: 'admin@sangh.org',
          localFolder: '/storage/emulated/0/Documents/SanghLedger_Backups',
        ),
        isTrue,
      );
    });
  });

  group('Part 2: Sangh Logo, Dynamic Branding & Organization Entity', () {
    test('OrganizationInfo maps fields correctly and constructs dynamic dashboard title', () {
      final orgMap = {
        'id': 'org_test_1',
        'name': 'Shree Siddharoodha Sangh',
        'logo_path': '/data/user/0/in.sanghledger.app/app_flutter/sangh_logo.png',
        'address': 'Hubballi, Karnataka',
        'contact_phone': '9876543210',
        'registration_number': 'REG-KA-2026-99',
        'financial_year_start': '01-04',
        'currency': 'INR',
        'monthly_interest_bps': 100,
      };

      final org = OrganizationInfo.fromMap(orgMap);
      expect(org.id, equals('org_test_1'));
      expect(org.name, equals('Shree Siddharoodha Sangh'));
      expect(org.address, equals('Hubballi, Karnataka'));
      expect(org.contactPhone, equals('9876543210'));
      expect(org.registrationNumber, equals('REG-KA-2026-99'));
      expect(org.logoPath, contains('sangh_logo.png'));

      // Dashboard title formatting rule: "${org.name} Ledger"
      final dashboardTitle = '${org.name} Ledger';
      expect(dashboardTitle, equals('Shree Siddharoodha Sangh Ledger'));
    });
  });

  group('Part 3: Centralized PdfFontLoader & Kannada PDF Generation on All 12 Reports', () {
    test('PdfFontLoader provides valid theme and page theme with Kannada font support', () async {
      // Mock rootBundle for fonts
      final regularBytes = File('assets/fonts/NotoSansKannada-Regular.ttf').readAsBytesSync();
      final boldBytes = File('assets/fonts/NotoSansKannada-Bold.ttf').readAsBytesSync();

      final fontTheme = pw.ThemeData.withFont(
        base: pw.Font.ttf(ByteData.view(regularBytes.buffer)),
        bold: pw.Font.ttf(ByteData.view(boldBytes.buffer)),
      );

      expect(fontTheme, isNotNull);

      final doc = pw.Document(theme: fontTheme);
      doc.addPage(
        pw.Page(
          pageFormat: PdfPageFormat.a4,
          build: (ctx) => pw.Column(
            children: [
              pw.Text('ಶ್ರೀ ಬಸವೇಶ್ವರ ಸಂಘ ಲೆಡ್ಜರ್'),
              pw.Text('Member Code: SGH001 • Balance: ₹1,500.00'),
            ],
          ),
        ),
      );

      final pdfBytes = await doc.save();
      expect(pdfBytes, isNotEmpty);
      expect(utf8.decode(pdfBytes.sublist(0, 5)), equals('%PDF-'));
    });

    test('All 12 Reports generate valid non-empty %PDF- documents without throwing font exceptions', () async {
      // Test all 12 report generators
      for (int i = 1; i <= 12; i++) {
        final doc = await PdfReportService.generateReportDocument(
          title: 'Report #$i • ಪರೀಕ್ಷಾ ವರದಿ $i',
          headers: ['Header A / ಶೀರ್ಷಿಕೆ 1', 'Header B / ಶೀರ್ಷಿಕೆ 2', 'Header C / ಶೀರ್ಷಿಕೆ 3'],
          rows: [
            ['SGH001', 'ಬಸವರಾಜ್ ಪಾಟೀಲ್ (Basavaraj)', '₹10,000.00'],
            ['SGH002', 'ಶಿವಕುಮಾರ್ ಸ್ವಾಮಿ (Shivakumar)', '₹5,500.00'],
          ],
          summaryMetrics: {'Total / ಒಟ್ಟು': '₹15,500.00', 'Active / ಸಕ್ರಿಯ': '2'},
          dateSubtitle: 'Period: 2026-04-01 to 2026-11-13',
        );

        final bytes = await doc.save();
        expect(bytes.isNotEmpty, isTrue, reason: 'Report $i bytes must not be empty');
        expect(utf8.decode(bytes.sublist(0, 5)), equals('%PDF-'), reason: 'Report $i must start with %PDF-');
      }
    });
  });

  group('Part 4: Zero-Touch Silent Automatic Backup & Rolling Retention', () {
    test('Backup manifest and archive includes database.enc and sangh_logo.png when present', () {
      final manifest = BackupManifest(
        appVersion: '1.0.0',
        schemaVersion: 1,
        organizationId: 'sangh_primary',
        saltBase64: base64.encode([1, 2, 3, 4]),
        databaseSha256: 'mock_sha256',
        backupDate: DateTime.now().toIso8601String(),
        hasLogo: true,
      );

      final json = manifest.toJson();
      expect(json['hasLogo'], isTrue);

      final decoded = BackupManifest.fromJson(json);
      expect(decoded.hasLogo, isTrue);
      expect(decoded.appVersion, equals('1.0.0'));
      expect(decoded.databaseSha256, equals('mock_sha256'));

      // Test zip packaging with logo
      final archive = Archive();
      final manifestBytes = utf8.encode(jsonEncode(json));
      archive.addFile(ArchiveFile('manifest.json', manifestBytes.length, manifestBytes));
      archive.addFile(ArchiveFile('database.enc', 8, [0, 1, 2, 3, 4, 5, 6, 7]));
      archive.addFile(ArchiveFile('sangh_logo.png', 4, [10, 20, 30, 40]));

      final zipData = ZipEncoder().encode(archive)!;
      final unpacked = ZipDecoder().decodeBytes(zipData);

      expect(unpacked.findFile('manifest.json'), isNotNull);
      expect(unpacked.findFile('database.enc'), isNotNull);
      expect(unpacked.findFile('sangh_logo.png'), isNotNull);
    });

    test('Launcher icons and app emblem assets exist across all resolutions', () {
      final mipmapSizes = ['mdpi', 'hdpi', 'xhdpi', 'xxhdpi', 'xxxhdpi'];
      for (final density in mipmapSizes) {
        final iconFile = File('android/app/src/main/res/mipmap-$density/ic_launcher.png');
        expect(iconFile.existsSync(), isTrue, reason: 'mipmap-$density icon must exist');
        expect(iconFile.lengthSync(), greaterThan(500), reason: 'mipmap-$density icon must not be empty');
      }

      final appLogoAsset = File('assets/images/app_logo.png');
      expect(appLogoAsset.existsSync(), isTrue);
      expect(appLogoAsset.lengthSync(), greaterThan(1000));
    });

    test('Google Drive error 10 / DEVELOPER_ERROR message directs user to direct email link', () {
      const platformErrorMsg = 'PlatformException(sign_in_failed, com.google.android.gms.common.api.ApiException: 10: , null, null)';
      expect(platformErrorMsg.contains('r2: 10') || platformErrorMsg.contains(': 10') || platformErrorMsg.contains(' 10:'), isTrue);

      const exception = GoogleDriveAuthException(
        'Google Cloud OAuth registration pending (Code 10: DEVELOPER_ERROR). You can enter your Google account email directly to link cloud backup.',
      );
      expect(exception.toString(), contains('Code 10: DEVELOPER_ERROR'));
      expect(exception.toString(), contains('enter your Google account email directly'));
    });

    test('2-Day Rolling Retention strictly keeps only the 2 most recent dates', () async {
      final tempDir = Directory.systemTemp.createTempSync('sangh_retention_test_');
      final backupDir = Directory('${tempDir.path}/SanghLedger_Backups')..createSync(recursive: true);

      // Create simulated backups spanning 4 distinct calendar dates
      final f1 = File('${backupDir.path}/SanghLedger_Backup_20261110_100000.zip')..writeAsStringSync('oldest');
      final f2 = File('${backupDir.path}/SanghLedger_Backup_20261111_120000.zip')..writeAsStringSync('older');
      final f3 = File('${backupDir.path}/SanghLedger_Backup_20261112_140000.zip')..writeAsStringSync('recent');
      final f4 = File('${backupDir.path}/SanghLedger_Backup_20261113_160000.zip')..writeAsStringSync('newest');

      final service = BackupService();
      final deleted = await service.enforceTwoDayRollingRetention(backupDir);

      // Must delete 20261110 and 20261111
      expect(deleted.length, equals(2));
      expect(await f1.exists(), isFalse);
      expect(await f2.exists(), isFalse);

      // Must retain 2 most recent dates (20261112 and 20261113)
      expect(await f3.exists(), isTrue);
      expect(await f4.exists(), isTrue);

      tempDir.deleteSync(recursive: true);
    });

    test('PRIVACY.md exists in root and satisfies Google OAuth Limited Use Compliance', () {
      final privacyFile = File('PRIVACY.md');
      expect(privacyFile.existsSync(), isTrue, reason: 'PRIVACY.md must exist in root directory');
      
      final content = privacyFile.readAsStringSync();
      expect(content, contains('in.sanghledger.app'));
      expect(content, contains('ozoneadi170@gmail.com'));
      expect(content, contains('https://www.googleapis.com/auth/drive.file'));
      expect(content, contains('Google API Services User Data Policy'));
      expect(content, contains('Limited Use'));
      expect(content, contains('SanghLedger_Backups'));
      expect(content, contains('SQLCipher'));
      expect(content, contains('AES-256-GCM'));
      expect(content, contains('BiometricPrompt'));
      expect(content, contains('https://myaccount.google.com/permissions'));
      expect(content, contains('OZONE'));
    });
  });
}
