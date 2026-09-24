-- MDM_CORE.mdm_merchant_xref
-- One row per source record, mapping it to its golden key. THIS is the
-- only MDM table the rest of the platform (Gold Core) needs to consume.
--
-- CAVEAT: the real system tracks this as true SCD2 (rows never overwritten;
-- a change closes the old row and opens a new one, via the repo's existing
-- scd2_merge macro). This demo just does a full-refresh table each run with
-- no history - fine for testing matching logic, not a template for the
-- real xref table. Also not tracked here: which tier/rule each record
-- joined through (seed/T1/T2/STEWARD) - add that once wiring to a real
-- run_id and steward audit trail.

select
    g.golden_key,
    n.source_system,
    n.source_key,
    current_date() as effective_from,
    cast(null as date) as effective_to,
    'Y' as active
from {{ ref('mdm_merchant_golden') }} g
join {{ ref('mdm_merchant_cluster') }} cl on g.cluster_id = cl.cluster_id
join {{ ref('mdm_merchant_normalized') }} n on cl.record_id = n.record_id
