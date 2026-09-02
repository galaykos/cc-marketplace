import { VariantStage } from "@/harness/VariantStage"
import type { StageConfig } from "@/harness/stage.config"
import VariantA from "@/variants/VariantA"
import VariantB from "@/variants/VariantB"
import VariantChart from "@/variants/VariantChart"

// Design lane: two layout treatments, full four-state matrix toggle.
const designConfig: StageConfig = {
  mode: "compare",
  lane: "design",
  variants: [
    {
      id: "dense-table",
      label: "A — Dense data table",
      rationale: {
        serves: "power users scanning many invoices at once",
        trades: "breathing room and comfortable touch targets",
        breaks: "on narrow screens or with long client names",
      },
      Component: VariantA,
    },
    {
      id: "card-list",
      label: "B — Card / list layout",
      rationale: {
        serves: "casual users skimming a few records on any device",
        trades: "on-screen density — fewer rows fit per viewport",
        breaks: "when comparing dozens of records side by side",
      },
      Component: VariantB,
    },
  ],
}

// Dataviz lane: a live Recharts chart, also across all four states.
const datavizConfig: StageConfig = {
  mode: "compare",
  lane: "dataviz",
  variants: [
    {
      id: "revenue-bars",
      label: "Chart — Monthly revenue",
      rationale: {
        serves: "readers wanting the revenue trend at a glance",
        trades: "exact per-month figures for overall shape",
        breaks: "with sparse data or too many months to label",
      },
      Component: VariantChart,
    },
  ],
}

// Creative lane: populated-only showcase — the harness suppresses the toggle.
const creativeConfig: StageConfig = {
  mode: "compare",
  lane: "creative",
  variants: [
    {
      id: "card-showcase",
      label: "Showcase — Card list",
      rationale: {
        serves: "a first-impression showcase of the populated layout",
        trades: "state coverage — only the populated case is shown",
        breaks: "as a real state harness; no toggle is rendered here",
      },
      Component: VariantB,
    },
  ],
}

export default function App() {
  return (
    <>
      <VariantStage config={designConfig} />
      <VariantStage config={datavizConfig} />
      <VariantStage config={creativeConfig} />
    </>
  )
}
