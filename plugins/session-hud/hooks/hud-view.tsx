import type { Elements, RenderElement } from 'claude-code'

import type { PaneRow } from './hud-core'

export function hudView(ui: Pick<Elements['terminal'], 'Box' | 'Text'>, rows: readonly PaneRow[]): RenderElement {
  const { Box, Text } = ui

  return (
    <Box flexDirection="column">
      {rows.map(row => (
        <Text bold={row.isHeading === true} wrap="truncate-end">
          {row.text}
        </Text>
      ))}
    </Box>
  )
}
