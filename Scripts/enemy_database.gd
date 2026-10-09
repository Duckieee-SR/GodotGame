class_name EnemyDB
extends RefCounted

const FOLDER := "res://Enemies/"

static func load_enemy(id: String) -> EnemyData:
	var path := FOLDER + id + ".tres"
	if not ResourceLoader.exists(path):
		push_error("Inimigo não encontrado: " + path)
		return null
	return load(path) as EnemyData

static func all_ids() -> Array[String]:
	var ids: Array[String] = []
	var dir := DirAccess.open(FOLDER)
	if dir == null:
		return ids
	dir.list_dir_begin()
	var f := dir.get_next()
	while f != "":
		if f.ends_with(".tres"):
			ids.append(f.get_basename())
		f = dir.get_next()
	dir.list_dir_end()
	return ids
