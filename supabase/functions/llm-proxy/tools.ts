// Read-only tool whitelist for the AI companion.
//
// SECURITY INVARIANT: every tool maps to a READ RPC or an RLS-scoped select — NEVER a
// mutation. No create_/post_/close_/approve_/disburse_/record_/update_ RPC is ever
// registered here. `runTool` rejects any name not in TOOLS (defense in depth). Tools run
// on the CALLER's RLS-scoped client, so results are already tenant-isolated.

// deno-lint-ignore no-explicit-any
type Any = any;

// Minimal shape of the Supabase client the tools need (avoids heavy Deno typings).
type Sb = {
  rpc: (fn: string, args?: Record<string, unknown>) => Promise<{ data: unknown; error: unknown }>;
  from: (table: string) => Any;
};

export interface ToolDef {
  schema: { name: string; description: string; input_schema: Record<string, unknown> };
  run: (sb: Sb, input: Record<string, unknown>) => Promise<unknown>;
}

// Strip undefined/null/"" so the RPC's own defaults apply.
function present(args: Record<string, unknown>): Record<string, unknown> {
  const out: Record<string, unknown> = {};
  for (const [k, v] of Object.entries(args)) if (v !== undefined && v !== null && v !== "") out[k] = v;
  return out;
}

function unwrap({ data, error }: { data: unknown; error: unknown }): unknown {
  if (error) throw new Error((error as { message?: string }).message ?? "rpc error");
  return data;
}

const branchProp = { branch_id: { type: "string", description: "Optional branch UUID to scope to." } };
const asOfProp = { as_of: { type: "string", description: "Optional ISO date; defaults to today." } };
const rangeProps = {
  from: { type: "string", description: "ISO date/datetime start." },
  to: { type: "string", description: "ISO date/datetime end." },
};

export const TOOLS: Record<string, ToolDef> = {
  // ---- overview / KPIs ----
  get_dashboard_summary: {
    schema: {
      name: "get_dashboard_summary",
      description:
        "Snapshot of the business right now: today's sales, cash & bank balances, receivables " +
        "and payables totals, and a profit & loss summary. Call for 'how are sales today', " +
        "'cash position', 'give me an overview'.",
      input_schema: { type: "object", properties: { ...branchProp, ...rangeProps } },
    },
    run: (sb, i) =>
      sb.rpc("dashboard_summary", present({ p_branch_id: i.branch_id, p_from: i.from, p_to: i.to })).then(unwrap),
  },

  // ---- inventory ----
  list_low_stock: {
    schema: {
      name: "list_low_stock",
      description:
        "Products at or below their reorder point (need restocking). Call for 'what's low on stock', " +
        "'what should I reorder', 'low stock'.",
      input_schema: { type: "object", properties: { ...branchProp } },
    },
    run: (sb, i) => sb.rpc("drilldown_low_stock", present({ p_branch: i.branch_id })).then(unwrap),
  },
  search_products: {
    schema: {
      name: "search_products",
      description:
        "Find products by name, SKU, or barcode. Call whenever the user names or asks about a " +
        "specific product, or to resolve a product before answering a question about it.",
      input_schema: {
        type: "object",
        properties: { query: { type: "string", description: "Search text (name, SKU, or barcode)." } },
        required: ["query"],
      },
    },
    run: (sb, i) => sb.rpc("search_products", { p_query: String(i.query ?? "") }).then(unwrap),
  },
  get_inventory_valuation: {
    schema: {
      name: "get_inventory_valuation",
      description: "Total value of stock on hand. Call for 'stock value', 'inventory worth', 'value of my inventory'.",
      input_schema: { type: "object", properties: {} },
    },
    run: (sb) => sb.rpc("report_inventory_valuation").then(unwrap),
  },
  get_product_performance: {
    schema: {
      name: "get_product_performance",
      description:
        "Per-product sales performance (units, revenue, profit). Call for 'best sellers', 'top products', " +
        "'worst performing products', 'which products make the most money'.",
      input_schema: { type: "object", properties: {} },
    },
    run: (sb) => sb.rpc("report_product_performance").then(unwrap),
  },

  // ---- sales / receivables ----
  get_daily_sales: {
    schema: {
      name: "get_daily_sales",
      description:
        "Sales totals per day over a date range (a sales trend). Call for 'sales this week', " +
        "'sales trend', 'how did sales do over the last month'.",
      input_schema: { type: "object", properties: { ...rangeProps } },
    },
    run: (sb, i) => sb.rpc("report_daily_sales", present({ p_from: i.from, p_to: i.to })).then(unwrap),
  },
  get_receivables_aging: {
    schema: {
      name: "get_receivables_aging",
      description:
        "Money customers owe us, bucketed by how overdue it is. Call for 'who owes me', " +
        "'outstanding receivables', 'overdue customers', 'accounts receivable aging'.",
      input_schema: { type: "object", properties: {} },
    },
    run: (sb) => sb.rpc("receivables_aging").then(unwrap),
  },
  find_customer: {
    schema: {
      name: "find_customer",
      description:
        "Look up a customer by name to get their id (needed before get_customer_ledger). Returns matches.",
      input_schema: {
        type: "object",
        properties: { name: { type: "string", description: "Customer name (partial ok)." } },
        required: ["name"],
      },
    },
    run: (sb, i) =>
      sb.from("customers").select("id, name").ilike("name", `%${String(i.name ?? "")}%`).limit(10).then(unwrap),
  },
  get_customer_ledger: {
    schema: {
      name: "get_customer_ledger",
      description:
        "One customer's running balance and transaction history. Needs the customer's id — call " +
        "find_customer first if you only have a name. Call for 'how much does X owe', 'X's balance'.",
      input_schema: {
        type: "object",
        properties: { customer_id: { type: "string", description: "Customer UUID." } },
        required: ["customer_id"],
      },
    },
    run: (sb, i) => sb.rpc("customer_ledger", { p_customer_id: String(i.customer_id ?? "") }).then(unwrap),
  },

  // ---- purchasing / payables ----
  get_payables_aging: {
    schema: {
      name: "get_payables_aging",
      description:
        "Money we owe suppliers, bucketed by how overdue it is. Call for 'who do I owe', " +
        "'outstanding payables', 'supplier balances due', 'accounts payable aging'.",
      input_schema: { type: "object", properties: {} },
    },
    run: (sb) => sb.rpc("payables_aging").then(unwrap),
  },
  find_supplier: {
    schema: {
      name: "find_supplier",
      description:
        "Look up a supplier by name to get their id (needed before get_supplier_ledger). Returns matches.",
      input_schema: {
        type: "object",
        properties: { name: { type: "string", description: "Supplier name (partial ok)." } },
        required: ["name"],
      },
    },
    run: (sb, i) =>
      sb.from("suppliers").select("id, name").ilike("name", `%${String(i.name ?? "")}%`).limit(10).then(unwrap),
  },
  get_supplier_ledger: {
    schema: {
      name: "get_supplier_ledger",
      description:
        "One supplier's running balance and transaction history. Needs the supplier's id — call " +
        "find_supplier first if you only have a name. Call for 'how much do I owe supplier X'.",
      input_schema: {
        type: "object",
        properties: { supplier_id: { type: "string", description: "Supplier UUID." } },
        required: ["supplier_id"],
      },
    },
    run: (sb, i) => sb.rpc("supplier_ledger", { p_supplier_id: String(i.supplier_id ?? "") }).then(unwrap),
  },

  // ---- accounting / financial statements ----
  get_profit_loss: {
    schema: {
      name: "get_profit_loss",
      description:
        "Profit & loss (income statement) for a period. Call for 'P&L', 'profit this month', " +
        "'income statement', 'was I profitable'. Requires from and to dates.",
      input_schema: {
        type: "object",
        properties: { ...rangeProps, ...branchProp },
        required: ["from", "to"],
      },
    },
    run: (sb, i) =>
      sb.rpc("profit_loss", present({ p_from: i.from, p_to: i.to, p_branch_id: i.branch_id })).then(unwrap),
  },
  get_trial_balance: {
    schema: {
      name: "get_trial_balance",
      description: "Trial balance as of a date. Call for 'trial balance', 'account balances', 'TB'.",
      input_schema: { type: "object", properties: { ...asOfProp, ...branchProp } },
    },
    run: (sb, i) => sb.rpc("trial_balance", present({ p_as_of: i.as_of, p_branch_id: i.branch_id })).then(unwrap),
  },
  get_balance_sheet: {
    schema: {
      name: "get_balance_sheet",
      description:
        "Balance sheet (assets, liabilities, equity) as of a date. Call for 'balance sheet', " +
        "'what are my assets and liabilities', 'net worth of the business'.",
      input_schema: { type: "object", properties: { ...asOfProp, ...branchProp } },
    },
    run: (sb, i) => sb.rpc("balance_sheet", present({ p_as_of: i.as_of, p_branch_id: i.branch_id })).then(unwrap),
  },
};

// OpenAI function tools for the request (stable insertion order). OpenAI takes standard
// JSON Schema for `parameters`, which is exactly our `input_schema` — no conversion needed.
export function openaiTools(): Record<string, unknown>[] {
  return Object.values(TOOLS).map((t) => ({
    type: "function",
    function: {
      name: t.schema.name,
      description: t.schema.description,
      parameters: t.schema.input_schema,
    },
  }));
}

export async function runTool(sb: Sb, name: string, input: Record<string, unknown>): Promise<unknown> {
  const tool = TOOLS[name];
  if (!tool) throw new Error(`unknown tool: ${name}`); // never dispatch an unregistered name
  return await tool.run(sb, input ?? {});
}
