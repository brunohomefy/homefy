import 'package:cloud_firestore/cloud_firestore.dart';

import '../config.dart';
import '../models/servico.dart';

/// Leitura da coleção `servicos`.
class ServicosRepo {
  const ServicosRepo();

  /// Mesma consulta da Home do FlutterFlow: ativo == true, limite 10.
  /// Stream: se alguém editar no console do Firebase, a Home atualiza sozinha.
  Stream<List<Servico>> ativos({int limite = 10}) {
    if (kModoDemo) {
      return Stream.fromFuture(
        Future.delayed(const Duration(milliseconds: 900), () => _exemplos),
      );
    }
    return FirebaseFirestore.instance
        .collection('servicos')
        .where('ativo', isEqualTo: true)
        .limit(limite)
        .snapshots()
        .map((snap) => snap.docs.map(Servico.fromFirestore).toList());
  }

  static final _nomes = <String, Future<String?>>{};

  /// Nome do profissional dono do serviço (campo `nome` em `usuarios`).
  /// Guarda em memória para não buscar o mesmo profissional várias vezes.
  Future<String?> nomeDoProfissional(DocumentReference<Map<String, dynamic>> ref) {
    return _nomes.putIfAbsent(ref.path, () async {
      try {
        final doc = await ref.get();
        final nome = doc.data()?['nome'];
        return nome is String && nome.trim().isNotEmpty ? nome.trim() : null;
      } catch (_) {
        _nomes.remove(ref.path); // tenta de novo na próxima vez
        return null;
      }
    });
  }

  /// Dados SÓ do modo demonstração (nunca aparecem com o Firebase real).
  static final _exemplos = <Servico>[
    Servico.fromMap('d1', {
      'nome_servico': 'Corte Masculino',
      'categoria': 'Cabeleireiro(a)',
      'descricao': 'Corte com máquina e tesoura, acabamento na navalha.',
      'preco_base': 25.0,
      'duracao_minutos': 40,
      'ativo': true,
    }),
    Servico.fromMap('d2', {
      'nome_servico': 'Corte + Barba',
      'categoria': 'Barbeiro(a)',
      'descricao': 'Corte completo e barba com toalha quente.',
      'preco_base': 40.0,
      'duracao_minutos': 60,
      'ativo': true,
    }),
    Servico.fromMap('d3', {
      'nome_servico': 'Mão e pé',
      'categoria': 'Manicure',
      'descricao': 'Cutilagem, esmaltação e hidratação.',
      'preco_base': 45.0,
      'duracao_minutos': 90,
      'ativo': true,
    }),
    Servico.fromMap('d4', {
      'nome_servico': 'Lavagem completa',
      'categoria': 'Lavagem de veículos',
      'descricao': 'Lavagem externa e interna no seu endereço.',
      'preco_base': 60.0,
      'duracao_minutos': 75,
      'ativo': true,
    }),
    Servico.fromMap('d5', {
      'nome_servico': 'Faxina residencial',
      'categoria': 'Limpeza',
      'descricao': 'Limpeza geral de casa ou apartamento.',
      'preco_base': 150.0,
      'duracao_minutos': 240,
      'ativo': true,
    }),
  ];
}
