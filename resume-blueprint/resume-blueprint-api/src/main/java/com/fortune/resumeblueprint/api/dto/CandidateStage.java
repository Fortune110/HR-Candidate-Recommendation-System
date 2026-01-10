package com.fortune.resumeblueprint.api.dto;

/**
 * Candidate pipeline stage enum.
 * Stages: new → screened → shortlisted → interviewed → offer → hired / rejected
 */
public enum CandidateStage {
    NEW("new"),
    SCREENED("screened"),
    SHORTLISTED("shortlisted"),
    INTERVIEWED("interviewed"),
    OFFER("offer"),
    HIRED("hired"),        // Final state
    REJECTED("rejected");  // Final state

    private final String value;

    CandidateStage(String value) {
        this.value = value;
    }

    public String getValue() {
        return value;
    }

    public static CandidateStage fromString(String value) {
        if (value == null) {
            return null;
        }
        for (CandidateStage stage : values()) {
            if (stage.value.equalsIgnoreCase(value)) {
                return stage;
            }
        }
        throw new IllegalArgumentException("Unknown candidate stage: " + value);
    }

    /**
     * Check if this is a final state (hired or rejected)
     */
    public boolean isFinalState() {
        return this == HIRED || this == REJECTED;
    }

    /**
     * Check if transition from fromStage to this stage is valid
     */
    public boolean isValidTransition(CandidateStage fromStage) {
        if (fromStage == null) {
            // Initial state must be NEW
            return this == NEW;
        }

        // Rejected can be reached from any non-final state
        if (this == REJECTED) {
            return !fromStage.isFinalState();
        }

        // Hired can only be reached from OFFER
        if (this == HIRED) {
            return fromStage == OFFER;
        }

        // Normal progression: new → screened → shortlisted → interviewed → offer
        // Allow staying at the same stage (idempotency)
        if (this == fromStage) {
            return true;
        }

        // Linear progression only
        CandidateStage[] progression = {NEW, SCREENED, SHORTLISTED, INTERVIEWED, OFFER};
        int fromIndex = -1;
        int toIndex = -1;
        for (int i = 0; i < progression.length; i++) {
            if (progression[i] == fromStage) {
                fromIndex = i;
            }
            if (progression[i] == this) {
                toIndex = i;
            }
        }

        if (fromIndex == -1 || toIndex == -1) {
            return false;
        }

        // Can only move forward by one step
        return toIndex == fromIndex + 1;
    }
}
