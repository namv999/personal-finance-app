package com.pfm.backend.sync.repo;
import com.pfm.backend.sync.entity.SavingGoal;
import java.util.UUID;
import java.util.List;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.domain.Pageable;
public interface SavingGoalRepository extends JpaRepository<SavingGoal, UUID> {
    List<SavingGoal> findByUserIdAndServerVersionGreaterThanOrderByServerVersionAsc(UUID userId, long serverVersion, Pageable pageable);
}
