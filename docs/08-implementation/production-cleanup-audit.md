# Production Supabase Cleanup Audit Snapshot

- **Timestamp**: 2026-10-02T23:44:33.114033Z
- **Target Project Ref**: `rvrskluqfbrkvvlxtxfp`
- **Project URL**: `https://rvrskluqfbrkvvlxtxfp.supabase.co`
- **Environment**: Production
- **Audit Status**: Pre-cleanup forensic snapshot captured

---

## 1. Pre-Cleanup Row Counts

| Entity / Table | Active Live Rows | Sync Changes Events | Status |
| :--- | :--- | :--- | :--- |
| `customers` | 4 | 0 | Test/Demo transactional data |
| `orders` | 2 | 0 | Test/Demo transactional data |
| `order_items` | 13 | 0 | Test/Demo transactional data |
| `order_item_carpets` | 0 | 0 | None found |
| `payments` | 0 | 0 | None found |
| `refunds` | 0 | 0 | None found |
| `storage_records` | 0 | 0 | None found |
| `expenses` | 0 | 0 | None found |
| `sync_idempotency_log` | 0 | 0 | Unsynced system table |
| `sync_changes` | 40 (latest seq: 40) | 40 | Authoritative sync log |
| `item_types` | 13 | 0 | Non-canonical (13 rows vs 11 canonical) |
| `services` | 3 | 0 | Non-canonical (3 custom rows) |
| `storage_locations` | 0 | 0 | Empty (expected 3 canonical) |

---

## 2. Textual Snapshot of Transactional Data (To Be Deleted)

### Customers (4)
```json
[
  {
    "id": "428a67ff-639a-469a-9a12-406da4f07d32",
    "name": "كريم محمد",
    "phone": "01221477572",
    "notes": null,
    "created_at": "2026-09-30T17:49:34.735131+00:00",
    "updated_at": "2026-09-30T17:49:34.735131+00:00",
    "server_version": 1,
    "address": null
  },
  {
    "id": "9f476a93-943f-4575-a983-e630572bcf04",
    "name": "محمد عبد الرازق",
    "phone": "01001748271",
    "notes": null,
    "created_at": "2026-09-30T13:18:59.660336+00:00",
    "updated_at": "2026-09-30T13:18:59.660336+00:00",
    "server_version": 1,
    "address": null
  },
  {
    "id": "de2b6104-00dd-4571-b011-4198b59fc67e",
    "name": "محمد عبد الرازق",
    "phone": "01001748272",
    "notes": null,
    "created_at": "2026-09-30T13:15:53.24644+00:00",
    "updated_at": "2026-09-30T13:15:53.24644+00:00",
    "server_version": 1,
    "address": null
  },
  {
    "id": "ab3d8d06-fd9e-45b2-9ca1-349aa211f112",
    "name": "احمد حسنى",
    "phone": "01120776302",
    "notes": null,
    "created_at": "2026-09-30T02:52:02.429416+00:00",
    "updated_at": "2026-09-30T02:52:02.429416+00:00",
    "server_version": 1,
    "address": null
  }
]
```

### Orders and Order Items (2)
```json
[
  {
    "id": "9759efbf-9242-4701-8258-38886bec7950",
    "order_number": "26-002",
    "customer_id": "9f476a93-943f-4575-a983-e630572bcf04",
    "customer_name_snapshot": "محمد عبد الرازق",
    "customer_phone_snapshot": "01001748271",
    "status": "processing",
    "expected_pickup_date": "2026-10-07",
    "notes": null,
    "customer_pickup_requested": false,
    "customer_pickup_fee": 0,
    "customer_delivery_requested": false,
    "customer_delivery_fee": 0,
    "subtotal": 72000,
    "discount": 0,
    "tax": 0,
    "total": 72000,
    "completed_at": null,
    "cancelled_at": null,
    "cancellation_reason": null,
    "created_at": "2026-09-30T13:19:05.005232+00:00",
    "updated_at": "2026-09-30T13:19:05.005232+00:00",
    "paid_amount": 0,
    "server_version": 1,
    "order_items": [
      {
        "id": "4562fd1d-0995-4509-a1a6-ddfe441101f5",
        "notes": null,
        "order_id": "9759efbf-9242-4701-8258-38886bec7950",
        "quantity": 1,
        "created_at": "2026-09-30T13:19:05.005232+00:00",
        "service_id": "d41bb93f-3709-4330-847d-3e9a33ba39b7",
        "unit_price": 6000,
        "updated_at": "2026-09-30T13:19:05.005232+00:00",
        "item_type_id": "eec035c5-0872-4304-8d44-9e5eb11445ea",
        "pricing_type": "per_piece",
        "calculated_total": 6000,
        "item_definition_id": null,
        "service_name_snapshot": "تنظيف بطانية زوجى",
        "item_type_name_snapshot": "بطانية زوجى",
        "item_definition_name_snapshot": null
      },
      {
        "id": "e5b17c88-7811-4d37-8a41-027957abaa94",
        "notes": null,
        "order_id": "9759efbf-9242-4701-8258-38886bec7950",
        "quantity": 1,
        "created_at": "2026-09-30T13:19:05.005232+00:00",
        "service_id": "d41bb93f-3709-4330-847d-3e9a33ba39b7",
        "unit_price": 6000,
        "updated_at": "2026-09-30T13:19:05.005232+00:00",
        "item_type_id": "eec035c5-0872-4304-8d44-9e5eb11445ea",
        "pricing_type": "per_piece",
        "calculated_total": 6000,
        "item_definition_id": null,
        "service_name_snapshot": "تنظيف بطانية زوجى",
        "item_type_name_snapshot": "بطانية زوجى",
        "item_definition_name_snapshot": null
      },
      {
        "id": "8360cf79-bf92-4437-a7ef-9fec247a4b60",
        "notes": null,
        "order_id": "9759efbf-9242-4701-8258-38886bec7950",
        "quantity": 1,
        "created_at": "2026-09-30T13:19:05.005232+00:00",
        "service_id": "d41bb93f-3709-4330-847d-3e9a33ba39b7",
        "unit_price": 6000,
        "updated_at": "2026-09-30T13:19:05.005232+00:00",
        "item_type_id": "eec035c5-0872-4304-8d44-9e5eb11445ea",
        "pricing_type": "per_piece",
        "calculated_total": 6000,
        "item_definition_id": null,
        "service_name_snapshot": "تنظيف بطانية زوجى",
        "item_type_name_snapshot": "بطانية زوجى",
        "item_definition_name_snapshot": null
      },
      {
        "id": "0f8f8091-d184-4023-aeb2-cfc39eb3b81c",
        "notes": null,
        "order_id": "9759efbf-9242-4701-8258-38886bec7950",
        "quantity": 1,
        "created_at": "2026-09-30T13:19:05.005232+00:00",
        "service_id": "d41bb93f-3709-4330-847d-3e9a33ba39b7",
        "unit_price": 6000,
        "updated_at": "2026-09-30T13:19:05.005232+00:00",
        "item_type_id": "eec035c5-0872-4304-8d44-9e5eb11445ea",
        "pricing_type": "per_piece",
        "calculated_total": 6000,
        "item_definition_id": null,
        "service_name_snapshot": "تنظيف بطانية زوجى",
        "item_type_name_snapshot": "بطانية زوجى",
        "item_definition_name_snapshot": null
      },
      {
        "id": "5815012a-e21b-4631-9cc0-961c0ddcd62c",
        "notes": null,
        "order_id": "9759efbf-9242-4701-8258-38886bec7950",
        "quantity": 1,
        "created_at": "2026-09-30T13:19:05.005232+00:00",
        "service_id": "d41bb93f-3709-4330-847d-3e9a33ba39b7",
        "unit_price": 6000,
        "updated_at": "2026-09-30T13:19:05.005232+00:00",
        "item_type_id": "eec035c5-0872-4304-8d44-9e5eb11445ea",
        "pricing_type": "per_piece",
        "calculated_total": 6000,
        "item_definition_id": null,
        "service_name_snapshot": "تنظيف بطانية زوجى",
        "item_type_name_snapshot": "بطانية زوجى",
        "item_definition_name_snapshot": null
      },
      {
        "id": "02abb2c7-4b33-4234-a60b-a22b7ecadff2",
        "notes": null,
        "order_id": "9759efbf-9242-4701-8258-38886bec7950",
        "quantity": 1,
        "created_at": "2026-09-30T13:19:05.005232+00:00",
        "service_id": "d41bb93f-3709-4330-847d-3e9a33ba39b7",
        "unit_price": 6000,
        "updated_at": "2026-09-30T13:19:05.005232+00:00",
        "item_type_id": "eec035c5-0872-4304-8d44-9e5eb11445ea",
        "pricing_type": "per_piece",
        "calculated_total": 6000,
        "item_definition_id": null,
        "service_name_snapshot": "تنظيف بطانية زوجى",
        "item_type_name_snapshot": "بطانية زوجى",
        "item_definition_name_snapshot": null
      },
      {
        "id": "fd3654e4-9d67-4ab0-975f-d36b9b64348f",
        "notes": null,
        "order_id": "9759efbf-9242-4701-8258-38886bec7950",
        "quantity": 1,
        "created_at": "2026-09-30T13:19:05.005232+00:00",
        "service_id": "d41bb93f-3709-4330-847d-3e9a33ba39b7",
        "unit_price": 6000,
        "updated_at": "2026-09-30T13:19:05.005232+00:00",
        "item_type_id": "eec035c5-0872-4304-8d44-9e5eb11445ea",
        "pricing_type": "per_piece",
        "calculated_total": 6000,
        "item_definition_id": null,
        "service_name_snapshot": "تنظيف بطانية زوجى",
        "item_type_name_snapshot": "بطانية زوجى",
        "item_definition_name_snapshot": null
      },
      {
        "id": "e0985efa-ceff-42cf-9ae6-37bd1b842a07",
        "notes": null,
        "order_id": "9759efbf-9242-4701-8258-38886bec7950",
        "quantity": 1,
        "created_at": "2026-09-30T13:19:05.005232+00:00",
        "service_id": "d41bb93f-3709-4330-847d-3e9a33ba39b7",
        "unit_price": 6000,
        "updated_at": "2026-09-30T13:19:05.005232+00:00",
        "item_type_id": "eec035c5-0872-4304-8d44-9e5eb11445ea",
        "pricing_type": "per_piece",
        "calculated_total": 6000,
        "item_definition_id": null,
        "service_name_snapshot": "تنظيف بطانية زوجى",
        "item_type_name_snapshot": "بطانية زوجى",
        "item_definition_name_snapshot": null
      },
      {
        "id": "7dd9577c-88ab-4b89-b79b-686702a9f74b",
        "notes": null,
        "order_id": "9759efbf-9242-4701-8258-38886bec7950",
        "quantity": 1,
        "created_at": "2026-09-30T13:19:05.005232+00:00",
        "service_id": "d41bb93f-3709-4330-847d-3e9a33ba39b7",
        "unit_price": 6000,
        "updated_at": "2026-09-30T13:19:05.005232+00:00",
        "item_type_id": "eec035c5-0872-4304-8d44-9e5eb11445ea",
        "pricing_type": "per_piece",
        "calculated_total": 6000,
        "item_definition_id": null,
        "service_name_snapshot": "تنظيف بطانية زوجى",
        "item_type_name_snapshot": "بطانية زوجى",
        "item_definition_name_snapshot": null
      },
      {
        "id": "a08d10d3-70b4-4c04-857b-c92f556380af",
        "notes": null,
        "order_id": "9759efbf-9242-4701-8258-38886bec7950",
        "quantity": 1,
        "created_at": "2026-09-30T13:19:05.005232+00:00",
        "service_id": "d41bb93f-3709-4330-847d-3e9a33ba39b7",
        "unit_price": 6000,
        "updated_at": "2026-09-30T13:19:05.005232+00:00",
        "item_type_id": "eec035c5-0872-4304-8d44-9e5eb11445ea",
        "pricing_type": "per_piece",
        "calculated_total": 6000,
        "item_definition_id": null,
        "service_name_snapshot": "تنظيف بطانية زوجى",
        "item_type_name_snapshot": "بطانية زوجى",
        "item_definition_name_snapshot": null
      },
      {
        "id": "93597b6b-8db7-42a8-95d4-a7d15b32eba7",
        "notes": null,
        "order_id": "9759efbf-9242-4701-8258-38886bec7950",
        "quantity": 1,
        "created_at": "2026-09-30T13:19:05.005232+00:00",
        "service_id": "d41bb93f-3709-4330-847d-3e9a33ba39b7",
        "unit_price": 6000,
        "updated_at": "2026-09-30T13:19:05.005232+00:00",
        "item_type_id": "eec035c5-0872-4304-8d44-9e5eb11445ea",
        "pricing_type": "per_piece",
        "calculated_total": 6000,
        "item_definition_id": null,
        "service_name_snapshot": "تنظيف بطانية زوجى",
        "item_type_name_snapshot": "بطانية زوجى",
        "item_definition_name_snapshot": null
      },
      {
        "id": "324e36b8-9083-498b-b7ab-a0e803aa03f3",
        "notes": null,
        "order_id": "9759efbf-9242-4701-8258-38886bec7950",
        "quantity": 1,
        "created_at": "2026-09-30T13:19:05.005232+00:00",
        "service_id": "d41bb93f-3709-4330-847d-3e9a33ba39b7",
        "unit_price": 6000,
        "updated_at": "2026-09-30T13:19:05.005232+00:00",
        "item_type_id": "eec035c5-0872-4304-8d44-9e5eb11445ea",
        "pricing_type": "per_piece",
        "calculated_total": 6000,
        "item_definition_id": null,
        "service_name_snapshot": "تنظيف بطانية زوجى",
        "item_type_name_snapshot": "بطانية زوجى",
        "item_definition_name_snapshot": null
      }
    ]
  },
  {
    "id": "9caa74de-67a5-459d-af09-6aa0182ad9f9",
    "order_number": "26-001",
    "customer_id": "de2b6104-00dd-4571-b011-4198b59fc67e",
    "customer_name_snapshot": "محمد عبد الرازق",
    "customer_phone_snapshot": "01001748272",
    "status": "processing",
    "expected_pickup_date": "2026-10-07",
    "notes": null,
    "customer_pickup_requested": false,
    "customer_pickup_fee": 0,
    "customer_delivery_requested": false,
    "customer_delivery_fee": 0,
    "subtotal": 6000,
    "discount": 0,
    "tax": 0,
    "total": 6000,
    "completed_at": null,
    "cancelled_at": null,
    "cancellation_reason": null,
    "created_at": "2026-09-30T13:16:01.258441+00:00",
    "updated_at": "2026-09-30T13:16:01.258441+00:00",
    "paid_amount": 0,
    "server_version": 1,
    "order_items": [
      {
        "id": "72aae8f9-5c29-46fc-87a8-961ca96644b2",
        "notes": null,
        "order_id": "9caa74de-67a5-459d-af09-6aa0182ad9f9",
        "quantity": 1,
        "created_at": "2026-09-30T13:16:01.258441+00:00",
        "service_id": "d41bb93f-3709-4330-847d-3e9a33ba39b7",
        "unit_price": 6000,
        "updated_at": "2026-09-30T13:16:01.258441+00:00",
        "item_type_id": "eec035c5-0872-4304-8d44-9e5eb11445ea",
        "pricing_type": "per_piece",
        "calculated_total": 6000,
        "item_definition_id": null,
        "service_name_snapshot": "تنظيف بطانية زوجى",
        "item_type_name_snapshot": "بطانية زوجى",
        "item_definition_name_snapshot": null
      }
    ]
  }
]
```

### Expenses (0)
```json
[]
```

---

## 3. Snapshot of Existing Master Data

### Item Types (13)
```json
[
  {
    "id": "b7772cc9-af69-4cf6-9079-e1bd6b030e31",
    "name": "بدلة",
    "is_active": true,
    "created_at": "2026-09-29T23:55:30.615479+00:00",
    "updated_at": "2026-09-29T23:55:30.615479+00:00",
    "server_version": 1
  },
  {
    "id": "eec035c5-0872-4304-8d44-9e5eb11445ea",
    "name": "بطانية زوجى",
    "is_active": true,
    "created_at": "2026-09-29T23:59:14.705914+00:00",
    "updated_at": "2026-09-29T23:59:14.705914+00:00",
    "server_version": 1
  },
  {
    "id": "287b0e94-10b6-4c9d-9951-e455e6064c85",
    "name": "بنطلون",
    "is_active": true,
    "created_at": "2026-09-30T00:01:15.873953+00:00",
    "updated_at": "2026-09-30T00:01:15.873953+00:00",
    "server_version": 1
  },
  {
    "id": "9fe9650a-a4bd-42de-b2c4-d68ebbcdb962",
    "name": "جاكت",
    "is_active": true,
    "created_at": "2026-09-30T00:01:25.34069+00:00",
    "updated_at": "2026-09-30T00:01:25.34069+00:00",
    "server_version": 1
  },
  {
    "id": "1b08e1ad-4be6-4ba6-b954-fbeafb3613fe",
    "name": "جلابية",
    "is_active": true,
    "created_at": "2026-09-30T00:02:08.101911+00:00",
    "updated_at": "2026-09-30T00:02:08.101911+00:00",
    "server_version": 1
  },
  {
    "id": "9db7e580-2ae4-4c5d-8502-a7caad3d750a",
    "name": "حافظة",
    "is_active": true,
    "created_at": "2026-09-29T23:56:44.322288+00:00",
    "updated_at": "2026-09-29T23:56:44.322288+00:00",
    "server_version": 1
  },
  {
    "id": "367e2d99-803f-4ca3-a359-31e455a82813",
    "name": "دفاية",
    "is_active": true,
    "created_at": "2026-09-29T23:59:27.409733+00:00",
    "updated_at": "2026-09-29T23:59:27.409733+00:00",
    "server_version": 1
  },
  {
    "id": "6469e518-078b-4ee1-abb8-f134aea0abab",
    "name": "دواسة",
    "is_active": true,
    "created_at": "2026-09-29T23:57:28.037506+00:00",
    "updated_at": "2026-09-29T23:57:28.037506+00:00",
    "server_version": 1
  },
  {
    "id": "75800189-c36e-414d-b792-da5092357650",
    "name": "عباية",
    "is_active": true,
    "created_at": "2026-09-30T00:01:33.687434+00:00",
    "updated_at": "2026-09-30T00:01:33.687434+00:00",
    "server_version": 1
  },
  {
    "id": "cc507c95-7515-4b95-8974-4519ccff807d",
    "name": "قميص",
    "is_active": true,
    "created_at": "2026-09-30T00:01:20.556088+00:00",
    "updated_at": "2026-09-30T00:01:20.556088+00:00",
    "server_version": 1
  },
  {
    "id": "6a9e8367-327b-4845-ab4a-aa6d14009b28",
    "name": "كبرته",
    "is_active": true,
    "created_at": "2026-09-30T00:00:16.13657+00:00",
    "updated_at": "2026-09-30T00:00:16.13657+00:00",
    "server_version": 1
  },
  {
    "id": "016c4305-b1db-4070-9e1b-775668601f5e",
    "name": "مشاية",
    "is_active": true,
    "created_at": "2026-09-29T23:57:06.003728+00:00",
    "updated_at": "2026-09-29T23:57:06.003728+00:00",
    "server_version": 1
  },
  {
    "id": "fffa76b2-6918-47e5-ae8f-06faedbbd080",
    "name": "موكيتة",
    "is_active": true,
    "created_at": "2026-09-29T23:57:16.07291+00:00",
    "updated_at": "2026-09-30T00:32:04.55886+00:00",
    "server_version": 2
  }
]
```

### Services (3)
```json
[
  {
    "id": "d41bb93f-3709-4330-847d-3e9a33ba39b7",
    "name": "تنظيف بطانية زوجى",
    "description": null,
    "pricing_type": "per_piece",
    "price": 6000,
    "is_active": true,
    "created_at": "2026-09-30T03:03:53.182565+00:00",
    "updated_at": "2026-10-01T17:29:38.888753+00:00",
    "server_version": 3,
    "service_item_types": [
      {
        "created_at": "2026-09-30T00:34:31.322051+00:00",
        "service_id": "d41bb93f-3709-4330-847d-3e9a33ba39b7",
        "item_type_id": "eec035c5-0872-4304-8d44-9e5eb11445ea"
      }
    ]
  },
  {
    "id": "a99915aa-7a05-45a6-9db0-4db43576bf66",
    "name": "صبغة اسود",
    "description": null,
    "pricing_type": "per_piece",
    "price": 10000,
    "is_active": true,
    "created_at": "2026-09-30T03:06:23.932812+00:00",
    "updated_at": "2026-09-30T03:12:08.947281+00:00",
    "server_version": 2,
    "service_item_types": [
      {
        "created_at": "2026-09-30T00:36:04.317454+00:00",
        "service_id": "a99915aa-7a05-45a6-9db0-4db43576bf66",
        "item_type_id": "1b08e1ad-4be6-4ba6-b954-fbeafb3613fe"
      },
      {
        "created_at": "2026-09-30T00:36:04.317454+00:00",
        "service_id": "a99915aa-7a05-45a6-9db0-4db43576bf66",
        "item_type_id": "287b0e94-10b6-4c9d-9951-e455e6064c85"
      },
      {
        "created_at": "2026-09-30T00:36:04.317454+00:00",
        "service_id": "a99915aa-7a05-45a6-9db0-4db43576bf66",
        "item_type_id": "75800189-c36e-414d-b792-da5092357650"
      },
      {
        "created_at": "2026-09-30T00:36:04.317454+00:00",
        "service_id": "a99915aa-7a05-45a6-9db0-4db43576bf66",
        "item_type_id": "9fe9650a-a4bd-42de-b2c4-d68ebbcdb962"
      },
      {
        "created_at": "2026-09-30T00:36:04.317454+00:00",
        "service_id": "a99915aa-7a05-45a6-9db0-4db43576bf66",
        "item_type_id": "cc507c95-7515-4b95-8974-4519ccff807d"
      },
      {
        "created_at": "2026-09-30T00:36:04.317454+00:00",
        "service_id": "a99915aa-7a05-45a6-9db0-4db43576bf66",
        "item_type_id": "b7772cc9-af69-4cf6-9079-e1bd6b030e31"
      }
    ]
  },
  {
    "id": "41cd5710-bb0c-4e4c-88d6-70476a4f7f2c",
    "name": "غسيل ومكوة جاكت",
    "description": null,
    "pricing_type": "per_piece",
    "price": 8000,
    "is_active": true,
    "created_at": "2026-09-30T03:17:09.787113+00:00",
    "updated_at": "2026-09-30T03:17:09.787113+00:00",
    "server_version": 1,
    "service_item_types": [
      {
        "created_at": "2026-09-30T00:37:01.276967+00:00",
        "service_id": "41cd5710-bb0c-4e4c-88d6-70476a4f7f2c",
        "item_type_id": "9fe9650a-a4bd-42de-b2c4-d68ebbcdb962"
      }
    ]
  }
]
```

### Storage Locations (0)
```json
[]
```

---

## 4. Complete Changelog Snapshot (`sync_changes` 1..40)
```json
[
  {
    "payload": {
      "id": "00000000-0000-0000-0000-000000000001",
      "phone": "01092955171 - 01002542402",
      "address": "طراد النيل الواسطى بنى سويف",
      "tax_rate": 0,
      "updated_at": "2026-09-29T21:32:34.683185+00:00",
      "tax_enabled": false,
      "business_name": "المغسلة الحديثة",
      "logo_reference": null,
      "server_version": 1,
      "invoice_footer_text": "المغسلة غير مسؤولة عن السجاد او البطاطين بعد مرور شهر من تاريخ الاستلام"
    },
    "sequence": 1,
    "entity_id": "00000000-0000-0000-0000-000000000001",
    "created_at": "2026-09-29T21:32:36.668683+00:00",
    "entity_type": "business_settings",
    "operation_id": "9d2b0f3b-ee23-4f8a-95a7-a39e2fe652fc",
    "operation_type": "update",
    "server_version": 1
  },
  {
    "payload": {
      "id": "ab3d8d06-fd9e-45b2-9ca1-349aa211f112",
      "name": "احمد حسنى",
      "notes": null,
      "phone": "01120776302",
      "address": null,
      "created_at": "2026-09-30T02:52:02.429416+00:00",
      "updated_at": "2026-09-30T02:52:02.429416+00:00",
      "server_version": 1
    },
    "sequence": 2,
    "entity_id": "ab3d8d06-fd9e-45b2-9ca1-349aa211f112",
    "created_at": "2026-09-30T00:23:44.280319+00:00",
    "entity_type": "customer",
    "operation_id": "a0a6461c-a137-47d4-b1ff-ef60f258ebea",
    "operation_type": "create",
    "server_version": 1
  },
  {
    "payload": {
      "id": "b7772cc9-af69-4cf6-9079-e1bd6b030e31",
      "name": "بدلة",
      "is_active": true,
      "created_at": "2026-09-29T23:55:30.615479+00:00",
      "updated_at": "2026-09-29T23:55:30.615479+00:00",
      "server_version": 1
    },
    "sequence": 3,
    "entity_id": "b7772cc9-af69-4cf6-9079-e1bd6b030e31",
    "created_at": "2026-09-30T00:28:52.100806+00:00",
    "entity_type": "item_type",
    "operation_id": "9542b63d-db09-43ad-b01e-4a9abfe77c89",
    "operation_type": "create",
    "server_version": 1
  },
  {
    "payload": {
      "id": "db23c06a-1620-4caf-a17e-b329dfd28365",
      "name": "٣ قطع",
      "is_active": true,
      "created_at": "2026-09-29T23:55:42.354459+00:00",
      "updated_at": "2026-09-29T23:55:42.354459+00:00",
      "item_type_id": "b7772cc9-af69-4cf6-9079-e1bd6b030e31",
      "server_version": 1
    },
    "sequence": 4,
    "entity_id": "db23c06a-1620-4caf-a17e-b329dfd28365",
    "created_at": "2026-09-30T00:28:53.303785+00:00",
    "entity_type": "item_definition",
    "operation_id": "35ef1604-72ef-44c3-bd4e-1366998e95d7",
    "operation_type": "create",
    "server_version": 1
  },
  {
    "payload": {
      "id": "9db7e580-2ae4-4c5d-8502-a7caad3d750a",
      "name": "حافظة",
      "is_active": true,
      "created_at": "2026-09-29T23:56:44.322288+00:00",
      "updated_at": "2026-09-29T23:56:44.322288+00:00",
      "server_version": 1
    },
    "sequence": 5,
    "entity_id": "9db7e580-2ae4-4c5d-8502-a7caad3d750a",
    "created_at": "2026-09-30T00:31:52.856427+00:00",
    "entity_type": "item_type",
    "operation_id": "79ef4cae-9bc6-47a4-a29d-d7863cb6a803",
    "operation_type": "create",
    "server_version": 1
  },
  {
    "payload": {
      "id": "016c4305-b1db-4070-9e1b-775668601f5e",
      "name": "مشاية",
      "is_active": true,
      "created_at": "2026-09-29T23:57:06.003728+00:00",
      "updated_at": "2026-09-29T23:57:06.003728+00:00",
      "server_version": 1
    },
    "sequence": 6,
    "entity_id": "016c4305-b1db-4070-9e1b-775668601f5e",
    "created_at": "2026-09-30T00:31:53.451104+00:00",
    "entity_type": "item_type",
    "operation_id": "db07935e-a8ea-43d4-8e6f-1106b8f90da3",
    "operation_type": "create",
    "server_version": 1
  },
  {
    "payload": {
      "id": "fffa76b2-6918-47e5-ae8f-06faedbbd080",
      "name": "موكيت",
      "is_active": true,
      "created_at": "2026-09-29T23:57:16.07291+00:00",
      "updated_at": "2026-09-29T23:57:16.07291+00:00",
      "server_version": 1
    },
    "sequence": 7,
    "entity_id": "fffa76b2-6918-47e5-ae8f-06faedbbd080",
    "created_at": "2026-09-30T00:31:54.036213+00:00",
    "entity_type": "item_type",
    "operation_id": "16472cad-fa96-4fc4-8b3c-483d29da0e74",
    "operation_type": "create",
    "server_version": 1
  },
  {
    "payload": {
      "id": "6469e518-078b-4ee1-abb8-f134aea0abab",
      "name": "دواسة",
      "is_active": true,
      "created_at": "2026-09-29T23:57:28.037506+00:00",
      "updated_at": "2026-09-29T23:57:28.037506+00:00",
      "server_version": 1
    },
    "sequence": 8,
    "entity_id": "6469e518-078b-4ee1-abb8-f134aea0abab",
    "created_at": "2026-09-30T00:31:55.324645+00:00",
    "entity_type": "item_type",
    "operation_id": "bd2740d8-e00f-46ee-a04b-05a5b3cbbf46",
    "operation_type": "create",
    "server_version": 1
  },
  {
    "payload": {
      "id": "14ab6e62-fdbc-44df-9bb1-39d0656baa46",
      "name": "مشاية",
      "is_active": true,
      "created_at": "2026-09-29T23:58:07.987907+00:00",
      "updated_at": "2026-09-29T23:58:07.987907+00:00",
      "item_type_id": "9db7e580-2ae4-4c5d-8502-a7caad3d750a",
      "server_version": 1
    },
    "sequence": 9,
    "entity_id": "14ab6e62-fdbc-44df-9bb1-39d0656baa46",
    "created_at": "2026-09-30T00:31:56.437905+00:00",
    "entity_type": "item_definition",
    "operation_id": "ed7f1ce7-7ab7-4ab6-8967-fa7a3313d61d",
    "operation_type": "create",
    "server_version": 1
  },
  {
    "payload": {
      "id": "eec035c5-0872-4304-8d44-9e5eb11445ea",
      "name": "بطانية زوجى",
      "is_active": true,
      "created_at": "2026-09-29T23:59:14.705914+00:00",
      "updated_at": "2026-09-29T23:59:14.705914+00:00",
      "server_version": 1
    },
    "sequence": 10,
    "entity_id": "eec035c5-0872-4304-8d44-9e5eb11445ea",
    "created_at": "2026-09-30T00:32:06.474359+00:00",
    "entity_type": "item_type",
    "operation_id": "97001f25-8935-4742-8d81-159c1b7f82a0",
    "operation_type": "create",
    "server_version": 1
  },
  {
    "payload": {
      "id": "367e2d99-803f-4ca3-a359-31e455a82813",
      "name": "دفاية",
      "is_active": true,
      "created_at": "2026-09-29T23:59:27.409733+00:00",
      "updated_at": "2026-09-29T23:59:27.409733+00:00",
      "server_version": 1
    },
    "sequence": 11,
    "entity_id": "367e2d99-803f-4ca3-a359-31e455a82813",
    "created_at": "2026-09-30T00:32:06.891384+00:00",
    "entity_type": "item_type",
    "operation_id": "3230338b-7bbd-4cbd-9b1d-f04ff63fae30",
    "operation_type": "create",
    "server_version": 1
  },
  {
    "payload": {
      "id": "6a9e8367-327b-4845-ab4a-aa6d14009b28",
      "name": "كبرته",
      "is_active": true,
      "created_at": "2026-09-30T00:00:16.13657+00:00",
      "updated_at": "2026-09-30T00:00:16.13657+00:00",
      "server_version": 1
    },
    "sequence": 12,
    "entity_id": "6a9e8367-327b-4845-ab4a-aa6d14009b28",
    "created_at": "2026-09-30T00:32:07.410777+00:00",
    "entity_type": "item_type",
    "operation_id": "8a572da0-8e17-427d-a522-9ad900596996",
    "operation_type": "create",
    "server_version": 1
  },
  {
    "payload": {
      "id": "287b0e94-10b6-4c9d-9951-e455e6064c85",
      "name": "بنطلون",
      "is_active": true,
      "created_at": "2026-09-30T00:01:15.873953+00:00",
      "updated_at": "2026-09-30T00:01:15.873953+00:00",
      "server_version": 1
    },
    "sequence": 13,
    "entity_id": "287b0e94-10b6-4c9d-9951-e455e6064c85",
    "created_at": "2026-09-30T00:33:08.317035+00:00",
    "entity_type": "item_type",
    "operation_id": "3c83a620-6063-4e47-ad11-cde2493e7761",
    "operation_type": "create",
    "server_version": 1
  },
  {
    "payload": {
      "id": "cc507c95-7515-4b95-8974-4519ccff807d",
      "name": "قميص",
      "is_active": true,
      "created_at": "2026-09-30T00:01:20.556088+00:00",
      "updated_at": "2026-09-30T00:01:20.556088+00:00",
      "server_version": 1
    },
    "sequence": 14,
    "entity_id": "cc507c95-7515-4b95-8974-4519ccff807d",
    "created_at": "2026-09-30T00:33:08.838551+00:00",
    "entity_type": "item_type",
    "operation_id": "680b60f7-f44f-4ab9-b32c-b84707a02a1a",
    "operation_type": "create",
    "server_version": 1
  },
  {
    "payload": {
      "id": "9fe9650a-a4bd-42de-b2c4-d68ebbcdb962",
      "name": "جاكت",
      "is_active": true,
      "created_at": "2026-09-30T00:01:25.34069+00:00",
      "updated_at": "2026-09-30T00:01:25.34069+00:00",
      "server_version": 1
    },
    "sequence": 15,
    "entity_id": "9fe9650a-a4bd-42de-b2c4-d68ebbcdb962",
    "created_at": "2026-09-30T00:33:09.29477+00:00",
    "entity_type": "item_type",
    "operation_id": "1fdbf67c-1e76-45d8-8e80-c40e4f436e84",
    "operation_type": "create",
    "server_version": 1
  },
  {
    "payload": {
      "id": "75800189-c36e-414d-b792-da5092357650",
      "name": "عباية",
      "is_active": true,
      "created_at": "2026-09-30T00:01:33.687434+00:00",
      "updated_at": "2026-09-30T00:01:33.687434+00:00",
      "server_version": 1
    },
    "sequence": 16,
    "entity_id": "75800189-c36e-414d-b792-da5092357650",
    "created_at": "2026-09-30T00:33:09.775641+00:00",
    "entity_type": "item_type",
    "operation_id": "f5a18dce-e0f8-4d50-8d84-a9801f06ba47",
    "operation_type": "create",
    "server_version": 1
  },
  {
    "payload": {
      "id": "ad1340cf-df97-47f8-b90c-efb68ca9f46f",
      "name": "رجالى",
      "is_active": true,
      "created_at": "2026-09-30T00:01:42.029684+00:00",
      "updated_at": "2026-09-30T00:01:42.029684+00:00",
      "item_type_id": "75800189-c36e-414d-b792-da5092357650",
      "server_version": 1
    },
    "sequence": 17,
    "entity_id": "ad1340cf-df97-47f8-b90c-efb68ca9f46f",
    "created_at": "2026-09-30T00:33:10.112429+00:00",
    "entity_type": "item_definition",
    "operation_id": "6f27bad4-6708-4186-902b-5f8a0733d991",
    "operation_type": "create",
    "server_version": 1
  },
  {
    "payload": {
      "id": "b7a86b85-d3cc-4fd1-8a47-8ecd76d373d2",
      "name": "حريمى",
      "is_active": true,
      "created_at": "2026-09-30T00:01:49.898022+00:00",
      "updated_at": "2026-09-30T00:01:49.898022+00:00",
      "item_type_id": "75800189-c36e-414d-b792-da5092357650",
      "server_version": 1
    },
    "sequence": 18,
    "entity_id": "b7a86b85-d3cc-4fd1-8a47-8ecd76d373d2",
    "created_at": "2026-09-30T00:33:10.538464+00:00",
    "entity_type": "item_definition",
    "operation_id": "eba0f877-2add-4e93-b3d2-4406017daa35",
    "operation_type": "create",
    "server_version": 1
  },
  {
    "payload": {
      "id": "1b08e1ad-4be6-4ba6-b954-fbeafb3613fe",
      "name": "جلابية",
      "is_active": true,
      "created_at": "2026-09-30T00:02:08.101911+00:00",
      "updated_at": "2026-09-30T00:02:08.101911+00:00",
      "server_version": 1
    },
    "sequence": 19,
    "entity_id": "1b08e1ad-4be6-4ba6-b954-fbeafb3613fe",
    "created_at": "2026-09-30T00:33:11.053443+00:00",
    "entity_type": "item_type",
    "operation_id": "a9756fd0-c4ac-460d-a14c-4f34926d50d7",
    "operation_type": "create",
    "server_version": 1
  },
  {
    "payload": {
      "id": "d41bb93f-3709-4330-847d-3e9a33ba39b7",
      "name": "تنظيف بطانية زوجى",
      "price": 6000,
      "is_active": true,
      "created_at": "2026-09-30T03:03:53.182565+00:00",
      "updated_at": "2026-09-30T03:03:53.182565+00:00",
      "description": null,
      "pricing_type": "per_piece",
      "server_version": 1,
      "supported_item_type_ids": [
        "eec035c5-0872-4304-8d44-9e5eb11445ea"
      ]
    },
    "sequence": 20,
    "entity_id": "d41bb93f-3709-4330-847d-3e9a33ba39b7",
    "created_at": "2026-09-30T00:34:31.322051+00:00",
    "entity_type": "service",
    "operation_id": "5b375408-b3b6-43e9-867c-bd53271dd1eb",
    "operation_type": "create",
    "server_version": 1
  },
  {
    "payload": {
      "id": "a99915aa-7a05-45a6-9db0-4db43576bf66",
      "name": "صبغة اسود",
      "price": 10000,
      "is_active": true,
      "created_at": "2026-09-30T03:06:23.932812+00:00",
      "updated_at": "2026-09-30T03:06:23.932812+00:00",
      "description": null,
      "pricing_type": "per_piece",
      "server_version": 1,
      "supported_item_type_ids": [
        "75800189-c36e-414d-b792-da5092357650",
        "287b0e94-10b6-4c9d-9951-e455e6064c85",
        "9fe9650a-a4bd-42de-b2c4-d68ebbcdb962",
        "1b08e1ad-4be6-4ba6-b954-fbeafb3613fe"
      ]
    },
    "sequence": 21,
    "entity_id": "a99915aa-7a05-45a6-9db0-4db43576bf66",
    "created_at": "2026-09-30T00:35:35.898027+00:00",
    "entity_type": "service",
    "operation_id": "01aaf19a-7145-4383-bc48-09b08d0be88f",
    "operation_type": "create",
    "server_version": 1
  },
  {
    "payload": {
      "id": "a99915aa-7a05-45a6-9db0-4db43576bf66",
      "name": "صبغة اسود",
      "price": 10000,
      "is_active": true,
      "updated_at": "2026-09-30T03:12:08.947281+00:00",
      "description": null,
      "pricing_type": "per_piece",
      "server_version": 2
    },
    "sequence": 22,
    "entity_id": "a99915aa-7a05-45a6-9db0-4db43576bf66",
    "created_at": "2026-09-30T00:36:04.317454+00:00",
    "entity_type": "service",
    "operation_id": "afb7533d-c587-4735-a6b9-4c28b9d52d2e",
    "operation_type": "update",
    "server_version": 2
  },
  {
    "payload": {
      "id": "41cd5710-bb0c-4e4c-88d6-70476a4f7f2c",
      "name": "غسيل ومكوة جاكت",
      "price": 8000,
      "is_active": true,
      "created_at": "2026-09-30T03:17:09.787113+00:00",
      "updated_at": "2026-09-30T03:17:09.787113+00:00",
      "description": null,
      "pricing_type": "per_piece",
      "server_version": 1,
      "supported_item_type_ids": [
        "9fe9650a-a4bd-42de-b2c4-d68ebbcdb962"
      ]
    },
    "sequence": 23,
    "entity_id": "41cd5710-bb0c-4e4c-88d6-70476a4f7f2c",
    "created_at": "2026-09-30T00:37:01.276967+00:00",
    "entity_type": "service",
    "operation_id": "5197018e-7ddc-4b90-868f-a4de55e01be1",
    "operation_type": "create",
    "server_version": 1
  },
  {
    "payload": {
      "id": "fffa76b2-6918-47e5-ae8f-06faedbbd080",
      "name": "موكيتة",
      "is_active": true,
      "updated_at": "2026-09-30T00:32:04.55886+00:00",
      "server_version": 2
    },
    "sequence": 24,
    "entity_id": "fffa76b2-6918-47e5-ae8f-06faedbbd080",
    "created_at": "2026-09-30T00:44:40.561357+00:00",
    "entity_type": "item_type",
    "operation_id": "41903e16-a420-4d6c-9534-6831fe389f04",
    "operation_type": "update",
    "server_version": 2
  },
  {
    "payload": {
      "id": "866f582e-0d91-4d60-afda-125e5c7cfd4e",
      "area": 3,
      "name": null,
      "width": 2,
      "length": 1.5,
      "is_active": true,
      "created_at": "2026-09-30T00:35:33.143598+00:00",
      "updated_at": "2026-09-30T00:35:33.143598+00:00",
      "server_version": 1
    },
    "sequence": 25,
    "entity_id": "866f582e-0d91-4d60-afda-125e5c7cfd4e",
    "created_at": "2026-09-30T00:46:20.703855+00:00",
    "entity_type": "carpet_size",
    "operation_id": "08988049-09c3-44d6-ba7e-a30d0c3f6451",
    "operation_type": "create",
    "server_version": 1
  },
  {
    "payload": {
      "id": "89b5c8db-7b29-4ffb-99ea-e26f3ede4c14",
      "area": 6,
      "name": null,
      "width": 3,
      "length": 2,
      "is_active": true,
      "created_at": "2026-09-30T00:35:41.929751+00:00",
      "updated_at": "2026-09-30T00:35:41.929751+00:00",
      "server_version": 1
    },
    "sequence": 26,
    "entity_id": "89b5c8db-7b29-4ffb-99ea-e26f3ede4c14",
    "created_at": "2026-09-30T00:46:21.277677+00:00",
    "entity_type": "carpet_size",
    "operation_id": "6abb00ca-a7b3-4ba8-86e4-5563a40f5198",
    "operation_type": "create",
    "server_version": 1
  },
  {
    "payload": {
      "id": "fd9cd509-a095-4ced-ae0b-5f089c696862",
      "area": 9,
      "name": null,
      "width": 3,
      "length": 3,
      "is_active": true,
      "created_at": "2026-09-30T00:35:48.451507+00:00",
      "updated_at": "2026-09-30T00:35:48.451507+00:00",
      "server_version": 1
    },
    "sequence": 27,
    "entity_id": "fd9cd509-a095-4ced-ae0b-5f089c696862",
    "created_at": "2026-09-30T00:46:21.975038+00:00",
    "entity_type": "carpet_size",
    "operation_id": "37a8056a-6512-4b45-9fbf-5d3dcef9bec1",
    "operation_type": "create",
    "server_version": 1
  },
  {
    "payload": {
      "id": "886981f9-542f-4e40-9f4a-d45aec1227e1",
      "area": 12,
      "name": null,
      "width": 4,
      "length": 3,
      "is_active": true,
      "created_at": "2026-09-30T00:35:52.989559+00:00",
      "updated_at": "2026-09-30T00:35:52.989559+00:00",
      "server_version": 1
    },
    "sequence": 28,
    "entity_id": "886981f9-542f-4e40-9f4a-d45aec1227e1",
    "created_at": "2026-09-30T00:46:22.379223+00:00",
    "entity_type": "carpet_size",
    "operation_id": "f4f589d7-fefa-4d71-93f4-4969375903ab",
    "operation_type": "create",
    "server_version": 1
  },
  {
    "payload": {
      "id": "9edf2770-d7bb-4a53-9308-3d5e62fba591",
      "area": 16,
      "name": null,
      "width": 4,
      "length": 4,
      "is_active": true,
      "created_at": "2026-09-30T00:35:58.407557+00:00",
      "updated_at": "2026-09-30T00:35:58.407557+00:00",
      "server_version": 1
    },
    "sequence": 29,
    "entity_id": "9edf2770-d7bb-4a53-9308-3d5e62fba591",
    "created_at": "2026-09-30T00:46:22.915802+00:00",
    "entity_type": "carpet_size",
    "operation_id": "c147268d-dc89-4ec1-8c45-127e9d076eac",
    "operation_type": "create",
    "server_version": 1
  },
  {
    "payload": {
      "id": "a47aaaed-f238-4dcc-b40c-0c728b798949",
      "area": 20,
      "name": null,
      "width": 5,
      "length": 4,
      "is_active": true,
      "created_at": "2026-09-30T00:36:02.49962+00:00",
      "updated_at": "2026-09-30T00:36:02.49962+00:00",
      "server_version": 1
    },
    "sequence": 30,
    "entity_id": "a47aaaed-f238-4dcc-b40c-0c728b798949",
    "created_at": "2026-09-30T00:46:23.576998+00:00",
    "entity_type": "carpet_size",
    "operation_id": "fa62f9db-b903-471f-a510-a0f15fceab9a",
    "operation_type": "create",
    "server_version": 1
  },
  {
    "payload": {
      "id": "ef7aa3c4-697c-42e3-8829-b67daf38e9fd",
      "area": 4.5,
      "name": null,
      "width": 3,
      "length": 1.5,
      "is_active": true,
      "created_at": "2026-09-30T00:36:59.211893+00:00",
      "updated_at": "2026-09-30T00:36:59.211893+00:00",
      "server_version": 1
    },
    "sequence": 31,
    "entity_id": "ef7aa3c4-697c-42e3-8829-b67daf38e9fd",
    "created_at": "2026-09-30T00:46:23.975165+00:00",
    "entity_type": "carpet_size",
    "operation_id": "22025f49-5dba-4d6c-a3a6-df03cd99a8c2",
    "operation_type": "create",
    "server_version": 1
  },
  {
    "payload": {
      "id": "2a4aaa67-2ca2-42e3-bfbb-ae015c3449ab",
      "name": "٤ قطع",
      "is_active": true,
      "created_at": "2026-09-30T01:22:09.060169+00:00",
      "updated_at": "2026-09-30T01:22:09.060169+00:00",
      "item_type_id": "b7772cc9-af69-4cf6-9079-e1bd6b030e31",
      "server_version": 1
    },
    "sequence": 32,
    "entity_id": "2a4aaa67-2ca2-42e3-bfbb-ae015c3449ab",
    "created_at": "2026-09-30T01:22:12.058271+00:00",
    "entity_type": "item_definition",
    "operation_id": "7739e0c7-ee4e-45d4-95fe-d6e27abdddd4",
    "operation_type": "create",
    "server_version": 1
  },
  {
    "payload": {
      "id": "fff6bd11-cda9-4848-a8cc-5b5848cc09eb",
      "name": "٢ قطعة",
      "is_active": true,
      "created_at": "2026-09-30T01:23:22.196855+00:00",
      "updated_at": "2026-09-30T01:23:22.196855+00:00",
      "item_type_id": "b7772cc9-af69-4cf6-9079-e1bd6b030e31",
      "server_version": 1
    },
    "sequence": 33,
    "entity_id": "fff6bd11-cda9-4848-a8cc-5b5848cc09eb",
    "created_at": "2026-09-30T01:23:23.889648+00:00",
    "entity_type": "item_definition",
    "operation_id": "de095df8-1619-4fba-a96c-18137d843d79",
    "operation_type": "create",
    "server_version": 1
  },
  {
    "payload": {
      "id": "de2b6104-00dd-4571-b011-4198b59fc67e",
      "name": "محمد عبد الرازق",
      "notes": null,
      "phone": "01001748272",
      "address": null,
      "created_at": "2026-09-30T13:15:53.24644+00:00",
      "updated_at": "2026-09-30T13:15:53.24644+00:00",
      "server_version": 1
    },
    "sequence": 34,
    "entity_id": "de2b6104-00dd-4571-b011-4198b59fc67e",
    "created_at": "2026-09-30T10:15:50.681505+00:00",
    "entity_type": "customer",
    "operation_id": "10bd632d-6671-4989-a643-99525cc7e1b0",
    "operation_type": "create",
    "server_version": 1
  },
  {
    "payload": {
      "id": "9caa74de-67a5-459d-af09-6aa0182ad9f9",
      "tax": 0,
      "items": [
        {
          "id": "72aae8f9-5c29-46fc-87a8-961ca96644b2",
          "notes": null,
          "order_id": "9caa74de-67a5-459d-af09-6aa0182ad9f9",
          "quantity": 1,
          "created_at": "2026-09-30T13:16:01.258441",
          "service_id": "d41bb93f-3709-4330-847d-3e9a33ba39b7",
          "unit_price": 6000,
          "updated_at": "2026-09-30T13:16:01.258441",
          "item_type_id": "eec035c5-0872-4304-8d44-9e5eb11445ea",
          "pricing_type": "per_piece",
          "calculated_total": 6000,
          "item_definition_id": null,
          "service_name_snapshot": "تنظيف بطانية زوجى",
          "item_type_name_snapshot": "بطانية زوجى",
          "item_definition_name_snapshot": null
        }
      ],
      "notes": null,
      "total": 6000,
      "status": "processing",
      "discount": 0,
      "subtotal": 6000,
      "created_at": "2026-09-30T13:16:01.258441+00:00",
      "updated_at": "2026-09-30T13:16:01.258441+00:00",
      "customer_id": "de2b6104-00dd-4571-b011-4198b59fc67e",
      "paid_amount": 0,
      "order_number": "26-001",
      "server_version": 1,
      "customer_pickup_fee": 0,
      "expected_pickup_date": "2026-10-07",
      "customer_delivery_fee": 0,
      "customer_name_snapshot": "محمد عبد الرازق",
      "customer_phone_snapshot": "01001748272",
      "customer_pickup_requested": false,
      "customer_delivery_requested": false
    },
    "sequence": 35,
    "entity_id": "9caa74de-67a5-459d-af09-6aa0182ad9f9",
    "created_at": "2026-09-30T10:15:58.520104+00:00",
    "entity_type": "order",
    "operation_id": "dc2a7afd-1de0-4425-a3a7-4756d912afe4",
    "operation_type": "create",
    "server_version": 1
  },
  {
    "payload": {
      "id": "9f476a93-943f-4575-a983-e630572bcf04",
      "name": "محمد عبد الرازق",
      "notes": null,
      "phone": "01001748271",
      "address": null,
      "created_at": "2026-09-30T13:18:59.660336+00:00",
      "updated_at": "2026-09-30T13:18:59.660336+00:00",
      "server_version": 1
    },
    "sequence": 36,
    "entity_id": "9f476a93-943f-4575-a983-e630572bcf04",
    "created_at": "2026-09-30T10:18:57.181101+00:00",
    "entity_type": "customer",
    "operation_id": "4cc152cb-854b-4a4e-9427-d25cdc0a963e",
    "operation_type": "create",
    "server_version": 1
  },
  {
    "payload": {
      "id": "9759efbf-9242-4701-8258-38886bec7950",
      "tax": 0,
      "items": [
        {
          "id": "4562fd1d-0995-4509-a1a6-ddfe441101f5",
          "notes": null,
          "order_id": "9759efbf-9242-4701-8258-38886bec7950",
          "quantity": 1,
          "created_at": "2026-09-30T13:19:05.005232",
          "service_id": "d41bb93f-3709-4330-847d-3e9a33ba39b7",
          "unit_price": 6000,
          "updated_at": "2026-09-30T13:19:05.005232",
          "item_type_id": "eec035c5-0872-4304-8d44-9e5eb11445ea",
          "pricing_type": "per_piece",
          "calculated_total": 6000,
          "item_definition_id": null,
          "service_name_snapshot": "تنظيف بطانية زوجى",
          "item_type_name_snapshot": "بطانية زوجى",
          "item_definition_name_snapshot": null
        },
        {
          "id": "e5b17c88-7811-4d37-8a41-027957abaa94",
          "notes": null,
          "order_id": "9759efbf-9242-4701-8258-38886bec7950",
          "quantity": 1,
          "created_at": "2026-09-30T13:19:05.005232",
          "service_id": "d41bb93f-3709-4330-847d-3e9a33ba39b7",
          "unit_price": 6000,
          "updated_at": "2026-09-30T13:19:05.005232",
          "item_type_id": "eec035c5-0872-4304-8d44-9e5eb11445ea",
          "pricing_type": "per_piece",
          "calculated_total": 6000,
          "item_definition_id": null,
          "service_name_snapshot": "تنظيف بطانية زوجى",
          "item_type_name_snapshot": "بطانية زوجى",
          "item_definition_name_snapshot": null
        },
        {
          "id": "8360cf79-bf92-4437-a7ef-9fec247a4b60",
          "notes": null,
          "order_id": "9759efbf-9242-4701-8258-38886bec7950",
          "quantity": 1,
          "created_at": "2026-09-30T13:19:05.005232",
          "service_id": "d41bb93f-3709-4330-847d-3e9a33ba39b7",
          "unit_price": 6000,
          "updated_at": "2026-09-30T13:19:05.005232",
          "item_type_id": "eec035c5-0872-4304-8d44-9e5eb11445ea",
          "pricing_type": "per_piece",
          "calculated_total": 6000,
          "item_definition_id": null,
          "service_name_snapshot": "تنظيف بطانية زوجى",
          "item_type_name_snapshot": "بطانية زوجى",
          "item_definition_name_snapshot": null
        },
        {
          "id": "0f8f8091-d184-4023-aeb2-cfc39eb3b81c",
          "notes": null,
          "order_id": "9759efbf-9242-4701-8258-38886bec7950",
          "quantity": 1,
          "created_at": "2026-09-30T13:19:05.005232",
          "service_id": "d41bb93f-3709-4330-847d-3e9a33ba39b7",
          "unit_price": 6000,
          "updated_at": "2026-09-30T13:19:05.005232",
          "item_type_id": "eec035c5-0872-4304-8d44-9e5eb11445ea",
          "pricing_type": "per_piece",
          "calculated_total": 6000,
          "item_definition_id": null,
          "service_name_snapshot": "تنظيف بطانية زوجى",
          "item_type_name_snapshot": "بطانية زوجى",
          "item_definition_name_snapshot": null
        },
        {
          "id": "5815012a-e21b-4631-9cc0-961c0ddcd62c",
          "notes": null,
          "order_id": "9759efbf-9242-4701-8258-38886bec7950",
          "quantity": 1,
          "created_at": "2026-09-30T13:19:05.005232",
          "service_id": "d41bb93f-3709-4330-847d-3e9a33ba39b7",
          "unit_price": 6000,
          "updated_at": "2026-09-30T13:19:05.005232",
          "item_type_id": "eec035c5-0872-4304-8d44-9e5eb11445ea",
          "pricing_type": "per_piece",
          "calculated_total": 6000,
          "item_definition_id": null,
          "service_name_snapshot": "تنظيف بطانية زوجى",
          "item_type_name_snapshot": "بطانية زوجى",
          "item_definition_name_snapshot": null
        },
        {
          "id": "02abb2c7-4b33-4234-a60b-a22b7ecadff2",
          "notes": null,
          "order_id": "9759efbf-9242-4701-8258-38886bec7950",
          "quantity": 1,
          "created_at": "2026-09-30T13:19:05.005232",
          "service_id": "d41bb93f-3709-4330-847d-3e9a33ba39b7",
          "unit_price": 6000,
          "updated_at": "2026-09-30T13:19:05.005232",
          "item_type_id": "eec035c5-0872-4304-8d44-9e5eb11445ea",
          "pricing_type": "per_piece",
          "calculated_total": 6000,
          "item_definition_id": null,
          "service_name_snapshot": "تنظيف بطانية زوجى",
          "item_type_name_snapshot": "بطانية زوجى",
          "item_definition_name_snapshot": null
        },
        {
          "id": "fd3654e4-9d67-4ab0-975f-d36b9b64348f",
          "notes": null,
          "order_id": "9759efbf-9242-4701-8258-38886bec7950",
          "quantity": 1,
          "created_at": "2026-09-30T13:19:05.005232",
          "service_id": "d41bb93f-3709-4330-847d-3e9a33ba39b7",
          "unit_price": 6000,
          "updated_at": "2026-09-30T13:19:05.005232",
          "item_type_id": "eec035c5-0872-4304-8d44-9e5eb11445ea",
          "pricing_type": "per_piece",
          "calculated_total": 6000,
          "item_definition_id": null,
          "service_name_snapshot": "تنظيف بطانية زوجى",
          "item_type_name_snapshot": "بطانية زوجى",
          "item_definition_name_snapshot": null
        },
        {
          "id": "e0985efa-ceff-42cf-9ae6-37bd1b842a07",
          "notes": null,
          "order_id": "9759efbf-9242-4701-8258-38886bec7950",
          "quantity": 1,
          "created_at": "2026-09-30T13:19:05.005232",
          "service_id": "d41bb93f-3709-4330-847d-3e9a33ba39b7",
          "unit_price": 6000,
          "updated_at": "2026-09-30T13:19:05.005232",
          "item_type_id": "eec035c5-0872-4304-8d44-9e5eb11445ea",
          "pricing_type": "per_piece",
          "calculated_total": 6000,
          "item_definition_id": null,
          "service_name_snapshot": "تنظيف بطانية زوجى",
          "item_type_name_snapshot": "بطانية زوجى",
          "item_definition_name_snapshot": null
        },
        {
          "id": "7dd9577c-88ab-4b89-b79b-686702a9f74b",
          "notes": null,
          "order_id": "9759efbf-9242-4701-8258-38886bec7950",
          "quantity": 1,
          "created_at": "2026-09-30T13:19:05.005232",
          "service_id": "d41bb93f-3709-4330-847d-3e9a33ba39b7",
          "unit_price": 6000,
          "updated_at": "2026-09-30T13:19:05.005232",
          "item_type_id": "eec035c5-0872-4304-8d44-9e5eb11445ea",
          "pricing_type": "per_piece",
          "calculated_total": 6000,
          "item_definition_id": null,
          "service_name_snapshot": "تنظيف بطانية زوجى",
          "item_type_name_snapshot": "بطانية زوجى",
          "item_definition_name_snapshot": null
        },
        {
          "id": "a08d10d3-70b4-4c04-857b-c92f556380af",
          "notes": null,
          "order_id": "9759efbf-9242-4701-8258-38886bec7950",
          "quantity": 1,
          "created_at": "2026-09-30T13:19:05.005232",
          "service_id": "d41bb93f-3709-4330-847d-3e9a33ba39b7",
          "unit_price": 6000,
          "updated_at": "2026-09-30T13:19:05.005232",
          "item_type_id": "eec035c5-0872-4304-8d44-9e5eb11445ea",
          "pricing_type": "per_piece",
          "calculated_total": 6000,
          "item_definition_id": null,
          "service_name_snapshot": "تنظيف بطانية زوجى",
          "item_type_name_snapshot": "بطانية زوجى",
          "item_definition_name_snapshot": null
        },
        {
          "id": "93597b6b-8db7-42a8-95d4-a7d15b32eba7",
          "notes": null,
          "order_id": "9759efbf-9242-4701-8258-38886bec7950",
          "quantity": 1,
          "created_at": "2026-09-30T13:19:05.005232",
          "service_id": "d41bb93f-3709-4330-847d-3e9a33ba39b7",
          "unit_price": 6000,
          "updated_at": "2026-09-30T13:19:05.005232",
          "item_type_id": "eec035c5-0872-4304-8d44-9e5eb11445ea",
          "pricing_type": "per_piece",
          "calculated_total": 6000,
          "item_definition_id": null,
          "service_name_snapshot": "تنظيف بطانية زوجى",
          "item_type_name_snapshot": "بطانية زوجى",
          "item_definition_name_snapshot": null
        },
        {
          "id": "324e36b8-9083-498b-b7ab-a0e803aa03f3",
          "notes": null,
          "order_id": "9759efbf-9242-4701-8258-38886bec7950",
          "quantity": 1,
          "created_at": "2026-09-30T13:19:05.005232",
          "service_id": "d41bb93f-3709-4330-847d-3e9a33ba39b7",
          "unit_price": 6000,
          "updated_at": "2026-09-30T13:19:05.005232",
          "item_type_id": "eec035c5-0872-4304-8d44-9e5eb11445ea",
          "pricing_type": "per_piece",
          "calculated_total": 6000,
          "item_definition_id": null,
          "service_name_snapshot": "تنظيف بطانية زوجى",
          "item_type_name_snapshot": "بطانية زوجى",
          "item_definition_name_snapshot": null
        }
      ],
      "notes": null,
      "total": 72000,
      "status": "processing",
      "discount": 0,
      "subtotal": 72000,
      "created_at": "2026-09-30T13:19:05.005232+00:00",
      "updated_at": "2026-09-30T13:19:05.005232+00:00",
      "customer_id": "9f476a93-943f-4575-a983-e630572bcf04",
      "paid_amount": 0,
      "order_number": "26-002",
      "server_version": 1,
      "customer_pickup_fee": 0,
      "expected_pickup_date": "2026-10-07",
      "customer_delivery_fee": 0,
      "customer_name_snapshot": "محمد عبد الرازق",
      "customer_phone_snapshot": "01001748271",
      "customer_pickup_requested": false,
      "customer_delivery_requested": false
    },
    "sequence": 37,
    "entity_id": "9759efbf-9242-4701-8258-38886bec7950",
    "created_at": "2026-09-30T10:19:02.35355+00:00",
    "entity_type": "order",
    "operation_id": "1b654f85-58b2-4084-8f67-6e6831b41b10",
    "operation_type": "create",
    "server_version": 1
  },
  {
    "payload": {
      "id": "428a67ff-639a-469a-9a12-406da4f07d32",
      "name": "كريم محمد",
      "notes": null,
      "phone": "01221477572",
      "address": null,
      "created_at": "2026-09-30T17:49:34.735131+00:00",
      "updated_at": "2026-09-30T17:49:34.735131+00:00",
      "server_version": 1
    },
    "sequence": 38,
    "entity_id": "428a67ff-639a-469a-9a12-406da4f07d32",
    "created_at": "2026-09-30T14:49:31.839867+00:00",
    "entity_type": "customer",
    "operation_id": "0438fcbc-7742-4786-a8fb-311be1fa7c00",
    "operation_type": "create",
    "server_version": 1
  },
  {
    "payload": {
      "id": "d41bb93f-3709-4330-847d-3e9a33ba39b7",
      "name": "تنظيف بطانية زوجى",
      "price": 6000,
      "is_active": true,
      "updated_at": "2026-10-01T17:29:27.148712+00:00",
      "description": null,
      "pricing_type": "per_piece",
      "server_version": 2
    },
    "sequence": 39,
    "entity_id": "d41bb93f-3709-4330-847d-3e9a33ba39b7",
    "created_at": "2026-10-01T14:29:28.208978+00:00",
    "entity_type": "service",
    "operation_id": "11501448-6a61-4fbf-bd74-4eb87e3c139e",
    "operation_type": "update",
    "server_version": 2
  },
  {
    "payload": {
      "id": "d41bb93f-3709-4330-847d-3e9a33ba39b7",
      "name": "تنظيف بطانية زوجى",
      "price": 6000,
      "is_active": true,
      "updated_at": "2026-10-01T17:29:38.888753+00:00",
      "description": null,
      "pricing_type": "per_piece",
      "server_version": 3
    },
    "sequence": 40,
    "entity_id": "d41bb93f-3709-4330-847d-3e9a33ba39b7",
    "created_at": "2026-10-01T14:29:40.108512+00:00",
    "entity_type": "service",
    "operation_id": "c98fc21b-311d-462c-b63d-099da124c0af",
    "operation_type": "update",
    "server_version": 3
  }
]
```

---

## 5. Execution Scripts

The cleanup and canonical seeding are defined in:
1. `scripts/prod_supabase_safe_clean.sql`: Purges transactional and non-canonical master rows, resets sequence to 1.
2. `scripts/prod_supabase_seed_canonical_baseline.sql`: Atomically inserts canonical 35 master records and 35 sync_changes.
