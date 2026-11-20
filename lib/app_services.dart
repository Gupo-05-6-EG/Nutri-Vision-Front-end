import 'core/config/theme_controller.dart';
import 'core/network/api_client.dart';
import 'features/achievements/data/achievement_repository.dart';
import 'features/auth/application/auth_controller.dart';
import 'features/challenges/data/challenge_repository.dart';
import 'features/foods/data/food_repository.dart';
import 'features/meals/application/meal_sync_service.dart';
import 'features/meals/data/meal_repository.dart';
import 'features/plan/data/plan_repository.dart';
import 'features/privacy/data/privacy_repository.dart';
import 'features/profile/application/profile_controller.dart';
import 'features/recognition/data/recognition_repository.dart';
import 'features/reminders/application/push_service.dart';
import 'features/reminders/data/reminder_repository.dart';
import 'features/screening/data/screening_repository.dart';
import 'features/social/data/social_repository.dart';

/// Repositorios e controladores do app, criados uma vez so em `app.dart` e
/// repassados as telas. Antes alguns eram recriados a cada rebuild da raiz.
class AppServices {
  AppServices({
    required this.client,
    required this.auth,
    required this.profile,
    required this.screening,
    required this.plans,
    required this.reminders,
    required this.push,
    required this.meals,
    required this.recognition,
    required this.challenges,
    required this.achievements,
    required this.privacy,
    this.syncService,
    ThemeController? theme,
  }) : theme = theme ?? ThemeController(store: MemoryThemePreferenceStore());

  final ApiClient client;
  final AuthController auth;
  final ProfileController profile;
  final ScreeningRepository screening;
  final PlanRepository plans;
  final ReminderRepository reminders;
  final PushService push;
  final MealRepository meals;
  final MealSyncService? syncService;
  final RecognitionRepository recognition;
  final ChallengeRepository challenges;
  final AchievementRepository achievements;
  final PrivacyRepository privacy;

  /// Modo de exibição (claro, escuro ou sistema).
  final ThemeController theme;

  /// Ranking semanal e amizades.
  late final SocialRepository social = SocialRepository(client);

  /// Busca so na TACO (trocar ou adicionar alimento na revisao da refeicao).
  late final FoodRepository tacoFoods = FoodRepository(client);

  /// Busca na TACO e nos alimentos personalizados do paciente logado.
  FoodRepository patientFoods() =>
      FoodRepository(client, patientId: auth.userId);

  int? get patientId => auth.userId;
}
