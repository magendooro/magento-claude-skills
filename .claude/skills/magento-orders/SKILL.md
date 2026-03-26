---
name: magento-orders
description: Look up, inspect, and manage Magento orders via the admin REST API. Covers order search, detail, tracking, status history, analytics (revenue/AOV), abandoned cart quotes, and guarded write operations (cancel, hold, comment). Requires MAGENTO_ADMIN_TOKEN.
argument-hint: "[order id, increment id, email, 'recent', 'analytics', or 'abandoned carts']"
allowed-tools: Bash(curl:*), Bash(echo:*), Bash(jq:*), Bash(python3:*)
effort: high
---

# Magento Order Operations (REST)

This skill calls Magento's admin REST API directly — no MCP server needed.

## Configuration

```bash
echo "MAGENTO_BASE_URL=${MAGENTO_BASE_URL:-NOT SET}"
echo "MAGENTO_ADMIN_TOKEN=${MAGENTO_ADMIN_TOKEN:+SET (${#MAGENTO_ADMIN_TOKEN} chars)}"
echo "MAGENTO_STORE_CODE=${MAGENTO_STORE_CODE:-default}"
```

- **Base URL:** `${MAGENTO_BASE_URL}/rest/${MAGENTO_STORE_CODE:-default}/V1/`
- **Auth:** `Authorization: Bearer ${MAGENTO_ADMIN_TOKEN}`

If either env var is missing, stop and ask the user to set them.

---

## Operation 1: Search Orders

Use when the user asks for "recent orders", "orders by customer", "pending orders", or any order list.

### Endpoint

```
GET /rest/default/V1/orders?searchCriteria[...]
```

### searchCriteria Pattern

```
searchCriteria[filterGroups][0][filters][0][field]=<field>
searchCriteria[filterGroups][0][filters][0][value]=<value>
searchCriteria[filterGroups][0][filters][0][conditionType]=<condition>
searchCriteria[pageSize]=<n>
searchCriteria[currentPage]=1
searchCriteria[sortOrders][0][field]=created_at
searchCriteria[sortOrders][0][direction]=DESC
```

Condition types: `eq`, `neq`, `gt`, `gteq`, `lt`, `lteq`, `like`, `in`, `notnull`, `null`, `from`, `to`.

### Common Filters

| What | Field | Condition | Value |
|------|-------|-----------|-------|
| By status | `status` | `eq` | `pending`, `processing`, `complete`, `canceled`, `holded` |
| By customer email | `customer_email` | `eq` | `customer@example.com` |
| By customer ID | `customer_id` | `eq` | `5` |
| By increment ID | `increment_id` | `eq` | `000000001` |
| Orders since date | `created_at` | `gteq` | `2024-01-01 00:00:00` |
| Orders in range | `created_at` | `from`/`to` | `2024-01-01 00:00:00` |
| Grand total | `grand_total` | `gteq` | `100` |

### Practical Examples

**Recent 10 orders:**
```bash
curl -s -g "${MAGENTO_BASE_URL}/rest/${MAGENTO_STORE_CODE:-default}/V1/orders?searchCriteria[pageSize]=10&searchCriteria[sortOrders][0][field]=created_at&searchCriteria[sortOrders][0][direction]=DESC" \
  -H "Authorization: Bearer ${MAGENTO_ADMIN_TOKEN}" \
  -H "Content-Type: application/json"
```

**Orders by status:**
```bash
curl -s -g "${MAGENTO_BASE_URL}/rest/${MAGENTO_STORE_CODE:-default}/V1/orders?searchCriteria[filterGroups][0][filters][0][field]=status&searchCriteria[filterGroups][0][filters][0][value]=processing&searchCriteria[filterGroups][0][filters][0][conditionType]=eq&searchCriteria[pageSize]=20&searchCriteria[sortOrders][0][field]=created_at&searchCriteria[sortOrders][0][direction]=DESC" \
  -H "Authorization: Bearer ${MAGENTO_ADMIN_TOKEN}" \
  -H "Content-Type: application/json"
```

**Orders by customer email:**
```bash
curl -s -g "${MAGENTO_BASE_URL}/rest/${MAGENTO_STORE_CODE:-default}/V1/orders?searchCriteria[filterGroups][0][filters][0][field]=customer_email&searchCriteria[filterGroups][0][filters][0][value]=roni_cost@example.com&searchCriteria[filterGroups][0][filters][0][conditionType]=eq&searchCriteria[pageSize]=10&searchCriteria[sortOrders][0][field]=created_at&searchCriteria[sortOrders][0][direction]=DESC" \
  -H "Authorization: Bearer ${MAGENTO_ADMIN_TOKEN}" \
  -H "Content-Type: application/json"
```

### Response Fields to Extract

From the `items` array, surface:
- `increment_id` — customer-facing order number
- `entity_id` — internal ID (needed for write operations)
- `status` — current status
- `created_at` — order date
- `customer_firstname`, `customer_lastname`, `customer_email`
- `grand_total`, `base_currency_code`
- `total_item_count`

---

## Operation 2: Get Order Detail

Use when the user asks about a specific order (items, addresses, tracking, comments).

### By entity_id (internal ID)

```bash
curl -s "${MAGENTO_BASE_URL}/rest/${MAGENTO_STORE_CODE:-default}/V1/orders/${ENTITY_ID}" \
  -H "Authorization: Bearer ${MAGENTO_ADMIN_TOKEN}" \
  -H "Content-Type: application/json"
```

### By increment_id (customer order number)

Search first to get `entity_id`, then fetch by ID:
```bash
curl -s -g "${MAGENTO_BASE_URL}/rest/${MAGENTO_STORE_CODE:-default}/V1/orders?searchCriteria[filterGroups][0][filters][0][field]=increment_id&searchCriteria[filterGroups][0][filters][0][value]=000000001&searchCriteria[filterGroups][0][filters][0][conditionType]=eq" \
  -H "Authorization: Bearer ${MAGENTO_ADMIN_TOKEN}" \
  -H "Content-Type: application/json"
```

### Key Response Fields

- `items[]` — line items: `sku`, `name`, `qty_ordered`, `qty_shipped`, `qty_invoiced`, `price`, `row_total`
- `billing_address`, `extension_attributes.shipping_assignments[0].address` — addresses
- `status_histories[]` — order comment/status history (sorted by `created_at`)
- `payment.method` — payment method code
- `extension_attributes.shipping_assignments[0].shipping.total` — shipping info
- `extension_attributes.payment_additional_info[]` — transaction reference

**PII note:** REST order responses contain full customer/address/payment data. Never display raw payment info. Mask email, show street as "[REDACTED]" if showing to support agents.

---

## Operation 3: Get Tracking Numbers

Use when the user asks for shipping tracking, "where is my order", "has this shipped".

```bash
curl -s "${MAGENTO_BASE_URL}/rest/${MAGENTO_STORE_CODE:-default}/V1/shipments?searchCriteria[filterGroups][0][filters][0][field]=order_id&searchCriteria[filterGroups][0][filters][0][value]=${ENTITY_ID}&searchCriteria[filterGroups][0][filters][0][conditionType]=eq" \
  -H "Authorization: Bearer ${MAGENTO_ADMIN_TOKEN}" \
  -H "Content-Type: application/json"
```

From response: `items[].tracks[]` contains `track_number`, `title` (carrier name), `carrier_code`.

---

## Operation 4: Add Order Comment (Write — Confirm First)

**Always confirm with user before executing.** Tell the user what will be done and ask: "Shall I add this comment to order #XXXXXX?"

```bash
curl -s -X POST "${MAGENTO_BASE_URL}/rest/${MAGENTO_STORE_CODE:-default}/V1/orders/${ENTITY_ID}/comments" \
  -H "Authorization: Bearer ${MAGENTO_ADMIN_TOKEN}" \
  -H "Content-Type: application/json" \
  -d '{"statusHistory": {"comment": "Customer called, confirmed delivery address.", "is_customer_notified": 0, "is_visible_on_front": 0, "status": "processing"}}'
```

---

## Operation 5: Cancel Order (Write — Confirm First)

**Always confirm with user before executing.** This cannot be undone if the order has been invoiced.

```bash
curl -s -X POST "${MAGENTO_BASE_URL}/rest/${MAGENTO_STORE_CODE:-default}/V1/orders/${ENTITY_ID}/cancel" \
  -H "Authorization: Bearer ${MAGENTO_ADMIN_TOKEN}" \
  -H "Content-Type: application/json"
```

Response is `true` on success.

---

## Operation 6: Hold / Unhold Order (Write — Confirm First)

**Hold:**
```bash
curl -s -X POST "${MAGENTO_BASE_URL}/rest/${MAGENTO_STORE_CODE:-default}/V1/orders/${ENTITY_ID}/hold" \
  -H "Authorization: Bearer ${MAGENTO_ADMIN_TOKEN}" \
  -H "Content-Type: application/json"
```

**Unhold:**
```bash
curl -s -X POST "${MAGENTO_BASE_URL}/rest/${MAGENTO_STORE_CODE:-default}/V1/orders/${ENTITY_ID}/unhold" \
  -H "Authorization: Bearer ${MAGENTO_ADMIN_TOKEN}" \
  -H "Content-Type: application/json"
```

---

## Response Formatting

**Order list:**
- Numbered list: `#000000001 | processing | Jane Doe | $125.00 | 2024-01-15`
- Total: "Showing X of Y orders"
- Offer to filter by status, date, or customer

**Order detail:**
- Header: order number, status, date, customer name (masked email)
- Line items table: name, qty ordered/shipped/refunded, unit price, row total
- Shipping address (city + state only unless explicitly asked for full address)
- Status history: last 3 entries with date and comment
- Tracking numbers if shipped

**Write confirmations:**
Before any POST: "I'll [action] on order #XXXXXX. Confirm? (yes/no)"

---

## Error Handling

- **HTTP 401:** Token missing or expired. Check `MAGENTO_ADMIN_TOKEN`.
- **HTTP 404:** Order not found. Confirm the entity_id or increment_id.
- **HTTP 400:** Bad request — check field names and condition types in searchCriteria.
- **`message: "You cannot cancel this order"` etc.:** Show Magento's error message directly to the user.

---

## Decision Table

| User says | Action |
|-----------|--------|
| "recent orders" / "last orders" | Search, sorted by created_at DESC, pageSize=10 |
| "orders for [email]" | Search by customer_email eq |
| "order #000000001" | Search by increment_id, then get detail |
| "pending orders" | Search by status=pending |
| "where is order 123" | Get detail + get shipments/tracking |
| "cancel order 123" | Confirm, then POST /cancel |
| "put order 123 on hold" | Confirm, then POST /hold |
| "add a note to order 123" | Confirm comment text, then POST /comments |

---

## Operation 7: Order Analytics (Revenue / AOV / Count)

Magento has no native aggregate stats endpoint. Fetch all orders in the date range and aggregate with jq or python3.

**Important:** If total_count > pageSize, you must paginate to get all orders. Use pageSize=100 and loop pages.

```bash
# Fetch all orders in a date range (single page — adjust if total_count > 100)
export FROM_DATE="2026-01-01 00:00:00"
export TO_DATE="2026-03-31 23:59:59"

curl -s -g "${MAGENTO_BASE_URL}/rest/${MAGENTO_STORE_CODE:-default}/V1/orders?searchCriteria[filterGroups][0][filters][0][field]=created_at&searchCriteria[filterGroups][0][filters][0][value]=${FROM_DATE}&searchCriteria[filterGroups][0][filters][0][conditionType]=gteq&searchCriteria[filterGroups][1][filters][0][field]=created_at&searchCriteria[filterGroups][1][filters][0][value]=${TO_DATE}&searchCriteria[filterGroups][1][filters][0][conditionType]=lteq&searchCriteria[filterGroups][2][filters][0][field]=status&searchCriteria[filterGroups][2][filters][0][value]=canceled&searchCriteria[filterGroups][2][filters][0][conditionType]=neq&searchCriteria[pageSize]=100&searchCriteria[currentPage]=1" \
  -H "Authorization: Bearer ${MAGENTO_ADMIN_TOKEN}" \
  -H "Content-Type: application/json" | \
  jq '{
    total_orders: .total_count,
    revenue: ([.items[].grand_total] | add // 0),
    aov: (([.items[].grand_total] | add // 0) / ((.items | length) | if . == 0 then 1 else . end)),
    note: (if .total_count > (.items | length) then "WARNING: results truncated — paginate for full data" else "complete" end)
  }'
```

**Paginating for large result sets:**
```bash
export FROM_DATE="2026-01-01 00:00:00"
export TO_DATE="2026-03-31 23:59:59"
PAGE=1; TOTAL=0; REVENUE=0; COUNT=0

while true; do
  RESULT=$(curl -s -g "${MAGENTO_BASE_URL}/rest/${MAGENTO_STORE_CODE:-default}/V1/orders?searchCriteria[filterGroups][0][filters][0][field]=created_at&searchCriteria[filterGroups][0][filters][0][value]=${FROM_DATE}&searchCriteria[filterGroups][0][filters][0][conditionType]=gteq&searchCriteria[filterGroups][1][filters][0][field]=created_at&searchCriteria[filterGroups][1][filters][0][value]=${TO_DATE}&searchCriteria[filterGroups][1][filters][0][conditionType]=lteq&searchCriteria[filterGroups][2][filters][0][field]=status&searchCriteria[filterGroups][2][filters][0][value]=canceled&searchCriteria[filterGroups][2][filters][0][conditionType]=neq&searchCriteria[pageSize]=100&searchCriteria[currentPage]=${PAGE}" \
    -H "Authorization: Bearer ${MAGENTO_ADMIN_TOKEN}")
  TOTAL=$(echo "$RESULT" | jq '.total_count')
  PAGE_REV=$(echo "$RESULT" | jq '[.items[].grand_total] | add // 0')
  PAGE_COUNT=$(echo "$RESULT" | jq '.items | length')
  REVENUE=$(python3 -c "print($REVENUE + $PAGE_REV)")
  COUNT=$((COUNT + PAGE_COUNT))
  [ $COUNT -ge $TOTAL ] && break
  PAGE=$((PAGE + 1))
done

python3 -c "
revenue=$REVENUE; count=$COUNT
print(f'Orders: {count}')
print(f'Revenue: €{revenue:,.2f}')
print(f'AOV: €{revenue/count:,.2f}' if count > 0 else 'AOV: n/a')
"
```

**Break down by status:**
```bash
curl -s -g "${MAGENTO_BASE_URL}/rest/${MAGENTO_STORE_CODE:-default}/V1/orders?searchCriteria[filterGroups][0][filters][0][field]=created_at&searchCriteria[filterGroups][0][filters][0][value]=2026-01-01 00:00:00&searchCriteria[filterGroups][0][filters][0][conditionType]=gteq&searchCriteria[pageSize]=100" \
  -H "Authorization: Bearer ${MAGENTO_ADMIN_TOKEN}" | \
  jq '.items | group_by(.status) | map({status: .[0].status, count: length, revenue: ([.[].grand_total] | add)}) | sort_by(.count) | reverse'
```

---

## Operation 8: Abandoned Cart / Quote Search

Magento stores active and abandoned carts as quotes. Status 1=open (active/abandoned).

```bash
# Recent abandoned carts (open quotes updated > 1 day ago)
curl -s -g "${MAGENTO_BASE_URL}/rest/${MAGENTO_STORE_CODE:-default}/V1/carts?searchCriteria[filterGroups][0][filters][0][field]=is_active&searchCriteria[filterGroups][0][filters][0][value]=1&searchCriteria[filterGroups][0][filters][0][conditionType]=eq&searchCriteria[filterGroups][1][filters][0][field]=items_count&searchCriteria[filterGroups][1][filters][0][value]=0&searchCriteria[filterGroups][1][filters][0][conditionType]=gt&searchCriteria[pageSize]=20&searchCriteria[sortOrders][0][field]=updated_at&searchCriteria[sortOrders][0][direction]=DESC" \
  -H "Authorization: Bearer ${MAGENTO_ADMIN_TOKEN}" \
  -H "Content-Type: application/json"
```

**Extract:** `entity_id`, `customer_email`, `customer_firstname`, `customer_lastname`, `grand_total`, `items_count`, `created_at`, `updated_at`, `items[].name`, `items[].sku`, `items[].qty`

**PII note:** Mask `customer_email` in output (`r***@e***.com`). Show customer name as initials only (e.g., `V. C.`). Never display raw email addresses in abandoned cart reports.

**Filter by cart value (high-value abandoned carts):**
```bash
# Carts with > €100 grand_total
curl -s -g "${MAGENTO_BASE_URL}/rest/${MAGENTO_STORE_CODE:-default}/V1/carts?searchCriteria[filterGroups][0][filters][0][field]=is_active&searchCriteria[filterGroups][0][filters][0][value]=1&searchCriteria[filterGroups][0][filters][0][conditionType]=eq&searchCriteria[filterGroups][1][filters][0][field]=grand_total&searchCriteria[filterGroups][1][filters][0][value]=100&searchCriteria[filterGroups][1][filters][0][conditionType]=gteq&searchCriteria[pageSize]=20&searchCriteria[sortOrders][0][field]=grand_total&searchCriteria[sortOrders][0][direction]=DESC" \
  -H "Authorization: Bearer ${MAGENTO_ADMIN_TOKEN}" \
  -H "Content-Type: application/json"
```

**Guest carts:** Guest carts have `customer_is_guest: true` and no customer_id. They still show email if the customer entered it during checkout.

---

## Response Formatting (additions)

**Analytics:**
```
Order Analytics: 2026-01-01 → 2026-03-31
Orders: 142 (excluding canceled)
Revenue: €18,450.00
AOV: €129.93

By status:
  complete:    98 orders | €14,200.00
  processing:  32 orders | €3,800.00
  holded:       8 orders | €450.00
  pending:      4 orders | €0.00
```

**Abandoned carts:**
```
Top 5 abandoned carts (by value):
1. V. C. (r***@e***.com) | €285.00 | 3 items | last active 2 days ago
2. J. D. (j***@e***.com) | €199.99 | 1 item  | last active 5 days ago
```

---

## Decision Table (updated)

| User says | Action |
|-----------|--------|
| "recent orders" / "last orders" | Op 1 — Search, sorted by created_at DESC |
| "orders for [email]" | Op 1 — Search by customer_email |
| "order #000000001" | Op 1 search by increment_id → Op 2 detail |
| "pending orders" | Op 1 — Search by status=pending |
| "where is order 123" | Op 2 detail + Op 3 tracking |
| "cancel order 123" | Confirm → Op 5 |
| "put order 123 on hold" | Confirm → Op 6 |
| "add a note to order 123" | Confirm → Op 4 |
| "revenue this month / analytics" | Op 7 with date range |
| "abandoned carts" | Op 8 |
| "high-value abandoned carts" | Op 8 with grand_total filter |

## User Request

$ARGUMENTS
