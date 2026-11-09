# Chi tiết đối chiếu class, hằng số, UI và test

> Chỉ đọc source/test. Dẫn chứng dùng `file:dòng`. Khi test chỉ assert một phần kết quả thì ghi rõ phần nào được assert; không mở rộng thành assertion không tồn tại. Secret không được sao chép.

## D1. Class inventory cho các nhóm A8 và B10

### Backend — A8

Ký hiệu: fields là khai báo trong source; `@Autowired` không dùng ở các class dưới, dependency được truyền constructor trừ nơi ghi khác. `JpaRepository<T,UUID>` là interface Spring Data.

#### (1) Auth + config + common

| Class | Fields (`name:type`) | Public methods/constructor | extends/implements/inject |
|---|---|---|---|
| `AuthController` | `service:AuthService` | `AuthController(AuthService)`; `register(RegisterRequest):AuthResponse`; `login(LoginRequest):AuthResponse` | Controller; inject service (`auth/AuthController.java:14-32`) |
| `AuthService` | `users:UserRepository`, `encoder:PasswordEncoder`, `jwt:JwtService` | `AuthService(...)`; `register(RegisterRequest):AuthResponse`; `login(LoginRequest):AuthResponse` | Service; inject 3 dependencies (`auth/AuthService.java:15-25,27-48`) |
| `JwtService` | `encoder:JwtEncoder`, `expiresDays:long` | `JwtService(JwtEncoder,long)`; `issue(UUID):String` | Service; inject encoder, config value (`auth/JwtService.java:14-24`) |
| `User` | `id:UUID`, `fullName:String`, `email:String`, `passwordHash:String`, `monthlyIncome:Long`, `createdAt:Instant`, `updatedAt:Instant`, `deleted:boolean` | public getters/setters được Lombok `@Getter/@Setter`; explicit constructor: KHÔNG TÌM THẤY | Entity; không extends custom class (`auth/User.java:11-`) |
| `UserRepository` | none | Spring Data inherited methods; `findByEmailAndDeletedFalse(String):Optional<User>`, `existsByEmail(String):boolean` | `JpaRepository<User,UUID>` (`auth/UserRepository.java:7-`) |
| `RegisterRequest` | record components `id:UUID,fullName:String,email:String,password:String` | canonical record constructor/accessors | DTO; validation annotations (`auth/dto/RegisterRequest.java:9-`) |
| `LoginRequest` | `email:String,password:String` | canonical constructor/accessors | DTO (`auth/dto/LoginRequest.java:6`) |
| `AuthResponse` | `token:String,user:UserInfo` | record constructor/accessors | DTO (`auth/dto/AuthResponse.java:3`) |
| `UserInfo` | `id:UUID,fullName:String,email:String` | record constructor/accessors | DTO (`auth/dto/UserInfo.java:5`) |
| `SecurityConfig` | none | `passwordEncoder():PasswordEncoder`; `filterChain(HttpSecurity):SecurityFilterChain` | `@Configuration`; security beans (`config/SecurityConfig.java:18-45`) |
| `JwtConfig` | none | `jwtKey(String):SecretKey`; `jwtEncoder(SecretKey):JwtEncoder`; `jwtDecoder(SecretKey):JwtDecoder` | `@Configuration`; HS256 (`config/JwtConfig.java:17-31`) |
| `ApiException` | `status:HttpStatus`, `code:String` | `ApiException(HttpStatus,String,String)`; `getStatus():HttpStatus`; `getCode():String` | extends `RuntimeException` (`common/ApiException.java:5-`) |
| `GlobalExceptionHandler` | nested record `ErrorResponse(code:String,message:String)` | `api(ApiException):ResponseEntity<ErrorResponse>`; handlers for validation, JSON, mismatch, integrity exception | `@RestControllerAdvice` (`common/GlobalExceptionHandler.java:11-42`) |

#### (2) Sync entity + repository

| Class | Fields | Public methods | extends/implements/dependency |
|---|---|---|---|
| `SyncEntity` | `id:UUID,userId:UUID,updatedAt:Instant,deleted:boolean,serverVersion:long` | public getters/setters | mapped superclass (`sync/entity/SyncEntity.java`) |
| `Wallet` | `walletName:String,walletType:String,openingBalance:Long,color:String,icon:String` | getters/setters | extends SyncEntity; `@Entity` (`Wallet.java`) |
| `Category` | `categoryName:String,type:String,color:String,icon:String` | getters/setters | extends SyncEntity (`Category.java`) |
| `SavingGoal` | `walletId:UUID,goalName:String,targetAmount:Long,expectedCompletionDate:LocalDate,status:String` | getters/setters | extends SyncEntity (`SavingGoal.java`) |
| `Transaction` | `walletId:UUID,categoryId:UUID,type:String,amount:Long,note:String,source:String,transactionDate:LocalDate,createdAt:Instant` | getters/setters | extends SyncEntity (`Transaction.java`) |
| `Transfer` | `sourceWalletId:UUID,destinationWalletId:UUID,goalId:UUID,amount:Long,transferDate:LocalDate,note:String` | getters/setters | extends SyncEntity (`Transfer.java`) |
| `MonthlyBudget` | `categoryId:UUID,month:String,spendingLimit:Long` | getters/setters | extends SyncEntity (`MonthlyBudget.java`) |
| `ScheduledTransaction` | wallet/category IDs, type, amount, note, startDate/timeOfDay, repeatUnit/every/endDate/nextDueDate | getters/setters | extends SyncEntity (`ScheduledTransaction.java`) |
| `WalletRepository` | none | inherited `JpaRepository<Wallet,UUID>`; custom: KHÔNG TÌM THẤY | extends JpaRepository (`sync/repo/WalletRepository.java:9`) |
| `CategoryRepository` | none | `findByUserIdOrUserIdIsNull(UUID):List<Category>` | extends JpaRepository (`CategoryRepository.java:9-`) |
| `SavingGoalRepository` | none | `findByUserIdAndServerVersionGreaterThanOrderByServerVersionAsc(UUID,long,Pageable):List<SavingGoal>` and user-specific query methods | extends JpaRepository (`SavingGoalRepository.java:9-`) |
| `TransactionRepository` | none | derived query methods for user/date/deleted/serverVersion; inherited CRUD/specification methods | extends `JpaRepository<Transaction,UUID>`, `JpaSpecificationExecutor<Transaction>` (`TransactionRepository.java:11-`) |
| `TransferRepository` | none | user/server-version query methods | extends JpaRepository (`TransferRepository.java:9-`) |
| `MonthlyBudgetRepository` | none | user/month/deleted and server-version query methods | extends JpaRepository (`MonthlyBudgetRepository.java:9-`) |
| `ScheduledTransactionRepository` | none | user/server-version query methods | extends JpaRepository (`ScheduledTransactionRepository.java:9-`) |

**Ghi chú chữ ký:** các entity có Lombok-generated accessor; vì method body không khai báo trong source, không liệt kê mỗi getter/setter đầy đủ. Nếu cần chữ ký bytecode-resolved, dùng `javap` sau build; không được nhầm generated members với explicit methods. Căn cứ `@Getter/@Setter` tại entity source.

#### (3) Sync service + controller + DTO chính

| Class | Fields | Public methods | Inject/relations |
|---|---|---|---|
| `SyncController` | push/pull service | constructor; `push(Jwt,PushRequest):PushResponse`; `pull(Jwt,long,int):PullResponse` | inject `SyncPushService`, `SyncPullService`; `sync/SyncController.java` |
| `SyncPushService` | TransactionTemplate; ServerVersionService; 7 repositories | constructor; `push(UUID,PushRequest):PushResponse` | inject dependencies (`sync/SyncPushService.java:25-49,69`) |
| `SyncPullService` | 7 repositories | constructor; `pull(UUID,long,int):PullResponse` | inject repositories (`sync/SyncPullService.java:27-48`) |
| `ServerVersionService` | `entityManager:EntityManager` (`@PersistenceContext`) | `next():long` | Service; SQL sequence (`sync/ServerVersionService.java:8-17`) |
| `SyncDto` | contract methods `id,userId,updatedAt,isDeleted` | interface accessors | implemented by each record DTO (`sync/dto/SyncDto.java:6-`) |
| `PushRequest` | `records:Records` | record accessors; nested `Records` has 7 lists | DTO (`PushRequest.java:5-`) |
| `PushResponse` | `results:List<PushResult>` | record accessors (`PushResponse.java:5`) | DTO |
| `PushResult` | `table:String,id:UUID,status:PushStatus,reason:RejectReason,message:String` | record accessors (`PushResult.java:5`) | DTO |
| `PushStatus` | enum constants | `APPLIED,SKIPPED_NEWER,REJECTED` | enum (`PushStatus.java:3-`) |
| `RejectReason` | enum constants | `PARENT_DELETED,FUTURE_DATE,INVALID` | enum (`RejectReason.java:3-`) |
| `PullResponse` | `changes:Changes,nextCursor:long,hasMore:boolean`; nested row records per table | record accessors | DTO (`PullResponse.java:8-`) |
| `WalletDto` | id/userId, walletName/type/openingBalance/color/icon, updatedAt/deleted | record accessors; `implements SyncDto` | `WalletDto.java:10-` |
| `CategoryDto` | id/userId/name/type/color/icon/updatedAt/deleted | record accessors; `implements SyncDto` | `CategoryDto.java:10-` |
| `SavingGoalDto` | id/userId/walletId/name/target/expected date/status/updated/deleted | record accessors; `implements SyncDto` | `SavingGoalDto.java:11-` |
| `TransactionDto` | IDs/type/amount/note/source/date/createdAt/updatedAt/deleted | record accessors; `implements SyncDto` | `TransactionDto.java:11-` |
| `TransferDto` | IDs/source/destination/goal/amount/date/note/updated/deleted | record accessors; `implements SyncDto` | `TransferDto.java:11-` |
| `MonthlyBudgetDto` | IDs/month/limit/updated/deleted | record accessors; `implements SyncDto` | `MonthlyBudgetDto.java:10-` |
| `ScheduledTransactionDto` | IDs/type/amount/note/start/time/repeat/end/nextDue/updated/deleted | record accessors; `implements SyncDto` | `ScheduledTransactionDto.java:11-` |

#### (4) AI

| Class | Fields | Public methods | Inject/relations |
|---|---|---|---|
| `AiController` | `service:AiParseService,suggestionService:AiSuggestionService,chatService:AiChatService` | constructor; `parseText(ParseTextRequest):ParseTextResponse`; `parseImage(ParseImageRequest):ParseImageResponse`; `suggest(Jwt,SuggestionRequest):SuggestionResponse`; `chat(Jwt,ChatRequest):ChatResponse` | inject 3 services (`ai/AiController.java:19-48`) |
| `AiParseService` | `gemini:GeminiClient,mapper:JsonMapper` | constructor; `parse(ParseTextRequest):ParseTextResponse`; `parseImage(ParseImageRequest):ParseImageResponse` | inject Gemini/mapper (`AiParseService.java:65-89`) |
| `AiSuggestionService` | Gemini, mapper, tx/category/budget repos | constructor; `suggest(UUID,PeriodType):SuggestionResponse` | inject 5 (`AiSuggestionService.java:57-67`) |
| `AiChatService` | Gemini, mapper, tx/category/budget repos | constructor; `chat(UUID,ChatRequest):ChatResponse` | inject 5 (`AiChatService.java:50-65`) |
| `GeminiClient` | none | `generateJson(String,String):String`; overloads with schema/image/MIME | interface (`ai/GeminiClient.java:5-`) |
| `GeminiHttpClient` | `http:RestClient,apiKey/model/fallbackModel:String` | constructor; overloads `generateJson`; internal generate/callOnce private | implements GeminiClient (`GeminiHttpClient.java:19-61`) |
| `SensitiveMasker` | static regex patterns BALANCE/ACCOUNT_KEY/CARD/PHONE/LONG_DIGITS/PARTIAL | `static mask(String):String` | final util (`SensitiveMasker.java:5-27`) |
| AI DTOs | records `ParseTextRequest/Response`, `ParseImageRequest/Response`, `SuggestionRequest/Response`, `ChatRequest/Response` | canonical constructors/accessors; nested enums/records | exact component lists are in DTO record declarations: `ai/dto/*.java` |

#### (5) Transaction query

| Class | Fields | Public methods | Inject/relations |
|---|---|---|---|
| `TransactionController` | `service:TransactionQueryService` | constructor; `list(Jwt,String,String,UUID,UUID,LocalDate,LocalDate,Long,Long,int,int):TransactionPageResponse` | inject service (`transaction/TransactionController.java:16-37`) |
| `TransactionFilter` | `q:String,type:String,walletId:UUID,categoryId:UUID,from:LocalDate,to:LocalDate,minAmount:Long,maxAmount:Long` | record constructor/accessors | DTO (`TransactionFilter.java:6-7`) |
| `TransactionQueryService` | `repo:TransactionRepository` | constructor; `search(UUID,TransactionFilter,int,int):TransactionPageResponse` | inject repo (`TransactionQueryService.java:32-44`) |
| `TransactionItem` | id/userId/walletId/categoryId UUID; updatedAt/source String; deleted boolean; type String; amount Long; note String; transactionDate/createdAt String | record accessors | DTO (`transaction/dto/TransactionItem.java:6-`) |
| `TransactionPageResponse` | `items:List<TransactionItem>,page:int,size:int,totalElements:long,totalPages:int` | record accessors | DTO (`transaction/dto/TransactionPageResponse.java:5-`) |

### Frontend — B10

Để không nhập nhằng field của 2 tầng, ký hiệu `repo` là repository cụ thể trong constructor; `notifyListeners` inherited từ ChangeNotifier không tính là method riêng. Method signature dưới đây lấy declaration; `...` chỉ dùng nếu source có nhiều optional named args—các method được gọi đúng tên để tra declaration.

#### (1) Core + Sync + Auth

| Class | Fields chính | Public method chính | Quan hệ/inject |
|---|---|---|---|
| `AuthProvider` | `_repo:AuthRepository,status:AuthStatus,currentUser:AppUser?,isLoading:bool,errorMessage:String?,onLoggedIn:Future<void> Function(String)?` | `bootstrap():Future<void>`; `login(String,String):Future<bool>`; `register(String,String,String):Future<bool>`; `logout():Future<void>`; `updateProfile({String?,int?}):Future<void>` | extends ChangeNotifier; inject AuthRepository (`providers/auth_provider.dart:7-`) |
| `AuthRepository` | `_db:DatabaseExecutor` | `register({required String fullName,email,password}):Future<AppUser>`; `login({required String email,password}):Future<AppUser>`; `getSessionUserId():Future<String?>`; `getCurrentUser():Future<AppUser?>`; `logout():Future<void>`; `updateProfile(AppUser):Future<void>` | SQLite, ApiClient, SharedPreferences; `repositories/auth_repository.dart:15-` |
| `ApiClient` | Dio instance, token, unauthorized callback (private fields) | `loadToken():Future<void>`; `saveToken(String):Future<void>`; `clearToken():Future<void>`; `get/post/put/delete` wrappers | singleton; `core/network/api_client.dart` |
| `DbHelper` | singleton, static `Database? _db` | `get database:Future<Database>` | `core/database/db_helper.dart:67-88` |
| `SyncQueueItem` | id/tableName/recordId/action/isSynced/createdAt | `fromMap`, `toMap` | model (`models/sync_queue_item.dart`) |
| `SyncRepository` | `_db:DatabaseExecutor`; static `onLocalChange:void Function()?` | `enqueue({tableName,recordId,action})`; `enqueueMany`; `getPending`; `buildPushBatch`; `splitBatch`; `markSynced`; `handleRejected`; `getCursor`; `saveCursor`; `applyPulled` | DatabaseExecutor; `repositories/sync_repository.dart:119-` |
| `SyncPushRepository` | `_sync:SyncRepository,_post:PostJson,_running:bool` | `push(String):Future<PushResult>` | inject sync + post function (`sync_push_repository.dart:27-34`) |
| `SyncPullRepository` | `pageSize:int,_sync:SyncRepository,_db:Database,_get:GetJson,_running:bool` | `resetCursor(String):Future<void>`; `pull(String):Future<PullResult>` | inject sync/db/GET (`sync_pull_repository.dart:26-37`) |
| `SyncService` | `_push,_pull,pulledTick:ValueNotifier<int>,_running:bool` | `syncAll(String):Future<SyncOutcome>` | inject push/pull (`sync_service.dart:13-23`) |
| `AutoSyncService` | sync/userId getter/callback/timers/failure state/lastSyncAt/lastError | `request({bool immediate=false}):void`; `onResume():void`; `markUnauthorized():void`; `clearUnauthorized():void`; `syncNow():Future<SyncOutcome>`; `reset():void`; `dispose():void` | extends ChangeNotifier; inject SyncService + callbacks (`auto_sync_service.dart:11-`) |

#### (2) Wallet/Category/Transaction/Transfer

| Class family | Fields | Public methods | Relations |
|---|---|---|---|
| `WalletProvider` | `_repo:WalletRepository,userId:String,wallets:List<Wallet>,isLoading:bool` | `updateUser(String):void`; `load():Future<void>`; `addWallet(...):Future<void>`; `editWallet(Wallet):Future<void>`; `deleteWallet(String):Future<void>`; `previewDelete(String):Future<WalletDeletePreview>` | ChangeNotifier→WalletRepository (`providers/wallet_provider.dart:5-`) |
| `WalletRepository` | `_db:DatabaseExecutor` | `getAll(String):Future<List<Wallet>>`; `getById(String):Future<Wallet?>`; `getOwned(String,String):Future<Wallet?>`; `create(...)`; `update(Wallet):Future<void>`; `delete(String):Future<void>`; `recomputeBalance(String):Future<int>`; `previewDelete(String):Future<WalletDeletePreview>`; `getTotalBalance(String):Future<int>` | DB + SyncRepository (`repositories/wallet_repository.dart:12-`) |
| `Wallet` | id,userId,walletName,walletType strings; currentBalance/openingBalance ints; color/icon/updatedAt strings; isDeleted bool | ctor/fromMap/toMap/toJson/copyWith | model (`models/wallet.dart:4-`) |
| `CategoryProvider` / `CategoryRepository` / `TransactionCategory` | provider repo/user/categories/loading; repository DB; model id/user/name/type/color/icon/timestamps/deleted | load/CRUD; repo get/create/update/delete; model converters | constructor injection; source `providers/category_provider.dart`, `repositories/category_repository.dart`, `models/category.dart` |
| `TransactionProvider` | `_repo,userId,transactions,isLoading` | `load():Future<void>`; `fetchByWallet(String):Future<List<FinanceTransaction>>`; `addTransaction(...)`; `editTransaction(FinanceTransaction):Future<void>`; `deleteTransaction(String,String):Future<void>`; `expenseByCategoryForMonth(DateTime):Future<Map<String,int>>` | repo injection (`providers/transaction_provider.dart:8-`) |
| `TransactionRepository` | `_db:DatabaseExecutor` | `getAll(...)`; `create(...)`; `validateRefs(...)`; `update(FinanceTransaction)`; `delete(String,String)`; `getTotalsByType(...)`; `getExpenseByCategory(...)` | DB + Sync/Wallet/Streak repo (`repositories/transaction_repository.dart:13-`) |
| `FinanceTransaction` | ids/type/note/source strings; amount int; transactionDate/createdAt/updatedAt DateTime; isDeleted bool | fromMap/toMap/toJson/copyWith | `models/transaction.dart:17-` |
| `TransferProvider` / `TransferRepository` / `Transfer` | provider repo/user/transfers/loading; repo executor; transfer id/user/source/destination/goal, amount/date/note/deleted | provider load/create/delete; repo `getAll(String,{int? limit})`, `create({...})`, `delete(Transfer)` | `providers/transfer_provider.dart`; `repositories/transfer_repository.dart:13-`; `models/transfer.dart:6-` |

#### (3) SavingGoal/Budget/Pet/Streak

| Class family | Fields | Public methods | Relations |
|---|---|---|---|
| `SavingGoalProvider` | repository/userId/goals/loading | `load`; `create`; `update`; `delete` | ChangeNotifier→SavingGoalRepository (`providers/saving_goal_provider.dart`) |
| `SavingGoalRepository` | DB executor | get/create/update/delete/recomputeSavedAmount | inject/use SyncRepository, Transfer query (`repositories/saving_goal_repository.dart`) |
| `SavingGoal` | id,user/wallet,name,status strings; target/saved ints; date; updated/deleted | fromMap/toMap/copyWith; `progress:double` | `models/saving_goal.dart` |
| `BudgetProvider` | budget repo, transaction repo, userId, budgets, selectedMonth/loading/status | `load`; `setBudget({String? id,required String categoryId,required int limit})` | ChangeNotifier; inject two repos (`providers/budget_provider.dart`) |
| `BudgetRepository` | DB executor | get/list/create-or-update/delete by user/category/month/limit | `repositories/budget_repository.dart` |
| `MonthlyBudget` | ids/category/month strings, spendingLimit int, updatedAt, deleted | fromMap/toMap | model (`models/monthly_budget.dart`) |
| `PetStreakProvider` | PetRepository, SavingStreakRepository,userId,pet,streak,loading | `load`, rename/recompute (see source declarations) | ChangeNotifier inject two repositories (`providers/pet_streak_provider.dart`) |
| `PetRepository` | `_db:DatabaseExecutor` | `createDefaultForUser(String):Future<void>`; `getForUser(String):Future<Pet?>`; `setTotalExperience(String,int):Future<void>`; `rename(String,String):Future<void>` | `repositories/pet_repository.dart:10-` |
| `SavingStreakRepository` | `_db:DatabaseExecutor,_pets:PetRepository` | `createDefaultForUser(String):Future<void>`; `getForUser(String):Future<SavingStreak?>`; `recompute(String):Future<void>` | inject DB, constructs PetRepository (`saving_streak_repository.dart:9-`) |
| `Pet`, `SavingStreak` | model persisted columns: pet fields / streak fields | fromMap/toMap/copyWith as declared | `models/pet.dart`,`models/saving_streak.dart` |

#### (4) AI: pending/suggestion/chat/SMS

| Class | Fields | Public methods | Relations |
|---|---|---|---|
| `PendingProvider` | pending repo,userId,items/loading/busy/lastRun | `load`; `submitText`; `scanSms`; `scanImage`; `confirm`; `reject`; `retry` | ChangeNotifier→PendingTransactionRepository (`providers/pending_provider.dart`) |
| `PendingTransactionRepository` | DB executor | `addText`, `retryNeedsAi`, `addImage`, `confirm`, `reject` | DB, Dio/ApiClient, TextMasker, TransactionRepository (`repositories/pending_transaction_repository.dart`) |
| `PendingTransaction` | id/user/source/hash/status + maskedContent, amount/type/date/note/category/confidence | fromMap/toMap/copyWith | `models/pending_transaction.dart` |
| `AiSuggestionProvider` | repo,AutoSyncService,userId,periodType,current,isLoading,isRequesting,lastOutcome | `load():Future<void>`; `setType(AiPeriodType):Future<void>`; `requestNew():Future<SuggestOutcome>`; getters suggestions/targetPeriod | ChangeNotifier inject repo+sync (`providers/ai_suggestion_provider.dart:7-`) |
| `AiSuggestionRepository` | `_db:DatabaseExecutor` | `getForPeriod(String,AiPeriod):Future<List<AiSuggestion>>`; `requestSuggestion(String,AiPeriodType):Future<SuggestOutcome>` | DB/API (`repositories/ai_suggestion_repository.dart:21-`) |
| `AiSuggestion`, `AiPeriod` | cache fields / type,start,end | `AiPeriod.of`, `AiPeriod.next`; model fromMap/toMap | `models/ai_suggestion.dart:13-` |
| `AiChatProvider` | repo,messages,isSending | `clear():void`; `send(String):Future<void>` | ChangeNotifier→AiChatRepository (`providers/ai_chat_provider.dart`) |
| `AiChatRepository` | no instance state; `static const maxMessages:int=6` | `ask(List<ChatMessage>):Future<ChatOutcome>` | ApiClient/Dio; `repositories/ai_chat_repository.dart:31-` |
| `ChatMessage`, `ChatOutcome` | `fromUser:bool,text:String,isError:bool`; status/reply/message | const constructors | same file:15-28 |
| `SmsReader` | static plugin usage | `status():Future<SmsPermission>`; `request():Future<SmsPermission>`; `readInbox({int count=300,Duration within=30d}):Future<List<RawSms>>` | `core/sms/sms_reader.dart:13-` |
| `BankSmsFilter` | static RegExp amount/keyword/otp | `looksLikeTransaction(String?):bool` | util (`core/sms/bank_sms_filter.dart:2-`) |
| `TextMasker` | static regexes | `mask(String):String`; `hash(String,String):String`; `hashBytes(String,List<int>):String` | crypto SHA-256 (`core/utils/text_masker.dart:7-`) |

#### (5) Scheduled + Notification

| Class | Fields | Public methods | Relations |
|---|---|---|---|
| `ScheduledProvider` | repo,sync,userId,items,due,isLoading,isBusy | `start`, `load`, `create`, `update`, `delete`, `confirm`, `cancel`, `skipAllDue` | ChangeNotifier inject repo/sync (`providers/scheduled_provider.dart`) |
| `ScheduledTransactionRepository` | `_db:DatabaseExecutor` | `getAll(String)`, `create(...)`, `update(ScheduledTransaction)`, `delete(String,String)`, `getDue(String,{String? nowKey})`, `confirm(...)`, `cancel(...)`, `skipAllDue(String)`, `reconcileAfterPull(String)` | DB/transaction/sync (`repositories/scheduled_transaction_repository.dart:20-`) |
| `ScheduledTransaction` | ids/type/source fields; amount; start/date/time/repeat/end/nextDue; updated/deleted | getters `rule`; fromMap/toMap/copyWith | `models/scheduled_transaction.dart` |
| `RepeatUnit`, `RepeatUnitX`, `RecurrenceRule` | rule `startDate:String,unit:RepeatUnit?,every:int?,endDate:String?` | `fromValue(String?):RepeatUnit?`; `dateAt(int):String`; `nextAfter(String):String?` | `core/utils/occurrence.dart:3-` |
| `DueGate` / `_DueGateState` | navigator key/callback; timer/lifecycle state | `createState`; state lifecycle/build methods | StatefulWidget/WidgetsBindingObserver (`core/scheduled/due_gate.dart:9-`) |
| `NotificationService` | singleton plugin, `tapTick:ValueNotifier<int>`, `_ready:bool`; constants channel/test id/limits | `init():Future<void>`; `ensurePermissions():Future<bool>`; `scheduleTest(Duration):Future<String>`; `pendingCount():Future<int>`; `cancelAll():Future<void>`; `reschedule(List<ScheduledTransaction>):Future<void>` | singleton wrapping notifications (`core/notifications/notification_service.dart:9-`) |
| `DueOccurrence` | scheduledId/occurrence date/index (source model declaration) | ctor and occurrence helpers | `models/scheduled_transaction.dart` / `occurrence.dart` |

**Giới hạn inventory:** bảng D1 ưu tiên classes nằm trong A8/B10 và DTO chính; source-only nested records/enums/helpers và complete named-argument signatures của mọi CRUD form chưa được expanded hết: CHƯA XÁC MINH. Không thêm member không khai báo. Mỗi group/file path nêu trong bảng là nơi đối chiếu declaration.

## D2. Hằng số chính xác

| Nội dung | Giá trị | Evidence |
|---|---|---|
| image picker | `maxWidth:1600`; `maxHeight` không truyền (comment loại trừ để giữ chiều dọc hóa đơn); `imageQuality:85` | `frontend/lib/screens/pending/pending_inbox_screen.dart:134-140` |
| Suggestion HTTP timeout/cache | `receiveTimeout:60s`; cache SQLite key `(user_id,period_type,period_start)`; upsert `ConflictAlgorithm.replace`; không có TTL/expiration trong repo | `frontend/lib/repositories/ai_suggestion_repository.dart:25-35,38-63`; unique DB `db_helper.dart:151-162` |
| Chat | `maxMessages=6`; bỏ message `isError`; gửi 6 message gần nhất; `receiveTimeout=60s`; không lưu lịch sử DB, provider giữ list trong memory | `ai_chat_repository.dart:31-80`; `providers/ai_chat_provider.dart` |
| Suggestion minimum/window | min 10 transactions AND span >=14 days WEEK, >=28 days MONTH, AND expenseTotal !=0. History window 4×7=28 calendar days (WEEK) hoặc 3×30=90 days (MONTH), inclusive from date through today. Period next: next Monday..Sunday; monthly first..last next month. | `backend/ai/AiSuggestionService.java:30-31,69-83`; `frontend/models/ai_suggestion.dart:13-30` |
| Pet XP | `15 × số ngày transfer savings đủ điều kiện (distinct transfer_date) + 5 × số transaction active`; XP thresholds 100, then level×100 per next level; leftover stored as XP; shape small <5, medium 5..9, large >=10 | `frontend/lib/repositories/saving_streak_repository.dart:26-77`; `pet_repository.dart:26-45` |
| Streak | eligible distinct dates from transfer into goal wallet (or goal wallet null); consecutive days count; current alive when last saved today/yesterday, else 0 | `saving_streak_repository.dart:26-68` |
| Bank SMS amount | `\d[\d.,]*\s*(vnd|vnđ|đ)(?![a-z0-9])` | `frontend/lib/core/sms/bank_sms_filter.dart:5-8` |
| SMS keywords | `giao dich|giao dịch|\bgd\b|\btk\b|so du|số dư|\bsd\b|bien dong|biến động|thanh toan|thanh toán|chuyen khoan|chuyển khoản|nhan tien|nhận tiền|rut tien|rút tiền|nap tien|nạp tiền` | `bank_sms_filter.dart:9-14` |
| SMS exclusion | `\botp\b|ma xac thuc|mã xác thực|ma xac nhan|mã xác nhận|mat khau|mật khẩu`; accepted only if amount AND keyword and NOT otp | `bank_sms_filter.dart:15-26` |
| Masker backend patterns | balance: `\b(?:số dư|so du|sd|balance)\s*(?:cuối)?\s*[:=]?\s*[+-]?\d[\d.,]*\s*(?:vnd|vnđ|đ)?`; account keyword `\b(stk|tk|a/c|acc)\s*[:.]?\s*\d{6,}`; card `(?<!\d)(?:\d{4}[ -]){3}\d{4}(?!\d)`; phone `(?<!\d)(?:\+84|84|0)\d{9}(?!\d)`; long digit `(?<!\d)\d{10,19}(?!\d)`; partial `[*xX]{2,}\d{2,}` | `backend/src/main/java/com/pfm/backend/ai/SensitiveMasker.java:6-14` |

## D3. Ví dụ thực tế trong test

### Masker

Backend `AiParseServiceTest.masksSensitiveDataAndLeavesAmounts` dùng các input dưới đây. Test chỉ assert loại chuỗi bị che/giữ, không assert toàn bộ chuỗi output; output cụ thể dưới đây là áp dụng `SensitiveMasker.mask` theo thứ tự regex trong source, không phải expected literal của JUnit.

| Input trong test | Assertion/output theo code | Evidence |
|---|---|---|
| `gọi 0912345678 nhé` | không còn số điện thoại; code thay bằng `[SDT]` → `gọi [SDT] nhé` | `backend/src/test/java/com/pfm/backend/ai/AiParseServiceTest.java:76-79`; masker `SensitiveMasker.java:21-26` |
| `thẻ 1234 5678 9012 3456` | assert không còn `5678`; code output `thẻ [THE]` | same test:78-80; masker:23 |
| `STK 1234567890123` | assert không còn dãy; account pattern output `STK [SO]` | same test:80; masker:22 |
| `-50,000 VND` | assert còn `50,000`; unchanged | same test:81 |
| Cặp thứ năm | KHÔNG TÌM THẤY; backend test chỉ có bốn calls to mask trong method này. | `AiParseServiceTest.java:76-81` |

Frontend `TextMasker` test có 5 input cases. Assertions chính xác là contains/not-contains; không so sánh full output trừ case đã mask sẵn.

| Input | Output/behavior asserted | Evidence |
|---|---|---|
| `TK 0123456789 -50,000 VND luc 26/10 14:05 SD: 1,234,000 VND LH 0901234567` | giữ `50,000`, `14:05`; không còn account, `1,234,000`, phone | `frontend/test/text_masker_test.dart:5-14` |
| `Số dư 5.000.000 VND` | chứa `[đã ẩn số dư]`; không còn `5.000.000` | `text_masker_test.dart:16-20` |
| `the 1234 5678 9012 3456` | chứa `***`; không còn `1234` | `:22-26` |
| `LH 090 123 4567` | chứa `***`; không còn `4567` | `:28-32` |
| `TK ****1234 -50.000đ` | output đúng nguyên văn input | `:34-37` |

### JSON test cho AI endpoints

| Endpoint | Request fixture | Response fixture/được assert |
|---|---|---|
| `/ai/parse-text` | `{"items":[{"ref":"00000000-0000-4000-8000-000000000010","source":"TEXT","content":"-50,000 VND"}],"categories":[{"id":"00000000-0000-4000-8000-000000000003","category_name":"Ăn uống","type":"EXPENSE"}]}` | Test asserts HTTP 200, `results[0].status=PARSED`, `suggestion.amount=50000`, `suggestion.category_id=00000000-0000-4000-8000-000000000003`. Full response literal: KHÔNG TÌM THẤY; test không assert all fields. `backend/src/test/java/com/pfm/backend/ai/AiParseIntegrationTest.java:36-48` |
| `/ai/parse-image` | Helper `body(jpeg(0),"image/jpeg")`; JPEG byte[] length32 with FF D8 FF marker, category id above; base64 tạo runtime trong test | Test asserts status PARSED, amount10000, note `Chuyen den [SO]`, category id. Full response literal không được assert. `AiParseImageIntegrationTest.java:18-30,38-45` |
| `/ai/suggestions` | `{"period_type":"WEEK"}` | Successful test asserts `status=OK`, `period_type=WEEK`, `data.avg_expense=182609`, top category avg 182609/share100, `content="- OK"`; generated from 12 x 50,000 expense transactions every 2 days. `AiSuggestionIntegrationTest.java:39-58` |
| `/ai/chat` | `{"messages":[{"role":"USER","content":"Tháng này tôi chi nhiều nhất vào đâu?"}]}` | With 5 seeded expense transactions, asserts `status=OK`,`reply="OK"`; full JSON response is not asserted. `AiChatIntegrationTest.java:47-70` |

Image fixture response from fake Gemini input contains numeric account number; endpoint response masks it before returning. Fake fixture at `AiParseImageIntegrationTest.java:74-80`; visible expected note at `:43-45`.

## D4. Màn hình: fields, buttons, validation, states

Các form validation dùng chung `Validators` exact messages: required `$field không được để trống`; `Email không được để trống`; `Email không hợp lệ`; `Mật khẩu phải có ít nhất 6 ký tự`; `Vui lòng nhập số tiền`; `Nhập số nguyên lớn hơn 0` (`frontend/lib/core/utils/validators.dart:5-31`). Bảng dưới ghi control/strings khác riêng từng screen. Các trạng thái loading/empty/error chỉ ghi khi có source widget/branch; không đồng nhất loading toàn app.

| Màn hình/file | Trường nhập | Nút/hành động | Validation/thông báo chính xác | Loading/empty/error |
|---|---|---|---|---|
| `splash_screen.dart` | — | — | — | logo + CircularProgressIndicator; `:17-22` |
| `auth/login_screen.dart` | Email, mật khẩu | Đăng nhập; Đăng ký ngay | Validators email/password; SnackBar `auth.errorMessage ?? 'Đăng nhập thất bại'` (`:31-35,61-87`) | submit button spinner, disabled khi loading (`:77-82`) |
| `auth/register_screen.dart` | Họ và tên, email, mật khẩu | Đăng ký; Đã có tài khoản? Đăng nhập | required full name, email/password; SnackBar fallback `Đăng ký thất bại` (`:33-35,52-84`) | button spinner (`:75-80`) |
| `home/home_screen.dart` | — | Ví của tôi, Xem tất cả, pet link | — | wallet loading; empty expense `Chưa có chi tiêu tháng này`, recent `Chưa có giao dịch nào` (`:37-38,255,354`) |
| `home/home_shell.dart` | — | nav tabs, FAB theo tab: transaction/wallet/goal | — | child tab controls respective loading |
| `home/more_menu_screen.dart` | — | các tile module/profile | — | pending badge; list menu (`:42-57`) |
| `wallets/wallet_list_screen.dart` | — | add, detail, delete dialog | EmptyState when wallets none | LoadingView then empty/list (`:19-22`) |
| `wallets/wallet_detail_screen.dart` | — | edit/delete, transaction history | Snackbar delete flow via dialog | screen loading; `Ví không còn tồn tại`; history loading/empty (`:53-60,118-121`) |
| `wallets/wallet_form_screen.dart` | Tên ví, loại ví, số dư ban đầu/hiện tại, color/icon | Lưu/tạo ví; delete khi edit | `Tên ví không được để trống`; khi sửa số dư: `Vui lòng nhập số tiền` nếu rỗng, `Nhập số nguyên không âm` nếu không phải số nguyên không âm; khi tạo gọi `Validators.positiveAmount` (`frontend/lib/screens/wallets/wallet_form_screen.dart:40-46,184-204`) | save disabled while saving (`:119-120,184-217`) |
| `categories/category_list_screen.dart` | — | add/edit | empty `Chưa có danh mục` | LoadingView then empty/list (`:25-50`) |
| `categories/category_form_screen.dart` | Tên danh mục, type chi/thu, icon/color | Tạo danh mục/Lưu thay đổi/delete | `Tên danh mục không được để trống`; errors surfaced in SnackBar (`:56-59,122-148`) |
| `transactions/transaction_list_screen.dart` | — | add/edit | empty state; no form validation | LoadingView then empty/list (`:26-30`) |
| `transactions/transaction_form_screen.dart` | type, amount, wallet, category, note, date | Thêm giao dịch/Lưu thay đổi/delete | amount validators; wallet `Vui lòng chọn ví`; no wallet state `Bạn cần có ít nhất 1 ví` / `Hãy tạo ví trước khi ghi thu chi.`; errors shown SnackBar (`:127-129,153-173,219-265`) |
| `transfers/transfer_list_screen.dart` | — | add transfer | empty state; if <2 wallets button directs add-wallet | loading/empty (`:27-31,85-86`) |
| `transfers/transfer_form_screen.dart` | source wallet, destination wallet, amount, optional goal, date, note | Chuyển khoản; add wallet | `Chọn ví nguồn`, `Chọn ví đích`, amount validator, `Ví nguồn và ví đích không được trùng nhau`; repo errors e.g. insufficient balance (`:109-138,227-252`) |
| `saving_goals/saving_goal_list_screen.dart` | — | add/open detail | empty state | loading/empty (`:20-24`) |
| `saving_goals/saving_goal_detail_screen.dart` | — | Nạp thêm tiền vào mục tiêu, edit/delete | snackbar `Cần ít nhất 2 ví để nạp tiền vào mục tiêu` | LoadingView; `Mục tiêu không tồn tại`; progress spinner (`:50-52,66,98-112`) |
| `saving_goals/saving_goal_form_screen.dart` | Tên mục tiêu, target amount, optional wallet/date | Tạo mục tiêu | `Tên mục tiêu không được để trống`, amount validators; errors snackbar (`:79-90`) |
| `budgets/budget_list_screen.dart` | — | previous/next month, add/edit/delete | empty state | LoadingView (`:26-45`) |
| `budgets/budget_form_screen.dart` | category, monthly limit | Lưu ngân sách | `Chọn danh mục`, positiveAmount messages; repository error snackbar (`:33-37,61-73`) |
| `pet/pet_screen.dart` | pet name in dialog | save/cancel rename | KHÔNG TÌM THẤY explicit validator; empty string handling CHƯA XÁC MINH | LoadingView (`:18-20`) |
| `pending/paste_message_screen.dart` | multiline message, max1000 | Phân tích | empty/too long exact `Yêu cầu nhập nội dung không quá 1000 ký tự.`; duplicate `Tin nhắn đã có trong hộp thư.`; status/error messages (`:53-57,139-157`; test lines 422-459) | spinner + `Đang phân tích...` (`:148-154`) |
| `pending/pending_inbox_screen.dart` | review sheet: amount,note,type,wallet,category,date | scan SMS, choose image, paste, retry, bỏ qua, Kiểm tra & xác nhận, Xác nhận | amount validator exact `Nhập số tiền lớn hơn 0`; SMS blocked `Quyền SMS đang bị chặn.`; image errors e.g. `Có lỗi, vui lòng thử lại.` (`frontend/lib/screens/pending/pending_inbox_screen.dart:802-808,283-316,523-573`) | busy disables scan; empty state; needs-AI/review sections; confirmation spinner (`:283-316,889-900`) |
| `ai_suggestions/ai_suggestion_screen.dart` | WEEK/MONTH selector | refresh/request | SnackBar statuses incl `Có lỗi, vui lòng thử lại` | LoadingView; insufficient/empty states; request spinner (`:68-73,151-200,225-234`) |
| `ai_chat/ai_chat_screen.dart` | chat input | send, clear | input blank handling in provider; status prompts | disables send while sending; suggestion prompts when empty (`:70-140`) |
| `scheduled/scheduled_list_screen.dart` | — | add/edit/delete | empty state | LoadingView then empty/list (`:57-60`) |
| `scheduled/scheduled_form_screen.dart` | type, amount, wallet, category, date/time, repeat unit/every/end date, note | save/delete | `Số tiền` uses positiveAmount; wallet `Vui lòng chọn ví`; repeat invalid `Chu kỳ lặp phải từ 1 đến 365`; repository throws `Ngày hoặc giờ không hợp lệ`, `Chu kỳ lặp không hợp lệ`, `Chu kỳ lặp phải từ 1 đến 365`, `Giao dịch một lần không có ngày kết thúc`, `Ngày kết thúc không được trước ngày bắt đầu`, `Thời điểm hẹn phải ở tương lai` (`scheduled_transaction_repository.dart:47-74`; screen:398-418,515-`) | Loading/error Snackbar for missing schedule; save state |
| `scheduled/due_dialog.dart` | amount override | confirm, cancel, skip missed | positive amount / repo error visible `_errorMessage`; skip dialog `Bỏ qua $count kỳ?` (`:50-72,107-119`) | due occurrence list/progress |
| `settings/settings_screen.dart` | none | sync now, test sync, reset cursor, profile | sync SnackBars; confirmation `Tạo giao dịch kiểm thử?`; no field validation (`:48-90,127-150`) | sync status/loading based AutoSync |
| `settings/profile_screen.dart` | full name, readonly email, monthly income | Lưu thay đổi | required full name; success `Đã lưu thay đổi` (`:40,59-69`) |

**Chuỗi exact chưa trích:** Wallet `_validateBalance` và Pending review sheet custom validators cần dùng file lines indicated; chưa dán lời nhắc suy diễn. Loading/error branches khác ở each file; các entries không ghi state không có state-specific branch được xác nhận trong lần trích này: CHƯA XÁC MINH.

## D5. AutoSync

| Trigger/tình huống | Hành vi |
|---|---|
| Ghi local | `SyncRepository.onLocalChange` gọi `AutoSyncService.request`; debounce 3 giây, mỗi lần mới reset timer (`auto_sync_service.dart:15,39-43`; hook `app.dart:88`) |
| Auth transition | authenticated + token → immediate request; unauthenticated → reset (`app.dart:120-135`) |
| Resume | nếu `lastSyncAt` có và tuổi <30s thì skip; ngược lại immediate (`AutoSyncService.onResume`, `:46-49`). Không có timer định kỳ/periodic trigger: KHÔNG TÌM THẤY (`auto_sync_service.dart:15-168`) |
| Network/general error | retries 30,60,120,300 seconds; sau index cuối lặp lại 300s (`:17,153-163`) |
| BUSY | retry cố định sau 5s (`:113-124`) |
| 401 | markUnauthorized; hủy retry/debounce; không tự thử lại đến khi relogin clears state (`:51-62,101-104`) |
| No token/no user/disposed | bỏ trigger; không enqueue retry (`:34-37,75-84`) |
| Success | reset failure, set `lastSyncAt`, clear error, refresh providers nếu pull applied hoặc rejected (`:126-148`) |

## D6. Test method names

### Backend

| Test class | Method names (mỗi tên là một test; `@TestConfiguration`/helper không tính) |
|---|---|
| `AuthIntegrationTest` | `registerThenLogin`; `registerDuplicateEmail`; `registerDuplicateId`; `loginWrongPassword`; `registerShortPasswordIsRejected` (`backend/src/test/java/com/pfm/backend/AuthIntegrationTest.java:25-60`) |
| `BackendApplicationTests` | `contextLoads` (`.../BackendApplicationTests.java:11-12`) |
| `ScheduledSyncIntegrationTest` | `pushThenPullReturnsAllFields`; `olderVersionIsSkipped`; `pastStartDateIsAccepted`; `missingWalletIsInvalid`; `deletedWalletIsParentDeleted`; `deletingScheduledUnderDeletedWalletIsApplied`; `invalidRulesAreRejected`; `pullIsIsolatedBetweenUsers` (`.../ScheduledSyncIntegrationTest.java:26-116`) |
| `SyncIntegrationTest` | `pushWalletThenOlderVersionIsSkipped`; `transactionWithFutureDateIsRejected`; `transactionWithMissingWalletIsInvalid`; `transactionWithDeletedWalletIsParentDeleted`; `pullPaginatesByCursor`; `pullIsIsolatedBetweenUsers`; `pullInvalidLimitReturns400`; `pullWithoutTokenReturns401` (`.../SyncIntegrationTest.java:13-94`) |
| `TransactionSearchIntegrationTest` | `noFilterSortsByDateDescAndSkipsDeleted`; `filterByType`; `filterByCategory`; `searchNoteIsCaseInsensitive`; `likeSpecialCharsAreLiteral`; `filterByAmountRange`; `filterByDateRange`; `pagination`; `otherWalletAndOtherUserSeeNothing`; `invalidParamsReturn400`; `invertedRangesReturn400`; `withoutTokenReturns401` (`.../TransactionSearchIntegrationTest.java:35-113`) |
| `AiChatIntegrationTest` | `insufficientDataDoesNotCallAi`; `computesMonthlyTotalsAndSendsOnlySafePromptData`; `lastMessageMustBeUser`; `rejectsMoreThanSixMessages` (`.../ai/AiChatIntegrationTest.java:38-93`) |
| `AiParseErrorIntegrationTest` | `rateLimitReturns429` (`.../ai/AiParseErrorIntegrationTest.java:19-29`) |
| `AiParseImageIntegrationTest` | `requiresAuthentication`; `parsesImageAndMasksNote`; `notATransaction`; `rejectsMimeMismatch` (`.../ai/AiParseImageIntegrationTest.java:32-60`) |
| `AiParseIntegrationTest` | `requiresAuthentication`; `validatesRequestBeforeCallingAi`; `returnsParsedResultWithFakeGemini` (`.../ai/AiParseIntegrationTest.java:15-48`) |
| `AiParseServiceTest` | `parsedAndDateFallback`; `rejectsInvalidJsonAmountTypeAndMissingIndexAsFailed`; `notTransactionAndInvalidCategory`; `propagatesRateLimit`; `masksSensitiveDataAndLeavesAmounts` (`.../ai/AiParseServiceTest.java:41-82`) |
| `AiSuggestionIntegrationTest` | `insufficientDataDoesNotCallAi`; `backendComputesFigures`; `invalidPeriodTypeIs400` (`.../ai/AiSuggestionIntegrationTest.java:31-65`) |

Description corresponds to method names; test assertions detail: Auth register/login and duplicate/invalid; Scheduled sync fields/version/future/ownership/deletion/rules/pull; Sync LWW/future/parent/cursor/auth; Transaction filters/order/page/isolation/validation; AI methods named self-descriptively and listed at source evidence above.

### Frontend

| Test file | Test methods (names are literal descriptions in test declarations) |
|---|---|
| `ai_suggestion_screen_test.dart` | `Header displays SegmentedButton and period label`; `EmptyState shown when current is null`; `isRequesting disables button and shows spinner`; `insufficientData displays info card and not a SnackBar`; `Error outcomes display expected SnackBar messages`; `syncFailed with BUSY message displays busy SnackBar` (`frontend/test/ai_suggestion_screen_test.dart:86-`) |
| `auto_sync_service_test.dart` | `successful changed sync records time and refreshes data`; `received but unapplied records do not refresh data`; `unauthorized sync pauses future auto requests` (`:40-`) |
| `budget_status_bar_test.dart` | `1. Chi 600.000 / 1.000.000: safe, 60%, "Còn 400.000"`; `2. Chi 750.000 / 1.000.000: warning, 75%, "Sắp hết, còn 250.000"`; `3. Chi 1.000.000 / 1.000.000: warning, 100%, "Sắp hết, còn 0"`; `4. Chi 1.000.001 / 1.000.000: exceeded, "Vượt 1", warning icon, AppColors.danger`; `Chi 1.500.000 / 1.000.000: shows 150% and clamped 1.0 barFill`; `showLabel: false hides the label row` (`budget_status_bar_test.dart:9-`) |
| `image_helpers_test.dart` | `hashBytes is stable and scoped to the user`; `sniffMime recognizes jpeg, png, webp, and rejects other data` (`:8-`) |
| `pending_screens_test.dart` | `Displays Hộp thư chờ duyệt with badge and Dán tin nhắn`; `parsed item opened from inbox keeps back to More screen`; `parsed item entered from More retains a back route`; `Has multiline TextField, 1000 max length, disclaimer and Phân tích button`; `Shows invalid outcome message when text is empty`; `Shows duplicate outcome message when duplicate`; `Shows queued message based on provider.lastRun`; `Empty inbox shows EmptyState and calls load + retryNeedsAi on init`; `Displays Đề xuất cần bạn xác nhận and Đang chờ phân tích sections with correct info`; `Tapping Kiểm tra & xác nhận opens edit sheet and confirms without displaying wallet balance` (`pending_screens_test.dart:257-`) |
| `recurrence_rule_test.dart` | `month end is clamped without drifting`; `leap day yearly recurrence`; `biweekly and every three days`; `end date and one-time occurrence`; `occurrence UUID v5 is deterministic` (`:6-`) |
| `scheduled_screens_test.dart` | `MoreMenuScreen contains Giao dịch hẹn trước tile`; `shows empty state when no items`; `displays items with note, amount, wallet, next due, and repeat`; `delete button opens confirm dialog and calls remove`; `renders all fields and creates one-time transaction`; `checking Lặp lại shows recurrence options and end date`; `editing schedule shows change note when schedule modified`; `displays due occurrence and confirms it`; `multiple occurrences show progress and skip all button` (`frontend/test/scheduled_screens_test.dart:330-621`) |
| `sync_repository_test.dart` | `LWW preserves newer local rows and applies newer remote rows`; `ignores records belonging to another user`; `newer natural-key budget wins and queues the displaced row`; `push sends current snapshot and leaves queue rows added after snapshot`; `GDHT: pull áp dụng bản mới, giữ bản local mới hơn`; `GDHT: push batch có bảng scheduled_transactions`; `GDHT: xác nhận tạo giao dịch id xác định, đẩy kỳ sau, tính lại số dư`; `GDHT: kỳ đã có giao dịch (kể cả đã xóa) không bị tạo lại`; `GDHT: getDue gom các kỳ đã lỡ, cũ nhất trước`; `G5: xóa ví xóa mềm GDHT của ví đó, ghi queue, không đụng ví khác` (`:61-`) |
| `text_masker_test.dart` | `giữ số tiền và giờ, che tài khoản/số dư/SĐT`; `che số dư dạng "Số dư"`; `che số thẻ có khoảng trắng`; `che SĐT có khoảng trắng`; `giữ nguyên số tài khoản đã che sẵn`; `hash ổn định với khoảng trắng và hoa/thường`; `hash khác nhau giữa 2 user` (`:5-`) |
| `transaction_flow_test.dart` | `creating a transaction returns to the transaction list` (`:155-`) |
| `wallet_delete_dialog_test.dart` | `WalletDeleteDialog displays preview details and 6s countdown`; `WalletDeleteDialog Cancel button dismisses dialog`; `empty wallet can be confirmed without countdown`; `scheduled transactions alone show warning and countdown` (`:29-`) |
| `wallet_flow_test.dart` | `first wallet creation returns to wallet list`; `deleting the last wallet returns to required creation screen`; `editing a wallet exposes its current balance` (`:81-`) |
| `widget_test.dart` | `Formatters formats currency correctly`; `businessToday returns non-empty UTC+7 date string`; `WalletDeletePreview holds correct stats` (`:7-`) |

**Giới hạn đối chiếu:** một số bảng phía trên ghi nhóm class tổng hợp hoặc chữ ký `...`; đó là dấu hiệu nội dung chưa được expanded thành từng declaration đầy đủ và cần đối chiếu source tại file path được nêu. Không được xem chúng là chữ ký chính xác. Các line citation dùng `file:line` hoặc range dòng tại declaration/assertion tương ứng; claim trạng thái UI mô tả state branch được trích trong file và line.
