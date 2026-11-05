package com.pfm.backend.ai;

import com.pfm.backend.ai.dto.ParseTextRequest;
import com.pfm.backend.ai.dto.ParseTextResponse;
import com.pfm.backend.ai.dto.ParseImageRequest;
import com.pfm.backend.ai.dto.ParseImageResponse;
import com.pfm.backend.ai.dto.SuggestionRequest;
import com.pfm.backend.ai.dto.SuggestionResponse;
import com.pfm.backend.ai.dto.ChatRequest;
import com.pfm.backend.ai.dto.ChatResponse;
import jakarta.validation.Valid;
import java.util.UUID;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.security.oauth2.jwt.Jwt;
import org.springframework.web.bind.annotation.*;

@RestController
@RequestMapping("/ai")
public class AiController {
    private final AiParseService service;
    private final AiSuggestionService suggestionService;
    private final AiChatService chatService;

    public AiController(AiParseService service, AiSuggestionService suggestionService, AiChatService chatService) {
        this.service = service;
        this.suggestionService = suggestionService;
        this.chatService = chatService;
    }

    @PostMapping("/parse-text")
    public ParseTextResponse parseText(@Valid @RequestBody ParseTextRequest request) {
        return service.parse(request);
    }

    @PostMapping("/parse-image")
    public ParseImageResponse parseImage(@Valid @RequestBody ParseImageRequest request) {
        return service.parseImage(request);
    }

    @PostMapping("/suggestions")
    public SuggestionResponse suggest(@AuthenticationPrincipal Jwt jwt, @Valid @RequestBody SuggestionRequest request) {
        return suggestionService.suggest(UUID.fromString(jwt.getSubject()), request.periodType());
    }

    @PostMapping("/chat")
    public ChatResponse chat(@AuthenticationPrincipal Jwt jwt, @Valid @RequestBody ChatRequest request) {
        return chatService.chat(UUID.fromString(jwt.getSubject()), request);
    }
}
