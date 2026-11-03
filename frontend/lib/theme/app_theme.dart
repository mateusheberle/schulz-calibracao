import 'package:flutter/material.dart';

class AppTheme {
  // Cores Institucionais Schulz S.A.
  static const Color azulEscuro = Color(0xFF002B49);
  static const Color azulMedio = Color(0xFF004B87);
  static const Color laranjaSchulz = Color(0xFFE35205);
  static const Color cinzaFundo = Color(0xFFF4F6F9);
  static const Color cinzaBorda = Color(0xFFE2E8F0);

  // Status Metrológicos
  static const Color verdeBg = Color(0xFFC6F6D5);
  static const Color verdeTexto = Color(0xFF22543D);
  static const Color verdeBorda = Color(0xFF38A169);

  static const Color vermelhoBg = Color(0xFFFED7D7);
  static const Color vermelhoTexto = Color(0xFF742A2A);
  static const Color vermelhoBorda = Color(0xFFE53E3E);

  static ThemeData get theme {
    return ThemeData(
      primaryColor: azulEscuro,
      scaffoldBackgroundColor: cinzaFundo,
      fontFamily: 'Roboto',
      colorScheme: ColorScheme.fromSeed(
        seedColor: azulEscuro,
        primary: azulEscuro,
        secondary: laranjaSchulz,
      ),
    );
  }
}
