# PHASE3_PLAN: AI và tính năng thông minh

Cập nhật: 26/10/2026. Đây là **đề xuất**, cả nhóm xác nhận trước khi chạy. Ngày nộp 21/11/2026 còn khoảng 3,7 tuần.

## 1. Mục tiêu

Ba tính năng AI, theo yêu cầu đã chốt trong Tech Stack:
1. Phân tích SMS ngân hàng và tin nhắn dán vào, đề xuất giao dịch và danh mục.
2. Phân tích ảnh hóa đơn hoặc ảnh chụp màn hình tin nhắn.
3. Gợi ý thu chi cho tuần hoặc tháng kế tiếp.

Nguyên tắc cố định:
- Flutter không gọi AI trực tiếp. Backend giữ API key và gọi Gemini.
- Kết quả AI chỉ là **đề xuất**, lưu ở `pending_transactions` (local). Chỉ khi người dùng xác nhận mới tạo transaction chính thức (`source` là `SMS`, `IMAGE` hoặc `TEXT`). Đề xuất không làm đổi số dư.
- `pending_transactions` không đồng bộ lên server. Transaction được tạo sau khi xác nhận thì đồng bộ như bình thường.
- Gợi ý thu chi: backend tính số liệu, AI chỉ diễn giải. Thiếu dữ liệu thì trả "chưa đủ dữ liệu".

## 2. Đề xuất đổi thứ tự

Tech Stack ghi thứ tự: văn bản, SMS, ảnh, gợi ý. Đề xuất làm **gợi ý thu chi trước ảnh**:
- Gợi ý không cần xử lý ảnh, số liệu do backend tính nên ít rủi ro sai.
- Ảnh có rủi ro cao nhất: quyền riêng tư, độ chính xác khi đọc hóa đơn tiếng Việt, tải ảnh.
- Ảnh trở thành mục mở rộng, quyết định ngày 09/11.

## 3. Lịch đề xuất

| Mã | Thời gian | Nội dung | Kết quả nghiệm thu |
|---|---|---|---|
| P3.0 | 26 đến 28/10 | Đóng Phase 2 (merge PR). Thêm `/ai/parse-text` vào `openapi.yaml`. Đặt `GEMINI_API_KEY` trong `env-local.ps1`. Chạy thử Gemini với vài tin nhắn mẫu để chọn model và cách ép JSON | Contract được cả nhóm đồng ý, gọi thử Gemini thành công |
| P3.1 | 27/10 đến 01/11 | Backend `POST /ai/parse-text`: che dữ liệu nhạy cảm, prompt, kiểm tra JSON, kiểm tra `category_id`, xử lý 429/503, test | Postman trả đúng `PARSED`, `NOT_A_TRANSACTION`, `FAILED`. Test chạy với `GeminiClient` giả |
| P3.2 | 30/10 đến 06/11 | Flutter: màn dán tin nhắn, gọi API, hộp thư chờ duyệt, xác nhận hoặc từ chối, tạo transaction chính thức. Offline giữ `NEEDS_AI`, có mạng thì gửi lại | Luồng dán, duyệt, xác nhận chạy trên điện thoại thật, số dư đúng |
| Mốc 1 | 06/11 | Kiểm tra luồng dán văn bản từ đầu đến cuối | Đạt thì làm tiếp P3.3 |
| P3.3 | 06 đến 09/11 | Đọc SMS: xin quyền `READ_SMS` khi bật tính năng, chỉ đọc khi bấm quét, lọc tin ngân hàng, chống trùng bằng `source_hash` | Quét SMS ra danh sách chờ duyệt, quét lại không bị trùng |
| Mốc 2 | 09/11 | Quyết định có làm ảnh không | Chỉ làm khi P3.1 đến P3.3 đã ổn định |
| P3.4 | 09 đến 13/11 | Gợi ý thu chi tuần/tháng: backend tính số liệu, Gemini diễn giải, màn hình hiển thị, cache vào `ai_suggestions` | Có gợi ý khi đủ dữ liệu, có thông báo khi thiếu dữ liệu |
| Ảnh (mở rộng) | 09 đến 13/11 | Phân tích ảnh hóa đơn, có hộp thoại đồng ý trước khi xử lý, không lưu ảnh lâu dài | Chỉ làm nếu còn người rảnh |
| Đóng băng | 13/11 | Dừng thêm tính năng | |
| Kiểm thử và báo cáo | 14 đến 19/11 | Test toàn bộ, sửa lỗi, cập nhật báo cáo (chương AI), build APK, kịch bản demo | |
| Dự phòng | 20 đến 21/11 | Chỉ sửa lỗi nghiêm trọng, nộp | |


## 4. Quyết định thiết kế (mặc định đề xuất)

- Nhà cung cấp: **Gemini**. Dùng interface `GeminiClient` ở backend để test không gọi API thật (tránh tốn lượt, tránh test chập chờn).
- Backend **không lưu** nội dung gửi lên, chỉ xử lý rồi trả kết quả.
- Client gửi kèm danh sách danh mục hợp lệ của user trong mỗi request. Server kiểm tra lại `category_id` AI trả về: không thuộc danh sách hoặc khác `type` thì để `null`.
- Tối đa 10 tin nhắn mỗi request.
- `source_hash` do client tính trước khi gọi, tin trùng không tốn lượt AI.
- Giai đoạn đầu chỉ đề xuất `INCOME` hoặc `EXPENSE`. Chuyển tiền giữa ví vẫn dùng chức năng Transfer.
- Hóa đơn nhiều món ghi nhận thành một giao dịch theo tổng tiền.

## 5. Contract tóm tắt `POST /ai/parse-text`

Cần token. Request (snake_case):
```json
{
  "items": [
    {
      "ref": "<pending_transactions.id>",
      "source": "SMS",
      "content": "TK ****1234 -50,000 VND luc 26/10 14:05 tai HIGHLANDS COFFEE"
    }
  ],
  "categories": [
    { "id": "00000000-0000-4000-8000-000000000003", "category_name": "Ăn uống", "type": "EXPENSE" }
  ]
}
```
Response:
```json
{
  "results": [
    {
      "ref": "<pending_transactions.id>",
      "status": "PARSED",
      "suggestion": {
        "amount": 50000,
        "type": "EXPENSE",
        "transaction_date": "2026-10-26",
        "note": "Highlands Coffee",
        "category_id": "00000000-0000-4000-8000-000000000003",
        "confidence": 0.92
      }
    }
  ]
}
```

| `status` | Client xử lý |
|---|---|
| `PARSED` | Lưu đề xuất, chuyển pending sang `PENDING` |
| `NOT_A_TRANSACTION` | OTP, quảng cáo, chuyển sang `REJECTED` |
| `FAILED` | AI trả sai schema hoặc số tiền không hợp lệ, giữ `NEEDS_AI` |

Lỗi toàn request: 429 `AI_RATE_LIMITED`, 503 `AI_UNAVAILABLE` (client giữ `NEEDS_AI`, thử lại sau).

Quy tắc server áp dụng: `amount` phải là số nguyên lớn hơn 0. Ngày thiếu hoặc ở tương lai thì đặt về hôm nay (theo Asia/Ho_Chi_Minh).

## 6. Vòng đời `pending_transactions`

`NEEDS_AI` (chưa gọi được AI hoặc đang offline) → `PENDING` (đã có đề xuất, chờ người dùng) → `CONFIRMED` (đã tạo transaction) hoặc `REJECTED`.

Khi xác nhận, tạo transaction bằng đúng đường ghi dữ liệu hiện có (ghi `sync_queue` cùng transaction, tính lại số dư), không cộng trừ số dư thủ công.

## 7. Quyền riêng tư (checklist)

- [ ] Che số tài khoản, số thẻ, số điện thoại trước khi gửi (client che, server che lại lần nữa)
- [ ] Không gửi số dư
- [ ] Ảnh: có hộp thoại đồng ý trước khi xử lý, không lưu lâu dài
- [ ] Chỉ xin `READ_SMS` khi người dùng bật tính năng, chỉ đọc khi người dùng bấm quét
- [ ] Có phương án dán tin nhắn khi không cấp quyền SMS
- [ ] API key chỉ ở biến môi trường `GEMINI_API_KEY`, không commit, không gửi vào chat
- [ ] Đọc điều khoản xử lý dữ liệu của gói Gemini đang dùng để ghi vào báo cáo

## 8. Phân công đề xuất

- **Nam**: contract, dữ liệu phía Flutter (hộp thư chờ, xác nhận tạo transaction, chống trùng), đọc SMS, tích hợp.
- **Thành viên B (backend)**: endpoint `/ai/parse-text`, gợi ý thu chi, test.
- **Thành viên C (Flutter UI)**: màn dán tin nhắn, hộp thư chờ duyệt, màn gợi ý. Có thể làm sớm bằng dữ liệu giả khi contract đã chốt.

## 9. Rủi ro và điểm cắt

- Gemini miễn phí thường có giới hạn tần suất → giữ `NEEDS_AI` và thử lại, hiển thị thông báo rõ ràng.
- Gemini trả JSON sai → backend kiểm tra schema, trả `FAILED`, không để lỗi lan sang app.
- Package đọc SMS Android chưa được chốt → dành 1 đến 2 giờ khảo sát ở P3.0, chọn package còn được bảo trì và hỗ trợ Flutter 3.47.
- Tin nhắn thiếu năm hoặc định dạng khác nhau giữa các ngân hàng → dùng bộ mẫu để đo (mục 10).
- **Điểm cắt khi trễ**: bỏ phân tích ảnh trước, sau đó rút gọn gợi ý (chỉ theo tháng). Phần dán văn bản và SMS là lõi của tính năng AI, giữ lại.

## 10. Kiểm thử và đo độ chính xác

- Backend: test tích hợp dùng `GeminiClient` giả (trường hợp `PARSED`, `NOT_A_TRANSACTION`, `FAILED`, `category_id` sai, ngày tương lai, 429/503).
- Thủ công: Postman với Gemini thật.
- Tạo **bộ mẫu 20 đến 30 tin nhắn giả lập** (tự soạn, không dùng SMS thật chứa thông tin cá nhân) để đo tỉ lệ đúng số tiền, loại, danh mục. Kết quả đưa vào chương AI của báo cáo.
- Nghiệm thu trên điện thoại thật cho luồng SMS và quyền truy cập.

## 11. Việc làm ngay (P3.0)

- [ ] Merge PR Phase 2 vào `develop`
- [ ] Tạo nhánh `feature/ai-parse-text` từ `develop`
- [ ] Thêm `GEMINI_API_KEY` vào `backend/env-local.ps1` (mỗi người dùng key riêng của mình)
- [ ] Thêm `/ai/parse-text` vào `docs/openapi.yaml`, nâng version lên 1.2.0
- [ ] Cập nhật `DB_Flutter_Idea.md` nếu có thay đổi schema AI (thêm `pending_transactions`, `transactions.source`, `ai_suggestions` theo kỳ đã có ở DB v4)
- [ ] Khảo sát package đọc SMS