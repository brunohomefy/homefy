import 'package:go_router/go_router.dart';

import 'screens/criar_conta_screen.dart';
import 'screens/home_screen.dart';
import 'screens/login_screen.dart';
import 'screens/meus_servicos_screen.dart';
import 'screens/oferta_screen.dart';
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
    GoRoute(path: '/home', builder: (context, state) => const HomeScreen()),
    GoRoute(path: '/oferecer', builder: (context, state) => const OfertaScreen()),
    GoRoute(path: '/meus-servicos', builder: (context, state) => const MeusServicosScreen()),
  ],
);
