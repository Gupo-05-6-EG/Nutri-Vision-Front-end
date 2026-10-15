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
    ├── foods/                    # busca manual de alimentos (RF02.2)
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
