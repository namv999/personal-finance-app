# Backend: cấu trúc và file Java

Cập nhật theo code hiện tại: backend Spring Boot có auth JWT, đồng bộ push/pull, truy vấn giao dịch có lọc/phân trang và endpoint AI `POST /ai/parse-text`. Endpoint AI che dữ liệu nhạy cảm trước khi gửi Gemini, kiểm tra kết quả theo từng tin và không lưu nội dung tin nhắn. Spring Security cho phép `/auth/**` và Swagger/OpenAPI truy cập công khai; các API nghiệp vụ còn lại yêu cầu JWT.

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
    │   │       └── V2__tx_search_index.sql
    │   └── test/
    │       ├── java/com/pfm/backend/
    │       │   ├── AbstractIntegrationTest.java
    │       │   ├── ai/
    │       │   │   ├── AiParseErrorIntegrationTest.java
    │       │   │   ├── AiParseIntegrationTest.java
    │       │   │   └── AiParseServiceTest.java
    │       │   ├── AuthIntegrationTest.java
    │       │   ├── BackendApplicationTests.java
    │       │   ├── SyncIntegrationTest.java
    │       │   └── TransactionSearchIntegrationTest.java
    │       └── resources/application-test.yml
```

Các API hiện có: `POST /auth/register`, `POST /auth/login`, `POST /sync/push`, `GET /sync/pull`, `GET /transactions` và `POST /ai/parse-text`. Ngoại trừ auth, các API nghiệp vụ yêu cầu JWT. `/ai/parse-text` chấp nhận tối đa 10 tin SMS/TEXT mỗi request và trả `PARSED`, `NOT_A_TRANSACTION` hoặc `FAILED` cho từng tin. Springdoc cung cấp Swagger UI và OpenAPI; hợp đồng API dùng chung được lưu tại `docs/api/openapi.yaml` ở thư mục gốc repository.

Cây trên liệt kê file Java trong `src/main/java`, test Java và cấu hình test, cùng migration SQL đang có. Maven Wrapper có tại `backend/mvnw` và `backend/mvnw.cmd`; không liệt kê wrapper, `target/` hoặc file build sinh tự động trong cây mã nguồn.

