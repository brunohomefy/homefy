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
        gradient: claro ? null : HomefyColors.brandGradient,
        color: claro ? Colors.white.withValues(alpha: 0.16) : null,
        borderRadius: BorderRadius.circular(tamanho * 0.3),
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

class _CasaCheckPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final s = size.width;
    final traco = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = s * 0.075
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    // Casa
    final casa = Path()
      ..moveTo(s * 0.24, s * 0.48)
      ..lineTo(s * 0.50, s * 0.25)
      ..lineTo(s * 0.76, s * 0.48)
      ..moveTo(s * 0.31, s * 0.43)
      ..lineTo(s * 0.31, s * 0.74)
      ..lineTo(s * 0.69, s * 0.74)
      ..lineTo(s * 0.69, s * 0.43);
    canvas.drawPath(casa, traco);

    // Check dentro da casa
    final check = Path()
      ..moveTo(s * 0.40, s * 0.57)
      ..lineTo(s * 0.47, s * 0.64)
      ..lineTo(s * 0.60, s * 0.50);
    canvas.drawPath(check, traco..color = const Color(0xFFB7E4C7));
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
          'Homefy',
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w900,
                color: claro ? Colors.white : HomefyColors.primary,
              ),
        ),
      ],
    );
  }
}
