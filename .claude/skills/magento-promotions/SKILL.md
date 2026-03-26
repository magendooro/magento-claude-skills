---
name: magento-promotions
description: Manage Magento cart price rules and coupons via admin REST API. Covers sales rule search, rule detail, coupon search, and coupon generation. Requires MAGENTO_ADMIN_TOKEN.
argument-hint: "[search rules, rule id, 'coupons for rule N', or 'generate coupons rule=N qty=N']"
allowed-tools: Bash(curl:*), Bash(echo:*), Bash(jq:*)
effort: medium
---

# Magento Promotions & Coupons (REST)

Cart price rules define discount logic; coupons are codes that trigger specific rules.

## Configuration

- **Base:** `${MAGENTO_BASE_URL}/rest/${MAGENTO_STORE_CODE:-default}/V1/`
- **Auth:** `Authorization: Bearer ${MAGENTO_ADMIN_TOKEN}`

---

## Operation 1: Search Sales Rules (Cart Price Rules)

```bash
curl -s -g "${MAGENTO_BASE_URL}/rest/${MAGENTO_STORE_CODE:-default}/V1/salesRules/search?searchCriteria[filterGroups][0][filters][0][field]=is_active&searchCriteria[filterGroups][0][filters][0][value]=1&searchCriteria[filterGroups][0][filters][0][conditionType]=eq&searchCriteria[pageSize]=20&searchCriteria[sortOrders][0][field]=rule_id&searchCriteria[sortOrders][0][direction]=DESC" \
  -H "Authorization: Bearer ${MAGENTO_ADMIN_TOKEN}" \
  -H "Content-Type: application/json"
```

**Common filters:**

| What | Field | Condition |
|------|-------|-----------|
| Active rules only | `is_active` | `eq` = `1` |
| By name | `name` | `like` = `%summer%` |
| By coupon type | `coupon_type` | `eq` = `1` (no coupon), `2` (specific coupon), `3` (auto-generated) |
| Valid now | `from_date` | `lteq` today + `to_date` | `gteq` today (two filterGroups) |

**Extract:** `rule_id`, `name`, `description`, `is_active`, `coupon_type`, `discount_amount`, `discount_step`, `simple_action`, `from_date`, `to_date`, `uses_per_customer`, `uses_per_coupon`

### Discount types (`simple_action`)

| Code | Meaning |
|------|---------|
| `by_percent` | % discount on cart |
| `by_fixed` | Fixed amount off cart |
| `cart_fixed` | Fixed discount applied to whole cart |
| `buy_x_get_y` | Buy X get Y free |
| `by_percent` on shipping | Shipping discount |

---

## Operation 2: Get Sales Rule by ID

```bash
curl -s "${MAGENTO_BASE_URL}/rest/${MAGENTO_STORE_CODE:-default}/V1/salesRules/${RULE_ID}" \
  -H "Authorization: Bearer ${MAGENTO_ADMIN_TOKEN}" \
  -H "Content-Type: application/json"
```

**Key fields:**
- `discount_amount` — value (% or fixed depending on `simple_action`)
- `discount_qty` — max qty discounted per item
- `discount_step` — buy-X step for buy_x_get_y
- `uses_per_coupon` — max uses per coupon code (0 = unlimited)
- `uses_per_customer` — max uses per customer
- `conditions_serialized` — JSON rule conditions (product/cart conditions)
- `customer_group_ids[]` — which customer groups qualify
- `website_ids[]` — which websites the rule applies to

---

## Operation 3: Search Coupons for a Rule

```bash
curl -s -g "${MAGENTO_BASE_URL}/rest/${MAGENTO_STORE_CODE:-default}/V1/salesRules/coupons/search?searchCriteria[filterGroups][0][filters][0][field]=rule_id&searchCriteria[filterGroups][0][filters][0][value]=${RULE_ID}&searchCriteria[filterGroups][0][filters][0][conditionType]=eq&searchCriteria[pageSize]=50" \
  -H "Authorization: Bearer ${MAGENTO_ADMIN_TOKEN}" \
  -H "Content-Type: application/json"
```

**Extract:** `coupon_id`, `rule_id`, `code`, `usage_limit`, `usage_per_customer`, `times_used`, `created_at`, `expiration_date`, `is_primary`

---

## Operation 4: Search All Coupons (by code or rule)

```bash
# Find a specific coupon code
curl -s -g "${MAGENTO_BASE_URL}/rest/${MAGENTO_STORE_CODE:-default}/V1/salesRules/coupons/search?searchCriteria[filterGroups][0][filters][0][field]=code&searchCriteria[filterGroups][0][filters][0][value]=SUMMER20&searchCriteria[filterGroups][0][filters][0][conditionType]=eq" \
  -H "Authorization: Bearer ${MAGENTO_ADMIN_TOKEN}" \
  -H "Content-Type: application/json"
```

---

## Operation 5: Generate Coupons (Write — Confirm First)

The rule must have `coupon_type: 3` (auto-generated) for this endpoint to work.

**Confirm:** "I'll generate ${QTY} coupon(s) for rule `${RULE_NAME}` (ID: ${RULE_ID}), length ${LENGTH} chars, prefix `${PREFIX}`. Confirm? (yes/no)"

```bash
# Use jq to safely build JSON — prevents injection if RULE_ID/QTY are non-numeric
curl -s -X POST "${MAGENTO_BASE_URL}/rest/${MAGENTO_STORE_CODE:-default}/V1/salesRules/${RULE_ID}/generate-coupon" \
  -H "Authorization: Bearer ${MAGENTO_ADMIN_TOKEN}" \
  -H "Content-Type: application/json" \
  -d "$(jq -n \
    --argjson rule_id "${RULE_ID}" \
    --argjson qty "${QTY:-5}" \
    --arg prefix "${PREFIX:-SUMMER-}" \
    --arg expiry "${EXPIRY_DATE:-2024-12-31}" \
    '{"couponSpec": {"rule_id": $rule_id, "quantity": $qty, "length": 12, "format": "alphanum", "prefix": $prefix, "suffix": "", "delimiter": "-", "delimiter_at_every": 4, "expiration_date": $expiry}}')"
```

**Parameter reference:**
- `quantity` — number of coupons to generate
- `length` — total code length (including prefix/suffix)
- `format` — `alphanum` (letters+digits), `alpha` (letters only), `num` (digits only)
- `prefix` / `suffix` — optional fixed strings prepended/appended
- `delimiter` + `delimiter_at_every` — e.g., delimiter=`-`, every=4 → `XXXX-XXXX-XXXX`
- `expiration_date` — optional expiry (`YYYY-MM-DD`); if omitted, rule's `to_date` applies

Response: array of generated coupon codes.

---

## Response Formatting

**Rules list:**
```
1. Rule #5 — Summer Sale 20% (active)
   Type: by_percent | 20% off | Coupon: auto-generated
   Valid: 2024-06-01 → 2024-08-31 | Uses/coupon: 1 | Uses/customer: 1

2. Rule #3 — Free Shipping over $50 (active)
   Type: shipping discount | 100% off shipping | No coupon required
```

**Coupon list:**
```
Coupons for rule #5 (Summer Sale 20%):
SUMM-ERXX-2024  | used 0/1 | expires 2024-08-31
SUMM-ABCD-2024  | used 1/1 | expires 2024-08-31
```

**Generated coupons:**
```
Generated 5 coupons for "Summer Sale 20%":
SUMMER-A4KZ-NP19
SUMMER-BM7X-QR42
SUMMER-CV3Y-WT08
SUMMER-DH6W-JS71
SUMMER-EK2V-LU95
```

---

## Error Handling

- **`"Coupon generation is allowed for rules with auto-generated coupons only"` (HTTP 400):** Rule's `coupon_type` is not 3. Cannot auto-generate; coupons must be added manually via Admin.
- **HTTP 404 on rule:** Rule ID doesn't exist or is not accessible for this store.
- **Empty coupon list:** Rule uses a fixed coupon code (`coupon_type: 2`), not auto-generated ones. Fetch the primary coupon from the rule's `code` field directly.

---

## Decision Table

| User says | Action |
|-----------|--------|
| "active promotions" / "current discounts" | Op 1 with `is_active=1` |
| "rule #5 details" | Op 2 |
| "coupons for rule 5" | Op 3 |
| "find coupon SUMMER20" | Op 4 search by code |
| "generate 10 coupons for rule 5" | Op 2 to verify type=3 → Confirm → Op 5 |
| "how many times was coupon X used?" | Op 4 search by code → extract `times_used` |

## User Request

$ARGUMENTS
