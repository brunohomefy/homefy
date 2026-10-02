// Configuração do Firebase do Homefy (projeto homefy-67cdd).
//
// Web: valores copiados do console do Firebase (app "Homefy Web").
// Android / iOS: rode "flutterfire configure" para gerar a versão completa
// deste arquivo (ele será sobrescrito, sem problema).
//
// Estes valores NÃO são segredos: são identificadores públicos do app.
// A segurança vem das regras do Firestore (firestore.rules).

import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart' show kIsWeb;

class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) return web;
    throw UnsupportedError(
      'Para rodar no Android/iOS, rode "flutterfire configure" na pasta do projeto.',
    );
  }

  static const FirebaseOptions web = FirebaseOptions(
    apiKey: 'AIzaSyCU1p-5KBCJRonWcllZ8T2SLZzyest-wYo',
    appId: '1:235436234564:web:670d8808c623d41c046911',
    messagingSenderId: '235436234564',
    projectId: 'homefy-67cdd',
    authDomain: 'homefy-67cdd.firebaseapp.com',
    storageBucket: 'homefy-67cdd.firebasestorage.app',
    measurementId: 'G-RW0B0C0STJ',
  );
}
