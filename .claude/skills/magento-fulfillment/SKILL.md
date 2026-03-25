---
name: magento-fulfillment
description: Manage Magento order fulfillment documents via admin REST API. Covers invoices (search, get, create), shipments (search, get, create), credit memos, order email, and returns/RMA. Requires MAGENTO_ADMIN_TOKEN.
argument-hint: "[invoice/shipment/creditmemo/return + order id or increment id]"
allowed-tools: Bash(curl:*), Bash(echo:*), Bash(jq:*)
effort: high
---

# Magento Fulfillment Documents (REST)

Covers the post-placement order lifecycle: invoices → shipments → credit memos → returns.

## Configuration

- **Base:** `${MAGENTO_BASE_URL}/rest/${MAGENTO_STORE_CODE:-default}/V1/`
- **Auth:** `Authorization: Bearer ${MAGENTO_ADMIN_TOKEN}`

---

## Operation 1: Search Invoices

```bash
curl -s -g "${MAGENTO_BASE_URL}/rest/${MAGENTO_STORE_CODE:-default}/V1/invoices?searchCriteria[filterGroups][0][filters][0][field]=order_id&searchCriteria[filterGroups][0][filters][0][value]=${ORDER_ENTITY_ID}&searchCriteria[filterGroups][0][filters][0][conditionType]=eq" \
  -H "Authorization: Bearer ${MAGENTO_ADMIN_TOKEN}" \
  -H "Content-Type: application/json"
```

**Common filters:**

| What | Field | Condition |
|------|-------|-----------|
| By order entity_id | `order_id` | `eq` |
| By invoice state | `state` | `eq` (1=pending, 2=paid, 3=canceled) |
| Date range | `created_at` | `from`/`to` |

**Extract:** `increment_id`, `order_id`, `state`, `grand_total`, `created_at`, `items[].sku`, `items[].name`, `items[].qty`

---

## Operation 2: Get Invoice by ID

```bash
curl -s "${MAGENTO_BASE_URL}/rest/${MAGENTO_STORE_CODE:-default}/V1/invoices/${INVOICE_ID}" \
  -H "Authorization: Bearer ${MAGENTO_ADMIN_TOKEN}" \
  -H "Content-Type: application/json"
```

---

## Operation 3: Create Invoice (Write — Confirm First)

**Confirm:** "I'll create an invoice for order #XXXXXX. This will capture payment. Confirm? (yes/no)"

Creates an invoice for the entire order (all items, all qty):
```bash
curl -s -X POST "${MAGENTO_BASE_URL}/rest/${MAGENTO_STORE_CODE:-default}/V1/order/${ORDER_ENTITY_ID}/invoice" \
  -H "Authorization: Bearer ${MAGENTO_ADMIN_TOKEN}" \
  -H "Content-Type: application/json" \
  -d '{"capture": false, "notify": false}'
```

- `capture: true` — attempt online payment capture (requires online payment method)
- `capture: false` — offline invoice only
- `notify: true` — send invoice email to customer

To invoice only specific items, include `items` array:
```bash
-d '{"capture": false, "notify": false, "items": [{"order_item_id": 5, "qty": 1}]}'
```

Response is the new invoice ID (integer) on success.

---

## Operation 4: Search Shipments

```bash
curl -s -g "${MAGENTO_BASE_URL}/rest/${MAGENTO_STORE_CODE:-default}/V1/shipments?searchCriteria[filterGroups][0][filters][0][field]=order_id&searchCriteria[filterGroups][0][filters][0][value]=${ORDER_ENTITY_ID}&searchCriteria[filterGroups][0][filters][0][conditionType]=eq" \
  -H "Authorization: Bearer ${MAGENTO_ADMIN_TOKEN}" \
  -H "Content-Type: application/json"
```

**Extract:** `increment_id`, `order_id`, `created_at`, `items[].sku`, `items[].qty`, `tracks[].track_number`, `tracks[].title` (carrier), `tracks[].carrier_code`

---

## Operation 5: Get Shipment by ID

```bash
curl -s "${MAGENTO_BASE_URL}/rest/${MAGENTO_STORE_CODE:-default}/V1/shipments/${SHIPMENT_ID}" \
  -H "Authorization: Bearer ${MAGENTO_ADMIN_TOKEN}" \
  -H "Content-Type: application/json"
```

---

## Operation 6: Create Shipment (Write — Confirm First)

**IMPORTANT:** Always use `POST /V1/order/{orderId}/ship`, NOT `POST /V1/shipment`. The `/V1/shipment` endpoint can create duplicate shipments if called multiple times; the order-scoped endpoint validates against order state.

**Confirm:** "I'll create a shipment for order #XXXXXX with tracking [carrier: number]. Confirm? (yes/no)"

```bash
curl -s -X POST "${MAGENTO_BASE_URL}/rest/${MAGENTO_STORE_CODE:-default}/V1/order/${ORDER_ENTITY_ID}/ship" \
  -H "Authorization: Bearer ${MAGENTO_ADMIN_TOKEN}" \
  -H "Content-Type: application/json" \
  -d '{
    "notify": true,
    "tracks": [
      {
        "track_number": "1Z999AA10123456784",
        "title": "UPS",
        "carrier_code": "ups"
      }
    ]
  }'
```

Common `carrier_code` values: `ups`, `fedex`, `usps`, `dhl`, `custom`.
To ship without tracking: omit the `tracks` array or pass `"tracks": []`.
To ship specific items: add `"items": [{"order_item_id": 5, "qty": 1}]`.

Response is the new shipment ID on success.

---

## Operation 7: Search Credit Memos

```bash
curl -s -g "${MAGENTO_BASE_URL}/rest/${MAGENTO_STORE_CODE:-default}/V1/creditmemos?searchCriteria[filterGroups][0][filters][0][field]=order_id&searchCriteria[filterGroups][0][filters][0][value]=${ORDER_ENTITY_ID}&searchCriteria[filterGroups][0][filters][0][conditionType]=eq" \
  -H "Authorization: Bearer ${MAGENTO_ADMIN_TOKEN}" \
  -H "Content-Type: application/json"
```

**Extract:** `increment_id`, `order_id`, `state`, `grand_total`, `created_at`, `items[].sku`, `items[].qty`, `items[].row_total`

---

## Operation 8: Get Credit Memo by ID

```bash
curl -s "${MAGENTO_BASE_URL}/rest/${MAGENTO_STORE_CODE:-default}/V1/creditmemos/${CREDITMEMO_ID}" \
  -H "Authorization: Bearer ${MAGENTO_ADMIN_TOKEN}" \
  -H "Content-Type: application/json"
```

**Note:** Do NOT expose refund creation as an agent action. Magento has documented race conditions producing duplicate credit memos. Refunds must be initiated from the Admin UI.

---

## Operation 9: Send Order Email (Write — Confirm First)

**Confirm:** "I'll send the order confirmation email for order #XXXXXX to the customer. Confirm? (yes/no)"

```bash
curl -s -X POST "${MAGENTO_BASE_URL}/rest/${MAGENTO_STORE_CODE:-default}/V1/orders/${ORDER_ENTITY_ID}/emails" \
  -H "Authorization: Bearer ${MAGENTO_ADMIN_TOKEN}" \
  -H "Content-Type: application/json"
```

Response is `true` on success.

---

## Operation 10: Search Returns (RMA)

Returns are available on Magento Open Source 2.3+. If the endpoint returns 404, the RMA module may not be enabled.

```bash
curl -s -g "${MAGENTO_BASE_URL}/rest/${MAGENTO_STORE_CODE:-default}/V1/returns?searchCriteria[filterGroups][0][filters][0][field]=order_id&searchCriteria[filterGroups][0][filters][0][value]=${ORDER_ENTITY_ID}&searchCriteria[filterGroups][0][filters][0][conditionType]=eq&searchCriteria[pageSize]=10" \
  -H "Authorization: Bearer ${MAGENTO_ADMIN_TOKEN}" \
  -H "Content-Type: application/json"
```

**Extract:** `entity_id`, `increment_id`, `order_id`, `status`, `created_at`, `items[].sku`, `items[].qty_requested`, `items[].reason`

---

## Operation 11: Get Return by ID

```bash
curl -s "${MAGENTO_BASE_URL}/rest/${MAGENTO_STORE_CODE:-default}/V1/returns/${RETURN_ID}/labels" \
  -H "Authorization: Bearer ${MAGENTO_ADMIN_TOKEN}" \
  -H "Content-Type: application/json"
```

Full return detail:
```bash
curl -s "${MAGENTO_BASE_URL}/rest/${MAGENTO_STORE_CODE:-default}/V1/returns/${RETURN_ID}" \
  -H "Authorization: Bearer ${MAGENTO_ADMIN_TOKEN}" \
  -H "Content-Type: application/json"
```

---

## Response Formatting

**Invoice list:**
```
Invoice #000000001 | paid | $36.39 | 2024-01-15
  Items: Iris Workout Top (WS03-XS-Red) × 1
```

**Shipment list:**
```
Shipment #000000001 | 2024-01-16
  Tracking: UPS 1Z999AA10123456784
  Items: Iris Workout Top × 1
```

**Credit memo:**
```
Credit Memo #000000001 | refunded $36.39 | 2024-01-20
  Items: Iris Workout Top × 1 | $29.00
  Shipping refund: $5.00 | Tax refund: $2.39
```

---

## Error Handling

- **`"Cannot create invoice"` / HTTP 400:** Order may already be fully invoiced, or status doesn't allow it. Show the error.
- **`"Cannot ship order"` etc.:** Order not in shippable state (check if invoice exists first for some payment methods).
- **HTTP 404 on `/returns`:** RMA module may not be enabled on this store.
- **Duplicate shipment concern:** Always use `/order/{id}/ship` not `/shipment`.

---

## Decision Table

| User says | Action |
|-----------|--------|
| "invoices for order 123" | Search invoices by order_id |
| "create invoice for order 123" | Confirm → POST /order/123/invoice |
| "has order 123 shipped?" | Search shipments by order_id |
| "create shipment with UPS tracking XYZ" | Confirm → POST /order/123/ship |
| "refund for order 123" | Search credit memos — DO NOT create via API |
| "send confirmation email for order 123" | Confirm → POST /orders/123/emails |
| "return request for order 123" | Search returns by order_id |

## User Request

$ARGUMENTS
