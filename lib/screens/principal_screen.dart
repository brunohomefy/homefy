import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../models/perfil.dart';
import '../models/solicitacao.dart';
import '../services/perfil_repo.dart';
import '../services/solicitacoes_repo.dart';

/// Estrutura principal do app, com a barra de baixo: Início · Pedidos · Conta.
///
/// Cada aba tem um endereço (/home, /meus-pedidos, /conta) e guarda o próprio
/// estado ao trocar de aba (o bairro escolhido na Início não se perde).
class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key, required this.shell});
  final StatefulNavigationShell shell;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: shell,
      bottomNavigationBar: _Barra(
        aba: shell.currentIndex,
        aoTrocar: (i) => shell.goBranch(i, initialLocation: i == shell.currentIndex),
      ),
    );
  }
}

class _Barra extends StatelessWidget {
  const _Barra({required this.aba, required this.aoTrocar});
  final int aba;
  final ValueChanged<int> aoTrocar;

  @override
  Widget build(BuildContext context) {
    final repo = SolicitacoesRepo.instance;
    // Selo na aba Pedidos: quantos pedidos esperam uma ação minha.
    return StreamBuilder<List<Solicitacao>>(
      stream: repo.comoCliente(),
      builder: (context, cli) => StreamBuilder<PerfilUsuario?>(
        stream: PerfilRepo.instance.meu(),
        builder: (context, perfil) => StreamBuilder<List<Solicitacao>>(
          stream: perfil.data?.ehProfissional == true ? repo.comoProfissional() : const Stream.empty(),
          builder: (context, prof) {
            final n = (cli.data ?? const <Solicitacao>[]).where((s) => s.status == StatusPedido.proposta).length +
                (prof.data ?? const <Solicitacao>[]).where((s) => s.status == StatusPedido.pendente).length;
            return NavigationBar(
              selectedIndex: aba,
              onDestinationSelected: aoTrocar,
              destinations: [
                const NavigationDestination(
                  icon: Icon(Icons.home_outlined),
                  selectedIcon: Icon(Icons.home_rounded),
                  label: 'Início',
                ),
                NavigationDestination(
                  icon: Badge(isLabelVisible: n > 0, label: Text('$n'), child: const Icon(Icons.receipt_long_outlined)),
                  selectedIcon:
                      Badge(isLabelVisible: n > 0, label: Text('$n'), child: const Icon(Icons.receipt_long_rounded)),
                  label: 'Pedidos',
                ),
                const NavigationDestination(
                  icon: Icon(Icons.person_outline_rounded),
                  selectedIcon: Icon(Icons.person_rounded),
                  label: 'Conta',
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}
