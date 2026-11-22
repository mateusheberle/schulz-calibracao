import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

class SidebarWidget extends StatelessWidget {
  const SidebarWidget({
    required this.selectedIndex,
    required this.onDestinationSelected,
    this.compact = false,
    super.key,
  });

  final int selectedIndex;
  final ValueChanged<int> onDestinationSelected;
  final bool compact;

  static const _destinos = [
    _Destino('1. Ingestão (MMC)', 'Ingestão', Icons.cloud_upload_outlined),
    _Destino(
      '2. Minuta & Revisão',
      'Revisão',
      Icons.assignment_turned_in_outlined,
    ),
    _Destino('3. Validador QR Code', 'QR Code', Icons.qr_code_scanner),
    _Destino('4. Histórico AWS', 'Histórico', Icons.history),
  ];

  @override
  Widget build(BuildContext context) {
    if (compact) {
      return NavigationBar(
        selectedIndex: selectedIndex,
        onDestinationSelected: onDestinationSelected,
        destinations: [
          for (final destino in _destinos)
            NavigationDestination(
              icon: Icon(destino.icone),
              label: destino.rotuloCompacto,
            ),
        ],
      );
    }

    return Container(
      width: 208,
      color: Colors.white,
      child: Column(
        children: [
          const SizedBox(height: 16),
          for (var index = 0; index < _destinos.length; index++)
            _buildItem(index, _destinos[index]),
        ],
      ),
    );
  }

  Widget _buildItem(int index, _Destino destino) {
    final selecionado = selectedIndex == index;
    return Container(
      decoration: BoxDecoration(
        border: selecionado
            ? const Border(
                left: BorderSide(color: AppTheme.laranjaSchulz, width: 2),
              )
            : null,
      ),
      child: Material(
        color: selecionado ? const Color(0xFFF0F4F8) : Colors.white,
        child: ListTile(
          dense: true,
          contentPadding: const EdgeInsets.symmetric(horizontal: 14),
          horizontalTitleGap: 8,
          minLeadingWidth: 22,
          leading: Icon(
            destino.icone,
            size: 19,
            color: selecionado ? AppTheme.azulEscuro : const Color(0xFF718096),
          ),
          title: Text(
            destino.rotulo,
            style: TextStyle(
              color: selecionado
                  ? AppTheme.azulEscuro
                  : const Color(0xFF718096),
              fontSize: 12,
              fontWeight: selecionado ? FontWeight.w700 : FontWeight.normal,
            ),
          ),
          selected: selecionado,
          selectedTileColor: Colors.transparent,
          onTap: () => onDestinationSelected(index),
        ),
      ),
    );
  }
}

class _Destino {
  const _Destino(this.rotulo, this.rotuloCompacto, this.icone);

  final String rotulo;
  final String rotuloCompacto;
  final IconData icone;
}
