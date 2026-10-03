import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

/// Documento `avaliacoes/{solicitacaoId}`: uma avaliação por atendimento concluído.
class Avaliacao {
  const Avaliacao({
    required this.id,
    required this.profissionalUid,
    required this.clienteUid,
    required this.clienteNome,
    required this.servicoNome,
    required this.nota,
    required this.comentario,
    this.criadoEm,
  });

  final String id;
  final String profissionalUid;
  final String clienteUid;

  /// Só o primeiro nome (é público).
  final String clienteNome;
  final String servicoNome;
  final int nota;
  final String comentario;
  final DateTime? criadoEm;

  factory Avaliacao.fromMap(String id, Map<String, dynamic> d) {
    String txt(Object? v) => v is String ? v.trim() : '';
    final nota = d['nota'];
    final criado = d['criado_em'];
    return Avaliacao(
      id: id,
      profissionalUid: txt(d['profissional_uid']),
      clienteUid: txt(d['cliente_uid']),
      clienteNome: txt(d['cliente_nome']),
      servicoNome: txt(d['servico_nome']),
      nota: nota is num ? nota.toInt().clamp(1, 5) : 5,
      comentario: txt(d['comentario']),
      criadoEm: criado is Timestamp ? criado.toDate() : (criado is DateTime ? criado : null),
    );
  }

  factory Avaliacao.fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc) =>
      Avaliacao.fromMap(doc.id, doc.data() ?? const {});

  /// Primeiro nome, para não expor o nome completo do cliente.
  static String primeiroNome(String nome) {
    final p = nome.trim().split(RegExp(r'\s+')).first;
    return p.length > 40 ? p.substring(0, 40) : p;
  }
}

/// Média e quantidade de avaliações de um profissional.
class ResumoNotas {
  const ResumoNotas(this.media, this.total);
  final double media;
  final int total;

  static ResumoNotas de(List<Avaliacao> l) {
    if (l.isEmpty) return const ResumoNotas(0, 0);
    final soma = l.fold<int>(0, (a, b) => a + b.nota);
    return ResumoNotas(soma / l.length, l.length);
  }

  /// "4,8"
  String get mediaTexto => media.toStringAsFixed(1).replaceAll('.', ',');

  /// "4,8 (12 avaliações)" / "Novo no Homefy"
  String get texto => total == 0
      ? 'Ainda sem avaliações'
      : '$mediaTexto (${total == 1 ? '1 avaliação' : '$total avaliações'})';
}

/// Linha de estrelas. Com [aoEscolher], vira seletor de nota.
class Estrelas extends StatelessWidget {
  const Estrelas({super.key, required this.nota, this.tamanho = 18, this.aoEscolher});
  final double nota;
  final double tamanho;
  final ValueChanged<int>? aoEscolher;

  static const cor = Color(0xFFF4A100);

  @override
  Widget build(BuildContext context) {
    return Row(mainAxisSize: MainAxisSize.min, children: [
      for (var i = 1; i <= 5; i++)
        _estrela(i),
    ]);
  }

  Widget _estrela(int i) {
    final icone = nota >= i
        ? Icons.star_rounded
        : (nota >= i - 0.5 ? Icons.star_half_rounded : Icons.star_outline_rounded);
    final w = Icon(icone, color: cor, size: tamanho);
    if (aoEscolher == null) return w;
    return Semantics(
      button: true,
      label: '$i ${i == 1 ? 'estrela' : 'estrelas'}',
      child: InkResponse(
        onTap: () => aoEscolher!(i),
        radius: tamanho * 0.8,
        child: Padding(padding: const EdgeInsets.all(4), child: w),
      ),
    );
  }
}
