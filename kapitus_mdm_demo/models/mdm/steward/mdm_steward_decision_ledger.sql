-- MDM_STEWARD.mdm_steward_decision_ledger
-- In production, a steward inserts a row here directly (MERGE /
-- KEEP_SEPARATE / SPLIT); the next run reads it before clustering. This
-- demo simulates that by seeding two decisions that mirror the
-- walkthrough's own worked examples (C-0001 MERGE, C-0004 KEEP_SEPARATE) -
-- see seeds/seed_steward_decisions.csv.

select
    d.case_id,
    c.record_a,
    c.record_b,
    d.decision,
    d.decided_by,
    d.decided_at
from {{ ref('seed_steward_decisions') }} d
join {{ ref('mdm_steward_case') }} c
    on d.case_id = c.case_id
