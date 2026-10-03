import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

import '../config.dart';
import '../models/avaliacao.dart';
import '../models/solicitacao.dart';
import 'solicitacoes_repo.dart' show PedidoFalha;

/// Avaliações: o cliente dá nota de 1 a 5 (e um comentário opcional) depois
/// do atendimento concluído. A média é calculada no app (plano grátis, sem servidor).
class AvaliacoesRepo {
  AvaliacoesRepo._();
  static final AvaliacoesRepo instance = AvaliacoesRepo._();

  CollectionReference<Map<String, dynamic>> get _col =>
      FirebaseFirestore.instance.collection('avaliacoes');

  /// Guarda em memória para não buscar o mesmo profissional várias vezes.
  final _cache = <String, Future<List<Avaliacao>>>{};

  /// Até 50 avaliações do profissional, mais recentes primeiro.
  Future<List<Avaliacao>> doProfissional(String uid) {
    if (kModoDemo) return Future.value(List.of(_demo));
    return _cache.putIfAbsent(uid, () async {
      try {
        final s = await _col.where('profissional_uid', isEqualTo: uid).limit(50).get();
        final l = s.docs.map(Avaliacao.fromFirestore).toList()
          ..sort((a, b) => (b.criadoEm ?? DateTime(0)).compareTo(a.criadoEm ?? DateTime(0)));
        return l;
      } catch (e) {
        debugPrint('avaliacoes: $e');
        _cache.remove(uid);
        return const [];
      }
    });
  }

  /// Avaliação de um atendimento (nula se ainda não avaliado).
  Future<Avaliacao?> doPedido(String solicitacaoId) async {
    if (kModoDemo) return _demoFeitas[solicitacaoId];
    try {
      final d = await _col.doc(solicitacaoId).get();
      return d.exists ? Avaliacao.fromFirestore(d) : null;
    } catch (_) {
      return null;
    }
  }

  Future<Avaliacao> avaliar(Solicitacao s, int nota, String comentario) async {
    final dados = {
      'profissional_uid': s.profissionalUid,
      'cliente_uid': s.clienteUid,
      'cliente_nome': Avaliacao.primeiroNome(s.clienteNome),
      'servico_nome': s.servicoNome,
      'nota': nota,
      'comentario': comentario.trim().length > 300 ? comentario.trim().substring(0, 300) : comentario.trim(),
    };
    if (kModoDemo) {
      final a = Avaliacao.fromMap(s.id, {...dados, 'criado_em': DateTime.now()});
      _demoFeitas[s.id] = a;
      return a;
    }
    try {
      await _col.doc(s.id).set({...dados, 'criado_em': FieldValue.serverTimestamp()});
      _cache.remove(s.profissionalUid);
      return Avaliacao.fromMap(s.id, {...dados, 'criado_em': DateTime.now()});
    } on FirebaseException catch (e) {
      debugPrint('avaliar: ${e.code} ${e.message}');
      throw PedidoFalha(e.code == 'permission-denied'
          ? 'Não foi possível avaliar. Ou este atendimento já foi avaliado, ou as regras novas ainda não foram publicadas.'
          : 'Não foi possível enviar. Verifique a conexão.');
    }
  }

  // ── Modo demonstração ──
  final _demoFeitas = <String, Avaliacao>{};
  final _demo = [
    Avaliacao.fromMap('a1', {
      'cliente_nome': 'Marina', 'servico_nome': 'Lavagem completa', 'nota': 5,
      'comentario': 'Chegou no horário e deixou o carro impecável.',
      'criado_em': DateTime.now().subtract(const Duration(days: 2)),
    }),
    Avaliacao.fromMap('a2', {
      'cliente_nome': 'José', 'servico_nome': 'Lavagem simples', 'nota': 4,
      'comentario': 'Bom serviço, só atrasou um pouco.',
      'criado_em': DateTime.now().subtract(const Duration(days: 9)),
    }),
    Avaliacao.fromMap('a3', {
      'cliente_nome': 'Carla', 'servico_nome': 'Lavagem completa', 'nota': 5, 'comentario': '',
      'criado_em': DateTime.now().subtract(const Duration(days: 15)),
    }),
  ];
}
