# Kapitus MDM Demo — Merchant Entity Resolution Sandbox

A working dbt project that runs the whole Merchant entity-resolution pipeline
end to end — normalize → Tier 1 exact → Tier 2 fuzzy → score/band → steward →
cluster → survive → publish crosswalk → Gold Core consumption — against
**sample data modeled on real defect patterns**, so you can test matching
strategies before real Silver/Snowflake access is finalized.

It maps directly onto `ACT_Working_Design_v0.md` (the design doc built
earlier) — same table names, same stage order, same schemas.

## What this is for

- Testing whether the design in the working doc actually produces sensible
  results, before wiring it to real data
- Having something concrete to bring to grooming for PHDAT-369/370
- A safe place to try changing thresholds, weights, or blocking rules and
  see what breaks
- **Not** a production template to copy as-is — see §3 below for exactly
  what would need to change.

## 1. How to run it

You said dbt Cloud is already connected to both your Snowflake trial and
GitHub, so:

1. Push this whole folder as a new repo (or a branch/subfolder of an
   existing one) to GitHub:
   ```bash
   git init
   git add .
   git commit -m "Initial MDM demo project"
   git remote add origin <your-repo-url>
   git push -u origin main
   ```
2. In dbt Cloud, point your project at this repo (or create a new dbt Cloud
   project for it) and select the branch.
3. In the dbt Cloud IDE or a job, run:
   ```bash
   dbt deps      # installs dbt_utils
   dbt seed      # loads all the sample data + config tables
   dbt run       # builds the full pipeline
   dbt test      # runs the generic + custom tests
   ```
4. Look at the results, in this order, to understand what happened:
   - `mdm_merchant_normalized` — check the normalized/hashed values
   - `mdm_merchant_candidate_pair` — see which pairs got compared, and by
     which tier/rule
   - `mdm_merchant_match_score` — the full evidence table with scores and
     bands
   - `mdm_steward_case` — which pairs need a human decision
   - `mdm_merchant_cluster` — which records got grouped together
   - `mdm_merchant_golden` — the final golden records
   - `mdm_merchant_xref` — the crosswalk Gold Core reads
   - `gc_prep_merchant` / `gc_merchant` — proof Gold Core needs zero
     identity logic of its own

## 2. What the sample data is designed to demonstrate

Every row was chosen to reproduce a specific pattern from the FND design
walkthrough, so you can verify the pipeline handles each case the way the
walkthrough describes:

| Sample | What it tests |
|---|---|
| Acme Bakery (SFSDB, Salesforce, KEF_ORION) | Shared-source-ID match (Salesforce↔SFSDB) + an EIN typo that forces steward review even at a near-1.0 fuzzy score |
| Wade Group (two SFSDB rows) | Clean Tier 1 exact match on a real shared EIN |
| 1 Tree Expert (two SFSDB rows) | Same name+address, but EINs genuinely differ — the EIN-conflict guard should force `STEWARD_REVIEW`, not auto-match |
| DPR Consult | A placeholder EIN (`00-0000000`) — must be treated as *missing*, not as a real value |
| 1 Way Transportation vs. One Way Transport | The Tier 2 blocking gap — different first name-token means they're never even compared. Check: does this pair appear anywhere in `mdm_merchant_candidate_pair`? It shouldn't — that's the point, and it's exactly the gap Tier 3 (not built here) is meant to close |
| Braeswood Trillion vs. Braeswood Trill Inc | A close-but-not-identical name pair that *does* share a first token — worth comparing its actual score here against the walkthrough's own (different) Tier-3 example |
| Acme Baking / Acme Equipment Rental vs. Acme Bakery | Same first token + zip, but different enough businesses to test where NO_MATCH vs. STEWARD_REVIEW lands |
| Zip stored as `7307` instead of `07307` | Confirms the `LPAD` fix in `stg_merchant_addresses` actually restores the leading zero before matching |

The steward decisions seeded in `seed_steward_decisions.csv` mirror the
walkthrough's own worked examples (its case `C-0001` → `MERGE`, `C-0004` →
`KEEP_SEPARATE`) so you can check the cluster/golden outputs against
something already validated in the design doc.

**Note:** exact scores in this demo will not match the walkthrough's
illustrative numbers precisely — this demo only implements Tier 1 + Tier 2
(no Cortex Search / Tier 3), and uses its own similarity function calls.
The point is to check the *shape* of the results (which pairs match, which
go to steward, which don't match at all), not to reproduce exact decimals.

## 3. What's demo-grade — confirm/replace before this touches real data

This is the most important section. Everything below is a deliberate
shortcut made *because* real access wasn't available yet — not a design
recommendation.

| Shortcut in this demo | What production needs instead |
|---|---|
| Golden keys minted with `ROW_NUMBER()` (`mdm_merchant_golden.sql`) | A real Snowflake sequence per `mdm_golden_key_standard` (PHDAT-366) — `ROW_NUMBER()` is not stable across reruns and could silently reassign keys |
| `mdm_merchant_xref` is a full-refresh table, no history | True SCD2 using the repo's existing `scd2_merge` macro — rows must never be overwritten |
| Address survivorship picks arbitrarily (`address_pick` in `mdm_merchant_golden.sql`) | A real `RECENCY` signal — needs an actual last-modified timestamp from Silver, which isn't in this demo's sample columns |
| Clustering uses a depth-capped recursive CTE | Explicitly flagged in `mdm_merchant_cluster.sql` as untested at real scale (1.1M+ records) — evaluate a proper graph/union-find approach before relying on this at volume |
| Tier 3 / Cortex Search not implemented | Still an open architecture decision (per the walkthrough) — don't build until the recall test settles it |
| No steward UI | Matches the walkthrough's own scope (tables only) — but steward ownership is still unassigned; tables alone don't make the workflow operate |
| `run_id` is just `current_timestamp()` | Real system gets `run_id`/`run_ts_utc` from Dagster (PHDAT-321 dependency) |
| Column names in `seed_slv_merchants.csv` / `seed_slv_merchant_addresses.csv` | **Assumed**, based on the walkthrough. Confirm against real Silver DDL the moment you have access, and update `stg_merchants.sql` / `stg_merchant_addresses.sql` accordingly |
| Thresholds (0.90 / 0.70) and field weights | Still "illustrative" per the FND ticket (open items R1/R2) — fine to test against, not fine to treat as final |

## 4. Swapping in real Silver data, once you have access

The only two files that need to change are:
- `models/staging/stg_merchants.sql`
- `models/staging/stg_merchant_addresses.sql`

Replace the `{{ ref('seed_slv_merchants') }}` / `{{ ref('seed_slv_merchant_addresses') }}`
with `{{ source('silver', 'slv_merchants') }}` / `{{ source('silver', 'slv_merchant_addresses') }}`
(you'll need a `sources.yml` declaring the `silver` source once you know the
real database/schema), and adjust column names to match the real DDL.
Everything downstream (`mdm_merchant_normalized` onward) should keep working
unchanged, since it only depends on the staging layer's contract, not on
where the data came from.

## 5. A few things worth double-checking once you can actually run this

- **`JAROWINKLER_SIMILARITY`** — used in `mdm_merchant_candidate_pair_tier2.sql`.
  Confirm this function is available in your Snowflake trial edition/region;
  if not, `EDITDISTANCE` is a fallback (different scale, would need
  reweighting).
- **Recursive CTE support/limits** — `mdm_merchant_cluster.sql` uses
  `WITH RECURSIVE`. Snowflake supports this, but confirm behavior/depth
  limits in your account, especially if you add larger or more densely
  connected sample data later.
- **Regex behavior** — the suffix-stripping and street normalization regexes
  in `mdm_merchant_normalized.sql` are intentionally minimal. Expect to
  extend them once you see real messy name/address data (unit formats,
  more legal suffixes, abbreviation variants).

## 6. Suggested experiments once it's running

- Add a new sample pair designed to be *ambiguous* on purpose and watch
  which band it lands in — does it match your intuition?
- Change `seed_mdm_field_weights` and re-run — how much does the Braeswood
  pair's score move?
- Add a third source system record for one of the existing merchants and
  confirm the cluster correctly picks it up.
- Try lowering the Tier 2 block key to zip5-only (drop the first-token
  requirement) and see how many more (and how many wrong) candidate pairs
  it generates — this is a good way to build intuition for the blocking
  tradeoff before the real R1/R2 governance conversation.
