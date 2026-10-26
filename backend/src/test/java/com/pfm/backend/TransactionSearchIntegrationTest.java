package com.pfm.backend;

import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

import java.time.LocalDate;
import java.util.UUID;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;

class TransactionSearchIntegrationTest extends AbstractIntegrationTest {
    private UUID user;
    private UUID wallet;
    private LocalDate today;

    @BeforeEach
    void seed() throws Exception {
        user = registerUser();
        wallet = UUID.randomUUID();
        today = LocalDate.now(VN);
        String transactions = String.join(",",
                txJson(UUID.randomUUID(), wallet, "EXPENSE", 50000, "Ăn phở", today.minusDays(2), CAT_FOOD, false),
                txJson(UUID.randomUUID(), wallet, "EXPENSE", 120000, "Mua sách", today.minusDays(1), null, false),
                txJson(UUID.randomUUID(), wallet, "INCOME", 5000000, "Lương tháng 10", today, null, false),
                txJson(UUID.randomUUID(), wallet, "EXPENSE", 1000, "Đã xóa", today, null, true));
        push(user, "{\"wallets\":[" + walletJson(wallet, ts(60), false) + "],\"transactions\":[" + transactions + "]}")
                .andExpect(status().isOk());
    }

    private org.springframework.test.web.servlet.request.MockHttpServletRequestBuilder search() {
        return get("/transactions").with(as(user));
    }

    @Test
    void noFilterSortsByDateDescAndSkipsDeleted() throws Exception {
        mvc.perform(search()).andExpect(status().isOk()).andExpect(jsonPath("$.total_elements").value(3))
                .andExpect(jsonPath("$.items[0].amount").value(5000000))
                .andExpect(jsonPath("$.items[2].amount").value(50000));
    }

    @Test
    void filterByType() throws Exception {
        mvc.perform(search().param("type", "EXPENSE")).andExpect(jsonPath("$.total_elements").value(2));
    }

    @Test
    void filterByCategory() throws Exception {
        mvc.perform(search().param("category_id", CAT_FOOD)).andExpect(jsonPath("$.total_elements").value(1))
                .andExpect(jsonPath("$.items[0].amount").value(50000));
    }

    @Test
    void searchNoteIsCaseInsensitive() throws Exception {
        mvc.perform(search().param("q", "PHỞ")).andExpect(jsonPath("$.total_elements").value(1))
                .andExpect(jsonPath("$.items[0].amount").value(50000));
    }

    @Test
    void likeSpecialCharsAreLiteral() throws Exception {
        for (String query : new String[] {"%", "_", "["}) {
            mvc.perform(search().param("q", query)).andExpect(status().isOk())
                    .andExpect(jsonPath("$.total_elements").value(0));
        }
    }

    @Test
    void filterByAmountRange() throws Exception {
        mvc.perform(search().param("min_amount", "100000")).andExpect(jsonPath("$.total_elements").value(2));
        mvc.perform(search().param("max_amount", "60000")).andExpect(jsonPath("$.total_elements").value(1));
    }

    @Test
    void filterByDateRange() throws Exception {
        mvc.perform(search().param("from", today.minusDays(1).toString()).param("to", today.minusDays(1).toString()))
                .andExpect(jsonPath("$.total_elements").value(1)).andExpect(jsonPath("$.items[0].amount").value(120000));
    }

    @Test
    void pagination() throws Exception {
        mvc.perform(search().param("size", "2").param("page", "0")).andExpect(jsonPath("$.items.length()").value(2))
                .andExpect(jsonPath("$.total_pages").value(2));
        mvc.perform(search().param("size", "2").param("page", "1")).andExpect(jsonPath("$.items.length()").value(1));
    }

    @Test
    void otherWalletAndOtherUserSeeNothing() throws Exception {
        mvc.perform(search().param("wallet_id", UUID.randomUUID().toString())).andExpect(jsonPath("$.total_elements").value(0));
        mvc.perform(get("/transactions").with(as(registerUser()))).andExpect(jsonPath("$.total_elements").value(0));
    }

    @Test
    void invalidParamsReturn400() throws Exception {
        String[][] bad = {{"type", "FOO"}, {"size", "0"}, {"size", "101"}, {"page", "-1"},
                {"wallet_id", "abc"}, {"from", "2026-13-45"}, {"min_amount", "0"}};
        for (String[] parameter : bad) {
            mvc.perform(search().param(parameter[0], parameter[1])).andExpect(status().isBadRequest())
                    .andExpect(jsonPath("$.code").value("VALIDATION_FAILED"));
        }
    }

    @Test
    void invertedRangesReturn400() throws Exception {
        mvc.perform(search().param("from", "2026-10-20").param("to", "2026-10-10"))
                .andExpect(status().isBadRequest());
        mvc.perform(search().param("min_amount", "200").param("max_amount", "100"))
                .andExpect(status().isBadRequest());
    }

    @Test
    void withoutTokenReturns401() throws Exception {
        mvc.perform(get("/transactions")).andExpect(status().isUnauthorized());
    }
}
