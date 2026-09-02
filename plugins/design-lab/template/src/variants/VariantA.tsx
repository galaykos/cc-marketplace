import { useMemo, useState } from "react"
import {
  ArrowDown,
  ArrowUp,
  ChevronsUpDown,
  FileX2,
  RotateCw,
  TriangleAlert,
} from "lucide-react"

import type { VariantState } from "@/harness/stage.config"
import {
  invoices as allInvoices,
  formatCurrency,
  statusLabel,
  type Invoice,
} from "@/lib/fixtures"
import { Button } from "@/components/ui/button"
import { Input } from "@/components/ui/input"
import { Skeleton } from "@/components/ui/skeleton"
import {
  Table,
  TableBody,
  TableCell,
  TableHead,
  TableHeader,
  TableRow,
} from "@/components/ui/table"
import {
  Dialog,
  DialogClose,
  DialogContent,
  DialogDescription,
  DialogFooter,
  DialogHeader,
  DialogTitle,
} from "@/components/ui/dialog"

type SortKey = "number" | "client" | "amount"
type SortDir = "asc" | "desc"

const statusStyles: Record<Invoice["status"], string> = {
  paid: "bg-emerald-500/10 text-emerald-600 dark:text-emerald-400",
  pending: "bg-amber-500/10 text-amber-600 dark:text-amber-400",
  overdue: "bg-destructive/10 text-destructive",
}

function StatusBadge({ invoice }: { invoice: Invoice }) {
  return (
    <span
      className={`inline-flex items-center rounded-full px-2 py-0.5 text-xs font-medium capitalize ${statusStyles[invoice.status]}`}
    >
      {statusLabel(invoice)}
    </span>
  )
}

export default function VariantA({ state }: { state: VariantState }) {
  const [query, setQuery] = useState("")
  const [sortKey, setSortKey] = useState<SortKey>("amount")
  const [sortDir, setSortDir] = useState<SortDir>("desc")
  const [selected, setSelected] = useState<Invoice | null>(null)
  const [attempts, setAttempts] = useState(0)

  const base = state === "populated" ? allInvoices : []

  const rows = useMemo(() => {
    const q = query.trim().toLowerCase()
    const filtered = base.filter(
      (inv) =>
        inv.client.toLowerCase().includes(q) ||
        inv.number.toLowerCase().includes(q)
    )
    const sorted = [...filtered].sort((a, b) => {
      let cmp = 0
      if (sortKey === "amount") cmp = a.amount - b.amount
      else cmp = String(a[sortKey]).localeCompare(String(b[sortKey]))
      return sortDir === "asc" ? cmp : -cmp
    })
    return sorted
  }, [base, query, sortKey, sortDir])

  function toggleSort(key: SortKey) {
    if (key === sortKey) {
      setSortDir((d) => (d === "asc" ? "desc" : "asc"))
    } else {
      setSortKey(key)
      setSortDir("asc")
    }
  }

  function SortHeader({ label, sortKey: key }: { label: string; sortKey: SortKey }) {
    const active = sortKey === key
    const Icon = !active ? ChevronsUpDown : sortDir === "asc" ? ArrowUp : ArrowDown
    return (
      <button
        type="button"
        onClick={() => toggleSort(key)}
        className="inline-flex items-center gap-1 font-medium hover:text-foreground"
      >
        {label}
        <Icon className={active ? "size-3.5" : "size-3.5 text-muted-foreground"} />
      </button>
    )
  }

  if (state === "loading") {
    return <LoadingTable />
  }

  if (state === "error") {
    return (
      <ErrorState
        attempts={attempts}
        onRetry={() => setAttempts((n) => n + 1)}
      />
    )
  }

  if (base.length === 0) {
    return <EmptyState />
  }

  return (
    <div className="space-y-4">
      <Input
        value={query}
        onChange={(e) => setQuery(e.target.value)}
        placeholder="Filter by client or invoice #..."
        className="max-w-xs"
        aria-label="Filter invoices"
      />

      <div className="rounded-lg border">
        <Table>
          <TableHeader>
            <TableRow>
              <TableHead>
                <SortHeader label="Invoice" sortKey="number" />
              </TableHead>
              <TableHead>
                <SortHeader label="Client" sortKey="client" />
              </TableHead>
              <TableHead>Status</TableHead>
              <TableHead className="text-right">
                <SortHeader label="Amount" sortKey="amount" />
              </TableHead>
              <TableHead className="text-right">Action</TableHead>
            </TableRow>
          </TableHeader>
          <TableBody>
            {rows.length === 0 ? (
              <TableRow>
                <TableCell colSpan={5} className="h-24 text-center text-muted-foreground">
                  No invoices match "{query}".
                </TableCell>
              </TableRow>
            ) : (
              rows.map((inv) => (
                <TableRow key={inv.id}>
                  <TableCell className="font-medium">#{inv.number}</TableCell>
                  <TableCell>{inv.client}</TableCell>
                  <TableCell>
                    <StatusBadge invoice={inv} />
                  </TableCell>
                  <TableCell className="text-right tabular-nums">
                    {formatCurrency(inv.amount)}
                  </TableCell>
                  <TableCell className="text-right">
                    <Button size="sm" variant="outline" onClick={() => setSelected(inv)}>
                      View
                    </Button>
                  </TableCell>
                </TableRow>
              ))
            )}
          </TableBody>
        </Table>
      </div>

      <InvoiceDialog invoice={selected} onClose={() => setSelected(null)} />
    </div>
  )
}

function EmptyState() {
  return (
    <div className="flex flex-col items-center justify-center gap-2 rounded-lg border border-dashed py-16 text-center">
      <FileX2 className="size-8 text-muted-foreground" />
      <p className="text-sm font-medium">No invoices to show</p>
      <p className="text-sm text-muted-foreground">
        New invoices will appear here once they are issued.
      </p>
    </div>
  )
}

function LoadingTable() {
  return (
    <div className="space-y-4">
      <Skeleton className="h-9 w-full max-w-xs" />
      <div className="rounded-lg border">
        <div className="flex items-center gap-4 border-b px-4 py-3">
          <Skeleton className="h-4 w-16" />
          <Skeleton className="h-4 flex-1" />
          <Skeleton className="h-4 w-20" />
          <Skeleton className="ml-auto h-4 w-16" />
        </div>
        {Array.from({ length: 5 }).map((_, i) => (
          <div
            key={i}
            className="flex items-center gap-4 border-b px-4 py-3 last:border-0"
          >
            <Skeleton className="h-4 w-14" />
            <Skeleton className="h-4 flex-1" />
            <Skeleton className="h-5 w-16 rounded-full" />
            <Skeleton className="h-4 w-20" />
            <Skeleton className="h-8 w-16 rounded-md" />
          </div>
        ))}
      </div>
    </div>
  )
}

function ErrorState({
  attempts,
  onRetry,
}: {
  attempts: number
  onRetry: () => void
}) {
  return (
    <div className="flex flex-col items-center justify-center gap-3 rounded-lg border border-destructive/30 bg-destructive/5 py-16 text-center">
      <TriangleAlert className="size-8 text-destructive" />
      <div className="space-y-1">
        <p className="text-sm font-medium">Couldn't load invoices</p>
        <p className="text-sm text-muted-foreground">
          Something went wrong while fetching this list.
          {attempts > 0 && ` Retried ${attempts}×.`}
        </p>
      </div>
      <Button size="sm" variant="outline" onClick={onRetry}>
        <RotateCw />
        Try again
      </Button>
    </div>
  )
}

function InvoiceDialog({
  invoice,
  onClose,
}: {
  invoice: Invoice | null
  onClose: () => void
}) {
  return (
    <Dialog open={invoice !== null} onOpenChange={(open) => !open && onClose()}>
      <DialogContent>
        {invoice && (
          <>
            <DialogHeader>
              <DialogTitle>Invoice #{invoice.number}</DialogTitle>
              <DialogDescription>{invoice.client}</DialogDescription>
            </DialogHeader>
            <dl className="grid grid-cols-2 gap-3 text-sm">
              <DetailRow label="Amount" value={formatCurrency(invoice.amount)} />
              <DetailRow label="Status" value={statusLabel(invoice)} />
              <DetailRow label="Issued" value={invoice.issued} />
              <DetailRow label="Due" value={invoice.due} />
              <DetailRow label="Billing email" value={invoice.email} />
            </dl>
            <DialogFooter>
              <DialogClose asChild>
                <button className="text-sm text-muted-foreground hover:text-foreground">
                  Close
                </button>
              </DialogClose>
            </DialogFooter>
          </>
        )}
      </DialogContent>
    </Dialog>
  )
}

function DetailRow({ label, value }: { label: string; value: string }) {
  return (
    <div className="space-y-0.5">
      <dt className="text-xs text-muted-foreground">{label}</dt>
      <dd className="font-medium">{value}</dd>
    </div>
  )
}
