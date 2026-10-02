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
  });

  final String id;
  final String rotulo;
  final IconData icone;
  final Color cor;
  final List<String> palavrasChave;

  bool combinaCom(String categoriaDoServico) {
    final alvo = normalizar(categoriaDoServico);
    return palavrasChave.any(alvo.contains);
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
    ),
    Categoria(
      id: 'manicure',
      rotulo: 'Manicure',
      icone: Icons.back_hand_outlined,
      cor: Color(0xFFC0567A),
      palavrasChave: ['manicure', 'pedicure', 'unha'],
    ),
    Categoria(
      id: 'veiculos',
      rotulo: 'Lavagem de veículos',
      icone: Icons.local_car_wash_rounded,
      cor: Color(0xFF0077B6),
      palavrasChave: ['lava', 'veicul', 'carro', 'moto'],
    ),
    Categoria(
      id: 'limpeza',
      rotulo: 'Limpeza',
      icone: Icons.cleaning_services_rounded,
      cor: Color(0xFFB7791F),
      palavrasChave: ['limpeza', 'faxin', 'diarista'],
    ),
  ];
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
