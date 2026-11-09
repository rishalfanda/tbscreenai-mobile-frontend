# Backend PR40 integration - 9 November 2026

Backend source: PR #40, head fe8df03dad40f78dceea363dcb8de0d595355d89 (merged).
Exact team comment: https://github.com/rishalfanda/tbscreenai-mobile-backend/pull/40#issuecomment-6705740641

Implemented:
- Local DB v5 adds lesion_rating, validation_deleted_at, validation_deleted_by. Legacy validation_score keeps its trust-score meaning and is not backfilled into lesion_rating.
- Validation dialog/table use lesion_rating, with an explicit prompt for legacy trust-only reviews. New writes carry lesion_rating and optional/null doctor_note; the actor and confirmed time remain attached.
- Deletion queues versioned diagnosis/delete_validation with deleted_at. It preserves verdict, ratings, note, patient, screening and encrypted X-ray for audit. A deletion marker removes the item from the local validation list/counts without changing its verdict to pending.
- Deleted fields and lesion ratings survive normal diagnosis mapping, operator state refresh, encrypted handoff and doctor restore. Applied/skipped/already_deleted complete normally; actual conflicts stay in the queue.
- Local list/search/filter remain offline and owner scoped; GET /validations is not required to display locally retained screenings and images.
- Never-sent legacy score-only updates can be superseded only by a new explicit lesion rating. Legacy local archives with known versions and never-sent reset operations are upgraded to delete_validation. Ambiguous already-dispatched/retry/conflict operations are retained for verification; they are not rewritten or assigned guessed versions.
- Deletes require a known screening version. Sync a newly created screening before deleting its validation.

Deployment gate:
The live staging OpenAPI checked on 9 November 2026 still advertised the old trust-score contract, with no lesion_rating/delete-validation endpoint.
New rating/delete operations remain queued and blocked until the deployed write/read/delete contract advertises PR40.
On PR40 servers, legacy validation_score-only updates are blocked; they must not be silently interpreted as lesion ratings.
No backend deployment or real tablet/server end-to-end validation was performed.

Evidence:
- test/fixtures/pr40_validation_openapi.json is a reduced schema fixture from the exact backend head above.
- Regression coverage includes v4 data migration, preserved trust score, explicit rerating, conversion of never-sent archives, versioned deletion, optional disagreement note, already_deleted, real conflict, old-server gate and operator-state deletion propagation while retaining local X-ray.
- Local Flutter SDK 3.44.7; repository CI pins 3.47.1. Keep the canonical lockfile unchanged.
