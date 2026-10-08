/// Route path constants used by GoRouter.
///
/// Design note: these paths intentionally mirror the REST resource names
/// the future Spring Boot backend will expose (see [ApiEndpoints]), e.g.
/// the screen at `/wallets` manages the same resource the backend calls
/// `GET /api/v1/wallets`. Keeping the naming symmetric makes it trivial to
/// reason about which screen talks to which endpoint later.
class AppRoutes {
  AppRoutes._();

  static const String splash = '/';
  static const String login = '/login';
  static const String register = '/register';

  static const String home = '/home';

  static const String wallets = '/wallets';
  static const String walletAdd = '/wallets/add';
  static const String walletEdit = '/wallets/edit/:id';
  static const String walletDetail = '/wallets/:id';

  static const String categories = '/categories';
  static const String categoryAdd = '/categories/add';
  static const String categoryEdit = '/categories/edit/:id';

  static const String transactions = '/transactions';
  static const String transactionAdd = '/transactions/add';
  static const String transactionEdit = '/transactions/edit/:id';

  static const String transfers = '/transfers';
  static const String transferAdd = '/transfers/add';

  static const String savingGoals = '/saving-goals';
  static const String savingGoalAdd = '/saving-goals/add';
  static const String savingGoalDetail = '/saving-goals/:id';

  static const String budgets = '/budgets';
  static const String budgetAdd = '/budgets/add';

  static const String pet = '/pet';
  static const String aiSuggestions = '/ai-suggestions';

  static const String settings = '/settings';
  static const String profile = '/profile';

  // Helper builders for parameterized routes.
  static String walletEditPath(String id) => '/wallets/edit/$id';
  static String walletDetailPath(String id) => '/wallets/$id';
  static String categoryEditPath(String id) => '/categories/edit/$id';
  static String transactionEditPath(String id) => '/transactions/edit/$id';
  static String savingGoalDetailPath(String id) => '/saving-goals/$id';
}
