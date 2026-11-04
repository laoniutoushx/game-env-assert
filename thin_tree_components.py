"""Thin disconnected leaf components while preserving their original geometry."""
import json
from pathlib import Path

import numpy as np
from scipy.sparse import coo_matrix
from scipy.sparse.csgraph import connected_components

root = Path(__file__).parent / "tree_small_02"
model = json.loads((root / "tree_small_02_prepared.gltf").read_text(encoding="utf-8"))
binary = bytearray((root / "tree_small_02.bin").read_bytes())
primitive = model["meshes"][0]["primitives"][1]
accessor = model["accessors"][primitive["indices"]]
view = model["bufferViews"][accessor["bufferView"]]
dtype = {5123: np.dtype("<u2"), 5125: np.dtype("<u4")}[accessor["componentType"]]
offset = view.get("byteOffset", 0) + accessor.get("byteOffset", 0)
tri = np.frombuffer(binary, dtype=dtype, count=accessor["count"], offset=offset).reshape(-1, 3).copy()
count = model["accessors"][primitive["attributes"]["POSITION"]]["count"]
edges_a = np.concatenate((tri[:, 0], tri[:, 1]))
edges_b = np.concatenate((tri[:, 1], tri[:, 2]))
graph = coo_matrix((np.ones(edges_a.size, dtype=np.uint8), (edges_a, edges_b)), shape=(count, count)).tocsr()
n_components, labels = connected_components(graph, directed=False)
rng = np.random.default_rng(20261029)
keep = rng.random(n_components) < 0.50
selected = tri[keep[labels[tri[:, 0]]]].reshape(-1)
print(f"leaf components={n_components}, faces {len(tri)} -> {len(selected) // 3}")
while len(binary) % 4:
    binary.append(0)
new_offset = len(binary)
binary.extend(selected.astype(dtype).tobytes())
model["bufferViews"].append({"buffer": 0, "byteOffset": new_offset, "byteLength": selected.nbytes, "target": 34963})
accessor["bufferView"] = len(model["bufferViews"]) - 1
accessor["byteOffset"] = 0
accessor["count"] = len(selected)
accessor.pop("min", None)
accessor.pop("max", None)
model["buffers"][0]["uri"] = "tree_components.bin"
model["buffers"][0]["byteLength"] = len(binary)
(root / "tree_components.bin").write_bytes(binary)
(root / "tree_components.gltf").write_text(json.dumps(model), encoding="utf-8")
