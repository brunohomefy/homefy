import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';

import '../models/servico.dart';
import '../models/solicitacao.dart';
import '../services/solicitacoes_repo.dart';
import '../theme/homefy_theme.dart';
import '../widgets/formulario.dart';
import '../widgets/pedido_card.dart';
import 'servico_editor_screen.dart' show lerPreco;

/// Lista de pedidos. [souCliente] = "Meus pedidos"; senão "Pedidos recebidos".
class PedidosScreen extends StatelessWidget {
  const PedidosScreen({super.key, required this.souCliente});
  final bool souCliente;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final repo = SolicitacoesRepo.instance;
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          tooltip: 'Voltar',
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => context.canPop() ? context.pop() : context.go('/home'),
        ),
        title: Text(souCliente ? 'Meus pedidos' : 'Pedidos recebidos'),
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 640),
          child: StreamBuilder<List<Solicitacao>>(
            stream: souCliente ? repo.comoCliente() : repo.comoProfissional(),
            builder: (context, snap) {
              if (snap.hasError) {
                debugPrint('pedidos: ${snap.error}');
                return _Mensagem(
                  icone: Icons.cloud_off_rounded,
                  titulo: 'Não foi possível carregar',
                  texto: '${snap.error}'.contains('permission-denied')
                      ? 'O banco recusou a leitura. Confira se as regras novas foram publicadas.'
                      : 'Verifique sua conexão e tente de novo.',
                );
              }
              if (!snap.hasData) return const Center(child: CircularProgressIndicator());
              final lista = snap.data!;
              if (lista.isEmpty) {
                return _Mensagem(
                  icone: souCliente ? Icons.receipt_long_outlined : Icons.inbox_outlined,
                  titulo: souCliente ? 'Você ainda não fez pedidos' : 'Nenhum pedido ainda',
                  texto: souCliente
                      ? 'Escolha um serviço na tela inicial e toque em "Pedir atendimento".'
                      : 'Quando um cliente pedir um dos seus serviços, ele aparece aqui.',
                  acao: souCliente
                      ? FilledButton(onPressed: () => context.go('/home'), child: const Text('Ver serviços'))
                      : null,
                );
              }
              final abertos = lista.where((s) => !s.status.encerrado).length;
              return ListView(
                padding: const EdgeInsets.fromLTRB(24, 8, 24, 32),
                children: [
                  if (abertos > 0)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Text('$abertos em andamento',
                          style: t.labelLarge?.copyWith(color: HomefyColors.textSecondary)),
                    ),
                  for (final s in lista)
                    PedidoCard(
                      pedido: s,
                      souCliente: souCliente,
                      aoTocar: () => showModalBottomSheet<void>(
                        context: context,
                        isScrollControlled: true,
                        builder: (_) => DetalhePedido(pedidoId: s.id, souCliente: souCliente),
                      ),
                    ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

/// Detalhe do pedido com as ações do momento. Acompanha mudanças em tempo real.
class DetalhePedido extends StatelessWidget {
  const DetalhePedido({super.key, required this.pedidoId, required this.souCliente});
  final String pedidoId;
  final bool souCliente;

  @override
  Widget build(BuildContext context) {
    final repo = SolicitacoesRepo.instance;
    return StreamBuilder<List<Solicitacao>>(
      stream: souCliente ? repo.comoCliente() : repo.comoProfissional(),
      builder: (context, snap) {
        final s = snap.data?.where((x) => x.id == pedidoId).firstOrNull;
        if (s == null) {
          return const SizedBox(height: 200, child: Center(child: CircularProgressIndicator()));
        }
        return _ConteudoDetalhe(pedido: s, souCliente: souCliente);
      },
    );
  }
}

class _ConteudoDetalhe extends StatefulWidget {
  const _ConteudoDetalhe({required this.pedido, required this.souCliente});
  final Solicitacao pedido;
  final bool souCliente;

  @override
  State<_ConteudoDetalhe> createState() => _ConteudoDetalheState();
}

class _ConteudoDetalheState extends State<_ConteudoDetalhe> {
  late final _valor = TextEditingController(
    text: widget.pedido.precoReferencia == null ? '' : _precoTexto(widget.pedido.precoReferencia!),
  );
  final _mensagem = TextEditingController();
  bool _ocupado = false;
  String? _erro;

  static String _precoTexto(double v) =>
      v == v.roundToDouble() ? v.toStringAsFixed(0) : v.toStringAsFixed(2).replaceAll('.', ',');

  @override
  void dispose() {
    _valor.dispose();
    _mensagem.dispose();
    super.dispose();
  }

  Solicitacao get s => widget.pedido;
  SolicitacoesRepo get repo => SolicitacoesRepo.instance;

  Future<void> _fazer(Future<void> Function() acao, String sucesso, {bool fechar = false}) async {
    setState(() {
      _ocupado = true;
      _erro = null;
    });
    try {
      await acao();
      mostrarAviso(sucesso);
      if (fechar && mounted) Navigator.of(context).pop();
    } on PedidoFalha catch (e) {
      if (mounted) setState(() => _erro = e.mensagem);
    } catch (e) {
      debugPrint('acao pedido: $e');
      if (mounted) setState(() => _erro = 'Algo deu errado. Tente de novo.');
    } finally {
      if (mounted) setState(() => _ocupado = false);
    }
  }

  String get _msgWhatsapp => widget.souCliente
      ? 'Olá${s.profissionalNome.isEmpty ? '' : ', ${s.profissionalNome.split(' ').first}'}! '
          'Sou ${s.clienteNome.isEmpty ? 'cliente' : s.clienteNome} do Homefy. Confirmei ${s.servicoNome} '
          'para ${dataCurta(s.data)}, ${s.periodo.rotulo.toLowerCase()}. Vamos combinar o horário e o endereço?'
      : 'Olá${s.clienteNome.isEmpty ? '' : ', ${s.clienteNome.split(' ').first}'}! '
          'Aqui é ${s.profissionalNome.isEmpty ? 'o profissional' : s.profissionalNome} do Homefy, sobre '
          '${s.servicoNome} em ${dataCurta(s.data)}, ${s.periodo.rotulo.toLowerCase()}. Pode me passar o endereço?';

  Future<void> _whatsapp() async {
    setState(() => _ocupado = true);
    final numero = widget.souCliente
        ? await repo.whatsappDoProfissional(s.profissionalUid)
        : await repo.whatsappDoCliente(s.id);
    if (mounted) setState(() => _ocupado = false);
    await abrirWhatsapp(numero, _msgWhatsapp);
  }

  Future<void> _cancelar() async {
    final confirmado = s.status == StatusPedido.confirmada;
    final ok = await confirmarAcao(
      context,
      titulo: confirmado ? 'Cancelar atendimento?' : 'Cancelar pedido?',
      texto: confirmado
          ? 'O horário fica livre de novo e o WhatsApp deixa de ser compartilhado. '
              'Avise a outra pessoa pelo WhatsApp antes, se puder.'
          : 'O pedido será encerrado.',
      botao: 'Cancelar',
      perigo: true,
    );
    if (!ok) return;
    await _fazer(() => repo.cancelar(s, souCliente: widget.souCliente), 'Cancelado.');
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final outro = widget.souCliente ? s.profissionalNome : s.clienteNome;
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 0, 24, 16),
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, mainAxisSize: MainAxisSize.min, children: [
            Text(s.servicoNome, style: t.titleLarge),
            if (outro.isNotEmpty)
              Text(widget.souCliente ? 'com $outro' : 'pedido de $outro', style: t.bodyMedium),
            const SizedBox(height: 10),
            Align(
              alignment: Alignment.centerLeft,
              child: EtiquetaStatus(status: s.status, souCliente: widget.souCliente),
            ),
            const SizedBox(height: 16),
            ResumoPedido(pedido: s),
            if (s.valorFinal != null) _CaixaValor(pedido: s),
            const SizedBox(height: 8),
            ..._acoes(t),
            if (_erro != null) ...[
              const SizedBox(height: 12),
              Text(_erro!, style: t.bodySmall?.copyWith(color: HomefyColors.error)),
            ],
          ]),
        ),
      ),
    );
  }

  List<Widget> _acoes(TextTheme t) {
    final cliente = widget.souCliente;
    final espaco = const SizedBox(height: 10);
    switch (s.status) {
      case StatusPedido.pendente:
        if (cliente) {
          return [
            Text('O profissional vai responder com o valor final. Você é avisado aqui.',
                style: t.bodySmall?.copyWith(color: HomefyColors.textSecondary)),
            espaco,
            OutlinedButton(onPressed: _ocupado ? null : _cancelar, child: const Text('Cancelar pedido')),
          ];
        }
        return [
          const SizedBox(height: 8),
          Text('Responda com o valor final', style: t.titleSmall),
          espaco,
          TextField(
            controller: _valor,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]'))],
            decoration: const InputDecoration(labelText: 'Valor final', prefixText: 'R\$ '),
          ),
          espaco,
          TextField(
            controller: _mensagem,
            maxLength: 500,
            minLines: 1,
            maxLines: 3,
            textCapitalization: TextCapitalization.sentences,
            decoration: const InputDecoration(
              labelText: 'Mensagem (opcional)',
              hintText: 'Ex.: inclui produtos. Chego por volta das 14h.',
            ),
          ),
          BotaoPrimario(
            texto: 'Enviar valor',
            icone: Icons.send_rounded,
            carregando: _ocupado,
            aoTocar: () {
              final v = lerPreco(_valor.text);
              if (v == null || v <= 0 || v > 100000) {
                setState(() => _erro = 'Informe um valor válido.');
                return;
              }
              _fazer(() => repo.enviarProposta(s.id, v, _mensagem.text),
                  'Valor enviado. Agora é com o cliente.');
            },
          ),
          espaco,
          TextButton(
            onPressed: _ocupado
                ? null
                : () async {
                    final ok = await confirmarAcao(context,
                        titulo: 'Recusar pedido?',
                        texto: 'O cliente verá que você não pode atender. A mensagem acima vai junto.',
                        botao: 'Recusar',
                        perigo: true);
                    if (ok) await _fazer(() => repo.recusar(s.id, _mensagem.text), 'Pedido recusado.');
                  },
            child: const Text('Não posso atender'),
          ),
        ];
      case StatusPedido.proposta:
        if (cliente) {
          return [
            BotaoPrimario(
              texto: 'Confirmar por ${Servico.formatarPreco(s.valorFinal)}',
              icone: Icons.check_rounded,
              carregando: _ocupado,
              aoTocar: () => _fazer(() => repo.confirmar(s),
                  'Confirmado! Agora vocês podem conversar no WhatsApp.'),
            ),
            espaco,
            OutlinedButton(onPressed: _ocupado ? null : _cancelar, child: const Text('Não quero')),
            espaco,
            Text('Ao confirmar, seu WhatsApp e o do profissional ficam visíveis um para o outro.',
                style: t.bodySmall?.copyWith(color: HomefyColors.textMuted)),
          ];
        }
        return [
          Text('Você enviou o valor. Aguarde o cliente confirmar.',
              style: t.bodySmall?.copyWith(color: HomefyColors.textSecondary)),
        ];
      case StatusPedido.confirmada:
        final hoje = DateTime.now();
        final chegouODia = !DateTime.parse(s.data).isAfter(DateTime(hoje.year, hoje.month, hoje.day));
        return [
          FilledButton.icon(
            style: FilledButton.styleFrom(backgroundColor: const Color(0xFF25D366)),
            onPressed: _ocupado ? null : _whatsapp,
            icon: const Icon(Icons.chat_rounded),
            label: Text(cliente ? 'Chamar o profissional no WhatsApp' : 'Chamar o cliente no WhatsApp'),
          ),
          if (!cliente && chegouODia) ...[
            espaco,
            OutlinedButton.icon(
              onPressed: _ocupado
                  ? null
                  : () => _fazer(() => repo.concluir(s.id), 'Atendimento concluído. Bom trabalho!'),
              icon: const Icon(Icons.task_alt_rounded),
              label: const Text('Marcar como concluído'),
            ),
          ],
          espaco,
          TextButton(
            onPressed: _ocupado ? null : _cancelar,
            style: TextButton.styleFrom(foregroundColor: HomefyColors.error),
            child: const Text('Cancelar atendimento'),
          ),
        ];
      case StatusPedido.recusada:
        return [
          if (cliente)
            FilledButton(
              onPressed: () {
                Navigator.of(context).pop();
                context.go('/home');
              },
              child: const Text('Procurar outro profissional'),
            ),
        ];
      case StatusPedido.cancelada:
        return [
          Text(
            s.canceladoPor == null
                ? 'Pedido cancelado.'
                : 'Cancelado pelo ${s.canceladoPor == 'cliente' ? 'cliente' : 'profissional'}.',
            style: t.bodySmall?.copyWith(color: HomefyColors.textSecondary),
          ),
        ];
      case StatusPedido.concluida:
        return [
          Text('Atendimento concluído. Em breve: avaliar o atendimento.',
              style: t.bodySmall?.copyWith(color: HomefyColors.textSecondary)),
        ];
    }
  }
}

class _CaixaValor extends StatelessWidget {
  const _CaixaValor({required this.pedido});
  final Solicitacao pedido;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return Container(
      margin: const EdgeInsets.only(top: 8, bottom: 8),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: HomefyColors.mint,
        borderRadius: BorderRadius.circular(HomefySpace.radiusMd),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('Valor final', style: t.labelLarge?.copyWith(color: HomefyColors.primaryDark)),
        Text(Servico.formatarPreco(pedido.valorFinal)!,
            style: t.headlineSmall?.copyWith(color: HomefyColors.primaryDark)),
        if (pedido.mensagemProfissional.isNotEmpty) ...[
          const SizedBox(height: 6),
          Text('"${pedido.mensagemProfissional}"',
              style: t.bodyMedium?.copyWith(color: HomefyColors.primaryDark, fontStyle: FontStyle.italic)),
        ],
        const SizedBox(height: 6),
        Text('Pagamento combinado direto com o profissional.',
            style: t.bodySmall?.copyWith(color: HomefyColors.primaryDark)),
      ]),
    );
  }
}

class _Mensagem extends StatelessWidget {
  const _Mensagem({required this.icone, required this.titulo, required this.texto, this.acao});
  final IconData icone;
  final String titulo;
  final String texto;
  final Widget? acao;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Icon(icone, size: 48, color: HomefyColors.primary),
          const SizedBox(height: 12),
          Text(titulo, style: t.titleMedium, textAlign: TextAlign.center),
          const SizedBox(height: 6),
          Text(texto, style: t.bodySmall, textAlign: TextAlign.center),
          if (acao != null) ...[const SizedBox(height: 16), acao!],
        ]),
      ),
    );
  }
}
