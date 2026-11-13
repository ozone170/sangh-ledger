import 'package:flutter/services.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

class PdfFontLoader {
  static pw.Font? _regular;
  static pw.Font? _bold;

  /// Loads and caches NotoSansKannada-Regular
  static Future<pw.Font> get regular async {
    if (_regular != null) return _regular!;
    final data = await rootBundle.load('assets/fonts/NotoSansKannada-Regular.ttf');
    _regular = pw.Font.ttf(data);
    return _regular!;
  }

  /// Loads and caches NotoSansKannada-Bold
  static Future<pw.Font> get bold async {
    if (_bold != null) return _bold!;
    try {
      final data = await rootBundle.load('assets/fonts/NotoSansKannada-Bold.ttf');
      _bold = pw.Font.ttf(data);
    } catch (_) {
      _bold = await regular;
    }
    return _bold!;
  }

  /// Returns global pw.ThemeData configured with NotoSansKannada font family
  /// to eliminate any missing glyph boxes (□□□) in Kannada, English, numbers & symbols.
  static Future<pw.ThemeData> getThemeData() async {
    final reg = await regular;
    final b = await bold;
    return pw.ThemeData.withFont(
      base: reg,
      bold: b,
      italic: reg,
      boldItalic: b,
    );
  }

  /// Returns standardized pw.PageTheme with Kannada fonts and uniform margins
  static Future<pw.PageTheme> getPageTheme({
    PdfPageFormat pageFormat = PdfPageFormat.a4,
    pw.EdgeInsets margin = const pw.EdgeInsets.all(28),
  }) async {
    final theme = await getThemeData();
    return pw.PageTheme(
      pageFormat: pageFormat,
      margin: margin,
      theme: theme,
    );
  }
}

