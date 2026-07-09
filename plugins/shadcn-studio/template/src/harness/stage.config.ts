import type { ComponentType } from "react"

/** The two states every variant must be able to render. */
export type VariantState = "populated" | "empty"

/** One variant under comparison. */
export type VariantEntry = {
  id: string
  label: string
  /** One-line summary of what this variant trades off. */
  tradeoff: string
  Component: ComponentType<{ state: VariantState }>
}

/** Stage configuration. Compare mode renders variants side by side. */
export type StageConfig = {
  mode: "compare"
  variants: VariantEntry[]
}
