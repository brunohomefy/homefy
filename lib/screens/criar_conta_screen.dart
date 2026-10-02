import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../services/auth_service.dart';
import '../widgets/auth_layout.dart';
import '../widgets/formulario.dart';

class CriarContaScreen extends StatefulWidget {
  const CriarContaScreen({super.key});
  @override
  State<CriarContaScreen> createState() => _CriarContaScreenState();
}

class _CriarContaScreenState extends State<CriarContaScreen> {
  final _form = GlobalKey<FormState>();
  final _nome = TextEditingController();
  final _email = TextEditingController();
  final _senha = TextEditingController();
  bool _carregando = false;

  @override
  void dispose() {
    _nome.dispose();
    _email.dispose();
    _senha.dispose();
    super.dispose();
  }

  void _voltar() => context.canPop() ? context.pop() : context.go('/login');

  Future<void> _criar() async {
    FocusScope.of(context).unfocus();
    if (!_form.currentState!.validate()) return;
    setState(() => _carregando = true);
    try {
      await AuthService.instance.criarConta(
        nome: _nome.text,
        email: _email.text,
        senha: _senha.text,
      );
      mostrarAviso('Conta criada. Bem-vindo ao Homefy!');
    } on AuthFalha catch (e) {
      mostrarAviso(e.mensagem, erro: true);
    } finally {
      if (mounted) setState(() => _carregando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return AuthLayout(
      titulo: 'Crie sua conta\nem 1 minuto.',
      subtitulo: 'Uma conta só para contratar serviços e, se quiser, oferecer os seus.',
      voltar: _voltar,
      child: Form(
        key: _form,
        child: AutofillGroup(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('Cadastro', style: t.headlineSmall),
              const SizedBox(height: 4),
              Text('Preencha seus dados para começar.', style: t.bodyMedium),
              const SizedBox(height: 28),
              CampoTexto(
                rotulo: 'Nome completo',
                controller: _nome,
                dica: 'Ex.: João Silva',
                icone: Icons.person_outline_rounded,
                acaoTeclado: TextInputAction.next,
                capitalizacao: TextCapitalization.words,
                validador: Validar.nome,
                autofill: const [AutofillHints.name],
              ),
              const SizedBox(height: 18),
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
                dica: 'Mínimo de 6 caracteres',
                icone: Icons.lock_outline_rounded,
                senha: true,
                acaoTeclado: TextInputAction.done,
                aoEnviar: (_) => _criar(),
                validador: Validar.novaSenha,
                autofill: const [AutofillHints.newPassword],
              ),
              const SizedBox(height: 28),
              BotaoPrimario(
                texto: 'Criar conta',
                carregando: _carregando,
                aoTocar: _criar,
              ),
              const SizedBox(height: 12),
              LinhaLink(texto: 'Já tem uma conta?', link: 'Entrar', aoTocar: _voltar),
              const Spacer(),
              const SizedBox(height: 16),
              const RodapeTermos(),
            ],
          ),
        ),
      ),
    );
  }
}
