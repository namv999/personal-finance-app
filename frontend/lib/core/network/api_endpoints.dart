/// All backend endpoints in one place. Nothing in the app calls these yet
/// except [SyncRepository] (deliberately stubbed) — but every repository is
/// already structured so that pointing these at a real Spring Boot server
/// is a matter of implementing the HTTP calls, not restructuring the app.
///
/// Suggested Spring Boot controller mapping (`@RequestMapping("/api/v1")`):
///   AuthController        -> auth/*
///   WalletController       -> wallets
///   CategoryController     -> categories
///   TransactionController  -> transactions
///   SavingGoalController   -> saving-goals
///   TransferController     -> transfers
///   BudgetController       -> monthly-budgets
///   PetController          -> pets
///   StreakController       -> saving-streaks
///   AiSuggestionController -> ai-suggestions
///   SyncController         -> sync/push, sync/pull
class ApiEndpoints {
  ApiEndpoints._();

  /// Overridable at build time: `--dart-define=API_BASE_URL=https://api.example.com`
  static const String baseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'https://api.your-domain.com/api/v1',
  );

  // --- Auth ---
  static const String login = '/auth/login';
  static const String register = '/auth/register';
  static const String refreshToken = '/auth/refresh';
  static const String me = '/auth/me';

  // --- Core resources (standard REST: GET/POST list, GET/PUT/DELETE {id}) ---
  static const String wallets = '/wallets';
  static const String categories = '/categories';
  static const String transactions = '/transactions';
  static const String savingGoals = '/saving-goals';
  static const String transfers = '/transfers';
  static const String monthlyBudgets = '/monthly-budgets';
  static const String pets = '/pets';
  static const String savingStreaks = '/saving-streaks';
  static const String aiSuggestions = '/ai-suggestions';

  // --- Offline sync (matches "Tóm tắt luồng đồng bộ" in the design doc) ---
  static const String syncPush = '/sync/push';
  static const String syncPull = '/sync/pull';

  static String withId(String resource, String id) => '$resource/$id';
}
