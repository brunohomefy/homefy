import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

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

  // ───────────── Serviços do próprio profissional ─────────────

  static final _demoMeus = <Servico>[];
  static final _demoMudou = StreamController<void>.broadcast();

  DocumentReference<Map<String, dynamic>>? get _minhaRef {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    return uid == null ? null : FirebaseFirestore.instance.collection('usuarios').doc(uid);
  }

  /// Todos os serviços do usuário logado (ativos e desativados).
  /// Sem orderBy na consulta para não precisar de índice composto:
  /// a ordenação (ativos primeiro, depois categoria e preço) é feita aqui.
  Stream<List<Servico>> meus() {
    List<Servico> ordenarMeus(List<Servico> l) {
      final ativos = ordenar(l.where((s) => s.ativo).toList());
      final inativos = ordenar(l.where((s) => !s.ativo).toList());
      return [...ativos, ...inativos];
    }

    if (kModoDemo) {
      Stream<List<Servico>> demo() async* {
        yield ordenarMeus(List.of(_demoMeus));
        await for (final _ in _demoMudou.stream) {
          yield ordenarMeus(List.of(_demoMeus));
        }
      }

      return demo();
    }
    final ref = _minhaRef;
    if (ref == null) return Stream.value(const []);
    return FirebaseFirestore.instance
        .collection('servicos')
        .where('profissional_ref', isEqualTo: ref)
        .snapshots()
        .map((snap) => ordenarMeus(snap.docs.map(Servico.fromFirestore).toList()));
  }

  /// Cria (id nulo) ou atualiza um serviço do próprio profissional.
  Future<void> salvar({
    String? id,
    required String nome,
    required Categoria categoria,
    required String? subtipo,
    required String descricao,
    required List<Variacao> variacoes,
    required List<String> bairros,
    required bool atendeTodaCidade,
    required bool ativo,
  }) async {
    if (kModoDemo) {
      final novo = Servico.fromMap(id ?? 'demo${_demoMeus.length + 1}', {
        'nome_servico': nome,
        'categoria': categoria.rotulo,
        'categoria_id': categoria.id,
        'subtipo': subtipo,
        'descricao': descricao,
        'variacoes': variacoes.map((v) => v.toMap()).toList(),
        'preco_base': (variacoes.map((v) => v.preco).whereType<double>().toList()..sort()).firstOrNull,
        'duracao_minutos': variacoes.first.duracaoMinutos,
        'ativo': ativo,
      });
      _demoMeus.removeWhere((s) => s.id == novo.id);
      _demoMeus.add(novo);
      _demoMudou.add(null);
      return;
    }
    final ref = _minhaRef;
    if (ref == null) throw StateError('Sem usuário logado');
    final dados = Servico.dadosParaGravar(
      nome: nome,
      categoria: categoria,
      subtipo: subtipo,
      descricao: descricao,
      variacoes: variacoes,
      bairros: atendeTodaCidade ? const [] : bairros,
      atendeTodaCidade: atendeTodaCidade,
      ativo: ativo,
      profissionalRef: ref,
    );
    final col = FirebaseFirestore.instance.collection('servicos');
    if (id == null) {
      await col.add({...dados, 'criado_em': FieldValue.serverTimestamp()});
    } else {
      await col.doc(id).update(dados);
    }
  }

  /// Liga/desliga o serviço na vitrine (não apaga: preserva o histórico).
  Future<void> definirAtivo(String id, bool ativo) async {
    if (kModoDemo) {
      final i = _demoMeus.indexWhere((s) => s.id == id);
      if (i >= 0) {
        final s = _demoMeus[i];
        _demoMeus[i] = Servico.fromMap(s.id, {
          'nome_servico': s.nome,
          'categoria_id': s.categoriaId,
          'subtipo': s.subtipo,
          'descricao': s.descricao,
          'variacoes': s.variacoes.map((v) => v.toMap()).toList(),
          'preco_base': s.precoBase,
          'ativo': ativo,
        });
        _demoMudou.add(null);
      }
      return;
    }
    await FirebaseFirestore.instance.collection('servicos').doc(id).update({
      'ativo': ativo,
      'atualizado_em': FieldValue.serverTimestamp(),
    });
  }

  // ───────────── Perfil do profissional na vitrine ─────────────

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
      'categoria_id': 'cabelo',
      'subtipo': 'corte_masculino',
      'bairros': ['salgado', 'universitario', 'mauricio_de_nassau'],
      'descricao': 'Corte com máquina e tesoura, acabamento na navalha.',
      'preco_base': 25.0,
      'duracao_minutos': 40,
      'ativo': true,
    }),
    Servico.fromMap('d2', {
      'nome_servico': 'Corte + Barba',
      'categoria': 'Barbeiro(a)',
      'categoria_id': 'cabelo',
      'subtipo': 'barba',
      'bairros': ['universitario'],
      'descricao': 'Corte completo e barba com toalha quente.',
      'preco_base': 40.0,
      'duracao_minutos': 60,
      'ativo': true,
    }),
    Servico.fromMap('d3', {
      'nome_servico': 'Mão e pé',
      'categoria': 'Manicure',
      'categoria_id': 'manicure',
      'subtipo': 'mao_pe',
      'bairros': ['salgado', 'petropolis'],
      'descricao': 'Cutilagem, esmaltação e hidratação.',
      'preco_base': 45.0,
      'duracao_minutos': 90,
      'ativo': true,
    }),
    Servico.fromMap('d4', {
      'nome_servico': 'Lavagem completa',
      'categoria': 'Lavagem de veículos',
      'categoria_id': 'veiculos',
      'subtipo': 'lavagem_completa',
      'atende_toda_cidade': true,
      'variacoes': [
        {'rotulo': 'Carro pequeno', 'preco': 60.0, 'duracao_minutos': 75},
        {'rotulo': 'Carro médio', 'preco': 70.0, 'duracao_minutos': 90},
        {'rotulo': 'SUV ou picape', 'preco': 90.0, 'duracao_minutos': 110},
      ],
      'descricao': 'Lavagem externa e interna no seu endereço.',
      'preco_base': 60.0,
      'duracao_minutos': 75,
      'ativo': true,
    }),
    Servico.fromMap('d5', {
      'nome_servico': 'Faxina residencial',
      'categoria': 'Limpeza',
      'categoria_id': 'limpeza',
      'subtipo': 'faxina_residencial',
      'bairros': ['salgado', 'kennedy', 'vila_do_aeroporto'],
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
