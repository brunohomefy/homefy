import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../config.dart';
import '../theme/homefy_theme.dart';
import 'formulario.dart';

/// Tipos de feedback gravados em `feedbacks` (o Bruno lê no console).
enum TipoFeedback {
  /// "Não achou o que precisa?": mede a demanda por novas categorias (D1).
  naoAchei('nao_achei'),

  /// "Conte sua experiência": sugestões gerais de clientes e profissionais.
  experiencia('experiencia');

  const TipoFeedback(this.valor);
  final String valor;
}

/// Abre o formulário curto de feedback.
/// [busca], [categoriaId] e [bairro] dão contexto ao "Não achou".
Future<void> abrirFeedback(
  BuildContext context, {
  required TipoFeedback tipo,
  String? busca,
  String? categoriaId,
  String? bairro,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    builder: (_) => _FolhaFeedback(
      tipo: tipo,
      busca: busca,
      categoriaId: categoriaId,
      bairro: bairro,
    ),
  );
}

class _FolhaFeedback extends StatefulWidget {
  const _FolhaFeedback({required this.tipo, this.busca, this.categoriaId, this.bairro});
  final TipoFeedback tipo;
  final String? busca;
  final String? categoriaId;
  final String? bairro;

  @override
  State<_FolhaFeedback> createState() => _FolhaFeedbackState();
}

class _FolhaFeedbackState extends State<_FolhaFeedback> {
  late final _texto = TextEditingController(
    text: widget.tipo == TipoFeedback.naoAchei && (widget.busca?.isNotEmpty ?? false)
        ? 'Procurei "${widget.busca}". '
        : '',
  );
  bool _enviando = false;
  String? _erro;

  @override
  void dispose() {
    _texto.dispose();
    super.dispose();
  }

  Future<void> _enviar() async {
    final texto = _texto.text.trim();
    if (texto.length < 3) {
      setState(() => _erro = 'Escreva um pouco mais, por favor.');
      return;
    }
    setState(() {
      _enviando = true;
      _erro = null;
    });
    try {
      if (!kModoDemo) {
        String? curto(String? v, int max) {
          final s = v?.trim() ?? '';
          if (s.isEmpty) return null;
          return s.length > max ? s.substring(0, max) : s;
        }

        final busca = curto(widget.busca, 100);
        final cat = curto(widget.categoriaId, 20);
        final bairro = curto(widget.bairro, 60);
        await FirebaseFirestore.instance.collection('feedbacks').add({
          'autor_uid': FirebaseAuth.instance.currentUser!.uid,
          'tipo': widget.tipo.valor,
          'texto': texto.length > 1000 ? texto.substring(0, 1000) : texto,
          if (busca != null) 'busca': busca,
          if (cat != null) 'categoria_id': cat,
          if (bairro != null) 'bairro': bairro,
          'criado_em': FieldValue.serverTimestamp(),
        });
      }
      if (!mounted) return;
      Navigator.of(context).pop();
      mostrarAviso('Obrigado! Sua mensagem chegou para a equipe do Homefy.');
    } catch (e) {
      debugPrint('feedback: $e');
      setState(() => _erro = 'Não foi possível enviar. Verifique a conexão e tente de novo.');
    } finally {
      if (mounted) setState(() => _enviando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final naoAchei = widget.tipo == TipoFeedback.naoAchei;
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 0, 24, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(naoAchei ? 'O que você procurava?' : 'Conte sua experiência', style: t.titleLarge),
              const SizedBox(height: 6),
              Text(
                naoAchei
                    ? 'Estamos começando com quatro áreas em Caruaru. Diga qual serviço faltou: '
                        'os mais pedidos entram primeiro.'
                    : 'O que você achou do Homefy? O que faltou, o que atrapalhou, que serviço '
                        'gostaria de encontrar aqui? A gente lê tudo.',
                style: t.bodyMedium?.copyWith(color: HomefyColors.textSecondary, height: 1.4),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _texto,
                autofocus: true,
                minLines: 3,
                maxLines: 6,
                maxLength: 1000,
                textCapitalization: TextCapitalization.sentences,
                decoration: InputDecoration(
                  hintText: naoAchei
                      ? 'Ex.: dog walker, conserto de geladeira, aula de violão…'
                      : 'Escreva aqui…',
                ),
              ),
              Text('Não coloque telefone, CPF ou endereço.',
                  style: t.bodySmall?.copyWith(color: HomefyColors.textMuted)),
              if (_erro != null) ...[
                const SizedBox(height: 8),
                Text(_erro!, style: t.bodySmall?.copyWith(color: HomefyColors.error)),
              ],
              const SizedBox(height: 16),
              BotaoPrimario(
                texto: 'Enviar',
                icone: Icons.send_rounded,
                carregando: _enviando,
                aoTocar: _enviar,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
