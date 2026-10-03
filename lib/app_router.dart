import 'package:go_router/go_router.dart';

import 'screens/criar_conta_screen.dart';
import 'screens/conta_screen.dart';
import 'screens/home_screen.dart';
import 'screens/principal_screen.dart';
import 'screens/login_screen.dart';
import 'screens/meus_servicos_screen.dart';
import 'screens/oferta_screen.dart';
import 'screens/pedidos_screen.dart';
import 'services/auth_service.dart';

/// Rotas do app. O redirecionamento segue o estado de login:
/// deslogado → /login ; logado → /home.
final appRouter = GoRouter(
  initialLocation: '/login',
  refreshListenable: AuthService.instance,
  redirect: (context, state) {
    final logado = AuthService.instance.logado;
    final rota = state.matchedLocation;
    final telaDeEntrada = rota == '/login' || rota == '/criar-conta';

    if (!logado && !telaDeEntrada) return '/login';
    if (logado && telaDeEntrada) return '/home';
    return null;
  },
  routes: [
    GoRoute(path: '/login', builder: (context, state) => const LoginScreen()),
    GoRoute(path: '/criar-conta', builder: (context, state) => const CriarContaScreen()),
    // Barra de baixo: cada aba guarda o próprio estado.
    StatefulShellRoute.indexedStack(
      builder: (context, state, shell) => HomeScreen(shell: shell),
      branches: [
        StatefulShellBranch(routes: [
          GoRoute(path: '/home', builder: (context, state) => const VitrineAba()),
        ]),
        StatefulShellBranch(routes: [
          GoRoute(
              path: '/meus-pedidos',
              builder: (context, state) => const PedidosScreen(souCliente: true, emAba: true)),
        ]),
        StatefulShellBranch(routes: [
          GoRoute(path: '/conta', builder: (context, state) => const ContaAba()),
        ]),
      ],
    ),
    GoRoute(path: '/oferecer', builder: (context, state) => const OfertaScreen()),
    GoRoute(path: '/meus-servicos', builder: (context, state) => const MeusServicosScreen()),
    GoRoute(path: '/pedidos-recebidos', builder: (context, state) => const PedidosScreen(souCliente: false)),
  ],
);
