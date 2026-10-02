# HOMEFY — ESTADO ATUAL E DECISÕES (02/10/2026)

**Este documento é o ponto de retomada mais recente.** Ele substitui a parte "retomada" das seções 66 e 67 do `HOMEFY_DOSSIE_MESTRE.md`. As regras de produto do dossiê continuam valendo, exceto onde este documento decide diferente.

---

## 1. Onde o projeto está

- **App:** Flutter + Firebase, sem FlutterFlow.
- **Código:** https://github.com/brunohomefy/homefy (público; branch `main`).
- **App no ar para testes:** https://brunohomefy.github.io/homefy/. Cada push na `main` compila, analisa, testa e publica sozinho (GitHub Actions + Pages, grátis).
- **Firebase:** projeto `homefy-67cdd`, plano **Spark (grátis)**. Config Web já está no código. Para Android, falta rodar `flutterfire configure` (o pacote do app Android existente é `com.mycompany.homefy`).
- **Regras do Firestore:** publicadas em 02/10/2026 10:24, a partir do arquivo `firestore.rules` do repositório.
- **Cloud Shell:** ativado no console (grátis), usado para scripts de dados.

### Telas prontas
Login, Criar conta (gera `usuarios/{uid}`), Home (vitrine com busca, sinônimos, filtro por categoria, detalhe do serviço com "Sobre o profissional") e Perfil/Sair.

### Banco de dados real (descoberto em 02/10)
As 8 coleções já existem no Firestore com dados de teste antigos do FlutterFlow.
- `servicos` tem `profissional_ref`, que aponta para `usuarios`.
- `usuarios` usa o campo `auth_uid`. As contas novas usam ID = UID.

Há **dados de teste** marcados com `teste: true` e IDs começando com `teste_`: 4 profissionais e 13 serviços (`tools/seed_teste.sh`). Ver `HOMEFY_RELATORIO_TESTES_01.md`.

---

## 2. Decisões de produto aprovadas pelo Bruno em 02/10/2026

**D1. Categorias fixas com subtipos.**
- 4 categorias: Cabelo e barba · Manicure · Lavagem de veículos (a domicílio) · Limpeza.
- Cada uma tem **subtipos** que o profissional marca se faz. Exemplo, Limpeza: residencial, pós-obra, passadoria.
- Um subtipo só aparece para quem marcou.
- **Sem categoria "Outros" pública.** No lugar dela, o botão **"Não achou o que precisa? Conte pra gente"** grava em `feedbacks`. Serve para medir a demanda e escolher as próximas categorias com prova.

**D2. Preço com variações.**
- O profissional define **variações por porte/tamanho**, cada uma com o seu "a partir de".
  - Lavagem: moto, carro pequeno, médio, SUV/picape.
  - Faxina: 1, 2 ou 3+ quartos.
- O pedido tem um **campo de detalhes**.
- O profissional responde com o **valor final**, e o cliente aprova (dossiê, item 11).

**D3. WhatsApp só depois do pedido.**
- O número nunca aparece no perfil.
- Depois do pedido, o botão abre o WhatsApp com a mensagem pronta "Olá, vi você no Homefy, pedido #123".

**D4. Estratégia para manter o uso no app** (sem pagamento no app):
- A avaliação só existe se houver pedido no app.
- O cliente tem histórico e "contratar de novo".
- No dia seguinte ao atendimento, o app pergunta "o serviço aconteceu?".
- Monetização futura por **mensalidade do profissional, nunca comissão**, porque a comissão incentiva fechar por fora.
- Objetivo do Bruno: as pessoas devem usar muito o app porque ele é grátis e facilita. A monetização vem aos poucos, depois da reputação.

**D5. Custos.** Nada pago agora nem no futuro próximo, até o app estar pronto para a Play Store.
- Avisar **antes** de qualquer passo que possa custar.
- Desvios grátis já mapeados:
  - Confirmação sem conflito: transação no app, em vez de Cloud Functions.
  - Notificação: aviso dentro do app + WhatsApp, em vez de push automático.
  - Fotos: **confirmar se o Storage exige Blaze**. Se exigir, usar uma alternativa gratuita.

---

## 3. Forma de trabalho combinada

- Auditoria a cada camada: o que mudou, por que mudou, se valeu a pena e como foi testado.
- Perguntar ao Bruno quando houver mais de um caminho. Mudança de rumo de produto **sempre** passa por ele.
- Testar no app publicado antes de dar uma camada por pronta.
- Avisar quando a conversa estiver densa, para migrar para um chat novo.

---

## 4. Próxima camada: CADASTRO DE PROFISSIONAL

Escopo proposto (confirmar com o Bruno no início):
1. "Quero oferecer" abre o fluxo de virar profissional, na mesma conta.
2. Escolher a(s) categoria(s) e os subtipos a partir da lista fixa (D1).
3. Bairros atendidos, numa lista fixa de bairros de Caruaru (dossiê 65.6).
4. WhatsApp (privado; só aparece depois do pedido, D3) e descrição curta.
5. Cadastrar serviços: nome, subtipo, variações com preço e duração (D2).
6. Os serviços aparecem na Home. Na Home, o cliente pode filtrar pelo seu bairro.
7. Regras do Firestore: o profissional só cria e edita os **próprios** serviços. `eh_profissional` só muda por esse fluxo.
8. Testar com contas de teste e escrever o Relatório de Testes 02.

Fora desta camada: solicitação/agenda, avaliações e fotos.
