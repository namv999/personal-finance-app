package com.pfm.backend;

import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

import java.util.UUID;
import org.junit.jupiter.api.Test;

class ScheduledSyncIntegrationTest extends AbstractIntegrationTest {
    private String sched(UUID id, UUID wallet, String updatedAt, String start, String time, String unit,
            Integer every, String end) {
        return """
                {"id":"%s","updated_at":"%s","is_deleted":false,"wallet_id":"%s","category_id":"%s","type":"EXPENSE","amount":50000,"note":"Tiền nhà","start_date":"%s","time_of_day":"%s","repeat_unit":%s,"repeat_every":%s,"end_date":%s,"next_due_date":"%s"}
                """.formatted(id, updatedAt, wallet, CAT_FOOD, start, time,
                unit == null ? "null" : "\"" + unit + "\"", every == null ? "null" : every,
                end == null ? "null" : "\"" + end + "\"", start);
    }

    private org.springframework.test.web.servlet.ResultActions pushWith(UUID user, UUID wallet, String schedJson)
            throws Exception {
        return push(user, "{\"wallets\":[" + walletJson(wallet, ts(600), false)
                + "],\"scheduled_transactions\":[" + schedJson + "]}");
    }

    @Test
    void pushThenPullReturnsAllFields() throws Exception {
        UUID user = registerUser();
        UUID wallet = UUID.randomUUID();
        pushWith(user, wallet, sched(UUID.randomUUID(), wallet, ts(60), "2026-11-10", "08:00", "MONTH", 1, null))
                .andExpect(status().isOk()).andExpect(jsonPath("$.results[1].status").value("APPLIED"));
        mvc.perform(get("/sync/pull").with(as(user))).andExpect(status().isOk())
                .andExpect(jsonPath("$.changes.scheduled_transactions.length()").value(1))
                .andExpect(jsonPath("$.changes.scheduled_transactions[0].repeat_unit").value("MONTH"))
                .andExpect(jsonPath("$.changes.scheduled_transactions[0].repeat_every").value(1))
                .andExpect(jsonPath("$.changes.scheduled_transactions[0].time_of_day").value("08:00"))
                .andExpect(jsonPath("$.changes.scheduled_transactions[0].next_due_date").value("2026-11-10"))
                .andExpect(jsonPath("$.changes.scheduled_transactions[0].amount").value(50000));
    }

    @Test
    void olderVersionIsSkipped() throws Exception {
        UUID user = registerUser();
        UUID wallet = UUID.randomUUID();
        UUID id = UUID.randomUUID();
        pushWith(user, wallet, sched(id, wallet, ts(60), "2026-11-10", "08:00", null, null, null))
                .andExpect(jsonPath("$.results[1].status").value("APPLIED"));
        push(user, "{\"scheduled_transactions\":["
                + sched(id, wallet, ts(3600), "2026-11-10", "08:00", null, null, null) + "]}")
                .andExpect(jsonPath("$.results[0].status").value("SKIPPED_NEWER"));
    }

    @Test
    void pastStartDateIsAccepted() throws Exception {
        UUID user = registerUser();
        UUID wallet = UUID.randomUUID();
        pushWith(user, wallet, sched(UUID.randomUUID(), wallet, ts(60), "2026-10-01", "08:00", "DAY", 1, null))
                .andExpect(jsonPath("$.results[1].status").value("APPLIED"));
    }

    @Test
    void missingWalletIsInvalid() throws Exception {
        UUID user = registerUser();
        push(user, "{\"scheduled_transactions\":["
                + sched(UUID.randomUUID(), UUID.randomUUID(), ts(60), "2026-11-10", "08:00", null, null, null) + "]}")
                .andExpect(jsonPath("$.results[0].status").value("REJECTED"))
                .andExpect(jsonPath("$.results[0].reason").value("INVALID"));
    }

    @Test
    void deletedWalletIsParentDeleted() throws Exception {
        UUID user = registerUser();
        UUID wallet = UUID.randomUUID();
        push(user, "{\"wallets\":[" + walletJson(wallet, ts(600), false) + "]}")
                .andExpect(status().isOk());
        push(user, "{\"wallets\":[" + walletJson(wallet, ts(300), true) + "]}")
                .andExpect(jsonPath("$.results[0].status").value("APPLIED"));
        push(user, "{\"scheduled_transactions\":["
                + sched(UUID.randomUUID(), wallet, ts(60), "2026-11-10", "08:00", null, null, null) + "]}")
                .andExpect(jsonPath("$.results[0].status").value("REJECTED"))
                .andExpect(jsonPath("$.results[0].reason").value("PARENT_DELETED"));
    }

    @Test
    void deletingScheduledUnderDeletedWalletIsApplied() throws Exception {
        UUID user = registerUser();
        UUID wallet = UUID.randomUUID();
        UUID id = UUID.randomUUID();
        pushWith(user, wallet, sched(id, wallet, ts(600), "2026-11-10", "08:00", null, null, null))
                .andExpect(jsonPath("$.results[1].status").value("APPLIED"));
        push(user, "{\"wallets\":[" + walletJson(wallet, ts(300), true) + "]}")
                .andExpect(jsonPath("$.results[0].status").value("APPLIED"));
        String deleted = sched(id, wallet, ts(60), "2026-11-10", "08:00", null, null, null)
                .replace("\"is_deleted\":false", "\"is_deleted\":true");
        push(user, "{\"scheduled_transactions\":[" + deleted + "]}")
                .andExpect(jsonPath("$.results[0].status").value("APPLIED"));
    }

    @Test
    void invalidRulesAreRejected() throws Exception {
        UUID user = registerUser();
        UUID wallet = UUID.randomUUID();
        pushWith(user, wallet, sched(UUID.randomUUID(), wallet, ts(60), "2026-11-10", "25:00", null, null, null))
                .andExpect(jsonPath("$.results[1].reason").value("INVALID"));
        pushWith(user, wallet, sched(UUID.randomUUID(), wallet, ts(60), "2026-11-10", "08:00", "WEEK", null, null))
                .andExpect(jsonPath("$.results[1].reason").value("INVALID"));
        pushWith(user, wallet,
                sched(UUID.randomUUID(), wallet, ts(60), "2026-11-10", "08:00", "DAY", 1, "2026-11-01"))
                .andExpect(jsonPath("$.results[1].reason").value("INVALID"));
        pushWith(user, wallet,
                sched(UUID.randomUUID(), wallet, ts(60), "2026-11-10", "08:00", null, null, "2026-11-20"))
                .andExpect(jsonPath("$.results[1].reason").value("INVALID"));
    }

    @Test
    void pullIsIsolatedBetweenUsers() throws Exception {
        UUID a = registerUser();
        UUID b = registerUser();
        UUID wallet = UUID.randomUUID();
        pushWith(a, wallet, sched(UUID.randomUUID(), wallet, ts(60), "2026-11-10", "08:00", null, null, null))
                .andExpect(status().isOk());
        mvc.perform(get("/sync/pull").with(as(b))).andExpect(status().isOk())
                .andExpect(jsonPath("$.changes.scheduled_transactions.length()").value(0));
    }
}
