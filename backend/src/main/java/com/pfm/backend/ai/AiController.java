package com.pfm.backend.ai;

import com.pfm.backend.ai.dto.ParseTextRequest;
import com.pfm.backend.ai.dto.ParseTextResponse;
import jakarta.validation.Valid;
import org.springframework.web.bind.annotation.*;

@RestController
@RequestMapping("/ai")
public class AiController {
    private final AiParseService service;

    public AiController(AiParseService service) {
        this.service = service;
    }

    @PostMapping("/parse-text")
    public ParseTextResponse parseText(@Valid @RequestBody ParseTextRequest request) {
        return service.parse(request);
    }
}
