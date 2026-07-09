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
      tradeoff: "Maximum density and scanning; sortable columns, less breathing room.",
      Component: VariantA,
    },
    {
      id: "card-list",
      label: "B — Card / list layout",
      tradeoff: "Calmer, touch-friendly rows; easier to read, fewer visible at once.",
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
      tradeoff: "Trend at a glance via bars; wired to the --chart tokens through chart.tsx.",
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
      tradeoff: "Creative lane is populated-only; no state toggle is rendered.",
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
