import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../config.dart';
import '../models/bairros.dart';
import '../models/categoria.dart';
import '../models/perfil.dart';
import '../models/servico.dart';
import '../services/auth_service.dart';
import '../services/perfil_repo.dart';
import '../models/solicitacao.dart';
import '../services/servicos_repo.dart';
import '../services/solicitacoes_repo.dart';
import '../theme/homefy_theme.dart';
import '../widgets/avaliacoes_widgets.dart';
import '../widgets/feedback_sheet.dart';
import '../widgets/homefy_logo.dart';
import '../widgets/servico_card.dart';
import 'solicitar_screen.dart';

/// Aba "Início": a vitrine de serviços.
class VitrineAba extends StatefulWidget {
  const VitrineAba({super.key});
  @override
  State<VitrineAba> createState() => _VitrineAbaState();
}

class _VitrineAbaState extends State<VitrineAba> with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  late final Stream<List<Servico>> _servicos = const ServicosRepo().ativos();
  final _busca = TextEditingController();
  Categoria? _categoria;

  /// Bairro onde será o atendimento. Filtro temporário: não é salvo no perfil.
  String? _bairro;

  @override
  void initState() {
    super.initState();
    _busca.addListener(() => setState(() {}));
    // Contas antigas: tira o e-mail do perfil público e cria o perfil se faltar.
    PerfilRepo.instance.arrumarPerfil();
  }

  Future<void> _escolherBairro() async {
    final escolhido = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      builder: (_) => _EscolherBairro(atual: _bairro),
    );
    if (escolhido == null) return;
    setState(() => _bairro = escolhido.isEmpty ? null : escolhido);
  }

  @override
  void dispose() {
    _busca.dispose();
    super.dispose();
  }

  List<Servico> _filtrar(List<Servico> todos) {
    final termo = normalizar(_busca.text.trim());
    return todos.where((s) {
      if (_categoria != null && s.categoriaMvp?.id != _categoria!.id) return false;
      if (_bairro != null && !s.atende(_bairro!)) return false;
      if (termo.isEmpty) return true;
      if (normalizar('${s.nome} ${s.categoria} ${s.subtipoRotulo ?? ''} ${s.descricao}').contains(termo)) {
        return true;
      }
      // Sinônimos: "unha" acha Manicure, "carro" acha Lavagem, "diarista" acha Limpeza.
      final cat = s.categoriaMvp;
      return cat != null && cat.combinaComBusca(termo);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    // Uma única escuta da lista de serviços, usada pelas categorias e pela vitrine.
    return Scaffold(
      body: StreamBuilder<List<Servico>>(
        stream: _servicos,
        builder: (context, snap) => Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 640),
          child: CustomScrollView(
            slivers: [
              SliverToBoxAdapter(
                child: _Cabecalho(busca: _busca, bairro: _bairro, aoEscolherBairro: _escolherBairro),
              ),
              if (kModoDemo) const SliverToBoxAdapter(child: _FaixaDemo()),
              const SliverToBoxAdapter(child: _AvisoPedidos()),
              SliverToBoxAdapter(
                child: _Categorias(
                  selecionada: _categoria,
                  servicos: snap.data ?? const [],
                  aoSelecionar: (c) => setState(() => _categoria = c == _categoria ? null : c),
                ),
              ),
              _listaServicos(context, snap),
              SliverToBoxAdapter(
                child: _NaoAchou(
                  aoTocar: () => abrirFeedback(
                    context,
                    tipo: TipoFeedback.naoAchei,
                    busca: _busca.text.trim(),
                    categoriaId: _categoria?.id,
                    bairro: _bairro,
                  ),
                ),
              ),
              const SliverToBoxAdapter(child: _ConviteProfissional()),
              SliverToBoxAdapter(
                child: SizedBox(height: 32 + MediaQuery.paddingOf(context).bottom),
              ),
            ],
          ),
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
      final temFiltro = _categoria != null || _bairro != null || _busca.text.trim().isNotEmpty;
      corpo = _EstadoVazio(
        icone: temFiltro ? Icons.search_off_rounded : Icons.inventory_2_outlined,
        titulo: temFiltro ? 'Nada encontrado' : 'Ainda não há serviços ativos',
        texto: temFiltro
            ? (_bairro != null
                ? 'Ainda não há profissional para isso em ${Bairro.nomeDe(_bairro!)}. Tente outro bairro ou nos conte o que procura.'
                : 'Tente outra palavra ou outra categoria.')
            : 'Assim que houver serviços com "ativo = true" no banco, eles aparecem aqui.',
        acao: temFiltro
            ? TextButton(
                onPressed: () => setState(() {
                  _categoria = null;
                  _bairro = null;
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
      builder: (_) => _DetalheServico(servico: s, bairro: _bairro),
    );
  }
}

// ───────────────────────── Cabeçalho ─────────────────────────

class _Cabecalho extends StatelessWidget {
  const _Cabecalho({required this.busca, required this.bairro, required this.aoEscolherBairro});
  final TextEditingController busca;
  final String? bairro;
  final VoidCallback aoEscolherBairro;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final topo = MediaQuery.paddingOf(context).top;
    final branco70 = Colors.white.withValues(alpha: 0.72);

    return Container(
      decoration: const BoxDecoration(
        color: HomefyColors.primary,
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(28)),
      ),
      padding: EdgeInsets.fromLTRB(20, topo + 14, 20, 22),
      child: ListenableBuilder(
        listenable: AuthService.instance,
        builder: (context, _) {
          final nome = AuthService.instance.primeiroNome;
          return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            // Linha 1: onde será o atendimento (como "entregar em" dos apps de entrega)
            Row(children: [
              Expanded(
                child: InkWell(
                  onTap: aoEscolherBairro,
                  borderRadius: BorderRadius.circular(12),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text('Atendimento em', style: t.labelMedium?.copyWith(color: branco70)),
                      Row(children: [
                        const Icon(Icons.location_on_rounded, size: 18, color: HomefyColors.sol),
                        const SizedBox(width: 4),
                        Flexible(
                          child: Text(
                            bairro == null ? 'Caruaru · escolha o bairro' : '${Bairro.nomeDe(bairro!)}, Caruaru',
                            overflow: TextOverflow.ellipsis,
                            style: t.titleSmall?.copyWith(color: Colors.white, fontWeight: FontWeight.w700),
                          ),
                        ),
                        const Icon(Icons.keyboard_arrow_down_rounded, color: Colors.white),
                      ]),
                    ]),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              const HomefyLogo(tamanho: 40, claro: true),
            ]),
            const SizedBox(height: 22),
            Text(nome == null ? 'Olá!' : 'Olá, $nome', style: t.bodyLarge?.copyWith(color: branco70)),
            const SizedBox(height: 2),
            Text('Do que sua casa precisa hoje?',
                style: t.headlineSmall?.copyWith(color: Colors.white, height: 1.15)),
            const SizedBox(height: 18),
            _CampoBusca(controller: busca),
          ]);
        },
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

// ───────────────────────── Categorias ─────────────────────────

class _Categorias extends StatelessWidget {
  const _Categorias({required this.selecionada, required this.servicos, required this.aoSelecionar});
  final Categoria? selecionada;
  final List<Servico> servicos;
  final ValueChanged<Categoria> aoSelecionar;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    int quantos(Categoria c) => servicos.where((s) => s.categoriaMvp?.id == c.id).length;
    final cats = Categoria.todas;
    Widget tile(Categoria c) => Expanded(
          child: _CategoriaTile(
            categoria: c,
            quantidade: quantos(c),
            selecionada: c == selecionada,
            aoTocar: () => aoSelecionar(c),
          ),
        );
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 26, 20, 0),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Text('O que você procura?', style: t.titleLarge),
        const SizedBox(height: 12),
        // 4 categorias: grade 2×2 cabe inteira na tela, sem rolagem lateral.
        Row(children: [tile(cats[0]), const SizedBox(width: 12), tile(cats[1])]),
        const SizedBox(height: 12),
        Row(children: [tile(cats[2]), const SizedBox(width: 12), tile(cats[3])]),
      ]),
    );
  }
}

class _CategoriaTile extends StatelessWidget {
  const _CategoriaTile({
    required this.categoria,
    required this.quantidade,
    required this.selecionada,
    required this.aoTocar,
  });
  final Categoria categoria;
  final int quantidade;
  final bool selecionada;
  final VoidCallback aoTocar;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final cor = categoria.cor;
    return Semantics(
      selected: selecionada,
      button: true,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        height: 96,
        decoration: BoxDecoration(
          color: selecionada ? cor : cor.withValues(alpha: 0.09),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: selecionada ? cor : cor.withValues(alpha: 0.16)),
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(20),
            onTap: aoTocar,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(14, 12, 12, 12),
              child: Row(children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(categoria.rotulo,
                          maxLines: 2,
                          style: t.titleSmall?.copyWith(
                            height: 1.15,
                            color: selecionada ? Colors.white : HomefyColors.text,
                          )),
                      Text(
                        quantidade == 0 ? 'em breve' : (quantidade == 1 ? '1 serviço' : '$quantidade serviços'),
                        style: t.labelSmall?.copyWith(
                          color: selecionada ? Colors.white.withValues(alpha: 0.85) : HomefyColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: selecionada ? Colors.white.withValues(alpha: 0.2) : Colors.white,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(categoria.icone, size: 22, color: selecionada ? Colors.white : cor),
                ),
              ]),
            ),
          ),
        ),
      ),
    );
  }
}

// ───────────────────────── Detalhe ─────────────────────────

class _DetalheServico extends StatelessWidget {
  const _DetalheServico({required this.servico, this.bairro});
  final Servico servico;

  /// Bairro escolhido na Home (vai pré-preenchido no pedido).
  final String? bairro;

  /// O serviço é do próprio usuário? (não faz sentido pedir para si mesmo)
  bool get _ehMeu {
    final dono = servico.profissionalRef?.id;
    final eu = kModoDemo ? 'demo' : FirebaseAuth.instance.currentUser?.uid;
    return dono != null && dono == eu;
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final cat = servico.categoriaMvp;
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
      child: SingleChildScrollView(
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
                  if (servico.categoriaRotulo.isNotEmpty)
                    Text(servico.categoriaRotulo,
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
            if (servico.profissionalRef != null) SobreProfissional(servico: servico),
            if (servico.profissionalRef != null || kModoDemo)
              AvaliacoesDoProfissional(
                  profissionalUid: servico.profissionalRef?.id ?? 'teste_demo'),
            const SizedBox(height: 20),
            if (servico.temVariacoes)
              _TabelaVariacoes(servico: servico, cor: cor)
            else
              Row(children: [
                info(Icons.payments_outlined, 'A partir de',
                    servico.precoFormatado ?? 'Sob consulta'),
                const SizedBox(width: 12),
                info(Icons.schedule_rounded, 'Duração média',
                    servico.duracaoFormatada ?? 'A combinar'),
              ]),
            if (servico.atendeTodaCidade || servico.bairros.isNotEmpty) ...[
              const SizedBox(height: 12),
              Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Icon(Icons.place_outlined, size: 18, color: cor),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    servico.atendeTodaCidade
                        ? 'Atende Caruaru toda'
                        : 'Atende: ${servico.bairros.map(Bairro.nomeDe).join(', ')}',
                    style: t.bodySmall?.copyWith(height: 1.4),
                  ),
                ),
              ]),
            ],
            const SizedBox(height: 12),
            Text(
              'O valor final é combinado com o profissional e só vale depois da sua aprovação.',
              style: t.bodySmall?.copyWith(color: HomefyColors.textMuted),
            ),
            const SizedBox(height: 20),
            if (_ehMeu)
              OutlinedButton.icon(
                onPressed: () {
                  Navigator.of(context).pop();
                  context.push('/meus-servicos');
                },
                icon: const Icon(Icons.storefront_outlined),
                label: const Text('Este serviço é seu: editar'),
              )
            else
              FilledButton.icon(
                onPressed: () {
                  Navigator.of(context).pop();
                  Navigator.of(context).push(MaterialPageRoute<void>(
                    builder: (_) => SolicitarScreen(servico: servico, bairroInicial: bairro),
                  ));
                },
                icon: const Icon(Icons.event_available_rounded),
                label: const Text('Pedir atendimento'),
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
    return StreamBuilder<PerfilUsuario?>(
      stream: PerfilRepo.instance.meu(),
      builder: (context, snap) => _cartao(context, snap.data?.ehProfissional == true),
    );
  }

  Widget _cartao(BuildContext context, bool profissional) {
    final t = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: HomefyColors.primaryDark,
          borderRadius: BorderRadius.circular(24),
        ),
        child: Row(children: [
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(profissional ? 'Sua vitrine' : 'Trabalha com isso?',
                  style: t.titleMedium?.copyWith(color: Colors.white)),
              const SizedBox(height: 4),
              Text(
                  profissional
                      ? 'Cadastre, edite ou esconda seus serviços quando quiser.'
                      : 'Ofereça seus serviços para clientes de Caruaru, com a mesma conta. É grátis.',
                  style: t.bodySmall?.copyWith(color: Colors.white.withValues(alpha: 0.78), height: 1.4)),
              const SizedBox(height: 14),
              FilledButton(
                style: FilledButton.styleFrom(
                  minimumSize: const Size(0, 42),
                  backgroundColor: HomefyColors.sol,
                  foregroundColor: HomefyColors.primaryDark,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(99)),
                ),
                onPressed: () => context.push(profissional ? '/meus-servicos' : '/oferecer'),
                child: Text(profissional ? 'Meus serviços' : 'Quero oferecer'),
              ),
            ]),
          ),
          const SizedBox(width: 14),
          const HomefyLogo(tamanho: 64, claro: true),
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

// ───────────────────────── Bairro, variações e "não achou" ─────────────────────────

/// Lista de bairros para o cliente dizer onde será o atendimento.
/// Devolve o id do bairro, ou '' para "todos".
class _EscolherBairro extends StatefulWidget {
  const _EscolherBairro({required this.atual});
  final String? atual;
  @override
  State<_EscolherBairro> createState() => _EscolherBairroState();
}

class _EscolherBairroState extends State<_EscolherBairro> {
  final _busca = TextEditingController();

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

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final termo = normalizar(_busca.text.trim());
    final lista = Bairro.todos.where((b) => termo.isEmpty || normalizar(b.nome).contains(termo)).toList();
    return SafeArea(
      child: SizedBox(
        height: MediaQuery.sizeOf(context).height * 0.8,
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 0, 24, 8),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Onde será o atendimento?', style: t.titleLarge),
              const SizedBox(height: 4),
              Text('Mostramos só quem atende o seu bairro. Não fica salvo no seu perfil.',
                  style: t.bodySmall),
              const SizedBox(height: 12),
              TextField(
                controller: _busca,
                autofocus: false,
                decoration: const InputDecoration(
                  hintText: 'Procurar bairro',
                  prefixIcon: Icon(Icons.search_rounded, size: 20),
                ),
              ),
            ]),
          ),
          Expanded(
            child: ListView(children: [
              if (termo.isEmpty)
                ListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 24),
                  leading: const Icon(Icons.public_rounded),
                  title: const Text('Todos os bairros'),
                  trailing: widget.atual == null
                      ? const Icon(Icons.check_rounded, color: HomefyColors.primary)
                      : null,
                  onTap: () => Navigator.of(context).pop(''),
                ),
              for (final b in lista)
                ListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 24),
                  title: Text(b.nome),
                  trailing: widget.atual == b.id
                      ? const Icon(Icons.check_rounded, color: HomefyColors.primary)
                      : null,
                  onTap: () => Navigator.of(context).pop(b.id),
                ),
              if (lista.isEmpty)
                Padding(
                  padding: const EdgeInsets.all(24),
                  child: Text('Nenhum bairro com esse nome em Caruaru.', style: t.bodySmall),
                ),
            ]),
          ),
        ]),
      ),
    );
  }
}

/// Faixas de preço do serviço (ex.: Carro pequeno / Carro médio / SUV).
class _TabelaVariacoes extends StatelessWidget {
  const _TabelaVariacoes({required this.servico, required this.cor});
  final Servico servico;
  final Color cor;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
      decoration: BoxDecoration(
        color: HomefyColors.background,
        borderRadius: BorderRadius.circular(HomefySpace.radiusMd),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Row(children: [
          Icon(Icons.payments_outlined, size: 18, color: cor),
          const SizedBox(width: 6),
          Text('Preços a partir de', style: t.labelLarge),
        ]),
        const SizedBox(height: 6),
        for (final v in servico.variacoes)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Row(children: [
              Expanded(child: Text(v.rotulo, style: t.bodyMedium)),
              if (Servico.formatarDuracao(v.duracaoMinutos) != null)
                Padding(
                  padding: const EdgeInsets.only(right: 12),
                  child: Text(Servico.formatarDuracao(v.duracaoMinutos)!,
                      style: t.bodySmall?.copyWith(color: HomefyColors.textMuted)),
                ),
              Text(Servico.formatarPreco(v.preco) ?? 'Sob consulta',
                  style: t.titleSmall?.copyWith(color: HomefyColors.primary)),
            ]),
          ),
      ]),
    );
  }
}

/// Convite discreto no fim da vitrine (decisão D1: no lugar de "Outros").
class _NaoAchou extends StatelessWidget {
  const _NaoAchou({required this.aoTocar});
  final VoidCallback aoTocar;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 12, 24, 0),
      child: OutlinedButton.icon(
        onPressed: aoTocar,
        style: OutlinedButton.styleFrom(
          minimumSize: const Size.fromHeight(52),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(HomefySpace.radiusMd)),
        ),
        icon: const Icon(Icons.lightbulb_outline_rounded),
        label: Text('Não achou? Conte pra gente', style: t.labelLarge),
      ),
    );
  }
}

/// Faixa no topo da Home quando há pedido esperando ação do usuário:
/// cliente com valor para confirmar, ou profissional com pedido novo.
class _AvisoPedidos extends StatelessWidget {
  const _AvisoPedidos();

  @override
  Widget build(BuildContext context) {
    final repo = SolicitacoesRepo.instance;
    return StreamBuilder<List<Solicitacao>>(
      stream: repo.comoCliente(),
      builder: (context, cli) => StreamBuilder<PerfilUsuario?>(
        stream: PerfilRepo.instance.meu(),
        builder: (context, perfil) {
          final confirmar = (cli.data ?? const <Solicitacao>[])
              .where((s) => s.status == StatusPedido.proposta)
              .length;
          if (perfil.data?.ehProfissional != true) {
            return _faixa(context, confirmar, 0);
          }
          return StreamBuilder<List<Solicitacao>>(
            stream: repo.comoProfissional(),
            builder: (context, prof) {
              final responder = (prof.data ?? const <Solicitacao>[])
                  .where((s) => s.status == StatusPedido.pendente)
                  .length;
              return _faixa(context, confirmar, responder);
            },
          );
        },
      ),
    );
  }

  Widget _faixa(BuildContext context, int confirmar, int responder) {
    if (confirmar == 0 && responder == 0) return const SizedBox.shrink();
    final t = Theme.of(context).textTheme;
    final cliente = confirmar > 0;
    final n = cliente ? confirmar : responder;
    final texto = cliente
        ? (n == 1 ? '1 pedido com valor para você confirmar' : '$n pedidos com valor para confirmar')
        : (n == 1 ? '1 pedido novo para responder' : '$n pedidos novos para responder');
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 0),
      child: Material(
        color: const Color(0xFFE3F2FD),
        borderRadius: BorderRadius.circular(HomefySpace.radiusMd),
        child: InkWell(
          borderRadius: BorderRadius.circular(HomefySpace.radiusMd),
          onTap: () => context.push(cliente ? '/meus-pedidos' : '/pedidos-recebidos'),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(children: [
              const Icon(Icons.notifications_active_outlined, color: HomefyColors.tertiary),
              const SizedBox(width: 10),
              Expanded(
                child: Text(texto,
                    style: t.titleSmall?.copyWith(color: const Color(0xFF023E7D))),
              ),
              const Icon(Icons.chevron_right_rounded, color: HomefyColors.tertiary),
            ]),
          ),
        ),
      ),
    );
  }
}

/// Só na versão de demonstração: explica que os dados são de exemplo.
class _FaixaDemo extends StatelessWidget {
  const _FaixaDemo();

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 0),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: const Color(0xFFFFF8E6),
          borderRadius: BorderRadius.circular(HomefySpace.radiusMd),
          border: Border.all(color: const Color(0xFFF4D58D)),
        ),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Icon(Icons.science_outlined, color: Color(0xFF8A6100)),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'Versão de demonstração: dados de exemplo, nada é salvo (ao recarregar a página, tudo volta ao início). '
              'Experimente: pedir um serviço, ver "Meus pedidos" no menu do perfil (B), confirmar e avaliar; '
              'ou "Quero oferecer meus serviços".',
              style: t.bodySmall?.copyWith(color: const Color(0xFF5C4100), height: 1.4),
            ),
          ),
        ]),
      ),
    );
  }
}
