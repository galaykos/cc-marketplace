import { describe, expect, test } from 'claude-code/testing'

import { appendTail, bar, hudLine, money, paneRows, parseSegments, span, tokens, turnLine } from '../hooks/hud-core'
import type { Figures } from '../hooks/hud-core'

const NOW = Date.UTC(2026, 9, 8, 12)

const FULL: Figures = {
  now: NOW,
  startedAt: NOW - 42 * 60_000,
  contextPercent: 43,
  contextTokens: 86_000,
  window: 200_000,
  limits: [
    { kind: 'five_hour', percentUsed: 61.4, resetsAt: new Date(NOW + 2 * 3_600_000 + 5 * 60_000).toISOString() },
    { kind: 'seven_day', percentUsed: 12 },
  ],
  costUsd: 1.2,
  branch: 'main',
  isDirty: true,
}

describe('hud-core', () => {
  test('parses segments in the order given, dropping unknown and repeated names', () => {
    expect(parseSegments('cost, Context,bogus,cost')).toEqual(['cost', 'context'])
  })

  test('falls back to every segment when none is set', () => {
    expect(parseSegments(undefined)).toEqual(['context', 'limits', 'cost', 'time', 'git'])
    expect(parseSegments('  ')).toEqual(['context', 'limits', 'cost', 'time', 'git'])
  })

  test('keeps an all-unknown list empty rather than guessing', () => {
    expect(parseSegments('model,effort')).toEqual([])
  })

  test('formats tokens, money and spans', () => {
    expect([tokens(950), tokens(3_249), tokens(12_345), tokens(1_250_000)]).toEqual(['950', '3.2k', '12k', '1.3M'])
    expect(money(0.081)).toBe('$0.08')
    expect([span(42 * 60_000), span(65 * 60_000), span(26 * 3_600_000), span(-5)]).toEqual(['42m', '1h05m', '1d2h', '<1m'])
  })

  test('joins every segment with a reset countdown on a window that has one', () => {
    expect(hudLine(parseSegments(undefined), FULL)).toBe('ctx 43% · 5h 61% ↻2h05m · 7d 12% · $1.20 · 42m · main*')
  })

  test('leaves out a segment with no reading', () => {
    expect(hudLine(parseSegments(undefined), { now: NOW, limits: [] })).toBe('')
    expect(hudLine(['git', 'cost'], { now: NOW, limits: [], branch: 'feat/x', isDirty: false, costUsd: 0 })).toBe('feat/x · $0.00')
  })

  test('drops a countdown whose reset is already past', () => {
    expect(hudLine(['limits'], { now: NOW, limits: [{ kind: 'five_hour', percentUsed: 99, resetsAt: new Date(NOW - 1).toISOString() }] })).toBe(
      '5h 99%',
    )
  })

  test('says what a turn cost and leaves out what is zero', () => {
    expect(turnLine({ outputTokens: 3_200, costUsd: 0.081, contextDelta: 6 })).toBe('3.2k out · $0.08 · ctx +6%')
    expect(turnLine({ outputTokens: 0, costUsd: 0.001, contextDelta: 0 })).toBe('')
    expect(turnLine({ contextDelta: -30 })).toBe('ctx -30%')
  })

  test('appends to a tail another plugin set', () => {
    expect(appendTail(undefined, 'ctx 4%')).toBe('ctx 4%')
    expect(appendTail('[TERSE:FULL]', 'ctx 4%')).toBe('[TERSE:FULL] · ctx 4%')
  })

  test('clamps a bar to its width', () => {
    expect(bar(50, 10)).toBe('█████░░░░░')
    expect(bar(140, 4)).toBe('████')
    expect(bar(-3, 4)).toBe('░░░░')
  })

  test('pane rows name what has no reading yet', () => {
    expect(paneRows({ now: NOW, limits: [] }, null, 60).map(row => row.text)).toEqual([
      'Context',
      'no reading yet — it arrives with the first answer',
      'Rate limits',
      'no reading yet',
      'Session',
      '',
    ])
  })

  test('pane rows carry the breakdown, the compaction point and each window', () => {
    const rows = paneRows(FULL, { categories: [{ name: 'Messages', tokens: 50_000 }, { name: 'Empty', tokens: 0 }], maxTokens: 200_000, compactAt: 160_000 }, 60).map(
      row => row.text,
    )

    expect(rows).toContain('compacts at 160k (80%)')
    expect(rows.some(row => row.includes('Messages') && row.includes('50k'))).toBe(true)
    expect(rows.some(row => row.includes('Empty'))).toBe(false)
    expect(rows.some(row => row.startsWith('5h') && row.endsWith('61% ↻2h05m'))).toBe(true)
    expect(rows.at(-1)).toBe('$1.20  42m  main*')
  })

  test('pane rows fit the 23-column docked body', () => {
    const rows = paneRows(FULL, { categories: [{ name: 'System prompt', tokens: 3_200 }], maxTokens: 1_000_000, compactAt: 967_000 }, 23).map(row => row.text)

    expect(rows.filter(row => row.length > 23)).toEqual([])
    expect(rows).toContain('5h ███░░ 61% ↻2h05m')
    expect(rows).toContain('  System prompt   3.2k')
  })
})
