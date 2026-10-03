# Homefy: instruções para o Claude (ler antes de qualquer tarefa)

App de serviços domiciliares (piloto em Caruaru-PE), inspirado em iFood e BlaBlaCar.
Dono: Bruno. Fala português do Brasil, sem jargão. Cliente e profissional usam **a mesma conta**.

## Como o Bruno quer que você trabalhe
- **Confirme o escopo antes de construir** quando houver mais de um caminho. Depois siga direto, sem idas e voltas.
- **Faça uma auditoria a cada parte**: o que mudou, como foi testado e se valeu a pena.
- **Avise ANTES de qualquer coisa que custe dinheiro.** Meta: gasto zero até publicar na Play Store. Se um caminho levar a custo obrigatório mais adiante (beco sem saída), diga isso logo.
- Feedback honesto: se uma ideia for ruim, diga.
- Avise quando a conversa estiver ficando longa ou densa, para ele abrir um chat novo.

## Stack e onde as coisas vivem
- Flutter (web primeiro; Android depois) + Firebase **plano Spark (grátis)**, projeto `homefy-67cdd`.
- Repositório público: github.com/brunohomefy/homefy. Cada push na `main` publica em https://brunohomefy.github.io/homefy/
  - `/demo/` = versão sem Firebase, com dados de exemplo.
- **Fluxo de trabalho:** trabalhar numa branch (ex.: `camada-<nome>`) → o CI roda → só fazer merge na `main` com tudo verde.
- O CI (`.github/workflows/publicar.yml`) faz:
  - `flutter analyze`, `flutter test`;
  - testes das regras no emulador (`tests_regras/`, Node);
  - build web + demo, prints automáticos das telas na branch `auditoria-telas` (`tools/auditoria/telas.mjs`).
- Não é preciso Flutter instalado no PC: o CI compila e testa. Só instale se o Bruno pedir.

## Modelo de dados (Firestore)
- `usuarios/{uid}`: perfil **público** (nome, eh_profissional, categorias, subtipos, bairros, atende_toda_cidade, descricao). **Nunca** e-mail, telefone, CPF ou endereço (LGPD).
- `usuarios/{uid}/privado/contato`: `whatsapp` (`55` + DDD + número). Só o dono lê.
- `servicos/{id}`:
  - nome_servico, categoria (rótulo), categoria_id (`cabelo|manicure|veiculos|limpeza`), subtipo;
  - variacoes `[{rotulo, preco|null, duracao_minutos}]`, preco_base (menor preço);
  - bairros, atende_toda_cidade, ativo, profissional_ref, criado_em, atualizado_em.
  - Não se apaga, só se desativa.
- `feedbacks/{id}`: tipo `nao_achei|experiencia`. Só escrita pelo app.
- `solicitacoes/{id}`: pedido de atendimento. status `pendente → proposta|recusada → confirmada|cancelada → concluida|cancelada`.
  Campos: cliente_uid/nome, profissional_uid/nome, servico_id/nome, categoria_id, variacao, preco_referencia, data (`AAAA-MM-DD`), periodo (`manha|tarde|noite`), bairro, observacao, valor_final, mensagem_profissional, datas de cada etapa. **Sem endereço** (combinado no WhatsApp).
  - `solicitacoes/{id}/privado/cliente`: WhatsApp do cliente; o profissional só lê depois de confirmada.
- `avaliacoes/{solicitacaoId}`: nota (int 1–5), comentario (≤300), cliente_nome (só o primeiro nome), profissional_uid, cliente_uid, servico_nome. Só o cliente cria, só se a solicitação estiver `concluida`; sem edição nem exclusão; leitura para logados. A média é calculada no app.
- Páginas públicas em `paginas/` (copiadas para o site pelo CI): `privacidade.html` e `termos.html`. Links em `lib/config.dart`.
- `agenda/{profissional}_{data}_{periodo}`: trava de horário, criada no mesmo lote da confirmação (impede confirmar o mesmo horário duas vezes).
- `usuarios/{uid}/liberados/{clienteUid}`: libera o WhatsApp do profissional para quem confirmou. Criado na confirmação e apagado no cancelamento.
- Catálogo fixo em código: `lib/models/categoria.dart` (subtipos/portes) e `lib/models/bairros.dart` (45 bairros, revisados pelo Bruno).
- **Toda mudança de dados precisa vir junto com:** `firestore.rules` + testes em `tests_regras/regras.test.js` + testes Dart.

## Decisões fechadas (não reabrir sem o Bruno pedir)
- D1: 4 categorias com subtipos fixos; em vez de "Outros", existe "Não achou? Conte pra gente".
- D2: preço "a partir de" com faixas opcionais; preço vazio = sob consulta. O valor final é combinado com o profissional.
- D3: o WhatsApp do profissional só é liberado ao cliente depois de um pedido aceito. Usar link `wa.me` (grátis), nunca a API paga do WhatsApp.
- O bairro do cliente é só um filtro temporário (não fica salvo no perfil).

## Becos sem saída e custos: NÃO seguir sem falar com o Bruno
- **Cloud Storage (fotos):** exige o plano Blaze (cartão cadastrado) desde 2026. Adiar fotos ou buscar alternativa grátis.
- **Cloud Functions:** publicar funções exige o Blaze. Projetar tudo com regras + app (transações no cliente).
- **Login por SMS/telefone:** no Spark são cerca de 10 por dia, só para teste. Manter e-mail e senha.
- **API do WhatsApp Business, Google Maps/Places, SMS, gateways de pagamento:** pagos ou exigem cartão. Usar `wa.me` e a lista fixa de bairros.
- **Notificações push** enviadas por servidor precisam de Functions (Blaze). Por enquanto, usar o status dentro do app (faixa de aviso na Home). É o maior limite do plano grátis.
- **iOS / App Store:** US$ 99 por ano. Fora do escopo; o foco é Android e web.
- **Play Store:** taxa única de US$ 25. É o único custo previsto, só na publicação.
- Plano Blaze: só com decisão explícita do Bruno.

## Pendências atuais (ver docs/ESTADO_ATUAL.md, seção 7)
1. Publicar `firestore.rules`, colando no console ou com `npx firebase-tools deploy --only firestore:rules`.
2. Rodar `tools/atualizar_dados_v2.sh` no Cloud Shell.
3. Testes manuais: relatórios 02, 03 e 04.
4. E-mail de contato nas páginas `paginas/privacidade.html` e `paginas/termos.html` (hoje: "[e-mail de contato a definir]").
5. Próximo passo sugerido: Android (precisa da configuração Android do console, feita pelo Bruno) e depois a Play Store.
