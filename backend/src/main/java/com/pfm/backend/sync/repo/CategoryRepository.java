package com.pfm.backend.sync.repo;
import com.pfm.backend.sync.entity.Category;
import java.util.UUID;
import java.util.List;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.domain.Pageable;
public interface CategoryRepository extends JpaRepository<Category, UUID> {
    List<Category> findByUserIdAndServerVersionGreaterThanOrderByServerVersionAsc(UUID userId, long serverVersion, Pageable pageable);
}
