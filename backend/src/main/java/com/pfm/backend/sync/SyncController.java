package com.pfm.backend.sync;

import com.pfm.backend.sync.dto.PushRequest;
import com.pfm.backend.sync.dto.PushResponse;
import java.util.UUID;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.security.oauth2.jwt.Jwt;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

@RestController
@RequestMapping("/sync")
public class SyncController {
    private final SyncPushService pushService;
    public SyncController(SyncPushService pushService) { this.pushService = pushService; }
    @PostMapping("/push")
    public PushResponse push(@AuthenticationPrincipal Jwt jwt, @RequestBody PushRequest req) {
        return pushService.push(UUID.fromString(jwt.getSubject()), req);
    }
}
