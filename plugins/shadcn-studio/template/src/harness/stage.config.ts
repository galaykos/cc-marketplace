import type { ComponentType } from "react"

/** The four states every variant must be able to render. */
export type VariantState = "populated" | "empty" | "loading" | "error"

/** One variant under comparison. */
export type VariantEntry = {
  id: string
  label: string
  /** One-line summary of what this variant trades off. */
  tradeoff: string
  Component: ComponentType<{ state: VariantState }>
}

/**
 * Which lane a stage belongs to. The lane — not the variant — decides the
 * depth of the state matrix: design & dataviz lanes exercise all four states,
 * while the creative lane is populated-only (no toggle).
 */
export type StageLane = "design" | "creative" | "dataviz"

/** Stage configuration. Compare mode renders variants side by side. */
export type StageConfig = {
  mode: "compare"
  /** One lane per stage; drives the toggle button set. */
  lane: StageLane
  variants: VariantEntry[]
}
