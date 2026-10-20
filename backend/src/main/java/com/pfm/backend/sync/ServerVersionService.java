package com.pfm.backend.sync;

import jakarta.persistence.EntityManager;
import jakarta.persistence.PersistenceContext;
import org.springframework.stereotype.Service;

@Service
public class ServerVersionService {
    @PersistenceContext
    private EntityManager entityManager;

    public long next() {
        return ((Number) entityManager
                .createNativeQuery("SELECT NEXT VALUE FOR seq_server_version")
                .getSingleResult())
                .longValue();
    }
}
