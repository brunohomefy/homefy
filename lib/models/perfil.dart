import 'package:cloud_firestore/cloud_firestore.dart';

/// Parte PÚBLICA do perfil (documento `usuarios/{uid}`).
///
/// Qualquer pessoa logada lê este documento. Por isso ele NÃO guarda
/// e-mail, WhatsApp, CPF nem endereço (LGPD: só o necessário fica visível).
/// Dados privados ficam em `usuarios/{uid}/privado/contato`, que só o dono lê.
class PerfilUsuario {
  const PerfilUsuario({
    required this.uid,
    required this.nome,
    this.ehProfissional = false,
    this.categorias = const [],
    this.subtipos = const [],
    this.bairros = const [],
    this.atendeTodaCidade = false,
    this.descricao = '',
  });

  final String uid;
  final String nome;
  final bool ehProfissional;

  /// Ids fixos das categorias (ex.: 'limpeza').
  final List<String> categorias;

  /// Ids dos subtipos marcados (ex.: 'pos_obra').
  final List<String> subtipos;

  /// Ids dos bairros atendidos (ver models/bairros.dart).
  final List<String> bairros;
  final bool atendeTodaCidade;
  final String descricao;

  factory PerfilUsuario.fromMap(String uid, Map<String, dynamic> d) {
    List<String> lista(Object? v) => v is List ? v.whereType<String>().toList() : const [];
    final nome = d['nome'];
    final desc = d['descricao'];
    return PerfilUsuario(
      uid: uid,
      nome: nome is String ? nome.trim() : '',
      ehProfissional: d['eh_profissional'] == true,
      categorias: lista(d['categorias']),
      subtipos: lista(d['subtipos']),
      bairros: lista(d['bairros']),
      atendeTodaCidade: d['atende_toda_cidade'] == true,
      descricao: desc is String ? desc.trim() : '',
    );
  }

  factory PerfilUsuario.fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc) =>
      PerfilUsuario.fromMap(doc.id, doc.data() ?? const {});
}

/// WhatsApp: só dígitos, sempre com o 55 do Brasil na frente.
/// Aceita "(81) 99999-1234", "81999991234" ou "+55 81 99999-1234".
/// Devolve nulo se não for um número brasileiro com DDD.
String? normalizarWhatsapp(String entrada) {
  var d = entrada.replaceAll(RegExp(r'\D'), '');
  if (d.startsWith('55') && (d.length == 12 || d.length == 13)) d = d.substring(2);
  if (d.startsWith('0')) d = d.substring(1);
  if (d.length != 10 && d.length != 11) return null;
  if (d.startsWith('0') || d[1] == '0') return null; // DDD inválido
  if (d.length == 11 && d[2] != '9') return null; // celular começa com 9
  return '55$d';
}

/// "5581999991234" → "(81) 99999-1234", para mostrar ao próprio dono.
String formatarWhatsapp(String n) {
  final d = n.startsWith('55') ? n.substring(2) : n;
  if (d.length < 10) return n;
  final ddd = d.substring(0, 2), resto = d.substring(2);
  final corte = resto.length - 4;
  return '($ddd) ${resto.substring(0, corte)}-${resto.substring(corte)}';
}
