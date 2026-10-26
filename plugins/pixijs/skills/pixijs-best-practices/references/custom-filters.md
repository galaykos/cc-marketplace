# Custom filters in v8 — constructor, uniforms, coordinates

Read on demand from the pixijs-best-practices SKILL when writing or porting a custom
`Filter`. Read 2026-10-26 from the v8 migration guide and PixiJS 8.22.0's
`src/filters/FilterSystem.ts` and `src/filters/defaults/defaultFilter.vert`.

## The constructor

```js
import { Filter, GlProgram } from 'pixi.js';

const filter = new Filter({
  glProgram: GlProgram.from({ vertex, fragment }),
  resources: {
    waveUniforms: {
      uAmp:  { value: 0.05, type: 'f32' },   // every uniform declares its type
      uTime: { value: 0.0,  type: 'f32' },
    },
  },
});

app.ticker.add((ticker) => {
  filter.resources.waveUniforms.uniforms.uTime += ticker.deltaMS / 1000;
});
```

- The v7 form `new Filter(vertex, fragment, { uTime: 0 })` no longer applies.
- Textures are resources of their own, never members of a uniform group.
- The `@pixi/filter-*` community packages are not maintained for v8.

## No initialisers on uniforms

GLSL ES — the language WebGL compiles — forbids initialisers on global variables with any
storage qualifier other than `const` (GLSL ES 3.20 §4.3). `uniform float uAmp = 0.05;`
compiles in desktop GLSL and fails in the browser. Declare `uniform float uAmp;` and put the
default in `resources`, as above.

## `vTextureCoord` is not 0–1 over the object

The default filter vertex shader computes:

```glsl
vTextureCoord = aPosition * (uOutputFrame.zw * uInputSize.zw);
```

`uInputSize` is the size of the pooled input texture (`.zw` is its reciprocal), and that
texture can be larger than the frame being filtered. `uOutputFrame.zw` is the frame's size,
which is the object's bounds plus the filter's padding. So `vTextureCoord` runs from 0 to
`frame / input` on each axis, and any effect that assumes 0–1 (a gradient, a vignette, a
wave across the sprite) is stretched or cut short.

Convert in the fragment shader:

```glsl
in vec2 vTextureCoord;
out vec4 finalColor;
uniform vec4 uInputSize;
uniform vec4 uOutputFrame;
uniform vec4 uInputClamp;
uniform sampler2D uTexture;

void main() {
  vec2 uv = vTextureCoord * uInputSize.xy / uOutputFrame.zw;   // 0–1 over the filter frame
  vec2 offset = vec2(sin(uv.y * 20.0) * 0.01, 0.0) * uOutputFrame.zw / uInputSize.xy;
  vec2 coord = clamp(vTextureCoord + offset, uInputClamp.xy, uInputClamp.zw);
  finalColor = texture(uTexture, coord);
}
```

- Compute the effect in `uv`, then convert any offset back to input-texture space before
  sampling. Sample with `vTextureCoord`-space coordinates only.
- Clamp sample coordinates to `uInputClamp` (`.xy` the minimum, `.zw` the maximum, each half
  a texel inside the frame), or an offset reads neighbouring data from the pooled texture.
- `uv` covers the padded frame, not the bare sprite. Account for `filter.padding` when an
  effect must line up with the sprite's own edges.
