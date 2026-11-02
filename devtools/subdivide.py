#!/usr/bin/env python3
"""Smooth-subdivides the KayKit character models for a rounder, higher-poly look,
keeping skins and animations. Run from the project root:
    python3 devtools/subdivide.py [levels]
Each triangle becomes four; new points are bent outward along the averaged surface
normals (Phong tessellation), and their skin weights are blended from the edge's
ends. Writes <name>_hd.glb next to each source .glb (so external textures resolve).
"""
import json, struct, sys
import numpy as np

SOURCES = [
    "assets/kaykit/adventures/Barbarian.glb", "assets/kaykit/adventures/Knight.glb",
    "assets/kaykit/adventures/Mage.glb", "assets/kaykit/adventures/Rogue.glb",
    "assets/kaykit/adventures/Rogue_Hooded.glb",
    "assets/kaykit/skeletons/Skeleton_Mage.glb", "assets/kaykit/skeletons/Skeleton_Minion.glb",
    "assets/kaykit/skeletons/Skeleton_Rogue.glb", "assets/kaykit/skeletons/Skeleton_Warrior.glb",
]
# How strongly new points bulge toward the smooth surface (0 = flat split, 1 = full).
ALPHA = 0.75

CTYPE = {5120: np.int8, 5121: np.uint8, 5122: np.int16, 5123: np.uint16, 5125: np.uint32, 5126: np.float32}
NCOMP = {"SCALAR": 1, "VEC2": 2, "VEC3": 3, "VEC4": 4, "MAT4": 16}


def read_glb(path):
    data = open(path, "rb").read()
    off, chunks = 12, []
    while off < len(data):
        length, kind = struct.unpack_from("<II", data, off)
        chunks.append((kind, data[off + 8: off + 8 + length]))
        off += 8 + length
    gltf = json.loads(chunks[0][1])
    binary = bytearray(chunks[1][1]) if len(chunks) > 1 else bytearray()
    return gltf, binary


def write_glb(path, gltf, binary):
    while len(binary) % 4:
        binary.append(0)
    gltf["buffers"][0]["byteLength"] = len(binary)
    js = json.dumps(gltf, separators=(",", ":")).encode()
    js += b" " * ((4 - len(js) % 4) % 4)
    total = 12 + 8 + len(js) + 8 + len(binary)
    with open(path, "wb") as f:
        f.write(struct.pack("<III", 0x46546C67, 2, total))
        f.write(struct.pack("<II", len(js), 0x4E4F534A) + js)
        f.write(struct.pack("<II", len(binary), 0x004E4942) + bytes(binary))


def read_acc(gltf, binary, i):
    a = gltf["accessors"][i]
    bv = gltf["bufferViews"][a["bufferView"]]
    dt = np.dtype(CTYPE[a["componentType"]])
    n = NCOMP[a["type"]]
    start = bv.get("byteOffset", 0) + a.get("byteOffset", 0)
    stride = bv.get("byteStride", dt.itemsize * n)
    if stride == dt.itemsize * n:
        arr = np.frombuffer(binary, dtype=dt, count=a["count"] * n, offset=start).reshape(a["count"], n)
    else:
        arr = np.stack([np.frombuffer(binary, dtype=dt, count=n, offset=start + k * stride) for k in range(a["count"])])
    arr = arr.astype(np.float64) if a["componentType"] == 5126 else arr.copy()
    if a.get("normalized") and a["componentType"] != 5126:
        arr = arr.astype(np.float64) / np.iinfo(dt).max
    return arr


def add_acc(gltf, binary, arr, ctype, kind, target=None, minmax=False):
    while len(binary) % 4:
        binary.append(0)
    raw = np.ascontiguousarray(arr.astype(CTYPE[ctype])).tobytes()
    view = {"buffer": 0, "byteOffset": len(binary), "byteLength": len(raw)}
    if target:
        view["target"] = target
    binary.extend(raw)
    gltf["bufferViews"].append(view)
    acc = {"bufferView": len(gltf["bufferViews"]) - 1, "componentType": ctype,
           "count": int(arr.shape[0]), "type": kind}
    if minmax:
        acc["min"] = arr.min(axis=0).tolist()
        acc["max"] = arr.max(axis=0).tolist()
    gltf["accessors"].append(acc)
    return len(gltf["accessors"]) - 1


def subdivide(pos, nrm, uv, joints, weights, tris):
    # Smooth normals per geometric position (shared across UV/hard-edge seams), so
    # both copies of a seam edge bend the same way and the surface stays closed.
    keys = np.round(pos, 5)
    _, group = np.unique(keys, axis=0, return_inverse=True)
    group = group.reshape(-1)
    smooth = np.zeros((group.max() + 1, 3))
    np.add.at(smooth, group, nrm)
    smooth /= np.maximum(np.linalg.norm(smooth, axis=1, keepdims=True), 1e-9)
    sn = smooth[group]

    edges = np.concatenate([tris[:, [0, 1]], tris[:, [1, 2]], tris[:, [2, 0]]])
    e_sorted = np.sort(edges, axis=1)
    uniq, inv = np.unique(e_sorted, axis=0, return_inverse=True)
    inv = inv.reshape(-1)
    a, b = uniq[:, 0], uniq[:, 1]
    mid = (pos[a] + pos[b]) / 2.0
    # Phong tessellation: project the midpoint onto each end's tangent plane, average.
    pa = mid - np.sum((mid - pos[a]) * sn[a], axis=1, keepdims=True) * sn[a]
    pb = mid - np.sum((mid - pos[b]) * sn[b], axis=1, keepdims=True) * sn[b]
    new_pos = (1 - ALPHA) * mid + ALPHA * (pa + pb) / 2.0
    new_nrm = nrm[a] + nrm[b]
    new_nrm /= np.maximum(np.linalg.norm(new_nrm, axis=1, keepdims=True), 1e-9)
    new_uv = (uv[a] + uv[b]) / 2.0 if uv is not None else None
    new_j = new_w = None
    if joints is not None:
        new_j = np.zeros((len(a), 4), dtype=joints.dtype)
        new_w = np.zeros((len(a), 4))
        for k in range(len(a)):
            acc = {}
            for v in (a[k], b[k]):
                for j, w in zip(joints[v], weights[v]):
                    if w > 0:
                        acc[int(j)] = acc.get(int(j), 0.0) + w * 0.5
            top = sorted(acc.items(), key=lambda t: -t[1])[:4]
            s = sum(w for _, w in top) or 1.0
            for slot, (j, w) in enumerate(top):
                new_j[k, slot] = j
                new_w[k, slot] = w / s
    n0 = len(pos)
    m = (inv + n0).reshape(3, -1).T  # midpoints of edges (0-1, 1-2, 2-0) per triangle
    t0, t1, t2 = tris[:, 0], tris[:, 1], tris[:, 2]
    m01, m12, m20 = m[:, 0], m[:, 1], m[:, 2]
    out_tris = np.concatenate([
        np.stack([t0, m01, m20], 1), np.stack([m01, t1, m12], 1),
        np.stack([m20, m12, t2], 1), np.stack([m01, m12, m20], 1)])
    cat = lambda x, y: np.concatenate([x, y]) if x is not None else None
    return (cat(pos, new_pos), cat(nrm, new_nrm), cat(uv, new_uv), cat(joints, new_j),
            cat(weights, new_w), out_tris)


def process(path, levels):
    gltf, binary = read_glb(path)
    before = after = 0
    for mesh in gltf["meshes"]:
        for prim in mesh["primitives"]:
            if prim.get("mode", 4) != 4 or "indices" not in prim:
                continue
            at = prim["attributes"]
            pos = read_acc(gltf, binary, at["POSITION"])
            nrm = read_acc(gltf, binary, at["NORMAL"])
            uv = read_acc(gltf, binary, at["TEXCOORD_0"]) if "TEXCOORD_0" in at else None
            joints = read_acc(gltf, binary, at["JOINTS_0"]) if "JOINTS_0" in at else None
            weights = read_acc(gltf, binary, at["WEIGHTS_0"]) if "WEIGHTS_0" in at else None
            tris = read_acc(gltf, binary, prim["indices"]).reshape(-1, 3).astype(np.int64)
            before += len(tris)
            for _ in range(levels):
                pos, nrm, uv, joints, weights, tris = subdivide(pos, nrm, uv, joints, weights, tris)
            after += len(tris)
            at["POSITION"] = add_acc(gltf, binary, pos, 5126, "VEC3", 34962, minmax=True)
            at["NORMAL"] = add_acc(gltf, binary, nrm, 5126, "VEC3", 34962)
            if uv is not None:
                at["TEXCOORD_0"] = add_acc(gltf, binary, uv, 5126, "VEC2", 34962)
            if joints is not None:
                at["JOINTS_0"] = add_acc(gltf, binary, joints, 5123, "VEC4", 34962)
                at["WEIGHTS_0"] = add_acc(gltf, binary, weights, 5126, "VEC4", 34962)
            prim["indices"] = add_acc(gltf, binary, tris.reshape(-1, 1), 5125, "SCALAR", 34963)
    out = path[:-4] + "_hd.glb"
    write_glb(out, gltf, binary)
    print(f"{out}: {before} -> {after} triangles")


if __name__ == "__main__":
    lv = int(sys.argv[1]) if len(sys.argv) > 1 else 1
    for src in SOURCES:
        process(src, lv)
