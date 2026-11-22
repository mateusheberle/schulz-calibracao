import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

class ParecerBanner extends StatelessWidget {
  final bool isAprovado;

  const ParecerBanner({super.key, required this.isAprovado});

  @override
  Widget build(BuildContext context) {
    final bgColor = isAprovado ? AppTheme.verdeBg : AppTheme.vermelhoBg;
    final textColor = isAprovado ? AppTheme.verdeTexto : AppTheme.vermelhoTexto;
    final borderColor = isAprovado
        ? AppTheme.verdeBorda
        : AppTheme.vermelhoBorda;
    final icon = isAprovado
        ? Icons.check_circle_outline
        : Icons.warning_amber_rounded;
    final texto = isAprovado
        ? 'PARECER FINAL: INSTRUMENTO APROVADO'
        : 'PARECER FINAL: INSTRUMENTO REPROVADO';

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: borderColor, width: 2),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: textColor, size: 28),
          const SizedBox(width: 12),
          Flexible(
            child: Text(
              texto,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: textColor,
                fontWeight: FontWeight.bold,
                fontSize: 16,
                letterSpacing: 0.5,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
