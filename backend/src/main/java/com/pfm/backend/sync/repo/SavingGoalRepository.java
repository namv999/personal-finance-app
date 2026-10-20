package com.pfm.backend.sync.repo;
import com.pfm.backend.sync.entity.SavingGoal;
import java.util.UUID;
import org.springframework.data.jpa.repository.JpaRepository;
public interface SavingGoalRepository extends JpaRepository<SavingGoal, UUID> {}
