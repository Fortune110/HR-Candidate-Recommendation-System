package com.fortune.resumeblueprint.api;

import com.fortune.resumeblueprint.api.dto.BaselineBuildResponse;
import com.fortune.resumeblueprint.service.BaselineService;
import org.springframework.web.bind.annotation.*;

@RestController
@RequestMapping("/api/baseline")
public class BaselineController {
    private final BaselineService service;

    public BaselineController(BaselineService service) {
        this.service = service;
    }

    @PostMapping("/build")
    public BaselineBuildResponse build(@RequestParam(defaultValue = "50") int lastN,
                                       @RequestParam(defaultValue = "2") int minCount) {
        var r = service.buildBaseline(lastN, minCount);
        return new BaselineBuildResponse(r.baselineSetId(), r.createdTerms());
    }
}
