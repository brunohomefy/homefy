import 'package:flutter/material.dart';

import '../theme/homefy_theme.dart';

/// Campo de formulário com rótulo acima, no padrão do Homefy.
class CampoTexto extends StatefulWidget {
  const CampoTexto({
    super.key,
    required this.rotulo,
    required this.controller,
    this.dica,
    this.icone,
    this.senha = false,
    this.teclado,
    this.acaoTeclado,
    this.aoEnviar,
    this.validador,
    this.autofill,
    this.capitalizacao = TextCapitalization.none,
  });

  final String rotulo;
  final TextEditingController controller;
  final String? dica;
  final IconData? icone;
  final bool senha;
  final TextInputType? teclado;
  final TextInputAction? acaoTeclado;
  final ValueChanged<String>? aoEnviar;
  final FormFieldValidator<String>? validador;
  final Iterable<String>? autofill;
  final TextCapitalization capitalizacao;

  @override
  State<CampoTexto> createState() => _CampoTextoState();
}

class _CampoTextoState extends State<CampoTexto> {
  bool _oculto = true;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(widget.rotulo,
            style: t.labelLarge?.copyWith(color: HomefyColors.text)),
        const SizedBox(height: HomefySpace.sm),
        TextFormField(
          controller: widget.controller,
          obscureText: widget.senha && _oculto,
          keyboardType: widget.teclado,
          textInputAction: widget.acaoTeclado,
          onFieldSubmitted: widget.aoEnviar,
          validator: widget.validador,
          autofillHints: widget.autofill,
          textCapitalization: widget.capitalizacao,
          autocorrect: !widget.senha,
          enableSuggestions: !widget.senha,
          style: t.bodyLarge,
          decoration: InputDecoration(
            hintText: widget.dica,
            prefixIcon: widget.icone != null ? Icon(widget.icone, size: 20) : null,
            suffixIcon: widget.senha
                ? IconButton(
                    tooltip: _oculto ? 'Mostrar senha' : 'Ocultar senha',
                    icon: Icon(
                      _oculto ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                      size: 20,
                    ),
                    onPressed: () => setState(() => _oculto = !_oculto),
                  )
                : null,
          ),
        ),
      ],
    );
  }
}

/// Botão principal com estado de carregamento.
class BotaoPrimario extends StatelessWidget {
  const BotaoPrimario({
    super.key,
    required this.texto,
    required this.aoTocar,
    this.carregando = false,
    this.icone,
  });

  final String texto;
  final VoidCallback? aoTocar;
  final bool carregando;
  final IconData? icone;

  @override
  Widget build(BuildContext context) {
    return FilledButton(
      onPressed: carregando ? null : aoTocar,
      style: FilledButton.styleFrom(
        disabledBackgroundColor: HomefyColors.primary.withValues(alpha: 0.6),
        disabledForegroundColor: Colors.white,
      ),
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 200),
        child: carregando
            ? const SizedBox(
                key: ValueKey('load'),
                width: 22,
                height: 22,
                child: CircularProgressIndicator(strokeWidth: 2.4, color: Colors.white),
              )
            : Row(
                key: const ValueKey('txt'),
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(texto),
                  if (icone != null) ...[
                    const SizedBox(width: 8),
                    Icon(icone, size: 20),
                  ],
                ],
              ),
      ),
    );
  }
}

/// Validações simples reutilizadas nos formulários.
class Validar {
  Validar._();

  static String? email(String? v) {
    final s = v?.trim() ?? '';
    if (s.isEmpty) return 'Informe seu e-mail.';
    if (!RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(s)) {
      return 'Esse e-mail não parece válido.';
    }
    return null;
  }

  static String? senha(String? v) {
    if ((v ?? '').isEmpty) return 'Informe sua senha.';
    return null;
  }

  static String? novaSenha(String? v) {
    final s = v ?? '';
    if (s.length < 6) return 'Use pelo menos 6 caracteres.';
    return null;
  }

  static String? nome(String? v) {
    final s = v?.trim() ?? '';
    if (s.length < 3) return 'Informe seu nome completo.';
    return null;
  }
}

/// Chave global: permite mostrar avisos mesmo se a tela já foi trocada
/// (ex.: logo após criar a conta o app já pulou para a Home).
final avisosKey = GlobalKey<ScaffoldMessengerState>();

void mostrarAviso(String texto, {bool erro = false}) {
  final m = avisosKey.currentState;
  if (m == null) return;
  m
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(
      content: Row(
        children: [
          Icon(erro ? Icons.error_outline_rounded : Icons.check_circle_outline_rounded,
              color: erro ? const Color(0xFFFF8FA3) : const Color(0xFFB7E4C7)),
          const SizedBox(width: 12),
          Expanded(child: Text(texto)),
        ],
      ),
    ));
}
