import { useState } from "react"

import type { StageConfig, StageLane, VariantState } from "./stage.config"
import { Button } from "@/components/ui/button"
import {
  Card,
  CardContent,
  CardDescription,
  CardHeader,
  CardTitle,
} from "@/components/ui/card"

/** Human labels for the toggle, in matrix order. */
const stateLabels: Record<VariantState, string> = {
  populated: "Populated",
  empty: "Empty",
  loading: "Loading",
  error: "Error",
}

/**
 * The lane decides how deep the state matrix goes. Design & dataviz lanes get
 * the full four-state toggle; the creative lane is populated-only and shows no
 * toggle at all.
 */
const laneStates: Record<StageLane, VariantState[]> = {
  design: ["populated", "empty", "loading", "error"],
  dataviz: ["populated", "empty", "loading", "error"],
  creative: ["populated"],
}

export function VariantStage({ config }: { config: StageConfig }) {
  // A single shared state drives every variant, so flipping the toggle
  // re-renders all variants at once and proves live state propagation.
  const [state, setState] = useState<VariantState>("populated")

  const states = laneStates[config.lane]
  const showToggle = states.length > 1

  return (
    <div className="min-h-svh bg-background">
      <header className="border-b">
        <div className="mx-auto flex max-w-7xl flex-col gap-4 px-6 py-5 sm:flex-row sm:items-center sm:justify-between">
          <div className="space-y-1">
            <h1 className="text-xl font-semibold tracking-tight">
              Shadcn Studio
            </h1>
            <p className="text-sm text-muted-foreground">
              {config.lane} lane · comparing {config.variants.length}{" "}
              {config.variants.length === 1 ? "variant" : "variants"} side by
              side.
            </p>
          </div>
          {showToggle && (
            <div
              className="inline-flex items-center gap-1 rounded-lg border bg-card p-1"
              role="group"
              aria-label="Toggle variant state"
            >
              {states.map((s) => (
                <Button
                  key={s}
                  size="sm"
                  variant={state === s ? "default" : "ghost"}
                  onClick={() => setState(s)}
                  aria-pressed={state === s}
                >
                  {stateLabels[s]}
                </Button>
              ))}
            </div>
          )}
        </div>
      </header>

      <main className="mx-auto max-w-7xl px-6 py-6">
        <div className="grid grid-cols-1 gap-6 lg:grid-cols-2">
          {config.variants.map((variant) => {
            const Component = variant.Component
            return (
              <Card key={variant.id} className="gap-0 overflow-hidden py-0">
                <CardHeader className="border-b bg-muted/40 py-4">
                  <CardTitle className="text-base">{variant.label}</CardTitle>
                  <CardDescription>{variant.tradeoff}</CardDescription>
                </CardHeader>
                <CardContent className="p-4">
                  <Component state={state} />
                </CardContent>
              </Card>
            )
          })}
        </div>
      </main>
    </div>
  )
}
