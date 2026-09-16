import "jsr:@supabase/functions-js/edge-runtime.d.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2.45.4";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type, x-operation-id",
  "Access-Control-Allow-Methods": "GET, POST, PATCH, PUT, DELETE, OPTIONS",
};

function jsonResponse(body: unknown, status = 200): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: {
      ...corsHeaders,
      "Content-Type": "application/json",
    },
  });
}

function errorResponse(code: string, message: string, requestId: string, status = 400): Response {
  return jsonResponse(
    {
      code,
      message,
      requestId,
    },
    status,
  );
}

function mapPostgresError(error: { code?: string; message: string }, requestId: string): Response {
  const code = error.code || "";
  const msg = error.message || "Database error";

  if (code === "23505" || msg.includes("already exists")) {
    return errorResponse("CONFLICT", msg, requestId, 409);
  }
  if (code === "P0002" || msg.includes("not found")) {
    return errorResponse("NOT_FOUND", msg, requestId, 404);
  }
  if (code === "23514" || code === "23502" || msg.includes("Invalid") || msg.includes("required")) {
    return errorResponse("VALIDATION_ERROR", msg, requestId, 422);
  }
  if (code === "23503" || msg.includes("does not exist")) {
    return errorResponse("FOREIGN_KEY_VIOLATION", msg, requestId, 400);
  }

  return errorResponse("BAD_REQUEST", msg, requestId, 400);
}

Deno.serve(async (req: Request) => {
  // 1. CORS Preflight
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  const url = new URL(req.url);
  // Extract and normalize path: strip any combination of prefixes
  let path = url.pathname;
  path = path.replace(/^(\/functions\/v1\/api|\/api|\/v1)+/, "");
  if (!path.startsWith("/")) {
    path = "/" + path;
  }
  // Trim trailing slash
  if (path.length > 1 && path.endsWith("/")) {
    path = path.slice(0, -1);
  }

  const method = req.method;
  const operationId = req.headers.get("x-operation-id") || crypto.randomUUID();

  // Initialize trusted service-role Supabase client
  const supabaseUrl = Deno.env.get("SUPABASE_URL") ?? "";
  const supabaseServiceKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "";
  const supabase = createClient(supabaseUrl, supabaseServiceKey);

  try {
    // -------------------------------------------------------------------------
    // Customers API
    // -------------------------------------------------------------------------
    if (path === "/customers" || path.startsWith("/customers/")) {
      const parts = path.split("/").filter(Boolean);
      const customerId = parts[1]; // /customers/:id

      if (method === "GET") {
        if (customerId) {
          const { data, error } = await supabase.from("customers").select("*").eq("id", customerId).maybeSingle();
          if (error) return mapPostgresError(error, operationId);
          if (!data) return errorResponse("NOT_FOUND", "Customer not found", operationId, 404);
          return jsonResponse(data);
        } else {
          const { data, error } = await supabase.from("customers").select("*").order("created_at", { ascending: false });
          if (error) return mapPostgresError(error, operationId);
          return jsonResponse(data ?? []);
        }
      }

      if (method === "POST") {
        const body = await req.json();
        const { data, error } = await supabase.rpc("sync_create_customer", {
          p_op_id: operationId,
          p_customer: body,
        });
        if (error) return mapPostgresError(error, operationId);
        return jsonResponse(data, 201);
      }

      if (method === "PATCH" && customerId) {
        const body = await req.json();
        const { data, error } = await supabase.rpc("sync_update_customer", {
          p_op_id: operationId,
          p_customer_id: customerId,
          p_customer: body,
        });
        if (error) return mapPostgresError(error, operationId);
        return jsonResponse(data, 200);
      }
    }

    // -------------------------------------------------------------------------
    // Orders API (Aggregate Atomic Transaction)
    // -------------------------------------------------------------------------
    if (path === "/orders" || path.startsWith("/orders/")) {
      const parts = path.split("/").filter(Boolean);
      const orderId = parts[1]; // /orders/:id

      if (method === "GET") {
        if (orderId) {
          const { data, error } = await supabase
            .from("orders")
            .select("*, order_items(*, order_item_carpets(*))")
            .eq("id", orderId)
            .maybeSingle();
          if (error) return mapPostgresError(error, operationId);
          if (!data) return errorResponse("NOT_FOUND", "Order not found", operationId, 404);
          return jsonResponse(data);
        } else {
          const { data, error } = await supabase
            .from("orders")
            .select("*, order_items(*)")
            .order("created_at", { ascending: false });
          if (error) return mapPostgresError(error, operationId);
          return jsonResponse(data ?? []);
        }
      }

      if (method === "POST") {
        const body = await req.json();
        const items = body.items || [];
        const { data, error } = await supabase.rpc("sync_create_order_aggregate", {
          p_op_id: operationId,
          p_order: body,
          p_items: items,
        });
        if (error) return mapPostgresError(error, operationId);
        return jsonResponse(data, 201);
      }

      if (method === "PATCH" && orderId) {
        const body = await req.json();
        const { data, error } = await supabase.rpc("sync_update_order", {
          p_op_id: operationId,
          p_order_id: orderId,
          p_order: body,
        });
        if (error) return mapPostgresError(error, operationId);
        return jsonResponse(data, 200);
      }
    }

    // -------------------------------------------------------------------------
    // Services API
    // -------------------------------------------------------------------------
    if (path === "/services" || path.startsWith("/services/")) {
      const parts = path.split("/").filter(Boolean);
      const serviceId = parts[1]; // /services/:id

      if (method === "GET") {
        if (serviceId) {
          const { data, error } = await supabase
            .from("services")
            .select("*, service_item_types(*)")
            .eq("id", serviceId)
            .maybeSingle();
          if (error) return mapPostgresError(error, operationId);
          if (!data) return errorResponse("NOT_FOUND", "Service not found", operationId, 404);
          return jsonResponse(data);
        } else {
          const { data, error } = await supabase
            .from("services")
            .select("*, service_item_types(*)")
            .order("name");
          if (error) return mapPostgresError(error, operationId);
          return jsonResponse(data ?? []);
        }
      }

      if (method === "POST") {
        const body = await req.json();
        const supportedItemTypeIds = body.supported_item_type_ids || null;
        const { data, error } = await supabase.rpc("sync_create_service", {
          p_op_id: operationId,
          p_service: body,
          p_item_type_ids: supportedItemTypeIds,
        });
        if (error) return mapPostgresError(error, operationId);
        return jsonResponse(data, 201);
      }

      if (method === "PATCH" && serviceId) {
        const body = await req.json();
        const supportedItemTypeIds = body.supported_item_type_ids || null;
        const { data, error } = await supabase.rpc("sync_update_service", {
          p_op_id: operationId,
          p_service_id: serviceId,
          p_service: body,
          p_item_type_ids: supportedItemTypeIds,
        });
        if (error) return mapPostgresError(error, operationId);
        return jsonResponse(data, 200);
      }
    }

    // -------------------------------------------------------------------------
    // Storage Records API (Supports both /storage and /storage-records)
    // -------------------------------------------------------------------------
    if (
      path === "/storage" ||
      path.startsWith("/storage/") ||
      path === "/storage-records" ||
      path.startsWith("/storage-records/")
    ) {
      const parts = path.split("/").filter(Boolean);
      const targetId = parts[1]; // :id or :orderItemId

      if (method === "GET") {
        if (targetId) {
          // Check by order_item_id or id
          const { data, error } = await supabase
            .from("storage_records")
            .select("*")
            .or(`id.eq.${targetId},order_item_id.eq.${targetId}`)
            .eq("is_active", true)
            .maybeSingle();
          if (error) return mapPostgresError(error, operationId);
          if (!data) return errorResponse("NOT_FOUND", "Active storage record not found", operationId, 404);
          return jsonResponse(data);
        } else {
          const { data, error } = await supabase
            .from("storage_records")
            .select("*")
            .eq("is_active", true);
          if (error) return mapPostgresError(error, operationId);
          return jsonResponse(data ?? []);
        }
      }

      if (method === "POST") {
        const body = await req.json();
        const { data, error } = await supabase.rpc("sync_create_storage_record", {
          p_op_id: operationId,
          p_storage: body,
        });
        if (error) return mapPostgresError(error, operationId);
        return jsonResponse(data, 201);
      }

      if (method === "PATCH" && targetId) {
        const body = await req.json();
        const { data, error } = await supabase.rpc("sync_update_storage_record", {
          p_op_id: operationId,
          p_record_id: targetId,
          p_storage: body,
        });
        if (error) return mapPostgresError(error, operationId);
        return jsonResponse(data, 200);
      }
    }

    return errorResponse("NOT_FOUND", `Endpoint ${method} ${path} not found`, operationId, 404);
  } catch (err: unknown) {
    const message = err instanceof Error ? err.message : String(err);
    return errorResponse("INTERNAL_ERROR", message, operationId, 500);
  }
});
