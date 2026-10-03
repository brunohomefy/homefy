# Homefy: começar no PC (Windows), passo a passo

Atualizado em 03/10/2026. Tempo total: cerca de 20 minutos. **Custo: zero.**

> Princípio: o PC serve só para **mexer no código com o Claude Code** e **publicar as regras do banco**.
> Compilar, testar e publicar o app continua acontecendo na nuvem (GitHub Actions), de graça.
> **Não instale** Android Studio, Flutter nem Google Cloud SDK agora. É peso e tempo sem ganho nesta fase.

---

## 1. Instalar o mínimo (uma vez só)

Abra o **PowerShell** (menu Iniciar → digite "PowerShell") e cole uma linha por vez:

```powershell
winget install --id Git.Git -e
winget install --id OpenJS.NodeJS.LTS -e
```

Feche e abra o PowerShell de novo. Para conferir se instalou:

```powershell
git --version
node --version
```

## 2. Baixar o projeto

```powershell
cd $HOME\Documents
git clone https://github.com/brunohomefy/homefy.git
cd homefy
```

> Na primeira vez que for enviar algo (`git push`), o Windows abre o navegador para você entrar no GitHub.
> Entre com a conta **brunohomefy** (aquela criada com o Google).

## 3. Abrir no Claude Code

Abra o Claude Code na pasta `Documents\homefy`. Ele lê o arquivo `CLAUDE.md` sozinho; ali estão as regras de trabalho, as decisões e os becos sem saída. Cole esta primeira mensagem:

```
Leia CLAUDE.md, docs/ESTADO_ATUAL.md e docs/RELATORIO_TESTES_02.md.
Depois me ajude, nesta ordem:
1) publicar as regras do Firestore (npx firebase-tools login e deploy --only firestore:rules);
2) me guiar no teste manual da seção 4 do relatório 02;
3) só então propor o escopo da próxima camada (solicitação de atendimento), sem construir antes de eu aprovar.
Lembre-se: gasto zero, avise antes de qualquer custo e de qualquer caminho que leve a plano pago.
```

## 4. Publicar as regras do banco (feito pelo Claude Code, você só aprova)

O Claude Code vai rodar estes comandos. Se preferir, rode você mesmo:

```powershell
npx firebase-tools login
npx firebase-tools deploy --only firestore:rules
```

- O `login` abre o navegador: entre com a conta Google **dona do projeto Firebase**.
- O projeto `homefy-67cdd` já está configurado no arquivo `.firebaserc`.
- **Alternativa sem PC:** colar o conteúdo de `firestore.rules` em
  https://console.firebase.google.com/project/homefy-67cdd/firestore/rules e clicar em **Publicar**.

## 5. Atualizar os dados (no navegador, Cloud Shell, grátis)

Este passo **não** é feito no PC: o Cloud Shell já vem pronto e com acesso ao seu projeto.

1. Abra https://console.cloud.google.com/?project=homefy-67cdd
2. Clique no ícone **`>_`** (Ativar o Cloud Shell), no topo à direita.
3. Cole a linha abaixo e aperte Enter. Se pedir, clique em **Autorizar**.

```bash
curl -sL https://raw.githubusercontent.com/brunohomefy/homefy/main/tools/atualizar_dados_v2.sh | bash
```

O que o script faz:
- apaga **só** o campo `email` dos perfis (LGPD);
- atualiza os 4 profissionais de teste.

Nada é apagado além disso. No fim aparece **FIM**.

## 6. Testar

Abra https://brunohomefy.github.io/homefy/ e siga a seção 4 de `docs/RELATORIO_TESTES_02.md` (8 passos).
Se algo der errado, mande um print para o Claude Code.

---

## Se algo der errado

| Problema | O que fazer |
|---|---|
| `winget` não existe | Instale o "Instalador de Aplicativo" pela Microsoft Store, ou baixe o Git em git-scm.com e o Node em nodejs.org (versão LTS) |
| `npx firebase-tools login` não abre o navegador | Use `npx firebase-tools login --no-localhost` e copie o código que aparecer |
| `deploy` diz "permission denied" | Você entrou com outra conta Google. Rode `npx firebase-tools logout` e faça o login de novo |
| App mostra "O banco recusou…" | As regras ainda não foram publicadas (passo 4) |
| App mostra a versão antiga | Recarregue a página com Ctrl+Shift+R |

## Onde ver cada coisa

- App: https://brunohomefy.github.io/homefy/
- Demonstração (sem login): https://brunohomefy.github.io/homefy/demo/
- Testes e publicação: https://github.com/brunohomefy/homefy/actions
- Prints automáticos das telas: branch `auditoria-telas`, pasta `prints/`
- Banco: https://console.firebase.google.com/project/homefy-67cdd/firestore
- Mensagens dos usuários: coleção `feedbacks` no banco
