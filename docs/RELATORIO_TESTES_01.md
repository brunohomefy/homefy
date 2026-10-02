# HOMEFY — RELATÓRIO DE TESTES 01 (02/10/2026)

**App testado:** https://brunohomefy.github.io/homefy/ (versão `48c7237`)
**Conta usada:** "João teste 1" (cliente), criada pelo Bruno.
**Tudo abaixo é TESTE.** Os profissionais e serviços são fictícios e estão marcados com `teste: true` no Firestore.

---

## 1. Catálogo de teste criado

Criado pelo Cloud Shell (grátis) com o script `tools/seed_teste.sh` do repositório.

| Profissional (fictício) | Categoria | Serviços |
|---|---|---|
| Rafael Barbosa (`usuarios/teste_rafael`) | Cabelo e barba | Barba completa R$ 20 · Corte + barba R$ 40 · Corte infantil R$ 20 |
| Joana Lima (`teste_joana`) | Manicure | Mão R$ 20 · Mão e pé R$ 35 · Alongamento em gel R$ 120 |
| Diego Santos (`teste_diego`) | Lavagem de veículos | Lavagem simples R$ 40 · Completa + aspiração R$ 70 · Moto R$ 25 |
| Cícera Alves (`teste_cicera`) | Limpeza | Passadoria R$ 60 · Faxina R$ 140 · Pós-obra (sem preço) · Higienização de sofá (**desativado**) |

Mais o serviço que já existia: Corte Masculino R$ 25 (Bruno teste). Total: 14 serviços, 13 ativos.

Casos difíceis incluídos de propósito: serviço **sem preço**, serviço **desativado**, categorias escritas de jeitos diferentes ("Lava-jato" e "Lavagem de veículos"; "Barbeiro(a)" e "Cabeleireiro(a)").

---

## 2. Jornadas de quem contrata (testadas no app real)

**Ana, 34 anos, quer fazer as unhas.** Digita "unha" na busca.
- Antes: **"Nada encontrado"**. Nenhum serviço tinha a palavra "unha" escrita. ❌ **Corrigido**: agora a busca entende sinônimos e mostra os 3 serviços da Joana. ✅
- Toca em "Mão": vê preço (R$ 20,00), duração (40 min) e "por Joana Lima". ✅
- Toca em "Solicitar atendimento": aparece "em breve". Ela **não consegue** saber se a Joana atende o bairro dela, nem em qual dia, nem falar com ela. ⚠️ É a próxima lacuna do produto.

**Dona Márcia, reforma terminada, quer limpeza pós-obra.** Toca na categoria Limpeza.
- Antes: aparecia **só 1 de 3 serviços**. A Home lia no máximo 10 serviços e cortava o resto. ❌ **Corrigido**: limite subiu para 50 e a lista vem ordenada por categoria e menor preço. ✅
- "Limpeza pós-obra" aparece como **"sob consulta"** e fica no fim da lista. ✅
- No detalhe aparece **"Sobre Cícera: diarista com 12 anos de experiência…"** (novo). ✅
- Ela quer um orçamento, mas não há como pedir. ⚠️ Isso entra no fluxo "Preço base → valor final → aprovação" (dossiê, item 11).

**Busca sem acento.** Digitar "mao" encontra "Mão" e "Mão e pé". ✅

**Serviço desativado.** "Higienização de sofá" (`ativo = false`) **não aparece**. ✅

**Cadastro e login.**
- A conta nova gerou `usuarios/{uid}` com ID = UID, `auth_uid`, `cidade`, `eh_profissional = false` e `criado_em`. Está de acordo com as regras. ✅
- A saudação "Olá, João!" usa o nome cadastrado. ✅
- Tocar em "Entrar" com os campos vazios mostra os avisos de campo obrigatório. ✅

---

## 3. Jornada de quem é contratado (SIMULADA: ainda não existe no app)

**Rafael, barbeiro, quer se cadastrar.** Hoje ele **não consegue**: o botão "Quero oferecer" diz "em breve". Os serviços só entram pelo console.

O que o profissional médio vai esperar, em ordem de importância:
1. **Escolher a categoria de uma lista fixa.** O texto livre já gerou bagunça no teste ("Lava-jato" e "Lavagem de veículos" aparecem como etiquetas diferentes no card).
2. Cadastrar os próprios serviços com preço "a partir de" e duração.
3. **Marcar os bairros que atende**, também numa lista fixa de bairros de Caruaru (dossiê, 65.6).
4. Informar o WhatsApp. O cliente só vê o número depois de pedir o atendimento.
5. Informar dias e horários em que trabalha.
6. Receber pedidos e responder (aceitar ou mandar o valor final).

Medo comum do profissional: "vou receber pedido para longe ou fora do meu horário?" Os itens 3 e 5 resolvem isso.

---

## 4. Erros encontrados e status

| # | Achado | Gravidade | Status |
|---|---|---|---|
| 1 | Home mostrava só 10 serviços (Limpeza 1 de 3) | Alta | ✅ Corrigido |
| 2 | Busca "unha", "carro", "diarista" não encontrava nada | Alta | ✅ Corrigido (sinônimos) |
| 3 | Detalhe não dizia quem é o profissional | Média | ✅ Corrigido ("Sobre …") |
| 4 | Lista sem ordem lógica | Baixa | ✅ Corrigido (categoria → preço) |
| 5 | Categoria em texto livre gera etiquetas diferentes | Média | ⏳ Resolver no cadastro de profissional (lista fixa) |
| 6 | Cliente não sabe bairro atendido nem disponibilidade | Alta | ⏳ Próximas camadas |
| 7 | Depois de uma atualização, o navegador pode mostrar a versão antiga | Baixa | ℹ️ Recarregar a página. Se persistir, recarregar de novo |

---

## 5. Projeção de custos: onde mora o risco de pagar

| Item | Custo hoje | Risco futuro | Caminho sem gastar |
|---|---|---|---|
| Firestore (banco) | Grátis (Spark) | 50 leituras por abertura da Home. Cota de 50 mil por dia dá ~1.000 aberturas/dia | Suficiente para o piloto. Depois, filtrar por bairro/categoria |
| Login e-mail/senha | Grátis | Nenhum | Não usar login por SMS (SMS é pago) |
| GitHub + publicação web | Grátis | Nenhum (repositório público) | Manter assim |
| **Confirmar atendimento sem conflito** (dossiê 65.5) | — | O dossiê previa Cloud Functions, que **exigem o plano Blaze (cartão)** | ✅ Existe caminho grátis: **transação do Firestore no próprio app + regras** |
| **Notificação push automática** | — | Enviar push sozinho exige servidor (Functions → Blaze) | Grátis: aviso dentro do app (coleção `notificacoes`) + botão de WhatsApp |
| **Fotos (portfólio)** | — | ⚠️ Projetos novos do Firebase só usam o Storage no plano Blaze. **Preciso confirmar no console** | Alternativa grátis: serviço de imagens com plano gratuito, ou adiar fotos |
| Domínio próprio | — | ~R$ 40/ano | Usar o link github.io até o lançamento |
| Google Play | — | US$ 25, uma vez só | Só na hora de publicar |
| App Store (iPhone) | — | US$ 99 por ano | Começar só com Android + Web |

**Conclusão:** não há beco sem saída **até o piloto**. Os três pontos que levariam ao plano pago (Functions, push automático e Storage) têm desvio grátis. Eu aviso antes de chegar em cada um.

---

## 6. Como apagar os dados de teste depois

Todos têm `teste: true` e IDs começando com `teste_`. Para limpar, basta um script de 10 linhas no Cloud Shell. Eu faço quando você pedir. A exclusão é definitiva, então só com a sua confirmação.

---

## 7. Próxima camada recomendada

**Cadastro de profissional**, com categoria e bairros em lista fixa e serviços com preço e duração. Depois disso, cliente e profissional se encontram de verdade no app, e a camada de **solicitação** passa a fazer sentido.
