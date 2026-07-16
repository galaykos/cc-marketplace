import { test } from 'node:test';
import assert from 'node:assert/strict';
import * as fs from 'node:fs';
import * as os from 'node:os';
import * as path from 'node:path';
import {
  CONFIG_DIR,
  CONFIG_FILE,
  ConfigError,
  cliOverride,
  configPath,
  loadConfig,
  parseConfig,
  resolveEffectiveSettings,
} from './loader.ts';
import { initProject, EXAMPLE_SCENARIO_FILE } from './init.ts';
import { parseScenario, type SettingsOverride } from '../scenario/schema.ts';

// A throwaway project dir with a written `.visual-check/config.json`.
function projectWith(config: unknown): string {
  const dir = fs.mkdtempSync(path.join(os.tmpdir(), 'vc-cfg-'));
  fs.mkdirSync(path.join(dir, CONFIG_DIR), { recursive: true });
  fs.writeFileSync(configPath(dir), JSON.stringify(config));
  return dir;
}

// The documented config.json shape (card 09).
const FULL_CONFIG = {
  threshold: 0.05,
  viewports: [{ name: 'wide', width: 1440, height: 900 }],
  mask: ['#ad', '.timestamp'],
  allowLlmEngine: true,
};

// --- loader --------------------------------------------------------------------

test('loadConfig reads the documented config.json shape into an override', () => {
  const dir = projectWith(FULL_CONFIG);
  const cfg = loadConfig(dir);
  assert.equal(cfg.override.threshold, 0.05);
  assert.deepEqual(cfg.override.viewports, [{ name: 'wide', width: 1440, height: 900 }]);
  assert.deepEqual(cfg.override.mask, ['#ad', '.timestamp']);
  assert.equal(cfg.allowLlmEngine, true);
  assert.equal(cfg.path, path.join(dir, CONFIG_DIR, CONFIG_FILE));
});

test('loadConfig on a project with no config file yields an empty override (no error)', () => {
  const dir = fs.mkdtempSync(path.join(os.tmpdir(), 'vc-noconf-'));
  const cfg = loadConfig(dir);
  assert.deepEqual(cfg.override, {});
  assert.equal(cfg.allowLlmEngine, undefined);
  assert.equal(cfg.path, null);
});

test('loadConfig only surfaces the keys the config actually declares', () => {
  const cfg = loadConfig(projectWith({ threshold: 0.2 }));
  assert.deepEqual(cfg.override, { threshold: 0.2 });
  assert.equal('viewports' in cfg.override, false);
  assert.equal('mask' in cfg.override, false);
});

test('loadConfig rejects a malformed config (out-of-range threshold, bad viewport)', () => {
  assert.throws(() => loadConfig(projectWith({ threshold: 5 })), ConfigError);
  assert.throws(() => loadConfig(projectWith({ viewports: [{ name: 'x' }] })), ConfigError);
  assert.throws(() => loadConfig(projectWith({ mask: [1, 2] })), ConfigError);
  assert.throws(() => parseConfig('not-an-object'), ConfigError);
});

test('cliOverride parses --threshold (and its --max-diff-ratio alias)', () => {
  assert.deepEqual(cliOverride({ threshold: '0.2' }), { threshold: 0.2 });
  assert.deepEqual(cliOverride({ 'max-diff-ratio': '0.3' }), { threshold: 0.3 });
  assert.deepEqual(cliOverride({}), {});
});

// --- the precedence chain (threshold / viewports / mask) -----------------------
// The card's exact scenario: config 0.05, scenario 0.02, CLI --threshold 0.2.

const configLayer: SettingsOverride = { threshold: 0.05 };
const scenarioLayer: SettingsOverride = { threshold: 0.02 };
const cliLayer: SettingsOverride = { threshold: 0.2 };

test('threshold chain: CLI 0.2 wins; drop CLI -> scenario 0.02; drop scenario -> config 0.05', () => {
  const full = resolveEffectiveSettings({ scenario: scenarioLayer, config: configLayer, cli: cliLayer });
  assert.equal(full.threshold, 0.2, 'CLI wins');
  const noCli = resolveEffectiveSettings({ scenario: scenarioLayer, config: configLayer });
  assert.equal(noCli.threshold, 0.02, 'scenario wins over config');
  const noScenario = resolveEffectiveSettings({ config: configLayer });
  assert.equal(noScenario.threshold, 0.05, 'config wins over default');
  const bare = resolveEffectiveSettings({});
  assert.equal(bare.threshold, 0.01, 'built-in default');
});

test('viewports resolve through the same chain', () => {
  const cfgVp = [{ name: 'wide', width: 1440, height: 900 }];
  const scnVp = [{ name: 'phone', width: 360, height: 640 }];
  assert.deepEqual(resolveEffectiveSettings({ scenario: { viewports: scnVp }, config: { viewports: cfgVp } }).viewports, scnVp);
  assert.deepEqual(resolveEffectiveSettings({ config: { viewports: cfgVp } }).viewports, cfgVp);
  const def = resolveEffectiveSettings({}).viewports;
  assert.deepEqual(def.map((v) => v.name), ['desktop', 'mobile'], 'default viewports');
});

test('mask resolves through the same chain', () => {
  const cfgMask = ['#ad', '.timestamp'];
  const scnMask = ['[data-testid=clock]'];
  assert.deepEqual(resolveEffectiveSettings({ scenario: { mask: scnMask }, config: { mask: cfgMask } }).mask, scnMask);
  assert.deepEqual(resolveEffectiveSettings({ config: { mask: cfgMask } }).mask, cfgMask);
  assert.deepEqual(resolveEffectiveSettings({}).mask, [], 'default mask');
});

// --- end-to-end through the harness call (parseScenario is what runScenario invokes) ---
// Proves the chain the harness actually walks, not just the standalone resolver.

const scenarioYaml = (extra: string): string =>
  `id: t\nurl: http://localhost:3000/\nengine: deterministic\n${extra}steps:\n  - goto: /\n`;

test('parseScenario walks CLI > scenario > config > default for threshold', () => {
  const config = loadConfig(projectWith(FULL_CONFIG)).override; // threshold 0.05
  const withScn = scenarioYaml('threshold: 0.02\n');
  const withoutScn = scenarioYaml('');

  assert.equal(parseScenario(withScn, { config, cli: { threshold: 0.2 } }).threshold, 0.2, 'CLI wins');
  assert.equal(parseScenario(withScn, { config }).threshold, 0.02, 'scenario wins');
  assert.equal(parseScenario(withoutScn, { config }).threshold, 0.05, 'config wins');
  assert.equal(parseScenario(withoutScn, {}).threshold, 0.01, 'default');
});

test('parseScenario walks the chain for viewports and mask', () => {
  const config = loadConfig(projectWith(FULL_CONFIG)).override; // wide vp + #ad/.timestamp mask
  const scn = scenarioYaml('viewports:\n  - { name: phone, width: 360, height: 640 }\nmask:\n  - "#local"\n');
  const bare = scenarioYaml('');

  const scnResolved = parseScenario(scn, { config });
  assert.deepEqual(scnResolved.viewports.map((v) => v.name), ['phone'], 'scenario viewports win');
  assert.deepEqual(scnResolved.mask, ['#local'], 'scenario mask wins');

  const cfgResolved = parseScenario(bare, { config });
  assert.deepEqual(cfgResolved.viewports.map((v) => v.name), ['wide'], 'config viewports win over default');
  assert.deepEqual(cfgResolved.mask, ['#ad', '.timestamp'], 'config mask wins over default');

  const def = parseScenario(bare, {});
  assert.deepEqual(def.viewports.map((v) => v.name), ['desktop', 'mobile'], 'default viewports');
  assert.deepEqual(def.mask, [], 'default mask');
});

// --- --init scaffolding --------------------------------------------------------

test('initProject writes config.json + an example scenario, announcing both', () => {
  const dir = fs.mkdtempSync(path.join(os.tmpdir(), 'vc-init-'));
  const res = initProject(dir);

  const cfgPath = path.join(dir, CONFIG_DIR, CONFIG_FILE);
  const scnPath = path.join(dir, CONFIG_DIR, EXAMPLE_SCENARIO_FILE);
  assert.ok(fs.existsSync(cfgPath), 'config.json written');
  assert.ok(fs.existsSync(scnPath), 'example scenario written');
  assert.deepEqual(res.created.sort(), [cfgPath, scnPath].sort());

  // The scaffolded config is loadable and the example scenario is parseable.
  const cfg = loadConfig(dir);
  assert.equal(cfg.override.threshold, 0.01);
  assert.deepEqual(cfg.override.viewports?.map((v) => v.name), ['desktop', 'mobile']);
  const scn = parseScenario(fs.readFileSync(scnPath, 'utf8'), { config: cfg.override });
  assert.equal(scn.id, 'home');
});

test('initProject is idempotent — a second run keeps existing files, clobbers nothing', () => {
  const dir = fs.mkdtempSync(path.join(os.tmpdir(), 'vc-init2-'));
  initProject(dir);
  fs.writeFileSync(path.join(dir, CONFIG_DIR, CONFIG_FILE), '{"threshold":0.9}');
  const second = initProject(dir);
  assert.equal(second.created.length, 0, 'nothing created on re-run');
  assert.equal(second.skipped.length, 2, 'both existing files skipped');
  assert.equal(loadConfig(dir).override.threshold, 0.9, 'user edit preserved');
});
