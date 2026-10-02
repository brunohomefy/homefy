import 'package:flutter/material.dart';

import '../theme/homefy_theme.dart';
import 'homefy_logo.dart';

/// Layout das telas de entrada: faixa verde com a marca no topo e um
/// "cartão" branco subindo por cima, com o formulário.
class AuthLayout extends StatelessWidget {
  const AuthLayout({
    super.key,
    required this.titulo,
    required this.subtitulo,
    required this.child,
    this.voltar,
  });

  final String titulo;
  final String subtitulo;
  final Widget child;
  final VoidCallback? voltar;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final topo = MediaQuery.paddingOf(context).top;

    return Scaffold(
      backgroundColor: HomefyColors.primaryDark,
      body: Stack(
        children: [
          // Fundo verde com formas decorativas
          Positioned.fill(
            child: DecoratedBox(
              decoration: const BoxDecoration(gradient: HomefyColors.brandGradient),
              child: Stack(children: const [
                _Bolha(top: -60, right: -40, tamanho: 220, opacidade: 0.10),
                _Bolha(top: 120, left: -70, tamanho: 160, opacidade: 0.07),
              ]),
            ),
          ),
          SafeArea(
            bottom: false,
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 480),
                child: CustomScrollView(
                  slivers: [
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: EdgeInsets.fromLTRB(24, topo > 0 ? 8 : 24, 24, 28),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(children: [
                              if (voltar != null) ...[
                                IconButton.filledTonal(
                                  onPressed: voltar,
                                  style: IconButton.styleFrom(
                                    backgroundColor: Colors.white.withValues(alpha: 0.14),
                                    foregroundColor: Colors.white,
                                  ),
                                  icon: const Icon(Icons.arrow_back_rounded),
                                ),
                                const SizedBox(width: 12),
                              ],
                              const HomefyMarca(claro: true, tamanho: 40),
                            ]),
                            const SizedBox(height: 32),
                            Text(titulo,
                                style: t.headlineMedium?.copyWith(
                                    color: Colors.white, height: 1.15)),
                            const SizedBox(height: 10),
                            Text(subtitulo,
                                style: t.bodyLarge?.copyWith(
                                    color: Colors.white.withValues(alpha: 0.82),
                                    height: 1.4)),
                          ],
                        ),
                      ),
                    ),
                    SliverFillRemaining(
                      hasScrollBody: false,
                      child: Container(
                        decoration: const BoxDecoration(
                          color: HomefyColors.surface,
                          borderRadius: BorderRadius.vertical(
                              top: Radius.circular(HomefySpace.radiusXl)),
                        ),
                        padding: EdgeInsets.fromLTRB(
                            24, 32, 24, 24 + MediaQuery.paddingOf(context).bottom),
                        child: child,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Bolha extends StatelessWidget {
  const _Bolha({this.top, this.left, this.right, required this.tamanho, required this.opacidade});
  final double? top, left, right;
  final double tamanho;
  final double opacidade;

  @override
  Widget build(BuildContext context) => Positioned(
        top: top,
        left: left,
        right: right,
        child: Container(
          width: tamanho,
          height: tamanho,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: Colors.white.withValues(alpha: opacidade),
          ),
        ),
      );
}

/// Linha "texto + link" do rodapé dos formulários.
class LinhaLink extends StatelessWidget {
  const LinhaLink({super.key, required this.texto, required this.link, required this.aoTocar});
  final String texto;
  final String link;
  final VoidCallback aoTocar;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(texto, style: t.bodyMedium),
        TextButton(onPressed: aoTocar, child: Text(link)),
      ],
    );
  }
}

class RodapeTermos extends StatelessWidget {
  const RodapeTermos({super.key});
  @override
  Widget build(BuildContext context) => Text(
        'Ao continuar, você concorda com nossos Termos de Serviço '
        'e Política de Privacidade.',
        textAlign: TextAlign.center,
        style: Theme.of(context)
            .textTheme
            .bodySmall
            ?.copyWith(color: HomefyColors.textMuted, height: 1.4),
      );
}
