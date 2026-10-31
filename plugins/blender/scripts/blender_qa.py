"""Catches z-fighting, floating parts, inverted normals, open or degenerate topology, unapplied scale, UV and weight gaps in one asset's meshes; runs inside Blender.
Does NOT judge silhouette, deformation, shading or material intent, and skips the z-fight and floating checks above --max-tris.
Exit 0 pass, 1 errors (or warnings with --strict), 2 could not run: blender -b f.blend --python-exit-code 2 --python blender_qa.py -- --objects A B"""
# Derived from EL4CTEO/blender-skills@71d031d skills/blender-asset-qa/scripts/qa_check.py and shared/_bpyx.py (MIT, see LICENSE); modified.
# Why, limits, history: rationale/derivations/plugin-blender.md § plugins/blender/scripts/blender_qa.py
import argparse
import json
import math
import sys
from collections import Counter, defaultdict

try:
    import bmesh
    import bpy
    from mathutils import Vector
    from mathutils.bvhtree import BVHTree
    from mathutils.kdtree import KDTree
except ImportError:
    bpy = None

# check -> severity per profile ("e" error, "w" warning, None skip)
PROFILES = {
    "game":   dict(zf="e", fl="e", inv="e", inc="e", nm="w", bd=None, dg="e", dup="w", ng="w", sc="e", uv="e", wt="e"),
    "render": dict(zf="e", fl="e", inv="w", inc="w", nm=None, bd=None, dg="w", dup="w", ng=None, sc="w", uv="w", wt="w"),
    "print":  dict(zf="e", fl="e", inv="e", inc="e", nm="e", bd="e", dg="e", dup="e", ng=None, sc="w", uv=None, wt=None),
    "roblox": dict(zf="e", fl="e", inv="e", inc="e", nm="w", bd="w", dg="e", dup="w", ng="e", sc="e", uv="e", wt="e"),
}
TRI_LIMIT = {"roblox": 20000}


def script_args(argv):
    """Arguments after '--'; Blender consumes everything before it."""
    return argv[argv.index("--") + 1:] if "--" in argv else []


def parse_args(args):
    p = argparse.ArgumentParser(prog="blender_qa.py", description=__doc__.splitlines()[0])
    p.add_argument("--objects", nargs="*", default=None, help="mesh objects of ONE asset (default: selected, else visible meshes)")
    p.add_argument("--profile", default="game", choices=list(PROFILES))
    p.add_argument("--eps", type=float, default=0.001, help="z-fight plane distance (m)")
    p.add_argument("--tol", type=float, default=0.002, help="contact tolerance for detached parts (m)")
    p.add_argument("--no-modifiers", action="store_true", help="check the base mesh, not the evaluated one")
    p.add_argument("--max-tris", type=int, default=300000)
    p.add_argument("--no-uv", dest="uv", action="store_false")
    p.add_argument("--strict", action="store_true", help="exit 1 on warnings too")
    p.add_argument("--json", action="store_true", help="print one JSON object instead of text")
    return p.parse_args(args)


def islands(count, edges):
    """Island id per vertex from (a, b) vertex-index pairs, numbered in first-seen order."""
    parent = list(range(count))

    def find(i):
        while parent[i] != i:
            parent[i] = parent[parent[i]]
            i = parent[i]
        return i
    for a, b in edges:
        ra, rb = find(a), find(b)
        if ra != rb:
            parent[ra] = rb
    roots = [find(i) for i in range(count)]
    remap = {r: n for n, r in enumerate(dict.fromkeys(roots))}
    return [remap[r] for r in roots]


def exit_status(result, strict=False):
    return 1 if result["errors"] or (strict and result["warnings"]) else 0


def rnd(v, n=4):
    return round(v, n) if isinstance(v, float) else [round(x, n) for x in v]


def pick_objects(names):
    if names:
        missing = [n for n in names if n not in bpy.data.objects]
        if missing:
            raise KeyError(f"objects not found: {missing}")
        return [bpy.data.objects[n] for n in names]
    pool = [o for o in bpy.context.scene.objects if o.type == "MESH"]
    return [o for o in pool if o.select_get()] or [o for o in pool if o.visible_get()]


def object_mode():
    ob = bpy.context.view_layer.objects.active
    if ob and ob.mode != "OBJECT":
        bpy.ops.object.mode_set(mode="OBJECT")


def _mesh_world(ob, use_mods):
    bm = bmesh.new()
    if use_mods:
        bm.from_object(ob, bpy.context.evaluated_depsgraph_get())
    else:
        bm.from_mesh(ob.data)
    bm.transform(ob.matrix_world)
    bm.verts.ensure_lookup_table()
    bm.faces.ensure_lookup_table()
    return bm


def _point_in_tri(p, a, b, c, n):
    for u, v in ((a, b), (b, c), (c, a)):
        if (v - u).cross(p - u).dot(n) < -1e-9:
            return False
    return True


def _uv_stats(ob, bm_local):
    me = ob.data
    if not me.uv_layers:
        return {"uv_maps": 0}
    uv = bm_local.loops.layers.uv.active
    oob = total = zero = 0
    grid, n = defaultdict(set), 128
    step = max(1, len(bm_local.faces) // 30000)
    for f in list(bm_local.faces)[::step]:
        pts = [lp[uv].uv.copy() for lp in f.loops]
        for p in pts:
            total += 1
            if p.x < -1e-4 or p.y < -1e-4 or p.x > 1.0001 or p.y > 1.0001:
                oob += 1
        a2 = sum(pts[i].x * pts[(i + 1) % len(pts)].y - pts[(i + 1) % len(pts)].x * pts[i].y for i in range(len(pts)))
        if abs(a2) < 1e-12:
            zero += 1
            continue
        xs, ys = [p.x for p in pts], [p.y for p in pts]
        for gx in range(max(0, int(min(xs) * n)), min(n, int(max(xs) * n) + 1)):
            for gy in range(max(0, int(min(ys) * n)), min(n, int(max(ys) * n) + 1)):
                c = Vector(((gx + .5) / n, (gy + .5) / n))
                for i in range(1, len(pts) - 1):
                    t = (pts[0], pts[i], pts[i + 1])
                    d = [(t[(k + 1) % 3] - t[k]).to_3d().cross((c - t[k]).to_3d()).z for k in range(3)]
                    if all(x >= 0 for x in d) or all(x <= 0 for x in d):
                        grid[(gx, gy)].add(f.index)
                        break
    used = len(grid)
    overlap = sum(1 for s in grid.values() if len(s) > 1)
    return {"uv_maps": len(me.uv_layers), "uv_oob_pct": round(100 * oob / max(total, 1), 2),
            "uv_zero_area_faces": zero, "uv_overlap_pct": round(100 * overlap / max(used, 1), 2),
            "uv_coverage_pct": round(100 * used / n / n, 1)}


def run(objects=None, profile="game", eps=0.001, tol=0.002, no_modifiers=False, max_tris=300000, uv=True, **_):
    object_mode()
    sev = PROFILES[profile]
    obs = [o for o in pick_objects(objects) if o.type == "MESH"]
    if not obs:
        raise ValueError("no mesh objects to check")
    errors, warnings, per = [], [], {}

    def flag(key, msg):
        s = sev.get(key)
        if s == "e":
            errors.append(msg)
        elif s == "w":
            warnings.append(msg)

    verts, tris, tri_meta = [], [], []
    island_info = {}
    gid_base = 0
    min_z = math.inf
    for oi, ob in enumerate(obs):
        bm = _mesh_world(ob, not no_modifiers)
        m = {}
        isl = islands(len(bm.verts), [(e.verts[0].index, e.verts[1].index) for e in bm.edges])
        n_isl = max(isl) + 1 if isl else 0
        base_v = len(verts)
        verts.extend(v.co.copy() for v in bm.verts)
        if bm.verts:
            min_z = min(min_z, min(v.co.z for v in bm.verts))
        ecount = Counter(len(e.link_faces) for e in bm.edges)
        m["verts"], m["faces"] = len(bm.verts), len(bm.faces)
        m["tris"] = sum(len(f.verts) - 2 for f in bm.faces)
        m["ngons"] = sum(1 for f in bm.faces if len(f.verts) > 4)
        m["boundary_edges"] = ecount.get(1, 0)
        m["nonmanifold_edges"] = sum(c for k, c in ecount.items() if k > 2)
        m["wire_edges"] = ecount.get(0, 0)
        m["loose_verts"] = sum(1 for v in bm.verts if not v.link_edges)
        m["degenerate_faces"] = sum(1 for f in bm.faces if f.calc_area() < 1e-10)
        m["zero_length_edges"] = sum(1 for e in bm.edges if e.calc_length() < 1e-7)
        directed = Counter((lp.vert.index, lp.link_loop_next.vert.index) for f in bm.faces for lp in f.loops)
        m["inconsistent_normals_edges"] = sum(1 for k, c in directed.items() if c > 1)
        kd = KDTree(len(bm.verts))
        for v in bm.verts:
            kd.insert(v.co, v.index)
        kd.balance()
        m["duplicate_verts"] = sum(1 for v in bm.verts if len(kd.find_range(v.co, 1e-5)) > 1) // 2
        m["islands"] = n_isl
        vol, closed = defaultdict(float), defaultdict(lambda: True)
        for e in bm.edges:
            if len(e.link_faces) != 2:
                closed[isl[e.verts[0].index]] = False
        bm_t = bm.copy()
        bmesh.ops.triangulate(bm_t, faces=bm_t.faces[:])
        bm_t.verts.ensure_lookup_table()
        for f in bm_t.faces:
            a, b, c = (v.co for v in f.verts)
            g = isl[f.verts[0].index]
            vol[g] += a.dot(b.cross(c)) / 6.0
            tris.append(tuple(base_v + v.index for v in f.verts))
            tri_meta.append((oi, gid_base + g, f.normal.copy()))
        bm_t.free()
        m["inside_out_islands"] = sum(1 for g in range(n_isl) if closed[g] and vol[g] < -1e-9)
        groups = defaultdict(list)
        for i, g in enumerate(isl):
            groups[g].append(i)
        for g, idx in groups.items():
            pts = [bm.verts[i].co for i in idx]
            lo = Vector((min(p.x for p in pts), min(p.y for p in pts), min(p.z for p in pts)))
            hi = Vector((max(p.x for p in pts), max(p.y for p in pts), max(p.z for p in pts)))
            island_info[gid_base + g] = {"ob": ob.name, "verts": [base_v + i for i in idx],
                                         "center": (lo + hi) / 2, "size": (hi - lo).length,
                                         "closed": closed[g], "tris": []}
        gid_base += n_isl
        s = ob.scale
        m["scale"] = rnd(tuple(s), 3)
        if any(abs(x - 1) > 1e-4 for x in s):
            flag("sc", f"{ob.name}: unapplied scale {m['scale']}")
        if s.x * s.y * s.z < 0:
            errors.append(f"{ob.name}: negative scale (flips normals on export)")
        m["materials"] = len(ob.material_slots)
        if any(sl.material is None for sl in ob.material_slots) or not ob.material_slots:
            warnings.append(f"{ob.name}: missing/empty material slot")
        arm_mod = next((md for md in ob.modifiers if md.type == "ARMATURE" and md.object), None)
        if arm_mod and ob.vertex_groups:
            deform = {b.name for b in arm_mod.object.data.bones if b.use_deform}
            gidx = {g.index for g in ob.vertex_groups if g.name in deform}
            unweighted = over4 = 0
            for v in ob.data.vertices:
                ws = [g for g in v.groups if g.group in gidx and g.weight > 1e-4]
                unweighted += not ws
                over4 += len(ws) > 4
            m["unweighted_verts"], m["verts_over_4_influences"] = unweighted, over4
            if unweighted:
                flag("wt", f"{ob.name}: {unweighted} verts with no deform weights")
            if over4:
                flag("wt", f"{ob.name}: {over4} verts with >4 bone influences")
        if uv:
            bm_l = bmesh.new()
            bm_l.from_mesh(ob.data)
            m.update(_uv_stats(ob, bm_l))
            bm_l.free()
            if m["uv_maps"] == 0:
                flag("uv", f"{ob.name}: no UV map")
            else:
                if m["uv_zero_area_faces"]:
                    flag("uv", f"{ob.name}: {m['uv_zero_area_faces']} zero-area UV faces")
                if m["uv_oob_pct"] > 0 and profile == "roblox":
                    flag("uv", f"{ob.name}: {m['uv_oob_pct']}% UVs outside 0-1")
                if m["uv_overlap_pct"] > 5:
                    warnings.append(f"{ob.name}: ~{m['uv_overlap_pct']}% UV overlap (ok only if mirrored/stacked on purpose; bakes break)")
        bm.free()
        if m["inside_out_islands"]:
            flag("inv", f"{ob.name}: {m['inside_out_islands']} closed parts with normals pointing inward")
        if m["inconsistent_normals_edges"]:
            flag("inc", f"{ob.name}: {m['inconsistent_normals_edges']} edges with inconsistent face winding")
        if m["nonmanifold_edges"] or m["wire_edges"]:
            flag("nm", f"{ob.name}: non-manifold edges={m['nonmanifold_edges']} wire={m['wire_edges']}")
        if m["boundary_edges"]:
            flag("bd", f"{ob.name}: {m['boundary_edges']} open boundary edges (not watertight)")
        if m["degenerate_faces"] or m["zero_length_edges"]:
            flag("dg", f"{ob.name}: degenerate faces={m['degenerate_faces']} zero-len edges={m['zero_length_edges']}")
        if m["duplicate_verts"] or m["loose_verts"]:
            flag("dup", f"{ob.name}: duplicate verts={m['duplicate_verts']} loose verts={m['loose_verts']}")
        if m["ngons"]:
            flag("ng", f"{ob.name}: {m['ngons']} n-gons")
        lim = TRI_LIMIT.get(profile)
        if lim and m["tris"] > lim:
            errors.append(f"{ob.name}: {m['tris']} tris > {profile} limit {lim}")
        per[ob.name] = m

    if len(tris) > max_tris:
        warnings.append(f"{len(tris)} tris > max_tris {max_tris}: z-fighting/floating checks skipped")
        return _result(errors, warnings, per, min_z, tol, [], [], [])

    bvh = BVHTree.FromPolygons(verts, tris, epsilon=0.0)
    tri_sets = [set(t) for t in tris]
    for ti, (_, g, _) in enumerate(tri_meta):
        island_info[g]["tris"].append(ti)

    zf_pairs, contact_pairs = set(), set()
    for ti, t in enumerate(tris):
        a, b, c = (verts[i] for i in t)
        n = tri_meta[ti][2]
        if n.length < 0.5:
            continue
        cen = (a + b + c) / 3
        for p in (cen, cen.lerp(a, .6), cen.lerp(b, .6), cen.lerp(c, .6)):
            for _, _, tj, _ in bvh.find_nearest_range(p, eps):
                if tj is None or tj == ti or tri_sets[ti] & tri_sets[tj]:
                    continue
                n2 = tri_meta[tj][2]
                d = n.dot(n2)
                if abs(d) < 0.999:
                    continue
                a2, b2, c2 = (verts[i] for i in tris[tj])
                q = p - n2 * n2.dot(p - a2)
                if _point_in_tri(q, a2, b2, c2, n2):
                    (zf_pairs if d > 0 else contact_pairs).add((min(ti, tj), max(ti, tj)))

    def _describe(pairs):
        out = Counter()
        for i, j in pairs:
            oa, ob_ = obs[tri_meta[i][0]].name, obs[tri_meta[j][0]].name
            out[f"{oa}<->{ob_}" if oa != ob_ else oa] += 1
        return [{"where": k, "tri_pairs": v} for k, v in out.most_common(20)]
    zf = _describe(zf_pairs)
    for z in zf:
        flag("zf", f"z-fighting: {z['where']} ({z['tri_pairs']} overlapping coplanar tri pairs)")
    contact = _describe(contact_pairs)
    for z in contact:
        warnings.append(f"hidden back-to-back faces: {z['where']} ({z['tri_pairs']} pairs) - delete to save tris")

    floating, enclosed = [], []
    if len(island_info) > 1:
        tri_island = [m_[1] for m_ in tri_meta]
        biggest = max(island_info, key=lambda g: island_info[g]["size"])
        for g, info in island_info.items():
            if g == biggest:
                continue
            touching = False
            vs = info["verts"]
            step = max(1, len(vs) // 400)
            for vi in vs[::step]:
                for _, _, tj, _ in bvh.find_nearest_range(verts[vi], tol):
                    if tj is not None and tri_island[tj] != g:
                        touching = True
                        break
                if touching:
                    break
            if not touching and info["tris"]:
                sub = BVHTree.FromPolygons(verts, [tris[t] for t in info["tris"]], epsilon=0.0)
                touching = any(tri_island[j] != g for _, j in sub.overlap(bvh))
            if touching:
                continue
            org, hits, d = info["center"], 0, Vector((0.137, 0.271, 0.953)).normalized()
            p = org.copy()
            for _ in range(64):
                loc, _, tj, _ = bvh.ray_cast(p, d)
                if loc is None:
                    break
                if tri_island[tj] != g:
                    hits += 1
                p = loc + d * 1e-5
            rec = {"object": info["ob"], "island_verts": len(vs), "center": rnd(tuple(info["center"]), 3)}
            (enclosed if hits % 2 == 1 else floating).append(rec)
    for f in floating:
        flag("fl", f"floating/detached part in {f['object']} ({f['island_verts']} verts at {f['center']})")
    if enclosed:
        warnings.append(f"{len(enclosed)} parts fully enclosed, not touching (eyes/internals?): {[e['object'] for e in enclosed][:5]}")
    return _result(errors, warnings, per, min_z, tol, zf, floating, contact, enclosed)


def _result(errors, warnings, per, min_z, tol, zf, floating, contact, enclosed=()):
    ground = None if min_z == math.inf else round(min_z, 4)
    if ground is not None and abs(ground) > max(tol, 1e-3):
        warnings.append(f"asset lowest point z={ground} (not resting on ground plane z=0)")
    return {"pass": not errors, "errors": errors, "warnings": warnings, "ground_z": ground, "zfighting": zf,
            "floating": floating, "back_to_back": contact, "enclosed": list(enclosed), "objects": per}


def main(argv=None):
    args = parse_args(script_args(sys.argv if argv is None else argv))
    if bpy is None:
        print("error: run inside Blender: blender -b file.blend --python-exit-code 2 --python blender_qa.py -- --objects ...", file=sys.stderr)
        return 2
    try:
        result = run(**vars(args))
    except (KeyError, ValueError) as error:
        print(f"error: {error}", file=sys.stderr)
        return 2
    if args.json:
        print(json.dumps(result, separators=(",", ":"), default=str))
    else:
        for e in result["errors"]:
            print("ERROR", e)
        for w in result["warnings"]:
            print("WARNING", w)
        tris = {name: m["tris"] for name, m in result["objects"].items()}
        print(f"Summary: {'pass' if result['pass'] else 'FAIL'}, {len(result['errors'])} errors, "
              f"{len(result['warnings'])} warnings, tris {tris}")
    sys.stdout.flush()
    return exit_status(result, args.strict)


if __name__ == "__main__":
    sys.exit(main())
