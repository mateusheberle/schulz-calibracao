import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

class HeaderWidget extends StatelessWidget {
  const HeaderWidget({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 72,
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 24),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: Color(0xFFE4EAF0))),
      ),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: AppTheme.azulEscuro,
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(
              Icons.precision_manufacturing_outlined,
              color: Colors.white,
              size: 24,
            ),
          ),
          const SizedBox(width: 12),
          const Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'SCHULZ',
                style: TextStyle(
                  color: AppTheme.azulEscuro,
                  fontSize: 17,
                  letterSpacing: 1.4,
                  fontWeight: FontWeight.w800,
                ),
              ),
              Text(
                'Sistema de calibração',
                style: TextStyle(fontSize: 12, color: Color(0xFF667788)),
              ),
            ],
          ),
          const Spacer(),
          const Icon(Icons.verified_user_outlined, color: AppTheme.azulMedio),
          const SizedBox(width: 8),
          const Text(
            'Qualidade',
            style: TextStyle(
              color: AppTheme.azulEscuro,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
