import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../models/bairros.dart';
import '../models/categoria.dart';
import '../models/perfil.dart';
import '../models/servico.dart';
import '../services/perfil_repo.dart';
import '../services/servicos_repo.dart';
import '../theme/homefy_theme.dart';
import '../widgets/formulario.dart';
import 'servico_editor_screen.dart';

/// Área do profissional: resumo do perfil e lista dos próprios serviços.
class MeusServicosScreen extends StatelessWidget {
  const MeusServicosScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<PerfilUsuario?>(
      stream: PerfilRepo.instance.meu(),
      builder: (context, snapPerfil) {
        final perfil = snapPerfil.data;
        return Scaffold(
          appBar: AppBar(
            leading: IconButton(
              tooltip: 'Voltar',
              icon: const Icon(Icons.arrow_back_rounded),
              onPressed: () => context.canPop() ? context.pop() : context.go('/home'),
            ),
            title: const Text('Meus serviços'),
          ),
          floatingActionButton: perfil?.ehProfissional == true
              ? FloatingActionButton.extended(
                  onPressed: () => _abrirEditor(context, perfil!, null),
                  icon: const Icon(Icons.add_rounded),
                  label: const Text('Novo serviço'),
                )
              : null,
          body: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 640),
              child: !snapPerfil.hasData && snapPerfil.connectionState != ConnectionState.active
                  ? const Center(child: CircularProgressIndicator())
                  : perfil == null || !perfil.ehProfissional
                      ? const _AindaNaoProfissional()
                      : _Conteudo(perfil: perfil),
            ),
          ),
        );
      },
    );
  }
}

void _abrirEditor(BuildContext context, PerfilUsuario perfil, Servico? s) {
  Navigator.of(context).push(MaterialPageRoute<void>(
    builder: (_) => ServicoEditorScreen(perfil: perfil, servico: s),
  ));
}

class _Conteudo extends StatelessWidget {
  const _Conteudo({required this.perfil});
  final PerfilUsuario perfil;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return StreamBuilder<List<Servico>>(
      stream: const ServicosRepo().meus(),
      builder: (context, snap) {
        final lista = snap.data ?? const <Servico>[];
        return ListView(
          padding: const EdgeInsets.fromLTRB(24, 8, 24, 100),
          children: [
            _ResumoPerfil(perfil: perfil),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: () => context.push('/pedidos-recebidos'),
              style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(48)),
              icon: const Icon(Icons.inbox_outlined),
              label: const Text('Ver pedidos recebidos'),
            ),
            const SizedBox(height: 24),
            Text('Seus serviços', style: t.titleLarge),
            const SizedBox(height: 12),
            if (snap.hasError)
              Text('Não foi possível carregar seus serviços. Verifique a conexão.',
                  style: t.bodyMedium?.copyWith(color: HomefyColors.error))
            else if (!snap.hasData)
              const Padding(
                padding: EdgeInsets.all(24),
                child: Center(child: CircularProgressIndicator()),
              )
            else if (lista.isEmpty)
              _Vazio(aoCriar: () => _abrirEditor(context, perfil, null))
            else
              for (final s in lista)
                _ItemServico(
                  servico: s,
                  aoTocar: () => _abrirEditor(context, perfil, s),
                ),
          ],
        );
      },
    );
  }
}

class _ResumoPerfil extends StatelessWidget {
  const _ResumoPerfil({required this.perfil});
  final PerfilUsuario perfil;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final cats = perfil.categorias.map(Categoria.porId).whereType<Categoria>().map((c) => c.rotulo);
    final area = perfil.atendeTodaCidade
        ? 'Caruaru toda'
        : perfil.bairros.length <= 3
            ? perfil.bairros.map(Bairro.nomeDe).join(', ')
            : '${perfil.bairros.take(2).map(Bairro.nomeDe).join(', ')} e mais ${perfil.bairros.length - 2}';
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: HomefyColors.mint,
        borderRadius: BorderRadius.circular(HomefySpace.radiusLg),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          const Icon(Icons.verified_user_outlined, color: HomefyColors.primaryDark),
          const SizedBox(width: 8),
          Expanded(
            child: Text('Perfil profissional ativo',
                style: t.titleSmall?.copyWith(color: HomefyColors.primaryDark)),
          ),
          TextButton(
            onPressed: () => context.push('/oferecer'),
            child: const Text('Editar'),
          ),
        ]),
        const SizedBox(height: 4),
        Text(cats.join(' · '), style: t.bodyMedium?.copyWith(color: HomefyColors.primaryDark)),
        const SizedBox(height: 4),
        Row(children: [
          const Icon(Icons.place_outlined, size: 16, color: HomefyColors.primaryDark),
          const SizedBox(width: 4),
          Expanded(
            child: Text(area, style: t.bodySmall?.copyWith(color: HomefyColors.primaryDark)),
          ),
        ]),
      ]),
    );
  }
}

class _ItemServico extends StatelessWidget {
  const _ItemServico({required this.servico, required this.aoTocar});
  final Servico servico;
  final VoidCallback aoTocar;

  Future<void> _alternar(bool v) async {
    try {
      await const ServicosRepo().definirAtivo(servico.id, v);
      mostrarAviso(v ? 'Serviço de volta na vitrine.' : 'Serviço escondido da vitrine.');
    } catch (e) {
      debugPrint('definirAtivo: $e');
      mostrarAviso('Não foi possível alterar. Tente de novo.', erro: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final s = servico;
    final cat = s.categoriaMvp;
    final precos = s.variacoesOuPadrao;
    final resumoPreco = precos.length == 1
        ? (Servico.formatarPreco(precos.first.preco) ?? 'Sob consulta')
        : s.precoFormatado != null
            ? 'A partir de ${s.precoFormatado} · ${precos.length} faixas'
            : '${precos.length} faixas, sob consulta';
    return Opacity(
      opacity: s.ativo ? 1 : 0.55,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: HomefyColors.surface,
          borderRadius: BorderRadius.circular(HomefySpace.radiusMd),
          border: Border.all(color: HomefyColors.border),
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(HomefySpace.radiusMd),
          onTap: aoTocar,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 12, 4, 12),
            child: Row(children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: (cat?.cor ?? HomefyColors.primary).withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(HomefySpace.radiusSm),
                ),
                child: Icon(cat?.icone ?? Icons.handyman_outlined, color: cat?.cor ?? HomefyColors.primary),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(s.nome, style: t.titleSmall, maxLines: 1, overflow: TextOverflow.ellipsis),
                  const SizedBox(height: 2),
                  Text(resumoPreco, style: t.bodySmall),
                  if (!s.ativo)
                    Text('Escondido da vitrine',
                        style: t.labelSmall?.copyWith(color: HomefyColors.textSecondary)),
                ]),
              ),
              Switch(value: s.ativo, onChanged: _alternar),
            ]),
          ),
        ),
      ),
    );
  }
}

class _Vazio extends StatelessWidget {
  const _Vazio({required this.aoCriar});
  final VoidCallback aoCriar;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: HomefyColors.surface,
        borderRadius: BorderRadius.circular(HomefySpace.radiusLg),
        border: Border.all(color: HomefyColors.border),
      ),
      child: Column(children: [
        const Icon(Icons.storefront_outlined, size: 40, color: HomefyColors.primary),
        const SizedBox(height: 12),
        Text('Você ainda não tem serviços', style: t.titleMedium, textAlign: TextAlign.center),
        const SizedBox(height: 6),
        Text('Cadastre o primeiro para aparecer na vitrine para os clientes dos seus bairros.',
            style: t.bodySmall, textAlign: TextAlign.center),
        const SizedBox(height: 16),
        FilledButton.icon(
          onPressed: aoCriar,
          icon: const Icon(Icons.add_rounded),
          label: const Text('Cadastrar serviço'),
        ),
      ]),
    );
  }
}

class _AindaNaoProfissional extends StatelessWidget {
  const _AindaNaoProfissional();

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        const Icon(Icons.work_outline_rounded, size: 48, color: HomefyColors.primary),
        const SizedBox(height: 12),
        Text('Primeiro, complete seu perfil profissional', style: t.titleMedium, textAlign: TextAlign.center),
        const SizedBox(height: 6),
        Text('Conte o que você faz, onde atende e seu WhatsApp.',
            style: t.bodySmall, textAlign: TextAlign.center),
        const SizedBox(height: 16),
        FilledButton(onPressed: () => context.go('/oferecer'), child: const Text('Quero oferecer')),
      ]),
    );
  }
}
