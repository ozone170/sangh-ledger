// ignore_for_file: avoid_print, unused_local_variable
import 'dart:io';
import 'dart:math';
import 'package:image/image.dart' as img;

void main() {
  final sizes = {
    'mipmap-mdpi': 48,
    'mipmap-hdpi': 72,
    'mipmap-xhdpi': 96,
    'mipmap-xxhdpi': 144,
    'mipmap-xxxhdpi': 192,
  };

  for (final entry in sizes.entries) {
    final folder = entry.key;
    final size = entry.value;
    final image = _generateSanghIcon(size);
    final targetDir = Directory('android/app/src/main/res/$folder');
    if (!targetDir.existsSync()) {
      targetDir.createSync(recursive: true);
    }
    final file = File('${targetDir.path}/ic_launcher.png');
    file.writeAsBytesSync(img.encodePng(image));
    print('Generated ${file.path} (${size}x$size)');
  }

  // Also save a master 512x512 app logo in assets/images/app_logo.png
  final masterDir = Directory('assets/images');
  if (!masterDir.existsSync()) {
    masterDir.createSync(recursive: true);
  }
  final masterImage = _generateSanghIcon(512);
  File('assets/images/app_logo.png').writeAsBytesSync(img.encodePng(masterImage));
  print('Generated assets/images/app_logo.png (512x512)');
}

img.Image _generateSanghIcon(int size) {
  final image = img.Image(width: size, height: size, numChannels: 4);

  final center = size / 2.0;
  final radius = size * 0.46;

  // Background colors
  final navyColor = img.ColorRgba8(15, 23, 42, 255); // #0F172A
  final goldColor = img.ColorRgba8(245, 158, 11, 255); // #F59E0B
  final tealColor = img.ColorRgba8(13, 148, 136, 255); // #0D9488
  final whiteColor = img.ColorRgba8(255, 255, 255, 255);
  final lightGoldColor = img.ColorRgba8(252, 211, 77, 255); // #FCD34D

  // Fill outer transparent
  img.fill(image, color: img.ColorRgba8(0, 0, 0, 0));

  // Draw circular base navy background
  img.fillCircle(
    image,
    x: center.round(),
    y: center.round(),
    radius: radius.round(),
    color: navyColor,
  );

  // Outer gold ring
  img.drawCircle(
    image,
    x: center.round(),
    y: center.round(),
    radius: radius.round(),
    color: goldColor,
  );
  img.drawCircle(
    image,
    x: center.round(),
    y: center.round(),
    radius: (radius - 1).round(),
    color: lightGoldColor,
  );

  // Inner teal accent circle
  final innerRadius = radius * 0.86;
  img.drawCircle(
    image,
    x: center.round(),
    y: center.round(),
    radius: innerRadius.round(),
    color: tealColor,
  );

  // Draw classical financial ledger emblem (Pediment, Columns, Base)
  final s = size / 100.0; // scale factor (size = 100 * s)

  // 1. Triangular Pediment / Roof
  final roofTopY = (center - 24 * s).round();
  final roofBottomY = (center - 13 * s).round();
  final roofLeftX = (center - 28 * s).round();
  final roofRightX = (center + 28 * s).round();
  final roofCenterX = center.round();

  // Roof triangle fill
  for (int y = roofTopY; y <= roofBottomY; y++) {
    final progress = (y - roofTopY) / (roofBottomY - roofTopY);
    final curHalfW = (28 * s * progress).round();
    img.drawLine(
      image,
      x1: roofCenterX - curHalfW,
      y1: y,
      x2: roofCenterX + curHalfW,
      y2: y,
      color: goldColor,
    );
  }

  // Small gold architrave under roof
  img.fillRect(
    image,
    x1: (center - 26 * s).round(),
    y1: (center - 13 * s).round(),
    x2: (center + 26 * s).round(),
    y2: (center - 10 * s).round(),
    color: lightGoldColor,
  );

  // 2. Pillars (4 classic ledger columns)
  final pillarTopY = (center - 9 * s).round();
  final pillarBottomY = (center + 14 * s).round();
  final pillarWidth = max(2, (4 * s).round());

  final pillarOffsets = [-20 * s, -7 * s, 7 * s, 20 * s];
  for (final offset in pillarOffsets) {
    final px = (center + offset).round() - (pillarWidth ~/ 2);
    img.fillRect(
      image,
      x1: px,
      y1: pillarTopY,
      x2: px + pillarWidth,
      y2: pillarBottomY,
      color: whiteColor,
    );
  }

  // 3. Base / Steps
  img.fillRect(
    image,
    x1: (center - 28 * s).round(),
    y1: (center + 15 * s).round(),
    x2: (center + 28 * s).round(),
    y2: (center + 19 * s).round(),
    color: lightGoldColor,
  );
  img.fillRect(
    image,
    x1: (center - 32 * s).round(),
    y1: (center + 20 * s).round(),
    x2: (center + 32 * s).round(),
    y2: (center + 24 * s).round(),
    color: goldColor,
  );

  // 4. Central Rupee emblem symbol in middle
  // Draw an elegant gold circle badge in center
  final badgeRadius = (7.5 * s).round();
  img.fillCircle(
    image,
    x: center.round(),
    y: (center + 2 * s).round(),
    radius: badgeRadius,
    color: navyColor,
  );
  img.drawCircle(
    image,
    x: center.round(),
    y: (center + 2 * s).round(),
    radius: badgeRadius,
    color: goldColor,
  );

  // Rupee horizontal bars in center badge
  final rupeeY = (center + 2 * s).round();
  final rupeeHalfW = (4 * s).round();
  img.drawLine(
    image,
    x1: center.round() - rupeeHalfW,
    y1: rupeeY - (3 * s).round(),
    x2: center.round() + rupeeHalfW,
    y2: rupeeY - (3 * s).round(),
    color: goldColor,
  );
  img.drawLine(
    image,
    x1: center.round() - rupeeHalfW,
    y1: rupeeY - (1 * s).round(),
    x2: center.round() + (rupeeHalfW * 0.8).round(),
    y2: rupeeY - (1 * s).round(),
    color: lightGoldColor,
  );
  img.drawLine(
    image,
    x1: center.round() - (2 * s).round(),
    y1: rupeeY - (3 * s).round(),
    x2: center.round() - (2 * s).round(),
    y2: rupeeY + (4 * s).round(),
    color: goldColor,
  );
  img.drawLine(
    image,
    x1: center.round() - (1 * s).round(),
    y1: rupeeY + (1 * s).round(),
    x2: center.round() + (3 * s).round(),
    y2: rupeeY + (4 * s).round(),
    color: lightGoldColor,
  );

  return image;
}
