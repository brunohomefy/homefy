# HOMEFY — RELATÓRIO DE TESTES 02 (02/10/2026)

**Camada:** cadastro de profissional (Partes A a D).
**Versão:** `main` em `24f1c38`, publicada em https://brunohomefy.github.io/homefy/
**Demonstração (sem Firebase, dados de exemplo):** https://brunohomefy.github.io/homefy/demo/

---

## 1. O que foi construído

| Parte | Entrega |
|---|---|
| A. Dados e regras | Catálogo fixo (4 categorias, subtipos e portes); 45 bairros de Caruaru; e-mail fora do perfil público; WhatsApp em `usuarios/{uid}/privado/contato`; serviços com `categoria_id`, `subtipo`, `variacoes` e `bairros`; regras novas |
| B. Quero oferecer | 4 passos: categorias e subtipos → bairros (ou "Caruaru toda") → WhatsApp e apresentação → revisão. Também serve para editar o perfil depois |
| C. Meus serviços | Lista dos próprios serviços, liga/desliga na vitrine, editor com subtipo, faixas de preço ("Padrão" + portes opcionais) e duração. Preço vazio = "sob consulta" |
| D. Home | "Onde será o atendimento?" (filtro por bairro, **não fica salvo**), tabela de faixas no detalhe, "Não achou? Conte pra gente" e "Conte sua experiência" (vão para `feedbacks`) |

---

## 2. Testes automáticos (rodam a cada envio, no GitHub Actions)

**Regras do Firestore: 23 de 23 passando** (no emulador; não tocam no banco real). Principais garantias:
- Sem login, ninguém lê nada.
- O WhatsApp só é lido pelo dono.
- O perfil não aceita e-mail, CPF nem campos inventados.
- Só vira profissional quem tem categoria, área de atendimento e WhatsApp válido.
- Cliente não cria serviço; profissional não cria em nome de outro nem "toma posse" de serviço alheio.
- Serviço não se apaga, só se desativa.
- Feedback é só de escrita, e ninguém se passa por outro autor.

**App: 15 de 15 passando.** Cobrem preço em R$, duração, categorias, sinônimos, ordem da vitrine, catálogo sem ids repetidos, variações, filtro de bairro e normalização do WhatsApp ("(81) 99999-1234", "+55…" e "081…").

**Auditoria visual automática:** a cada envio, o GitHub abre a demonstração num navegador de celular (390×844) e grava prints na branch `auditoria-telas`.

---

## 3. Auditoria visual (prints da demonstração)

| Tela | Resultado |
|---|---|
| Home com o seletor de bairro | ✅ |
| Escolher bairro (lista com busca, "Todos os bairros") | ✅ |
| Home filtrada por "Salgado" | ✅ Some quem não atende o Salgado; "Lavagem completa" (atende a cidade toda) continua |
| Detalhe com faixas (Carro pequeno / médio / SUV) | ✅ Mostra preço e duração por faixa e "Atende Caruaru toda" |
| "Não achou?" | ✅ |
| Quero oferecer: passos 1 a 3, mensagens de erro | ✅ |
| Folha do perfil: "Quero oferecer", "Conte sua experiência", "Sair" | ✅ |
| Salvar perfil, Meus serviços, editor de serviço | ⏳ O roteiro automático não consegue digitar no campo do Flutter. **Precisa do teste manual do Bruno** (abaixo) |

**Achado corrigido:** o botão "Não achou o que precisa? Conte pra gente" quebrava em duas linhas no celular. Virou "Não achou? Conte pra gente".

---

## 4. Teste manual pendente (Bruno, no app real)

Pré-requisitos:
1. Publicar `firestore.rules` no console.
2. Rodar `tools/atualizar_dados_v2.sh` no Cloud Shell.

Roteiro:
1. Home → "Onde será o atendimento?" → **Salgado**. Devem aparecer Joana, Cícera e Diego (Diego atende a cidade toda). Rafael **não** aparece.
2. Tocar em "Lavagem simples de carro" → aparecem 3 faixas.
3. Perfil → "Quero oferecer meus serviços" → completar os 4 passos com bairros marcados (testar a busca "salga").
4. Cadastrar um serviço com duas faixas e outro sem preço → os dois aparecem em "Meus serviços" e na Home (com o seu bairro escolhido).
5. Desligar um serviço → some da Home.
6. Editar o perfil e trocar os bairros → os serviços acompanham.
7. Enviar um "Não achou?" e um "Conte sua experiência" → aparecem em `feedbacks` no console.
8. No console, conferir que `usuarios/<seu uid>` **não tem** e-mail nem WhatsApp, e que o WhatsApp está em `privado/contato`.

---

## 5. Custos

Nada pago. Tudo continua no plano Spark (grátis) e no GitHub (grátis para repositório público).
- Cada abertura da Home ainda lê até 50 serviços; o filtro por bairro é feito no próprio app.
- Quando o catálogo crescer, dá para filtrar no banco (`bairros array-contains`), o que reduz as leituras. Também é grátis.

---

## 6. Riscos e pendências

1. **Publicação das regras é manual.** Opção futura: o GitHub publicar sozinho com uma conta de serviço (grátis, exige guardar uma chave como secret).
2. **Contas antigas com ID aleatório** (do FlutterFlow) não viram profissional pelo app. O app cria `usuarios/{uid}` na primeira entrada, então dá para usar, mas o documento antigo fica órfão.
3. O cliente vê os bairros que o profissional atende. Isso é informação de trabalho, não pessoal, e está de acordo com a LGPD.
4. **Próxima camada natural:** solicitação de atendimento (pedido → resposta com valor final → aprovação → WhatsApp liberado, D3), com transação para não confirmar dois atendimentos no mesmo horário.
