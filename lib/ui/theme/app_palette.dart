import 'package:flutter/material.dart';

@immutable
final class AppPalette extends ThemeExtension<AppPalette> {

  const AppPalette({
    required this.bg0, required this.bg1, required this.bg2, required this.bg3,
    required this.bg4, required this.bg5, required this.bgAccent,
    required this.border, required this.borderStrong,
    required this.fg0, required this.fg1, required this.fg2, required this.fg3,
    required this.accentCurrent, required this.accentTag,
    required this.accentRemote,
    required this.accentWarn, required this.accentErr,
    required this.lanePalette,
  });

  factory AppPalette.dark() => const AppPalette(
    bg0: Color(0xFF1A1A1D), bg1: Color(0xFF1F1F23), bg2: Color(0xFF25252A),
    bg3: Color(0xFF2C2C31), bg4: Color(0xFF34343A), bg5: Color(0xFF3D3D44),
    bgAccent: Color(0xFF094771),
    border: Color(0xFF313137), borderStrong: Color(0xFF404048),
    fg0: Color(0xFFD4D4D4), fg1: Color(0xFFB8B8BC),
    fg2: Color(0xFF888892), fg3: Color(0xFF5D5D65),
    accentCurrent: Color(0xFF4EC9B0), accentTag: Color(0xFFD7BA7D),
    accentRemote: Color(0xFF569CD6), accentWarn: Color(0xFFCE9178),
    accentErr: Color(0xFFF48771),
    lanePalette: [
      Color(0xFF5FB3A1), Color(0xFFD6C068), Color(0xFF6FA8DC),
      Color(0xFFC97C5D),
      Color(0xFFB787B3), Color(0xFF7A98C9), Color(0xFFC79A5D),
      Color(0xFFC97078),
    ],
  );

  factory AppPalette.light() => const AppPalette(
    bg0: Color(0xFFFAFAFB), bg1: Color(0xFFFFFFFF), bg2: Color(0xFFF4F4F6),
    bg3: Color(0xFFECECEE), bg4: Color(0xFFE4E4E7), bg5: Color(0xFFD8D8DC),
    bgAccent: Color(0xFFCFE5FF),
    border: Color(0xFFD8D8DC), borderStrong: Color(0xFFC0C0C7),
    fg0: Color(0xFF202024), fg1: Color(0xFF414148),
    fg2: Color(0xFF6E6E78), fg3: Color(0xFF9A9AA2),
    accentCurrent: Color(0xFF1B9E83), accentTag: Color(0xFFA87514),
    accentRemote: Color(0xFF2A6BB1), accentWarn: Color(0xFFA0552C),
    accentErr: Color(0xFFB92C2C),
    lanePalette: [
      Color(0xFF2B8C73), Color(0xFF8E7A1C), Color(0xFF2A6BB1),
      Color(0xFFA0552C),
      Color(0xFF7E4B7C), Color(0xFF456493), Color(0xFF8F6A1C),
      Color(0xFFA84858),
    ],
  );
  final Color bg0;
  final Color bg1;
  final Color bg2;
  final Color bg3;
  final Color bg4;
  final Color bg5;
  final Color bgAccent;
  final Color border;
  final Color borderStrong;
  final Color fg0;
  final Color fg1;
  final Color fg2;
  final Color fg3;
  final Color accentCurrent;
  final Color accentTag;
  final Color accentRemote;
  final Color accentWarn;
  final Color accentErr;
  final List<Color> lanePalette;

  @override
  AppPalette copyWith({
    Color? bg0, Color? bg1, Color? bg2, Color? bg3, Color? bg4, Color? bg5,
    Color? bgAccent, Color? border, Color? borderStrong,
    Color? fg0, Color? fg1, Color? fg2, Color? fg3,
    Color? accentCurrent, Color? accentTag, Color? accentRemote,
    Color? accentWarn, Color? accentErr,
    List<Color>? lanePalette,
  }) {
    return AppPalette(
      bg0: bg0 ?? this.bg0, bg1: bg1 ?? this.bg1, bg2: bg2 ?? this.bg2,
      bg3: bg3 ?? this.bg3, bg4: bg4 ?? this.bg4, bg5: bg5 ?? this.bg5,
      bgAccent: bgAccent ?? this.bgAccent,
      border: border ?? this.border,
      borderStrong: borderStrong ?? this.borderStrong,
      fg0: fg0 ?? this.fg0, fg1: fg1 ?? this.fg1,
      fg2: fg2 ?? this.fg2, fg3: fg3 ?? this.fg3,
      accentCurrent: accentCurrent ?? this.accentCurrent,
      accentTag: accentTag ?? this.accentTag,
      accentRemote: accentRemote ?? this.accentRemote,
      accentWarn: accentWarn ?? this.accentWarn,
      accentErr: accentErr ?? this.accentErr,
      lanePalette: lanePalette ?? this.lanePalette,
    );
  }

  @override
  AppPalette lerp(ThemeExtension<AppPalette>? other, double t) {
    if (other is! AppPalette) return this;
    return AppPalette(
      bg0: Color.lerp(bg0, other.bg0, t)!, bg1: Color.lerp(bg1, other.bg1, t)!,
      bg2: Color.lerp(bg2, other.bg2, t)!, bg3: Color.lerp(bg3, other.bg3, t)!,
      bg4: Color.lerp(bg4, other.bg4, t)!, bg5: Color.lerp(bg5, other.bg5, t)!,
      bgAccent: Color.lerp(bgAccent, other.bgAccent, t)!,
      border: Color.lerp(border, other.border, t)!,
      borderStrong: Color.lerp(borderStrong, other.borderStrong, t)!,
      fg0: Color.lerp(fg0, other.fg0, t)!, fg1: Color.lerp(fg1, other.fg1, t)!,
      fg2: Color.lerp(fg2, other.fg2, t)!, fg3: Color.lerp(fg3, other.fg3, t)!,
      accentCurrent: Color.lerp(accentCurrent, other.accentCurrent, t)!,
      accentTag: Color.lerp(accentTag, other.accentTag, t)!,
      accentRemote: Color.lerp(accentRemote, other.accentRemote, t)!,
      accentWarn: Color.lerp(accentWarn, other.accentWarn, t)!,
      accentErr: Color.lerp(accentErr, other.accentErr, t)!,
      lanePalette: lanePalette, // not lerped — palette swap is discrete
    );
  }

  static AppPalette of(BuildContext context) =>
      Theme.of(context).extension<AppPalette>()!;
}
