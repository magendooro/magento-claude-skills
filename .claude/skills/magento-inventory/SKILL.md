---
name: magento-inventory
description: Check and manage Magento product inventory via admin REST API. Covers salable quantity, source items (MSI), legacy stock, inventory updates, and async bulk operations. Requires MAGENTO_ADMIN_TOKEN.
argument-hint: "[sku, 'check <sku>', 'update <sku> qty=N', or 'bulk']"
allowed-tools: Bash(curl:*), Bash(echo:*), Bash(jq:*)
effort: high
---

# Magento Inventory Management (REST)

Magento 2.3+ uses Multi-Source Inventory (MSI). The correct salable quantity for a customer is the **salable qty** (reservations-aware), not the raw source qty.

## Configuration

- **Base:** `${MAGENTO_BASE_URL}/rest/${MAGENTO_STORE_CODE:-default}/V1/`
- **Auth:** `Authorization: Bearer ${MAGENTO_ADMIN_TOKEN}`

---

## Inventory Concepts

| Concept | Meaning | Endpoint |
|---------|---------|----------|
| **Salable qty** | What can be sold (raw qty minus open reservations) | `/V1/inventory/get-product-salable-qty/{sku}/{stockId}` |
| **Source item qty** | Physical quantity at a source warehouse | `/V1/inventory/source-items` |
| **Stock** | Logical grouping of sources assigned to a sales channel | `/V1/inventory/stocks` |
| **Source** | Physical warehouse/location | `/V1/inventory/sources` |
| **Stock ID** | Default stock = `1`. Multi-stock stores have higher IDs | `/V1/inventory/stocks` |

**Rule of thumb:** Always check salable qty for "can this be sold?" questions. Check source items for "where is it physically?" questions.

---

## Operation 1: Get Salable Quantity (MSI)

The authoritative "is this product available?" check. stockId=1 is the default stock.

**Preferred endpoint — returns numeric quantity:**
```bash
curl -s "${MAGENTO_BASE_URL}/rest/${MAGENTO_STORE_CODE:-default}/V1/inventory/get-product-salable-qty/${SKU}/1" \
  -H "Authorization: Bearer ${MAGENTO_ADMIN_TOKEN}" \
  -H "Content-Type: application/json"
```

Response is a number (float): `42.0`

**If the above returns `"Request does not match any route"` — the MSI salable-qty API is not enabled on this store.** Use these fallbacks:

```bash
# Boolean check: is the SKU currently salable?
curl -s "${MAGENTO_BASE_URL}/rest/${MAGENTO_STORE_CODE:-default}/V1/inventory/is-product-salable/${SKU}/1" \
  -H "Authorization: Bearer ${MAGENTO_ADMIN_TOKEN}"
# Response: true or false

# Physical qty per source (always available when MSI is enabled):
curl -s -g "${MAGENTO_BASE_URL}/rest/${MAGENTO_STORE_CODE:-default}/V1/inventory/source-items?searchCriteria[filterGroups][0][filters][0][field]=sku&searchCriteria[filterGroups][0][filters][0][value]=${SKU}&searchCriteria[filterGroups][0][filters][0][conditionType]=eq" \
  -H "Authorization: Bearer ${MAGENTO_ADMIN_TOKEN}" | jq '.items[] | {source_code, quantity, status}'
```

**If all MSI endpoints fail**, fall back to legacy stock (Op 3 below).

**Multiple SKUs:** Run in parallel or loop:
```bash
for sku in WS03-XS-Red WS08-XS-Blue MH01-XS-Black; do
  qty=$(curl -s "${MAGENTO_BASE_URL}/rest/${MAGENTO_STORE_CODE:-default}/V1/inventory/get-product-salable-qty/${sku}/1" \
    -H "Authorization: Bearer ${MAGENTO_ADMIN_TOKEN}")
  echo "$sku: $qty"
done
```

---

## Operation 2: Get Source Items (Physical Stock per Warehouse)

```bash
curl -s -g "${MAGENTO_BASE_URL}/rest/${MAGENTO_STORE_CODE:-default}/V1/inventory/source-items?searchCriteria[filterGroups][0][filters][0][field]=sku&searchCriteria[filterGroups][0][filters][0][value]=${SKU}&searchCriteria[filterGroups][0][filters][0][conditionType]=eq" \
  -H "Authorization: Bearer ${MAGENTO_ADMIN_TOKEN}" \
  -H "Content-Type: application/json"
```

**Extract from each item:** `sku`, `source_code`, `quantity`, `status` (1=in stock, 0=out of stock)

**Browse all sources:**
```bash
curl -s -g "${MAGENTO_BASE_URL}/rest/${MAGENTO_STORE_CODE:-default}/V1/inventory/sources?searchCriteria[pageSize]=50" \
  -H "Authorization: Bearer ${MAGENTO_ADMIN_TOKEN}" \
  -H "Content-Type: application/json"
```

---

## Operation 3: Get Legacy Stock Item (Single-Source / Simple Check)

For stores not using MSI, or for a quick stock status check:

```bash
curl -s "${MAGENTO_BASE_URL}/rest/${MAGENTO_STORE_CODE:-default}/V1/stockItems/${SKU}" \
  -H "Authorization: Bearer ${MAGENTO_ADMIN_TOKEN}" \
  -H "Content-Type: application/json"
```

**Extract:** `qty`, `is_in_stock`, `min_qty`, `backorders`, `manage_stock`

---

## Operation 4: Update Source Item Quantity (Write — Confirm First)

**Confirm:** "I'll set SKU `${SKU}` quantity to ${QTY} at source `${SOURCE_CODE}`. Confirm? (yes/no)"

```bash
curl -s -X POST "${MAGENTO_BASE_URL}/rest/${MAGENTO_STORE_CODE:-default}/V1/inventory/source-items" \
  -H "Authorization: Bearer ${MAGENTO_ADMIN_TOKEN}" \
  -H "Content-Type: application/json" \
  -d '{
    "sourceItems": [
      {
        "sku": "WS03-XS-Red",
        "source_code": "default",
        "quantity": 50,
        "status": 1
      }
    ]
  }'
```

- `status: 1` = in stock, `status: 0` = out of stock
- `source_code: "default"` is the standard single-source code. Check `/V1/inventory/sources` if unsure.
- Multiple items can be sent in one call by adding more objects to `sourceItems`.

Response: HTTP 200 with empty body on success.

---

## Operation 5: Bulk Inventory Update (Async — Confirm First)

For updating many SKUs at once. Uses Magento's async bulk API — returns a `bulk_uuid` immediately, processes in background.

**Confirm:** "I'll bulk-update inventory for X SKU(s) — this will overwrite existing quantities at the specified sources. Confirm? (yes/no)"

```bash
curl -s -X POST "${MAGENTO_BASE_URL}/rest/${MAGENTO_STORE_CODE:-default}/async/bulk/V1/inventory/source-items" \
  -H "Authorization: Bearer ${MAGENTO_ADMIN_TOKEN}" \
  -H "Content-Type: application/json" \
  -d '[
    {"sourceItems": [{"sku": "WS03-XS-Red", "source_code": "default", "quantity": 50, "status": 1}]},
    {"sourceItems": [{"sku": "WS08-XS-Blue", "source_code": "default", "quantity": 30, "status": 1}]},
    {"sourceItems": [{"sku": "MH01-XS-Black", "source_code": "default", "quantity": 0, "status": 0}]}
  ]'
```

Response includes `bulk_uuid` — save it to check status.

---

## Operation 6: Check Bulk Job Status

```bash
curl -s "${MAGENTO_BASE_URL}/rest/${MAGENTO_STORE_CODE:-default}/V1/bulk/${BULK_UUID}/status" \
  -H "Authorization: Bearer ${MAGENTO_ADMIN_TOKEN}" \
  -H "Content-Type: application/json"
```

**Extract:** `operations_list[].status` (4=complete, 1=open, 2=complete_with_errors, 3=retriably_failed, 5=rejected)

Detailed per-operation status:
```bash
curl -s "${MAGENTO_BASE_URL}/rest/${MAGENTO_STORE_CODE:-default}/V1/bulk/${BULK_UUID}/detailed-status" \
  -H "Authorization: Bearer ${MAGENTO_ADMIN_TOKEN}" \
  -H "Content-Type: application/json"
```

**Polling:** Check every 5-10 seconds. A bulk job of 100 items typically completes in 10-30 seconds.

---

## Operation 7: List Stocks and Sources

```bash
# All stocks
curl -s -g "${MAGENTO_BASE_URL}/rest/${MAGENTO_STORE_CODE:-default}/V1/inventory/stocks?searchCriteria[pageSize]=50" \
  -H "Authorization: Bearer ${MAGENTO_ADMIN_TOKEN}" \
  -H "Content-Type: application/json"

# All sources with their codes
curl -s -g "${MAGENTO_BASE_URL}/rest/${MAGENTO_STORE_CODE:-default}/V1/inventory/sources?searchCriteria[pageSize]=50" \
  -H "Authorization: Bearer ${MAGENTO_ADMIN_TOKEN}" \
  -H "Content-Type: application/json"
```

---

## Response Formatting

**Salable qty check:**
```
WS03-XS-Red: 42 available (salable)
WS08-XS-Blue: 0 available (out of stock)
```

**Source items:**
```
WS03-XS-Red inventory:
  default warehouse: 50 units (in stock)
  east-coast: 12 units (in stock)
```

**Bulk update started:**
```
Bulk job submitted. UUID: abc123...
Run /magento-inventory bulk_uuid=abc123 to check status.
```

---

## Error Handling

- **HTTP 404 on `/V1/inventory/get-product-salable-qty`:** SKU not found, or MSI not enabled. Fall back to `/V1/stockItems/{sku}`.
- **HTTP 404 on `/rest/async/bulk/`:** Async API may not be available on older Magento versions.
- **`source_code` unknown:** Run sources list first to find valid codes.
- **`status` field missing in update:** Always include `status` explicitly — omitting it may leave status unchanged.

---

## Decision Table

| User says | Action |
|-----------|--------|
| "how many [sku] in stock?" | Salable qty (Op 1) |
| "is [sku] available?" | Salable qty (Op 1) |
| "stock at each warehouse for [sku]" | Source items (Op 2) |
| "set [sku] qty to N" | Confirm → update source item (Op 4) |
| "update inventory for these SKUs: ..." | Confirm → bulk update (Op 5) |
| "check bulk job [uuid]" | Bulk status (Op 6) |
| "what warehouses/sources exist?" | List sources (Op 7) |

## User Request

$ARGUMENTS
