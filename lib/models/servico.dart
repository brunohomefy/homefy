import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

import 'categoria.dart';

/// Uma faixa de preço do serviço (decisão D2), ex.: "SUV ou picape" a partir de R$ 90.
/// Preço nulo = "sob consulta".
class Variacao {
  const Variacao({required this.rotulo, this.preco, this.duracaoMinutos});

  final String rotulo;
  final double? preco;
  final int? duracaoMinutos;

  static const rotuloPadrao = 'Padrão';

  factory Variacao.fromMap(Object? m) {
    final d = m is Map ? m : const {};
    final r = d['rotulo'];
    final p = d['preco'];
    final dur = d['duracao_minutos'];
    return Variacao(
      rotulo: r is String && r.trim().isNotEmpty ? r.trim() : rotuloPadrao,
      preco: p is num ? p.toDouble() : null,
      duracaoMinutos: dur is num ? dur.toInt() : null,
    );
  }

  Map<String, dynamic> toMap() => {
        'rotulo': rotulo,
        'preco': preco,
        'duracao_minutos': duracaoMinutos,
      };
}

/// Documento da coleção `servicos` no Firestore.
///
/// Campos antigos (FlutterFlow): nome_servico, categoria, descricao,
/// preco_base, duracao_minutos, ativo, criado_em, profissional_ref.
/// Campos novos (cadastro de profissional): categoria_id, subtipo, variacoes,
/// bairros, atende_toda_cidade, atualizado_em.
///
/// `preco_base` continua sendo gravado (menor preço das variações), para a
/// vitrine ordenar por preço sem abrir as variações.
/// A leitura é tolerante: campo ausente ou com tipo errado não derruba a tela.
class Servico {
  const Servico({
    required this.id,
    required this.nome,
    required this.categoria,
    required this.descricao,
    required this.precoBase,
    required this.duracaoMinutos,
    required this.ativo,
    this.criadoEm,
    this.profissionalRef,
    this.categoriaId,
    this.subtipo,
    this.variacoes = const [],
    this.bairros = const [],
    this.atendeTodaCidade = false,
  });

  final String id;
  final String nome;
  final String categoria;
  final String descricao;
  final double? precoBase;
  final int? duracaoMinutos;
  final bool ativo;
  final DateTime? criadoEm;

  /// Referência ao documento do profissional em `usuarios` (pode faltar).
  final DocumentReference<Map<String, dynamic>>? profissionalRef;

  /// Id fixo da categoria ('cabelo', 'manicure', 'veiculos', 'limpeza').
  final String? categoriaId;

  /// Id do subtipo (ex.: 'pos_obra').
  final String? subtipo;

  final List<Variacao> variacoes;

  /// Ids dos bairros atendidos, copiados do perfil do profissional.
  final List<String> bairros;
  final bool atendeTodaCidade;

  factory Servico.fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc) {
    final d = doc.data() ?? const <String, dynamic>{};
    return Servico.fromMap(doc.id, d);
  }

  factory Servico.fromMap(String id, Map<String, dynamic> d) {
    final preco = d['preco_base'];
    final duracao = d['duracao_minutos'];
    final criado = d['criado_em'];
    final prof = d['profissional_ref'];
    final vars = d['variacoes'];
    final bairros = d['bairros'];
    String txt(Object? v) => v is String ? v.trim() : '';
    String? opt(Object? v) => v is String && v.trim().isNotEmpty ? v.trim() : null;
    final nome = txt(d['nome_servico']);
    return Servico(
      id: id,
      nome: nome.isNotEmpty ? nome : 'Serviço sem nome',
      categoria: txt(d['categoria']),
      descricao: txt(d['descricao']),
      precoBase: preco is num ? preco.toDouble() : null,
      duracaoMinutos: duracao is num ? duracao.toInt() : null,
      ativo: d['ativo'] == true,
      criadoEm: criado is Timestamp ? criado.toDate() : null,
      profissionalRef: prof is DocumentReference<Map<String, dynamic>> ? prof : null,
      categoriaId: opt(d['categoria_id']),
      subtipo: opt(d['subtipo']),
      variacoes: vars is List ? vars.map(Variacao.fromMap).toList() : const [],
      bairros: bairros is List ? bairros.whereType<String>().toList() : const [],
      atendeTodaCidade: d['atende_toda_cidade'] == true,
    );
  }

  /// Categoria do MVP: pelo id fixo (serviços novos) ou por palavra-chave
  /// no texto livre (serviços antigos do FlutterFlow).
  Categoria? get categoriaMvp => Categoria.porId(categoriaId) ?? Categoria.deServico(categoria);

  /// Nome do subtipo para mostrar (ex.: "Limpeza pós-obra").
  String? get subtipoRotulo => categoriaMvp?.subtipo(subtipo)?.rotulo;

  /// Etiqueta da linha 2 do card. Sempre o nome oficial da categoria
  /// ("Lava-jato" antigo vira "Lavagem de veículos"); texto antigo só se não reconhecer.
  String get categoriaRotulo => categoriaMvp?.rotulo ?? categoria;

  /// Este serviço atende o bairro escolhido pelo cliente?
  /// Serviços antigos, sem bairros informados, não entram no filtro.
  bool atende(String bairroId) => atendeTodaCidade || bairros.contains(bairroId);

  /// Variações para exibir. Serviço antigo vira uma variação "Padrão".
  List<Variacao> get variacoesOuPadrao => variacoes.isNotEmpty
      ? variacoes
      : [Variacao(rotulo: Variacao.rotuloPadrao, preco: precoBase, duracaoMinutos: duracaoMinutos)];

  /// Tem mais de uma faixa de preço? (o card mostra "a partir de" o menor)
  bool get temVariacoes => variacoes.length > 1;

  /// Dados para gravar um serviço criado/editado no app.
  /// Precisa bater com as regras de `servicos` em firestore.rules.
  static Map<String, dynamic> dadosParaGravar({
    required String nome,
    required Categoria categoria,
    required String? subtipo,
    required String descricao,
    required List<Variacao> variacoes,
    required List<String> bairros,
    required bool atendeTodaCidade,
    required bool ativo,
    required DocumentReference profissionalRef,
  }) {
    final precos = variacoes.map((v) => v.preco).whereType<double>().toList()..sort();
    return {
      'nome_servico': nome.trim(),
      'categoria': categoria.rotulo,
      'categoria_id': categoria.id,
      'subtipo': subtipo,
      'descricao': descricao.trim(),
      'variacoes': variacoes.map((v) => v.toMap()).toList(),
      'preco_base': precos.isEmpty ? null : precos.first,
      'duracao_minutos': variacoes.first.duracaoMinutos,
      'bairros': bairros,
      'atende_toda_cidade': atendeTodaCidade,
      'ativo': ativo,
      'profissional_ref': profissionalRef,
      'atualizado_em': FieldValue.serverTimestamp(),
    };
  }

  static final _moeda = NumberFormat.currency(locale: 'pt_BR', symbol: r'R$');

  static String? formatarPreco(double? v) => v == null ? null : _moeda.format(v);

  /// Ex.: "40 min", "1h", "1h30".
  static String? formatarDuracao(int? m) {
    if (m == null || m <= 0) return null;
    if (m < 60) return '$m min';
    final h = m ~/ 60, r = m % 60;
    return r == 0 ? '${h}h' : '${h}h${r.toString().padLeft(2, '0')}';
  }

  /// Ex.: "R$ 25,00". Nulo quando o serviço não tem preço base.
  String? get precoFormatado => formatarPreco(precoBase);

  String? get duracaoFormatada => formatarDuracao(duracaoMinutos);
}
