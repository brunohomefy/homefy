import 'package:flutter/material.dart';

import '../models/categoria.dart';
import '../models/servico.dart';
import '../services/auth_service.dart';
import '../services/servicos_repo.dart';
import '../theme/homefy_theme.dart';
import '../widgets/formulario.dart';
import '../widgets/homefy_logo.dart';
import '../widgets/servico_card.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  late final Stream<List<Servico>> _servicos = const ServicosRepo().ativos();
  final _busca = TextEditingController();
  Categoria? _categoria;

  @override
  void initState() {
    super.initState();
    _busca.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _busca.dispose();
    super.dispose();
  }

  List<Servico> _filtrar(List<Servico> todos) {
    final termo = normalizar(_busca.text.trim());
    return todos.where((s) {
      if (_categoria != null && !_categoria!.combinaCom(s.categoria)) return false;
      if (termo.isEmpty) return true;
      return normalizar('${s.nome} ${s.categoria} ${s.descricao}').contains(termo);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 640),
          child: CustomScrollView(
            slivers: [
              SliverToBoxAdapter(child: _Cabecalho(busca: _busca)),
              SliverToBoxAdapter(
                child: _Categorias(
                  selecionada: _categoria,
                  aoSelecionar: (c) => setState(() => _categoria = c == _categoria ? null : c),
                ),
              ),
              StreamBuilder<List<Servico>>(
                stream: _servicos,
                builder: (context, snap) => _listaServicos(context, snap),
              ),
              const SliverToBoxAdapter(child: _ConviteProfissional()),
              SliverToBoxAdapter(
                child: SizedBox(height: 24 + MediaQuery.paddingOf(context).bottom),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _listaServicos(BuildContext context, AsyncSnapshot<List<Servico>> snap) {
    final t = Theme.of(context).textTheme;
    final filtrados = snap.hasData ? _filtrar(snap.data!) : const <Servico>[];

    final titulo = Padding(
      padding: const EdgeInsets.fromLTRB(24, 28, 24, 14),
      child: Row(
        children: [
          Expanded(
            child: Text(
              _categoria?.rotulo ?? 'Serviços disponíveis',
              style: t.titleLarge,
            ),
          ),
          if (snap.hasData)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: HomefyColors.mint,
                borderRadius: BorderRadius.circular(99),
              ),
              child: Text('${filtrados.length}',
                  style: t.labelMedium?.copyWith(
                      color: HomefyColors.primaryDark, fontWeight: FontWeight.w700)),
            ),
        ],
      ),
    );

    Widget corpo;
    if (snap.hasError) {
      debugPrint('Erro ao ler servicos: ${snap.error}');
      final semPermissao = '${snap.error}'.contains('permission-denied');
      corpo = _EstadoVazio(
        icone: Icons.cloud_off_rounded,
        titulo: 'Não foi possível carregar os serviços',
        texto: semPermissao
            ? 'O banco recusou a leitura. Confira se as regras do Firestore foram publicadas.'
            : 'Verifique sua conexão e tente novamente.',
      );
    } else if (!snap.hasData) {
      corpo = Column(
        children: List.generate(
          3,
          (_) => const Padding(
            padding: EdgeInsets.only(bottom: 12),
            child: ServicoCardCarregando(),
          ),
        ),
      );
    } else if (filtrados.isEmpty) {
      final temFiltro = _categoria != null || _busca.text.trim().isNotEmpty;
      corpo = _EstadoVazio(
        icone: temFiltro ? Icons.search_off_rounded : Icons.inventory_2_outlined,
        titulo: temFiltro ? 'Nada encontrado' : 'Ainda não há serviços ativos',
        texto: temFiltro
            ? 'Tente outra palavra ou outra categoria.'
            : 'Assim que houver serviços com "ativo = true" no banco, eles aparecem aqui.',
        acao: temFiltro
            ? TextButton(
                onPressed: () => setState(() {
                  _categoria = null;
                  _busca.clear();
                }),
                child: const Text('Limpar filtros'),
              )
            : null,
      );
    } else {
      corpo = Column(
        children: [
          for (var i = 0; i < filtrados.length; i++)
            _EntradaAnimada(
              indice: i,
              child: Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: ServicoCard(
                  servico: filtrados[i],
                  aoTocar: () => _abrirDetalhe(context, filtrados[i]),
                ),
              ),
            ),
        ],
      );
    }

    return SliverToBoxAdapter(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          titulo,
          Padding(padding: const EdgeInsets.symmetric(horizontal: 24), child: corpo),
        ],
      ),
    );
  }

  void _abrirDetalhe(BuildContext context, Servico s) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (_) => _DetalheServico(servico: s),
    );
  }
}

// ───────────────────────── Cabeçalho ─────────────────────────

class _Cabecalho extends StatelessWidget {
  const _Cabecalho({required this.busca});
  final TextEditingController busca;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final topo = MediaQuery.paddingOf(context).top;

    return Container(
      decoration: const BoxDecoration(
        gradient: HomefyColors.brandGradient,
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(HomefySpace.radiusXl)),
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        children: [
          Positioned(
            right: -50,
            top: -30,
            child: Container(
              width: 190,
              height: 190,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withValues(alpha: 0.07),
              ),
            ),
          ),
          Padding(
            padding: EdgeInsets.fromLTRB(24, topo + 16, 24, 24),
            child: ListenableBuilder(
              listenable: AuthService.instance,
              builder: (context, _) {
                final nome = AuthService.instance.primeiroNome;
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const HomefyMarca(claro: true, tamanho: 34),
                        const Spacer(),
                        _BotaoPerfil(nome: nome),
                      ],
                    ),
                    const SizedBox(height: 28),
                    Text(
                      nome == null ? 'Olá!' : 'Olá, $nome!',
                      style: t.bodyLarge?.copyWith(
                          color: Colors.white.withValues(alpha: 0.85)),
                    ),
                    const SizedBox(height: 4),
                    Text('Do que você precisa hoje?',
                        style: t.headlineSmall?.copyWith(color: Colors.white)),
                    const SizedBox(height: 20),
                    _CampoBusca(controller: busca),
                    const SizedBox(height: 14),
                    Row(children: [
                      Icon(Icons.location_on_outlined,
                          size: 16, color: Colors.white.withValues(alpha: 0.8)),
                      const SizedBox(width: 4),
                      Text('Atendendo em Caruaru – PE',
                          style: t.bodySmall?.copyWith(
                              color: Colors.white.withValues(alpha: 0.8))),
                    ]),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _CampoBusca extends StatelessWidget {
  const _CampoBusca({required this.controller});
  final TextEditingController controller;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(HomefySpace.radiusMd),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.12),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: TextField(
        controller: controller,
        textInputAction: TextInputAction.search,
        decoration: InputDecoration(
          hintText: 'Buscar corte, manicure, faxina…',
          prefixIcon: const Icon(Icons.search_rounded, color: HomefyColors.primary),
          suffixIcon: controller.text.isEmpty
              ? null
              : IconButton(
                  tooltip: 'Limpar busca',
                  icon: const Icon(Icons.close_rounded),
                  onPressed: controller.clear,
                ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(HomefySpace.radiusMd),
            borderSide: BorderSide.none,
          ),
        ),
      ),
    );
  }
}

class _BotaoPerfil extends StatelessWidget {
  const _BotaoPerfil({required this.nome});
  final String? nome;

  @override
  Widget build(BuildContext context) {
    final inicial = (nome?.isNotEmpty ?? false) ? nome![0].toUpperCase() : null;
    return Material(
      color: Colors.white.withValues(alpha: 0.16),
      shape: CircleBorder(side: BorderSide(color: Colors.white.withValues(alpha: 0.3))),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: () => showModalBottomSheet<void>(
          context: context,
          builder: (_) => const _FolhaPerfil(),
        ),
        child: SizedBox(
          width: 44,
          height: 44,
          child: Center(
            child: inicial != null
                ? Text(inicial,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(color: Colors.white))
                : const Icon(Icons.person_outline_rounded, color: Colors.white),
          ),
        ),
      ),
    );
  }
}

class _FolhaPerfil extends StatelessWidget {
  const _FolhaPerfil();

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final auth = AuthService.instance;
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 0, 24, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(children: [
              CircleAvatar(
                radius: 26,
                backgroundColor: HomefyColors.mint,
                child: Text(
                  (auth.primeiroNome ?? '?')[0].toUpperCase(),
                  style: t.titleLarge?.copyWith(color: HomefyColors.primary),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(auth.primeiroNome ?? 'Minha conta', style: t.titleMedium),
                  if (auth.email != null) Text(auth.email!, style: t.bodySmall),
                ]),
              ),
            ]),
            const SizedBox(height: 20),
            const Divider(),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.chat_bubble_outline_rounded),
              title: const Text('Enviar sugestão'),
              subtitle: const Text('Em breve'),
              enabled: false,
              onTap: () {},
            ),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.logout_rounded, color: HomefyColors.error),
              title: Text('Sair',
                  style: t.bodyLarge?.copyWith(
                      color: HomefyColors.error, fontWeight: FontWeight.w600)),
              onTap: () async {
                Navigator.of(context).pop();
                await AuthService.instance.sair();
              },
            ),
          ],
        ),
      ),
    );
  }
}

// ───────────────────────── Categorias ─────────────────────────

class _Categorias extends StatelessWidget {
  const _Categorias({required this.selecionada, required this.aoSelecionar});
  final Categoria? selecionada;
  final ValueChanged<Categoria> aoSelecionar;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 28, 24, 14),
          child: Text('Categorias', style: t.titleLarge),
        ),
        SizedBox(
          height: 112,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 24),
            itemCount: Categoria.todas.length,
            separatorBuilder: (context, index) => const SizedBox(width: 12),
            itemBuilder: (context, i) {
              final c = Categoria.todas[i];
              return _CategoriaTile(
                categoria: c,
                selecionada: c == selecionada,
                aoTocar: () => aoSelecionar(c),
              );
            },
          ),
        ),
      ],
    );
  }
}

class _CategoriaTile extends StatelessWidget {
  const _CategoriaTile({
    required this.categoria,
    required this.selecionada,
    required this.aoTocar,
  });
  final Categoria categoria;
  final bool selecionada;
  final VoidCallback aoTocar;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final cor = categoria.cor;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOut,
      width: 104,
      decoration: BoxDecoration(
        color: selecionada ? cor : HomefyColors.surface,
        borderRadius: BorderRadius.circular(HomefySpace.radiusLg),
        boxShadow: homefyShadow,
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(HomefySpace.radiusLg),
          onTap: aoTocar,
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: selecionada
                        ? Colors.white.withValues(alpha: 0.2)
                        : cor.withValues(alpha: 0.10),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(categoria.icone,
                      size: 22, color: selecionada ? Colors.white : cor),
                ),
                Text(
                  categoria.rotulo,
                  maxLines: 2,
                  style: t.labelMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                    height: 1.2,
                    color: selecionada ? Colors.white : HomefyColors.text,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ───────────────────────── Detalhe ─────────────────────────

class _DetalheServico extends StatelessWidget {
  const _DetalheServico({required this.servico});
  final Servico servico;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final cat = Categoria.deServico(servico.categoria);
    final cor = cat?.cor ?? HomefyColors.primary;

    Widget info(IconData i, String rotulo, String valor) => Expanded(
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: HomefyColors.background,
              borderRadius: BorderRadius.circular(HomefySpace.radiusMd),
            ),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Icon(i, size: 20, color: cor),
              const SizedBox(height: 8),
              Text(rotulo, style: t.bodySmall),
              Text(valor, style: t.titleMedium),
            ]),
          ),
        );

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 0, 24, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(children: [
              IconeCategoria(
                  cor: cor, icone: cat?.icone ?? Icons.home_repair_service_rounded, tamanho: 56),
              const SizedBox(width: 14),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(servico.nome, style: t.titleLarge),
                  if (servico.categoria.isNotEmpty)
                    Text(servico.categoria,
                        style: t.bodyMedium?.copyWith(color: cor, fontWeight: FontWeight.w600)),
                  if (servico.profissionalRef != null)
                    NomeProfissional(servico: servico, grande: true),
                ]),
              ),
            ]),
            if (servico.descricao.isNotEmpty) ...[
              const SizedBox(height: 18),
              Text(servico.descricao, style: t.bodyLarge?.copyWith(height: 1.45)),
            ],
            const SizedBox(height: 20),
            Row(children: [
              info(Icons.payments_outlined, 'A partir de',
                  servico.precoFormatado ?? 'Sob consulta'),
              const SizedBox(width: 12),
              info(Icons.schedule_rounded, 'Duração média',
                  servico.duracaoFormatada ?? 'A combinar'),
            ]),
            const SizedBox(height: 12),
            Text(
              'O valor final é combinado com o profissional e só vale depois da sua aprovação.',
              style: t.bodySmall?.copyWith(color: HomefyColors.textMuted),
            ),
            const SizedBox(height: 20),
            FilledButton.icon(
              onPressed: () {
                Navigator.of(context).pop();
                mostrarAviso('Em breve: escolher data, horário e profissional.');
              },
              icon: const Icon(Icons.event_available_rounded),
              label: const Text('Solicitar atendimento'),
            ),
          ],
        ),
      ),
    );
  }
}

// ───────────────────────── Outros ─────────────────────────

class _ConviteProfissional extends StatelessWidget {
  const _ConviteProfissional();

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 0),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: HomefyColors.mint,
          borderRadius: BorderRadius.circular(HomefySpace.radiusLg),
        ),
        child: Row(children: [
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Você é profissional?',
                  style: t.titleMedium?.copyWith(color: HomefyColors.primaryDark)),
              const SizedBox(height: 4),
              Text('Com a mesma conta você poderá oferecer seus serviços em Caruaru.',
                  style: t.bodySmall?.copyWith(color: HomefyColors.primaryDark, height: 1.4)),
              const SizedBox(height: 12),
              FilledButton.tonal(
                style: FilledButton.styleFrom(
                  minimumSize: const Size(0, 40),
                  backgroundColor: HomefyColors.primary,
                  foregroundColor: Colors.white,
                ),
                onPressed: () => mostrarAviso('Cadastro de profissional chega na próxima etapa.'),
                child: const Text('Quero oferecer'),
              ),
            ]),
          ),
          const SizedBox(width: 12),
          const HomefyLogo(tamanho: 64),
        ]),
      ),
    );
  }
}

class _EstadoVazio extends StatelessWidget {
  const _EstadoVazio({
    required this.icone,
    required this.titulo,
    required this.texto,
    this.acao,
  });
  final IconData icone;
  final String titulo;
  final String texto;
  final Widget? acao;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 24),
      decoration: BoxDecoration(
        color: HomefyColors.surface,
        borderRadius: BorderRadius.circular(HomefySpace.radiusLg),
        border: Border.all(color: HomefyColors.border),
      ),
      child: Column(children: [
        Icon(icone, size: 40, color: HomefyColors.textMuted),
        const SizedBox(height: 12),
        Text(titulo, style: t.titleMedium, textAlign: TextAlign.center),
        const SizedBox(height: 6),
        Text(texto, style: t.bodyMedium, textAlign: TextAlign.center),
        if (acao != null) ...[const SizedBox(height: 8), acao!],
      ]),
    );
  }
}

/// Faz cada card entrar com um leve deslize, em cascata.
class _EntradaAnimada extends StatelessWidget {
  const _EntradaAnimada({required this.indice, required this.child});
  final int indice;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: Duration(milliseconds: 350 + indice * 70),
      curve: Curves.easeOutCubic,
      child: child,
      builder: (context, v, child) => Opacity(
        opacity: v,
        child: Transform.translate(offset: Offset(0, (1 - v) * 16), child: child),
      ),
    );
  }
}
