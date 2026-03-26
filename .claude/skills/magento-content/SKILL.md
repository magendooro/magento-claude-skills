---
name: magento-content
description: Read and manage Magento CMS pages and blocks via GraphQL (storefront) and admin REST API. Covers policy pages, store content, page search, and page updates. Use for 'what is your return policy', 'show shipping info', or any CMS content question.
argument-hint: "[page identifier, 'returns policy', 'shipping', 'search <term>', or 'update <id>']"
allowed-tools: Bash(curl:*), Bash(echo:*), Bash(jq:*), Bash(python3:*)
effort: medium
---

# Magento CMS Content (GraphQL + REST)

Two surfaces: GraphQL for public storefront content (no auth), REST for admin management.

## Configuration

- **GraphQL:** `${MAGENTO_BASE_URL}/graphql` — no auth required
- **REST Base:** `${MAGENTO_BASE_URL}/rest/${MAGENTO_STORE_CODE:-default}/V1/`
- **REST Auth:** `Authorization: Bearer ${MAGENTO_ADMIN_TOKEN}`

---

## Common Policy Page Identifiers

| Page | URL identifier |
|------|---------------|
| Returns / Refunds | `returns` or `return-policy` or `refund-policy` |
| Shipping | `shipping` or `shipping-policy` |
| Privacy Policy | `privacy-policy-cookie-restriction-mode` or `privacy-policy` |
| About Us | `about-us` |
| Contact | `contact` |
| FAQ | `faq` |

Identifiers are store-specific. Use Operation 2 (Search) to discover the correct identifier for unknown pages.

---

## Operation 1: Get CMS Page by Identifier (GraphQL — No Auth)

The fastest way to get a public-facing policy or content page.

```bash
curl -s -X POST "${MAGENTO_BASE_URL}/graphql" \
  -H "Content-Type: application/json" \
  -H "Store: ${MAGENTO_STORE_CODE:-default}" \
  -d '{"query": "{ cmsPage(identifier: \"returns\") { title content_heading content meta_title meta_description } }"}'
```

If the page is not found, response will have `"cmsPage": null`.

**Try common identifiers automatically** if the first one returns null:
```bash
for id in returns return-policy returns-policy refunds; do
  result=$(curl -s -X POST "${MAGENTO_BASE_URL}/graphql" \
    -H "Content-Type: application/json" \
    -H "Store: ${MAGENTO_STORE_CODE:-default}" \
    -d "{\"query\": \"{ cmsPage(identifier: \\\"${id}\\\") { title content } }\"}")
  title=$(echo "$result" | jq -r '.data.cmsPage.title // empty')
  if [ -n "$title" ]; then
    echo "Found: $title (identifier: $id)"
    echo "$result" | jq -r '.data.cmsPage.content' | sed 's/<[^>]*>//g'
    break
  fi
done
```

---

## Operation 2: Search CMS Pages (Admin REST)

Finds pages with their IDs, which are needed for updates.

```bash
# Search by title
curl -s -g "${MAGENTO_BASE_URL}/rest/${MAGENTO_STORE_CODE:-default}/V1/cmsPage/search?searchCriteria[filterGroups][0][filters][0][field]=title&searchCriteria[filterGroups][0][filters][0][value]=%return%&searchCriteria[filterGroups][0][filters][0][conditionType]=like&searchCriteria[pageSize]=20" \
  -H "Authorization: Bearer ${MAGENTO_ADMIN_TOKEN}" \
  -H "Content-Type: application/json"
```

**Common filters:**

| What | Field | Condition |
|------|-------|-----------|
| Title contains | `title` | `like` |
| URL key | `identifier` | `like` or `eq` |
| Active pages | `is_active` | `eq` (1=active, 0=inactive) |
| Store view | `store_id` | `eq` (0=all stores, 1=default) |

**Extract:** `page_id`, `title`, `identifier`, `is_active`, `creation_time`, `update_time`

---

## Operation 3: Get CMS Page by ID (Admin REST — includes full content)

```bash
curl -s "${MAGENTO_BASE_URL}/rest/${MAGENTO_STORE_CODE:-default}/V1/cmsPage/${PAGE_ID}" \
  -H "Authorization: Bearer ${MAGENTO_ADMIN_TOKEN}" \
  -H "Content-Type: application/json"
```

**Extract:** `page_id`, `title`, `identifier`, `content`, `content_heading`, `is_active`, `meta_title`, `meta_description`, `meta_keywords`, `sort_order`

---

## Operation 4: Get CMS Blocks (GraphQL — No Auth)

CMS blocks are reusable content snippets (banners, footer content, etc.).

```bash
curl -s -X POST "${MAGENTO_BASE_URL}/graphql" \
  -H "Content-Type: application/json" \
  -H "Store: ${MAGENTO_STORE_CODE:-default}" \
  -d '{"query": "{ cmsBlocks(identifiers: [\"contact-us-info\"]) { items { identifier title content } } }"}'
```

---

## Operation 5: Search CMS Blocks (Admin REST)

```bash
curl -s -g "${MAGENTO_BASE_URL}/rest/${MAGENTO_STORE_CODE:-default}/V1/cmsBlock/search?searchCriteria[filterGroups][0][filters][0][field]=title&searchCriteria[filterGroups][0][filters][0][value]=%footer%&searchCriteria[filterGroups][0][filters][0][conditionType]=like&searchCriteria[pageSize]=20" \
  -H "Authorization: Bearer ${MAGENTO_ADMIN_TOKEN}" \
  -H "Content-Type: application/json"
```

**Extract:** `block_id`, `identifier`, `title`, `is_active`

---

## Operation 6: Update CMS Page (Write — Confirm First)

**Confirm:** "I'll update the `${PAGE_TITLE}` page (ID: ${PAGE_ID}). Changes: [describe]. Confirm? (yes/no)"

```bash
# Use jq to safely build JSON — prevents injection from non-integer PAGE_ID
curl -s -X PUT "${MAGENTO_BASE_URL}/rest/${MAGENTO_STORE_CODE:-default}/V1/cmsPage/${PAGE_ID}" \
  -H "Authorization: Bearer ${MAGENTO_ADMIN_TOKEN}" \
  -H "Content-Type: application/json" \
  -d "$(jq -n \
    --argjson id "${PAGE_ID}" \
    --arg title "Returns Policy" \
    --arg content "<p>Updated return policy content here.</p>" \
    '{"page": {"id": $id, "title": $title, "content": $content, "is_active": 1}}')"
```

**Notes:**
- Always include `"id"` in the body — it must match the URL parameter.
- `content` supports HTML. Magento uses PageBuilder widgets — preserve existing widget markup when doing partial updates.
- After update, flush cache: run `bin/magento cache:flush full_page block_html` on the server (or instruct the admin to flush from Admin > System > Cache Management).
- For large content changes, **read the current content first** (Op 3) to avoid overwriting existing sections.

---

## Response Formatting

**Page content (strip HTML for display):**
```
Page: Returns Policy
Identifier: returns
Last updated: 2024-01-10

[Content with HTML tags stripped]
```

To strip HTML in bash:
```bash
echo "$CONTENT" | sed 's/<[^>]*>//g' | sed '/^[[:space:]]*$/d'
```

Or with python3:
```bash
echo "$CONTENT" | python3 -c "import sys, html; from html.parser import HTMLParser
class S(HTMLParser):
    def handle_data(self, d): print(d, end='')
S().feed(sys.stdin.read())"
```

---

## Error Handling

- **`"cmsPage": null` in GraphQL:** Page identifier doesn't exist. Try alternatives or use REST search.
- **HTTP 404 on REST get:** Page ID not found.
- **Content looks garbled after update:** May have wiped PageBuilder widget markup. Always read before write.
- **Cache stale after update:** Instruct user to flush cache from Admin or CLI.

---

## Decision Table

| User says | Action |
|-----------|--------|
| "what is the return/refund policy?" | Op 1 with common identifiers |
| "show shipping policy" | Op 1 with `shipping` / `shipping-policy` |
| "find the privacy page" | Op 2 search by title `%privacy%` |
| "get all active CMS pages" | Op 2 with `is_active eq 1` |
| "update the returns page" | Op 3 to read → Confirm → Op 6 to write |
| "find footer block" | Op 5 search by title `%footer%` |

## User Request

$ARGUMENTS
