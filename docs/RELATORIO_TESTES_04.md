# HOMEFY: RELATÓRIO DE TESTES 04 (03/10/2026)

**Entregas:** Política de Privacidade + Termos de Uso, e a camada de **avaliações**.
Feito com o Bruno ausente, a pedido dele ("faça mais"). Pontos para revisar: seção 5.

---

## 1. Política de Privacidade e Termos de Uso

- Duas páginas públicas, exigidas pela Play Store e pela LGPD:
  - https://brunohomefy.github.io/homefy/privacidade.html
  - https://brunohomefy.github.io/homefy/termos.html
- O rodapé "Ao continuar, você concorda com…" do login e do cadastro **já existia, mas não levava a lugar nenhum**. Agora tem links de verdade.
- No menu do perfil: "Privacidade e termos".
- O conteúdo segue o que o app realmente coleta: nome, e-mail (só no login), WhatsApp (só após confirmação), bairro, pedidos, avaliações e sugestões. E deixa claro o que **não** coleta: CPF, endereço, GPS, fotos e pagamento.
- Os Termos deixam claro que o Homefy é uma vitrine: **não presta o serviço nem participa do pagamento**.

> Não sou advogado. Estes textos são um bom ponto de partida para o piloto, mas vale uma revisão jurídica antes de crescer.

## 2. Avaliações

- **Quando:** depois que o profissional marca o atendimento como **concluído**. No detalhe do pedido, o cliente vê "Como foi o atendimento?" (de 1 a 5 estrelas, mais um comentário opcional de até 300 caracteres).
- **Uma por atendimento:** o documento `avaliacoes/{id}` usa o mesmo id da solicitação, então o banco não aceita uma segunda.
- **Não pode ser editada nem apagada**, nem pelo cliente nem pelo profissional. Isso evita pressão para trocar a nota.
- **Onde aparece:** no detalhe do serviço, com a média em estrelas, por exemplo "4,7 (3 avaliações)", e os 3 comentários mais recentes. Quem ainda não tem avaliação aparece como "Novo no Homefy".
- **Privacidade:** só o **primeiro nome** do cliente fica público.
- O profissional vê a avaliação no pedido concluído.
- **Média calculada no app** (até 50 avaliações por profissional), sem servidor, no plano grátis.

## 3. Testes

| Conjunto | Resultado |
|---|---|
| Regras do Firestore (emulador) | **45 de 45** (+4: avaliar concluído; não avaliar antes; nota 0, 6 ou 4,5, autoavaliação e campos extras recusados; não editar nem apagar) |
| App (Dart) | **23 de 23** (+3: média e texto, nota fora da faixa, só o primeiro nome) |
| Auditoria visual | ✅ avaliar (estrelas e comentário), avaliação enviada, média e comentários no detalhe do serviço |

## 4. Custo

Zero. Abrir o detalhe de um serviço lê até 50 avaliações daquele profissional uma vez por sessão (fica guardado na memória do app).

## 5. Para o Bruno revisar

1. **E-mail de contato** nas duas páginas: está como "[e-mail de contato a definir]". **Precisa ser preenchido antes de publicar na Play Store.** Sugestão: criar um e-mail só do Homefy (Gmail é grátis) em vez de usar o pessoal.
2. **Nome do responsável:** as páginas dizem "o criador do Homefy". Se você abrir MEI/CNPJ, trocar pelo nome da empresa.
3. **Comentário público:** escolhi deixar visível, com o primeiro nome. Alternativa: mostrar só a nota.
4. **Profissional não responde avaliação** (por enquanto).
5. **Nota não aparece no card da lista**, só no detalhe. Mostrar na lista custaria uma leitura por profissional a cada abertura da Home. Dá para fazer mais adiante, guardando a média no perfil.

## 6. Teste manual (no app real, depois de publicar as regras)

1. Leve um pedido até "confirmado" (relatório 03, seção 7).
2. Na conta profissional: "Marcar como concluído". O botão aparece no dia do atendimento ou depois; para testar, peça para amanhã e conclua amanhã.
3. Na conta cliente: abra o pedido, dê as estrelas e envie.
4. Abra o serviço na Home: a média e o comentário aparecem.
5. Tente avaliar de novo: não aparece mais a opção.
