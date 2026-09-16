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

  if (
    code === "23505" ||
    msg.includes("already exists") ||
    msg.includes("cancelled") ||
    msg.includes("exceeds") ||
    msg.includes("remaining balance")
  ) {
    return errorResponse("CONFLICT", msg, requestId, 409);
  }
  if (code === "P0002" || msg.includes("not found")) {
    return errorResponse("NOT_FOUND", msg, requestId, 404);
  }
  if (
    code === "23514" ||
    code === "23502" ||
    msg.includes("Invalid") ||
    msg.includes("required") ||
    msg.includes("greater than zero")
  ) {
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

    // -------------------------------------------------------------------------
    // Payments API (Immutable in V1)
    // -------------------------------------------------------------------------
    if (path === "/payments" || path.startsWith("/payments/")) {
      const parts = path.split("/").filter(Boolean);
      const paymentId = parts[1]; // /payments/:id

      if (method === "GET") {
        if (paymentId) {
          const { data, error } = await supabase
            .from("payments")
            .select("*")
            .eq("id", paymentId)
            .maybeSingle();
          if (error) return mapPostgresError(error, operationId);
          if (!data) return errorResponse("NOT_FOUND", "Payment not found", operationId, 404);
          return jsonResponse(data, 200);
        } else {
          const orderId = url.searchParams.get("order_id");
          let query = supabase.from("payments").select("*").order("paid_at", { ascending: false });
          if (orderId) {
            query = query.eq("order_id", orderId);
          }
          const { data, error } = await query;
          if (error) return mapPostgresError(error, operationId);
          return jsonResponse(data ?? [], 200);
        }
      }

      if (method === "POST") {
        const body = await req.json();
        const { data, error } = await supabase.rpc("sync_create_payment", {
          p_op_id: operationId,
          p_payment: body,
        });
        if (error) return mapPostgresError(error, operationId);
        return jsonResponse(data, 201);
      }
    }

    // -------------------------------------------------------------------------
    // Expense Categories API
    // -------------------------------------------------------------------------
    if (path === "/expense-categories" || path.startsWith("/expense-categories/")) {
      const parts = path.split("/").filter(Boolean);
      const categoryId = parts[1]; // /expense-categories/:id

      if (method === "GET") {
        if (categoryId) {
          const { data, error } = await supabase
            .from("expense_categories")
            .select("*")
            .eq("id", categoryId)
            .maybeSingle();
          if (error) return mapPostgresError(error, operationId);
          if (!data) return errorResponse("NOT_FOUND", "Expense category not found", operationId, 404);
          return jsonResponse(data, 200);
        } else {
          let query = supabase.from("expense_categories").select("*").order("name");
          const isActiveParam = url.searchParams.get("is_active") ?? url.searchParams.get("isActive");
          if (isActiveParam !== null) {
            query = query.eq("is_active", isActiveParam === "true");
          }
          const { data, error } = await query;
          if (error) return mapPostgresError(error, operationId);
          return jsonResponse(data ?? [], 200);
        }
      }

      if (method === "POST") {
        const body = await req.json();
        const { data, error } = await supabase.rpc("sync_create_expense_category", {
          p_op_id: operationId,
          p_category: body,
        });
        if (error) return mapPostgresError(error, operationId);
        return jsonResponse(data, 201);
      }

      if (method === "PATCH" && categoryId) {
        const body = await req.json();
        const { data, error } = await supabase.rpc("sync_update_expense_category", {
          p_op_id: operationId,
          p_category_id: categoryId,
          p_category: body,
        });
        if (error) return mapPostgresError(error, operationId);
        return jsonResponse(data, 200);
      }

      if (method === "DELETE") {
        return errorResponse("NOT_FOUND", "Expense category deletion is not permitted", operationId, 404);
      }
    }

    // -------------------------------------------------------------------------
    // Expenses API
    // -------------------------------------------------------------------------
    if (path === "/expenses" || path.startsWith("/expenses/")) {
      const parts = path.split("/").filter(Boolean);
      const expenseId = parts[1]; // /expenses/:id

      if (method === "GET") {
        if (expenseId) {
          const { data, error } = await supabase
            .from("expenses")
            .select("*")
            .eq("id", expenseId)
            .maybeSingle();
          if (error) return mapPostgresError(error, operationId);
          if (!data) return errorResponse("NOT_FOUND", "Expense not found", operationId, 404);
          return jsonResponse(data, 200);
        } else {
          let query = supabase
            .from("expenses")
            .select("*")
            .order("expense_date", { ascending: false })
            .order("created_at", { ascending: false });

          const categoryId = url.searchParams.get("categoryId") ?? url.searchParams.get("category_id");
          if (categoryId) {
            query = query.eq("expense_category_id", categoryId);
          }

          const startDate = url.searchParams.get("startDate") ?? url.searchParams.get("start_date");
          if (startDate) {
            query = query.gte("expense_date", startDate);
          }

          const endDate = url.searchParams.get("endDate") ?? url.searchParams.get("end_date");
          if (endDate) {
            query = query.lte("expense_date", endDate);
          }

          const limit = parseInt(url.searchParams.get("limit") || "50", 10);
          const page = parseInt(url.searchParams.get("page") || "1", 10);
          const offset = url.searchParams.has("offset")
            ? parseInt(url.searchParams.get("offset") || "0", 10)
            : (page - 1) * limit;

          query = query.range(offset, offset + limit - 1);

          const { data, error } = await query;
          if (error) return mapPostgresError(error, operationId);
          return jsonResponse(data ?? [], 200);
        }
      }

      if (method === "POST") {
        const body = await req.json();
        const { data, error } = await supabase.rpc("sync_create_expense", {
          p_op_id: operationId,
          p_expense: body,
        });
        if (error) return mapPostgresError(error, operationId);
        return jsonResponse(data, 201);
      }

      if (method === "PATCH" && expenseId) {
        const body = await req.json();
        const { data, error } = await supabase.rpc("sync_update_expense", {
          p_op_id: operationId,
          p_expense_id: expenseId,
          p_expense: body,
        });
        if (error) return mapPostgresError(error, operationId);
        return jsonResponse(data, 200);
      }

      if (method === "DELETE") {
        return errorResponse("NOT_FOUND", "Expense deletion is not permitted", operationId, 404);
      }
    }

    // -------------------------------------------------------------------------
    // Item Types API
    // -------------------------------------------------------------------------
    if (path === "/item-types" || path.startsWith("/item-types/")) {
      const parts = path.split("/").filter(Boolean);
      const itemTypeId = parts[1]; // /item-types/:id

      if (method === "GET") {
        if (itemTypeId) {
          const { data, error } = await supabase
            .from("item_types")
            .select("*")
            .eq("id", itemTypeId)
            .maybeSingle();
          if (error) return mapPostgresError(error, operationId);
          if (!data) return errorResponse("NOT_FOUND", "Item type not found", operationId, 404);
          return jsonResponse(data, 200);
        } else {
          let query = supabase.from("item_types").select("*").order("name");
          const isActive = url.searchParams.get("isActive") ?? url.searchParams.get("is_active");
          if (isActive !== null && isActive !== undefined) {
            query = query.eq("is_active", isActive === "true");
          }
          const { data, error } = await query;
          if (error) return mapPostgresError(error, operationId);
          return jsonResponse(data ?? [], 200);
        }
      }

      if (method === "POST") {
        const body = await req.json();
        const { data, error } = await supabase.rpc("sync_create_item_type", {
          p_op_id: operationId,
          p_item_type: body,
        });
        if (error) return mapPostgresError(error, operationId);
        return jsonResponse(data, 201);
      }

      if (method === "PATCH" && itemTypeId) {
        const body = await req.json();
        const { data, error } = await supabase.rpc("sync_update_item_type", {
          p_op_id: operationId,
          p_item_type_id: itemTypeId,
          p_item_type: body,
        });
        if (error) return mapPostgresError(error, operationId);
        return jsonResponse(data, 200);
      }

      if (method === "DELETE") {
        return errorResponse("NOT_FOUND", "Item type deletion is not permitted", operationId, 404);
      }
    }

    // -------------------------------------------------------------------------
    // Item Definitions API
    // -------------------------------------------------------------------------
    if (path === "/item-definitions" || path.startsWith("/item-definitions/")) {
      const parts = path.split("/").filter(Boolean);
      const itemDefId = parts[1]; // /item-definitions/:id

      if (method === "GET") {
        if (itemDefId) {
          const { data, error } = await supabase
            .from("item_definitions")
            .select("*")
            .eq("id", itemDefId)
            .maybeSingle();
          if (error) return mapPostgresError(error, operationId);
          if (!data) return errorResponse("NOT_FOUND", "Item definition not found", operationId, 404);
          return jsonResponse(data, 200);
        } else {
          let query = supabase.from("item_definitions").select("*").order("name");
          const itemTypeId = url.searchParams.get("item_type_id") ?? url.searchParams.get("itemTypeId");
          if (itemTypeId) {
            query = query.eq("item_type_id", itemTypeId);
          }
          const isActive = url.searchParams.get("isActive") ?? url.searchParams.get("is_active");
          if (isActive !== null && isActive !== undefined) {
            query = query.eq("is_active", isActive === "true");
          }
          const { data, error } = await query;
          if (error) return mapPostgresError(error, operationId);
          return jsonResponse(data ?? [], 200);
        }
      }

      if (method === "POST") {
        const body = await req.json();
        const { data, error } = await supabase.rpc("sync_create_item_definition", {
          p_op_id: operationId,
          p_item_def: body,
        });
        if (error) return mapPostgresError(error, operationId);
        return jsonResponse(data, 201);
      }

      if (method === "PATCH" && itemDefId) {
        const body = await req.json();
        const { data, error } = await supabase.rpc("sync_update_item_definition", {
          p_op_id: operationId,
          p_item_def_id: itemDefId,
          p_item_def: body,
        });
        if (error) return mapPostgresError(error, operationId);
        return jsonResponse(data, 200);
      }

      if (method === "DELETE") {
        return errorResponse("NOT_FOUND", "Item definition deletion is not permitted", operationId, 404);
      }
    }

    // -------------------------------------------------------------------------
    // Carpet Sizes API
    // -------------------------------------------------------------------------
    if (path === "/carpet-sizes" || path.startsWith("/carpet-sizes/")) {
      const parts = path.split("/").filter(Boolean);
      const carpetSizeId = parts[1]; // /carpet-sizes/:id

      if (method === "GET") {
        if (carpetSizeId) {
          const { data, error } = await supabase
            .from("carpet_sizes")
            .select("*")
            .eq("id", carpetSizeId)
            .maybeSingle();
          if (error) return mapPostgresError(error, operationId);
          if (!data) return errorResponse("NOT_FOUND", "Carpet size not found", operationId, 404);
          return jsonResponse(data, 200);
        } else {
          let query = supabase.from("carpet_sizes").select("*").order("name");
          const isActive = url.searchParams.get("isActive") ?? url.searchParams.get("is_active");
          if (isActive !== null && isActive !== undefined) {
            query = query.eq("is_active", isActive === "true");
          }
          const { data, error } = await query;
          if (error) return mapPostgresError(error, operationId);
          return jsonResponse(data ?? [], 200);
        }
      }

      if (method === "POST") {
        const body = await req.json();
        const { data, error } = await supabase.rpc("sync_create_carpet_size", {
          p_op_id: operationId,
          p_carpet_size: body,
        });
        if (error) return mapPostgresError(error, operationId);
        return jsonResponse(data, 201);
      }

      if (method === "PATCH" && carpetSizeId) {
        const body = await req.json();
        const { data, error } = await supabase.rpc("sync_update_carpet_size", {
          p_op_id: operationId,
          p_carpet_size_id: carpetSizeId,
          p_carpet_size: body,
        });
        if (error) return mapPostgresError(error, operationId);
        return jsonResponse(data, 200);
      }

      if (method === "DELETE") {
        return errorResponse("NOT_FOUND", "Carpet size deletion is not permitted", operationId, 404);
      }
    }

    // -------------------------------------------------------------------------
    // Storage Locations API
    // -------------------------------------------------------------------------
    if (path === "/storage-locations" || path.startsWith("/storage-locations/")) {
      const parts = path.split("/").filter(Boolean);
      const locationId = parts[1]; // /storage-locations/:id

      if (method === "GET") {
        if (locationId) {
          const { data, error } = await supabase
            .from("storage_locations")
            .select("*")
            .eq("id", locationId)
            .maybeSingle();
          if (error) return mapPostgresError(error, operationId);
          if (!data) return errorResponse("NOT_FOUND", "Storage location not found", operationId, 404);

          const { data: itemTypesData, error: jtError } = await supabase
            .from("storage_location_item_types")
            .select("item_type_id")
            .eq("storage_location_id", locationId);
          if (jtError) return mapPostgresError(jtError, operationId);

          const supportedIds = (itemTypesData ?? []).map((row: { item_type_id: string }) => row.item_type_id);
          return jsonResponse({
            ...data,
            supported_item_type_ids: supportedIds,
            supportedItemTypeIds: supportedIds,
          }, 200);
        } else {
          let query = supabase.from("storage_locations").select("*").order("name");
          const isActive = url.searchParams.get("isActive") ?? url.searchParams.get("is_active");
          if (isActive !== null && isActive !== undefined) {
            query = query.eq("is_active", isActive === "true");
          }
          const { data: locations, error } = await query;
          if (error) return mapPostgresError(error, operationId);

          const { data: jtRows, error: jtError } = await supabase
            .from("storage_location_item_types")
            .select("storage_location_id, item_type_id");
          if (jtError) return mapPostgresError(jtError, operationId);

          const typeMap = new Map<string, string[]>();
          for (const row of jtRows ?? []) {
            const list = typeMap.get(row.storage_location_id) || [];
            list.push(row.item_type_id);
            typeMap.set(row.storage_location_id, list);
          }

          const result = (locations ?? []).map((loc: { id: string }) => ({
            ...loc,
            supported_item_type_ids: typeMap.get(loc.id) || [],
            supportedItemTypeIds: typeMap.get(loc.id) || [],
          }));

          return jsonResponse(result, 200);
        }
      }

      if (method === "POST") {
        const body = await req.json();
        const { data, error } = await supabase.rpc("sync_create_storage_location", {
          p_op_id: operationId,
          p_location: body,
        });
        if (error) return mapPostgresError(error, operationId);
        return jsonResponse(data, 201);
      }

      if (method === "PATCH" && locationId) {
        const body = await req.json();
        const { data, error } = await supabase.rpc("sync_update_storage_location", {
          p_op_id: operationId,
          p_location_id: locationId,
          p_location: body,
        });
        if (error) return mapPostgresError(error, operationId);
        return jsonResponse(data, 200);
      }

      if (method === "DELETE") {
        return errorResponse("NOT_FOUND", "Storage location deletion is not permitted", operationId, 404);
      }
    }

    // -------------------------------------------------------------------------
    // Business Settings API
    // -------------------------------------------------------------------------
    if (path === "/business-settings" || path.startsWith("/business-settings/")) {
      if (method === "GET") {
        const { data, error } = await supabase
          .from("business_settings")
          .select("*")
          .limit(1)
          .maybeSingle();
        if (error) return mapPostgresError(error, operationId);
        if (!data) {
          return jsonResponse({
            id: "00000000-0000-0000-0000-000000000001",
            business_name: "",
            tax_enabled: false,
            tax_rate: 0.0,
            created_at: new Date().toISOString(),
            updated_at: new Date().toISOString(),
          }, 200);
        }
        return jsonResponse(data, 200);
      }

      if (method === "PATCH") {
        const body = await req.json();
        const { data, error } = await supabase.rpc("sync_update_business_settings", {
          p_op_id: operationId,
          p_settings: body,
        });
        if (error) return mapPostgresError(error, operationId);
        return jsonResponse(data, 200);
      }

      if (method === "DELETE") {
        return errorResponse("NOT_FOUND", "Business settings deletion is not permitted", operationId, 404);
      }
    }

    return errorResponse("NOT_FOUND", `Endpoint ${method} ${path} not found`, operationId, 404);
  } catch (err: unknown) {
    const message = err instanceof Error ? err.message : String(err);
    return errorResponse("INTERNAL_ERROR", message, operationId, 500);
  }
});
