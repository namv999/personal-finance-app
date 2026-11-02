# Backend: cấu trúc và file Java

Cập nhật theo code hiện tại: backend Spring Boot có auth JWT, đồng bộ push/pull, truy vấn giao dịch có lọc/phân trang, phân tích tin nhắn/ảnh và gợi ý thu chi bằng AI. Endpoint parse ảnh nhận một JPEG/PNG/WebP tối đa 3 MB, kiểm tra chữ ký MIME, không lưu ảnh và che dữ liệu nhạy cảm trong ghi chú trả về. Backend tính xu hướng chi tiêu, số tiền còn lại và ngân sách; Gemini chỉ viết câu diễn giải theo schema. Spring Security cho phép `/auth/**` và Swagger/OpenAPI truy cập công khai; các API nghiệp vụ còn lại yêu cầu JWT.

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
    │   │   │   ├── AiSuggestionService.java
    │   │   │   ├── GeminiClient.java
    │   │   │   ├── GeminiHttpClient.java
    │   │   │   ├── SensitiveMasker.java
    │   │   │   └── dto/
    │   │   │       ├── ParseImageRequest.java
    │   │   │       ├── ParseImageResponse.java
    │   │   │       ├── ParseTextRequest.java
    │   │   │       ├── ParseTextResponse.java
    │   │   │       ├── SuggestionRequest.java
    │   │   │       └── SuggestionResponse.java
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
    │       │   │   ├── AiParseImageIntegrationTest.java
    │       │   │   ├── AiParseIntegrationTest.java
    │       │   │   ├── AiParseServiceTest.java
    │       │   │   └── AiSuggestionIntegrationTest.java
    │       │   ├── AuthIntegrationTest.java
    │       │   ├── BackendApplicationTests.java
    │       │   ├── SyncIntegrationTest.java
    │       │   └── TransactionSearchIntegrationTest.java
    │       └── resources/application-test.yml
```

Các API hiện có: `POST /auth/register`, `POST /auth/login`, `POST /sync/push`, `GET /sync/pull`, `GET /transactions`, `POST /ai/parse-text`, `POST /ai/parse-image` và `POST /ai/suggestions`. Ngoại trừ auth, các API nghiệp vụ yêu cầu JWT. `/ai/parse-text` chấp nhận tối đa 10 tin SMS/TEXT mỗi request và trả `PARSED`, `NOT_A_TRANSACTION` hoặc `FAILED` cho từng tin. `/ai/parse-image` nhận ảnh Base64 tối đa 3 MB, xác thực JPEG/PNG/WebP bằng chữ ký file, gửi ảnh cùng prompt/schema tới Gemini và chỉ trả đề xuất giao dịch; ảnh không được lưu, ghi chú AI trả về được che số nhạy cảm. `/ai/suggestions` nhận kỳ `WEEK` hoặc `MONTH`; backend tính thu/chi dự kiến, tiền còn lại, tỷ lệ, xu hướng theo kỳ/danh mục và số liệu ngân sách rồi gửi số đã làm tròn nghìn cho Gemini. Gemini trả mảng câu, backend làm sạch và ghép thành nội dung nhiều dòng, đồng thời vẫn đọc định dạng `content` cũ. Response thể hiện trạng thái thiếu dữ liệu khi chưa đủ điều kiện. Lỗi Gemini được log kèm loại nguyên nhân gốc, không ghi nội dung ảnh. Springdoc cung cấp Swagger UI và OpenAPI; hợp đồng API dùng chung được lưu tại `docs/api/openapi.yaml` ở thư mục gốc repository.

Cây trên liệt kê file Java trong `src/main/java`, test Java và cấu hình test, cùng migration SQL đang có. Maven Wrapper có tại `backend/mvnw` và `backend/mvnw.cmd`; không liệt kê wrapper, `target/` hoặc file build sinh tự động trong cây mã nguồn.

