import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../config.dart';
import '../services/auth_service.dart';
import '../theme/homefy_theme.dart';
import '../widgets/auth_layout.dart';
import '../widgets/formulario.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});
  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _form = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _senha = TextEditingController();
  bool _carregando = false;

  @override
  void dispose() {
    _email.dispose();
    _senha.dispose();
    super.dispose();
  }

  Future<void> _entrar() async {
    FocusScope.of(context).unfocus();
    if (!kModoDemo && !_form.currentState!.validate()) return;
    setState(() => _carregando = true);
    try {
      await AuthService.instance.entrar(email: _email.text, senha: _senha.text);
      // O roteador leva para a Home sozinho quando o login muda.
    } on AuthFalha catch (e) {
      mostrarAviso(e.mensagem, erro: true);
    } finally {
      if (mounted) setState(() => _carregando = false);
    }
  }

  Future<void> _esqueciSenha() async {
    final erro = Validar.email(_email.text);
    if (erro != null) {
      mostrarAviso('Digite seu e-mail no campo acima e toque de novo.', erro: true);
      return;
    }
    try {
      await AuthService.instance.redefinirSenha(_email.text);
      if (mounted) {
        mostrarAviso('Enviamos um link de redefinição para ${_email.text.trim()}.');
      }
    } on AuthFalha catch (e) {
      mostrarAviso(e.mensagem, erro: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return AuthLayout(
      titulo: 'Serviços em casa,\ncom quem você confia.',
      subtitulo: 'Cabelo, unhas, limpeza e lavagem de veículos no seu endereço.',
      child: Form(
        key: _form,
        child: AutofillGroup(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('Entrar', style: t.headlineSmall),
              const SizedBox(height: 4),
              Text('Que bom te ver de novo.', style: t.bodyMedium),
              const SizedBox(height: 28),
              CampoTexto(
                rotulo: 'E-mail',
                controller: _email,
                dica: 'voce@email.com',
                icone: Icons.mail_outline_rounded,
                teclado: TextInputType.emailAddress,
                acaoTeclado: TextInputAction.next,
                validador: Validar.email,
                autofill: const [AutofillHints.email],
              ),
              const SizedBox(height: 18),
              CampoTexto(
                rotulo: 'Senha',
                controller: _senha,
                dica: 'Sua senha',
                icone: Icons.lock_outline_rounded,
                senha: true,
                acaoTeclado: TextInputAction.done,
                aoEnviar: (_) => _entrar(),
                validador: Validar.senha,
                autofill: const [AutofillHints.password],
              ),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: _esqueciSenha,
                  child: const Text('Esqueceu a senha?'),
                ),
              ),
              const SizedBox(height: 8),
              BotaoPrimario(
                texto: 'Entrar',
                icone: Icons.arrow_forward_rounded,
                carregando: _carregando,
                aoTocar: _entrar,
              ),
              const SizedBox(height: 12),
              LinhaLink(
                texto: 'Não tem uma conta?',
                link: 'Cadastre-se',
                aoTocar: () => context.push('/criar-conta'),
              ),
              const Spacer(),
              const SizedBox(height: 16),
              if (kModoDemo) ...[
                const _AvisoDemo(),
                const SizedBox(height: 12),
              ],
              const RodapeTermos(),
            ],
          ),
        ),
      ),
    );
  }
}

class _AvisoDemo extends StatelessWidget {
  const _AvisoDemo();
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: HomefyColors.warning.withValues(alpha: 0.14),
          borderRadius: BorderRadius.circular(HomefySpace.radiusSm),
        ),
        child: Text(
          'Modo demonstração: sem Firebase. Toque em Entrar para ver a Home.',
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(color: HomefyColors.text),
        ),
      );
}
