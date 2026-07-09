import { useMemo, useState } from "react"
import { ArrowUpDown, Inbox, RotateCw, TriangleAlert } from "lucide-react"

import type { VariantState } from "@/harness/stage.config"
import {
  invoices as allInvoices,
  formatCurrency,
  statusLabel,
  type Invoice,
} from "@/lib/fixtures"
import { Button } from "@/components/ui/button"
import { Input } from "@/components/ui/input"
import { Card, CardContent } from "@/components/ui/card"
import { Skeleton } from "@/components/ui/skeleton"
import {
  Dialog,
  DialogClose,
  DialogContent,
  DialogDescription,
  DialogFooter,
  DialogHeader,
  DialogTitle,
} from "@/components/ui/dialog"

type SortDir = "asc" | "desc"

const dotStyles: Record<Invoice["status"], string> = {
  paid: "bg-emerald-500",
  pending: "bg-amber-500",
  overdue: "bg-destructive",
}

export default function VariantB({ state }: { state: VariantState }) {
  const [query, setQuery] = useState("")
  const [sortDir, setSortDir] = useState<SortDir>("desc")
  const [selected, setSelected] = useState<Invoice | null>(null)
  const [attempts, setAttempts] = useState(0)

  const base = state === "populated" ? allInvoices : []

  const items = useMemo(() => {
    const q = query.trim().toLowerCase()
    const filtered = base.filter(
      (inv) =>
        inv.client.toLowerCase().includes(q) ||
        inv.number.toLowerCase().includes(q)
    )
    return [...filtered].sort((a, b) =>
      sortDir === "asc" ? a.amount - b.amount : b.amount - a.amount
    )
  }, [base, query, sortDir])

  if (state === "loading") {
    return (
      <div className="space-y-4">
        <div className="flex items-center gap-2">
          <Skeleton className="h-9 flex-1" />
          <Skeleton className="h-8 w-32 shrink-0 rounded-md" />
        </div>
        <ul className="space-y-3">
          {Array.from({ length: 4 }).map((_, i) => (
            <li key={i}>
              <Card className="py-0">
                <CardContent className="flex items-center gap-4 p-4">
                  <Skeleton className="size-2.5 shrink-0 rounded-full" />
                  <div className="min-w-0 flex-1 space-y-2">
                    <Skeleton className="h-4 w-48" />
                    <Skeleton className="h-3 w-32" />
                  </div>
                  <Skeleton className="h-4 w-20" />
                  <Skeleton className="h-8 w-16 rounded-md" />
                </CardContent>
              </Card>
            </li>
          ))}
        </ul>
      </div>
    )
  }

  if (state === "error") {
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
        <Button
          size="sm"
          variant="outline"
          onClick={() => setAttempts((n) => n + 1)}
        >
          <RotateCw />
          Try again
        </Button>
      </div>
    )
  }

  if (base.length === 0) {
    return (
      <div className="flex flex-col items-center justify-center gap-2 rounded-lg border border-dashed py-16 text-center">
        <Inbox className="size-8 text-muted-foreground" />
        <p className="text-sm font-medium">Nothing outstanding</p>
        <p className="text-sm text-muted-foreground">
          You're all caught up. Issued invoices will list here.
        </p>
      </div>
    )
  }

  return (
    <div className="space-y-4">
      <div className="flex items-center gap-2">
        <Input
          value={query}
          onChange={(e) => setQuery(e.target.value)}
          placeholder="Search invoices..."
          aria-label="Search invoices"
        />
        <Button
          variant="outline"
          size="sm"
          className="shrink-0"
          onClick={() => setSortDir((d) => (d === "asc" ? "desc" : "asc"))}
        >
          <ArrowUpDown />
          {sortDir === "asc" ? "Low to high" : "High to low"}
        </Button>
      </div>

      {items.length === 0 ? (
        <p className="rounded-lg border border-dashed py-10 text-center text-sm text-muted-foreground">
          No invoices match "{query}".
        </p>
      ) : (
        <ul className="space-y-3">
          {items.map((inv) => (
            <li key={inv.id}>
              <Card className="py-0">
                <CardContent className="flex items-center gap-4 p-4">
                  <span
                    className={`size-2.5 shrink-0 rounded-full ${dotStyles[inv.status]}`}
                    aria-hidden
                  />
                  <div className="min-w-0 flex-1">
                    <p className="font-medium">
                      #{inv.number} &middot; {inv.client}
                    </p>
                    <p className="truncate text-sm text-muted-foreground capitalize">
                      {statusLabel(inv)} &middot; due {inv.due}
                    </p>
                  </div>
                  <div className="text-right">
                    <p className="font-semibold tabular-nums">
                      {formatCurrency(inv.amount)}
                    </p>
                  </div>
                  <Button size="sm" variant="ghost" onClick={() => setSelected(inv)}>
                    Details
                  </Button>
                </CardContent>
              </Card>
            </li>
          ))}
        </ul>
      )}

      <Dialog
        open={selected !== null}
        onOpenChange={(open) => !open && setSelected(null)}
      >
        <DialogContent>
          {selected && (
            <>
              <DialogHeader>
                <DialogTitle>Invoice #{selected.number}</DialogTitle>
                <DialogDescription>{selected.client}</DialogDescription>
              </DialogHeader>
              <dl className="grid grid-cols-2 gap-3 text-sm">
                <Detail label="Amount" value={formatCurrency(selected.amount)} />
                <Detail label="Status" value={statusLabel(selected)} />
                <Detail label="Issued" value={selected.issued} />
                <Detail label="Due" value={selected.due} />
                <Detail label="Billing email" value={selected.email} />
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
    </div>
  )
}

function Detail({ label, value }: { label: string; value: string }) {
  return (
    <div className="space-y-0.5">
      <dt className="text-xs text-muted-foreground">{label}</dt>
      <dd className="font-medium">{value}</dd>
    </div>
  )
}
