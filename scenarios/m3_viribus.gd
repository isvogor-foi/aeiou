extends "res://scenarios/scenario.gd"
## Mission 3: Viribus Unitis. Unite the crown lands and bring the five A.E.I.O.U.
## relics home to become the Federation the shot in Sarajevo failed to stop.


func setup(w) -> void:
	start(w, 1867, "coastal", {"map_size": "normal", "start_age": 5, "resources": "high", "difficulty": "hard",
			"victories": {"territory": false, "wonders": false, "relics": true}})
	capital(w, ME).title = "Vienna (Hofburg)"


func update(w, s: Dictionary) -> void:
	if once(w, "intro"):
		say(w, "Archduke Franz Ferdinand", "Croats, Czechs, Tyroleans, Magyars: an empire of equals or no empire at all. Proclaim the crown lands and recover the relics.")
		say(w, "Chancellor", "Found new cities and proclaim them as crown lands. Federal Charters keep distant cities loyal.")
	var lands := 0
	for e in w.entities.values():
		if e.alive and e.owner == ME and w.is_city(e) and e.crown_land != "":
			lands += 1
	objective(w, "lands", "Proclaim 3 crown lands (%d/3)" % mini(lands, 3))
	if lands >= 3:
		complete(w, "lands")
	var relics: int = w.relics_stored(ME)
	objective(w, "relics", "Store the five A.E.I.O.U. relics in your cities and hold them (%d/5)" % relics)
	if relics >= 5 and once(w, "all_relics"):
		say(w, "Chancellor", "All five relics are ours! Hold them and the Federation is proclaimed.")
