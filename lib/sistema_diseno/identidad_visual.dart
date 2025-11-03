import 'package:flutter/material.dart';

/// Define la paleta de colores principal para el tema claro.
class ColoresBase {
  static const Color fondoPrincipal = Color(0xFFF3F4F6);
  static const Color fondoTarjetas = Color(0xFFFFFFFF);
  static const Color fondoAlternativo = Color(0xFFE5E7EB);
  static const Color textoPrincipal = Color(0xFF1E3A8A);
  static const Color textoSecundario = Color(0xFF374151);
  static const Color textoTerciario = Color(0xFF6B7280);
}

/// Define la paleta de colores principal para el tema oscuro.
class ColoresBaseOscuro {
  static const Color fondoPrincipal = Color(0xFF111827);
  static const Color fondoTarjetas = Color(0xFF1F2937);
  static const Color fondoAlternativo = Color(0xFF0F172A);
  static const Color textoPrincipal = Color(0xFFE5E7EB);
  static const Color textoSecundario = Color(0xFFCBD5F5);
  static const Color textoTerciario = Color(0xFF94A3B8);
}

/// Colores de acciones y estados comunes en ambos modos.
class ColoresAcciones {
  static const Color primario = Color(0xFF2563EB);
  static const Color secundario = Color(0xFF3B82F6);
  static const Color neutro = Color(0xFF9CA3AF);
  static const Color exito = Color(0xFF10B981);
  static const Color advertencia = Color(0xFFF59E0B);
  static const Color error = Color(0xFFEF4444);
  static const Color informacion = Color(0xFF0EA5E9);
}

/// Tokens de color para alertas contextuales.
class EstiloAlerta {
  final Color fondo;
  final Color borde;
  final Color texto;

  const EstiloAlerta({
    required this.fondo,
    required this.borde,
    required this.texto,
  });
}

class AlertasColores {
  static const EstiloAlerta exito = EstiloAlerta(
    fondo: Color(0xFFECFDF5),
    borde: Color(0xFF10B981),
    texto: Color(0xFF065F46),
  );

  static const EstiloAlerta error = EstiloAlerta(
    fondo: Color(0xFFFEF2F2),
    borde: Color(0xFFEF4444),
    texto: Color(0xFF7F1D1D),
  );

  static const EstiloAlerta advertencia = EstiloAlerta(
    fondo: Color(0xFFFFFBEB),
    borde: Color(0xFFF59E0B),
    texto: Color(0xFF78350F),
  );

  static const EstiloAlerta informacion = EstiloAlerta(
    fondo: Color(0xFFEFF6FF),
    borde: Color(0xFF3B82F6),
    texto: Color(0xFF1E40AF),
  );
}

/// Definiciones para bordes y separadores.
class Bordes {
  static const Color bordeGeneral = Color(0xFFD1D5DB);
  static const Color hover = Color(0xFF93C5FD);
  static const Color lineaDivision = Color(0xFFE5E7EB);
  static const double radioTarjetas = 12.0;
}

/// Tipografías recomendadas para títulos y textos usando las fuentes por defecto del sistema.
/// Si más adelante se añaden Poppins e Inter, bastará con extender estos estilos.
class TipografiaApp {
  static TextTheme obtenerTextTheme(Brightness brillo) {
    final bool esClaro = brillo == Brightness.light;
    final Color colorPrincipal =
        esClaro ? ColoresBase.textoPrincipal : ColoresBaseOscuro.textoPrincipal;
    final Color colorSecundario =
        esClaro ? ColoresBase.textoSecundario : ColoresBaseOscuro.textoSecundario;
    final Color colorTerciario =
        esClaro ? ColoresBase.textoTerciario : ColoresBaseOscuro.textoTerciario;

    return TextTheme(
      displayLarge: TextStyle(
        fontWeight: FontWeight.w600,
        fontSize: 28,
        color: colorPrincipal,
      ),
      displayMedium: TextStyle(
        fontWeight: FontWeight.w600,
        fontSize: 24,
        color: colorPrincipal,
      ),
      headlineMedium: TextStyle(
        fontWeight: FontWeight.w500,
        fontSize: 20,
        color: colorPrincipal,
      ),
      bodyLarge: TextStyle(
        fontWeight: FontWeight.w400,
        fontSize: 16,
        color: colorSecundario,
      ),
      bodyMedium: TextStyle(
        fontWeight: FontWeight.w400,
        fontSize: 14,
        color: colorSecundario,
      ),
      bodySmall: TextStyle(
        fontWeight: FontWeight.w400,
        fontSize: 14,
        color: colorTerciario,
      ),
      labelLarge: TextStyle(
        fontWeight: FontWeight.w600,
        fontSize: 14,
        color: colorPrincipal,
      ),
      labelMedium: TextStyle(
        fontWeight: FontWeight.w500,
        fontSize: 12,
        color: colorTerciario,
      ),
    );
  }
}

/// Configuración centralizada de los temas claro y oscuro.
class TemasApp {
  static ThemeData obtenerTemaClaro() {
    final ColorScheme esquema = ColorScheme(
      brightness: Brightness.light,
      primary: ColoresAcciones.primario,
      onPrimary: Colors.white,
      secondary: ColoresAcciones.secundario,
      onSecondary: Colors.white,
      error: ColoresAcciones.error,
      onError: Colors.white,
      background: ColoresBase.fondoPrincipal,
      onBackground: ColoresBase.textoPrincipal,
      surface: ColoresBase.fondoTarjetas,
      onSurface: ColoresBase.textoSecundario,
    );

    return ThemeData(
      brightness: Brightness.light,
      colorScheme: esquema,
      scaffoldBackgroundColor: ColoresBase.fondoPrincipal,
      cardColor: ColoresBase.fondoTarjetas,
      textTheme: TipografiaApp.obtenerTextTheme(Brightness.light),
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        foregroundColor: ColoresBase.textoPrincipal,
      ),
      dividerColor: Bordes.lineaDivision,
      dividerTheme: const DividerThemeData(color: Bordes.lineaDivision, thickness: 1),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ButtonStyle(
          backgroundColor: MaterialStateProperty.resolveWith((states) {
            if (states.contains(MaterialState.disabled)) {
              return ColoresAcciones.neutro;
            }
            return ColoresAcciones.primario;
          }),
          foregroundColor: MaterialStateProperty.all<Color>(Colors.white),
          overlayColor: MaterialStateProperty.all<Color>(ColoresAcciones.secundario.withOpacity(0.1)),
          shape: MaterialStateProperty.all<RoundedRectangleBorder>(
            RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(Bordes.radioTarjetas),
            ),
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: ButtonStyle(
          foregroundColor: MaterialStateProperty.all<Color>(ColoresAcciones.primario),
          side: MaterialStateProperty.all<BorderSide>(
            const BorderSide(color: ColoresAcciones.primario),
          ),
          shape: MaterialStateProperty.all<RoundedRectangleBorder>(
            RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(Bordes.radioTarjetas),
            ),
          ),
          overlayColor: MaterialStateProperty.all<Color>(ColoresAcciones.primario.withOpacity(0.08)),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: ColoresBase.fondoTarjetas,
        hintStyle: TipografiaApp.obtenerTextTheme(Brightness.light).bodySmall,
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(Bordes.radioTarjetas),
          borderSide: const BorderSide(color: Bordes.bordeGeneral),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(Bordes.radioTarjetas),
          borderSide: const BorderSide(color: ColoresAcciones.primario),
        ),
      ),
    );
  }

  static ThemeData obtenerTemaOscuro() {
    final ColorScheme esquema = ColorScheme(
      brightness: Brightness.dark,
      primary: ColoresAcciones.primario,
      onPrimary: Colors.white,
      secondary: ColoresAcciones.secundario,
      onSecondary: Colors.white,
      error: ColoresAcciones.error,
      onError: Colors.white,
      background: ColoresBaseOscuro.fondoPrincipal,
      onBackground: ColoresBaseOscuro.textoPrincipal,
      surface: ColoresBaseOscuro.fondoTarjetas,
      onSurface: ColoresBaseOscuro.textoSecundario,
    );

    return ThemeData(
      brightness: Brightness.dark,
      colorScheme: esquema,
      scaffoldBackgroundColor: ColoresBaseOscuro.fondoPrincipal,
      cardColor: ColoresBaseOscuro.fondoTarjetas,
      textTheme: TipografiaApp.obtenerTextTheme(Brightness.dark),
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        foregroundColor: ColoresBaseOscuro.textoPrincipal,
      ),
      dividerColor: Bordes.hover.withOpacity(0.2),
      dividerTheme: DividerThemeData(
        color: Bordes.hover.withOpacity(0.2),
        thickness: 1,
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ButtonStyle(
          backgroundColor: MaterialStateProperty.resolveWith((states) {
            if (states.contains(MaterialState.disabled)) {
              return ColoresAcciones.neutro.withOpacity(0.4);
            }
            return ColoresAcciones.primario;
          }),
          foregroundColor: MaterialStateProperty.all<Color>(Colors.white),
          overlayColor: MaterialStateProperty.all<Color>(ColoresAcciones.secundario.withOpacity(0.2)),
          shape: MaterialStateProperty.all<RoundedRectangleBorder>(
            RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(Bordes.radioTarjetas),
            ),
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: ButtonStyle(
          foregroundColor: MaterialStateProperty.all<Color>(ColoresBaseOscuro.textoPrincipal),
          side: MaterialStateProperty.all<BorderSide>(
            BorderSide(color: ColoresAcciones.primario.withOpacity(0.7)),
          ),
          shape: MaterialStateProperty.all<RoundedRectangleBorder>(
            RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(Bordes.radioTarjetas),
            ),
          ),
          overlayColor: MaterialStateProperty.all<Color>(ColoresAcciones.primario.withOpacity(0.12)),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: ColoresBaseOscuro.fondoTarjetas,
        hintStyle: TipografiaApp.obtenerTextTheme(Brightness.dark).bodySmall,
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(Bordes.radioTarjetas),
          borderSide: BorderSide(color: ColoresAcciones.neutro.withOpacity(0.5)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(Bordes.radioTarjetas),
          borderSide: const BorderSide(color: ColoresAcciones.primario),
        ),
      ),
    );
  }
}
