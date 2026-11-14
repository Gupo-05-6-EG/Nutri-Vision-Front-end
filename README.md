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
| Push (lembretes) | `firebase_core` + `firebase_messaging` (FCM) |
| Lint | `flutter_lints` |
| Testes | `flutter_test` + `http/testing` (MockClient) |
| CI | GitHub Actions |

## Estrutura

Organização *feature-first* — cada requisito funcional entra como uma pasta em
`lib/features/`, sem mexer no núcleo:

```
lib/
├── main.dart                     # carrega o .env e sobe o app
├── app.dart                      # MaterialApp, tema, rota inicial
├── core/
│   ├── config/env.dart           # leitura validada do .env
│   ├── config/app_theme.dart     # tema (cores definitivas vêm da Task 1.7)
│   └── network/
│       ├── api_client.dart       # cliente HTTP + injeção do JWT
│       └── api_exception.dart
└── features/
    ├── challenges/               # desafios entre amigos e placar (RF05.2, RF05.3)
    ├── foods/                    # busca manual de alimentos (RF02.2)
    ├── meals/                    # histórico de refeições (RF04, RF12)
    ├── plan/                     # plano prescrito e progresso (RF06, RF25)
    ├── recognition/              # revisão do que a IA identificou (RF02.1, RF02.3)
    ├── reminders/                # lembretes de refeição + push FCM (RF26)
    └── health/                   # tela de diagnóstico (temporária)
test/                             # testes unitários
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

## Variáveis de ambiente

Documentadas em [`.env.example`](.env.example). O `.env` é declarado como asset
no `pubspec.yaml` e lido em runtime pelo `flutter_dotenv` — **não vai pro git**.

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

## CI/CD (RNF08)

[`.github/workflows/ci.yml`](.github/workflows/ci.yml) roda a cada push e pull
request em `main`/`develop`:

1. **analyze** — `dart format --set-exit-if-changed` + `flutter analyze`
2. **test** — `flutter test --coverage`
3. **build-apk** — gera as plataformas e publica o APK de debug como artefato

## Repositórios do projeto

- [Nutri-Vision-Back-end](https://github.com/Gupo-05-6-EG/Nutri-Vision-Back-end) — API FastAPI
- [Nutri-Vision-Front-end](https://github.com/Gupo-05-6-EG/Nutri-Vision-Front-end) — este app
- [Nutri-Vision-Front-end-Web](https://github.com/Gupo-05-6-EG/Nutri-Vision-Front-end-Web) — painel React
- [Nutri-Vision-IA](https://github.com/Gupo-05-6-EG/Nutri-Vision-IA) — reconhecimento de alimentos
