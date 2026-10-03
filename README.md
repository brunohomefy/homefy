# Homefy — app Flutter

Serviços domiciliares em Caruaru–PE. Flutter + Firebase (o mesmo projeto Firebase que era usado no FlutterFlow).

## Link para testar

**https://brunohomefy.github.io/homefy/**: atualiza sozinho a cada mudança enviada para a branch `main` (GitHub Actions → GitHub Pages, grátis).

## Começar

- **No PC (Windows):** siga `docs/INICIO_NO_PC.md` (só Git e Node; nada de Android Studio).
- **Para o Claude:** `CLAUDE.md` traz as regras de trabalho, as decisões e os custos a evitar.
- **Onde paramos:** `docs/ESTADO_ATUAL.md`. Último relatório: `docs/RELATORIO_TESTES_02.md`.

## O que já funciona

- Login, criar conta e redefinir senha.
- Home com busca, categorias, filtro por bairro (temporário), detalhe com faixas de preço.
- "Quero oferecer" (perfil profissional em 4 passos) e "Meus serviços" (criar, editar, esconder).
- "Não achou? Conte pra gente" e "Conte sua experiência" (coleção `feedbacks`).
- LGPD: e-mail e WhatsApp fora do perfil público; WhatsApp em `usuarios/{uid}/privado/contato`.
- Ainda não existe: solicitação de atendimento, agenda, avaliações, fotos.

## Como é testado e publicado

A cada envio, o GitHub Actions faz quatro coisas:
- analisa o código e roda os testes do app;
- testa as regras do Firestore no emulador;
- compila a versão web e a demonstração;
- tira prints das telas.

Só a branch `main` publica. Se algum passo falhar, nada vai ao ar.
