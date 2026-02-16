package com.introspect.claims.controller;

import com.introspect.claims.service.ClaimsService;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;

import java.util.Map;

@RestController
public class ClaimsServiceController {

    @Autowired
    ClaimsService claimsService;

    public ClaimsServiceController(ClaimsService claimsService) {
        this.claimsService = claimsService;
    }

    @GetMapping("/claims")
    public ResponseEntity<String> getHello(){
        return ResponseEntity.ok(claimsService.check());
    }

    // Requirement 1: GET /claims/{id}
    @GetMapping("/{id}")
    public ResponseEntity<Map<String, Object>> getClaimStatus(@PathVariable String id) {
        return ResponseEntity.ok(claimsService.getClaimFromDb(id));
    }

    // Requirement 2: POST /claims/{id}/summarize
    @PostMapping("/{id}/summarize")
    public ResponseEntity<String> summarizeClaim(@PathVariable String id) {
        String summary = claimsService.processGenAISummary(id);
        return ResponseEntity.ok(summary);
    }
}
