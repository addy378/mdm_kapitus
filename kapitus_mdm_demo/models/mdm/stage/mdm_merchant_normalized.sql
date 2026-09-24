-- MDM_STAGE.mdm_merchant_normalized
-- One row per source record, holding only the comparable form.
-- Mirrors the walkthrough's "Normalize" stage.

with base as (
    select
        m.source_system || ':' || m.source_key as record_id,
        m.source_system,
        m.source_key,
        m.platform_sid,
        m.merchant_name,
        m.tax_id,
        a.address_1,
        a.city,
        a.state_code,
        a.zip5
    from {{ ref('stg_merchants') }} m
    left join {{ ref('stg_merchant_addresses') }} a
        on m.source_system = a.source_system
        and m.source_key = a.source_key
),

cleaned as (
    select
        *,
        upper(trim(regexp_replace(merchant_name, '[^A-Za-z0-9 &]', ''))) as name_upper,
        regexp_replace(coalesce(tax_id, ''), '[^0-9]', '') as ein_digits
    from base
),

flagged as (
    select
        *,
        case
            when ein_digits = '' then false
            when length(ein_digits) != 9 then false
            -- reject known placeholder patterns (all-zeros, near-all-zeros)
            when ein_digits in ('000000000', '000000001') then false
            else true
        end as ein_valid
    from cleaned
)

select
    record_id,
    source_system,
    source_key,
    platform_sid,

    -- name: split trailing legal suffix into its own column
    trim(regexp_replace(name_upper, '\\s+(LLC|INC|CORP|CO|LTD)$', '')) as name_norm,
    regexp_substr(name_upper, '(LLC|INC|CORP|CO|LTD)$') as suffix,

    -- EIN: hash only if valid; the clear value never leaves this model
    case when ein_valid then sha2(ein_digits) else null end as ein_hash,
    ein_valid,

    -- street: minimal normalization (extend this for real data - unit
    -- formats, "AVE"/"AVENUE", "STE"/"SUITE" etc. are not handled yet)
    upper(trim(regexp_replace(address_1, '\\bST$', 'STREET'))) as street_norm,

    upper(trim(city)) as city_norm,
    zip5,

    upper(trim(address_1)) || ' ' || upper(trim(city)) || ' '
        || coalesce(state_code, '') || ' ' || coalesce(zip5, '') as search_text,

    -- placeholder for real incremental logic - fingerprint the source row
    -- so unchanged records can be skipped on rerun
    md5(concat_ws('|', record_id, merchant_name, tax_id, address_1, city, zip5)) as source_record_hash

from flagged
