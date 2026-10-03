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
- **Notificações push** enviadas por servidor precisam de Functions (Blaze). Por enquanto, usar o status dentro do app.
- **iOS / App Store:** US$ 99 por ano. Fora do escopo; o foco é Android e web.
- **Play Store:** taxa única de US$ 25. É o único custo previsto, só na publicação.
- Plano Blaze: só com decisão explícita do Bruno.

## Pendências atuais (ver docs/ESTADO_ATUAL.md)
1. Publicar `firestore.rules` (pode ser pelo PC: `npx firebase-tools deploy --only firestore:rules`).
2. Rodar `tools/atualizar_dados_v2.sh` no Cloud Shell (apaga só o campo `email` dos perfis e atualiza os profissionais de teste).
3. Teste manual: seção 4 de `docs/RELATORIO_TESTES_02.md`.
4. Próxima camada: **solicitação de atendimento** (confirmar o escopo com o Bruno antes).
