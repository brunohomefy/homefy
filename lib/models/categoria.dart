import 'package:flutter/material.dart';

/// As 4 categorias do MVP (dossiê, item 5).
///
/// O campo `categoria` dos documentos em `servicos` é texto livre hoje
/// (ex.: "Cabeleireiro(a)"). A associação é feita por palavras-chave,
/// para não quebrar com pequenas variações de escrita.
class Categoria {
  const Categoria({
    required this.id,
    required this.rotulo,
    required this.icone,
    required this.cor,
    required this.palavrasChave,
    this.sinonimos = const [],
    this.subtipos = const [],
    this.portes = const [],
  });

  final String id;
  final String rotulo;
  final IconData icone;
  final Color cor;
  final List<String> palavrasChave;

  /// Palavras que o cliente pode digitar na busca (sem acento).
  final List<String> sinonimos;

  /// Tipos de serviço que o profissional marca se faz (decisão D1).
  final List<Subtipo> subtipos;

  /// Variações de porte sugeridas para o preço (decisão D2).
  /// Lista vazia: a categoria usa só o preço "Padrão".
  final List<String> portes;

  Subtipo? subtipo(String? id) {
    for (final s in subtipos) {
      if (s.id == id) return s;
    }
    return null;
  }

  /// Categoria pelo id fixo gravado em `categoria_id` (ex.: 'limpeza').
  static Categoria? porId(String? id) {
    for (final c in todas) {
      if (c.id == id) return c;
    }
    return null;
  }

  bool combinaCom(String categoriaDoServico) {
    final alvo = normalizar(categoriaDoServico);
    return palavrasChave.any(alvo.contains);
  }

  /// Busca digitada pelo cliente (já normalizada) bate com esta categoria?
  /// Aceita palavra começada (ex.: "manic") e sinônimos (ex.: "unha").
  bool combinaComBusca(String termo) {
    if (termo.length < 3) return false;
    final palavras = termo.split(RegExp(r'\s+'));
    return palavras.any((p) =>
        p.length >= 3 &&
        [...palavrasChave, ...sinonimos].any((k) => k.startsWith(p) || p.startsWith(k)));
  }

  static Categoria? deServico(String categoriaDoServico) {
    for (final c in todas) {
      if (c.combinaCom(categoriaDoServico)) return c;
    }
    return null;
  }

  static const todas = <Categoria>[
    Categoria(
      id: 'cabelo',
      rotulo: 'Cabelo e barba',
      icone: Icons.content_cut_rounded,
      cor: Color(0xFF2D6A4F),
      palavrasChave: ['cabel', 'barb', 'corte'],
      sinonimos: ['cabelo', 'barba', 'barbeiro', 'cabeleireiro', 'escova', 'pezinho'],
      subtipos: [
        Subtipo('corte_masculino', 'Corte masculino'),
        Subtipo('corte_feminino', 'Corte feminino'),
        Subtipo('corte_infantil', 'Corte infantil'),
        Subtipo('barba', 'Barba'),
        Subtipo('escova_penteado', 'Escova e penteado'),
        Subtipo('coloracao_quimica', 'Coloração e química'),
      ],
      portes: ['Cabelo curto', 'Cabelo médio', 'Cabelo longo'],
    ),
    Categoria(
      id: 'manicure',
      rotulo: 'Manicure',
      icone: Icons.back_hand_outlined,
      cor: Color(0xFFC0567A),
      palavrasChave: ['manicure', 'pedicure', 'unha'],
      sinonimos: ['unhas', 'esmalte', 'esmaltacao', 'alongamento', 'cuticula'],
      subtipos: [
        Subtipo('mao', 'Mão'),
        Subtipo('pe', 'Pé'),
        Subtipo('mao_pe', 'Mão e pé'),
        Subtipo('alongamento', 'Alongamento'),
        Subtipo('esmaltacao_gel', 'Esmaltação em gel'),
      ],
    ),
    Categoria(
      id: 'veiculos',
      rotulo: 'Lavagem de veículos',
      icone: Icons.local_car_wash_rounded,
      cor: Color(0xFF0077B6),
      palavrasChave: ['lava', 'veicul', 'carro', 'moto'],
      sinonimos: ['lavagem', 'lavajato', 'automovel', 'automotiva', 'polimento'],
      subtipos: [
        Subtipo('lavagem_simples', 'Lavagem simples'),
        Subtipo('lavagem_completa', 'Lavagem completa (interna e externa)'),
        Subtipo('higienizacao_interna', 'Higienização interna'),
        Subtipo('polimento', 'Polimento'),
      ],
      portes: ['Moto', 'Carro pequeno', 'Carro médio', 'SUV ou picape'],
    ),
    Categoria(
      id: 'limpeza',
      rotulo: 'Limpeza',
      icone: Icons.cleaning_services_rounded,
      cor: Color(0xFFB7791F),
      palavrasChave: ['limpeza', 'faxin', 'diarista'],
      sinonimos: ['faxina', 'faxineira', 'casa', 'passar', 'roupa', 'passadoria', 'obra'],
      subtipos: [
        Subtipo('faxina_residencial', 'Faxina residencial'),
        Subtipo('pos_obra', 'Limpeza pós-obra'),
        Subtipo('passadoria', 'Passadoria'),
        Subtipo('higienizacao_estofados', 'Higienização de estofados'),
      ],
      portes: ['1 quarto', '2 quartos', '3 quartos ou mais'],
    ),
  ];
}

/// Tipo de serviço dentro de uma categoria (ex.: Limpeza → Pós-obra).
class Subtipo {
  const Subtipo(this.id, this.rotulo);
  final String id;
  final String rotulo;
}

/// Minúsculas e sem acentos, para comparar textos digitados à mão.
String normalizar(String s) {
  const de = 'áàâãäéèêëíìîïóòôõöúùûüçñ';
  const para = 'aaaaaeeeeiiiiooooouuuucn';
  final b = StringBuffer();
  for (final ch in s.toLowerCase().split('')) {
    final i = de.indexOf(ch);
    b.write(i >= 0 ? para[i] : ch);
  }
  return b.toString();
}
