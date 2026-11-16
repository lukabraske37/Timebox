import 'package:flutter/material.dart';

/// Six full themes and five accents, matching the prototype.
const List<String> kThemeNames = ['dark', 'dim', 'midnight', 'amoled', 'light', 'sepia'];
const Map<String, String> kThemeLabels = {
  'dark': 'Dark',
  'dim': 'Dim',
  'midnight': 'Midnight',
  'amoled': 'AMOLED',
  'light': 'Light',
  'sepia': 'Sepia',
};

const List<String> kAccentNames = ['teal', 'indigo', 'sky', 'violet', 'rose', 'orange', 'amber', 'lime'];

class AppColors {
  final Color bg, surf, surf2, node, line;
  final Color txt, txt2, txt3;
  final Color acc, accTxt, accTint, acc2;
  final Color danger, onDanger;
  final bool isDark;

  const AppColors({
    required this.bg,
    required this.surf,
    required this.surf2,
    required this.node,
    required this.line,
    required this.txt,
    required this.txt2,
    required this.txt3,
    required this.acc,
    required this.accTxt,
    required this.accTint,
    required this.acc2,
    required this.danger,
    required this.onDanger,
    required this.isDark,
  });

  static const Map<String, List<Color>> _accents = {
    // dark accent, dark on-accent, light accent, light on-accent
    'teal': [Color(0xFF74EFD1), Color(0xFF06322A), Color(0xFF0FA98A), Color(0xFFFFFFFF)],
    'indigo': [Color(0xFFA9B8FF), Color(0xFF131A44), Color(0xFF4257C9), Color(0xFFFFFFFF)],
    'amber': [Color(0xFFF2D06B), Color(0xFF3A2A05), Color(0xFF8A6206), Color(0xFFFFFFFF)],
    'rose': [Color(0xFFFFA6A6), Color(0xFF45100F), Color(0xFFB7382F), Color(0xFFFFFFFF)],
    'lime': [Color(0xFFB6E77F), Color(0xFF1E3606), Color(0xFF4B7B12), Color(0xFFFFFFFF)],
    'sky': [Color(0xFF8CCBFF), Color(0xFF0A2A45), Color(0xFF1A6FB8), Color(0xFFFFFFFF)],
    'violet': [Color(0xFFC9ABFF), Color(0xFF2A1250), Color(0xFF6E3FD1), Color(0xFFFFFFFF)],
    'orange': [Color(0xFFFFB37A), Color(0xFF3F1C04), Color(0xFFB5590F), Color(0xFFFFFFFF)],
  };

  static AppColors resolve(String theme, String accent) {
    final a = _accents[accent] ?? _accents['teal']!;
    final light = theme == 'light' || theme == 'sepia';
    final acc = light ? a[2] : a[0];
    final accTxt = light ? a[3] : a[1];

    switch (theme) {
      case 'light':
        return AppColors(
          bg: const Color(0xFFF4F6F5),
          surf: Colors.white,
          surf2: const Color(0xFFEAEEED),
          node: const Color(0xFFE6EBEA),
          line: const Color(0xFFE1E5E4),
          txt: const Color(0xFF101413),
          txt2: const Color(0xFF5C6564),
          txt3: const Color(0xFF5F6867),
          acc: acc,
          accTxt: accTxt,
          accTint: acc.withOpacity(0.13),
          acc2: acc,
          danger: const Color(0xFFA82A21),
          onDanger: Colors.white,
          isDark: false,
        );
      case 'sepia':
        return AppColors(
          bg: const Color(0xFFF3EBDD),
          surf: const Color(0xFFFBF6EC),
          surf2: const Color(0xFFEAE0CE),
          node: const Color(0xFFE4D8C2),
          line: const Color(0xFFE0D4BE),
          txt: const Color(0xFF241E14),
          txt2: const Color(0xFF5F5442),
          txt3: const Color(0xFF6B5F4B),
          acc: acc,
          accTxt: accTxt,
          accTint: acc.withOpacity(0.13),
          acc2: acc,
          danger: const Color(0xFF9E3B22),
          onDanger: Colors.white,
          isDark: false,
        );
      case 'dim':
        return _dark(acc, accTxt,
            bg: const Color(0xFF181C21),
            surf: const Color(0xFF22272E),
            surf2: const Color(0xFF2C333B),
            node: const Color(0xFF333B44),
            line: const Color(0xFF333A42),
            txt: const Color(0xFFEEF2F6),
            txt2: const Color(0xFFA9B4C0),
            txt3: const Color(0xFF78848F));
      case 'midnight':
        return _dark(acc, accTxt,
            bg: const Color(0xFF0B0F1C),
            surf: const Color(0xFF141A2B),
            surf2: const Color(0xFF1D2539),
            node: const Color(0xFF232C43),
            line: const Color(0xFF212942),
            txt: const Color(0xFFEDF1FA),
            txt2: const Color(0xFF9FA9C4),
            txt3: const Color(0xFF727D99));
      case 'amoled':
        return _dark(acc, accTxt,
            bg: Colors.black,
            surf: const Color(0xFF0A0C0C),
            surf2: const Color(0xFF141818),
            node: const Color(0xFF161A1A),
            line: const Color(0xFF1E2222),
            txt: const Color(0xFFF2F5F4),
            txt2: const Color(0xFFA6ADAC),
            txt3: const Color(0xFF6E7776));
      default:
        return _dark(acc, accTxt,
            bg: const Color(0xFF0E1011),
            surf: const Color(0xFF191C1D),
            surf2: const Color(0xFF232728),
            node: const Color(0xFF2A2E2F),
            line: const Color(0xFF2C3132),
            txt: const Color(0xFFF2F5F4),
            txt2: const Color(0xFFA6ADAC),
            txt3: const Color(0xFF6E7776));
    }
  }

  static AppColors _dark(
    Color acc,
    Color accTxt, {
    required Color bg,
    required Color surf,
    required Color surf2,
    required Color node,
    required Color line,
    required Color txt,
    required Color txt2,
    required Color txt3,
  }) {
    return AppColors(
      bg: bg,
      surf: surf,
      surf2: surf2,
      node: node,
      line: line,
      txt: txt,
      txt2: txt2,
      txt3: txt3,
      acc: acc,
      accTxt: accTxt,
      accTint: acc.withOpacity(0.14),
      acc2: acc,
      danger: const Color(0xFFFF8A80),
      onDanger: const Color(0xFF25090A),
      isDark: true,
    );
  }

  static Color accentSwatch(String name) => (_accents[name] ?? _accents['teal']!)[0];

  /// The colour an item wears: its own from the block palette, or the accent
  /// when it has none.
  Color item(int? index) {
    if (index == null) return acc;
    final palette = isDark ? kBlockColorsDark : kBlockColorsLight;
    return palette[index % palette.length];
  }

  /// Text and icons that sit on top of [fill].
  static Color onColor(Color fill) =>
      fill.computeLuminance() > 0.30 ? const Color(0xFF10151A) : Colors.white;

  /// This palette with [accent] standing in for the accent. An editor uses it
  /// to dress itself in the colour of the thing being edited, so choosing a
  /// colour shows on every button and chip at once.
  AppColors withAccent(Color accent) {
    // Something wearing the app's own accent looks exactly like the app.
    if (accent == acc) return this;
    return AppColors(
        bg: bg,
        surf: surf,
        surf2: surf2,
        node: node,
        line: line,
        txt: txt,
        txt2: txt2,
        txt3: txt3,
        acc: accent,
        accTxt: onColor(accent),
        accTint: accent.withOpacity(isDark ? 0.14 : 0.13),
        acc2: accent,
        danger: danger,
        onDanger: onDanger,
        isDark: isDark,
      );
  }
}

/// Block colours, tuned per mode so light themes stay legible. A block stores
/// the position of its colour here, so this list is only ever added to.
const List<Color> kBlockColorsDark = [
  Color(0xFF74EFD1), // teal
  Color(0xFFF98C7B), // coral
  Color(0xFFF5C563), // amber
  Color(0xFFA7DC6A), // lime
  Color(0xFF7FA9F0), // blue
  Color(0xFF57C4D4), // cyan
  Color(0xFFB9A2FF), // violet
  Color(0xFFF79BCB), // pink
  Color(0xFFFFAA66), // orange
  Color(0xFF6FD98F), // green
  Color(0xFFD9BC9C), // sand
  Color(0xFFB4BEC9), // grey
];

const List<Color> kBlockColorsLight = [
  Color(0xFF0E8F76),
  Color(0xFFC2503C),
  Color(0xFF9A6B08),
  Color(0xFF4E7B1C),
  Color(0xFF2F5FB5),
  Color(0xFF1F7A8C),
  Color(0xFF6B4FD0),
  Color(0xFFB8377F),
  Color(0xFFB85C0F),
  Color(0xFF1F8A47),
  Color(0xFF8A6240),
  Color(0xFF56616E),
];

const List<String> kBlockColorNames = [
  'Teal', 'Coral', 'Amber', 'Lime', 'Blue', 'Cyan',
  'Violet', 'Pink', 'Orange', 'Green', 'Sand', 'Grey',
];
