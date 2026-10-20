# Mount-fix workflow wiring, offline prepared

Candidate source6dd72…fc4dd/runtimec000b…458b is immutable. Fixed imports and child
paths use photo-album-authority-mount-fix. Readers/producer/downloader/guards unchanged.
Default entry disabled; source entry requires new independent candidate/code/human
packets. Draft candidateReviewSHA=zero is explicitly no authority; no PASS review
receipt is authored here. Existing real review/human/cold for consumed task00af…
cannot bind to new proposal/task/sha.

Reviewer first publishes fixed candidate packet (new actual v4 candidate review,
same preparation bytes, actual proposal with only candidateReviewSHA completed),
seals/checks it by the existing PacketSeal contract. Then creates orchestration
freeze/review binding actual published proposal SHA and exact codeHash. Both are
before human question/capture and before one fresh cold. This resolves future review
hashes without editing frozen workflow source or inventing a reviewer PASS.

Global workflow base/registry remains tiktok-photo-album-workflow-v1, shared across
candidate storage versions; CreateNew reservation is before bootstrap. Candidate
registry is fixed mount-fix namespace; its v4 latch/claim consumes before capability.
Offline scopes/simulation only here. No Docker cold/source/real claims/renew/retry.
