import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../config.dart';
import '../models/perfil.dart';
import '../services/auth_service.dart';
import '../services/perfil_repo.dart';
import '../theme/homefy_theme.dart';
import '../widgets/auth_layout.dart' show abrirPagina;
import '../widgets/feedback_sheet.dart';

/// Aba "Conta": perfil, área do profissional, ajuda e sair.
class ContaAba extends StatelessWidget {
  const ContaAba({super.key});

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final auth = AuthService.instance;
    return Scaffold(
      appBar: AppBar(title: const Text('Conta'), automaticallyImplyLeading: false),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 640),
          child: StreamBuilder<PerfilUsuario?>(
            stream: PerfilRepo.instance.meu(),
            builder: (context, snap) {
              final prof = snap.data?.ehProfissional == true;
              final nome = snap.data?.nome.isNotEmpty == true ? snap.data!.nome : (auth.primeiroNome ?? 'Minha conta');
              return ListView(
                padding: const EdgeInsets.fromLTRB(20, 4, 20, 32),
                children: [
                  // Cartão do perfil
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: HomefyColors.surface,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: HomefyColors.border),
                    ),
                    child: Row(children: [
                      CircleAvatar(
                        radius: 28,
                        backgroundColor: HomefyColors.primary,
                        child: Text(nome.characters.first.toUpperCase(),
                            style: t.titleLarge?.copyWith(color: Colors.white)),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Text(nome, style: t.titleMedium),
                          if (auth.email != null) Text(auth.email!, style: t.bodySmall),
                          if (prof)
                            Padding(
                              padding: const EdgeInsets.only(top: 6),
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                decoration: BoxDecoration(
                                  color: HomefyColors.solSuave,
                                  borderRadius: BorderRadius.circular(99),
                                ),
                                child: Text('Profissional',
                                    style: t.labelSmall?.copyWith(
                                        color: const Color(0xFF7A5400), fontWeight: FontWeight.w700)),
                              ),
                            ),
                        ]),
                      ),
                    ]),
                  ),

                  _Secao(titulo: prof ? 'Meu trabalho' : 'Oferecer serviços', itens: [
                    if (prof) ...[
                      _Item(Icons.inbox_outlined, 'Pedidos recebidos', 'Responda e acompanhe seus atendimentos',
                          () => context.push('/pedidos-recebidos')),
                      _Item(Icons.storefront_outlined, 'Meus serviços', 'Preços, faixas e o que aparece na vitrine',
                          () => context.push('/meus-servicos')),
                      _Item(Icons.badge_outlined, 'Perfil profissional', 'Áreas, bairros, WhatsApp e apresentação',
                          () => context.push('/oferecer')),
                    ] else
                      _Item(Icons.work_outline_rounded, 'Quero oferecer meus serviços',
                          'Cadastre-se como profissional com esta mesma conta', () => context.push('/oferecer')),
                  ]),

                  _Secao(titulo: 'Ajuda', itens: [
                    _Item(Icons.chat_bubble_outline_rounded, 'Conte sua experiência', 'Sugestões, ideias, o que melhorar',
                        () => abrirFeedback(context, tipo: TipoFeedback.experiencia)),
                    _Item(Icons.privacy_tip_outlined, 'Política de Privacidade', null, () => abrirPagina(kUrlPrivacidade)),
                    _Item(Icons.description_outlined, 'Termos de Uso', null, () => abrirPagina(kUrlTermos)),
                  ]),

                  const SizedBox(height: 20),
                  OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(foregroundColor: HomefyColors.error),
                    onPressed: () => AuthService.instance.sair(),
                    icon: const Icon(Icons.logout_rounded),
                    label: const Text('Sair da conta'),
                  ),
                  const SizedBox(height: 16),
                  Text('Homefy · versão de testes · Caruaru-PE',
                      textAlign: TextAlign.center, style: t.bodySmall?.copyWith(color: HomefyColors.textMuted)),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

class _Item {
  const _Item(this.icone, this.titulo, this.subtitulo, this.aoTocar);
  final IconData icone;
  final String titulo;
  final String? subtitulo;
  final VoidCallback aoTocar;
}

class _Secao extends StatelessWidget {
  const _Secao({required this.titulo, required this.itens});
  final String titulo;
  final List<_Item> itens;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.only(top: 24),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 8),
          child: Text(titulo, style: t.titleSmall?.copyWith(color: HomefyColors.textSecondary)),
        ),
        Container(
          decoration: BoxDecoration(
            color: HomefyColors.surface,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: HomefyColors.border),
          ),
          child: Column(children: [
            for (var i = 0; i < itens.length; i++) ...[
              if (i > 0) const Divider(height: 1, indent: 60),
              ListTile(
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
                leading: Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(color: HomefyColors.mint, borderRadius: BorderRadius.circular(10)),
                  child: Icon(itens[i].icone, size: 20, color: HomefyColors.primary),
                ),
                title: Text(itens[i].titulo, style: t.bodyLarge?.copyWith(fontWeight: FontWeight.w600)),
                subtitle: itens[i].subtitulo == null ? null : Text(itens[i].subtitulo!, style: t.bodySmall),
                trailing: const Icon(Icons.chevron_right_rounded, color: HomefyColors.textMuted),
                onTap: itens[i].aoTocar,
              ),
            ],
          ]),
        ),
      ]),
    );
  }
}
