import 'package:flutter/material.dart';

import '../theme/homefy_theme.dart';

/// Marca do Homefy: casa + check (dossiê, item 27), desenhada em código
/// para ficar nítida em qualquer tamanho e sem depender de imagem.
class HomefyLogo extends StatelessWidget {
  const HomefyLogo({super.key, this.tamanho = 56, this.claro = false});

  final double tamanho;

  /// true = versão branca, para usar sobre fundo verde.
  final bool claro;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: tamanho,
      height: tamanho,
      decoration: BoxDecoration(
        color: claro ? Colors.white.withValues(alpha: 0.14) : HomefyColors.primary,
        borderRadius: BorderRadius.circular(tamanho * 0.227),
        border: claro ? Border.all(color: Colors.white.withValues(alpha: 0.28)) : null,
        boxShadow: claro
            ? null
            : [
                BoxShadow(
                  color: HomefyColors.primary.withValues(alpha: 0.35),
                  blurRadius: tamanho * 0.4,
                  offset: Offset(0, tamanho * 0.12),
                ),
              ],
      ),
      child: CustomPaint(painter: _CasaCheckPainter()),
    );
  }
}

/// Casa em traço branco com a porta em amarelo-sol (identidade v2).
/// Mesma geometria de marca/homefy-simbolo.svg (grade de 512).
class _CasaCheckPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final k = size.width / 512;
    Offset p(double x, double y) => Offset(x * k, y * k);
    final traco = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 36 * k
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    Path linha(List<Offset> pts) {
      final path = Path()..moveTo(pts.first.dx, pts.first.dy);
      for (final q in pts.skip(1)) {
        path.lineTo(q.dx, q.dy);
      }
      return path;
    }

    canvas
      ..drawPath(linha([p(118, 262), p(256, 140), p(394, 262)]), traco)
      ..drawPath(linha([p(164, 232), p(164, 382), p(206, 382)]), traco)
      ..drawPath(linha([p(306, 382), p(348, 382), p(348, 232)]), traco);

    // Porta: o que o Homefy faz é trazer alguém de confiança até ela.
    final porta = Path()
      ..moveTo(222 * k, 400 * k)
      ..lineTo(222 * k, 322 * k)
      ..arcToPoint(p(290, 322), radius: Radius.circular(34 * k))
      ..lineTo(290 * k, 400 * k)
      ..close();
    canvas.drawPath(porta, Paint()..color = HomefyColors.sol);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// Logo + nome, para cabeçalhos.
class HomefyMarca extends StatelessWidget {
  const HomefyMarca({super.key, this.claro = false, this.tamanho = 36});
  final bool claro;
  final double tamanho;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        HomefyLogo(tamanho: tamanho, claro: claro),
        const SizedBox(width: 10),
        Text(
          'homefy',
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w800,
                letterSpacing: -0.8,
                fontSize: tamanho * 0.72,
                color: claro ? Colors.white : HomefyColors.primary,
              ),
        ),
      ],
    );
  }
}
