---
name: magento-api
description: Quick reference for Magento 2 REST and GraphQL API endpoints, searchCriteria syntax, and authentication patterns. Background knowledge — loaded automatically when working with Magento APIs.
user-invocable: false
allowed-tools: []
---

# Magento API Reference

Provide quick-reference Magento 2 API information relevant to the tool the user is building or asking about. If the user specifies a domain (products, orders, customers, inventory, etc.), focus on that domain.

## REST API Endpoints

### Products / Catalog

| Operation | Method | Endpoint |
|-----------|--------|----------|
| Get product by SKU | GET | `/rest/V1/products/{sku}` |
| Search products | GET | `/rest/V1/products?searchCriteria[...]` |
| Get categories | GET | `/rest/V1/categories` |
| Get category by ID | GET | `/rest/V1/categories/{id}` |
| Product attributes | GET | `/rest/V1/products/attributes/{attributeCode}` |
| Product media | GET | `/rest/V1/products/{sku}/media` |
| Configurable options | GET | `/rest/V1/configurable-products/{sku}/options/all` |

### Orders

| Operation | Method | Endpoint |
|-----------|--------|----------|
| Get order by ID | GET | `/rest/V1/orders/{id}` |
| Search orders | GET | `/rest/V1/orders?searchCriteria[...]` |
| Order items | GET | `/rest/V1/orders/items?searchCriteria[...]` |
| Order comments | GET | `/rest/V1/orders/{id}/comments` |
| Invoices | GET | `/rest/V1/invoices?searchCriteria[...]` |
| Shipments | GET | `/rest/V1/shipments?searchCriteria[...]` |
| Credit memos | GET | `/rest/V1/creditmemos?searchCriteria[...]` |

### Customers

| Operation | Method | Endpoint |
|-----------|--------|----------|
| Get customer by ID | GET | `/rest/V1/customers/{id}` |
| Search customers | GET | `/rest/V1/customers/search?searchCriteria[...]` |
| Customer groups | GET | `/rest/V1/customerGroups/search?searchCriteria[...]` |
| Customer addresses | GET | `/rest/V1/customers/{id}/billingAddress` |

### Inventory / Stock

| Operation | Method | Endpoint |
|-----------|--------|----------|
| Stock item by SKU | GET | `/rest/V1/stockItems/{sku}` |
| Source items | GET | `/rest/V1/inventory/source-items?searchCriteria[...]` |
| Stock status (MSI) | GET | `/rest/V1/inventory/get-product-salable-qty/{sku}/{stockId}` |
| Sources | GET | `/rest/V1/inventory/sources?searchCriteria[...]` |
| Stocks | GET | `/rest/V1/inventory/stocks?searchCriteria[...]` |

### CMS

| Operation | Method | Endpoint |
|-----------|--------|----------|
| CMS pages | GET | `/rest/V1/cmsPage/search?searchCriteria[...]` |
| CMS blocks | GET | `/rest/V1/cmsBlock/search?searchCriteria[...]` |

### Store / Config

| Operation | Method | Endpoint |
|-----------|--------|----------|
| Store configs | GET | `/rest/V1/store/storeConfigs` |
| Store groups | GET | `/rest/V1/store/storeGroups` |
| Websites | GET | `/rest/V1/store/websites` |
| Modules | GET | `/rest/V1/modules` |

## searchCriteria Pattern

Magento uses a standard searchCriteria query pattern for list endpoints:

```
?searchCriteria[filterGroups][0][filters][0][field]=status
&searchCriteria[filterGroups][0][filters][0][value]=processing
&searchCriteria[filterGroups][0][filters][0][conditionType]=eq
&searchCriteria[pageSize]=20
&searchCriteria[currentPage]=1
&searchCriteria[sortOrders][0][field]=created_at
&searchCriteria[sortOrders][0][direction]=DESC
```

Condition types: `eq`, `neq`, `gt`, `gteq`, `lt`, `lteq`, `like`, `in`, `notnull`, `null`, `from`, `to`.

## GraphQL Queries

### Products

```graphql
{
  products(search: "jacket", filter: { price: { from: "10", to: "100" } }, pageSize: 20) {
    items {
      sku
      name
      price_range { minimum_price { final_price { value currency } } }
      stock_status
    }
    total_count
  }
}
```

### Categories

```graphql
{
  categories(filters: { ids: { eq: "2" } }) {
    items { id name children { id name url_path } }
  }
}
```

### Customer Orders (authenticated)

```graphql
{
  customer {
    orders(filter: { number: { eq: "000000001" } }) {
      items {
        order_number
        status
        total { grand_total { value currency } }
        items { product_name quantity_ordered }
      }
    }
  }
}
```

## Authentication

- **REST**: Bearer token via `Authorization: Bearer <token>` header. Admin tokens from `POST /rest/V1/integration/admin/token`. Customer tokens from `POST /rest/V1/integration/customer/token`.
- **GraphQL**: Same bearer token in header. Customer queries require customer token. Admin-only queries (orders list, customer search) require admin token or integration token.
- **Integration tokens**: Long-lived, configured in Admin > System > Integrations. Preferred for MCP server use.

