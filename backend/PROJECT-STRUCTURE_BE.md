# Backend: cấu trúc và file code quan trọng

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
    │   │   └── sync/
    │   │       ├── ServerVersionService.java
    │   │       ├── SyncController.java
    │   │       ├── SyncPullService.java
    │   │       ├── SyncPushService.java
    │   │       ├── dto/
    │   │       │   ├── CategoryDto.java
    │   │       │   ├── MonthlyBudgetDto.java
    │   │       │   ├── PullResponse.java
    │   │       │   ├── PushRequest.java
    │   │       │   ├── PushResponse.java
    │   │       │   ├── PushResult.java
    │   │       │   ├── PushStatus.java
    │   │       │   ├── RejectReason.java
    │   │       │   ├── SavingGoalDto.java
    │   │       │   ├── SyncDto.java
    │   │       │   ├── TransactionDto.java
    │   │       │   ├── TransferDto.java
    │   │       │   └── WalletDto.java
    │   │       ├── entity/
    │   │       │   ├── Category.java
    │   │       │   ├── MonthlyBudget.java
    │   │       │   ├── SavingGoal.java
    │   │       │   ├── SyncEntity.java
    │   │       │   ├── Transaction.java
    │   │       │   ├── Transfer.java
    │   │       │   └── Wallet.java
    │   │       └── repo/
    │   │           ├── CategoryRepository.java
    │   │           ├── MonthlyBudgetRepository.java
    │   │           ├── SavingGoalRepository.java
    │   │           ├── TransactionRepository.java
    │   │           ├── TransferRepository.java
    │   │           └── WalletRepository.java
    │   └── resources/
    │       ├── application.yml
    │       └── db/migration/...
    └── test/...
```

`db/migration/...` và `test/...` được rút gọn vì không thuộc luồng code tính năng chính. Maven wrapper, `target/` và file build sinh tự động không hiển thị trong cây này.
