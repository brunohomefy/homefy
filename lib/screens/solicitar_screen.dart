import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../config.dart';
import '../models/bairros.dart';
import '../models/perfil.dart';
import '../models/servico.dart';
import '../models/solicitacao.dart';
import '../services/perfil_repo.dart';
import '../services/servicos_repo.dart';
import '../services/solicitacoes_repo.dart';
import '../theme/homefy_theme.dart';
import '../widgets/formulario.dart';

/// Pedido de atendimento: faixa de preço, dia, período, bairro, WhatsApp e observação.
///
/// O pedido vai como "pendente". O profissional responde com o valor final;
/// só depois da confirmação do cliente os WhatsApps são liberados (D3).
class SolicitarScreen extends StatefulWidget {
  const SolicitarScreen({super.key, required this.servico, this.bairroInicial});
  final Servico servico;
  final String? bairroInicial;

  @override
  State<SolicitarScreen> createState() => _SolicitarScreenState();
}

class _SolicitarScreenState extends State<SolicitarScreen> {
  late final List<Variacao> _variacoes = widget.servico.variacoesOuPadrao;
  late Variacao _variacao = _variacoes.first;
  final _dias = proximosDias(DateTime.now());
  DateTime? _dia;
  Periodo? _periodo;
  late String? _bairro = widget.bairroInicial;
  final _whats = TextEditingController();
  final _obs = TextEditingController();

  /// Períodos já confirmados com o profissional no dia escolhido.
  final _ocupados = <Periodo>{};
  bool _verificando = false;
  bool _enviando = false;
  String? _erro;
  String _meuNome = '';
  String _nomeProfissional = '';

  String? get _profUid => widget.servico.profissionalRef?.id ?? (kModoDemo ? 'teste_demo' : null);

  @override
  void initState() {
    super.initState();
    _carregar();
  }

  Future<void> _carregar() async {
    try {
      final perfil = await PerfilRepo.instance.meu().first;
      final whats = await PerfilRepo.instance.meuWhatsapp();
      final ref = widget.servico.profissionalRef;
      final prof = ref == null ? null : await const ServicosRepo().perfilDoProfissional(ref);
      if (!mounted) return;
      setState(() {
        _meuNome = perfil?.nome ?? '';
        _nomeProfissional = prof?.nome ?? (kModoDemo ? 'Diego Santos' : '');
        if (whats != null && _whats.text.isEmpty) _whats.text = formatarWhatsapp(whats);
      });
    } catch (_) {/* segue com campos em branco */}
  }

  @override
  void dispose() {
    _whats.dispose();
    _obs.dispose();
    super.dispose();
  }

  Future<void> _escolherDia(DateTime d) async {
    setState(() {
      _dia = d;
      _erro = null;
      _verificando = true;
      _ocupados.clear();
    });
    final prof = _profUid;
    if (prof == null) return;
    final iso = dataIso(d);
    final livres = await Future.wait(
        Periodo.values.map((p) => SolicitacoesRepo.instance.horarioLivre(prof, iso, p)));
    if (!mounted || _dia != d) return;
    setState(() {
      for (var i = 0; i < Periodo.values.length; i++) {
        if (!livres[i]) _ocupados.add(Periodo.values[i]);
      }
      if (_periodo != null && _ocupados.contains(_periodo)) _periodo = null;
      _verificando = false;
    });
  }

  String? _validar() {
    if (_dia == null) return 'Escolha o dia.';
    if (_periodo == null) return 'Escolha o período.';
    if (_bairro == null) return 'Escolha o bairro do atendimento.';
    if (normalizarWhatsapp(_whats.text) == null) {
      return 'Informe seu WhatsApp com DDD. Ex.: (81) 99999-1234';
    }
    if (_obs.text.trim().length > 500) return 'A observação passou de 500 caracteres.';
    return null;
  }

  Future<void> _enviar() async {
    final problema = _validar();
    setState(() => _erro = problema);
    if (problema != null) return;
    setState(() => _enviando = true);
    try {
      await SolicitacoesRepo.instance.criar(
        servico: widget.servico,
        variacao: _variacao,
        data: dataIso(_dia!),
        periodo: _periodo!,
        bairro: _bairro!,
        observacao: _obs.text,
        whatsapp: normalizarWhatsapp(_whats.text)!,
        clienteNome: _meuNome,
        profissionalNome: _nomeProfissional,
      );
      if (!mounted) return;
      mostrarAviso('Pedido enviado! Você recebe o valor final aqui em "Meus pedidos".');
      context.go('/meus-pedidos');
    } on PedidoFalha catch (e) {
      setState(() => _erro = e.mensagem);
    } catch (e) {
      debugPrint('criar pedido: $e');
      setState(() => _erro = 'Não foi possível enviar. Verifique a conexão e tente de novo.');
    } finally {
      if (mounted) setState(() => _enviando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final s = widget.servico;
    final cat = s.categoriaMvp;
    final cor = cat?.cor ?? HomefyColors.primary;
    final foraDaArea = _bairro != null && (s.atendeTodaCidade || s.bairros.isNotEmpty) && !s.atende(_bairro!);

    Widget secao(String titulo, Widget filho, {String? dica}) => Padding(
          padding: const EdgeInsets.only(top: 24),
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Text(titulo, style: t.titleSmall),
            if (dica != null) ...[
              const SizedBox(height: 2),
              Text(dica, style: t.bodySmall?.copyWith(color: HomefyColors.textSecondary)),
            ],
            const SizedBox(height: 10),
            filho,
          ]),
        );

    return Scaffold(
      appBar: AppBar(title: const Text('Pedir atendimento')),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 640),
          child: ListView(
            padding: const EdgeInsets.fromLTRB(24, 8, 24, 32),
            children: [
              // Serviço
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: HomefyColors.surface,
                  borderRadius: BorderRadius.circular(HomefySpace.radiusMd),
                  border: Border.all(color: HomefyColors.border),
                ),
                child: Row(children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: cor.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(HomefySpace.radiusSm),
                    ),
                    child: Icon(cat?.icone ?? Icons.handyman_outlined, color: cor),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(s.nome, style: t.titleMedium),
                      if (_nomeProfissional.isNotEmpty)
                        Text('com $_nomeProfissional', style: t.bodySmall),
                    ]),
                  ),
                ]),
              ),

              if (_variacoes.length > 1)
                secao(
                  'Qual opção?',
                  Wrap(spacing: 8, runSpacing: 8, children: [
                    for (final v in _variacoes)
                      ChoiceChip(
                        label: Text(v.preco == null
                            ? '${v.rotulo} · sob consulta'
                            : '${v.rotulo} · ${Servico.formatarPreco(v.preco)}'),
                        selected: identical(v, _variacao),
                        onSelected: (_) => setState(() => _variacao = v),
                      ),
                  ]),
                ),

              secao(
                'Qual dia?',
                SizedBox(
                  height: 72,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: _dias.length,
                    separatorBuilder: (_, __) => const SizedBox(width: 8),
                    itemBuilder: (_, i) => _ChipDia(
                      dia: _dias[i],
                      selecionado: _dia == _dias[i],
                      aoTocar: () => _escolherDia(_dias[i]),
                    ),
                  ),
                ),
                dica: 'A partir de amanhã, para dar tempo de o profissional responder.',
              ),

              secao(
                'Qual período?',
                _dia == null
                    ? Text('Escolha o dia primeiro.', style: t.bodySmall)
                    : Row(children: [
                        for (final p in Periodo.values) ...[
                          Expanded(
                            child: _CartaoPeriodo(
                              periodo: p,
                              selecionado: _periodo == p,
                              ocupado: _ocupados.contains(p),
                              carregando: _verificando,
                              aoTocar: () => setState(() {
                                _periodo = p;
                                _erro = null;
                              }),
                            ),
                          ),
                          if (p != Periodo.values.last) const SizedBox(width: 8),
                        ],
                      ]),
                dica: 'O horário exato vocês combinam no WhatsApp depois de confirmar.',
              ),

              secao(
                'Em qual bairro?',
                DropdownButtonFormField<String>(
                  initialValue: _bairro,
                  isExpanded: true,
                  hint: const Text('Escolha o bairro'),
                  items: [
                    for (final b in Bairro.todos) DropdownMenuItem(value: b.id, child: Text(b.nome)),
                  ],
                  onChanged: (v) => setState(() {
                    _bairro = v;
                    _erro = null;
                  }),
                ),
              ),
              if (foraDaArea)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(
                    'Este profissional não marcou esse bairro como área de atendimento. '
                    'Você pode pedir mesmo assim: ele decide se atende.',
                    style: t.bodySmall?.copyWith(color: HomefyColors.warning.withValues(alpha: 1)),
                  ),
                ),

              secao(
                'Seu WhatsApp',
                CampoTexto(
                  rotulo: 'WhatsApp',
                  controller: _whats,
                  dica: '(81) 99999-1234',
                  icone: Icons.phone_iphone_rounded,
                  teclado: TextInputType.phone,
                  autofill: const [AutofillHints.telephoneNumber],
                ),
                dica: 'O profissional só vê seu número depois que você confirmar o valor.',
              ),

              secao(
                'Observação (opcional)',
                TextField(
                  controller: _obs,
                  minLines: 2,
                  maxLines: 4,
                  maxLength: 500,
                  textCapitalization: TextCapitalization.sentences,
                  decoration: const InputDecoration(
                    hintText: 'Ex.: apartamento no 3º andar, cabelo bem comprido, tem torneira na garagem…',
                  ),
                ),
                dica: 'Não coloque o endereço completo: ele é combinado no WhatsApp depois de confirmar.',
              ),

              const SizedBox(height: 16),
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
                texto: 'Enviar pedido',
                icone: Icons.send_rounded,
                carregando: _enviando,
                aoTocar: _enviar,
              ),
              const SizedBox(height: 8),
              Text('Você ainda não paga nada. O profissional responde com o valor final e você decide se confirma.',
                  textAlign: TextAlign.center,
                  style: t.bodySmall?.copyWith(color: HomefyColors.textMuted)),
            ],
          ),
        ),
      ),
    );
  }
}

class _ChipDia extends StatelessWidget {
  const _ChipDia({required this.dia, required this.selecionado, required this.aoTocar});
  final DateTime dia;
  final bool selecionado;
  final VoidCallback aoTocar;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final partes = dataCurta(dataIso(dia)).split(', '); // ['sáb', '10 out']
    final cor = selecionado ? Colors.white : HomefyColors.text;
    return Material(
      color: selecionado ? HomefyColors.primary : HomefyColors.surface,
      borderRadius: BorderRadius.circular(HomefySpace.radiusMd),
      child: InkWell(
        borderRadius: BorderRadius.circular(HomefySpace.radiusMd),
        onTap: aoTocar,
        child: Container(
          width: 64,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(HomefySpace.radiusMd),
            border: Border.all(color: selecionado ? HomefyColors.primary : HomefyColors.border),
          ),
          child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
            Text(partes.first, style: t.labelMedium?.copyWith(color: cor.withValues(alpha: 0.8))),
            Text(partes.last.split(' ').first, style: t.titleMedium?.copyWith(color: cor)),
            Text(partes.last.split(' ').last, style: t.labelSmall?.copyWith(color: cor.withValues(alpha: 0.8))),
          ]),
        ),
      ),
    );
  }
}

class _CartaoPeriodo extends StatelessWidget {
  const _CartaoPeriodo({
    required this.periodo,
    required this.selecionado,
    required this.ocupado,
    required this.carregando,
    required this.aoTocar,
  });
  final Periodo periodo;
  final bool selecionado;
  final bool ocupado;
  final bool carregando;
  final VoidCallback aoTocar;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final ativo = !ocupado && !carregando;
    final cor = selecionado ? Colors.white : (ativo ? HomefyColors.text : HomefyColors.textMuted);
    return Material(
      color: selecionado ? HomefyColors.primary : HomefyColors.surface,
      borderRadius: BorderRadius.circular(HomefySpace.radiusMd),
      child: InkWell(
        borderRadius: BorderRadius.circular(HomefySpace.radiusMd),
        onTap: ativo ? aoTocar : null,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(HomefySpace.radiusMd),
            border: Border.all(color: selecionado ? HomefyColors.primary : HomefyColors.border),
          ),
          child: Column(children: [
            Icon(periodo.icone, color: cor, size: 22),
            const SizedBox(height: 4),
            Text(periodo.rotulo, style: t.titleSmall?.copyWith(color: cor)),
            Text(ocupado ? 'Ocupado' : periodo.faixa,
                style: t.labelSmall?.copyWith(color: cor.withValues(alpha: 0.8))),
          ]),
        ),
      ),
    );
  }
}
