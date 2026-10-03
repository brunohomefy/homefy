import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import 'servico.dart';

/// Período do dia do atendimento. Mais simples que hora marcada e combina
/// com serviço em domicílio (o horário exato é acertado no WhatsApp).
enum Periodo {
  manha('manha', 'Manhã', '8h–12h', Icons.wb_twilight_rounded),
  tarde('tarde', 'Tarde', '13h–17h', Icons.wb_sunny_outlined),
  noite('noite', 'Noite', '18h–21h', Icons.nights_stay_outlined);

  const Periodo(this.id, this.rotulo, this.faixa, this.icone);
  final String id;
  final String rotulo;
  final String faixa;
  final IconData icone;

  static Periodo? porId(String? id) {
    for (final p in values) {
      if (p.id == id) return p;
    }
    return null;
  }
}

/// Situação do pedido. A ordem das transições é garantida pelas regras do Firestore.
enum StatusPedido {
  pendente('pendente', 'Aguardando o profissional', Color(0xFFB7791F)),
  proposta('proposta', 'Valor enviado: falta você confirmar', Color(0xFF0077B6)),
  confirmada('confirmada', 'Confirmado', Color(0xFF2D6A4F)),
  concluida('concluida', 'Concluído', Color(0xFF5B6660)),
  recusada('recusada', 'Recusado pelo profissional', Color(0xFFD90429)),
  cancelada('cancelada', 'Cancelado', Color(0xFF98A29C));

  const StatusPedido(this.id, this.rotuloCliente, this.cor);
  final String id;
  final String rotuloCliente;
  final Color cor;

  /// O mesmo status visto pelo profissional.
  String get rotuloProfissional => switch (this) {
        pendente => 'Novo pedido: responda',
        proposta => 'Aguardando o cliente confirmar',
        _ => rotuloCliente,
      };

  bool get encerrado => this == concluida || this == recusada || this == cancelada;

  static StatusPedido porId(String? id) {
    for (final s in values) {
      if (s.id == id) return s;
    }
    return pendente;
  }
}

/// Documento `solicitacoes/{id}`.
class Solicitacao {
  const Solicitacao({
    required this.id,
    required this.clienteUid,
    required this.clienteNome,
    required this.profissionalUid,
    this.profissionalNome = '',
    required this.servicoId,
    required this.servicoNome,
    required this.categoriaId,
    required this.variacao,
    required this.precoReferencia,
    required this.data,
    required this.periodo,
    required this.bairro,
    required this.observacao,
    required this.status,
    this.valorFinal,
    this.mensagemProfissional = '',
    this.criadoEm,
    this.canceladoPor,
  });

  final String id;
  final String clienteUid;
  final String clienteNome;
  final String profissionalUid;
  final String profissionalNome;
  final String servicoId;
  final String servicoNome;
  final String? categoriaId;
  final String variacao;
  final double? precoReferencia;

  /// 'AAAA-MM-DD'
  final String data;
  final Periodo periodo;

  /// Id do bairro (models/bairros.dart).
  final String bairro;
  final String observacao;
  final StatusPedido status;
  final double? valorFinal;
  final String mensagemProfissional;
  final DateTime? criadoEm;
  final String? canceladoPor;

  /// Id do documento em `agenda`: trava o horário do profissional.
  String get agendaId => idAgenda(profissionalUid, data, periodo);

  static String idAgenda(String profissionalUid, String data, Periodo p) =>
      '${profissionalUid}_${data}_${p.id}';

  factory Solicitacao.fromMap(String id, Map<String, dynamic> d) {
    String txt(Object? v) => v is String ? v.trim() : '';
    final preco = d['preco_referencia'];
    final valor = d['valor_final'];
    final criado = d['criado_em'];
    return Solicitacao(
      id: id,
      clienteUid: txt(d['cliente_uid']),
      clienteNome: txt(d['cliente_nome']),
      profissionalUid: txt(d['profissional_uid']),
      profissionalNome: txt(d['profissional_nome']),
      servicoId: txt(d['servico_id']),
      servicoNome: txt(d['servico_nome']).isEmpty ? 'Serviço' : txt(d['servico_nome']),
      categoriaId: txt(d['categoria_id']).isEmpty ? null : txt(d['categoria_id']),
      variacao: txt(d['variacao']),
      precoReferencia: preco is num ? preco.toDouble() : null,
      data: txt(d['data']),
      periodo: Periodo.porId(txt(d['periodo'])) ?? Periodo.manha,
      bairro: txt(d['bairro']),
      observacao: txt(d['observacao']),
      status: StatusPedido.porId(txt(d['status'])),
      valorFinal: valor is num ? valor.toDouble() : null,
      mensagemProfissional: txt(d['mensagem_profissional']),
      criadoEm: criado is Timestamp ? criado.toDate() : (criado is DateTime ? criado : null),
      canceladoPor: txt(d['cancelado_por']).isEmpty ? null : txt(d['cancelado_por']),
    );
  }

  factory Solicitacao.fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc) =>
      Solicitacao.fromMap(doc.id, doc.data() ?? const {});

  /// Dados do pedido novo. Precisa bater com as regras de `solicitacoes`.
  static Map<String, dynamic> novo({
    required String clienteUid,
    required String clienteNome,
    required String profissionalUid,
    required String profissionalNome,
    required Servico servico,
    required Variacao variacao,
    required String data,
    required Periodo periodo,
    required String bairro,
    required String observacao,
  }) =>
      {
        'cliente_uid': clienteUid,
        'cliente_nome': clienteNome.length > 80 ? clienteNome.substring(0, 80) : clienteNome,
        'profissional_uid': profissionalUid,
        'profissional_nome':
            profissionalNome.length > 80 ? profissionalNome.substring(0, 80) : profissionalNome,
        'servico_id': servico.id,
        'servico_nome': servico.nome.length > 60 ? servico.nome.substring(0, 60) : servico.nome,
        'categoria_id': servico.categoriaMvp?.id ?? '',
        'variacao': variacao.rotulo,
        'preco_referencia': variacao.preco,
        'data': data,
        'periodo': periodo.id,
        'bairro': bairro,
        'observacao': observacao.trim(),
        'status': StatusPedido.pendente.id,
        'criado_em': FieldValue.serverTimestamp(),
      };

  /// Pedido ainda pode ser cancelado? (concluído/recusado/cancelado não).
  bool get podeCancelar => !status.encerrado;

  /// A data do atendimento já passou?
  bool passou(DateTime hoje) {
    final d = DateTime.tryParse(data);
    if (d == null) return false;
    return d.isBefore(DateTime(hoje.year, hoje.month, hoje.day));
  }
}

/// 'AAAA-MM-DD' de uma data (sem hora).
String dataIso(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

const _diasSemana = ['seg', 'ter', 'qua', 'qui', 'sex', 'sáb', 'dom'];
const _meses = ['jan', 'fev', 'mar', 'abr', 'mai', 'jun', 'jul', 'ago', 'set', 'out', 'nov', 'dez'];

/// '2026-10-10' → 'sáb, 10 out'
String dataCurta(String iso) {
  final d = DateTime.tryParse(iso);
  if (d == null) return iso;
  return '${_diasSemana[d.weekday - 1]}, ${d.day} ${_meses[d.month - 1]}';
}

/// Próximos [n] dias a partir de amanhã (o profissional precisa de tempo para responder).
List<DateTime> proximosDias(DateTime hoje, {int n = 14}) => [
      for (var i = 1; i <= n; i++) DateTime(hoje.year, hoje.month, hoje.day + i),
    ];

/// Link do WhatsApp com mensagem pronta (grátis, sem API paga).
Uri linkWhatsapp(String numero, String mensagem) =>
    Uri.https('wa.me', '/$numero', {'text': mensagem});
