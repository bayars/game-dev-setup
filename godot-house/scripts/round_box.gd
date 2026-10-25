class_name RoundBox
extends RefCounted
## Box meshes with rounded edges and corners, for walls, floors, steps and anything built in code.
## Each face is a grid whose outer rows sit on the rounded edge: a point P on the plain box is pulled
## onto a sphere of `radius` around the nearest point of the inner box (half size minus radius).

static var _cache := {}

static func clear_cache() -> void:
	_cache.clear()

static func mesh(size: Vector3, radius := 0.04, segments := 3) -> ArrayMesh:
	var key := "%s|%s|%d" % [size, radius, segments]
	if _cache.has(key):
		return _cache[key]
	var half := size / 2.0
	var r := minf(radius, minf(half.x, minf(half.y, half.z)) * 0.98)
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	# faces: normal axis, and the two in-plane axes (u, v) ordered so u x v points outwards
	for face in [[0, 1, 2], [1, 2, 0], [2, 0, 1]]:
		for sgn in [1.0, -1.0]:
			_face(st, half, r, segments, face[0], face[1], face[2], sgn)
	st.index()
	var m := st.commit()
	_cache[key] = m
	return m

## Sample positions along one axis: dense across the rounded rims, one span across the flat middle.
static func _samples(h: float, r: float, segs: int) -> PackedFloat32Array:
	var out := PackedFloat32Array()
	for i in segs + 1:
		out.append(-h + r - r * cos(PI / 2.0 * i / segs))
	for i in range(segs, -1, -1):
		var v := h - r + r * cos(PI / 2.0 * i / segs)
		if v > out[out.size() - 1] + 0.0001:
			out.append(v)
	return out

static func _face(st: SurfaceTool, half: Vector3, r: float, segs: int, n: int, u: int, v: int, sgn: float) -> void:
	var us := _samples(half[u], r, segs)
	var vs := _samples(half[v], r, segs)
	var inner := half - Vector3(r, r, r)
	var grid := []
	for a in us.size():
		var row := []
		for b in vs.size():
			var p := Vector3.ZERO
			p[n] = half[n] * sgn
			p[u] = us[a]
			p[v] = vs[b]
			var c := p.clamp(-inner, inner)
			var d := (p - c).normalized()
			row.append([c + d * r, d])
		grid.append(row)
	for a in us.size() - 1:
		for b in vs.size() - 1:
			var q := [grid[a][b], grid[a + 1][b], grid[a + 1][b + 1], grid[a][b + 1]]
			# u x v is the outward normal for sgn > 0; Godot front faces wind clockwise
			var tris := [[0, 2, 1], [0, 3, 2]] if sgn > 0 else [[0, 1, 2], [0, 2, 3]]
			for t in tris:
				for k in t:
					st.set_normal(q[k][1])
					st.add_vertex(q[k][0])
