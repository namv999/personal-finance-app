package com.pfm.backend.sync;

import com.pfm.backend.sync.dto.PushRequest;
import com.pfm.backend.sync.dto.PushResponse;
import com.pfm.backend.sync.dto.PullResponse;
import java.util.UUID;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.security.oauth2.jwt.Jwt;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

@RestController
@RequestMapping("/sync")
public class SyncController {
    private final SyncPushService pushService;
    private final SyncPullService pullService;
    public SyncController(SyncPushService pushService, SyncPullService pullService) {
        this.pushService = pushService;
        this.pullService = pullService;
    }
    @PostMapping("/push")
    public PushResponse push(@AuthenticationPrincipal Jwt jwt, @RequestBody PushRequest req) {
        return pushService.push(UUID.fromString(jwt.getSubject()), req);
    }

    @GetMapping("/pull")
    public PullResponse pull(@AuthenticationPrincipal Jwt jwt,
            @RequestParam(defaultValue = "0") long cursor,
            @RequestParam(defaultValue = "500") int limit) {
        return pullService.pull(UUID.fromString(jwt.getSubject()), cursor, limit);
    }
}
