import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/categoria.dart';
import '../models/perfil.dart';
import '../models/servico.dart';
import '../services/servicos_repo.dart';
import '../theme/homefy_theme.dart';
import '../widgets/formulario.dart';

/// Criar ou editar um serviço do próprio profissional.
///
/// Todo serviço começa com uma variação "Padrão" (preço único). As faixas
/// por porte (ex.: "SUV ou picape") são opcionais (decisão D2).
class ServicoEditorScreen extends StatefulWidget {
  const ServicoEditorScreen({super.key, required this.perfil, this.servico});

  final PerfilUsuario perfil;

  /// Nulo = novo serviço.
  final Servico? servico;

  @override
  State<ServicoEditorScreen> createState() => _ServicoEditorScreenState();
}

class _LinhaVariacao {
  _LinhaVariacao({String rotulo = Variacao.rotuloPadrao, double? preco, int? duracao})
      : rotulo = TextEditingController(text: rotulo),
        preco = TextEditingController(text: preco == null ? '' : _precoParaTexto(preco)),
        duracao = TextEditingController(text: duracao == null ? '' : '$duracao');

  final TextEditingController rotulo;
  final TextEditingController preco;
  final TextEditingController duracao;

  static String _precoParaTexto(double v) =>
      v == v.roundToDouble() ? v.toStringAsFixed(0) : v.toStringAsFixed(2).replaceAll('.', ',');

  void dispose() {
    rotulo.dispose();
    preco.dispose();
    duracao.dispose();
  }
}

/// "25", "25,50", "1.200,00" → 25.0 / 25.5 / 1200.0. Vazio → nulo ("sob consulta").
double? lerPreco(String texto) {
  final s = texto.trim().replaceAll('R\$', '').replaceAll(' ', '');
  if (s.isEmpty) return null;
  final normal = s.contains(',') ? s.replaceAll('.', '').replaceAll(',', '.') : s;
  return double.tryParse(normal);
}

class _ServicoEditorScreenState extends State<ServicoEditorScreen> {
  static const _maxVariacoes = 6;

  late final List<Categoria> _categorias = widget.perfil.categorias
      .map(Categoria.porId)
      .whereType<Categoria>()
      .toList();

  late Categoria? _categoria;
  String? _subtipo;
  final _nome = TextEditingController();
  final _descricao = TextEditingController();
  final _linhas = <_LinhaVariacao>[];
  bool _ativo = true;
  bool _salvando = false;
  String? _erro;
  bool _nomeTocado = false;
  bool _sugerindoNome = false;

  bool get _novo => widget.servico == null;

  @override
  void initState() {
    super.initState();
    final s = widget.servico;
    if (s != null) {
      _categoria = s.categoriaMvp;
      _subtipo = s.subtipo;
      _nome.text = s.nome;
      _nomeTocado = true;
      _descricao.text = s.descricao;
      _ativo = s.ativo;
      for (final v in s.variacoesOuPadrao) {
        _linhas.add(_LinhaVariacao(rotulo: v.rotulo, preco: v.preco, duracao: v.duracaoMinutos));
      }
    } else {
      _categoria = _categorias.length == 1 ? _categorias.first : null;
      _linhas.add(_LinhaVariacao());
    }
    // Se a pessoa digitar o nome, paramos de sugerir pelo tipo de serviço.
    _nome.addListener(() {
      if (!_sugerindoNome) _nomeTocado = true;
    });
  }

  @override
  void dispose() {
    _nome.dispose();
    _descricao.dispose();
    for (final l in _linhas) {
      l.dispose();
    }
    super.dispose();
  }

  /// Subtipos que o profissional marcou no perfil, dentro da categoria.
  List<Subtipo> get _subtiposDisponiveis {
    final c = _categoria;
    if (c == null) return const [];
    final marcados = c.subtipos.where((s) => widget.perfil.subtipos.contains(s.id)).toList();
    return marcados.isNotEmpty ? marcados : c.subtipos;
  }

  void _escolherSubtipo(Subtipo s) {
    setState(() {
      _subtipo = s.id;
      _erro = null;
      // Sugere o nome, sem atropelar o que a pessoa já escreveu.
      if (!_nomeTocado || _nome.text.trim().isEmpty) {
        _sugerindoNome = true;
        _nome.text = s.rotulo;
        _sugerindoNome = false;
      }
    });
  }

  void _adicionarPorte(String rotulo) {
    setState(() {
      // Ao usar portes, a linha "Padrão" vazia deixa de fazer sentido.
      if (_linhas.length == 1 &&
          _linhas.first.rotulo.text == Variacao.rotuloPadrao &&
          _linhas.first.preco.text.trim().isEmpty) {
        _linhas.first.rotulo.text = rotulo;
      } else {
        _linhas.add(_LinhaVariacao(rotulo: rotulo));
      }
    });
  }

  String? _validar() {
    if (_categoria == null) return 'Escolha a categoria.';
    if (_subtipo == null) return 'Escolha o tipo de serviço.';
    final nome = _nome.text.trim();
    if (nome.length < 3 || nome.length > 60) return 'O nome precisa ter entre 3 e 60 letras.';
    if (_descricao.text.trim().length > 500) return 'A descrição passou de 500 caracteres.';
    final rotulos = <String>{};
    for (final l in _linhas) {
      final r = l.rotulo.text.trim();
      if (r.isEmpty) return 'Dê um nome para cada faixa de preço.';
      if (!rotulos.add(normalizar(r))) return 'Há duas faixas com o mesmo nome: "$r".';
      if (l.preco.text.trim().isNotEmpty) {
        final p = lerPreco(l.preco.text);
        if (p == null || p < 0 || p > 100000) return 'Preço inválido em "$r".';
      }
      if (l.duracao.text.trim().isNotEmpty) {
        final d = int.tryParse(l.duracao.text.trim());
        if (d == null || d <= 0 || d > 1440) return 'Duração inválida em "$r" (em minutos).';
      }
    }
    return null;
  }

  Future<void> _salvar() async {
    final problema = _validar();
    setState(() => _erro = problema);
    if (problema != null) return;
    setState(() => _salvando = true);
    try {
      await const ServicosRepo().salvar(
        id: widget.servico?.id,
        nome: _nome.text,
        categoria: _categoria!,
        subtipo: _subtipo,
        descricao: _descricao.text,
        variacoes: [
          for (final l in _linhas)
            Variacao(
              rotulo: l.rotulo.text.trim(),
              preco: lerPreco(l.preco.text),
              duracaoMinutos: int.tryParse(l.duracao.text.trim()),
            ),
        ],
        bairros: widget.perfil.bairros,
        atendeTodaCidade: widget.perfil.atendeTodaCidade,
        ativo: _ativo,
      );
      if (!mounted) return;
      mostrarAviso(_novo ? 'Serviço publicado na vitrine.' : 'Serviço atualizado.');
      Navigator.of(context).pop();
    } catch (e) {
      debugPrint('salvar servico: $e');
      setState(() => _erro = '$e'.contains('permission-denied')
          ? 'O banco recusou. Confira se seu perfil profissional está completo e se as regras foram publicadas.'
          : 'Não foi possível salvar. Verifique a conexão e tente de novo.');
    } finally {
      if (mounted) setState(() => _salvando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final cat = _categoria;
    final portesLivres = (cat?.portes ?? const <String>[])
        .where((p) => !_linhas.any((l) => normalizar(l.rotulo.text.trim()) == normalizar(p)))
        .toList();

    return Scaffold(
      appBar: AppBar(title: Text(_novo ? 'Novo serviço' : 'Editar serviço')),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 640),
          child: ListView(
            padding: const EdgeInsets.fromLTRB(24, 8, 24, 32),
            children: [
              // Categoria
              if (_categorias.length > 1) ...[
                Text('Categoria', style: t.labelLarge),
                const SizedBox(height: 8),
                Wrap(spacing: 8, runSpacing: 8, children: [
                  for (final c in _categorias)
                    ChoiceChip(
                      avatar: Icon(c.icone, size: 18, color: c.cor),
                      label: Text(c.rotulo),
                      selected: _categoria?.id == c.id,
                      onSelected: (_) => setState(() {
                        _categoria = c;
                        _subtipo = null;
                        _erro = null;
                      }),
                    ),
                ]),
                const SizedBox(height: 20),
              ],
              if (cat != null) ...[
                Text('Tipo de serviço', style: t.labelLarge),
                const SizedBox(height: 8),
                Wrap(spacing: 8, runSpacing: 8, children: [
                  for (final s in _subtiposDisponiveis)
                    ChoiceChip(
                      label: Text(s.rotulo),
                      selected: _subtipo == s.id,
                      onSelected: (_) => _escolherSubtipo(s),
                    ),
                ]),
                const SizedBox(height: 20),
              ],
              CampoTexto(
                rotulo: 'Nome do serviço',
                controller: _nome,
                dica: 'Ex.: Corte + barba',
                capitalizacao: TextCapitalization.sentences,
              ),
              const SizedBox(height: 20),
              Text('Descrição (opcional)', style: t.labelLarge),
              const SizedBox(height: 8),
              TextField(
                controller: _descricao,
                maxLines: 4,
                minLines: 2,
                maxLength: 500,
                textCapitalization: TextCapitalization.sentences,
                decoration: const InputDecoration(
                  hintText: 'O que está incluso, material que você leva, observações…',
                ),
              ),
              const SizedBox(height: 12),

              // Preço e duração
              Text('Preço "a partir de" e duração', style: t.titleSmall),
              const SizedBox(height: 4),
              Text('Deixe o preço vazio para "sob consulta". O valor final você combina com o cliente.',
                  style: t.bodySmall?.copyWith(color: HomefyColors.textSecondary, height: 1.4)),
              const SizedBox(height: 12),
              for (var i = 0; i < _linhas.length; i++)
                _CartaoVariacao(
                  linha: _linhas[i],
                  podeRemover: _linhas.length > 1,
                  aoRemover: () => setState(() => _linhas.removeAt(i).dispose()),
                  aoMudar: () => setState(() => _erro = null),
                ),
              if (_linhas.length < _maxVariacoes) ...[
                if (portesLivres.isNotEmpty) ...[
                  Text('Preço muda conforme o porte? Adicione faixas:',
                      style: t.bodySmall?.copyWith(color: HomefyColors.textSecondary)),
                  const SizedBox(height: 8),
                ],
                Wrap(spacing: 8, runSpacing: 8, children: [
                  for (final p in portesLivres)
                    ActionChip(
                      avatar: const Icon(Icons.add_rounded, size: 18),
                      label: Text(p),
                      onPressed: () => _adicionarPorte(p),
                    ),
                  ActionChip(
                    avatar: const Icon(Icons.add_rounded, size: 18),
                    label: const Text('Outra faixa'),
                    onPressed: () => setState(() => _linhas.add(_LinhaVariacao(rotulo: ''))),
                  ),
                ]),
              ],

              if (!_novo) ...[
                const SizedBox(height: 20),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  value: _ativo,
                  onChanged: (v) => setState(() => _ativo = v),
                  title: const Text('Aparece na vitrine'),
                  subtitle: Text(_ativo ? 'Clientes podem ver este serviço' : 'Escondido dos clientes'),
                ),
              ],

              const SizedBox(height: 24),
              if (_erro != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Row(children: [
                    const Icon(Icons.error_outline_rounded, color: HomefyColors.error, size: 20),
                    const SizedBox(width: 8),
                    Expanded(child: Text(_erro!, style: t.bodySmall?.copyWith(color: HomefyColors.error))),
                  ]),
                ),
              BotaoPrimario(
                texto: _novo ? 'Publicar serviço' : 'Salvar',
                icone: Icons.check_rounded,
                carregando: _salvando,
                aoTocar: _salvar,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CartaoVariacao extends StatelessWidget {
  const _CartaoVariacao({
    required this.linha,
    required this.podeRemover,
    required this.aoRemover,
    required this.aoMudar,
  });

  final _LinhaVariacao linha;
  final bool podeRemover;
  final VoidCallback aoRemover;
  final VoidCallback aoMudar;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.fromLTRB(12, 12, 4, 12),
      decoration: BoxDecoration(
        color: HomefyColors.surface,
        borderRadius: BorderRadius.circular(HomefySpace.radiusMd),
        border: Border.all(color: HomefyColors.border),
      ),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Expanded(
          child: Column(children: [
            TextField(
              controller: linha.rotulo,
              onChanged: (_) => aoMudar(),
              decoration: const InputDecoration(labelText: 'Faixa', hintText: 'Ex.: Padrão, Carro médio'),
            ),
            const SizedBox(height: 8),
            Row(children: [
              Expanded(
                child: TextField(
                  controller: linha.preco,
                  onChanged: (_) => aoMudar(),
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]'))],
                  decoration: const InputDecoration(
                    labelText: 'A partir de',
                    prefixText: 'R\$ ',
                    hintText: 'sob consulta',
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: TextField(
                  controller: linha.duracao,
                  onChanged: (_) => aoMudar(),
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  decoration: const InputDecoration(labelText: 'Duração', suffixText: 'min'),
                ),
              ),
            ]),
          ]),
        ),
        if (podeRemover)
          IconButton(
            tooltip: 'Remover faixa',
            icon: const Icon(Icons.close_rounded),
            onPressed: aoRemover,
          ),
      ]),
    );
  }
}
