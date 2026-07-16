// Config loader + precedence resolver for the consumer's committed
// `.visual-check/config.json`. This is ONE layer of the single settings chain
// (spec D18): CLI flag > scenario file > config.json > built-in default. The chain
// itself lives in scenario/schema.ts `resolveSettings`; this module only loads the
// config.json layer, parses CLI overrides, and delegates the pick — never duplicates
// the precedence logic. Applies to `threshold`, `viewports`, `mask`.

import * as fs from 'node:fs';
import * as path from 'node:path';
import {
  resolveSettings,
  type Settings,
  type SettingsOverride,
  type Viewport,
} from '../scenario/schema.ts';

export const CONFIG_DIR = '.visual-check';
export const CONFIG_FILE = 'config.json';

export class ConfigError extends Error {
  constructor(message: string) {
    super(message);
    this.name = 'ConfigError';
  }
}

/** The parsed config.json: the settings override it declares (only present keys),
 *  plus the non-settings `allowLlmEngine` flag and the file it was read from. */
export type LoadedConfig = {
  override: SettingsOverride;
  allowLlmEngine: boolean | undefined;
  path: string | null;
};

export function configPath(baseDir: string): string {
  return path.join(baseDir, CONFIG_DIR, CONFIG_FILE);
}

function isObject(v: unknown): v is Record<string, unknown> {
  return v !== null && typeof v === 'object' && !Array.isArray(v);
}

function parseThreshold(raw: unknown): number | undefined {
  if (raw === undefined) return undefined;
  if (typeof raw !== 'number' || Number.isNaN(raw) || raw < 0 || raw > 1) {
    throw new ConfigError("config 'threshold' must be a number in [0, 1]");
  }
  return raw;
}

function parseViewports(raw: unknown): Viewport[] | undefined {
  if (raw === undefined) return undefined;
  if (!Array.isArray(raw) || raw.length === 0) {
    throw new ConfigError("config 'viewports' must be a non-empty array");
  }
  return raw.map((v, i) => {
    if (!isObject(v) || typeof v.width !== 'number' || typeof v.height !== 'number') {
      throw new ConfigError(`config viewport ${i} needs numeric 'width' and 'height'`);
    }
    const name =
      typeof v.name === 'string' && v.name.trim() !== '' ? v.name : `${v.width}x${v.height}`;
    return { name, width: v.width, height: v.height };
  });
}

function parseMask(raw: unknown): string[] | undefined {
  if (raw === undefined) return undefined;
  if (!Array.isArray(raw) || !raw.every((m) => typeof m === 'string')) {
    throw new ConfigError("config 'mask' must be an array of selector strings");
  }
  return raw as string[];
}

function parseAllowLlm(raw: unknown): boolean | undefined {
  if (raw === undefined) return undefined;
  if (typeof raw !== 'boolean') throw new ConfigError("config 'allowLlmEngine' must be a boolean");
  return raw;
}

/** Validate a parsed config object into a settings override. Only keys the config
 *  actually declares appear on `override`, so undeclared keys fall through the chain. */
export function parseConfig(json: unknown): LoadedConfig {
  if (!isObject(json)) throw new ConfigError('config.json must be a JSON object');
  const override: SettingsOverride = {};
  const threshold = parseThreshold(json.threshold);
  const viewports = parseViewports(json.viewports);
  const mask = parseMask(json.mask);
  if (threshold !== undefined) override.threshold = threshold;
  if (viewports !== undefined) override.viewports = viewports;
  if (mask !== undefined) override.mask = mask;
  return { override, allowLlmEngine: parseAllowLlm(json.allowLlmEngine), path: null };
}

/** Load `<baseDir>/.visual-check/config.json`. A missing file is not an error — it
 *  yields an empty override so the chain falls straight through to defaults. */
export function loadConfig(baseDir: string): LoadedConfig {
  const p = configPath(baseDir);
  if (!fs.existsSync(p)) return { override: {}, allowLlmEngine: undefined, path: null };
  let raw: string;
  try {
    raw = fs.readFileSync(p, 'utf8');
  } catch (e) {
    throw new ConfigError(`cannot read ${p}: ${(e as Error).message}`);
  }
  let json: unknown;
  try {
    json = JSON.parse(raw);
  } catch (e) {
    throw new ConfigError(`invalid JSON in ${p}: ${(e as Error).message}`);
  }
  const cfg = parseConfig(json);
  cfg.path = p;
  return cfg;
}

/** Extract the CLI override layer. `--threshold` (alias `--max-diff-ratio`) is the
 *  only compact CLI form; viewports/mask are set via config.json or the scenario. */
export function cliOverride(args: Record<string, unknown>): SettingsOverride {
  const o: SettingsOverride = {};
  const t = args.threshold ?? args['max-diff-ratio'];
  if (t !== undefined && t !== null && String(t) !== '') {
    const n = Number(t);
    if (!Number.isNaN(n)) o.threshold = n;
  }
  return o;
}

/** Resolve effective settings from the three pre-assembled override layers. A thin
 *  wrapper over schema.ts `resolveSettings` so the precedence order stays defined once. */
export function resolveEffectiveSettings(o: {
  scenario?: SettingsOverride;
  config?: SettingsOverride;
  cli?: SettingsOverride;
}): Settings {
  return resolveSettings(o.scenario ?? {}, o.config ?? {}, o.cli ?? {});
}

export { resolveSettings };
export type { Settings, SettingsOverride };
