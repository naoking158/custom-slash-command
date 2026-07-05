# Specification Review Checklist

Purpose: verify a specification is complete, unambiguous, correct, verifiable, and traceable before planning begins.
Report violations only; severity tags are defaults, adjust with justification.

## Completeness
- [H] All required sections (Overview, User Stories, Interface, Data Models, Edge Cases) exist
- [H] Each user story has acceptance criteria defined
- [H] Scope is clearly defined with In Scope / Out of Scope distinction
- [H] Edge cases and error cases are comprehensively listed
- [M] Assumptions and constraints are documented

## Clarity
- [H] Each requirement has only one possible interpretation (no ambiguous terms like "appropriate", "sufficient")
- [M] Terminology is used consistently throughout the document
- [L] Abbreviations and technical terms are defined or explained at first use
- [M] Numerical criteria are specific (e.g., "within 200ms" instead of "fast")

## Correctness
- [H] No contradictions between requirements
- [H] Content is consistent with referenced documents (Research Document, etc.)
- [H] Only technically feasible requirements are included
- [H] Data models and interface definitions are consistent with each other

## Verifiability
- [H] Each requirement can be verified through testing (no subjective criteria)
- [M] Acceptance criteria are in a format that allows binary "done" or "not done" judgment
- [M] Performance requirements include measurement methods

## Traceability
- [M] References to Research Document are included
- [M] Rationale and source for each requirement are clear
- [L] Links to related existing features and documents are provided
