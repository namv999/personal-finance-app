package com.pfm.backend.sync.repo;
import com.pfm.backend.sync.entity.MonthlyBudget;
import java.util.List;
import java.util.UUID;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.domain.Pageable;
public interface MonthlyBudgetRepository extends JpaRepository<MonthlyBudget, UUID> {
    List<MonthlyBudget> findByUserIdAndCategoryIdAndMonthAndDeletedFalse(UUID userId, UUID categoryId, String month);
    List<MonthlyBudget> findByUserIdAndServerVersionGreaterThanOrderByServerVersionAsc(UUID userId, long serverVersion, Pageable pageable);
}
