export type InvoiceStatus = "paid" | "pending" | "overdue"

export type Invoice = {
  id: string
  number: string
  client: string
  email: string
  amount: number
  status: InvoiceStatus
  issued: string
  due: string
  /** Days overdue when status is "overdue"; 0 otherwise. */
  overdueDays: number
}

export const invoices: Invoice[] = [
  {
    id: "inv_4821",
    number: "4821",
    client: "Northwind Traders",
    email: "ap@northwind.example",
    amount: 1240.0,
    status: "overdue",
    issued: "2026-05-28",
    due: "2026-06-27",
    overdueDays: 12,
  },
  {
    id: "inv_4822",
    number: "4822",
    client: "Meridian Design Co.",
    email: "billing@meridian.example",
    amount: 3980.5,
    status: "pending",
    issued: "2026-06-14",
    due: "2026-07-14",
    overdueDays: 0,
  },
  {
    id: "inv_4823",
    number: "4823",
    client: "Larkspur Analytics",
    email: "finance@larkspur.example",
    amount: 640.0,
    status: "paid",
    issued: "2026-06-02",
    due: "2026-07-02",
    overdueDays: 0,
  },
  {
    id: "inv_4824",
    number: "4824",
    client: "Cedar & Vine Catering",
    email: "accounts@cedarvine.example",
    amount: 2150.75,
    status: "overdue",
    issued: "2026-05-10",
    due: "2026-06-09",
    overdueDays: 30,
  },
  {
    id: "inv_4825",
    number: "4825",
    client: "Halcyon Robotics",
    email: "ap@halcyon.example",
    amount: 12500.0,
    status: "pending",
    issued: "2026-06-30",
    due: "2026-07-30",
    overdueDays: 0,
  },
  {
    id: "inv_4826",
    number: "4826",
    client: "Solstice Print Studio",
    email: "hello@solstice.example",
    amount: 415.2,
    status: "paid",
    issued: "2026-05-22",
    due: "2026-06-21",
    overdueDays: 0,
  },
]

/** One month of billed revenue, for the dataviz lane. */
export type MonthlyRevenue = {
  month: string
  revenue: number
}

export const monthlyRevenue: MonthlyRevenue[] = [
  { month: "Feb", revenue: 8200 },
  { month: "Mar", revenue: 10450 },
  { month: "Apr", revenue: 9600 },
  { month: "May", revenue: 12750 },
  { month: "Jun", revenue: 15980 },
  { month: "Jul", revenue: 18240 },
]

export function formatCurrency(amount: number): string {
  return new Intl.NumberFormat("en-US", {
    style: "currency",
    currency: "USD",
  }).format(amount)
}

export function statusLabel(invoice: Invoice): string {
  if (invoice.status === "overdue") {
    return `overdue ${invoice.overdueDays} days`
  }
  return invoice.status
}
