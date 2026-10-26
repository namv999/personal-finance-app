package com.pfm.backend;

import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

import java.util.UUID;
import org.junit.jupiter.api.Test;
import org.springframework.http.MediaType;
import org.springframework.test.web.servlet.ResultActions;

class AuthIntegrationTest extends AbstractIntegrationTest {
    private ResultActions register(UUID id, String email, String password) throws Exception {
        return mvc.perform(post("/auth/register").contentType(MediaType.APPLICATION_JSON).content("""
                {"id":"%s","full_name":"Test","email":"%s","password":"%s"}
                """.formatted(id, email, password)));
    }

    private ResultActions login(String email, String password) throws Exception {
        return mvc.perform(post("/auth/login").contentType(MediaType.APPLICATION_JSON).content("""
                {"email":"%s","password":"%s"}
                """.formatted(email, password)));
    }

    @Test
    void registerThenLogin() throws Exception {
        UUID id = UUID.randomUUID();
        String email = "a" + id + "@test.com";
        register(id, email, "123456").andExpect(status().isCreated()).andExpect(jsonPath("$.token").isNotEmpty());
        login(email, "123456").andExpect(status().isOk()).andExpect(jsonPath("$.token").isNotEmpty());
    }

    @Test
    void registerDuplicateEmail() throws Exception {
        UUID id = UUID.randomUUID();
        String email = "b" + id + "@test.com";
        register(id, email, "123456").andExpect(status().isCreated());
        register(UUID.randomUUID(), email, "123456")
                .andExpect(status().isConflict()).andExpect(jsonPath("$.code").value("EMAIL_ALREADY_EXISTS"));
    }

    @Test
    void registerDuplicateId() throws Exception {
        UUID id = UUID.randomUUID();
        register(id, "c" + id + "@test.com", "123456").andExpect(status().isCreated());
        register(id, "d" + id + "@test.com", "123456")
                .andExpect(status().isConflict()).andExpect(jsonPath("$.code").value("ID_ALREADY_EXISTS"));
    }

    @Test
    void loginWrongPassword() throws Exception {
        UUID id = UUID.randomUUID();
        String email = "e" + id + "@test.com";
        register(id, email, "123456").andExpect(status().isCreated());
        login(email, "sai-mat-khau")
                .andExpect(status().isUnauthorized()).andExpect(jsonPath("$.code").value("INVALID_CREDENTIALS"));
    }

    @Test
    void registerShortPasswordIsRejected() throws Exception {
        UUID id = UUID.randomUUID();
        register(id, "f" + id + "@test.com", "123")
                .andExpect(status().isBadRequest()).andExpect(jsonPath("$.code").value("VALIDATION_FAILED"));
    }
}
