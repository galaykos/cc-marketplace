import { VariantStage } from "@/harness/VariantStage"
import type { StageConfig } from "@/harness/stage.config"
import VariantA from "@/variants/VariantA"
import VariantB from "@/variants/VariantB"

const config: StageConfig = {
  mode: "compare",
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

export default function App() {
  return <VariantStage config={config} />
}
