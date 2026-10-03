-- Final V1 sync contract: concurrent idempotency safety and pull metadata.

CREATE OR REPLACE FUNCTION public.check_idempotency(p_op_id TEXT)
RETURNS JSONB AS $$
DECLARE
    v_response JSONB;
BEGIN
    PERFORM pg_advisory_xact_lock(hashtextextended(p_op_id, 0));
    SELECT response_payload INTO v_response
    FROM public.sync_idempotency_log
    WHERE operation_id = p_op_id;
    RETURN v_response;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER
SET search_path = public, pg_temp;

CREATE OR REPLACE FUNCTION public.get_sync_changes(
    p_after BIGINT DEFAULT 0,
    p_limit INT DEFAULT 100
) RETURNS JSONB AS $$
DECLARE
    v_limit INT;
    v_oldest_sequence BIGINT;
    v_latest_sequence BIGINT;
    v_changes JSONB;
    v_has_more BOOLEAN;
BEGIN
    v_limit := LEAST(GREATEST(COALESCE(p_limit, 100), 1), 500);

    SELECT MIN(sequence), MAX(sequence)
    INTO v_oldest_sequence, v_latest_sequence
    FROM public.sync_changes;

    IF v_oldest_sequence IS NULL THEN
        RETURN jsonb_build_object(
            'changes', '[]'::jsonb,
            'has_more', false,
            'latest_sequence', 0,
            'oldest_available_sequence', NULL
        );
    END IF;

    IF p_after > 0 AND p_after < (v_oldest_sequence - 1) THEN
        RAISE EXCEPTION
            'CURSOR_TOO_OLD: requested sequence % is older than oldest available sequence %',
            p_after, v_oldest_sequence USING ERRCODE = 'P0005';
    END IF;

    SELECT COALESCE(jsonb_agg(row_to_json(c)), '[]'::jsonb)
    INTO v_changes
    FROM (
        SELECT sequence, operation_id, entity_type, entity_id, operation_type,
               payload, server_version, created_at
        FROM public.sync_changes
        WHERE sequence > COALESCE(p_after, 0)
        ORDER BY sequence ASC
        LIMIT v_limit
    ) c;

    SELECT EXISTS (
        SELECT 1
        FROM public.sync_changes
        WHERE sequence > COALESCE(p_after, 0)
        ORDER BY sequence ASC
        OFFSET v_limit
        LIMIT 1
    ) INTO v_has_more;

    RETURN jsonb_build_object(
        'changes', v_changes,
        'has_more', v_has_more,
        'latest_sequence', COALESCE(v_latest_sequence, 0),
        'oldest_available_sequence', v_oldest_sequence
    );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER
SET search_path = public, pg_temp;