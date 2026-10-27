package com.pfm.backend;

import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

import com.jayway.jsonpath.JsonPath;
import java.time.LocalDate;
import java.util.UUID;
import org.junit.jupiter.api.Test;

class SyncIntegrationTest extends AbstractIntegrationTest {
        @Test
        void pushWalletThenOlderVersionIsSkipped() throws Exception {
                UUID user = registerUser();
                UUID wallet = UUID.randomUUID();
                push(user, "{\"wallets\":[" + walletJson(wallet, ts(60), false) + "]}")
                                .andExpect(status().isOk()).andExpect(jsonPath("$.results[0].status").value("APPLIED"));
                push(user, "{\"wallets\":[" + walletJson(wallet, ts(3600), false) + "]}")
                                .andExpect(jsonPath("$.results[0].status").value("SKIPPED_NEWER"));
        }

        @Test
        void transactionWithFutureDateIsRejected() throws Exception {
                UUID user = registerUser();
                UUID wallet = UUID.randomUUID();
                LocalDate future = LocalDate.now(VN).plusDays(3);
                String body = "{\"wallets\":[" + walletJson(wallet, ts(60), false) + "],\"transactions\":["
                                + txJson(UUID.randomUUID(), wallet, "EXPENSE", 1000, "x", future, null, false) + "]}";
                push(user, body).andExpect(jsonPath("$.results[1].status").value("REJECTED"))
                                .andExpect(jsonPath("$.results[1].reason").value("FUTURE_DATE"));
        }

        @Test
        void transactionWithMissingWalletIsInvalid() throws Exception {
                UUID user = registerUser();
                push(user, "{\"transactions\":[" + txJson(UUID.randomUUID(), UUID.randomUUID(), "EXPENSE", 1000,
                                "x", LocalDate.now(VN), null, false) + "]}")
                                .andExpect(jsonPath("$.results[0].status").value("REJECTED"))
                                .andExpect(jsonPath("$.results[0].reason").value("INVALID"));
        }

        @Test
        void transactionWithDeletedWalletIsParentDeleted() throws Exception {
                UUID user = registerUser();
                UUID wallet = UUID.randomUUID();
                push(user, "{\"wallets\":[" + walletJson(wallet, ts(600), false) + "]}").andExpect(status().isOk());
                push(user, "{\"wallets\":[" + walletJson(wallet, ts(300), true) + "]}")
                                .andExpect(jsonPath("$.results[0].status").value("APPLIED"));
                push(user, "{\"transactions\":[" + txJson(UUID.randomUUID(), wallet, "EXPENSE", 1000,
                                "x", LocalDate.now(VN), null, false) + "]}")
                                .andExpect(jsonPath("$.results[0].status").value("REJECTED"))
                                .andExpect(jsonPath("$.results[0].reason").value("PARENT_DELETED"));
        }

        @Test
        void pullPaginatesByCursor() throws Exception {
                UUID user = registerUser();
                push(user, "{\"wallets\":[" + walletJson(UUID.randomUUID(), ts(60), false) + ","
                                + walletJson(UUID.randomUUID(), ts(60), false) + ","
                                + walletJson(UUID.randomUUID(), ts(60), false) + "]}").andExpect(status().isOk());

                String page1 = mvc.perform(get("/sync/pull").with(as(user)).param("limit", "2"))
                                .andExpect(status().isOk()).andExpect(jsonPath("$.changes.wallets.length()").value(2))
                                .andExpect(jsonPath("$.has_more").value(true)).andReturn().getResponse()
                                .getContentAsString();
                long cursor = ((Number) JsonPath.read(page1, "$.next_cursor")).longValue();

                mvc.perform(get("/sync/pull").with(as(user)).param("cursor", String.valueOf(cursor)).param("limit",
                                "2"))
                                .andExpect(jsonPath("$.changes.wallets.length()").value(1))
                                .andExpect(jsonPath("$.has_more").value(false));
        }

        @Test
        void pullIsIsolatedBetweenUsers() throws Exception {
                UUID userA = registerUser();
                UUID userB = registerUser();
                push(userA, "{\"wallets\":[" + walletJson(UUID.randomUUID(), ts(60), false) + "]}")
                                .andExpect(status().isOk());
                mvc.perform(get("/sync/pull").with(as(userB))).andExpect(status().isOk())
                                .andExpect(jsonPath("$.changes.wallets.length()").value(0));
        }

        @Test
        void pullInvalidLimitReturns400() throws Exception {
                UUID user = registerUser();
                mvc.perform(get("/sync/pull").with(as(user)).param("limit", "0"))
                                .andExpect(status().isBadRequest())
                                .andExpect(jsonPath("$.code").value("VALIDATION_FAILED"));
        }

        @Test
        void pullWithoutTokenReturns401() throws Exception {
                mvc.perform(get("/sync/pull")).andExpect(status().isUnauthorized())
                                .andExpect(jsonPath("$.code").value("UNAUTHORIZED"));
        }
}
