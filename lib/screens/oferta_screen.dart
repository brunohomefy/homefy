import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../models/bairros.dart';
import '../models/categoria.dart';
import '../models/perfil.dart';
import '../services/perfil_repo.dart';
import '../theme/homefy_theme.dart';
import '../widgets/formulario.dart';

/// "Quero oferecer": a mesma conta passa a oferecer serviços.
/// Também serve para EDITAR o perfil profissional depois.
///
/// Passos: 1. o que faz → 2. onde atende → 3. contato e apresentação → 4. revisão.
class OfertaScreen extends StatefulWidget {
  const OfertaScreen({super.key});
  @override
  State<OfertaScreen> createState() => _OfertaScreenState();
}

class _OfertaScreenState extends State<OfertaScreen> {
  static const _totalPassos = 4;
  static const _maxDescricao = 500;

  int _passo = 0;
  bool _carregando = true;
  bool _salvando = false;
  bool _editando = false;

  final _categorias = <String>[];
  final _subtipos = <String>{};
  final _bairros = <String>{};
  bool _todaCidade = false;
  final _whats = TextEditingController();
  final _descricao = TextEditingController();
  final _buscaBairro = TextEditingController();
  String? _erro;

  @override
  void initState() {
    super.initState();
    _buscaBairro.addListener(() => setState(() {}));
    _carregar();
  }

  Future<void> _carregar() async {
    try {
      final perfil = await PerfilRepo.instance.meu().first;
      final whats = await PerfilRepo.instance.meuWhatsapp();
      if (!mounted) return;
      setState(() {
        if (perfil != null && perfil.ehProfissional) {
          _editando = true;
          _categorias.addAll(perfil.categorias.where((c) => Categoria.porId(c) != null));
          _subtipos.addAll(perfil.subtipos);
          _bairros.addAll(perfil.bairros);
          _todaCidade = perfil.atendeTodaCidade;
          _descricao.text = perfil.descricao;
        }
        if (whats != null) _whats.text = formatarWhatsapp(whats);
      });
    } catch (_) {
      // Sem perfil ainda: começa em branco.
    } finally {
      if (mounted) setState(() => _carregando = false);
    }
  }

  @override
  void dispose() {
    _whats.dispose();
    _descricao.dispose();
    _buscaBairro.dispose();
    super.dispose();
  }

  // ── Validação de cada passo ──
  String? _problemaDoPasso(int p) {
    switch (p) {
      case 0:
        if (_categorias.isEmpty) return 'Escolha pelo menos uma categoria.';
        for (final id in _categorias) {
          final c = Categoria.porId(id)!;
          if (!c.subtipos.any((s) => _subtipos.contains(s.id))) {
            return 'Marque o que você faz em ${c.rotulo}.';
          }
        }
        return null;
      case 1:
        if (!_todaCidade && _bairros.isEmpty) return 'Escolha os bairros onde você atende.';
        return null;
      case 2:
        if (normalizarWhatsapp(_whats.text) == null) {
          return 'Informe um WhatsApp válido, com DDD. Ex.: (81) 99999-1234';
        }
        if (_descricao.text.trim().length > _maxDescricao) {
          return 'A apresentação passou de $_maxDescricao caracteres.';
        }
        return null;
    }
    return null;
  }

  void _avancar() {
    final problema = _problemaDoPasso(_passo);
    setState(() => _erro = problema);
    if (problema != null) return;
    if (_passo < _totalPassos - 1) {
      setState(() => _passo++);
    } else {
      _salvar();
    }
  }

  void _voltar() {
    if (_passo == 0) {
      context.canPop() ? context.pop() : context.go('/home');
    } else {
      setState(() {
        _passo--;
        _erro = null;
      });
    }
  }

  Future<void> _salvar() async {
    setState(() => _salvando = true);
    try {
      // Só guarda subtipos das categorias que continuam marcadas.
      final validos = _categorias
          .expand((id) => Categoria.porId(id)!.subtipos)
          .map((s) => s.id)
          .where(_subtipos.contains)
          .toList();
      await PerfilRepo.instance.salvarProfissional(
        categorias: List.of(_categorias),
        subtipos: validos,
        bairros: Bairro.todos.map((b) => b.id).where(_bairros.contains).toList(),
        atendeTodaCidade: _todaCidade,
        descricao: _descricao.text,
        whatsapp: normalizarWhatsapp(_whats.text)!,
      );
      if (!mounted) return;
      mostrarAviso(_editando ? 'Perfil profissional atualizado.' : 'Pronto! Agora cadastre seus serviços.');
      context.go('/meus-servicos');
    } catch (e) {
      debugPrint('salvarProfissional: $e');
      final semPermissao = '$e'.contains('permission-denied');
      setState(() => _erro = semPermissao
          ? 'O banco recusou o cadastro. Confira se as regras novas do Firestore foram publicadas.'
          : 'Não foi possível salvar. Verifique a conexão e tente de novo.');
    } finally {
      if (mounted) setState(() => _salvando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final titulos = [
      'O que você faz?',
      'Onde você atende?',
      'Contato e apresentação',
      'Confira e confirme',
    ];
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          tooltip: 'Voltar',
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: _salvando ? null : _voltar,
        ),
        title: Text(_editando ? 'Editar perfil profissional' : 'Quero oferecer'),
      ),
      body: _carregando
          ? const Center(child: CircularProgressIndicator())
          : Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 640),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(24, 8, 24, 0),
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(99),
                          child: LinearProgressIndicator(
                            value: (_passo + 1) / _totalPassos,
                            minHeight: 6,
                            backgroundColor: HomefyColors.mint,
                          ),
                        ),
                        const SizedBox(height: 16),
                        Text('Passo ${_passo + 1} de $_totalPassos',
                            style: t.labelMedium?.copyWith(color: HomefyColors.textSecondary)),
                        const SizedBox(height: 4),
                        Text(titulos[_passo], style: t.headlineSmall),
                      ]),
                    ),
                    Expanded(
                      child: ListView(
                        key: ValueKey(_passo),
                        padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
                        children: [
                          switch (_passo) {
                            0 => _passoCategorias(t),
                            1 => _passoBairros(t),
                            2 => _passoContato(t),
                            _ => _passoRevisao(t),
                          },
                        ],
                      ),
                    ),
                    _rodape(t),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _rodape(TextTheme t) {
    return SafeArea(
      top: false,
      child: Container(
        padding: const EdgeInsets.fromLTRB(24, 12, 24, 12),
        decoration: const BoxDecoration(
          color: HomefyColors.surface,
          border: Border(top: BorderSide(color: HomefyColors.border)),
        ),
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          if (_erro != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Row(children: [
                const Icon(Icons.error_outline_rounded, color: HomefyColors.error, size: 20),
                const SizedBox(width: 8),
                Expanded(child: Text(_erro!, style: t.bodySmall?.copyWith(color: HomefyColors.error))),
              ]),
            ),
          BotaoPrimario(
            texto: _passo == _totalPassos - 1
                ? (_editando ? 'Salvar alterações' : 'Começar a oferecer')
                : 'Continuar',
            icone: _passo == _totalPassos - 1 ? Icons.check_rounded : Icons.arrow_forward_rounded,
            carregando: _salvando,
            aoTocar: _avancar,
          ),
        ]),
      ),
    );
  }

  // ── Passo 1: categorias e subtipos ──
  Widget _passoCategorias(TextTheme t) {
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Text('Escolha uma ou mais áreas e marque o que você faz em cada uma. '
          'O cliente só vê o que você marcar.',
          style: t.bodyMedium?.copyWith(color: HomefyColors.textSecondary, height: 1.4)),
      const SizedBox(height: 16),
      for (final c in Categoria.todas) ...[
        _CartaoCategoria(
          categoria: c,
          marcada: _categorias.contains(c.id),
          subtipos: _subtipos,
          aoMarcar: (v) => setState(() {
            _erro = null;
            if (v) {
              _categorias.add(c.id);
            } else {
              _categorias.remove(c.id);
              _subtipos.removeAll(c.subtipos.map((s) => s.id));
            }
          }),
          aoMarcarSubtipo: (id, v) => setState(() {
            _erro = null;
            v ? _subtipos.add(id) : _subtipos.remove(id);
          }),
        ),
        const SizedBox(height: 12),
      ],
      Text('Faz outro tipo de serviço? Ainda estamos começando por essas quatro áreas em Caruaru.',
          style: t.bodySmall?.copyWith(color: HomefyColors.textMuted)),
    ]);
  }

  // ── Passo 2: bairros ──
  Widget _passoBairros(TextTheme t) {
    final termo = normalizar(_buscaBairro.text.trim());
    final lista = Bairro.todos.where((b) => termo.isEmpty || normalizar(b.nome).contains(termo));
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Text('Você só recebe pedidos dos bairros que marcar.',
          style: t.bodyMedium?.copyWith(color: HomefyColors.textSecondary, height: 1.4)),
      const SizedBox(height: 12),
      Container(
        decoration: BoxDecoration(
          color: HomefyColors.surface,
          borderRadius: BorderRadius.circular(HomefySpace.radiusMd),
          border: Border.all(color: _todaCidade ? HomefyColors.primary : HomefyColors.border),
        ),
        child: SwitchListTile(
          value: _todaCidade,
          onChanged: (v) => setState(() {
            _todaCidade = v;
            _erro = null;
          }),
          title: const Text('Atendo Caruaru toda'),
          subtitle: const Text('Inclusive bairros mais distantes'),
        ),
      ),
      if (!_todaCidade) ...[
        const SizedBox(height: 16),
        TextField(
          controller: _buscaBairro,
          decoration: const InputDecoration(
            hintText: 'Procurar bairro',
            prefixIcon: Icon(Icons.search_rounded, size: 20),
          ),
        ),
        const SizedBox(height: 12),
        Row(children: [
          Expanded(
            child: Text(
              _bairros.isEmpty ? 'Nenhum bairro marcado' : '${_bairros.length} bairro(s) marcado(s)',
              style: t.labelLarge?.copyWith(color: HomefyColors.primary),
            ),
          ),
          if (_bairros.isNotEmpty)
            TextButton(onPressed: () => setState(_bairros.clear), child: const Text('Limpar')),
        ]),
        const SizedBox(height: 8),
        Wrap(spacing: 8, runSpacing: 8, children: [
          for (final b in lista)
            FilterChip(
              label: Text(b.nome),
              selected: _bairros.contains(b.id),
              onSelected: (v) => setState(() {
                _erro = null;
                v ? _bairros.add(b.id) : _bairros.remove(b.id);
              }),
            ),
        ]),
        if (lista.isEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text('Nenhum bairro com esse nome.', style: t.bodySmall),
          ),
      ],
    ]);
  }

  // ── Passo 3: WhatsApp e descrição ──
  Widget _passoContato(TextTheme t) {
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      CampoTexto(
        rotulo: 'WhatsApp',
        controller: _whats,
        dica: '(81) 99999-1234',
        icone: Icons.phone_iphone_rounded,
        teclado: TextInputType.phone,
        autofill: const [AutofillHints.telephoneNumber],
      ),
      const SizedBox(height: 8),
      Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: HomefyColors.mint,
          borderRadius: BorderRadius.circular(HomefySpace.radiusSm),
        ),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Icon(Icons.lock_outline_rounded, size: 18, color: HomefyColors.primaryDark),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'Seu número fica privado. Ele não aparece no seu perfil: '
              'o cliente só recebe depois de fazer um pedido para você.',
              style: t.bodySmall?.copyWith(color: HomefyColors.primaryDark, height: 1.4),
            ),
          ),
        ]),
      ),
      const SizedBox(height: 24),
      Text('Apresentação (opcional)', style: t.labelLarge?.copyWith(color: HomefyColors.text)),
      const SizedBox(height: 8),
      TextField(
        controller: _descricao,
        maxLines: 5,
        minLines: 3,
        maxLength: _maxDescricao,
        textCapitalization: TextCapitalization.sentences,
        decoration: const InputDecoration(
          hintText: 'Ex.: Barbeiro há 8 anos. Levo todo o material e atendo com hora marcada.',
        ),
      ),
      Text('Não coloque telefone, endereço ou redes sociais aqui: esse texto é público.',
          style: t.bodySmall?.copyWith(color: HomefyColors.textMuted)),
    ]);
  }

  // ── Passo 4: revisão ──
  Widget _passoRevisao(TextTheme t) {
    Widget bloco(String titulo, int passo, Widget conteudo) => Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.fromLTRB(16, 8, 8, 16),
          decoration: BoxDecoration(
            color: HomefyColors.surface,
            borderRadius: BorderRadius.circular(HomefySpace.radiusMd),
            border: Border.all(color: HomefyColors.border),
          ),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Expanded(child: Text(titulo, style: t.titleSmall)),
              TextButton(onPressed: () => setState(() => _passo = passo), child: const Text('Alterar')),
            ]),
            conteudo,
          ]),
        );

    final cats = _categorias.map(Categoria.porId).whereType<Categoria>();
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      bloco(
        'O que você faz',
        0,
        Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          for (final c in cats)
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Text.rich(TextSpan(children: [
                TextSpan(text: '${c.rotulo}: ', style: const TextStyle(fontWeight: FontWeight.w700)),
                TextSpan(
                    text: c.subtipos.where((s) => _subtipos.contains(s.id)).map((s) => s.rotulo).join(', ')),
              ])),
            ),
        ]),
      ),
      bloco(
        'Onde atende',
        1,
        Text(_todaCidade
            ? 'Caruaru toda'
            : Bairro.todos.where((b) => _bairros.contains(b.id)).map((b) => b.nome).join(', ')),
      ),
      bloco(
        'Contato e apresentação',
        2,
        Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('WhatsApp (privado): ${formatarWhatsapp(normalizarWhatsapp(_whats.text) ?? '')}'),
          const SizedBox(height: 6),
          Text(_descricao.text.trim().isEmpty ? 'Sem apresentação.' : _descricao.text.trim(),
              style: t.bodySmall?.copyWith(height: 1.4)),
        ]),
      ),
      if (!_editando)
        Text('Depois de confirmar, você cadastra os seus serviços e preços.',
            style: t.bodySmall?.copyWith(color: HomefyColors.textSecondary)),
    ]);
  }
}

class _CartaoCategoria extends StatelessWidget {
  const _CartaoCategoria({
    required this.categoria,
    required this.marcada,
    required this.subtipos,
    required this.aoMarcar,
    required this.aoMarcarSubtipo,
  });

  final Categoria categoria;
  final bool marcada;
  final Set<String> subtipos;
  final ValueChanged<bool> aoMarcar;
  final void Function(String id, bool v) aoMarcarSubtipo;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final c = categoria;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      decoration: BoxDecoration(
        color: HomefyColors.surface,
        borderRadius: BorderRadius.circular(HomefySpace.radiusMd),
        border: Border.all(color: marcada ? c.cor : HomefyColors.border, width: marcada ? 1.6 : 1),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        InkWell(
          borderRadius: BorderRadius.circular(HomefySpace.radiusMd),
          onTap: () => aoMarcar(!marcada),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: c.cor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(HomefySpace.radiusSm),
                ),
                child: Icon(c.icone, color: c.cor),
              ),
              const SizedBox(width: 12),
              Expanded(child: Text(c.rotulo, style: t.titleMedium)),
              Checkbox(value: marcada, onChanged: (v) => aoMarcar(v ?? false)),
            ]),
          ),
        ),
        if (marcada)
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
            child: Wrap(spacing: 8, runSpacing: 8, children: [
              for (final s in c.subtipos)
                FilterChip(
                  label: Text(s.rotulo),
                  selected: subtipos.contains(s.id),
                  onSelected: (v) => aoMarcarSubtipo(s.id, v),
                ),
            ]),
          ),
      ]),
    );
  }
}
