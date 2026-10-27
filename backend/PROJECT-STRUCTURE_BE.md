# Backend: cấu trúc và file Java

Cập nhật theo code hiện có: Phase 2 (P2.1–P2.7) đã hoàn thành. Backend hiện có auth JWT, đồng bộ push/pull và truy vấn giao dịch có lọc/tìm kiếm/phân trang. Endpoint AI trong Phase 3 mới ở mức kế hoạch, chưa có package Java tương ứng.

```text
backend/
├── pom.xml
└── src/
    ├── main/
    │   ├── java/com/pfm/backend/
    │   │   ├── BackendApplication.java
    │   │   ├── auth/
    │   │   │   ├── AuthController.java
    │   │   │   ├── AuthService.java
    │   │   │   ├── JwtService.java
    │   │   │   ├── User.java
    │   │   │   ├── UserRepository.java
    │   │   │   └── dto/
    │   │   │       ├── AuthResponse.java
    │   │   │       ├── LoginRequest.java
    │   │   │       ├── RegisterRequest.java
    │   │   │       └── UserInfo.java
    │   │   ├── common/
    │   │   │   ├── ApiException.java
    │   │   │   └── GlobalExceptionHandler.java
    │   │   ├── config/
    │   │   │   ├── JwtConfig.java
    │   │   │   └── SecurityConfig.java
    │   │   ├── ai/
    │   │   │   ├── AiController.java
    │   │   │   ├── AiParseService.java
    │   │   │   ├── GeminiClient.java
    │   │   │   ├── GeminiHttpClient.java
    │   │   │   ├── SensitiveMasker.java
    │   │   │   └── dto/
    │   │   │       ├── ParseTextRequest.java
    │   │   │       └── ParseTextResponse.java
    │   │   ├── sync/
    │   │   │   ├── ServerVersionService.java
    │   │   │   ├── SyncController.java
    │   │   │   ├── SyncPullService.java
    │   │   │   ├── SyncPushService.java
    │   │   │   ├── dto/
    │   │   │   │   ├── CategoryDto.java
    │   │   │   │   ├── MonthlyBudgetDto.java
    │   │   │   │   ├── PullResponse.java
    │   │   │   │   ├── PushRequest.java
    │   │   │   │   ├── PushResponse.java
    │   │   │   │   ├── PushResult.java
    │   │   │   │   ├── PushStatus.java
    │   │   │   │   ├── RejectReason.java
    │   │   │   │   ├── SavingGoalDto.java
    │   │   │   │   ├── SyncDto.java
    │   │   │   │   ├── TransactionDto.java
    │   │   │   │   ├── TransferDto.java
    │   │   │   │   └── WalletDto.java
    │   │   │   ├── entity/
    │   │   │   │   ├── Category.java
    │   │   │   │   ├── MonthlyBudget.java
    │   │   │   │   ├── SavingGoal.java
    │   │   │   │   ├── SyncEntity.java
    │   │   │   │   ├── Transaction.java
    │   │   │   │   ├── Transfer.java
    │   │   │   │   └── Wallet.java
    │   │   │   └── repo/
    │   │   │       ├── CategoryRepository.java
    │   │   │       ├── MonthlyBudgetRepository.java
    │   │   │       ├── SavingGoalRepository.java
    │   │   │       ├── TransactionRepository.java
    │   │   │       ├── TransferRepository.java
    │   │   │       └── WalletRepository.java
    │   │   └── transaction/
    │   │       ├── TransactionController.java
    │   │       ├── TransactionFilter.java
    │   │       ├── TransactionQueryService.java
    │   │       └── dto/
    │   │           ├── TransactionItem.java
    │   │           └── TransactionPageResponse.java
    │   ├── resources/
    │   │   ├── application.yml
    │   │   └── db/migration/
    │   │       ├── V1__init.sql
    │   │       ├── V2__tx_search_index.sql
    │   │       └── V3__add_transaction_search_indexes.sql
    │   └── test/java/com/pfm/backend/
    │       ├── AbstractIntegrationTest.java
    │       ├── ai/
    │       │   ├── AiParseIntegrationTest.java
    │       │   └── AiParseServiceTest.java
    │       ├── AuthIntegrationTest.java
    │       ├── BackendApplicationTests.java
    │       ├── SyncIntegrationTest.java
    │       └── TransactionSearchIntegrationTest.java
```

Các API hiện có: `POST /auth/register`, `POST /auth/login`, `POST /sync/push`, `GET /sync/pull`, `GET /transactions`. Test tích hợp hiện bao phủ auth, sync và transaction search; trạng thái gần nhất trong tài liệu tiến độ là 26 test đã chạy thành công trên SQL Server `pfm_test`.

Cây trên liệt kê đầy đủ file Java trong `src/main/java` và `src/test/java` cùng migration SQL đang có. Không hiển thị Maven Wrapper, `target/` và file build sinh tự động.

