import { useState } from "react"
import { Bar, BarChart, CartesianGrid, XAxis } from "recharts"
import { ChartColumn, RotateCw, TriangleAlert } from "lucide-react"

import type { VariantState } from "@/harness/stage.config"
import { monthlyRevenue, formatCurrency } from "@/lib/fixtures"
import { Button } from "@/components/ui/button"
import { Skeleton } from "@/components/ui/skeleton"
import {
  ChartContainer,
  ChartTooltip,
  ChartTooltipContent,
  type ChartConfig,
} from "@/components/ui/chart"

const chartConfig = {
  revenue: {
    label: "Revenue",
    color: "var(--chart-1)",
  },
} satisfies ChartConfig

/** Skeleton bar heights (percent of plot area) for the loading state. */
const skeletonBars = [42, 58, 50, 72, 88, 100]

export default function VariantChart({ state }: { state: VariantState }) {
  const [attempts, setAttempts] = useState(0)

  if (state === "loading") {
    return (
      <div className="space-y-4">
        <Skeleton className="h-5 w-40" />
        <div className="flex aspect-video w-full items-end gap-3 px-2 pb-6">
          {skeletonBars.map((h, i) => (
            <Skeleton
              key={i}
              className="flex-1 rounded-t-md rounded-b-none"
              style={{ height: `${h}%` }}
            />
          ))}
        </div>
      </div>
    )
  }

  if (state === "error") {
    return (
      <div className="flex aspect-video w-full flex-col items-center justify-center gap-3 rounded-lg border border-destructive/30 bg-destructive/5 text-center">
        <TriangleAlert className="size-8 text-destructive" />
        <div className="space-y-1">
          <p className="text-sm font-medium">Couldn't load revenue</p>
          <p className="text-sm text-muted-foreground">
            The metrics service didn't respond.
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

  if (state === "empty") {
    return (
      <div className="flex aspect-video w-full flex-col items-center justify-center gap-2 rounded-lg border border-dashed text-center">
        <ChartColumn className="size-8 text-muted-foreground" />
        <p className="text-sm font-medium">No revenue yet</p>
        <p className="text-sm text-muted-foreground">
          Billed revenue will chart here once invoices are paid.
        </p>
      </div>
    )
  }

  return (
    <div className="space-y-2">
      <div className="flex items-baseline justify-between">
        <p className="text-sm font-medium">Monthly billed revenue</p>
        <p className="text-sm text-muted-foreground tabular-nums">
          {formatCurrency(
            monthlyRevenue.reduce((sum, m) => sum + m.revenue, 0)
          )}{" "}
          total
        </p>
      </div>
      <ChartContainer config={chartConfig} className="aspect-video w-full">
        <BarChart accessibilityLayer data={monthlyRevenue}>
          <CartesianGrid vertical={false} />
          <XAxis
            dataKey="month"
            tickLine={false}
            tickMargin={10}
            axisLine={false}
          />
          <ChartTooltip
            cursor={false}
            content={
              <ChartTooltipContent
                formatter={(value) => formatCurrency(Number(value))}
              />
            }
          />
          <Bar dataKey="revenue" fill="var(--color-revenue)" radius={4} />
        </BarChart>
      </ChartContainer>
    </div>
  )
}
