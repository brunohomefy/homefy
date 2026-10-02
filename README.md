# Homefy — app Flutter

Serviços domiciliares em Caruaru–PE. Flutter + Firebase (o mesmo projeto Firebase que era usado no FlutterFlow).

## O que já funciona

- **Login** com e-mail e senha, "Esqueceu a senha?" (envia e-mail de redefinição) e mensagens de erro em português.
- **Criar conta**: cria o usuário no Authentication **e** o documento `usuarios/{uid}` (nome, email, eh_profissional = false, criado_em).
- **Home**: lê `servicos` (ativo == true, até 10) em tempo real, preço em `R$ 25,00`, busca por texto, filtro pelas 4 categorias do MVP, detalhes do serviço, estados de carregando / vazio / erro.
- **Perfil** (botão redondo no topo da Home): mostra nome e e-mail e tem o **Sair**.
- Nada de foto, nota ou localização falsas. O "Solicitar atendimento" e o "Quero oferecer" mostram "em breve".

## Primeira vez (no seu computador)

Precisa ter instalado: **Flutter** (3.27 ou mais novo), **Node.js** e **Android Studio** (ou só o Chrome, para testar na web).

```bash
# 1. Entrar na pasta do projeto
cd homefy

# 2. Gerar as pastas de Android / iOS / Web (não mexe no que já está em lib/)
#    O "com.mycompany" é o mesmo pacote do app Android que já existe no Firebase.
flutter create . --org com.mycompany --project-name homefy --platforms android,ios,web

# 3. Baixar as dependências
flutter pub get

# 4. Testar no navegador (o Firebase da Web JÁ ESTÁ configurado)
flutter run -d chrome
```

Para rodar no **celular Android**, falta só gerar a configuração nativa (uma vez):

```bash
npm install -g firebase-tools
firebase login
dart pub global activate flutterfire_cli
flutterfire configure --project=homefy-67cdd   # marque android e web
```

## Publicar as regras do Firestore (obrigatório antes de criar conta)

As regras novas estão em `firestore.rules`. Sem elas, o cadastro falha com "permissão do banco".

Jeito mais fácil: Firebase Console → Firestore Database → **Regras** → apagar tudo → colar o conteúdo de `firestore.rules` → **Publicar**.

O que elas fazem:
- `servicos`: qualquer pessoa **logada** lê; ninguém grava pelo app.
- `usuarios/{uid}`: cada pessoa só cria, lê e altera o **próprio** perfil. Não dá para se marcar como profissional pelo app.
- Todo o resto: fechado.

## Rodar

```bash
flutter run -d chrome          # no navegador
flutter run                    # no celular Android ligado por cabo (depuração USB)
flutter test                   # testes de preço, duração e categorias
```

### Ver só o visual, sem Firebase

```bash
flutter run -d chrome --dart-define=HOMEFY_DEMO=true
```

Mostra serviços de exemplo e entra sem senha. **Só para olhar o design**; sem a flag o app usa sempre o Firebase real.

## Roteiro de teste rápido

1. Abrir → cai no Login.
2. Entrar com a conta de teste → vai para a Home e lista os serviços com `ativo = true`.
3. No console do Firebase, mudar um serviço para `ativo = false` → some da Home sem recarregar.
4. Buscar "corte"; tocar numa categoria; tocar de novo para desmarcar.
5. Tocar num serviço → abre os detalhes.
6. Perfil → Sair → volta ao Login.
7. Cadastre-se com um e-mail novo → entra na Home com "Olá, <nome>!" e aparece `usuarios/<uid>` no Firestore.
8. Login com senha errada → mensagem "E-mail ou senha incorretos."

## Estrutura

```
lib/
├─ main.dart              início, Firebase, tema, tela de "falta configurar"
├─ app_router.dart        rotas + redirecionamento por login
├─ config.dart            modo demonstração
├─ firebase_options.dart  gerado pelo flutterfire configure
├─ theme/                 cores, fontes, raios, sombras
├─ models/                Servico (leitura tolerante, R$) e Categoria (4 do MVP)
├─ services/              AuthService, ServicosRepo
├─ screens/               login, criar_conta, home
└─ widgets/               logo casa+check, campos, cards, layout de entrada
```

## Observações

- O banco já tinha as 8 coleções com dados de teste do FlutterFlow. O app lê `servicos` e, pelo campo `profissional_ref`, mostra "por <nome>" no card.
- Contas novas criam `usuarios/{uid}` (ID = UID). O usuário de teste antigo tem ID aleatório com o UID no campo `auth_uid`; ele continua funcionando para login.

- A categoria de cada serviço é reconhecida por palavra-chave (ex.: "Cabeleireiro(a)" e "Barbeiro(a)" → Cabelo e barba; "Lava-jato" → Lavagem de veículos). Categoria desconhecida aparece com ícone genérico.
- A seção da Home se chama **"Serviços disponíveis"**, e não "Profissionais Sugeridos", porque `servicos` ainda não tem vínculo com profissional (dossiê 65.1).
