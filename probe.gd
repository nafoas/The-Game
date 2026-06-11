extends SceneTree
## Asset probe — run headless, prints which textures/models/sounds load.
## godot --headless --script res://probe.gd

const TEXTURES := [
	# road / ground
	"res://materials/concrete/forest_road01.vtf",
	"res://materials/concrete/forest_road01a.vtf",
	"res://materials/nature/dirtroad001a.vtf",
	"res://materials/nature/dirtroad001b.vtf",
	"res://materials/concrete/blendroad_broken01.vmt",
	# sidewalk / concrete floors
	"res://materials/concrete/concretefloor028a.vtf",
	"res://materials/concrete/concretefloor028a_normal.vtf",
	"res://materials/concrete/concretefloor028c.vtf",
	"res://materials/concrete/concretefloor028d.vtf",
	"res://materials/concrete/concretefloor033a.vtf",
	"res://materials/concrete/concretefloor033a_normal.vtf",
	"res://materials/concrete/concretefloor033k.vtf",
	"res://materials/concrete/concretefloor033o.vtf",
	"res://materials/concrete/concretefloor033q.vtf",
	"res://materials/concrete/concretefloor033y.vtf",
	"res://materials/concrete/concretefloor039a.vtf",
	"res://materials/concrete/concretefloor039b.vtf",
	"res://materials/concrete/concrete_modular_floor001d.vtf",
	# plaza
	"res://materials/stone/cobble08a.vtf",
	"res://materials/stone/cobble08a_normal.vtf",
	"res://materials/stone/cobble08b.vtf",
	"res://materials/stone/stonefloor006b.vtf",
	"res://materials/stone/stonefloor006d.vtf",
	# walls
	"res://materials/plaster/plasterwall008a.vtf",
	"res://materials/plaster/plasterwall009a.vtf",
	"res://materials/plaster/plasterwall011b.vtf",
	"res://materials/plaster/plasterwall014a.vtf",
	"res://materials/plaster/plasterwall051b.vtf",
	"res://materials/plaster/plasterwall052a.vtf",
	"res://materials/plaster/plasterwall053a.vtf",
	"res://materials/plaster/cellarwall01b.vtf",
	"res://materials/concrete/concretewall075a.vtf",
	"res://materials/concrete/concretewall075b.vtf",
	"res://materials/concrete/concretewall076a.vtf",
	"res://materials/concrete/ep2_concretewall01a.vtf",
	"res://materials/concrete/ep2_concretewall01c.vtf",
	"res://materials/concrete/indust_concretewall01a.vtf",
	"res://materials/concrete/concrete_modular_wall001e.vtf",
	"res://materials/concrete/concretewall_inn01a.vtf",
	# wood
	"res://materials/wood/ep2_woodfloor01.vtf",
	"res://materials/wood/ep2_woodfloor02.vtf",
	"res://materials/wood/woodfloor002.vtf",
	"res://materials/wood/woodwall035a.vtf",
	"res://materials/wood/woodwall047a.vtf",
	"res://materials/wood/woodceiling003a.vtf",
	"res://materials/wood/woodfence001.vtf",
	"res://materials/wood/shingles003.vtf",
	"res://materials/wood/shingles005.vtf",
	"res://materials/wood/wooddoor010a.vtf",
	# metal
	"res://materials/metal/bunker_metalwall01a.vtf",
	"res://materials/metal/forest_metal01a.vtf",
	"res://materials/metal/forest_metal_02a.vtf",
	"res://materials/metal/forest_metal_03a.vtf",
	"res://materials/metal/metal_emergencystripe01a.vtf",
	"res://materials/metal/metalbeam001a.vtf",
	"res://materials/metal/metaldoor043b.vtf",
	# dirt
	"res://materials/nature/dirtfloor004a.vtf",
	"res://materials/nature/dirtfloor012a.vtf",
	"res://materials/nature/dirtfloor012a_normal.vtf",
	"res://materials/nature/dirtfloor_mine001a.vtf",
	"res://materials/nature/forest_dirt_01.vtf",
	"res://materials/nature/forest_gravel_01.vtf",
	# tile
	"res://materials/tile/tilefloor010b.vtf",
	"res://materials/tile/tilefloor010b_normal.vtf",
	"res://materials/tile/tilewall009e.vtf",
	"res://materials/tile/tilewall009h.vtf",
	# glass
	"res://materials/glass/ep2_window01.vtf",
]

const MODELS := [
	# vehicles
	"res://models/props_vehicles/car001b_hatchback.mdl",
	"res://models/props_vehicles/truck001a.mdl",
	"res://models/props_vehicles/van001a_nodoor.mdl",
	# street junk
	"res://models/props_lab/scrapyarddumpster_static.mdl",
	"res://models/props_c17/oildrum_crush.mdl",
	"res://models/props_junk/propane_tank001a.mdl",
	"res://models/props_junk/wood_spool01.mdl",
	"res://models/props_junk/bicycle01a.mdl",
	"res://models/props_junk/gnome.mdl",
	"res://models/props_junk/ibeam01b_cluster01.mdl",
	"res://models/props_wasteland/barricade001a.mdl",
	"res://models/props_wasteland/barricade002a.mdl",
	"res://models/props_wasteland/exterior_fence_notbarbed002a.mdl",
	"res://models/props_wasteland/exterior_fence_notbarbed002b.mdl",
	"res://models/props_wasteland/interior_fence002d.mdl",
	"res://models/props_wasteland/interior_fence004b.mdl",
	"res://models/props_debris/concrete_section64floor001a.mdl",
	"res://models/props_debris/walldestroyed02a.mdl",
	"res://models/props_debris/walldestroyed09a.mdl",
	"res://models/props_debris/rebar002a_32.mdl",
	"res://models/props_c17/lockers001a.mdl",
	"res://models/props_c17/furnitureshelf002a.mdl",
	"res://models/props_c17/chair_stool01a.mdl",
	"res://models/props_c17/powerbox.mdl",
	"res://models/props_c17/light_industrialbell01_on.mdl",
	"res://models/props_c17/metalladder004.mdl",
	"res://models/props_c17/truss02a.mdl",
	"res://models/props_c17/pillarcluster_001b.mdl",
	"res://models/props_c17/canister_propane01a.mdl",
	"res://models/props_c17/display_cooler01a.mdl",
	"res://models/props_c17/gate_door03.mdl",
	"res://models/props_c17/door01_left.mdl",
	"res://models/props_c17/hospital_bed01.mdl",
	"res://models/props_c17/clock01.mdl",
	"res://models/props_interiors/lightsconce01.mdl",
	"res://models/props_interiors/radiator01a.mdl",
	"res://models/props_forest/floodlight.mdl",
	"res://models/props_forest/footlocker01_closed.mdl",
	"res://models/props_forest/bunkbed.mdl",
	"res://models/props_forest/furniture_shelf01a.mdl",
	"res://models/props_forest/fence_border_256.mdl",
	"res://models/props_lab/citizenradio.mdl",
	"res://models/props_lab/reciever01b.mdl",
	"res://models/props_lab/reciever01d.mdl",
	"res://models/props_lab/monitor01b.mdl",
	"res://models/props_lab/monitor02.mdl",
	"res://models/props_lab/frame002a.mdl",
	"res://models/props_mining/diesel_generator.mdl",
	"res://models/props_outland/generator_static01a.mdl",
	"res://models/props_explosive/explosive_butane_can.mdl",
	"res://models/items/ammocrate_pistol.mdl",
	"res://models/items/ammocrate_smg2.mdl",
	"res://models/items/item_beacon_crate.mdl",
	"res://models/props_silo/desk_console1.mdl",
	"res://models/props_silo/desk_console2.mdl",
	"res://models/props_silo/equipment1.mdl",
	"res://models/props_silo/industriallight01.mdl",
	"res://models/props_silo/fuel_cask.mdl",
	"res://models/props_silo/handtruck.mdl",
	"res://models/props_silo/acunit01.mdl",
	"res://models/props_silo/chimneycluster01.mdl",
	"res://models/props_foliage/bush2.mdl",
	"res://models/props_foliage/fallentree_dry01.mdl",
	"res://models/props_foliage/grass_cluster01.mdl",
	"res://models/props_rooftop/attic_window.mdl",
	"res://models/props_radiostation/radio_antenna01.mdl",
	# characters
	"res://models/alyx.mdl",
	"res://models/barney.mdl",
	"res://models/eli.mdl",
	"res://models/gman.mdl",
	"res://models/kleiner.mdl",
	"res://models/magnusson.mdl",
	"res://models/mossman.mdl",
	"res://models/vortigaunt.mdl",
	"res://models/zombie/classic.mdl",
	"res://models/zombie/zombie_soldier.mdl",
	"res://models/stalker.mdl",
	"res://models/headcrab.mdl",
	"res://models/skeleton/skeleton_whole.mdl",
	# weapons
	"res://models/weapons/w_alyx_gun.mdl",
	"res://models/weapons/w_combine_sniper.mdl",
	"res://models/weapons/w_grenade.mdl",
	"res://models/weapons/v_magnade.mdl",
]

const SOUNDS := [
	"res://sounds/ambient/ambience/wind_light02_loop.wav",
	"res://sounds/ambient/ambience/waterlap_loop.wav",
	"res://sounds/ambient/levels/caves/rumble1.wav",
	"res://sounds/ambient/levels/caves/rumble2.wav",
	"res://sounds/ambient/levels/caves/rumble3.wav",
	"res://sounds/ambient/levels/caves/cave_howl_loop1.wav",
	"res://sounds/ambient/levels/caves/cave_heen_loop1.wav",
	"res://sounds/ambient/levels/city/citadel_winds_loop1.wav",
	"res://sounds/ambient/levels/city/citadel_nearwinds_loop1.wav",
	"res://sounds/ambient/levels/city/zombidoorscrapeloop01.wav",
	"res://sounds/npc/zombine/gear1.wav",
	"res://sounds/npc/zombine/gear2.wav",
	"res://sounds/npc/zombine/gear3.wav",
	"res://sounds/npc/combine_soldier/zipline_hitground1.wav",
	"res://sounds/npc/combine_soldier/zipline_hitground2.wav",
	"res://sounds/npc/combine_soldier/zipline_clothing1.wav",
	"res://sounds/npc/combine_soldier/zipline_clothing2.wav",
	"res://sounds/weapons/alyx_gun/alyx_gun_fire3.wav",
	"res://sounds/weapons/alyx_gun/alyx_gun_fire4.wav",
	"res://sounds/weapons/alyx_gun/alyx_gun_fire5.wav",
	"res://sounds/weapons/alyx_gun/alyx_gun_fire6.wav",
	"res://sounds/weapons/pistol/pistol_reload1.wav",
	"res://sounds/weapons/alyx_gun/alyx_shotgun_cock1.wav",
	"res://sounds/ambient/levels/citadel/citadel_breakershut1.wav",
	"res://sounds/ambient/levels/citadel/datatransrandom01.wav",
	"res://sounds/ambient/levels/citadel/citadel_sickdrone_loop1.wav",
	"res://sounds/ambient/levels/launch/warningsfx01_loop.wav",
	"res://sounds/ambient/levels/intro/rhumble_2_12_13.wav",
	"res://sounds/ambient/levels/intro/doorimpact01.wav",
	"res://sounds/ambient/levels/forest/buzz1.wav",
	"res://sounds/npc/turret_floor/detonate.wav",
	"res://sounds/ambient/energy/newspark01.wav",
	"res://sounds/ambient/energy/newspark02.wav",
	"res://music/menu_theme.mp3",
	"res://music/level_01_ambient.mp3",
	"res://music/cutscene_01.mp3",
	"res://voice/commander/briefing_01.mp3",
]


func _initialize() -> void:
	print("=== TEXTURE PROBE ===")
	for path in TEXTURES:
		var ok := false
		var info := ""
		if ResourceLoader.exists(path):
			var res: Resource = load(path)
			if res is Texture2D:
				var t := res as Texture2D
				ok = true
				info = "%dx%d" % [t.get_width(), t.get_height()]
			elif res is Material:
				ok = true
				info = "MATERIAL " + res.get_class()
				var bm := res as BaseMaterial3D
				if bm != null and bm.albedo_texture != null:
					info += " albedo=%dx%d" % [bm.albedo_texture.get_width(), bm.albedo_texture.get_height()]
			elif res != null:
				info = "OTHER " + res.get_class()
		print("%s | %s | %s" % ["OK " if ok else "FAIL", path, info])

	print("=== MODEL PROBE ===")
	for path in MODELS:
		var line: String = "FAIL | " + path
		if ResourceLoader.exists(path):
			var res: Resource = load(path)
			if res is PackedScene:
				var inst: Node = (res as PackedScene).instantiate()
				if inst != null:
					var aabb := _merged_aabb(inst)
					var nmesh := _count_meshes(inst)
					if nmesh > 0 and aabb.size.length() > 0.0001:
						line = "OK   | %s | meshes=%d size=(%.2f, %.2f, %.2f) pos=(%.2f, %.2f, %.2f)" % [
							path, nmesh, aabb.size.x, aabb.size.y, aabb.size.z,
							aabb.position.x, aabb.position.y, aabb.position.z]
					else:
						line = "EMPTY| %s | meshes=%d" % [path, nmesh]
					inst.free()
		print(line)

	print("=== SOUND PROBE ===")
	for path in SOUNDS:
		var ok := false
		var info := ""
		if ResourceLoader.exists(path):
			var res: Resource = load(path)
			if res is AudioStream:
				ok = true
				info = "len=%.2fs" % (res as AudioStream).get_length()
		print("%s | %s | %s" % ["OK " if ok else "FAIL", path, info])

	print("=== PROBE DONE ===")
	quit(0)


func _merged_aabb(node: Node) -> AABB:
	var result := AABB()
	var first := true
	var stack: Array = [[node, Transform3D.IDENTITY]]
	while stack.size() > 0:
		var entry: Array = stack.pop_back()
		var n: Node = entry[0]
		var xform: Transform3D = entry[1]
		if n is Node3D:
			xform = xform * (n as Node3D).transform
		if n is MeshInstance3D:
			var mi := n as MeshInstance3D
			if mi.mesh != null:
				var ab := xform * mi.mesh.get_aabb()
				if first:
					result = ab
					first = false
				else:
					result = result.merge(ab)
		for child in n.get_children():
			stack.append([child, xform])
	return result


func _count_meshes(node: Node) -> int:
	var count := 0
	var stack: Array = [node]
	while stack.size() > 0:
		var n: Node = stack.pop_back()
		if n is MeshInstance3D and (n as MeshInstance3D).mesh != null:
			count += 1
		for child in n.get_children():
			stack.append(child)
	return count
