package com.pfm.backend.auth;

import java.util.Optional;
import java.util.UUID;
import org.springframework.data.jpa.repository.JpaRepository;

public interface UserRepository extends JpaRepository<User, UUID> {
    Optional<User> findByEmailAndDeletedFalse(String email);
    boolean existsByEmail(String email);
}
