---
name: magento-customers
description: Search and view Magento customer data via admin REST API. Covers customer search by email/name/id, order history, customer groups. Requires MAGENTO_ADMIN_TOKEN. Never expose raw PII — mask emails and names in output.
argument-hint: "[email, name, customer id, or 'search <term>']"
allowed-tools: Bash(curl:*), Bash(echo:*), Bash(jq:*)
effort: high
---

# Magento Customer Operations (REST)

This skill calls Magento's admin REST API directly — no MCP server needed.

## Configuration

```bash
echo "MAGENTO_BASE_URL=${MAGENTO_BASE_URL:-NOT SET}"
echo "MAGENTO_ADMIN_TOKEN=${MAGENTO_ADMIN_TOKEN:+SET (${#MAGENTO_ADMIN_TOKEN} chars)}"
echo "MAGENTO_STORE_CODE=${MAGENTO_STORE_CODE:-default}"
```

- **Base URL:** `${MAGENTO_BASE_URL}/rest/${MAGENTO_STORE_CODE:-default}/V1/`
- **Auth:** `Authorization: Bearer ${MAGENTO_ADMIN_TOKEN}`

---

## Operation 1: Search Customers

Use when the user asks to find a customer by email, name, or ID.

### By email (exact match)

```bash
curl -s -g "${MAGENTO_BASE_URL}/rest/${MAGENTO_STORE_CODE:-default}/V1/customers/search?searchCriteria[filterGroups][0][filters][0][field]=email&searchCriteria[filterGroups][0][filters][0][value]=customer@example.com&searchCriteria[filterGroups][0][filters][0][conditionType]=eq" \
  -H "Authorization: Bearer ${MAGENTO_ADMIN_TOKEN}" \
  -H "Content-Type: application/json"
```

### By name (partial match)

```bash
curl -s -g "${MAGENTO_BASE_URL}/rest/${MAGENTO_STORE_CODE:-default}/V1/customers/search?searchCriteria[filterGroups][0][filters][0][field]=firstname&searchCriteria[filterGroups][0][filters][0][value]=%Jane%&searchCriteria[filterGroups][0][filters][0][conditionType]=like&searchCriteria[filterGroups][1][filters][0][field]=lastname&searchCriteria[filterGroups][1][filters][0][value]=%Doe%&searchCriteria[filterGroups][1][filters][0][conditionType]=like&searchCriteria[pageSize]=10" \
  -H "Authorization: Bearer ${MAGENTO_ADMIN_TOKEN}" \
  -H "Content-Type: application/json"
```

Note: Multiple `filterGroups` are ANDed. Multiple `filters` within the same group are ORed.

### Common Search Fields

| What | Field | Condition |
|------|-------|-----------|
| By email | `email` | `eq` or `like` |
| By first name | `firstname` | `eq` or `like` |
| By last name | `lastname` | `eq` or `like` |
| By group | `group_id` | `eq` |
| By website | `website_id` | `eq` |
| Created since | `created_at` | `gteq` |

---

## Operation 2: Get Customer by ID

```bash
curl -s "${MAGENTO_BASE_URL}/rest/${MAGENTO_STORE_CODE:-default}/V1/customers/${CUSTOMER_ID}" \
  -H "Authorization: Bearer ${MAGENTO_ADMIN_TOKEN}" \
  -H "Content-Type: application/json"
```

### Key Response Fields

- `id` — internal customer ID
- `email` — email address
- `firstname`, `lastname`
- `created_at`, `updated_at`
- `group_id` — customer group
- `website_id`
- `addresses[]` — shipping/billing addresses
- `extension_attributes.is_subscribed` — newsletter subscription

---

## Operation 3: Get Customer Order History

First resolve customer ID, then search orders by customer_id:

```bash
curl -s -g "${MAGENTO_BASE_URL}/rest/${MAGENTO_STORE_CODE:-default}/V1/orders?searchCriteria[filterGroups][0][filters][0][field]=customer_id&searchCriteria[filterGroups][0][filters][0][value]=${CUSTOMER_ID}&searchCriteria[filterGroups][0][filters][0][conditionType]=eq&searchCriteria[pageSize]=10&searchCriteria[sortOrders][0][field]=created_at&searchCriteria[sortOrders][0][direction]=DESC" \
  -H "Authorization: Bearer ${MAGENTO_ADMIN_TOKEN}" \
  -H "Content-Type: application/json"
```

---

## Operation 4: Get Customer Groups

```bash
curl -s -g "${MAGENTO_BASE_URL}/rest/${MAGENTO_STORE_CODE:-default}/V1/customerGroups/search?searchCriteria[pageSize]=50" \
  -H "Authorization: Bearer ${MAGENTO_ADMIN_TOKEN}" \
  -H "Content-Type: application/json"
```

Response: array of `{id, code, tax_class_id, tax_class_name}`. Common groups: 0=NOT LOGGED IN, 1=General, 2=Wholesale, 3=Retailer.

---

## PII Handling Rules

**Never display raw customer data without masking.** Apply these rules before showing output:

| Field | Masking rule | Example |
|-------|-------------|---------|
| `email` | First char + `***` + `@` + first char of domain + `***` + TLD | `j***@e***.com` |
| `firstname lastname` | Initials | `J. D.` |
| `telephone` | Last 4 digits only | `***1234` |
| `street` | Replace with `[REDACTED]` | — |
| DOB | Year only | `1985` |

Exception: If the user explicitly asks for full data in an admin context, provide it but note it's sensitive.

---

## Response Formatting

**Customer found:**
```
Customer #42 — J. D. (j***@e***.com)
Group: General | Website: Main Website
Account created: 2023-05-10
Addresses on file: 2
```

**Customer not found:** "No customer found with email X. Check the spelling or try searching by name."

**Order history:**
```
Last 5 orders for customer #42:
#000000001 | complete  | $125.00 | 2024-01-15
#000000002 | processing| $89.99  | 2024-02-01
```

---

## Error Handling

- **HTTP 401:** Token missing or invalid.
- **HTTP 404:** Customer ID not found.
- **Empty `items`:** No customers match. Broaden search or check spelling.

---

## Decision Table

| User says | Action |
|-----------|--------|
| "find customer [email]" | Search by email eq |
| "customer #42" / "customer id 42" | GET /customers/42 |
| "find customers named [name]" | Search by firstname/lastname like |
| "orders for [email]" | Search customers by email → get customer_id → search orders |
| "customer groups" | GET /customerGroups/search |

## User Request

$ARGUMENTS
