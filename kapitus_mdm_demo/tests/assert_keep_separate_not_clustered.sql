-- Passes if this returns zero rows. If a steward said KEEP_SEPARATE, those
-- two records must never end up sharing a cluster_id, no matter what the
-- scoring pipeline would otherwise have chained them into.

select
    l.record_a,
    l.record_b,
    ca.cluster_id as cluster_a,
    cb.cluster_id as cluster_b
from {{ ref('mdm_steward_decision_ledger') }} l
join {{ ref('mdm_merchant_cluster') }} ca on l.record_a = ca.record_id
join {{ ref('mdm_merchant_cluster') }} cb on l.record_b = cb.record_id
where l.decision = 'KEEP_SEPARATE'
  and ca.cluster_id = cb.cluster_id
