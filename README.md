# Magento Claude Skills

Claude Code skills for interacting with Magento 2 / Adobe Commerce stores directly via REST and GraphQL — no MCP server required.

Each skill gives Claude exact API call patterns, authentication headers, endpoint URLs, and error handling for a specific Magento domain. Claude calls your store's APIs directly using `curl`. No intermediate service, no extra process to run.

## Skills

| Skill | `/command` | Transport | What it does |
|-------|-----------|-----------|--------------|
| `magento-connect` | `/magento-connect` | GraphQL + REST | Verify store connectivity, show config |
| `magento-products` | `/magento-products` | GraphQL | Search catalog, product detail, categories, facets |
| `magento-orders` | `/magento-orders` | REST admin | Orders, tracking, analytics, abandoned carts |
| `magento-fulfillment` | `/magento-fulfillment` | REST admin | Invoices, shipments, credit memos, returns, email |
| `magento-customers` | `/magento-customers` | REST admin | Customer search, detail, order history |
| `magento-inventory` | `/magento-inventory` | REST admin | Salable qty, source items, bulk updates |
| `magento-product-admin` | `/magento-product-admin` | REST admin | Product search/update, EAV attribute resolution |
| `magento-content` | `/magento-content` | GraphQL + REST | CMS pages, policy pages, blocks |
| `magento-promotions` | `/magento-promotions` | REST admin | Sales rules, coupon search, coupon generation |
| `magento-api` | _(background)_ | — | API reference, loaded automatically |

## Prerequisites

- [Claude Code](https://code.claude.com) installed
- `curl` and `jq` available in your shell
- A Magento 2 or Adobe Commerce store (2.3+)
- An integration token for admin operations ([how to create one](#creating-an-integration-token))

## Quick Start

### Option A — `--add-dir` (recommended, no copying)

Clone once, point Claude at the repo:

```bash
git clone https://github.com/magendooroo/magento-claude-skills.git ~/magento-claude-skills
```

Set your environment variables:
```bash
export MAGENTO_BASE_URL=https://your-store.example.com
export MAGENTO_ADMIN_TOKEN=your-integration-token
```

Start Claude Code with the skills directory added:
```bash
claude --add-dir ~/magento-claude-skills
```

Skills are available immediately. Ask Claude about orders, inventory, products — it will use the right skill automatically. Or invoke directly: `/magento-orders recent orders`.

### Option B — Install to personal skills (available in all projects)

```bash
git clone https://github.com/magendooroo/magento-claude-skills.git
cd magento-claude-skills
./install.sh
```

Skills are copied to `~/.claude/skills/` and are available in every Claude Code session.

### Option C — Install to a project

Inside your project directory:

```bash
./install.sh --project
```

Skills are copied to `.claude/skills/` in your current project.

## Configuration

Two environment variables are required for admin operations:

| Variable | Required | Description |
|----------|----------|-------------|
| `MAGENTO_BASE_URL` | Yes | Store base URL, no trailing slash. Example: `https://shop.example.com` |
| `MAGENTO_ADMIN_TOKEN` | Yes (admin skills) | Integration Bearer token — see below |
| `MAGENTO_STORE_CODE` | No | Store view code, defaults to `default` |

Set them in your shell profile or pass them when starting Claude:
```bash
export MAGENTO_BASE_URL=https://shop.example.com
export MAGENTO_ADMIN_TOKEN=abc123xyz...
claude --add-dir ~/magento-claude-skills
```

### Creating an Integration Token

In Magento Admin: **System → Extensions → Integrations → Add New Integration**

1. Give it a name (e.g. "Claude Skills")
2. Under **API** tab, select all resources (or scope to what you need)
3. Save → Activate → Copy the **Access Token**

Then enable Bearer token mode (required in Magento 2.4+):
```bash
bin/magento config:set oauth/consumer/enable_integration_as_bearer 1
bin/magento cache:flush config
```

Or in Admin: **Stores → Configuration → Services → OAuth → Allow OAuth Access Tokens to be used as standalone Bearer tokens → Yes**

## Usage Examples

Once skills are loaded and env vars are set, ask Claude naturally:

```
Show me the last 10 orders
```
```
Is SKU WS03-XS-Red in stock?
```
```
Find orders for customer john@example.com
```
```
What is the return policy?
```
```
Search for products matching "yoga pants" under $50
```
```
Show revenue for this month
```
```
Generate 5 coupons for rule #4
```

Or invoke directly with `/skill-name [arguments]`:
```
/magento-orders recent orders
/magento-inventory check WS03-XS-Red
/magento-promotions active rules
```

### Write Operations

Skills that modify data (cancel order, update inventory, generate coupons, etc.) always ask for confirmation before executing. Claude will tell you exactly what it's about to do and wait for your approval.

## How It Works

These skills teach Claude the exact API patterns so it never guesses:

- **Exact `curl` commands** with correct headers, URL encoding, and `-g` flag for `searchCriteria` brackets
- **Decision tables** — maps natural language to the right operation
- **Error handling** — known Magento error messages and their fixes documented in the skill
- **PII masking rules** — customer data is masked before display
- **Confirmation patterns** — write operations require explicit user approval

This is the same information encoded in [MageMCP](https://github.com/magendooroo/magemcp), but as Claude Code skills instead of an MCP server. Skills are Claude Code-only; MageMCP works with any MCP-compatible client.

## Updating

```bash
cd ~/magento-claude-skills
git pull
```

If you used `--add-dir`, changes take effect in the next Claude Code session. If you used `install.sh`, re-run it to update the copies.

## Troubleshooting

**Skills not appearing:** Run `/magento-connect check` to verify Claude can see the skills.

**HTTP 401 on admin endpoints:** Token is invalid or Bearer mode is not enabled. See [Creating an Integration Token](#creating-an-integration-token).

**`/V1/inventory/get-product-salable-qty` returns 404:** MSI salable-qty API not available on this store. The `magento-inventory` skill falls back to source items and legacy stock automatically.

**`curl` bracket errors:** All searchCriteria calls use `curl -g` to disable glob expansion. If you see errors about `[` or `]`, check your curl version.

**"Request does not match any route":** The store code in the URL doesn't exist. Check `MAGENTO_STORE_CODE` or use `default`.

## License

MIT — see [LICENSE](LICENSE)
