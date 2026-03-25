---
name: magento-connect
description: Test Magento connectivity and show store configuration. Use when setting up or verifying the Magento connection.
argument-hint: "[check|status]"
allowed-tools: Bash(curl:*)
---

# Magento Connection Check

Test connectivity to a Magento 2 instance and display store configuration.

## Required Environment Variables

| Variable | Purpose | Example |
|----------|---------|---------|
| `MAGENTO_BASE_URL` | Magento base URL (no trailing slash) | `https://m248.magendoo.ro` |
| `MAGENTO_ADMIN_TOKEN` | Integration Bearer token for admin REST API | `53u9t46do...` |
| `MAGENTO_STORE_CODE` | Store view code (optional, defaults to `default`) | `default` |

## Step 1: Check environment variables

Verify all required env vars are set. If missing, tell the user what to set and how:
```bash
echo "MAGENTO_BASE_URL=${MAGENTO_BASE_URL:-NOT SET}"
echo "MAGENTO_ADMIN_TOKEN=${MAGENTO_ADMIN_TOKEN:+SET (${#MAGENTO_ADMIN_TOKEN} chars)}"
echo "MAGENTO_STORE_CODE=${MAGENTO_STORE_CODE:-default}"
```

If `MAGENTO_BASE_URL` is not set, stop and ask the user to set it:
```bash
export MAGENTO_BASE_URL=https://your-store.example.com
export MAGENTO_ADMIN_TOKEN=your-token-here
```

## Step 2: Test GraphQL (storefront)

```bash
curl -s --max-time 10 -w "\nHTTP_STATUS:%{http_code}" \
  -X POST "${MAGENTO_BASE_URL}/graphql" \
  -H "Content-Type: application/json" \
  -H "Store: ${MAGENTO_STORE_CODE:-default}" \
  -d '{"query":"{ storeConfig { store_code store_name locale base_currency_code default_display_currency_code timezone base_url base_media_url } }"}'
```

Parse the JSON response. Show: store name, currency, locale, timezone, base URL.

## Step 3: Test REST (admin)

```bash
curl -s --max-time 10 -g -w "\nHTTP_STATUS:%{http_code}" \
  "${MAGENTO_BASE_URL}/rest/${MAGENTO_STORE_CODE:-default}/V1/store/storeConfigs" \
  -H "Authorization: Bearer ${MAGENTO_ADMIN_TOKEN}" \
  -H "Content-Type: application/json"
```

If HTTP 200: admin token is valid. Show store view count.
If HTTP 401: token is invalid or `oauth/consumer/enable_integration_as_bearer` is not set to Yes.

## Step 4: Summary

Report connectivity status:
- GraphQL: OK/FAIL
- REST Admin: OK/FAIL
- Store: name, code, currency, timezone
- Base URL confirmed
