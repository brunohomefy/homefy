import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

import '../config.dart';
import 'perfil_repo.dart';

/// Erro já traduzido para mostrar ao usuário.
class AuthFalha implements Exception {
  AuthFalha(this.mensagem);
  final String mensagem;
  @override
  String toString() => mensagem;
}

/// Login, cadastro, logout e redefinição de senha.
///
/// É um ChangeNotifier para o roteador saber quando a pessoa entra ou sai.
class AuthService extends ChangeNotifier {
  AuthService._() {
    if (kModoDemo) return;
    _sub = FirebaseAuth.instance.authStateChanges().listen((_) => notifyListeners());
  }

  static final AuthService instance = AuthService._();

  StreamSubscription<User?>? _sub;
  // Na demonstração já entra logado (usada também na auditoria automática de telas).
  bool _demoLogado = true;
  String? _demoNome = 'Bruno';

  User? get _user => kModoDemo ? null : FirebaseAuth.instance.currentUser;

  bool get logado => kModoDemo ? _demoLogado : _user != null;

  /// Primeiro nome, para a saudação da Home.
  String? get primeiroNome {
    final nome = kModoDemo ? _demoNome : _user?.displayName;
    if (nome == null || nome.trim().isEmpty) return null;
    return nome.trim().split(RegExp(r'\s+')).first;
  }

  String? get email => kModoDemo ? 'demo@homefy.app' : _user?.email;

  Future<void> entrar({required String email, required String senha}) async {
    if (kModoDemo) {
      _demoLogado = true;
      _demoNome = 'Bruno';
      notifyListeners();
      return;
    }
    try {
      await FirebaseAuth.instance
          .signInWithEmailAndPassword(email: email.trim(), password: senha);
    } on FirebaseAuthException catch (e) {
      throw AuthFalha(_traduzir(e.code));
    }
    // Contas antigas: tira o e-mail do perfil público e cria o perfil se faltar.
    unawaited(PerfilRepo.instance.arrumarPerfil());
  }

  /// Cria a conta no Authentication e o documento `usuarios/{uid}`.
  /// (Regra crítica do dossiê, item 42: o perfil fica preso ao UID.)
  Future<void> criarConta({
    required String nome,
    required String email,
    required String senha,
  }) async {
    if (kModoDemo) {
      _demoLogado = true;
      _demoNome = nome;
      notifyListeners();
      return;
    }
    final UserCredential cred;
    try {
      cred = await FirebaseAuth.instance
          .createUserWithEmailAndPassword(email: email.trim(), password: senha);
    } on FirebaseAuthException catch (e) {
      throw AuthFalha(_traduzir(e.code));
    }

    final user = cred.user!;
    await user.updateDisplayName(nome.trim());

    try {
      await FirebaseFirestore.instance.collection('usuarios').doc(user.uid).set({
        'nome': nome.trim(),
        // Sem e-mail aqui: o perfil é público entre usuários logados e o
        // e-mail já fica guardado no Firebase Authentication (LGPD).
        'auth_uid': user.uid, // mesmo campo do documento de teste já existente
        'cidade': 'caruaru',
        'eh_profissional': false,
        'criado_em': FieldValue.serverTimestamp(),
      });
    } on FirebaseException catch (e) {
      // A conta foi criada, mas o perfil não. Avisamos com clareza:
      // quase sempre é a regra do Firestore que não foi publicada.
      debugPrint('Falha ao criar usuarios/${user.uid}: ${e.code} ${e.message}');
      throw AuthFalha(e.code == 'permission-denied'
          ? 'Conta criada, mas o perfil não foi salvo (permissão do banco). '
              'Publique o arquivo firestore.rules e tente de novo.'
          : 'Conta criada, mas houve um erro ao salvar o perfil. Tente entrar novamente.');
    }
    await user.reload();
    notifyListeners();
  }

  Future<void> redefinirSenha(String email) async {
    if (kModoDemo) return;
    try {
      await FirebaseAuth.instance.sendPasswordResetEmail(email: email.trim());
    } on FirebaseAuthException catch (e) {
      throw AuthFalha(_traduzir(e.code));
    }
  }

  Future<void> sair() async {
    if (kModoDemo) {
      _demoLogado = false;
      notifyListeners();
      return;
    }
    await FirebaseAuth.instance.signOut();
  }

  static String _traduzir(String code) {
    switch (code) {
      case 'invalid-email':
        return 'Esse e-mail não parece válido.';
      case 'user-disabled':
        return 'Esta conta foi desativada.';
      case 'user-not-found':
      case 'wrong-password':
      case 'invalid-credential':
      case 'invalid-login-credentials':
        return 'E-mail ou senha incorretos.';
      case 'email-already-in-use':
        return 'Já existe uma conta com esse e-mail. Tente entrar.';
      case 'weak-password':
        return 'Senha fraca. Use pelo menos 6 caracteres.';
      case 'too-many-requests':
        return 'Muitas tentativas. Aguarde um pouco e tente de novo.';
      case 'network-request-failed':
        return 'Sem conexão com a internet.';
      case 'operation-not-allowed':
        return 'Login por e-mail não está habilitado no Firebase.';
      default:
        return 'Algo deu errado ($code). Tente novamente.';
    }
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }
}
