import 'package:flutter/material.dart';

import '../models/categoria.dart';
import '../models/servico.dart';
import '../services/servicos_repo.dart';
import '../theme/homefy_theme.dart';

/// Card de serviço da Home.
///
/// Não mostra foto, nota nem localização falsas (decisão da migração, seção 5.3):
/// no lugar da foto entra o ícone da categoria.
class ServicoCard extends StatelessWidget {
  const ServicoCard({super.key, required this.servico, required this.aoTocar});

  final Servico servico;
  final VoidCallback aoTocar;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final cat = Categoria.deServico(servico.categoria);
    final cor = cat?.cor ?? HomefyColors.primary;

    return Container(
      decoration: BoxDecoration(
        color: HomefyColors.surface,
        borderRadius: BorderRadius.circular(HomefySpace.radiusLg),
        boxShadow: homefyShadow,
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(HomefySpace.radiusLg),
          onTap: aoTocar,
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              children: [
                IconeCategoria(cor: cor, icone: cat?.icone ?? Icons.home_repair_service_rounded),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(servico.nome,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: t.titleMedium),
                      const SizedBox(height: 4),
                      Text(
                        servico.categoria.isEmpty ? 'Serviço' : servico.categoria,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: t.bodySmall?.copyWith(color: cor, fontWeight: FontWeight.w600),
                      ),
                      if (servico.profissionalRef != null)
                        NomeProfissional(servico: servico),
                      if (servico.duracaoFormatada != null) ...[
                        const SizedBox(height: 6),
                        Row(children: [
                          const Icon(Icons.schedule_rounded,
                              size: 14, color: HomefyColors.textMuted),
                          const SizedBox(width: 4),
                          Text(servico.duracaoFormatada!,
                              style: t.bodySmall?.copyWith(color: HomefyColors.textMuted)),
                        ]),
                      ],
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                _Preco(servico: servico),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Preco extends StatelessWidget {
  const _Preco({required this.servico});
  final Servico servico;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final preco = servico.precoFormatado;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        if (preco != null) ...[
          Text('a partir de', style: t.labelSmall?.copyWith(color: HomefyColors.textMuted)),
          const SizedBox(height: 2),
          Text(preco,
              style: t.titleMedium?.copyWith(
                  color: HomefyColors.primary, fontWeight: FontWeight.w800)),
        ] else
          Text('sob consulta',
              style: t.labelMedium?.copyWith(color: HomefyColors.textSecondary)),
      ],
    );
  }
}

/// Quadrado colorido suave com o ícone da categoria.
class IconeCategoria extends StatelessWidget {
  const IconeCategoria({super.key, required this.cor, required this.icone, this.tamanho = 60});
  final Color cor;
  final IconData icone;
  final double tamanho;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: tamanho,
      height: tamanho,
      decoration: BoxDecoration(
        color: cor.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(tamanho * 0.3),
      ),
      child: Icon(icone, color: cor, size: tamanho * 0.45),
    );
  }
}

/// Esqueleto animado enquanto os serviços carregam.
class ServicoCardCarregando extends StatefulWidget {
  const ServicoCardCarregando({super.key});
  @override
  State<ServicoCardCarregando> createState() => _ServicoCardCarregandoState();
}

class _ServicoCardCarregandoState extends State<ServicoCardCarregando>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 1100))
        ..repeat(reverse: true);

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    Widget barra(double w, double h) => Container(
          width: w,
          height: h,
          decoration: BoxDecoration(
            color: HomefyColors.border,
            borderRadius: BorderRadius.circular(8),
          ),
        );
    return FadeTransition(
      opacity: Tween(begin: 0.45, end: 1.0).animate(_c),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: HomefyColors.surface,
          borderRadius: BorderRadius.circular(HomefySpace.radiusLg),
          boxShadow: homefyShadow,
        ),
        child: Row(children: [
          barra(60, 60),
          const SizedBox(width: 14),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              barra(140, 14),
              const SizedBox(height: 8),
              barra(90, 10),
            ]),
          ),
          barra(56, 18),
        ]),
      ),
    );
  }
}

/// Linha "por <nome do profissional>", lida de `usuarios`.
/// Se o nome não vier (sem permissão, sem campo), simplesmente não aparece.
class NomeProfissional extends StatelessWidget {
  const NomeProfissional({super.key, required this.servico, this.grande = false});
  final Servico servico;
  final bool grande;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return FutureBuilder<PerfilProfissional?>(
      future: const ServicosRepo().perfilDoProfissional(servico.profissionalRef!),
      builder: (context, snap) {
        final nome = snap.data?.nome;
        if (nome == null) return const SizedBox.shrink();
        return Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Row(children: [
            Icon(Icons.verified_user_outlined,
                size: grande ? 16 : 13, color: HomefyColors.textSecondary),
            const SizedBox(width: 4),
            Flexible(
              child: Text('por $nome',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: (grande ? t.bodyMedium : t.bodySmall)
                      ?.copyWith(color: HomefyColors.textSecondary)),
            ),
          ]),
        );
      },
    );
  }
}

/// Bloco "Sobre o profissional" do detalhe do serviço.
class SobreProfissional extends StatelessWidget {
  const SobreProfissional({super.key, required this.servico});
  final Servico servico;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return FutureBuilder<PerfilProfissional?>(
      future: const ServicosRepo().perfilDoProfissional(servico.profissionalRef!),
      builder: (context, snap) {
        final p = snap.data;
        if (p == null || p.descricao.isEmpty) return const SizedBox.shrink();
        return Container(
          margin: const EdgeInsets.only(top: 16),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: HomefyColors.background,
            borderRadius: BorderRadius.circular(HomefySpace.radiusMd),
          ),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Sobre ${p.nome.split(' ').first}', style: t.labelLarge),
            const SizedBox(height: 4),
            Text(p.descricao, style: t.bodyMedium?.copyWith(height: 1.4)),
          ]),
        );
      },
    );
  }
}
