// Scenario schema: parse + validate a scenario, enforce the FROZEN step vocabulary,
// assign a stable per-step stepIndex (capture keys are `<route>__<stepIndex>__<viewport>`),
// and enforce the read-only-by-default `allowMutations` gate. This card does NOT
// compile scenarios into Playwright steps (card 06) or execute asserts (card 07).

import { parseYaml, type YamlValue } from './yaml.ts';

// --- Frozen step vocabulary (spec R3 — do NOT extend into a DSL) -------------
export const ACTION_VERBS = ['goto', 'click', 'type', 'hover', 'wait'] as const;
export const CHECKPOINT_VERBS = ['expect', 'match'] as const;
export const VERBS = [...ACTION_VERBS, ...CHECKPOINT_VERBS] as const;
export type Verb = (typeof VERBS)[number];
// Author-declared per-step metadata (not verbs, but allowed keys on a step map).
const META_KEYS = ['mutates', 'label'] as const;

export type Engine = 'deterministic' | 'agent' | 'auto';

export type Viewport = { name: string; width: number; height: number };

export type Step = {
  stepIndex: number;
  verb: Verb;
  action: string; // e.g. "click [data-testid=sidebar-toggle]" — for verdict.step.action
  target: string | null;
  expect: Record<string, YamlValue> | null;
  match: Record<string, YamlValue> | null;
  mutates: boolean;
  label: string | null;
  keys: Record<string, string>; // viewport name -> `<route>__<stepIndex>__<viewport>`
};

export type Scenario = {
  id: string; // also the `<route>` used in capture keys
  url: string;
  engine: Engine;
  threshold: number;
  viewports: Viewport[];
  mask: string[];
  allowMutations: boolean;
  mutating: boolean; // any step marked `mutates: true`
  announcement: string | null; // set when the run must warn before driving
  steps: Step[];
};

export class ScenarioError extends Error {
  constructor(message: string) {
    super(message);
    this.name = 'ScenarioError';
  }
}

// --- Settings precedence (spec D18): CLI > scenario > config > default -------
export type Settings = { threshold: number; viewports: Viewport[]; mask: string[] };
export type SettingsOverride = Partial<Settings>;

export const DEFAULT_SETTINGS: Settings = {
  threshold: 0.01,
  viewports: [
    { name: 'desktop', width: 1280, height: 800 },
    { name: 'mobile', width: 390, height: 844 },
  ],
  mask: [],
};

/** Resolve threshold/viewports/mask with CLI > scenario > config > built-in default. */
export function resolveSettings(
  scenario: SettingsOverride,
  config: SettingsOverride = {},
  cli: SettingsOverride = {},
): Settings {
  const pick = <K extends keyof Settings>(key: K): Settings[K] =>
    (cli[key] ?? scenario[key] ?? config[key] ?? DEFAULT_SETTINGS[key]) as Settings[K];
  return { threshold: pick('threshold'), viewports: pick('viewports'), mask: pick('mask') };
}

/** Stable capture key for a step at a viewport. */
export function captureKey(route: string, stepIndex: number, viewport: string): string {
  return `${route}__${stepIndex}__${viewport}`;
}

const MUTATION_HINT =
  " — destructive clicks and form-submitting `type` steps must be marked `mutates: true`,"
  + ' and the scenario must set `allowMutations: true` to run them.';

function isObject(v: YamlValue): v is Record<string, YamlValue> {
  return v !== null && typeof v === 'object' && !Array.isArray(v);
}

function requireString(obj: Record<string, YamlValue>, key: string): string {
  const v = obj[key];
  if (typeof v !== 'string' || v.trim() === '') {
    throw new ScenarioError(`scenario is missing a non-empty '${key}'`);
  }
  return v;
}

function parseViewports(raw: YamlValue): Viewport[] | undefined {
  if (raw === undefined || raw === null) return undefined;
  if (!Array.isArray(raw) || raw.length === 0) {
    throw new ScenarioError("'viewports' must be a non-empty list");
  }
  return raw.map((v, i) => {
    if (!isObject(v) || typeof v.width !== 'number' || typeof v.height !== 'number') {
      throw new ScenarioError(`viewport ${i} must have numeric 'width' and 'height'`);
    }
    const name = typeof v.name === 'string' && v.name.trim() !== '' ? v.name : `${v.width}x${v.height}`;
    return { name, width: v.width, height: v.height };
  });
}

function parseStep(raw: YamlValue, index: number): Step {
  if (!isObject(raw)) {
    throw new ScenarioError(`step ${index} must be a mapping`);
  }
  const keys = Object.keys(raw);
  for (const k of keys) {
    if (!(VERBS as readonly string[]).includes(k) && !(META_KEYS as readonly string[]).includes(k)) {
      throw new ScenarioError(
        `step ${index}: unknown step verb '${k}' — the frozen vocabulary is ${VERBS.join(', ')}`,
      );
    }
  }
  const actionKeys = keys.filter((k) => (ACTION_VERBS as readonly string[]).includes(k)) as Verb[];
  const checkpointKeys = keys.filter((k) => (CHECKPOINT_VERBS as readonly string[]).includes(k)) as Verb[];
  if (actionKeys.length > 1) {
    throw new ScenarioError(`step ${index}: at most one action verb per step (found ${actionKeys.join(', ')})`);
  }
  if (actionKeys.length === 0 && checkpointKeys.length === 0) {
    throw new ScenarioError(`step ${index}: no verb — a step needs one of ${VERBS.join(', ')}`);
  }
  const verb: Verb = actionKeys[0] ?? checkpointKeys[0];

  const targetRaw = raw[verb];
  const target = typeof targetRaw === 'string' || typeof targetRaw === 'number' ? String(targetRaw) : null;
  const expect = isObject(raw.expect) ? raw.expect : null;
  const match = isObject(raw.match) ? raw.match : null;
  const mutates = raw.mutates === true;
  const label = typeof raw.label === 'string' ? raw.label : null;
  const action = target !== null ? `${verb} ${target}` : verb;

  return { stepIndex: index, verb, action, target, expect, match, mutates, label, keys: {} };
}

/**
 * Parse and validate a scenario. Accepts YAML text or an already-parsed object.
 * Throws ScenarioError on any violation (unknown verb, unflagged mutation, missing
 * required field). On success returns a normalized Scenario with stepIndex assigned
 * and per-viewport capture keys pre-computed.
 */
export function parseScenario(
  input: string | YamlValue,
  overrides: { config?: SettingsOverride; cli?: SettingsOverride } = {},
): Scenario {
  const doc: YamlValue = typeof input === 'string' ? parseYaml(input) : input;
  if (!isObject(doc)) {
    throw new ScenarioError('scenario must be a YAML mapping at the top level');
  }

  const id = requireString(doc, 'id');
  const url = requireString(doc, 'url');

  const engineRaw = doc.engine ?? 'auto';
  if (engineRaw !== 'deterministic' && engineRaw !== 'agent' && engineRaw !== 'auto') {
    throw new ScenarioError(`'engine' must be one of deterministic | agent | auto (got '${String(engineRaw)}')`);
  }
  const engine: Engine = engineRaw;

  if (doc.threshold !== undefined) {
    if (typeof doc.threshold !== 'number' || doc.threshold < 0 || doc.threshold > 1) {
      throw new ScenarioError("'threshold' must be a number in [0, 1]");
    }
  }
  const scenarioViewports = parseViewports(doc.viewports);
  const maskRaw = doc.mask;
  // Undeclared mask stays `undefined` (not `[]`) so the config/default layers can win
  // the precedence chain below — an explicit empty list is preserved as an override.
  const mask =
    maskRaw === undefined || maskRaw === null
      ? undefined
      : Array.isArray(maskRaw) && maskRaw.every((m) => typeof m === 'string')
        ? (maskRaw as string[])
        : ((): string[] => {
            throw new ScenarioError("'mask' must be a list of selector strings");
          })();

  // The scenario file is ONE layer of the settings chain (spec D18): CLI > scenario >
  // config > default. The harness supplies the config.json + CLI layers; any key the
  // scenario does not declare falls through to them.
  const settings = resolveSettings(
    {
      threshold: typeof doc.threshold === 'number' ? doc.threshold : undefined,
      viewports: scenarioViewports,
      mask,
    },
    overrides.config ?? {},
    overrides.cli ?? {},
  );

  const allowMutations = doc.allowMutations === true;

  const stepsRaw = doc.steps;
  if (!Array.isArray(stepsRaw) || stepsRaw.length === 0) {
    throw new ScenarioError("scenario needs a non-empty 'steps' list");
  }
  const steps = stepsRaw.map((s, i) => parseStep(s, i));

  // Read-only-default gate (spec D14): any state-changing step is refused unless the
  // scenario opts in with allowMutations: true.
  const mutating = steps.some((s) => s.mutates);
  if (mutating && !allowMutations) {
    const offenders = steps.filter((s) => s.mutates).map((s) => `step ${s.stepIndex} (${s.verb})`);
    throw new ScenarioError(
      `scenario '${id}' performs state-changing steps [${offenders.join(', ')}] but 'allowMutations' is not true`
      + MUTATION_HINT,
    );
  }

  // Pre-compute stable per-viewport capture keys; the id doubles as the route.
  for (const step of steps) {
    for (const vp of settings.viewports) {
      step.keys[vp.name] = captureKey(id, step.stepIndex, vp.name);
    }
  }

  const announcement = mutating
    ? 'this scenario performs state-changing actions'
    : null;

  return {
    id,
    url,
    engine,
    threshold: settings.threshold,
    viewports: settings.viewports,
    mask: settings.mask,
    allowMutations,
    mutating,
    announcement,
    steps,
  };
}
