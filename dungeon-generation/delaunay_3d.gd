class_name DunDelaunay3D
extends RefCounted

# Bowyer-Watson Delaunay tetrahedralization (3D).
# Ported from https://github.com/vazgriz/DungeonGenerator (Scripts3D/Delaunay3D.cs),
# itself adapted from https://github.com/Bl4ckb0ne/delaunay-triangulation (MIT).
# Circumcircles are replaced by circumspheres (Wolfram MathWorld formula).

const _DEGEN_SCALE := 1e-6


# points: room centers in grid space.
# Returns unique edges as canonical Vector2i(min, max) index pairs.
static func triangulate(points: PackedVector3Array) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	var n := points.size()
	if n < 4:
		return out

	var verts := points.duplicate()

	var mn := Vector3(INF, INF, INF)
	var mx := Vector3(-INF, -INF, -INF)
	for p in points:
		mn = mn.min(p)
		mx = mx.max(p)
	var extent := mx - mn
	var delta_max := maxf(extent.x, maxf(extent.y, extent.z)) * 2.0

	# super tetrahedron (indices n, n+1, n+2, n+3)
	verts.append(Vector3(mn.x - 1.0, mn.y - 1.0, mn.z - 1.0))
	verts.append(Vector3(mx.x + delta_max, mn.y - 1.0, mn.z - 1.0))
	verts.append(Vector3(mn.x - 1.0, mx.y + delta_max, mn.z - 1.0))
	verts.append(Vector3(mn.x - 1.0, mn.y - 1.0, mx.z + delta_max))

	var tets: Array[Dictionary] = []
	var first := _make_tet(verts, n, n + 1, n + 2, n + 3)
	if first.is_empty():
		return out
	tets.append(first)

	for i in n:
		var p: Vector3 = verts[i]
		var bad := {}
		for ti in tets.size():
			var r2 := float(tets[ti]["r2"])
			var c := tets[ti]["c"] as Vector3
			if r2 >= 0.0 and p.distance_squared_to(c) <= r2:
				bad[ti] = true
		if bad.is_empty():
			continue

		# boundary faces = faces shared by exactly one bad tet
		var face_count := {}
		for ti in bad:
			var v: Vector4i = tets[ti]["v"]
			_count_face(face_count, v.x, v.y, v.z)
			_count_face(face_count, v.x, v.y, v.w)
			_count_face(face_count, v.x, v.z, v.w)
			_count_face(face_count, v.y, v.z, v.w)

		var keep: Array[Dictionary] = []
		for ti in tets.size():
			if not bad.has(ti):
				keep.append(tets[ti])
		tets = keep

		for key in face_count:
			if int(face_count[key]) != 1:
				continue
			var f: Vector3i = key
			var nt := _make_tet(verts, f.x, f.y, f.z, i)
			if not nt.is_empty():
				tets.append(nt)

	# drop tetrahedra touching the super tetrahedron, collect edges
	var edge_set := {}
	for t in tets:
		var v: Vector4i = t["v"]
		if v.x >= n or v.y >= n or v.z >= n or v.w >= n:
			continue
		_add_edge(edge_set, v.x, v.y)
		_add_edge(edge_set, v.y, v.z)
		_add_edge(edge_set, v.z, v.x)
		_add_edge(edge_set, v.x, v.w)
		_add_edge(edge_set, v.y, v.w)
		_add_edge(edge_set, v.z, v.w)

	for key in edge_set:
		out.append(key as Vector2i)
	return out


static func _count_face(counts: Dictionary, a: int, b: int, c: int) -> void:
	var mn := mini(a, mini(b, c))
	var mx := maxi(a, maxi(b, c))
	var mid := a + b + c - mn - mx
	var key := Vector3i(mn, mid, mx)
	counts[key] = int(counts.get(key, 0)) + 1


static func _add_edge(edges: Dictionary, a: int, b: int) -> void:
	edges[Vector2i(mini(a, b), maxi(a, b))] = true


# Returns {} on degenerate (coplanar) input, otherwise {"v": Vector4i, "c": Vector3, "r2": float}.
static func _make_tet(verts: PackedVector3Array, a: int, b: int, c: int, d: int) -> Dictionary:
	if a == b or a == c or a == d or b == c or b == d or c == d:
		return {}
	var pa := verts[a]
	var pb := verts[b]
	var pc := verts[c]
	var pd := verts[d]
	var ba := pb - pa
	var ca := pc - pa
	var da := pd - pa

	# Basis takes columns; rows of the equation system are ba, ca, da
	var basis := Basis(ba, ca, da)
	var det := basis.determinant()
	var scale := ba.length() * ca.length() * da.length()
	if scale <= 0.0 or absf(det) <= _DEGEN_SCALE * scale:
		return {}

	var rhs := Vector3(
		pb.dot(pb) - pa.dot(pa),
		pc.dot(pc) - pa.dot(pa),
		pd.dot(pd) - pa.dot(pa)
	) * 0.5
	# A = rows(ba, ca, da) = basis.transposed(); solve A * center = rhs
	var center := basis.inverse().transposed() * rhs
	var r2 := pa.distance_squared_to(center)
	if r2 < 0.0:
		return {}
	return {"v": Vector4i(a, b, c, d), "c": center, "r2": r2}
