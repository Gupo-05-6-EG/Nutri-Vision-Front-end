# Nutri Vision — App do paciente

App mobile do paciente, em **Flutter**. Registra refeições por foto, acompanha o
histórico de consumo e a gamificação.

## Stack

| Camada | Tecnologia |
|---|---|
| SDK | Flutter (Dart ≥ 3.5) |
| HTTP | `http` |
| Configuração | `flutter_dotenv` |
| Token JWT | `flutter_secure_storage` |
| Armazenamento Offline | `hive` + `connectivity_plus` (RNF07) |
| Push (lembretes) | `firebase_core` + `firebase_messaging` (FCM) |
| Câmera própria | `camera` (Android, iOS e navegador) |
| QR Code do vínculo | `mobile_scanner` |
| Fonte | Nunito embutida em `assets/fonts` (OFL) |
| Lint | `flutter_lints` |
| Testes | `flutter_test` + `http/testing` (MockClient) |
| CI | GitHub Actions |

## Estrutura

Organização *feature-first* — cada requisito funcional entra como uma pasta em
`lib/features/`, sem mexer no núcleo:

```
lib/
├── main.dart                     # carrega o .env e sobe o app
├── app.dart                      # MaterialApp, tema (claro/escuro), rota inicial
├── app_services.dart             # repositórios e controladores, criados uma vez
├── core/
│   ├── config/env.dart           # leitura validada do .env
│   ├── config/app_theme.dart     # tema com a paleta do protótipo
│   ├── config/theme_controller.dart  # modo de exibição salvo entre aberturas
│   ├── ui/                       # componentes do protótipo (NvCard, NvButton, XP...)
│   └── network/
│       ├── api_client.dart       # cliente HTTP + injeção do JWT
│       └── api_exception.dart
└── features/
    ├── shell/                    # abas Início, Registrar, Social e Perfil
    ├── home/                     # aba Início (meta do dia, macros e conquistas)
    ├── register/                 # aba Registrar (foto, manual e histórico)
    ├── social/                   # Ranking Social, amigos por e-mail (RF05, RF29)
    ├── profile/                  # perfil, meta única, estatísticas e configurações
    ├── challenges/               # desafios entre amigos e placar (RF05.2, RF05.3)
    ├── foods/                    # busca manual de alimentos (RF02.2)
    ├── meals/                    # histórico de refeições (RF04, RF12)
    ├── plan/                     # plano prescrito e progresso (RF06, RF25)
    ├── recognition/              # câmera, análise da IA e revisão (RF02.1, RF02.3)
    ├── linking/                  # código e QR Code do nutricionista
    └── reminders/                # lembretes de refeição + push FCM (RF26)
test/                             # testes de unidade e de widget
```

## Primeiro setup

```bash
cp .env.example .env
flutter create --platforms=android,ios --org br.com.nutrivision .
flutter pub get
flutter run
```

> **Por que o `flutter create`?** As pastas `android/`, `ios/` etc. são geradas
> pelo SDK e não são versionadas (veja o `.gitignore`) — assim o repositório não
> carrega código nativo gerado nem conflitos de merge nele. O CI roda esse mesmo
> comando antes do build.

### No navegador

```bash
flutter create --platforms=web --org br.com.nutrivision .
flutter run -d chrome     # ou: flutter build web e sirva a pasta build/web
```

Use `API_URL=http://localhost:8000/api/v1` no `.env`. Na web o armazenamento
offline (Hive) usa o IndexedDB do navegador, e a câmera abre pelo navegador.

> **Emulador Android:** `localhost` dentro do emulador não é a sua máquina. Use
> `API_URL=http://10.0.2.2:8000/api/v1` (já é o padrão do `.env.example`).

## Comandos

| Comando | O que faz |
|---|---|
| `flutter run` | roda em debug no dispositivo/emulador |
| `flutter test` | testes |
| `flutter test --coverage` | testes com cobertura em `coverage/lcov.info` |
| `flutter analyze` | análise estática |
| `dart format .` | formatação |
| `flutter build apk --debug` | APK de debug |
| `flutter build web` | build para o navegador (precisa da pasta `web/`) |

## Variáveis de ambiente

Documentadas em [`.env.example`](.env.example). O `.env` é declarado como asset
no `pubspec.yaml` e lido em runtime pelo `flutter_dotenv` — **não vai pro git**.

A meta diária **não** vem mais do `.env`: todas as telas usam a meta do perfil
(`GET /pacientes/{id}/perfil`), que é a do plano ativo do nutricionista ou, sem
plano, a da triagem.

## Lembretes de refeição (RF26)

O paciente escolhe, em **Lembretes de refeição** (botão na home), o horário de
cada refeição e quais lembretes quer receber. O app salva os horários na API e
registra o token FCM do aparelho; o job do back-end
(`scripts/enviar_lembretes_refeicao.py`) envia o push quando a refeição ainda
não foi registrada — no máximo 1 por refeição por dia. Tocar no push abre o
histórico filtrado naquela refeição.

| Peça | Onde |
|---|---|
| Tela de horários | `features/reminders/presentation/meal_reminders_page.dart` |
| API (`/lembretes-refeicao`, `/dispositivos-push`) | `features/reminders/data/reminder_repository.dart` |
| Registro do token no login / remoção no logout | `features/reminders/application/push_registration.dart` |
| Único ponto que usa o Firebase | `features/reminders/application/firebase_push_service.dart` |

**Configuração do Firebase.** O Firebase é iniciado pelo Dart com as chaves do
`.env`, e não com `google-services.json`: as pastas `android/` e `ios/` não são
versionadas e o CI as recria. Com as 4 variáveis `FIREBASE_*` vazias (padrão do
`.env.example` e do CI) o app roda normalmente, só sem push.

1. No [Firebase Console](https://console.firebase.google.com), use o **mesmo
   projeto** do back-end (o do `FCM_CREDENTIALS_FILE`) ou crie um.
2. Adicione um app **Android** com o pacote `br.com.nutrivision.nutri_vision`
   (o gerado pelo `flutter create --org br.com.nutrivision`).
3. Baixe o `google-services.json` **só para copiar os valores** (não o coloque
   no repositório) e preencha o `.env`:

   | `.env` | Campo do `google-services.json` |
   |---|---|
   | `FIREBASE_API_KEY` | `client[0].api_key[0].current_key` |
   | `FIREBASE_APP_ID` | `client[0].client_info.mobilesdk_app_id` |
   | `FIREBASE_MESSAGING_SENDER_ID` | `project_info.project_number` |
   | `FIREBASE_PROJECT_ID` | `project_info.project_id` |

4. Em **Configurações do projeto → Contas de serviço**, gere a chave JSON e
   entregue ao back-end (`FCM_CREDENTIALS_FILE`). Esse arquivo é secreto e
   nunca vai para o git.

**Testando de ponta a ponta.**

- Use um emulador com imagem **Google Play** (sem os serviços do Google o FCM
  não funciona) — de preferência API 33+, para ver o pedido de permissão.
- Em debug, o token do aparelho aparece no log (`Token FCM: ...`): dá para
  testar pelo Firebase Console → Messaging → *Enviar mensagem de teste*.
- Ligue um lembrete para daqui a 1–2 minutos, salve e, passado o horário, rode
  `python -m scripts.enviar_lembretes_refeicao` no back-end.

**Limitações conhecidas.**

- **iOS ainda não configurado**: exige chave APNs no Firebase e as capabilities
  *Push Notifications* / *Background Modes* no Xcode (pasta `ios/` não versionada).
- A notificação usa o ícone padrão do app; um ícone próprio exige configurar o
  `AndroidManifest.xml`, que não é versionado.
- O app usa o token de registro do FCM (`getToken`), marcado como obsoleto no
  `firebase_messaging` 17 em favor do registro por *Installation ID*. O job do
  back-end envia para o token de registro, então migrar exige mudar os dois lados.
- O push só sai se o job do back-end estiver agendado (cron a cada 5 min) e com
  `FCM_CREDENTIALS_FILE` configurado.

## Registro de refeição por foto (IA)

Na aba **Registrar**, **Foto do prato** abre a câmera do app: guia de
enquadramento, flash, troca de câmera, galeria e a escolha **prato raso/fundo**,
que vai junto (`tipo_prato`) como dica para a IA. Sem câmera ou sem permissão, a
tela oferece a câmera do sistema e a galeria. A foto vai para o back-end em
`POST /analises`, que repassa ao serviço de IA
([Nutri-Vision-IA](https://github.com/Gupo-05-6-EG/Nutri-Vision-IA)); o app consulta
`GET /analises/{id}` a cada 2 s por até 3 min (a IA desiste antes, em cerca de
170 s). Se passar disso, **Continuar esperando** consulta o mesmo id, sem reenviar
a foto.

- **Deu certo:** abre a revisão com os alimentos da TACO, as gramas estimadas e a
  confiança de cada um. O paciente corrige as gramas (botões −/+ de 10 g ou
  digitando), **troca** um alimento por outro da TACO, **adiciona** um item que a IA
  não viu, exclui itens, escolhe a categoria e confirma (+20 XP). O recálculo usa
  `POST /calculo-nutricional` com o `alimento_taco_id`.
- **Registro manual:** **Adicionar manualmente** abre a mesma revisão, vazia, para
  montar a refeição com alimentos da TACO (+10 XP). Funciona sem internet.
- **Alimento fora da TACO:** a IA reconheceu, mas não está na nossa tabela — aparece
  como "Fora da TACO" e precisa ser trocado ou excluído antes de registrar.
- **Foto ruim, nada no prato ou baixa confiança:** a tela explica o motivo e oferece
  tirar outra foto (com baixa confiança, também dá para revisar os itens mesmo assim).
- **IA fora do ar ou sem internet:** avisa e permite repetir com a mesma foto.

A foto sai reduzida do aparelho (até 1600 px, JPEG 85%) e não é guardada.

> **iOS:** depois do `flutter create`, adicione ao `ios/Runner/Info.plist` as chaves
> `NSCameraUsageDescription` e `NSPhotoLibraryUsageDescription` (texto explicando que
> a foto é usada para identificar os alimentos) — sem elas o iOS fecha o app ao abrir
> a câmera. No Android não é preciso configurar nada.

| Peça | Onde |
|---|---|
| Câmera do app | `features/recognition/presentation/camera_capture_page.dart` e `data/camera_engine.dart` |
| Galeria e câmera do sistema (`image_picker`) | `features/recognition/data/photo_picker.dart` |
| Envio, consulta da análise e cálculo | `features/recognition/data/recognition_repository.dart` |
| Tela da foto e do andamento | `features/recognition/presentation/photo_analysis_page.dart` |
| Revisão e troca de alimento | `features/recognition/presentation/recognition_review_page.dart` |

## Sincronização offline de refeições (Task 2.3, RNF07)

Quando o dispositivo está sem conexão com a internet, as refeições registradas
são persistidas localmente no **Hive** com a flag `is_synced = false` e exibidas
normalmente no histórico diário com o indicador **Pendente de sincronização**.

Assim que a conectividade é restabelecida, o listener de rede
(`MealSyncService` + `ConnectivityService`) consulta todos os registros locais
com `is_synced == false` e dispara o envio em lote para a API FastAPI
(`POST /refeicoes/batch`), atualizando `is_synced = true` após `200 OK`.

| Peça | Onde |
|---|---|
| Armazenamento local (Hive) | `features/meals/data/local_meal_store.dart` |
| Modelo do registro local (`is_synced`) | `features/meals/domain/local_meal_record.dart` |
| Listener de conectividade e fila de lote | `features/meals/application/meal_sync_service.dart` |
| Fronteira de rede (`connectivity_plus`) | `core/network/connectivity_service.dart` |

## CI/CD (RNF08)

[`.github/workflows/ci.yml`](.github/workflows/ci.yml) roda a cada push e pull
request em `main`/`develop`:

1. **analyze** — `dart format --set-exit-if-changed` + `flutter analyze`
2. **test** — `flutter test --coverage`
3. **build-apk** — gera as plataformas e publica o APK de debug como artefato

## Documentação Técnica do Sistema

Para entender a arquitetura completa, integrações e modelagem de dados:
- [Documento de Arquitetura](../Documentação/ARQUITETURA.md) — Visão C4, fluxos de integração e modelo de gamificação.
- [Modelagem de Banco de Dados](../Documentação/BANCO_DE_DADOS.md) — DER completo e dicionário de dados.

## Repositórios do projeto

- [Nutri-Vision-Back-end](https://github.com/Gupo-05-6-EG/Nutri-Vision-Back-end) — API FastAPI
- [Nutri-Vision-Front-end](https://github.com/Gupo-05-6-EG/Nutri-Vision-Front-end) — este app
- [Nutri-Vision-Front-end-Web](https://github.com/Gupo-05-6-EG/Nutri-Vision-Front-end-Web) — painel React
- [Nutri-Vision-IA](https://github.com/Gupo-05-6-EG/Nutri-Vision-IA) — reconhecimento de alimentos
