import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

import '../config.dart';
import '../models/servico.dart';
import '../models/solicitacao.dart';

/// Erro já traduzido para mostrar ao usuário.
class PedidoFalha implements Exception {
  PedidoFalha(this.mensagem);
  final String mensagem;
  @override
  String toString() => mensagem;
}

/// Pedidos de atendimento: criar, responder, confirmar, cancelar, concluir.
///
/// Tudo roda no app, sem servidor (plano grátis). As regras do Firestore
/// garantem a ordem das etapas e que o mesmo horário não é confirmado duas vezes.
class SolicitacoesRepo {
  SolicitacoesRepo._();
  static final SolicitacoesRepo instance = SolicitacoesRepo._();

  FirebaseFirestore get _db => FirebaseFirestore.instance;
  String? get _uid => kModoDemo ? _demoUid : FirebaseAuth.instance.currentUser?.uid;

  CollectionReference<Map<String, dynamic>> get _col => _db.collection('solicitacoes');

  // ───────────── Leitura ─────────────

  /// Pedidos que eu fiz como cliente (mais recentes primeiro).
  Stream<List<Solicitacao>> comoCliente() => _lista('cliente_uid');

  /// Pedidos que recebi como profissional (mais recentes primeiro).
  Stream<List<Solicitacao>> comoProfissional() => _lista('profissional_uid');

  Stream<List<Solicitacao>> _lista(String campo) {
    if (kModoDemo) return _demoStream(campo);
    final uid = _uid;
    if (uid == null) return Stream.value(const []);
    // Sem orderBy: dispensa índice composto. Ordenação feita aqui.
    return _col
        .where(campo, isEqualTo: uid)
        .limit(50)
        .snapshots()
        .map((s) => ordenar(s.docs.map(Solicitacao.fromFirestore).toList()));
  }

  /// Em aberto primeiro (o que pede ação), depois o resto; mais novos antes.
  static List<Solicitacao> ordenar(List<Solicitacao> l) {
    int peso(Solicitacao s) => s.status.encerrado ? 1 : 0;
    l.sort((a, b) {
      final p = peso(a).compareTo(peso(b));
      if (p != 0) return p;
      final da = a.criadoEm ?? DateTime(2100), db = b.criadoEm ?? DateTime(2100);
      return db.compareTo(da);
    });
    return l;
  }

  /// O profissional já tem atendimento confirmado nesse dia e período?
  Future<bool> horarioLivre(String profissionalUid, String data, Periodo p) async {
    final id = Solicitacao.idAgenda(profissionalUid, data, p);
    if (kModoDemo) return !_demoAgenda.contains(id);
    try {
      return !(await _db.collection('agenda').doc(id).get()).exists;
    } catch (_) {
      return true; // na dúvida, deixa pedir: a confirmação é que trava.
    }
  }

  /// WhatsApp do profissional: só abre depois que o cliente confirmou.
  Future<String?> whatsappDoProfissional(String profissionalUid) async {
    if (kModoDemo) return '5581900000001';
    try {
      final d = (await _db.doc('usuarios/$profissionalUid/privado/contato').get()).data();
      final w = d?['whatsapp'];
      return w is String ? w : null;
    } catch (_) {
      return null;
    }
  }

  /// WhatsApp do cliente: o profissional só vê depois da confirmação.
  Future<String?> whatsappDoCliente(String solicitacaoId) async {
    if (kModoDemo) return '5581977776666';
    try {
      final d = (await _col.doc(solicitacaoId).collection('privado').doc('cliente').get()).data();
      final w = d?['whatsapp'];
      return w is String ? w : null;
    } catch (_) {
      return null;
    }
  }

  // ───────────── Cliente ─────────────

  Future<void> criar({
    required Servico servico,
    required Variacao variacao,
    required String data,
    required Periodo periodo,
    required String bairro,
    required String observacao,
    required String whatsapp,
    required String clienteNome,
    required String profissionalNome,
  }) async {
    final uid = _uid;
    final prof = servico.profissionalRef?.id ?? (kModoDemo ? 'teste_demo' : null);
    if (uid == null) throw PedidoFalha('Entre na sua conta para pedir.');
    if (prof == null) throw PedidoFalha('Este serviço não tem profissional ligado a ele.');
    if (prof == uid) throw PedidoFalha('Este serviço é seu.');
    final dados = Solicitacao.novo(
      clienteUid: uid,
      clienteNome: clienteNome,
      profissionalUid: prof,
      profissionalNome: profissionalNome,
      servico: servico,
      variacao: variacao,
      data: data,
      periodo: periodo,
      bairro: bairro,
      observacao: observacao,
    );
    if (kModoDemo) {
      _demoAdd(Solicitacao.fromMap('demo${_demo.length + 1}', {...dados, 'criado_em': DateTime.now()}));
      return;
    }
    final ref = _col.doc();
    final lote = _db.batch()
      ..set(ref, dados)
      ..set(ref.collection('privado').doc('cliente'), {'whatsapp': whatsapp});
    await _rodar(lote.commit, 'enviar o pedido');
  }

  /// Confirma o valor final. No mesmo lote: trava o horário e libera o WhatsApp.
  /// Se outro cliente confirmou o mesmo horário antes, o banco recusa.
  Future<void> confirmar(Solicitacao s) async {
    if (kModoDemo) {
      if (_demoAgenda.contains(s.agendaId)) throw _ocupado();
      _demoAgenda.add(s.agendaId);
      _demoMudar(s.id, {'status': 'confirmada'});
      return;
    }
    final lote = _db.batch()
      ..update(_col.doc(s.id), {
        'status': StatusPedido.confirmada.id,
        'confirmado_em': FieldValue.serverTimestamp(),
      })
      ..set(_db.collection('agenda').doc(s.agendaId), {
        'solicitacao_id': s.id,
        'profissional_uid': s.profissionalUid,
      })
      ..set(_db.doc('usuarios/${s.profissionalUid}/liberados/${s.clienteUid}'), {
        'solicitacao_id': s.id,
      });
    try {
      await lote.commit();
    } on FirebaseException catch (e) {
      debugPrint('confirmar: ${e.code} ${e.message}');
      if (e.code == 'permission-denied') {
        final livre = await horarioLivre(s.profissionalUid, s.data, s.periodo);
        throw livre
            ? PedidoFalha('O banco recusou a confirmação. Confira se as regras novas foram publicadas.')
            : _ocupado();
      }
      throw PedidoFalha('Não foi possível confirmar. Verifique a conexão.');
    }
  }

  PedidoFalha _ocupado() => PedidoFalha(
      'Esse horário acabou de ser confirmado por outra pessoa. Faça um novo pedido em outro dia ou período.');

  // ───────────── Profissional ─────────────

  Future<void> enviarProposta(String id, double valor, String mensagem) => _mudar(id, {
        'status': StatusPedido.proposta.id,
        'valor_final': valor,
        'mensagem_profissional': mensagem.trim(),
        'respondido_em': FieldValue.serverTimestamp(),
      }, 'enviar o valor');

  Future<void> recusar(String id, String mensagem) => _mudar(id, {
        'status': StatusPedido.recusada.id,
        'mensagem_profissional': mensagem.trim(),
        'respondido_em': FieldValue.serverTimestamp(),
      }, 'recusar');

  Future<void> concluir(String id) => _mudar(id, {
        'status': StatusPedido.concluida.id,
        'concluido_em': FieldValue.serverTimestamp(),
      }, 'concluir');

  // ───────────── Os dois ─────────────

  /// Cancela. Se já estava confirmado, libera o horário e tira o WhatsApp no mesmo lote.
  Future<void> cancelar(Solicitacao s, {required bool souCliente}) async {
    final campos = {
      'status': StatusPedido.cancelada.id,
      'cancelado_por': souCliente ? 'cliente' : 'profissional',
      'cancelado_em': FieldValue.serverTimestamp(),
    };
    if (kModoDemo) {
      _demoAgenda.remove(s.agendaId);
      _demoMudar(s.id, {'status': 'cancelada', 'cancelado_por': campos['cancelado_por']});
      return;
    }
    if (s.status != StatusPedido.confirmada) return _mudar(s.id, campos, 'cancelar');
    final lote = _db.batch()
      ..update(_col.doc(s.id), campos)
      ..delete(_db.collection('agenda').doc(s.agendaId))
      ..delete(_db.doc('usuarios/${s.profissionalUid}/liberados/${s.clienteUid}'));
    await _rodar(lote.commit, 'cancelar');
  }

  Future<void> _mudar(String id, Map<String, Object?> campos, String acao) async {
    if (kModoDemo) {
      _demoMudar(id, {
        for (final e in campos.entries)
          if (e.value is! FieldValue) e.key: e.value,
      });
      return;
    }
    await _rodar(() => _col.doc(id).update(campos), acao);
  }

  Future<void> _rodar(Future<void> Function() f, String acao) async {
    try {
      await f();
    } on FirebaseException catch (e) {
      debugPrint('$acao: ${e.code} ${e.message}');
      throw PedidoFalha(e.code == 'permission-denied'
          ? 'O banco recusou ($acao). Talvez o pedido já tenha mudado de situação, '
              'ou as regras novas ainda não foram publicadas.'
          : 'Não foi possível $acao. Verifique a conexão e tente de novo.');
    }
  }

  // ───────────── Modo demonstração (sem Firebase) ─────────────
  // Um pedido feito (com valor para confirmar) e um recebido (para responder),
  // para as telas não ficarem vazias nos prints.

  static const _demoUid = 'demo';
  final _demoMudou = StreamController<void>.broadcast();
  final _demoAgenda = <String>{};
  late final List<Solicitacao> _demo = [
    Solicitacao.fromMap('demoA', {
      'cliente_uid': 'demo',
      'cliente_nome': 'Bruno',
      'profissional_uid': 'teste_diego',
      'profissional_nome': 'Diego Santos',
      'servico_id': 'd4',
      'servico_nome': 'Lavagem completa',
      'categoria_id': 'veiculos',
      'variacao': 'Carro médio',
      'preco_referencia': 70.0,
      'data': dataIso(DateTime.now().add(const Duration(days: 2))),
      'periodo': 'manha',
      'bairro': 'salgado',
      'observacao': 'Carro na garagem, tem torneira.',
      'status': 'proposta',
      'valor_final': 75.0,
      'mensagem_profissional': 'Inclui cera. Chego às 9h.',
      'criado_em': DateTime.now().subtract(const Duration(hours: 3)),
    }),
    Solicitacao.fromMap('demoB', {
      'cliente_uid': 'teste_ana',
      'cliente_nome': 'Ana Souza',
      'profissional_uid': 'demo',
      'servico_id': 'demo1',
      'servico_nome': 'Faxina residencial',
      'categoria_id': 'limpeza',
      'variacao': '2 quartos',
      'preco_referencia': 140.0,
      'data': dataIso(DateTime.now().add(const Duration(days: 3))),
      'periodo': 'tarde',
      'bairro': 'universitario',
      'observacao': 'Apartamento no 3º andar, sem elevador.',
      'status': 'pendente',
      'criado_em': DateTime.now().subtract(const Duration(minutes: 40)),
    }),
  ];

  Stream<List<Solicitacao>> _demoStream(String campo) async* {
    List<Solicitacao> filtrar() => ordenar(_demo
        .where((s) => (campo == 'cliente_uid' ? s.clienteUid : s.profissionalUid) == _demoUid)
        .toList());
    yield filtrar();
    await for (final _ in _demoMudou.stream) {
      yield filtrar();
    }
  }

  void _demoAdd(Solicitacao s) {
    _demo.add(s);
    _demoMudou.add(null);
  }

  void _demoMudar(String id, Map<String, Object?> campos) {
    final i = _demo.indexWhere((s) => s.id == id);
    if (i < 0) return;
    final s = _demo[i];
    _demo[i] = Solicitacao.fromMap(id, {
      'cliente_uid': s.clienteUid,
      'cliente_nome': s.clienteNome,
      'profissional_uid': s.profissionalUid,
      'profissional_nome': s.profissionalNome,
      'servico_id': s.servicoId,
      'servico_nome': s.servicoNome,
      'categoria_id': s.categoriaId,
      'variacao': s.variacao,
      'preco_referencia': s.precoReferencia,
      'data': s.data,
      'periodo': s.periodo.id,
      'bairro': s.bairro,
      'observacao': s.observacao,
      'status': s.status.id,
      'valor_final': s.valorFinal,
      'mensagem_profissional': s.mensagemProfissional,
      'criado_em': s.criadoEm,
      ...campos,
    });
    _demoMudou.add(null);
  }
}
