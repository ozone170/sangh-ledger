import 'dart:io';
import 'package:flutter/services.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import '../../core/database/app_database.dart';

class OrgHeaderData {
  final String name;
  final String address;
  final String contactPhone;
  final String? registrationNumber;
  final Uint8List? logoBytes;

  const OrgHeaderData({
    required this.name,
    required this.address,
    required this.contactPhone,
    this.registrationNumber,
    this.logoBytes,
  });
}

class PdfBrandingHeader {
  PdfBrandingHeader._();

  /// Loads the active organization branding, prioritizing initialized user organization and custom logo
  static Future<OrgHeaderData> loadOrgHeader({String? fallbackName, String? fallbackAddress}) async {
    String name = fallbackName ?? 'Sangh Ledger';
    String address = fallbackAddress ?? 'Karnataka, India';
    String contactPhone = '';
    String? registrationNumber;
    Uint8List? logoBytes;

    try {
      final db = await AppDatabase().database;
      final orgResults = await db.query(
        'organizations',
        orderBy: 'is_initialized DESC, updated_at DESC, created_at DESC',
        limit: 1,
      );

      if (orgResults.isNotEmpty) {
        final org = orgResults.first;
        final n = org['name'] as String?;
        final a = org['address'] as String?;
        final cp = org['contact_phone'] as String?;
        final rn = org['registration_number'] as String?;
        final lp = org['logo_path'] as String?;

        if (n != null && n.trim().isNotEmpty) name = n.trim();
        if (a != null && a.trim().isNotEmpty) address = a.trim();
        if (cp != null && cp.trim().isNotEmpty) contactPhone = cp.trim();
        if (rn != null && rn.trim().isNotEmpty) registrationNumber = rn.trim();

        if (lp != null && lp.trim().isNotEmpty) {
          final file = File(lp.trim());
          if (await file.exists()) {
            logoBytes = await file.readAsBytes();
          }
        }
      }

      // Check standard sangh_logo.png in app docs directory if not loaded from path
      if (logoBytes == null) {
        final docDir = await getApplicationDocumentsDirectory();
        final docLogo = File(p.join(docDir.path, 'sangh_logo.png'));
        if (await docLogo.exists()) {
          logoBytes = await docLogo.readAsBytes();
        }
      }

      // Fallback to bundled app emblem if still null
      if (logoBytes == null) {
        try {
          final assetData = await rootBundle.load('assets/images/app_logo.png');
          logoBytes = assetData.buffer.asUint8List();
        } catch (_) {}
      }
    } catch (_) {}

    return OrgHeaderData(
      name: name,
      address: address,
      contactPhone: contactPhone,
      registrationNumber: registrationNumber,
      logoBytes: logoBytes,
    );
  }

  /// Builds the standardized letterhead widget for reports and receipts
  static pw.Widget buildHeader({
    required OrgHeaderData data,
    String? subTitle,
    String? dateStr,
    String? timeStr,
    bool isReceipt = false,
  }) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Row(
          crossAxisAlignment: pw.CrossAxisAlignment.center,
          children: [
            if (data.logoBytes != null)
              pw.Container(
                width: 48,
                height: 48,
                margin: const pw.EdgeInsets.only(right: 12),
                child: pw.Image(pw.MemoryImage(data.logoBytes!)),
              ),
            pw.Expanded(
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text(
                    data.name,
                    style: pw.TextStyle(
                      fontSize: isReceipt ? 16 : 15,
                      fontWeight: pw.FontWeight.bold,
                      color: PdfColors.blueGrey900,
                    ),
                  ),
                  pw.SizedBox(height: 2),
                  pw.Text(
                    data.address,
                    style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey700),
                  ),
                  if (data.contactPhone.isNotEmpty || (data.registrationNumber != null && data.registrationNumber!.isNotEmpty))
                    pw.Text(
                      [
                        if (data.contactPhone.isNotEmpty) 'Phone: ${data.contactPhone}',
                        if (data.registrationNumber != null && data.registrationNumber!.isNotEmpty)
                          'Reg No: ${data.registrationNumber}',
                      ].join(' | '),
                      style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey600),
                    ),
                ],
              ),
            ),
            if (dateStr != null)
              pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.end,
                children: [
                  pw.Text(
                    'Date: $dateStr',
                    style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey700),
                  ),
                  if (timeStr != null)
                    pw.Text(
                      timeStr,
                      style: const pw.TextStyle(fontSize: 7, color: PdfColors.grey600),
                    ),
                ],
              ),
          ],
        ),
        if (subTitle != null && subTitle.isNotEmpty) ...[
          pw.SizedBox(height: 8),
          pw.Container(
            width: double.infinity,
            padding: const pw.EdgeInsets.symmetric(vertical: 4, horizontal: 8),
            decoration: const pw.BoxDecoration(color: PdfColors.grey100),
            child: pw.Text(
              subTitle,
              style: pw.TextStyle(
                fontSize: 12,
                fontWeight: pw.FontWeight.bold,
                color: PdfColors.blueGrey800,
              ),
            ),
          ),
        ],
        pw.SizedBox(height: 8),
        pw.Divider(thickness: 1, color: PdfColors.grey300),
        pw.SizedBox(height: 6),
      ],
    );
  }
}
