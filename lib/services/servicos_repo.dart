import 'package:cloud_firestore/cloud_firestore.dart';

import '../config.dart';
import '../models/categoria.dart';
import '../models/servico.dart';

/// Leitura da coleção `servicos`.
class ServicosRepo {
  const ServicosRepo();

  /// Serviços com ativo == true, já ordenados (categoria do MVP, depois preço).
  /// Stream: se alguém editar no console do Firebase, a Home atualiza sozinha.
  ///
  /// Limite 50: cada abertura da Home lê até 50 documentos. No plano grátis
  /// (50 mil leituras/dia) isso dá ~1.000 aberturas por dia. Quando o catálogo
  /// passar de 50 serviços, trocar por busca filtrada por categoria/bairro.
  Stream<List<Servico>> ativos({int limite = 50}) {
    if (kModoDemo) {
      return Stream.fromFuture(
        Future.delayed(const Duration(milliseconds: 900), () => ordenar([..._exemplos])),
      );
    }
    return FirebaseFirestore.instance
        .collection('servicos')
        .where('ativo', isEqualTo: true)
        .limit(limite)
        .snapshots()
        .map((snap) => ordenar(snap.docs.map(Servico.fromFirestore).toList()));
  }

  /// Ordem da vitrine: categorias na ordem do MVP, depois menor preço.
  /// Serviço sem preço vai para o fim da sua categoria.
  static List<Servico> ordenar(List<Servico> lista) {
    int ordemCat(Servico s) {
      final c = s.categoriaMvp;
      return c == null ? Categoria.todas.length : Categoria.todas.indexOf(c);
    }

    lista.sort((a, b) {
      final c = ordemCat(a).compareTo(ordemCat(b));
      if (c != 0) return c;
      return (a.precoBase ?? double.infinity).compareTo(b.precoBase ?? double.infinity);
    });
    return lista;
  }

  static final _perfis = <String, Future<PerfilProfissional?>>{};

  /// Nome e descrição do profissional dono do serviço (documento em `usuarios`).
  /// Guarda em memória para não buscar o mesmo profissional várias vezes.
  Future<PerfilProfissional?> perfilDoProfissional(
      DocumentReference<Map<String, dynamic>> ref) {
    return _perfis.putIfAbsent(ref.path, () async {
      try {
        final d = (await ref.get()).data();
        final nome = d?['nome'];
        if (nome is! String || nome.trim().isEmpty) return null;
        final desc = d?['descricao'];
        return PerfilProfissional(
          nome: nome.trim(),
          descricao: desc is String ? desc.trim() : '',
        );
      } catch (_) {
        _perfis.remove(ref.path); // tenta de novo na próxima vez
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

/// Parte pública do perfil do profissional mostrada ao cliente.
class PerfilProfissional {
  const PerfilProfissional({required this.nome, required this.descricao});
  final String nome;
  final String descricao;
}
