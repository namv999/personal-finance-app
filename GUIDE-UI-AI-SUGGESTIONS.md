# GUIDE-UI: màn Gợi ý AI (`screens/ai_suggestions/ai_suggestion_screen.dart`)
Chỉ sửa file màn hình, không sửa provider, repository hay model. Dùng `context.watch<AiSuggestionProvider>()`.

## Trạng thái provider cung cấp
- `periodType` (AiPeriodType.week | month), `setType(type)`: đổi loại kỳ.
- `targetPeriod` (AiPeriod): kỳ kế tiếp được gợi ý (start/end).
- `current` (AiSuggestion?): gợi ý đã cache; null nghĩa là chưa có.
- `isLoading`: đang đọc cache. `isRequesting`: đang đồng bộ rồi gọi AI (tối đa ~60 giây).
- `requestNew()` trả `SuggestOutcome(status, message)`.

## Bố cục
1. Đầu màn: SegmentedButton "Tuần tới | Tháng tới", gọi `setType`. Dưới là nhãn kỳ, ví dụ "Tháng 11/2026" hoặc "02/11 – 08/11".
2. Có `current`: Card hiển thị `suggestionContent` (mỗi dòng "- " là một gạch đầu dòng) và "Tạo lúc dd/MM HH:mm" lấy từ `createdAt`.
   Dưới Card, mục thu gọn "Số liệu" đọc `jsonDecode(current.suggestedData)`: avg_expense, avg_income, top_expense_categories (tên, avg_amount, share_percent), budgets nếu có. Tiền định dạng bằng `Formatters`.
3. Không có `current`: EmptyState "Chưa có gợi ý cho kỳ này".
4. Nút chính "Tạo gợi ý" (khi đã có thì đổi nhãn thành "Tạo lại"). Khi `isRequesting`: vô hiệu hóa nút, hiện vòng quay và chữ "Đang đồng bộ và phân tích...". Không chặn nút Back.
5. Ghi chú nhỏ dưới nút: "Gợi ý dựa trên dữ liệu đã đồng bộ. AI chỉ diễn giải, mọi số liệu do hệ thống tính."

## Xử lý `SuggestOutcome.status` (SnackBar, trừ insufficientData)
- ok: không báo gì, nội dung tự cập nhật.
- insufficientData: Card thông tin (không phải lỗi) hiển thị `message`, kèm gợi ý "Hãy ghi thêm giao dịch rồi thử lại".
- offline: "Cần kết nối mạng và đăng nhập online để tạo gợi ý".
- unauthorized: "Phiên hết hạn, hãy đăng nhập lại".
- syncFailed: "Không đồng bộ được dữ liệu nên chưa thể tạo gợi ý. Thử lại sau" (nếu `message == 'BUSY'`: "Đang đồng bộ, thử lại sau ít giây").
- rateLimited: "Dịch vụ AI đang quá tải, thử lại sau ít phút".
- unavailable: "Dịch vụ AI tạm thời không khả dụng".
- error / busy: "Có lỗi, vui lòng thử lại".

## Lưu ý
- Gọi `await requestNew()` rồi kiểm tra `context.mounted` trước khi hiện SnackBar.
- Không tự tính hay đoán số liệu ở UI; chỉ hiển thị dữ liệu từ provider.