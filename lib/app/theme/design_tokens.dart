import 'package:flutter/material.dart';

// ─────────────────────────────────────────────────────────
// NunaKin Design Tokens
// Fuente canónica: docs/ui/design_system.md
//
// Uso: reemplazar literales de color/spacing/radius/duración
// en widgets por las constantes de este archivo.
// ─────────────────────────────────────────────────────────

// ── Colores ──────────────────────────────────────────────

abstract final class NkColors {
  // Canvas
  static const Color canvas   = Color(0xFF000000);

  // Marca / acento / CTA primario / success — un solo mint
  static const Color mint     = Color(0xFF1CE8A1);
  static const Color mintDeep = Color(0xFF17C98C); // pressed state
  static       Color mintSoft(double opacity) => mint.withValues(alpha: opacity);

  // Foreground sobre canvas y superficies oscuras
  static const Color onDark   = Color(0xFFFFFFFF);
  static const Color fgMuted  = Color(0xCCFFFFFF); // 80%
  static const Color fgSub    = Color(0x99FFFFFF); // 60%
  static const Color fgHint   = Color(0x66FFFFFF); // 40%
  static const Color fgDisabled = Color(0x40FFFFFF); // 25%

  // Superficies (dark-on-black)
  static const Color surface1 = Color(0xFF000000); // canvas
  static const Color surface2 = Color(0xFF1C1C1E); // cards / dialogs (iOS grouped bg)
  static const Color surface3 = Color(0xFF2C2C2E); // inputs / fills (iOS secondary bg)
  static const Color surface4 = Color(0xFF3A3A3C); // hover / pressed

  // Borde / línea de separación
  static const Color line     = Color(0x1AFFFFFF); // rgba(255,255,255,0.10)

  // SOS y acciones destructivas — rojo Material 700
  static const Color danger   = Color(0xFFD32F2F);
  static const Color dangerSoft = Color(0x33D32F2F); // 20%

  // Glow del CTA primario
  static const Color mintGlow = Color(0x291CE8A1); // rgba(28,232,161,0.16)

  // Foreground sobre mint (botón primario)
  static const Color onMint   = Color(0xFF000000);
}

// ── Espaciado (grid de 4pt) ───────────────────────────────

abstract final class NkSpacing {
  static const double xs1  = 4;
  static const double xs2  = 8;
  static const double xs3  = 12;
  static const double s    = 16;   // gap entre ítems
  static const double s5   = 20;
  static const double m    = 24;   // padding default de cards / CTAs laterales
  static const double l    = 32;   // gap entre secciones
  static const double xl   = 40;
  static const double xl2  = 48;
  static const double xxl  = 64;

  // Touch target mínimo (HIG)
  static const double touchTarget = 44;
}

// ── Radios ────────────────────────────────────────────────

abstract final class NkRadius {
  static const double small  = 8;
  static const double input  = 12;
  static const double button = 16;
  static const double card   = 20;
  static const double modal  = 24;
  static const double pill   = 999;

  static BorderRadius forSmall  = BorderRadius.circular(small);
  static BorderRadius forInput  = BorderRadius.circular(input);
  static BorderRadius forButton = BorderRadius.circular(button);
  static BorderRadius forCard   = BorderRadius.circular(card);
  static BorderRadius forModal  = BorderRadius.circular(modal);
  static BorderRadius forPill   = BorderRadius.circular(pill);
}

// ── Tipografía ────────────────────────────────────────────

abstract final class NkTextStyle {
  // Tamaños: 32 / 28 / 22 / 18 / 16 / 14 / 12
  // Pesos: 400 / 500 / 600 / 700
  // Fuente: sistema operativo nativo (SF Pro en iOS, Roboto en Android)

  static const TextStyle display = TextStyle(
    fontSize: 32, fontWeight: FontWeight.w700, color: NkColors.onDark,
  );
  static const TextStyle h1 = TextStyle(
    fontSize: 28, fontWeight: FontWeight.w700, color: NkColors.onDark,
  );
  static const TextStyle h2 = TextStyle(
    fontSize: 22, fontWeight: FontWeight.w600, color: NkColors.onDark,
  );
  static const TextStyle h3 = TextStyle(
    fontSize: 18, fontWeight: FontWeight.w600, color: NkColors.onDark,
  );
  static const TextStyle body = TextStyle(
    fontSize: 16, fontWeight: FontWeight.w400, color: NkColors.onDark,
  );
  static const TextStyle meta = TextStyle(
    fontSize: 14, fontWeight: FontWeight.w400, color: NkColors.fgMuted,
  );
  static const TextStyle micro = TextStyle(
    fontSize: 12, fontWeight: FontWeight.w400, color: NkColors.fgSub,
  );

  // Mono — solo para códigos de invitación, build numbers, debug tags
  static const TextStyle mono = TextStyle(
    fontSize: 16, fontWeight: FontWeight.w500,
    fontFamily: 'monospace', letterSpacing: 2.0,
    color: NkColors.onDark,
  );
}

// ── Duraciones de animación ───────────────────────────────

abstract final class NkDuration {
  static const Duration press    = Duration(milliseconds: 100);
  static const Duration hover    = Duration(milliseconds: 120);
  static const Duration modal    = Duration(milliseconds: 200);
  static const Duration fade     = Duration(milliseconds: 300);
  static const Duration splash   = Duration(seconds: 2);
}

// ── Curvas de animación ───────────────────────────────────

abstract final class NkCurve {
  static const Curve standard   = Curves.easeInOut;
  static const Curve emphasis   = Curves.easeOutCubic;  // --nk-ease-emph
  static const Curve fadeIn     = Curves.easeIn;
}

// ── Sombras / elevación ───────────────────────────────────

abstract final class NkShadow {
  // Glow del CTA primario
  static const List<BoxShadow> ctaGlow = [
    BoxShadow(color: NkColors.mintGlow, blurRadius: 24, spreadRadius: 0),
  ];

  // Sombra de modal (z elevado)
  static const List<BoxShadow> modal = [
    BoxShadow(
      color: Color(0x66000000),
      blurRadius: 32, offset: Offset(0, 8),
    ),
  ];
}
