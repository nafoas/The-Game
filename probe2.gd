extends SceneTree
## Probe #2: model scene structure (anim players?), music durations.

const STRUCT_MODELS := [
	"res://models/barney.mdl",
	"res://models/weapons/w_alyx_gun.mdl",
	"res://models/props_vehicles/car001b_hatchback.mdl",
]

const MUSIC := [
	"res://sounds/music/vlvx_song0.mp3",
	"res://sounds/music/vlvx_song1.mp3",
	"res://sounds/music/vlvx_song11.mp3",
	"res://sounds/music/vlvx_song12.mp3",
	"res://sounds/music/vlvx_song15.mp3",
	"res://sounds/music/vlvx_song2.mp3",
	"res://sounds/music/vlvx_song3.mp3",
	"res://sounds/music/vlvx_song23ambient.mp3",
	"res://sounds/music/vlvx_song20.mp3",
	"res://sounds/music/vlvx_song24.mp3",
	"res://sounds/music/vlvx_song25.mp3",
]


func _initialize() -> void:
	for path in STRUCT_MODELS:
		print("=== STRUCTURE: ", path)
		if ResourceLoader.exists(path):
			var ps: PackedScene = load(path) as PackedScene
			if ps != null:
				var inst := ps.instantiate()
				_dump(inst, 0)
				inst.free()

	print("=== MUSIC PROBE ===")
	for path in MUSIC:
		var ok := false
		var info := ""
		if ResourceLoader.exists(path):
			var res: Resource = load(path)
			if res is AudioStream:
				ok = true
				info = "len=%.1fs" % (res as AudioStream).get_length()
		print("%s | %s | %s" % ["OK " if ok else "FAIL", path, info])
	print("=== PROBE2 DONE ===")
	quit(0)


func _dump(node: Node, depth: int) -> void:
	var pad := ""
	for i in range(depth):
		pad += "  "
	var extra := ""
	if node is MeshInstance3D:
		var mi := node as MeshInstance3D
		if mi.mesh != null:
			extra = " surfaces=%d" % mi.mesh.get_surface_count()
			for s in range(mi.mesh.get_surface_count()):
				var m := mi.mesh.surface_get_material(s)
				extra += " mat%d=%s" % [s, m.get_class() if m != null else "null"]
	if node is Node3D:
		var n3 := node as Node3D
		extra += " scale=%s pos=%s" % [n3.scale, n3.position]
	if node is AnimationPlayer:
		var ap := node as AnimationPlayer
		var anims := ap.get_animation_list()
		extra = " anims=%d %s" % [anims.size(), str(anims.slice(0, 12))]
	print("%s- %s (%s)%s" % [pad, node.name, node.get_class(), extra])
	if depth < 4:
		for child in node.get_children():
			_dump(child, depth + 1)
