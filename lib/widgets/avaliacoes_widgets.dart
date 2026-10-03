import 'package:flutter/material.dart';

import '../models/avaliacao.dart';
import '../models/solicitacao.dart';
import '../services/avaliacoes_repo.dart';
import '../services/solicitacoes_repo.dart' show PedidoFalha;
import '../theme/homefy_theme.dart';
import 'formulario.dart';

/// No detalhe de um pedido concluído: o cliente avalia; o profissional vê a nota.
class AvaliarAtendimento extends StatefulWidget {
  const AvaliarAtendimento({super.key, required this.pedido, required this.souCliente});
  final Solicitacao pedido;
  final bool souCliente;

  @override
  State<AvaliarAtendimento> createState() => _AvaliarAtendimentoState();
}

class _AvaliarAtendimentoState extends State<AvaliarAtendimento> {
  late Future<Avaliacao?> _feita = AvaliacoesRepo.instance.doPedido(widget.pedido.id);
  final _comentario = TextEditingController();
  int _nota = 0;
  bool _enviando = false;
  String? _erro;

  @override
  void dispose() {
    _comentario.dispose();
    super.dispose();
  }

  Future<void> _enviar() async {
    if (_nota == 0) {
      setState(() => _erro = 'Toque nas estrelas para dar a nota.');
      return;
    }
    setState(() {
      _enviando = true;
      _erro = null;
    });
    try {
      final a = await AvaliacoesRepo.instance.avaliar(widget.pedido, _nota, _comentario.text);
      mostrarAviso('Obrigado pela avaliação!');
      if (mounted) setState(() => _feita = Future.value(a));
    } on PedidoFalha catch (e) {
      if (mounted) setState(() => _erro = e.mensagem);
    } finally {
      if (mounted) setState(() => _enviando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return FutureBuilder<Avaliacao?>(
      future: _feita,
      builder: (context, snap) {
        if (snap.connectionState != ConnectionState.done) {
          return const Padding(padding: EdgeInsets.all(12), child: LinearProgressIndicator());
        }
        final a = snap.data;
        if (a != null) {
          return _Caixa(children: [
            Text(widget.souCliente ? 'Sua avaliação' : 'Avaliação do cliente', style: t.titleSmall),
            const SizedBox(height: 6),
            Estrelas(nota: a.nota.toDouble(), tamanho: 22),
            if (a.comentario.isNotEmpty) ...[
              const SizedBox(height: 6),
              Text('"${a.comentario}"', style: t.bodyMedium?.copyWith(fontStyle: FontStyle.italic)),
            ],
          ]);
        }
        if (!widget.souCliente) {
          return Text('O cliente ainda não avaliou este atendimento.',
              style: t.bodySmall?.copyWith(color: HomefyColors.textSecondary));
        }
        return _Caixa(children: [
          Text('Como foi o atendimento?', style: t.titleSmall),
          const SizedBox(height: 4),
          Estrelas(nota: _nota.toDouble(), tamanho: 34, aoEscolher: (n) => setState(() {
                _nota = n;
                _erro = null;
              })),
          const SizedBox(height: 8),
          TextField(
            controller: _comentario,
            maxLength: 300,
            minLines: 1,
            maxLines: 3,
            textCapitalization: TextCapitalization.sentences,
            decoration: const InputDecoration(
              hintText: 'Conte em poucas palavras (opcional)',
            ),
          ),
          Text('Sua nota e o comentário aparecem para outros clientes, com seu primeiro nome. '
              'Depois de enviada, a avaliação não pode ser mudada.',
              style: t.bodySmall?.copyWith(color: HomefyColors.textMuted)),
          const SizedBox(height: 10),
          if (_erro != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Text(_erro!, style: t.bodySmall?.copyWith(color: HomefyColors.error)),
            ),
          BotaoPrimario(texto: 'Enviar avaliação', icone: Icons.star_rounded, carregando: _enviando, aoTocar: _enviar),
        ]);
      },
    );
  }
}

class _Caixa extends StatelessWidget {
  const _Caixa({required this.children});
  final List<Widget> children;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: const Color(0xFFFFF8E6),
          borderRadius: BorderRadius.circular(HomefySpace.radiusMd),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: children),
      );
}

/// No detalhe do serviço: média do profissional e os comentários mais recentes.
class AvaliacoesDoProfissional extends StatelessWidget {
  const AvaliacoesDoProfissional({super.key, required this.profissionalUid});
  final String profissionalUid;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return FutureBuilder<List<Avaliacao>>(
      future: AvaliacoesRepo.instance.doProfissional(profissionalUid),
      builder: (context, snap) {
        if (!snap.hasData) return const SizedBox(height: 8);
        final l = snap.data!;
        final r = ResumoNotas.de(l);
        if (r.total == 0) {
          return Padding(
            padding: const EdgeInsets.only(top: 16),
            child: Row(children: [
              const Icon(Icons.fiber_new_outlined, size: 20, color: HomefyColors.textSecondary),
              const SizedBox(width: 6),
              Text('Novo no Homefy: ainda sem avaliações', style: t.bodySmall),
            ]),
          );
        }
        final comComentario = l.where((a) => a.comentario.isNotEmpty).take(3).toList();
        return Padding(
          padding: const EdgeInsets.only(top: 16),
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Row(children: [
              Estrelas(nota: r.media),
              const SizedBox(width: 6),
              Text(r.texto, style: t.labelLarge),
            ]),
            for (final a in comComentario)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text.rich(TextSpan(children: [
                  TextSpan(text: '"${a.comentario}" ', style: const TextStyle(fontStyle: FontStyle.italic)),
                  TextSpan(
                      text: '— ${a.clienteNome.isEmpty ? 'cliente' : a.clienteNome}, ${a.nota}★',
                      style: TextStyle(color: HomefyColors.textSecondary)),
                ]), style: t.bodySmall),
              ),
          ]),
        );
      },
    );
  }
}
