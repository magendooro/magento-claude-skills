---
name: magento-product-admin
description: Manage Magento products via admin REST API. Covers product search, full product detail, attribute inspection, and product updates with automatic EAV label-to-ID resolution. Requires MAGENTO_ADMIN_TOKEN.
argument-hint: "[sku, 'search <term>', 'update <sku> field=value', or 'attribute <code>']"
allowed-tools: Bash(curl:*), Bash(echo:*), Bash(jq:*), Bash(python3:*)
effort: high
---

# Magento Admin Product Management (REST)

The admin REST product API returns more fields than GraphQL and supports writes. Use this skill for catalog management tasks; use `magento-products` for storefront search.

## Configuration

- **Base:** `${MAGENTO_BASE_URL}/rest/${MAGENTO_STORE_CODE:-default}/V1/`
- **Auth:** `Authorization: Bearer ${MAGENTO_ADMIN_TOKEN}`

---

## Operation 1: Search Products (Admin REST)

```bash
curl -s -g "${MAGENTO_BASE_URL}/rest/${MAGENTO_STORE_CODE:-default}/V1/products?searchCriteria[filterGroups][0][filters][0][field]=name&searchCriteria[filterGroups][0][filters][0][value]=%yoga%&searchCriteria[filterGroups][0][filters][0][conditionType]=like&searchCriteria[pageSize]=20&searchCriteria[sortOrders][0][field]=name&searchCriteria[sortOrders][0][direction]=ASC" \
  -H "Authorization: Bearer ${MAGENTO_ADMIN_TOKEN}" \
  -H "Content-Type: application/json"
```

**Common filters:**

| What | Field | Condition | Value |
|------|-------|-----------|-------|
| Name contains | `name` | `like` | `%yoga%` |
| Exact SKU | `sku` | `eq` | `WS03-XS-Red` |
| SKU prefix | `sku` | `like` | `WS03%` |
| Product type | `type_id` | `eq` | `simple`, `configurable`, `virtual`, `bundle`, `grouped`, `downloadable` |
| Status | `status` | `eq` | `1` (enabled), `2` (disabled) |
| Attribute set | `attribute_set_id` | `eq` | `4` (default) |
| Price range | `price` | `from`/`to` | `10.00` |
| Category | `category_id` | `eq` | `15` |
| Updated since | `updated_at` | `gteq` | `2024-01-01 00:00:00` |

**Extract from items:** `sku`, `name`, `type_id`, `status`, `price`, `attribute_set_id`, `extension_attributes.stock_item.qty`

---

## Operation 2: Get Full Product Detail

```bash
curl -s "${MAGENTO_BASE_URL}/rest/${MAGENTO_STORE_CODE:-default}/V1/products/${SKU}" \
  -H "Authorization: Bearer ${MAGENTO_ADMIN_TOKEN}" \
  -H "Content-Type: application/json"
```

**Key response fields:**
- `sku`, `name`, `type_id`, `status`, `visibility`, `price`, `weight`
- `custom_attributes[]` — array of `{attribute_code, value}` pairs (EAV attributes)
  - Values for `select`/`multiselect` attributes are integer option IDs, NOT labels
  - Use Operation 4 (Get Attribute) to resolve IDs → labels
- `extension_attributes.stock_item` — stock data
- `media_gallery_entries[]` — images
- `product_links[]` — related/upsell/crosssell links
- For configurables: `extension_attributes.configurable_product_options[]` and `extension_attributes.configurable_product_links[]`

---

## Operation 3: Update Product (Write — Confirm First + EAV Resolution)

**Confirm:** "I'll update SKU `${SKU}`: [list changes]. Confirm? (yes/no)"

### Standard fields (no EAV lookup needed)

```bash
curl -s -X PUT "${MAGENTO_BASE_URL}/rest/${MAGENTO_STORE_CODE:-default}/V1/products/${SKU}" \
  -H "Authorization: Bearer ${MAGENTO_ADMIN_TOKEN}" \
  -H "Content-Type: application/json" \
  -d '{
    "product": {
      "sku": "WS03-XS-Red",
      "name": "Iris Workout Top (Updated)",
      "price": 34.99,
      "status": 1,
      "visibility": 4
    }
  }'
```

`status`: 1=enabled, 2=disabled
`visibility`: 1=not visible, 2=catalog only, 3=search only, 4=catalog+search

### Custom attributes (EAV — requires label→ID resolution)

For `select`/`multiselect`/`swatch` attributes, you **must** send the integer option ID, not the label.

**Step 1:** Look up the attribute options (Op 4 below)
**Step 2:** Find the option where `label` matches (case-insensitive)
**Step 3:** Use the `value` field (integer ID) in the update

```bash
curl -s -X PUT "${MAGENTO_BASE_URL}/rest/${MAGENTO_STORE_CODE:-default}/V1/products/${SKU}" \
  -H "Authorization: Bearer ${MAGENTO_ADMIN_TOKEN}" \
  -H "Content-Type: application/json" \
  -d '{
    "product": {
      "sku": "WS03-XS-Red",
      "custom_attributes": [
        {"attribute_code": "color", "value": "58"},
        {"attribute_code": "description", "value": "<p>Updated description.</p>"},
        {"attribute_code": "special_price", "value": "24.99"}
      ]
    }
  }'
```

**Boolean attributes:** `"1"` for true, `"0"` for false (send as strings).
**Text/textarea attributes:** send the string value directly.
**Price attributes:** send as numeric string `"24.99"`.

---

## Operation 4: Get Attribute Options (EAV Resolution)

Use this to inspect available options for `select`/`multiselect` attributes (color, size, brand, etc.) before updating a product.

```bash
curl -s "${MAGENTO_BASE_URL}/rest/${MAGENTO_STORE_CODE:-default}/V1/products/attributes/${ATTRIBUTE_CODE}" \
  -H "Authorization: Bearer ${MAGENTO_ADMIN_TOKEN}" \
  -H "Content-Type: application/json"
```

**Key fields in response:**
- `frontend_input` — `select`, `multiselect`, `text`, `textarea`, `boolean`, `price`, `date`, `swatch_visual`, `swatch_text`
- `options[]` — array of `{label, value}` pairs — **`value` is the integer ID to use in product updates**
- `is_required`, `is_unique`, `default_value`

**EAV resolution pattern (bash + jq):**

```bash
# Find the option ID for "Red" in the color attribute
COLOR_ID=$(curl -s "${MAGENTO_BASE_URL}/rest/${MAGENTO_STORE_CODE:-default}/V1/products/attributes/color" \
  -H "Authorization: Bearer ${MAGENTO_ADMIN_TOKEN}" | \
  jq -r '.options[] | select(.label | ascii_downcase == "red") | .value')
echo "Color ID for Red: $COLOR_ID"
```

---

## Operation 5: Disable / Enable Product (Write — Confirm First)

Quick status toggle:

```bash
# Disable
curl -s -X PUT "${MAGENTO_BASE_URL}/rest/${MAGENTO_STORE_CODE:-default}/V1/products/${SKU}" \
  -H "Authorization: Bearer ${MAGENTO_ADMIN_TOKEN}" \
  -H "Content-Type: application/json" \
  -d '{"product": {"sku": "'${SKU}'", "status": 2}}'

# Enable
curl -s -X PUT "${MAGENTO_BASE_URL}/rest/${MAGENTO_STORE_CODE:-default}/V1/products/${SKU}" \
  -H "Authorization: Bearer ${MAGENTO_ADMIN_TOKEN}" \
  -H "Content-Type: application/json" \
  -d '{"product": {"sku": "'${SKU}'", "status": 1}}'
```

---

## Response Formatting

**Product search result:**
```
1. WS03-XS-Red | Iris Workout Top | simple | enabled | $29.00
2. WS08-XS-Blue | Minerva LumaTech V-Tee | configurable | enabled | $32.00
```

**Product detail:**
```
SKU: WS03-XS-Red
Name: Iris Workout Top
Type: simple | Status: enabled | Visibility: catalog+search
Price: $29.00 | Weight: 1 lbs
Color: Red (ID: 58) | Size: XS (ID: 166)
Stock: 42 qty | In stock: yes
```

**Attribute options:**
```
Attribute: color (select)
Options: Black (ID: 49), Blue (ID: 50), Green (ID: 53), Orange (ID: 56), Purple (ID: 57), Red (ID: 58), White (ID: 59), Yellow (ID: 62)
```

---

## Error Handling

- **`"The product that was requested doesn't exist"` (HTTP 404):** SKU not found. Check for URL encoding — SKUs with special characters may need encoding.
- **`"Invalid value of '...' for the 'color' attribute"` (HTTP 400):** Sending a label instead of option ID. Resolve with Op 4 first.
- **`"Attribute X does not exist"` (HTTP 400):** Attribute code typo or attribute doesn't exist on this store.
- **HTTP 401:** Token expired or invalid.

---

## Decision Table

| User says | Action |
|-----------|--------|
| "search products [term]" | Op 1 with name like filter |
| "get product [sku]" | Op 2 |
| "update [sku] price to $X" | Confirm → Op 3 (standard field) |
| "update [sku] color to Red" | Op 4 to get color ID → Confirm → Op 3 with custom_attribute |
| "disable product [sku]" | Confirm → Op 5 |
| "what options does [attribute] have?" | Op 4 |
| "what is the option ID for [label] in [attribute]?" | Op 4 + jq filter |

## User Request

$ARGUMENTS
