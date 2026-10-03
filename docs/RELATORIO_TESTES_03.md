# HOMEFY: RELATÓRIO DE TESTES 03 (03/10/2026)

**Camada:** solicitação de atendimento (pedido → valor final → confirmação → WhatsApp).
**Feita sem o Bruno presente**, a pedido dele ("adiante tudo o que puder").
O escopo seguiu as decisões já fechadas (D2, D3, dossiê 65.5). Pontos para ele revisar: seção 6.

---

## 1. Como funciona

```
Cliente: escolhe serviço → "Pedir atendimento"
         (faixa de preço, dia, período, bairro, WhatsApp, observação)
            ↓  status: pendente
Profissional: "Pedidos recebidos" → envia o VALOR FINAL (ou "Não posso atender")
            ↓  status: proposta (ou recusada)
Cliente: "Meus pedidos" → "Confirmar por R$ X" (ou "Não quero")
            ↓  status: confirmada
  • o horário do profissional (dia + período) fica travado
  • o WhatsApp de cada um fica visível para o outro (botão abre o wa.me com mensagem pronta)
            ↓
Profissional: no dia (ou depois) → "Marcar como concluído"
Qualquer um pode cancelar antes; cancelar um confirmado destrava o horário e esconde os WhatsApps de novo.
```

- **Dia:** os próximos 14 dias, a partir de amanhã.
- **Período:** manhã, tarde ou noite. A hora exata é combinada no WhatsApp.
- **Endereço completo NÃO fica no banco** (LGPD). Só o bairro. O endereço é combinado no WhatsApp depois de confirmar.
- **Pagamento:** combinado direto com o profissional. O app não cobra nada.
- **Na Home:** aparece uma faixa "1 pedido com valor para você confirmar" ou "1 pedido novo para responder".
- **No menu do perfil:** "Meus pedidos" e, para profissionais, "Pedidos recebidos".

## 2. Como foi garantido sem servidor (plano grátis)

Tudo roda no app. As **regras do Firestore** impõem a ordem das etapas:
- Só o profissional envia valor ou recusa.
- Só o cliente confirma.
- Só o profissional conclui.
- Ninguém pula etapa.
- Ninguém apaga pedido.

**Mesmo horário confirmado duas vezes é impossível.** Ao confirmar, o app cria o documento `agenda/{profissional}_{dia}_{período}` no mesmo lote da confirmação. Se esse documento já existir, o banco recusa o lote inteiro e o cliente vê: "Esse horário acabou de ser confirmado por outra pessoa".

**WhatsApp (D3):**
- O do profissional fica em `usuarios/{uid}/privado/contato`. Só é lido por quem tem `usuarios/{uid}/liberados/{cliente}`, documento criado no lote da confirmação e apagado no cancelamento.
- O do cliente fica em `solicitacoes/{id}/privado/cliente`. O profissional só lê depois de confirmado.

## 3. Testes automáticos

| Conjunto | Resultado |
|---|---|
| Regras do Firestore (emulador) | **41 de 41** (23 antigos + 18 novos) |
| App (Dart) | **20 de 20** (15 antigos + 5 novos) |
| Análise de código | sem erros |

Os testes novos de regras cobrem:
- pedido em nome de outro;
- pedido para serviço desativado ou de outro profissional;
- pedido para si mesmo;
- campo "endereço" recusado;
- terceiros não leem o pedido;
- cliente não envia valor e profissional não confirma;
- confirmar sem travar a agenda;
- **mesmo horário duas vezes**;
- WhatsApp do cliente escondido antes da confirmação;
- WhatsApp do profissional liberado só após confirmar e escondido de novo ao cancelar;
- mentir quem cancelou;
- cancelar sem destravar o horário;
- mexer na agenda à mão.

## 4. Auditoria visual (demonstração, celular 390×844)

| Tela | Resultado |
|---|---|
| Pedir atendimento: faixas, dias, períodos, bairro, WhatsApp, observação | ✅ |
| Erro ao enviar sem escolher o dia | ✅ "Escolha o dia." |
| Meus pedidos: pedido com valor para confirmar (destacado) | ✅ |
| Detalhe com valor final, mensagem do profissional, "Confirmar por R$ 75,00" | ✅ |
| Depois de confirmar: botão verde "Chamar o profissional no WhatsApp" | ✅ |
| Pedidos recebidos: pedido novo (destacado) | ✅ |
| Responder com valor final (já vem com o preço de referência) | ✅ |
| Depois de responder: "Aguardando o cliente" | ✅ |
| Faixa de aviso na Home | ✅ |

**Achado corrigido:** as etiquetas de situação quebravam em duas linhas. Viraram textos curtos ("Confirme o valor", "Responda o pedido", "Aguardando o cliente").

## 5. Custos

**Zero.** Sem Cloud Functions, sem SMS, sem API do WhatsApp (só o link `wa.me`).
- **Leituras a mais:** a Home escuta os pedidos do usuário (até 50) e o perfil.
- **Pedir:** 3 leituras para saber se os períodos do dia estão livres.
- Continua muito abaixo das 50 mil leituras/dia do plano grátis.

## 6. Pontos para o Bruno decidir ou revisar

1. **Período (manhã/tarde/noite) em vez de hora marcada.** Mais simples para os dois lados, e a hora fina é combinada no WhatsApp. Se preferir horários de 1 em 1 hora, a mudança é pequena.
2. **14 dias de antecedência no máximo, mínimo amanhã.** Pedido para hoje ficou de fora, para dar tempo de o profissional responder.
3. **Sem notificação fora do app.** O profissional só vê pedido novo quando abre o app (aviso na Home). Notificação push de verdade exige Cloud Functions (plano Blaze). Alternativa grátis futura: e-mail pelo Firebase Extensions também exige Blaze. **Este é o maior limite do plano grátis.** Por ora, o profissional precisa abrir o app.
4. **Pedido fora da área do profissional é permitido**, com aviso; o profissional decide se atende.
5. **Ainda não existe:** avaliação depois do atendimento (próxima camada natural) e histórico de quantos atendimentos cada profissional fez.

## 7. Teste manual (Bruno, no app real)

Pré-requisito: publicar o `firestore.rules` novo, que já inclui tudo da camada anterior.
Precisa de **duas contas**: uma profissional (a sua) e uma cliente (crie outra com outro e-mail).

1. Na conta cliente, escolha um serviço seu → "Pedir atendimento" → envie.
2. Na conta profissional: faixa azul na Home → responda com um valor.
3. Na conta cliente: faixa "valor para confirmar" → Confirmar.
4. Os dois lados: botão "Chamar no WhatsApp" abre a conversa certa, com mensagem pronta.
5. Com uma terceira conta (ou a cliente de novo), peça o **mesmo dia e período**. O período deve aparecer **"Ocupado"**.
6. Cancele o confirmado e veja o período voltar a ficar livre.
7. No console, confira que `solicitacoes` não tem endereço nem WhatsApp no documento principal.
