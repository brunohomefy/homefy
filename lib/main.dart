import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'app_router.dart';
import 'config.dart';
import 'firebase_options.dart';
import 'theme/homefy_theme.dart';
import 'widgets/formulario.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.light,
  ));

  if (!kModoDemo) {
    try {
      await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
    } catch (e) {
      runApp(_FirebaseNaoConfigurado(erro: '$e'));
      return;
    }
  }
  runApp(const HomefyApp());
}

class HomefyApp extends StatelessWidget {
  const HomefyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'Homefy',
      debugShowCheckedModeBanner: false,
      theme: buildHomefyTheme(),
      routerConfig: appRouter,
      scaffoldMessengerKey: avisosKey,
      locale: const Locale('pt', 'BR'),
      supportedLocales: const [Locale('pt', 'BR')],
      localizationsDelegates: GlobalMaterialLocalizations.delegates,
    );
  }
}

/// Mostrada só se o Firebase não iniciar (ex.: faltou o flutterfire configure).
class _FirebaseNaoConfigurado extends StatelessWidget {
  const _FirebaseNaoConfigurado({required this.erro});
  final String erro;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: buildHomefyTheme(),
      home: Scaffold(
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.settings_suggest_rounded,
                    size: 48, color: HomefyColors.primary),
                const SizedBox(height: 16),
                Text('Falta conectar o Firebase',
                    style: Theme.of(context).textTheme.headlineSmall),
                const SizedBox(height: 8),
                const Text('Na pasta do projeto, rode:\n\n'
                    '  flutterfire configure\n\n'
                    'escolha o projeto do Homefy e rode o app de novo.'),
                const SizedBox(height: 16),
                Text(erro,
                    style: Theme.of(context)
                        .textTheme
                        .bodySmall
                        ?.copyWith(color: HomefyColors.textMuted)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
