package com.fortune.resumeblueprint.api;

import com.fortune.resumeblueprint.api.dto.ImportProfileRequest;
import com.fortune.resumeblueprint.api.dto.ImportProfileResponse;
import com.fortune.resumeblueprint.service.SuccessProfileService;
import jakarta.validation.Valid;
import org.springframework.web.bind.annotation.*;

@RestController
@RequestMapping("/api/success-profiles")
public class SuccessProfileController {
    
    private final SuccessProfileService service;
    
    public SuccessProfileController(SuccessProfileService service) {
        this.service = service;
    }
    
    /**
     * Import a success profile
     * 
     * POST /api/success-profiles/import
     * Body: {
     *   "source": "internal_employee",
     *   "role": "Java Backend Engineer",
     *   "level": "mid",
     *   "company": "Acme Corp",
     *   "text": "Profile text here..."
     * }
     */
    @PostMapping("/import")
    public ImportProfileResponse importProfile(@RequestBody @Valid ImportProfileRequest req) {
        long profileId = service.importProfile(
                req.source(),
                req.role(),
                req.level(),
                req.company(),
                req.text()
        );
        
        return new ImportProfileResponse(profileId, "Profile imported successfully");
    }
}
