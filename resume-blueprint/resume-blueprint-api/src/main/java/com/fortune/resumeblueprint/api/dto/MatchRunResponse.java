package com.fortune.resumeblueprint.api.dto;

import java.time.OffsetDateTime;
import java.util.List;

public record MatchRunResponse(
        long matchRunId,
        long resumeDocumentId,
        String target,
        String roleFilter,
        String levelFilter,
        String algoVersion,
        OffsetDateTime createdAt,
        List<MatchResponse.ProfileMatch> matches
) {}
