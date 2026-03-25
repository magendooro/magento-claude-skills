# Magento Claude Skills

> **For store operators.** Ask Claude about your Magento store in plain language — look up orders, check inventory, manage customers, update products, and run reports. Claude calls your store's REST and GraphQL APIs directly using `curl`. No server to run, no extra process, no MCP client to configure.

---

## Who this is for

**Store operators, merchants, and support agents** who want to interact with a live Magento 2 / Adobe Commerce store through Claude Code.

| Role | Example tasks |
|------|--------------|
| Support agent | "Find order #000012345 for roni_cost@example.com and check if it has shipped" |
| Operations manager | "Show me all orders over €200 placed in the last 7 days that are still pending" |
| Merchandiser | "Set the special price of SKU WS03-XS-Red to €24.99" |
| Store manager | "How much revenue did we generate this month, excluding canceled orders?" |
| Marketing | "Generate 20 unique coupon codes for the Summer Sale rule, valid through July 31" |
| Support agent | "What is the store's return policy?" |

> **Not for Magento PHP developers** writing modules, themes, or code. For that, see [hyva-themes/hyva-ai-tools](https://github.com/hyva-themes/hyva-ai-tools) (Hyva frontend development) or [rubenzantingh/claude-code-magento-agents](https://github.com/rubenzantingh/claude-code-magento-agents) (general Magento development).

---

## Skills

| Skill | `/command` | What it does |
|-------|-----------|--------------|
| `magento-connect` | `/magento-connect` | Verify store connectivity, show store config |
| `magento-products` | `/magento-products` | Search catalog by text, category, price, attributes — with facets |
| `magento-orders` | `/magento-orders` | Orders, tracking, analytics, abandoned carts |
| `magento-fulfillment` | `/magento-fulfillment` | Invoices, shipments, credit memos, returns, email |
| `magento-customers` | `/magento-customers` | Customer search, detail, order history |
| `magento-inventory` | `/magento-inventory` | Salable qty, source items (MSI), bulk updates |
| `magento-product-admin` | `/magento-product-admin` | Product search, update price/status, EAV attribute resolution |
| `magento-content` | `/magento-content` | CMS pages — return policy, shipping info, any policy page |
| `magento-promotions` | `/magento-promotions` | Sales rules, coupon search, coupon generation |
| `magento-api` | _(background)_ | REST/GraphQL reference — loaded automatically when needed |

All read operations work out of the box. Write operations (cancel order, update inventory, generate coupons, etc.) ask for confirmation before executing.

---

## Prerequisites

- [Claude Code](https://code.claude.com) installed
- `curl` and `jq` in your `PATH`
- Magento 2.3+ or Adobe Commerce, reachable over HTTPS
- An integration token for admin operations ([how to create one](#creating-an-integration-token))

---

## Quick Start

### Option A — `--add-dir` (recommended, nothing to copy)

```bash
git clone https://github.com/magendooro/magento-claude-skills.git ~/magento-claude-skills

export MAGENTO_BASE_URL=https://your-store.example.com
export MAGENTO_ADMIN_TOKEN=your-integration-token

claude --add-dir ~/magento-claude-skills
```

Claude picks up the skills automatically. Ask naturally or invoke directly:

```
Show me the last 10 orders
/magento-inventory check WS03-XS-Red
```

### Option B — Install to personal skills (all projects)

```bash
git clone https://github.com/magendooro/magento-claude-skills.git
cd magento-claude-skills && ./install.sh
```

Copies skills to `~/.claude/skills/`. Available in every Claude Code session without `--add-dir`.

### Option C — Install to a specific project

```bash
./install.sh --project
```

Copies to `./.claude/skills/` in the current directory only.

---

## Configuration

| Variable | Required | Description |
|----------|----------|-------------|
| `MAGENTO_BASE_URL` | Yes | Store base URL, no trailing slash. Example: `https://shop.example.com` |
| `MAGENTO_ADMIN_TOKEN` | Yes (admin skills) | Integration Bearer token |
| `MAGENTO_STORE_CODE` | No | Store view code, default: `default` |

### Creating an Integration Token

In Magento Admin: **System → Extensions → Integrations → Add New Integration**

1. Give it a name (e.g. "Claude Skills")
2. **API** tab → select all resources (or scope to what you need)
3. Save → Activate → copy the **Access Token**

Enable Bearer token mode (required in Magento 2.4+):

```bash
bin/magento config:set oauth/consumer/enable_integration_as_bearer 1
bin/magento cache:flush config
```

Or in Admin: **Stores → Configuration → Services → OAuth → Allow OAuth Access Tokens to be used as standalone Bearer tokens → Yes**

---

## Usage Examples

### Support — order lookup and tracking

```
Find order #000000042
Has order 42 shipped? What's the tracking number?
Show all orders for roni_cost@example.com
```

### Operations — reporting and filtering

```
Show me pending orders from the last 24 hours
What is the revenue for March 2026, excluding canceled orders?
List high-value abandoned carts over €150
```

### Catalog and inventory

```
Search for products matching "yoga pants" priced under $50
Is SKU WS03-XS-Red in stock? How many units?
Set the special price of WS03-XS-Red to €24.99
```

### Content and promotions

```
What is the store's return policy?
Show all active promotions
Generate 10 coupon codes for the Summer Sale discount rule
```

### Write operations

All changes require confirmation. Claude shows exactly what it will do and waits:

```
> Cancel order #000000042

I'll cancel order #000000042 (Veronica Costello, €36.39, status: processing).
This cannot be undone if the order has been invoiced. Confirm? (yes/no)
```

---

## How It Works

Each skill contains exact API patterns, so Claude never guesses:

- **Exact `curl` commands** — correct headers, `-g` flag for `searchCriteria` brackets, URL encoding
- **Decision tables** — maps natural language requests to the right API operation
- **Error docs** — known Magento error messages with explanations and fixes
- **PII masking** — emails and addresses masked before display (`r***@e***.com`)
- **Confirmation gates** — all write operations pause for approval

### Why skills produce more accurate results than an MCP server

**Magento's API has many non-obvious traps.** Claude's general training knowledge covers the official docs but not the gotchas: the `searchCriteria[filterGroups][0][filters][0][field]=` bracket syntax that breaks with shell glob expansion, EAV attributes storing integer option IDs instead of labels, the Bearer token setting that's off by default in Magento 2.4+, `/order/{id}/ship` versus `/shipment` (the latter creates duplicates), and more. Skills document every pitfall explicitly. Claude copies known-good patterns rather than generating from approximate recall.

**Fewer tokens per operation.** MCP tool calls carry protocol overhead — JSON-RPC envelopes, input schema validation, output wrapping, tool listing on session start. With skills, the relevant patterns are already in context and Claude executes `curl` directly. No schema parsing, no tool-call envelope.

**Fewer network roundtrips.** An MCP server running over HTTP adds a full hop for every operation: Claude → MCP server → Magento (two network calls per tool call). Skills call Magento directly — one hop. Multi-step operations (e.g., find order → check shipment → get tracking) can be chained in a single bash execution rather than N sequential tool calls.

Internally, skills use Magento's public GraphQL endpoint (storefront reads, no token) and the admin REST API (`/rest/{store_code}/V1/...`, Bearer token). The same API knowledge is encoded in [MageMCP](https://github.com/magendooro/magemcp) as a Python MCP server — use MageMCP if you need to connect AI agents other than Claude Code.

---

## Updating

```bash
cd ~/magento-claude-skills && git pull
# If you used install.sh, re-run it to update copies:
./install.sh
```

---

## Troubleshooting

| Symptom | Fix |
|---------|-----|
| Skills don't appear | Run `/magento-connect check` |
| HTTP 401 on admin calls | Bearer token mode not enabled — see [Integration Token](#creating-an-integration-token) |
| `get-product-salable-qty` returns 404 | MSI salable-qty API unavailable; skill falls back to source items automatically |
| `[` or `]` errors in curl | All calls use `curl -g` — check curl version |
| "Request does not match any route" | Wrong `MAGENTO_STORE_CODE` — use `default` |

---

## License

MIT — see [LICENSE](LICENSE)
