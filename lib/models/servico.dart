import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

/// Documento da coleção `servicos` no Firestore.
///
/// Campos: nome_servico, categoria, descricao, preco_base (Double),
/// duracao_minutos (Integer), ativo (Boolean), criado_em (Timestamp).
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

  factory Servico.fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc) {
    final d = doc.data() ?? const <String, dynamic>{};
    return Servico.fromMap(doc.id, d);
  }

  factory Servico.fromMap(String id, Map<String, dynamic> d) {
    final preco = d['preco_base'];
    final duracao = d['duracao_minutos'];
    final criado = d['criado_em'];
    final prof = d['profissional_ref'];
    String txt(Object? v) => v is String ? v.trim() : '';
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
    );
  }

  Map<String, dynamic> toMap() => {
        'nome_servico': nome,
        'categoria': categoria,
        'descricao': descricao,
        'preco_base': precoBase,
        'duracao_minutos': duracaoMinutos,
        'ativo': ativo,
        if (profissionalRef != null) 'profissional_ref': profissionalRef,
        'criado_em':
            criadoEm != null ? Timestamp.fromDate(criadoEm!) : FieldValue.serverTimestamp(),
      };

  static final _moeda = NumberFormat.currency(locale: 'pt_BR', symbol: r'R$');

  /// Ex.: "R$ 25,00". Nulo quando o serviço não tem preço base.
  String? get precoFormatado => precoBase == null ? null : _moeda.format(precoBase);

  /// Ex.: "40 min", "1h", "1h30".
  String? get duracaoFormatada {
    final m = duracaoMinutos;
    if (m == null || m <= 0) return null;
    if (m < 60) return '$m min';
    final h = m ~/ 60, r = m % 60;
    return r == 0 ? '${h}h' : '${h}h${r.toString().padLeft(2, '0')}';
  }
}
