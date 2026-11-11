extends SceneTree

const MAIN_SCENE: PackedScene = preload("res://main.tscn")
const FACTIONS := ["الأمريكي", "الصيني", "الجيش العربي", "وطن"]

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var game = MAIN_SCENE.instantiate()
	root.add_child(game)
	await process_frame

	# Verify every faction profile is explicit, complete, and deterministic.
	for army in FACTIONS:
		var profile: Dictionary = game._faction_profile(army)
		for key in ["helicopter_cost", "helicopter_damage", "helicopter_cooldown", "missile_cost", "missile_damage", "missile_cooldown", "unit_costs"]:
			if not profile.has(key):
				push_error("%s faction profile is missing %s" % [army, key])
				quit(1)
				return
		for kind in ["infantry", "tank", "builder", "artillery", "fighter"]:
			if game._unit_cost(kind, army) <= 0:
				push_error("%s has an invalid %s production cost" % [army, kind])
				quit(1)
				return
		if game._unit_cost("helicopter", army) != int(profile.helicopter_cost):
			push_error("%s helicopter cost does not match its faction profile" % army)
			quit(1)
			return
		if game._missile_cost(army) != int(profile.missile_cost):
			push_error("%s missile cost does not match its faction profile" % army)
			quit(1)
			return

	# Economic identities: Arab infantry/artillery are affordable; China has efficient armor.
	if game._unit_cost("infantry", "الجيش العربي") != 90:
		push_error("Arab infantry affordability changed unexpectedly")
		quit(1)
		return
	if game._unit_cost("artillery", "الجيش العربي") != 430:
		push_error("Arab artillery affordability changed unexpectedly")
		quit(1)
		return
	if game._unit_cost("tank", "الصيني") != 270:
		push_error("Chinese armor efficiency changed unexpectedly")
		quit(1)
		return

	# Watan must lead in battlefield output, while its full land/air reinforcement costs remain premium.
	var watan_helicopter_dps := float(game._helicopter_damage({"faction": "وطن"})) / game._helicopter_cooldown({"faction": "وطن"})
	for army in FACTIONS:
		var dps := float(game._helicopter_damage({"faction": army})) / game._helicopter_cooldown({"faction": army})
		if army != "وطن" and watan_helicopter_dps <= dps:
			push_error("Watan helicopter combat output must exceed %s" % army)
			quit(1)
			return
		if army != "وطن" and game._unit_cost("tank", "وطن") <= game._unit_cost("tank", army):
			push_error("Watan armor must retain a reinforcement cost premium over %s" % army)
			quit(1)
			return
		if army != "وطن" and game._unit_cost("fighter", "وطن") <= game._unit_cost("fighter", army):
			push_error("Watan fighters must retain a reinforcement cost premium over %s" % army)
			quit(1)
			return
		if army != "وطن" and game._unit_cost("infantry", "وطن") <= game._unit_cost("infantry", army):
			push_error("Watan infantry must retain a reinforcement cost premium over %s" % army)
			quit(1)
			return
		if army != "وطن" and game._unit_cost("artillery", "وطن") <= game._unit_cost("artillery", army):
			push_error("Watan artillery must retain a reinforcement cost premium over %s" % army)
			quit(1)
			return

	# Missile output and cooldown must follow the selected faction, not the active player's faction.
	var watan_missile_dps := float(game._missile_damage("وطن")) / game._missile_cooldown("وطن")
	for army in FACTIONS:
		if game._missile_damage(army) <= 0 or game._missile_cooldown(army) <= 0.0:
			push_error("%s has invalid missile combat parameters" % army)
			quit(1)
			return
		if army != "وطن" and watan_missile_dps <= float(game._missile_damage(army)) / game._missile_cooldown(army):
			push_error("Watan missile output must exceed %s" % army)
			quit(1)
			return

	# Transport premium and faction rotation are checked without enabling naval gameplay.
	if game._unit_cost("transport_helicopter", "وطن") <= game._unit_cost("transport_helicopter", "الأمريكي"):
		push_error("Watan transport aircraft must retain its cost premium")
		quit(1)
		return
	for index in range(FACTIONS.size()):
		game.faction = FACTIONS[index]
		if game._enemy_faction() != FACTIONS[(index + 1) % FACTIONS.size()]:
			push_error("Enemy faction rotation is not deterministic for %s" % FACTIONS[index])
			quit(1)
			return

	print("PASS: four-faction combat output, land/air reinforcement premiums, faction pricing, and enemy rotation")
	quit(0)
