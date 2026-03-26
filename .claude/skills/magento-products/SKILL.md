---
name: magento-products
description: Search and explore Magento product catalog via GraphQL. Supports text search, category/price/attribute filters, aggregations (faceted search), and full product detail by SKU. Use for any product-related question.
argument-hint: "[search query or SKU]"
allowed-tools: Bash(curl:*), Bash(echo:*), Bash(jq:*), Bash(python3:*)
effort: high
---

# Magento Product Search (GraphQL)

Search the Magento 2 storefront catalog using GraphQL. This skill calls the `/graphql` endpoint directly — no MCP server needed.

## Configuration

- **Endpoint:** `${MAGENTO_BASE_URL}/graphql`
- **Auth:** None required (storefront/public). Optional customer token via `Authorization: Bearer <token>` header.
- **Store scope:** `Store: ${MAGENTO_STORE_CODE:-default}` header.

## How to Execute Queries

All queries use this curl pattern:

```bash
curl -s -X POST "${MAGENTO_BASE_URL}/graphql" \
  -H "Content-Type: application/json" \
  -H "Store: ${MAGENTO_STORE_CODE:-default}" \
  -d '<JSON_BODY>'
```

Where `<JSON_BODY>` is `{"query": "...", "variables": {...}}`.

**Important:** Always use `jq` to parse output if installed, or `python3 -m json.tool` for formatting. Check if `jq` is available: `which jq 2>/dev/null`.

---

## Query 1: Product Search

Use this when the user asks to search, find, list, or browse products.

### Full Query with Aggregations

```graphql
query SearchProducts(
  $search: String
  $filter: ProductAttributeFilterInput
  $sort: ProductAttributeSortInput
  $pageSize: Int!
  $currentPage: Int!
) {
  products(
    search: $search
    filter: $filter
    sort: $sort
    pageSize: $pageSize
    currentPage: $currentPage
  ) {
    items {
      sku
      name
      url_key
      stock_status
      __typename
      price_range {
        minimum_price {
          regular_price { value currency }
          final_price { value currency }
          discount { amount_off percent_off }
        }
        maximum_price {
          regular_price { value currency }
          final_price { value currency }
        }
      }
      small_image { url label }
      short_description { html }
    }
    total_count
    page_info {
      current_page
      page_size
      total_pages
    }
    aggregations {
      attribute_code
      label
      count
      options {
        label
        value
        count
      }
    }
  }
}
```

### Variables

```json
{
  "search": "yoga pants",
  "filter": {
    "category_id": { "eq": "15" },
    "price": { "from": "20", "to": "100" }
  },
  "sort": { "price": "ASC" },
  "pageSize": 10,
  "currentPage": 1
}
```

### Filter Reference — ProductAttributeFilterInput

| Filter | Type | Operators | Example |
|--------|------|-----------|---------|
| `category_id` | FilterEqualTypeInput | `eq`, `in` | `{"eq": "15"}` or `{"in": ["15","20"]}` |
| `name` | FilterMatchTypeInput | `match` | `{"match": "jacket"}` |
| `sku` | FilterEqualTypeInput | `eq`, `in` | `{"eq": "WJ12"}` or `{"in": ["WJ12","WJ13"]}` |
| `price` | FilterRangeTypeInput | `from`, `to` | `{"from": "50", "to": "150"}` |
| `url_key` | FilterEqualTypeInput | `eq` | `{"eq": "stellar-jacket"}` |
| `category_url_key` | FilterEqualTypeInput | `eq` | `{"eq": "tops"}` |

**Custom attributes** (color, size, brand, etc.) can also be used as filters if indexed for search:
```json
{ "filter": { "color": { "eq": "49" }, "size": { "in": ["167", "168"] } } }
```
(Use aggregation option `value` fields for the correct IDs.)

### Sort Reference — ProductAttributeSortInput

| Field | Direction | Notes |
|-------|-----------|-------|
| `relevance` | — | **Default when search term present.** Omit sort variable entirely. |
| `name` | `ASC` / `DESC` | Alphabetical |
| `price` | `ASC` / `DESC` | By final price |
| `position` | `ASC` / `DESC` | Category display position |

**Usage:** `"sort": { "price": "DESC" }`. Only one field at a time.
**When using text search without explicit sort:** omit the `sort` variable — Magento uses relevance automatically.

### Pagination

- `pageSize`: 1–50 (default 20)
- `currentPage`: 1-indexed (default 1)
- Response `page_info.total_pages` tells you how many pages exist.

### Aggregations (Faceted Search)

When `aggregations` is included in the query, Magento returns available filters based on the current result set. This is the same as "layered navigation" in the storefront.

Example response:
```json
{
  "aggregations": [
    {
      "attribute_code": "price",
      "label": "Price",
      "count": 5,
      "options": [
        { "label": "20-30", "value": "20_30", "count": 12 },
        { "label": "30-40", "value": "30_40", "count": 8 }
      ]
    },
    {
      "attribute_code": "color",
      "label": "Color",
      "count": 4,
      "options": [
        { "label": "Blue", "value": "49", "count": 15 },
        { "label": "Red", "value": "58", "count": 9 }
      ]
    },
    {
      "attribute_code": "size",
      "label": "Size",
      "count": 5,
      "options": [
        { "label": "XS", "value": "166", "count": 20 },
        { "label": "S", "value": "167", "count": 18 }
      ]
    },
    {
      "attribute_code": "category_id",
      "label": "Category",
      "count": 3,
      "options": [
        { "label": "Tops", "value": "21", "count": 50 },
        { "label": "Bottoms", "value": "22", "count": 25 }
      ]
    }
  ]
}
```

**Key usage pattern:**
1. Run initial search → get aggregations
2. Show user available filters (e.g., "Available colors: Blue (15), Red (9)")
3. Use aggregation `value` to add filter: `"color": {"eq": "49"}`
4. Re-search with filter → get refined aggregations

### Practical Examples

**Simple text search:**
```bash
curl -s -X POST "${MAGENTO_BASE_URL}/graphql" \
  -H "Content-Type: application/json" \
  -H "Store: ${MAGENTO_STORE_CODE:-default}" \
  -d '{"query":"{ products(search: \"yoga\", pageSize: 5) { items { sku name stock_status price_range { minimum_price { final_price { value currency } } } } total_count aggregations { attribute_code label options { label value count } } } }"}'
```

**Category browse with aggregations (no search term):**
```bash
curl -s -X POST "${MAGENTO_BASE_URL}/graphql" \
  -H "Content-Type: application/json" \
  -H "Store: ${MAGENTO_STORE_CODE:-default}" \
  -d '{"query":"{ products(filter: { category_id: { eq: \"21\" } }, pageSize: 10, currentPage: 1) { items { sku name stock_status price_range { minimum_price { final_price { value currency } } } } total_count page_info { total_pages } aggregations { attribute_code label options { label value count } } } }"}'
```

**Price range + in-stock only:**
Note: Magento GraphQL doesn't have a direct `stock_status` filter in the standard `ProductAttributeFilterInput`. Instead, filter client-side from the `stock_status` field on each item. Alternatively, use the admin REST endpoint for stock-aware searches.

---

## Query 2: Product Detail by SKU

Use this when the user asks about a specific product, wants full details, images, or variant options.

### Full Query

```graphql
query GetProduct($sku: String!) {
  products(filter: { sku: { eq: $sku } }) {
    items {
      sku
      name
      url_key
      meta_title
      meta_description
      stock_status
      __typename
      description { html }
      short_description { html }
      price_range {
        minimum_price {
          regular_price { value currency }
          final_price { value currency }
          discount { amount_off percent_off }
        }
        maximum_price {
          regular_price { value currency }
          final_price { value currency }
        }
      }
      media_gallery {
        url
        label
        position
        disabled
      }
      categories {
        id
        name
        url_path
        breadcrumbs {
          category_id
          category_name
          category_url_path
        }
      }
      ... on ConfigurableProduct {
        configurable_options {
          attribute_code
          label
          values { label value_index }
        }
      }
    }
  }
}
```

### Practical Example

```bash
curl -s -X POST "${MAGENTO_BASE_URL}/graphql" \
  -H "Content-Type: application/json" \
  -H "Store: ${MAGENTO_STORE_CODE:-default}" \
  -d '{"query":"{ products(filter: { sku: { eq: \"WS03\" } }) { items { sku name __typename stock_status description { html } price_range { minimum_price { regular_price { value currency } final_price { value currency } discount { percent_off } } } media_gallery { url label position disabled } categories { name url_path } ... on ConfigurableProduct { configurable_options { attribute_code label values { label value_index } } } } } }"}'
```

---

## Query 3: Category Tree

Use this when the user asks about categories, navigation, or site structure.

```bash
curl -s -X POST "${MAGENTO_BASE_URL}/graphql" \
  -H "Content-Type: application/json" \
  -H "Store: ${MAGENTO_STORE_CODE:-default}" \
  -d '{"query":"{ categories(filters: {}) { items { id name url_path product_count children { id name url_path product_count children { id name url_path product_count } } } } }"}'
```

---

## Response Formatting

When presenting results to the user:

1. **Search results:** Show as a numbered list with SKU, name, price (final), stock status. If there's a discount, show it.
2. **Aggregations:** Present as "Available filters" with counts — help the user narrow down.
3. **Product detail:** Show name, price, stock, description (strip HTML tags — remove `<p>`, `<br>`, etc.), images (just URLs), categories, and variant options.
4. **Pagination:** Always show "Page X of Y (Z total products)" and offer to show next page.

## Error Handling

- **HTTP 200 but `errors` key in response:** Magento GraphQL error. Show the error message — common: "Field X not found", "Variable $x not provided".
- **HTTP 403:** Store might require HTTPS or has CORS restrictions.
- **Empty `items`:** No products match the criteria. Suggest broadening the search.
- **`MAGENTO_BASE_URL` not set:** Tell the user to set the env var.

## Deciding What to Do

Given the user's request (`$ARGUMENTS`), decide:

| User says | Action |
|-----------|--------|
| A search term ("yoga pants", "red jacket") | Text search with aggregations |
| A SKU ("WS03", "MH01-XS-Black") | Product detail by SKU |
| "categories" / "what categories" | Category tree query |
| "products in [category]" | Category filter search |
| "products under $50" | Price range filter |
| "show me the filters for [search]" | Run search, present aggregations prominently |
| "page 2" / "next page" | Re-run previous search with `currentPage: 2` |

When in doubt, run a search with aggregations — aggregations give the user refinement options.

## User Request

$ARGUMENTS
