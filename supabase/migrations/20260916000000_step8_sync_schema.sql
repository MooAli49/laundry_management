-- =============================================================================
-- Step 9 — Supabase PostgreSQL Schema Migration
-- Laundry Management System — Offline-First Synchronized Tables & Idempotency
-- =============================================================================

-- Enable UUID extension if not enabled
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- -----------------------------------------------------------------------------
-- 1. Customers Table
-- -----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS customers (
    id UUID PRIMARY KEY,
    name TEXT NOT NULL,
    phone TEXT NOT NULL UNIQUE,
    notes TEXT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_supabase_customers_phone ON customers(phone);
CREATE INDEX IF NOT EXISTS idx_supabase_customers_name ON customers(name);

-- -----------------------------------------------------------------------------
-- 2. Services Table
-- -----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS services (
    id UUID PRIMARY KEY,
    name TEXT NOT NULL,
    description TEXT,
    pricing_type TEXT NOT NULL CHECK (pricing_type IN ('per_piece', 'per_square_meter', 'fixed_price')),
    price BIGINT NOT NULL CHECK (price >= 0),
    is_active BOOLEAN NOT NULL DEFAULT true,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_supabase_services_is_active ON services(is_active);

-- -----------------------------------------------------------------------------
-- 3. Service Item Types Junction Table
-- -----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS service_item_types (
    service_id UUID NOT NULL REFERENCES services(id) ON DELETE CASCADE,
    item_type_id TEXT NOT NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    PRIMARY KEY (service_id, item_type_id)
);

CREATE INDEX IF NOT EXISTS idx_supabase_service_item_types_item ON service_item_types(item_type_id);

-- -----------------------------------------------------------------------------
-- 4. Orders Table
-- -----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS orders (
    id UUID PRIMARY KEY,
    order_number TEXT NOT NULL UNIQUE,
    customer_id UUID NOT NULL REFERENCES customers(id) ON DELETE RESTRICT,
    customer_name_snapshot TEXT NOT NULL,
    customer_phone_snapshot TEXT NOT NULL,
    status TEXT NOT NULL CHECK (status IN ('processing', 'ready', 'completed', 'cancelled')),
    expected_pickup_date DATE NOT NULL,
    notes TEXT,
    customer_pickup_requested BOOLEAN NOT NULL DEFAULT false,
    customer_pickup_fee BIGINT NOT NULL DEFAULT 0 CHECK (customer_pickup_fee >= 0),
    customer_delivery_requested BOOLEAN NOT NULL DEFAULT false,
    customer_delivery_fee BIGINT NOT NULL DEFAULT 0 CHECK (customer_delivery_fee >= 0),
    subtotal BIGINT NOT NULL CHECK (subtotal >= 0),
    discount BIGINT NOT NULL DEFAULT 0 CHECK (discount >= 0),
    tax BIGINT NOT NULL DEFAULT 0 CHECK (tax >= 0),
    total BIGINT NOT NULL CHECK (total >= 0),
    completed_at TIMESTAMPTZ,
    cancelled_at TIMESTAMPTZ,
    cancellation_reason TEXT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_supabase_orders_customer_id ON orders(customer_id);
CREATE INDEX IF NOT EXISTS idx_supabase_orders_status ON orders(status);
CREATE INDEX IF NOT EXISTS idx_supabase_orders_expected_pickup ON orders(expected_pickup_date);

-- -----------------------------------------------------------------------------
-- 5. Order Items Table
-- -----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS order_items (
    id UUID PRIMARY KEY,
    order_id UUID NOT NULL REFERENCES orders(id) ON DELETE CASCADE,
    item_type_id TEXT NOT NULL,
    item_definition_id TEXT,
    service_id UUID NOT NULL REFERENCES services(id) ON DELETE RESTRICT,
    item_type_name_snapshot TEXT NOT NULL,
    item_definition_name_snapshot TEXT,
    service_name_snapshot TEXT NOT NULL,
    pricing_type TEXT NOT NULL CHECK (pricing_type IN ('per_piece', 'per_square_meter', 'fixed_price')),
    quantity DOUBLE PRECISION NOT NULL CHECK (quantity > 0),
    unit_price BIGINT NOT NULL CHECK (unit_price >= 0),
    calculated_total BIGINT NOT NULL CHECK (calculated_total >= 0),
    notes TEXT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_supabase_order_items_order_id ON order_items(order_id);
CREATE INDEX IF NOT EXISTS idx_supabase_order_items_service_id ON order_items(service_id);

-- -----------------------------------------------------------------------------
-- 6. Order Item Carpets Table
-- -----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS order_item_carpets (
    id UUID PRIMARY KEY,
    order_item_id UUID NOT NULL REFERENCES order_items(id) ON DELETE CASCADE,
    carpet_size_id TEXT,
    length DOUBLE PRECISION NOT NULL CHECK (length > 0),
    width DOUBLE PRECISION NOT NULL CHECK (width > 0),
    area DOUBLE PRECISION NOT NULL CHECK (area > 0),
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_supabase_order_item_carpets_item ON order_item_carpets(order_item_id);

-- -----------------------------------------------------------------------------
-- 7. Storage Records Table
-- -----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS storage_records (
    id UUID PRIMARY KEY,
    order_item_id UUID NOT NULL REFERENCES order_items(id) ON DELETE CASCADE,
    storage_location_id TEXT NOT NULL,
    is_active BOOLEAN NOT NULL DEFAULT true,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_supabase_storage_records_item ON storage_records(order_item_id);
-- Strict business invariant: An OrderItem cannot have more than one active storage record
CREATE UNIQUE INDEX IF NOT EXISTS idx_supabase_storage_records_unique_active ON storage_records(order_item_id) WHERE is_active = true;

-- -----------------------------------------------------------------------------
-- 8. Sync Idempotency Log Table
-- -----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS sync_idempotency_log (
    operation_id TEXT PRIMARY KEY,
    entity_type TEXT NOT NULL,
    entity_id TEXT NOT NULL,
    operation_type TEXT NOT NULL,
    applied_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    response_payload JSONB
);

CREATE INDEX IF NOT EXISTS idx_supabase_idempotency_entity ON sync_idempotency_log(entity_type, entity_id);

-- -----------------------------------------------------------------------------
-- 9. Row Level Security
-- Protect tables so only trusted server-side Edge Functions (service_role) mutate data.
-- -----------------------------------------------------------------------------
ALTER TABLE customers ENABLE ROW LEVEL SECURITY;
ALTER TABLE services ENABLE ROW LEVEL SECURITY;
ALTER TABLE service_item_types ENABLE ROW LEVEL SECURITY;
ALTER TABLE orders ENABLE ROW LEVEL SECURITY;
ALTER TABLE order_items ENABLE ROW LEVEL SECURITY;
ALTER TABLE order_item_carpets ENABLE ROW LEVEL SECURITY;
ALTER TABLE storage_records ENABLE ROW LEVEL SECURITY;
ALTER TABLE sync_idempotency_log ENABLE ROW LEVEL SECURITY;
