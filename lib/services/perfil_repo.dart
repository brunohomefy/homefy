import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

import '../config.dart';
import '../models/perfil.dart';

/// Perfil do usuário logado: parte pública (`usuarios/{uid}`) e
/// privada (`usuarios/{uid}/privado/contato`).
class PerfilRepo {
  PerfilRepo._();
  static final PerfilRepo instance = PerfilRepo._();

  FirebaseFirestore get _db => FirebaseFirestore.instance;
  String? get _uid => FirebaseAuth.instance.currentUser?.uid;

  DocumentReference<Map<String, dynamic>> refUsuario(String uid) =>
      _db.collection('usuarios').doc(uid);

  DocumentReference<Map<String, dynamic>> _refContato(String uid) =>
      refUsuario(uid).collection('privado').doc('contato');

  // ── Modo demonstração (sem Firebase) ──
  final _demo = StreamController<PerfilUsuario?>.broadcast();
  PerfilUsuario? _demoPerfil = const PerfilUsuario(uid: 'demo', nome: 'Bruno');
  String? _demoWhats;

  /// Perfil do usuário logado, em tempo real. Nulo se ainda não existe.
  Stream<PerfilUsuario?> meu() {
    if (kModoDemo) {
      return Stream<PerfilUsuario?>.value(_demoPerfil).asyncExpand((p) async* {
        yield p;
        yield* _demo.stream;
      });
    }
    final uid = _uid;
    if (uid == null) return Stream.value(null);
    return refUsuario(uid)
        .snapshots()
        .map((s) => s.exists ? PerfilUsuario.fromFirestore(s) : null);
  }

  /// WhatsApp do próprio usuário (só ele consegue ler).
  Future<String?> meuWhatsapp() async {
    if (kModoDemo) return _demoWhats;
    final uid = _uid;
    if (uid == null) return null;
    final d = (await _refContato(uid).get()).data();
    final w = d?['whatsapp'];
    return w is String ? w : null;
  }

  /// Contas antigas (antes de 02/10/2026) guardavam o e-mail no perfil
  /// público. O e-mail já fica no Firebase Authentication, então é só apagar.
  /// Também cria o perfil de quem ainda não tem `usuarios/{uid}`.
  Future<void> arrumarPerfil() async {
    if (kModoDemo) return;
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    try {
      final ref = refUsuario(user.uid);
      final snap = await ref.get();
      if (!snap.exists) {
        final nome = (user.displayName ?? '').trim();
        await ref.set({
          'nome': nome.length >= 3 ? nome : 'Usuário Homefy',
          'auth_uid': user.uid,
          'cidade': 'caruaru',
          'eh_profissional': false,
          'criado_em': FieldValue.serverTimestamp(),
        });
      } else if (snap.data()!.containsKey('email')) {
        await ref.update({'email': FieldValue.delete()});
      }
    } catch (e) {
      debugPrint('arrumarPerfil: $e');
    }
  }

  /// Salva (ou atualiza) o perfil profissional, numa gravação só (batch):
  /// 1. WhatsApp no documento privado;
  /// 2. dados públicos e eh_profissional = true;
  /// 3. bairros copiados para os serviços que ele já tem, para a busca por
  ///    bairro da Home funcionar sem ler o perfil de cada profissional.
  Future<void> salvarProfissional({
    required List<String> categorias,
    required List<String> subtipos,
    required List<String> bairros,
    required bool atendeTodaCidade,
    required String descricao,
    required String whatsapp,
  }) async {
    if (kModoDemo) {
      _demoWhats = whatsapp;
      _demoPerfil = PerfilUsuario(
        uid: 'demo',
        nome: _demoPerfil?.nome ?? 'Bruno',
        ehProfissional: true,
        categorias: categorias,
        subtipos: subtipos,
        bairros: bairros,
        atendeTodaCidade: atendeTodaCidade,
        descricao: descricao,
      );
      _demo.add(_demoPerfil);
      return;
    }
    final uid = _uid;
    if (uid == null) throw StateError('Sem usuário logado');
    await arrumarPerfil();

    final ref = refUsuario(uid);
    final eraProfissional = (await ref.get()).data()?['eh_profissional'] == true;
    final meusServicos =
        await _db.collection('servicos').where('profissional_ref', isEqualTo: ref).get();

    final lote = _db.batch()
      ..set(_refContato(uid), {
        'whatsapp': whatsapp,
        'atualizado_em': FieldValue.serverTimestamp(),
      })
      ..update(ref, {
        'eh_profissional': true,
        'categorias': categorias,
        'subtipos': subtipos,
        'bairros': atendeTodaCidade ? <String>[] : bairros,
        'atende_toda_cidade': atendeTodaCidade,
        'descricao': descricao.trim(),
        if (!eraProfissional) 'profissional_desde': FieldValue.serverTimestamp(),
        'atualizado_em': FieldValue.serverTimestamp(),
      });
    for (final s in meusServicos.docs) {
      lote.update(s.reference, {
        'bairros': atendeTodaCidade ? <String>[] : bairros,
        'atende_toda_cidade': atendeTodaCidade,
        'atualizado_em': FieldValue.serverTimestamp(),
      });
    }
    await lote.commit();
  }
}
