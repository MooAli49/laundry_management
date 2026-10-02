-- =============================================================================
-- Migration: 20261002000002_sync_snapshot_recovery.sql
-- Description: SUSP-01 — CURSOR_TOO_OLD / Full Resync Snapshot Recovery RPC
-- Purpose:
--   Provides an atomic, authoritative full database snapshot for devices whose
--   sync cursor has fallen behind the retained sync_changes history (HTTP 410).
--   Emits every active business entity formatted as a SyncChangeDto-compatible
--   record in strict foreign-key dependency order, alongside the latest_sequence
--   committed at snapshot time.
-- =============================================================================

CREATE OR REPLACE FUNCTION get_sync_snapshot()
RETURNS JSONB AS $$
DECLARE
    v_latest_sequence BIGINT;
    v_changes JSONB := '[]'::jsonb;
    v_batch JSONB;
BEGIN
    -- 1. Atomically capture the latest sequence in sync_changes
    SELECT COALESCE(MAX(sequence), 0)
    INTO v_latest_sequence
    FROM sync_changes;

    -- 2. Dependencies tier 1: business_settings
    SELECT COALESCE(jsonb_agg(c), '[]'::jsonb) INTO v_batch FROM (
        SELECT
            0 AS sequence,
            'snapshot-bs-' || id AS operation_id,
            'business_settings' AS entity_type,
            id::TEXT AS entity_id,
            'create' AS operation_type,
            row_to_json(b)::jsonb AS payload,
            server_version,
            updated_at AS created_at
        FROM business_settings b
    ) c;
    v_changes := v_changes || v_batch;

    -- 3. Dependencies tier 1: storage_locations (with supported item types)
    SELECT COALESCE(jsonb_agg(c), '[]'::jsonb) INTO v_batch FROM (
        SELECT
            0 AS sequence,
            'snapshot-sl-' || sl.id AS operation_id,
            'storage_location' AS entity_type,
            sl.id::TEXT AS entity_id,
            'create' AS operation_type,
            row_to_json(sl)::jsonb || jsonb_build_object(
                'supported_item_type_ids', COALESCE((
                    SELECT jsonb_agg(slit.item_type_id)
                    FROM storage_location_item_types slit
                    WHERE slit.storage_location_id = sl.id
                ), '[]'::jsonb)
            ) AS payload,
            sl.server_version,
            sl.created_at
        FROM storage_locations sl
        ORDER BY sl.created_at ASC
    ) c;
    v_changes := v_changes || v_batch;

    -- 4. Dependencies tier 1: item_types
    SELECT COALESCE(jsonb_agg(c), '[]'::jsonb) INTO v_batch FROM (
        SELECT
            0 AS sequence,
            'snapshot-it-' || it.id AS operation_id,
            'item_type' AS entity_type,
            it.id::TEXT AS entity_id,
            'create' AS operation_type,
            row_to_json(it)::jsonb AS payload,
            server_version,
            created_at
        FROM item_types it
        ORDER BY created_at ASC
    ) c;
    v_changes := v_changes || v_batch;

    -- 5. Dependencies tier 2: item_definitions (depends on item_types)
    SELECT COALESCE(jsonb_agg(c), '[]'::jsonb) INTO v_batch FROM (
        SELECT
            0 AS sequence,
            'snapshot-id-' || id_row.id AS operation_id,
            'item_definition' AS entity_type,
            id_row.id::TEXT AS entity_id,
            'create' AS operation_type,
            row_to_json(id_row)::jsonb AS payload,
            server_version,
            created_at
        FROM item_definitions id_row
        ORDER BY created_at ASC
    ) c;
    v_changes := v_changes || v_batch;

    -- 6. Dependencies tier 1: carpet_sizes
    SELECT COALESCE(jsonb_agg(c), '[]'::jsonb) INTO v_batch FROM (
        SELECT
            0 AS sequence,
            'snapshot-cs-' || cs.id AS operation_id,
            'carpet_size' AS entity_type,
            cs.id::TEXT AS entity_id,
            'create' AS operation_type,
            row_to_json(cs)::jsonb AS payload,
            server_version,
            created_at
        FROM carpet_sizes cs
        ORDER BY created_at ASC
    ) c;
    v_changes := v_changes || v_batch;

    -- 7. Dependencies tier 2: services (with service_item_types)
    SELECT COALESCE(jsonb_agg(c), '[]'::jsonb) INTO v_batch FROM (
        SELECT
            0 AS sequence,
            'snapshot-srv-' || s.id AS operation_id,
            'service' AS entity_type,
            s.id::TEXT AS entity_id,
            'create' AS operation_type,
            row_to_json(s)::jsonb || jsonb_build_object(
                'service_item_types', COALESCE((
                    SELECT jsonb_agg(row_to_json(sit))
                    FROM service_item_types sit
                    WHERE sit.service_id = s.id
                ), '[]'::jsonb)
            ) AS payload,
            s.server_version,
            s.created_at
        FROM services s
        ORDER BY created_at ASC
    ) c;
    v_changes := v_changes || v_batch;

    -- 8. Dependencies tier 1: expense_categories
    SELECT COALESCE(jsonb_agg(c), '[]'::jsonb) INTO v_batch FROM (
        SELECT
            0 AS sequence,
            'snapshot-ec-' || ec.id AS operation_id,
            'expense_category' AS entity_type,
            ec.id::TEXT AS entity_id,
            'create' AS operation_type,
            row_to_json(ec)::jsonb AS payload,
            server_version,
            created_at
        FROM expense_categories ec
        ORDER BY created_at ASC
    ) c;
    v_changes := v_changes || v_batch;

    -- 9. Dependencies tier 2: expenses (depends on expense_categories)
    SELECT COALESCE(jsonb_agg(c), '[]'::jsonb) INTO v_batch FROM (
        SELECT
            0 AS sequence,
            'snapshot-exp-' || e.id AS operation_id,
            'expense' AS entity_type,
            e.id::TEXT AS entity_id,
            'create' AS operation_type,
            row_to_json(e)::jsonb AS payload,
            server_version,
            created_at
        FROM expenses e
        ORDER BY created_at ASC
    ) c;
    v_changes := v_changes || v_batch;

    -- 10. Dependencies tier 1: customers
    SELECT COALESCE(jsonb_agg(c), '[]'::jsonb) INTO v_batch FROM (
        SELECT
            0 AS sequence,
            'snapshot-cust-' || cust.id AS operation_id,
            'customer' AS entity_type,
            cust.id::TEXT AS entity_id,
            'create' AS operation_type,
            row_to_json(cust)::jsonb AS payload,
            server_version,
            created_at
        FROM customers cust
        ORDER BY created_at ASC
    ) c;
    v_changes := v_changes || v_batch;

    -- 11. Dependencies tier 3: orders (depends on customers, services, item_types)
    SELECT COALESCE(jsonb_agg(c), '[]'::jsonb) INTO v_batch FROM (
        SELECT
            0 AS sequence,
            'snapshot-ord-' || o.id AS operation_id,
            'order' AS entity_type,
            o.id::TEXT AS entity_id,
            'create' AS operation_type,
            row_to_json(o)::jsonb || jsonb_build_object(
                'items', COALESCE((
                    SELECT jsonb_agg(
                        row_to_json(oi)::jsonb || jsonb_build_object(
                            'carpet_data', (
                                SELECT row_to_json(oic)
                                FROM order_item_carpets oic
                                WHERE oic.order_item_id = oi.id
                                LIMIT 1
                            )
                        )
                    )
                    FROM order_items oi
                    WHERE oi.order_id = o.id
                ), '[]'::jsonb)
            ) AS payload,
            o.server_version,
            o.created_at
        FROM orders o
        ORDER BY created_at ASC
    ) c;
    v_changes := v_changes || v_batch;

    -- 12. Dependencies tier 4: payments (depends on orders)
    SELECT COALESCE(jsonb_agg(c), '[]'::jsonb) INTO v_batch FROM (
        SELECT
            0 AS sequence,
            'snapshot-pay-' || p.id AS operation_id,
            'payment' AS entity_type,
            p.id::TEXT AS entity_id,
            'create' AS operation_type,
            row_to_json(p)::jsonb AS payload,
            NULL::INT AS server_version,
            created_at
        FROM payments p
        ORDER BY created_at ASC
    ) c;
    v_changes := v_changes || v_batch;

    -- 13. Dependencies tier 4: refunds (depends on orders, payments)
    SELECT COALESCE(jsonb_agg(c), '[]'::jsonb) INTO v_batch FROM (
        SELECT
            0 AS sequence,
            'snapshot-ref-' || r.id AS operation_id,
            'refund' AS entity_type,
            r.id::TEXT AS entity_id,
            'create' AS operation_type,
            row_to_json(r)::jsonb AS payload,
            NULL::INT AS server_version,
            created_at
        FROM refunds r
        ORDER BY created_at ASC
    ) c;
    v_changes := v_changes || v_batch;

    -- 14. Dependencies tier 4: storage_records (depends on order_items, storage_locations)
    SELECT COALESCE(jsonb_agg(c), '[]'::jsonb) INTO v_batch FROM (
        SELECT
            0 AS sequence,
            'snapshot-sr-' || sr.id AS operation_id,
            'storage_record' AS entity_type,
            sr.id::TEXT AS entity_id,
            'create' AS operation_type,
            row_to_json(sr)::jsonb AS payload,
            NULL::INT AS server_version,
            created_at
        FROM storage_records sr
        WHERE sr.is_active = true
        ORDER BY created_at ASC
    ) c;
    v_changes := v_changes || v_batch;

    RETURN jsonb_build_object(
        'changes', v_changes,
        'has_more', false,
        'latest_sequence', COALESCE(v_latest_sequence, 0)
    );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

ALTER FUNCTION public.get_sync_snapshot() SET search_path = public, pg_temp;
GRANT EXECUTE ON FUNCTION public.get_sync_snapshot() TO anon, authenticated, service_role;
