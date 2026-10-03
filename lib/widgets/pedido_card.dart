import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/bairros.dart';
import '../models/categoria.dart';
import '../models/servico.dart';
import '../models/solicitacao.dart';
import '../theme/homefy_theme.dart';
import 'formulario.dart';

/// Etiqueta colorida com a situação do pedido.
class EtiquetaStatus extends StatelessWidget {
  const EtiquetaStatus({super.key, required this.status, required this.souCliente});
  final StatusPedido status;
  final bool souCliente;

  @override
  Widget build(BuildContext context) {
    final texto = souCliente ? status.rotuloCliente : status.rotuloProfissional;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: status.cor.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(99),
      ),
      child: Text(texto,
          style: Theme.of(context)
              .textTheme
              .labelMedium
              ?.copyWith(color: status.cor, fontWeight: FontWeight.w700)),
    );
  }
}

/// Cartão de um pedido na lista (do cliente ou do profissional).
class PedidoCard extends StatelessWidget {
  const PedidoCard({super.key, required this.pedido, required this.souCliente, required this.aoTocar});
  final Solicitacao pedido;
  final bool souCliente;
  final VoidCallback aoTocar;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final s = pedido;
    final cat = Categoria.porId(s.categoriaId);
    final cor = cat?.cor ?? HomefyColors.primary;
    final outro = souCliente
        ? (s.profissionalNome.isEmpty ? 'Profissional' : s.profissionalNome)
        : (s.clienteNome.isEmpty ? 'Cliente' : s.clienteNome);
    final valor = s.valorFinal ?? s.precoReferencia;
    return Opacity(
      opacity: s.status.encerrado ? 0.6 : 1,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: HomefyColors.surface,
          borderRadius: BorderRadius.circular(HomefySpace.radiusMd),
          border: Border.all(
            color: !s.status.encerrado && _pedeAcao ? s.status.cor : HomefyColors.border,
            width: !s.status.encerrado && _pedeAcao ? 1.6 : 1,
          ),
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(HomefySpace.radiusMd),
          onTap: aoTocar,
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
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
                  Text(s.servicoNome, style: t.titleSmall, maxLines: 1, overflow: TextOverflow.ellipsis),
                  const SizedBox(height: 2),
                  Text('$outro · ${dataCurta(s.data)}, ${s.periodo.rotulo.toLowerCase()}',
                      style: t.bodySmall, maxLines: 1, overflow: TextOverflow.ellipsis),
                  const SizedBox(height: 8),
                  EtiquetaStatus(status: s.status, souCliente: souCliente),
                ]),
              ),
              if (valor != null) ...[
                const SizedBox(width: 8),
                Text(Servico.formatarPreco(valor)!,
                    style: t.titleSmall?.copyWith(
                        color: s.valorFinal != null ? HomefyColors.primary : HomefyColors.textMuted)),
              ],
            ]),
          ),
        ),
      ),
    );
  }

  /// Pedido esperando uma ação de quem está vendo.
  bool get _pedeAcao => souCliente
      ? pedido.status == StatusPedido.proposta
      : pedido.status == StatusPedido.pendente;
}

/// Linha "rótulo: valor" do resumo do pedido.
class LinhaInfo extends StatelessWidget {
  const LinhaInfo({super.key, required this.icone, required this.texto});
  final IconData icone;
  final String texto;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Icon(icone, size: 18, color: HomefyColors.textSecondary),
        const SizedBox(width: 8),
        Expanded(child: Text(texto, style: Theme.of(context).textTheme.bodyMedium)),
      ]),
    );
  }
}

/// Resumo comum aos dois lados: serviço, dia, período, bairro, observação.
class ResumoPedido extends StatelessWidget {
  const ResumoPedido({super.key, required this.pedido});
  final Solicitacao pedido;

  @override
  Widget build(BuildContext context) {
    final s = pedido;
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      LinhaInfo(
          icone: Icons.event_outlined,
          texto: '${dataCurta(s.data)}, ${s.periodo.rotulo.toLowerCase()} (${s.periodo.faixa})'),
      LinhaInfo(icone: Icons.place_outlined, texto: '${Bairro.nomeDe(s.bairro)}, Caruaru'),
      if (s.variacao.isNotEmpty && s.variacao != Variacao.rotuloPadrao)
        LinhaInfo(icone: Icons.tune_rounded, texto: s.variacao),
      if (s.precoReferencia != null)
        LinhaInfo(
            icone: Icons.sell_outlined,
            texto: 'Preço de referência: a partir de ${Servico.formatarPreco(s.precoReferencia)}'),
      if (s.observacao.isNotEmpty) LinhaInfo(icone: Icons.notes_rounded, texto: s.observacao),
    ]);
  }
}

/// Abre o WhatsApp com mensagem pronta. Sem custo: é só um link.
Future<void> abrirWhatsapp(String? numero, String mensagem) async {
  if (numero == null) {
    mostrarAviso('Não foi possível ver o WhatsApp agora. Tente de novo em instantes.', erro: true);
    return;
  }
  final ok = await launchUrl(linkWhatsapp(numero, mensagem), mode: LaunchMode.externalApplication);
  if (!ok) mostrarAviso('Não foi possível abrir o WhatsApp.', erro: true);
}

/// Pergunta de confirmação para ações que não têm volta.
Future<bool> confirmarAcao(BuildContext context,
    {required String titulo, required String texto, required String botao, bool perigo = false}) async {
  final r = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(titulo),
      content: Text(texto),
      actions: [
        TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('Voltar')),
        FilledButton(
          style: perigo ? FilledButton.styleFrom(backgroundColor: HomefyColors.error) : null,
          onPressed: () => Navigator.of(ctx).pop(true),
          child: Text(botao),
        ),
      ],
    ),
  );
  return r ?? false;
}
