class_name Lang
extends RefCounted
# Idioma del juego (es / en). El texto original del juego esta en espanol y se usa
# como clave: Lang.t("texto") devuelve el mismo texto en espanol o su traduccion al ingles.
# Primera ejecucion: idioma del sistema o del navegador (en* -> ingles, otro -> espanol).

const SETTINGS_PATH: String = "user://settings.cfg"
const EN_SCRIPT = preload("res://lang_en.gd")

static var code: String = _initial()
static var _en: Dictionary = {}

const SPEAKERS_EN: Dictionary = {
	"Narración": "Narration", "Dra. Yarisbel": "Dr. Yarisbel", "Ing. Enoc": "Eng. Enoc", "Com. Pam": "Cmdr. Pam",
	"Banco de trabajo": "Workbench", "Cama": "Bed",
}
const LOC_EN: Dictionary = {"Luna": "Moon", "Marte": "Mars"}


static func _initial() -> String:
	var cfg := ConfigFile.new()
	if cfg.load(SETTINGS_PATH) == OK:
		var v: String = str(cfg.get_value("game", "lang", ""))
		if v == "es" or v == "en":
			return v
	return "en" if OS.get_locale_language().to_lower().begins_with("en") else "es"


static func is_en() -> bool:
	return code == "en"


static func t(s: String) -> String:
	if code != "en":
		return s
	if _en.is_empty():
		_en = EN_SCRIPT.EN
	return _en.get(s, s)


static func speaker(who: String) -> String:
	return SPEAKERS_EN.get(who, who) if code == "en" else who


static func loc(id: String) -> String:
	return LOC_EN.get(id, id) if code == "en" else id
