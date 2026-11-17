extends RefCounted
# Gestor de emergencias (v26). No dibuja nada: guarda los incidentes, el mantenimiento y el historial,
# calcula las lecturas a partir del estado REAL del juego y aplica las consecuencias.
# La pantalla esta en diag_ui.gd y los datos en emergency_data.gd.
#
# Estados de un incidente: detected -> investigating -> diagnosing -> intervention -> (resuelto | fallido) y pasa al historial.
# Los incidentes ambientales (llamarada, tormenta de polvo) no tienen diagnostico: se prepara uno antes de que llegue.

const Data = preload("res://emergency_data.gd")
const MAINT_START: float = 92.0
const MED_ADVICE_MINS: int = 10
const MAT_NAMES: Dictionary = {"scrap": "chatarra", "polymer": "polímero", "circuits": "circuitos"}
const TOOL_NAMES: Dictionary = {"patch": "kit de parche", "medkit": "botiquín", "repair": "reparador de circuitos", "filter": "filtro de polvo"}

var g: Node = null                 # main.gd (el juego)
var active: Array = []             # incidentes en curso
var history: Array = []            # incidentes cerrados (persistente)
var maint: Dictionary = {}         # condicion de cada sistema, 0-100
var seq: int = 0
var report: Dictionary = {}        # ultimo informe, pendiente de mostrar al jugador
var cnt: Dictionary = {}           # estadisticas para la futura evaluacion final


func reset() -> void:
	active = []
	history = []
	seq = 0
	report = {}
	cnt = {"spawned": 0, "resolved": 0, "partial": 0, "failed": 0, "wrong_diag": 0, "wrong_iv": 0, "consults": 0, "preventive": 0}
	maint = {}
	for s in Data.SYS_ORDER:
		maint[s] = MAINT_START


# ---------------------------------------------------------------- mantenimiento y riesgo

func cond(sys: String) -> float:
	return clampf(float(maint.get(sys, MAINT_START)), 0.0, 100.0)


# Multiplicador de la probabilidad de averias de un sistema: 0,5 si esta impecable, 1,0 hacia el 67 %, 2,0 si esta destruido.
func risk(sys: String) -> float:
	return 0.5 + 1.5 * (1.0 - cond(sys) / 100.0)


func add_maint(sys: String, amt: float) -> void:
	if maint.has(sys):
		maint[sys] = clampf(float(maint[sys]) + amt, 0.0, 100.0)


func daily() -> void:
	var k: float = float(g._diff()["drain"])
	var base: Dictionary = {"life": 2.0, "power": 2.2, "water": 2.4, "filters": 1.2, "ext": 1.4}
	for s in base:
		add_maint(s, -float(base[s]) * k)


func on_eva() -> void:
	add_maint("filters", -2.5)
	add_maint("ext", -1.5)


func on_station_action(i: int) -> void:
	if Data.ACTION_MAINT.has(i):
		add_maint(str(Data.ACTION_MAINT[i]), 8.0)
		if i == 0:
			add_maint("filters", 4.0)


func preventive(sys: String) -> void:
	add_maint(sys, 25.0)
	cnt["preventive"] = int(cnt.get("preventive", 0)) + 1


# Averias por desgaste: un sistema descuidado puede fallar solo, y es mas probable cuanto peor esta.
func wear_failures(rng: RandomNumberGenerator) -> Array:
	var out: Array = []
	var ev: float = float(g._diff()["events"])
	var table: Array = [["life", "oxygen"], ["power", "power"], ["water", "water"], ["filters", "oxygen"]]
	for e in table:
		var c: float = cond(str(e[0]))
		if c < 35.0 and not has_kind(str(e[1])):
			var p: float = (35.0 - c) / 35.0 * 0.30 * (0.6 + ev)
			if rng.randf() < p:
				out.append({"kind": str(e[1]), "sys": str(e[0])})
				break
	return out


# ---------------------------------------------------------------- consulta de incidentes

func find(id: int) -> Dictionary:
	for inc in active:
		if int(inc["id"]) == id:
			return inc
	return {}


func has_kind(kind: String) -> bool:
	for inc in active:
		if str(inc["kind"]) == kind:
			return true
	return false


func has_active() -> bool:
	return not active.is_empty()


func is_env(inc: Dictionary) -> bool:
	return str(inc["cat"]) == "env"


func has_diag_step(inc: Dictionary) -> bool:
	return not is_env(inc)


func name_of(inc: Dictionary) -> String:
	return Lang.t(str(Data.kind_def(str(inc["kind"]))["name"]))


func diff_i() -> int:
	return int(g.difficulty)


# ---------------------------------------------------------------- crear incidentes

func _pick_cause(kind: String, rng: RandomNumberGenerator) -> String:
	match kind:
		"oxygen":
			var wf: float = 1.0 + (100.0 - cond("filters")) / 50.0
			return "filter" if rng.randf() * (wf + 1.0) < wf else "sensor"
		"power":
			var w: Array = [2.0 * (1.0 + (100.0 - cond("power")) / 50.0), 1.2, 1.2 + (0.8 if g.storm_left > 0 else 0.0)]
			var r: float = rng.randf() * (w[0] + w[1] + w[2])
			if r < w[0]:
				return "circuit"
			if r < w[0] + w[1]:
				return "overload"
			return "panel"
		"water":
			return "leak" if rng.randf() < 0.5 else "recycler"
	return ""


# opts: cause (forzar la causa), silent (no avisar), sev
func spawn(kind: String, rng: RandomNumberGenerator, opts: Dictionary = {}) -> Dictionary:
	var kd: Dictionary = Data.kind_def(kind)
	if kd.is_empty() or has_kind(kind):
		return {}
	if bool(kd.get("mars", false)) and str(g.location) != "Marte":
		return {}
	var sys: String = str(kd["sys"])
	var inc: Dictionary = {
		"id": 0, "kind": kind, "cat": str(kd["cat"]), "sys": sys, "state": "detected",
		"day": int(g.day), "clock": int(g.clock), "elapsed": 0, "sev": 1, "cause": "",
		"consulted": [], "hyps": [], "wrong": [], "diag": "", "diag_wrong": 0,
		"iv": "", "iv_wrong": 0, "mins": 0, "used": {}, "mit": 1.0, "pending": "",
		"advised": false, "perm1": [], "perm2": [], "case": -1, "deadline": -1, "esc": false, "wear": bool(opts.get("wear", false))
	}
	seq += 1
	inc["id"] = seq
	var c: float = cond(sys) if sys != "crew" else 100.0
	inc["sev"] = int(opts.get("sev", 1 + (1 if c < 50.0 else 0) + (1 if c < 25.0 else 0)))
	inc["cause"] = str(opts.get("cause", _pick_cause(kind, rng)))
	var dm: float = Data.DEADLINE_MULT[diff_i()]
	match kind:
		"oxygen":
			if str(inc["cause"]) == "filter":
				maint["filters"] = minf(cond("filters"), 28.0)   # coherente con la lectura: el filtro esta saturado
		"flare":
			inc["deadline"] = int(Data.FLARE_MINS[diff_i()])
		"storm":
			inc["deadline"] = rng.randi_range(600, 1080)
		"medical":
			inc["deadline"] = int(2880.0 * dm)
			var cases: Array = (load("res://minigame_data.gd") as GDScript).call("cases")
			inc["case"] = rng.randi_range(0, cases.size() - 1)
			var cs: Dictionary = cases[int(inc["case"])]
			inc["perm1"] = _perm((cs["o1"] as Array).size(), rng)
			inc["perm2"] = _perm((cs["o2"] as Array).size(), rng)
			inc["cause"] = "h0"
	if kind == "oxygen" or kind == "power" or kind == "water":
		inc["deadline"] = int(1440.0 * dm)   # tras este plazo la averia se agrava (solo una vez)
	if has_diag_step(inc):
		inc["hyps"] = _hyp_ids(inc, rng)
	active.append(inc)
	cnt["spawned"] = int(cnt.get("spawned", 0)) + 1
	if not bool(opts.get("silent", false)):
		g.call("_emg_on_spawn", inc)
	return inc


func _perm(n: int, rng: RandomNumberGenerator) -> Array:
	var a: Array = []
	for i in n:
		a.append(i)
	for i in range(n - 1, 0, -1):
		var j: int = rng.randi_range(0, i)
		var t: int = a[i]
		a[i] = a[j]
		a[j] = t
	return a


func _hyp_ids(inc: Dictionary, rng: RandomNumberGenerator) -> Array:
	var n: int = int(Data.HYP_COUNT[diff_i()])
	if str(inc["kind"]) == "medical":
		var out: Array = []
		for idx in inc["perm1"]:
			if out.size() < n or int(idx) == 0:
				out.append("h" + str(int(idx)))
		# si la correcta quedo fuera, la ultima se reemplaza por ella
		if not out.has("h0"):
			out[out.size() - 1] = "h0"
		return out
	return Data.hypothesis_ids(str(inc["kind"]), str(inc["cause"]), n, rng)


# ---------------------------------------------------------------- textos de hipotesis, causas e intervenciones

func _case(inc: Dictionary) -> Dictionary:
	var cases: Array = (load("res://minigame_data.gd") as GDScript).call("cases")
	return cases[clampi(int(inc["case"]), 0, cases.size() - 1)]


func hyp_text(inc: Dictionary, hid: String) -> String:
	if str(inc["kind"]) == "medical":
		return str((_case(inc)["o1"] as Array)[int(hid.substr(1))])
	return Lang.t(str(Data.KINDS[str(inc["kind"])]["causes"][hid]["n"]))


func hyp_no(inc: Dictionary, hid: String) -> String:
	if str(inc["kind"]) == "medical":
		return Lang.t("Esa opción no explica bien los síntomas.") + " " + str(_case(inc)["h1"])
	return Lang.t(str(Data.KINDS[str(inc["kind"])]["causes"][hid]["no"]))


# Intervenciones que se ofrecen tras el diagnostico (las de la causa correcta + la que "parece buena y no lo es")
func ivs(inc: Dictionary) -> Array:
	var out: Array = []
	var kind: String = str(inc["kind"])
	if kind == "medical":
		var cs: Dictionary = _case(inc)
		for idx in inc["perm2"]:
			var i: int = int(idx)
			var o: Dictionary = {"id": "t" + str(i), "n": str((cs["o2"] as Array)[i]), "fixes": (["h0"] if i == 0 else []), "mins": 30, "q": ("full" if i == 0 else "none")}
			if i == 0:
				o["d"] = Lang.t("Lo aplica la Dra. Yarisbel. Necesita el botiquín.")
				o["tool"] = "medkit"
			else:
				o["d"] = Lang.t("Un tratamiento que no corresponde puede empeorar las cosas.")
				o["fx"] = {"morale": -6}
			out.append(o)
		out.append({"id": "rest", "n": Lang.t("Reposo e hidratación, sin botiquín"), "d": Lang.t("No cura del todo, pero ayuda mientras fabricas un botiquín. Lleva 2 horas."), "fixes": [], "mins": 120, "q": "partial"})
		return out
	var cause: String = str(inc["cause"])
	for iv in (Data.KINDS[kind]["ivs"] as Array):
		var fx: Array = iv.get("fixes", [])
		if is_env(inc) or fx.has(cause) or fx.is_empty():
			out.append(iv)
	return out


func iv_by_id(inc: Dictionary, iv_id: String) -> Dictionary:
	for iv in ivs(inc):
		if str(iv["id"]) == iv_id:
			return iv
	return {}


func needs_text(iv: Dictionary) -> String:
	var miss: Array = []
	var needs: Dictionary = iv.get("needs", {})
	for k in needs:
		if int(g.inv.get(k, 0)) < int(needs[k]):
			miss.append("%d %s" % [int(needs[k]), Lang.t(str(MAT_NAMES.get(k, k)))])
	var tl: String = str(iv.get("tool", ""))
	if tl != "" and int(g.tools.get(tl, 0)) <= 0:
		miss.append(Lang.t(str(TOOL_NAMES.get(tl, tl))))
	return ", ".join(miss)


func iv_mins(inc: Dictionary, iv: Dictionary) -> int:
	var m: float = float(iv.get("mins", 0))
	if has_diag_step(inc) and int(inc["diag_wrong"]) == 0 and str(inc["diag"]) != "":
		m *= 0.85   # diagnosticar bien a la primera permite trabajar con mas eficiencia
	return int(round(m))


func steps_needed(inc: Dictionary) -> int:
	return int(Data.MIN_CONSULTS[diff_i()])


func state_index(inc: Dictionary) -> int:
	match str(inc["state"]):
		"detected":
			return 0
		"investigating":
			return 1
		"diagnosing":
			return 2
		_:
			return 3


func can_diagnose(inc: Dictionary) -> bool:
	return has_diag_step(inc) and (inc["consulted"] as Array).size() >= steps_needed(inc) and str(inc["diag"]) == ""


func can_intervene(inc: Dictionary) -> bool:
	if is_env(inc):
		return true
	return str(inc["diag"]) != ""


func remaining(inc: Dictionary) -> int:
	if int(inc["deadline"]) < 0:
		return -1
	return maxi(0, int(inc["deadline"]) - int(inc["elapsed"]))


# ---------------------------------------------------------------- acciones del jugador

# Consultar un instrumento: cuesta tiempo de juego segun la dificultad. Devuelve false si el juego no esta disponible.
func consult(inc: Dictionary, key: String) -> bool:
	var cons: Array = inc["consulted"]
	if cons.has(key):
		return true
	var cost: int = int(Data.CONSULT_MINS[diff_i()])
	if key == "ask":
		cost = MED_ADVICE_MINS
	cons.append(key)
	cnt["consults"] = int(cnt.get("consults", 0)) + 1
	if str(inc["state"]) == "detected":
		inc["state"] = "investigating"
	if can_diagnose(inc) and str(inc["state"]) == "investigating":
		inc["state"] = "diagnosing"
	inc["mins"] = int(inc["mins"]) + cost
	if cost > 0:
		g.call("_emg_spend", cost)
	return true


func ask_advice(inc: Dictionary) -> String:
	if bool(inc["advised"]):
		return _advice_text(inc)
	inc["advised"] = true
	inc["mins"] = int(inc["mins"]) + MED_ADVICE_MINS
	g.call("_emg_spend", MED_ADVICE_MINS)
	return _advice_text(inc)


func _advice_text(inc: Dictionary) -> String:
	if str(inc["kind"]) == "medical":
		return Lang.t("Dra. Yarisbel: «Fíjate en esto:»") + " " + str(_case(inc)["h1"])
	return Lang.t(str(Data.KINDS[str(inc["kind"])]["advice"]))


# Elegir una hipotesis. Devuelve {ok, text}.
func choose_hyp(inc: Dictionary, hid: String) -> Dictionary:
	if str(inc["diag"]) != "":
		return {"ok": true, "text": ""}
	if hid == str(inc["cause"]):
		inc["diag"] = hid
		inc["state"] = "intervention"
		var okt: String = _why_ok(inc)
		return {"ok": true, "text": okt}
	(inc["wrong"] as Array).append(hid)
	inc["diag_wrong"] = int(inc["diag_wrong"]) + 1
	cnt["wrong_diag"] = int(cnt.get("wrong_diag", 0)) + 1
	var pen: int = int(Data.WRONG_DIAG_MINS[diff_i()])
	inc["mins"] = int(inc["mins"]) + pen
	if pen > 0:
		g.call("_emg_spend", pen)
	return {"ok": false, "text": hyp_no(inc, hid), "mins": pen}


func _why_ok(inc: Dictionary) -> String:
	if str(inc["kind"]) == "medical":
		return str(_case(inc)["w1"])
	return Lang.t(str(Data.KINDS[str(inc["kind"])]["causes"][str(inc["cause"])]["why"]))


# Gasta los materiales y deja la intervencion "pendiente" (se completa al terminar el tiempo de trabajo).
func commit_iv(inc: Dictionary, iv: Dictionary) -> void:
	var needs: Dictionary = iv.get("needs", {})
	var used: Dictionary = inc["used"]
	for k in needs:
		g.inv[k] = int(g.inv[k]) - int(needs[k])
		used[k] = int(used.get(k, 0)) + int(needs[k])
	var tl: String = str(iv.get("tool", ""))
	if tl != "":
		g.tools[tl] = int(g.tools[tl]) - 1
		used[tl] = int(used.get(tl, 0)) + 1
	inc["pending"] = str(iv["id"])
	inc["mins"] = int(inc["mins"]) + iv_mins(inc, iv)
	if is_env(inc):
		inc["mit"] = float(inc["mit"]) * float(iv.get("mit", 1.0))
		for k in iv.get("fx", {}):
			g._add(k, float(iv["fx"][k]))
	g._refresh()


# Termina la intervencion pendiente: aplica el efecto real en el juego. Devuelve el informe si el incidente se cerro.
func finish_iv(inc: Dictionary) -> Dictionary:
	var iv_id: String = str(inc["pending"])
	inc["pending"] = ""
	if iv_id == "":
		return {}
	inc["iv"] = iv_id
	var iv: Dictionary = iv_by_id(inc, iv_id)
	if iv.is_empty():
		return {}
	if is_env(inc):
		inc["state"] = "intervention"
		if not (inc["consulted"] as Array).has("done_" + iv_id):
			(inc["consulted"] as Array).append("done_" + iv_id)
		return {}
	var kind: String = str(inc["kind"])
	var cause: String = str(inc["cause"])
	var q: String = str(iv.get("q", "none"))
	var fixes: Array = iv.get("fixes", [])
	if not fixes.has(cause) or q == "none":
		# intervencion equivocada: pierdes tiempo y recursos y el problema sigue
		inc["iv_wrong"] = int(inc["iv_wrong"]) + 1
		cnt["wrong_iv"] = int(cnt.get("wrong_iv", 0)) + 1
		for k in iv.get("fx", {}):
			g._add(k, float(iv["fx"][k]))
		if kind == "medical":
			g.ill_days = int(g.ill_days) + 1
		g.call("_emg_log", Lang.t("[color=orange]La intervención no resolvió el problema: las lecturas siguen anormales.[/color]"))
		inc["state"] = "intervention"
		return {}
	_apply_fix(inc, iv_id, q)
	return close(inc, "partial" if q == "partial" else "resolved", iv)


func _apply_fix(inc: Dictionary, iv_id: String, q: String) -> void:
	var kind: String = str(inc["kind"])
	var cause: String = str(inc["cause"])
	match kind:
		"oxygen":
			match cause:
				"leak":
					g.breach = false
					g.call("_efx", "sealed")   # v41: la tripulacion lo celebra
					if q == "full":
						g._add("shield", 10)
						add_maint("ext", 5.0)
					else:
						add_maint("ext", -10.0)
						g._add("morale", -3)
				"filter":
					maint["filters"] = maxf(cond("filters"), 85.0)
					add_maint("life", 5.0)
				"sensor":
					add_maint("life", 10.0)
		"power":
			match cause:
				"circuit":
					if q == "full":
						maint["power"] = maxf(cond("power"), 75.0)
					else:
						add_maint("power", -8.0)
				"overload":
					add_maint("power", 6.0)
				"panel":
					add_maint("power", 18.0)
		"water":
			match cause:
				"leak":
					if q == "full":
						maint["water"] = maxf(cond("water"), 75.0)
					else:
						add_maint("water", -10.0)
				"recycler":
					if iv_id == "fix_recycler":
						maint["water"] = maxf(cond("water"), 85.0)
					else:
						add_maint("water", 15.0)
		"medical":
			if q == "partial":
				g.ill_days = mini(int(g.ill_days), 1)
				g._add("morale", 4)
			else:
				g.ill_days = 0
				g._add("morale", 20)
				g.call("_emg_log", Lang.t("[color=lime]La Dra. Yarisbel aplica el tratamiento con el botiquín: el tripulante se recupera (+20 moral).[/color]"))


# ---------------------------------------------------------------- tiempo, consecuencias de ignorar y plazos

func extra_drain() -> Dictionary:
	var out: Dictionary = {}
	for inc in active:
		var kd: Dictionary = Data.kind_def(str(inc["kind"]))
		var dr: Dictionary = kd.get("drain", {})
		var c: String = str(inc["cause"])
		if dr.has(c):
			var f: float = 1.0 + 0.35 * float(int(inc["sev"]) - 1)
			if bool(inc["esc"]):
				f *= 1.4
			for r in (dr[c] as Dictionary):
				out[r] = float(out.get(r, 0.0)) + float((dr[c] as Dictionary)[r]) * f
	return out


func tick(step: int) -> void:
	var closed: Array = []
	for inc in active:
		inc["elapsed"] = int(inc["elapsed"]) + step
		var dl: int = int(inc["deadline"])
		if dl < 0 or int(inc["elapsed"]) < dl:
			continue
		if is_env(inc):
			closed.append(inc)
		elif str(inc["kind"]) == "medical":
			closed.append(inc)
		elif not bool(inc["esc"]):
			inc["esc"] = true
			g.call("_emg_log", Lang.t("[color=red]La avería sin resolver se agrava: «%s».[/color]") % name_of(inc))
	for inc in closed:
		_deadline(inc)


func _deadline(inc: Dictionary) -> void:
	var kind: String = str(inc["kind"])
	var mit: float = float(inc["mit"])
	if kind == "flare":
		var dmg: float = 15.0 * mit
		g._add("shield", -dmg)
		if mit >= 1.0:
			g._add("morale", -4)
		g.call("_emg_log", Lang.t("[color=orange]La oleada de radiación llega a la base (-%d escudo).[/color]") % int(round(dmg)))
		close(inc, "resolved" if mit < 1.0 else "failed", {})
	elif kind == "storm":
		g.call("_emg_storm_hit", mit)
		add_maint("filters", -8.0)
		close(inc, "resolved" if mit < 1.0 else "failed", {})
	elif kind == "medical":
		g.ill_days = mini(int(g.ill_days), 1)
		g._add("morale", -6)
		g.call("_emg_log", Lang.t("[color=orange]El tripulante mejora despacio por sí solo, sin tratamiento adecuado (-6 moral).[/color]"))
		close(inc, "failed", {})


# ---------------------------------------------------------------- lecturas (reflejan el estado real)

func _ln(t: String, s: String) -> Dictionary:
	return {"t": t, "s": s}


func _f1(x: float) -> String:
	var s: String = "%.1f" % x
	return s if Lang.is_en() else s.replace(".", ",")


func _cond_status(c: float) -> String:
	return "ok" if c >= 60.0 else ("warn" if c >= 35.0 else "bad")


func _o2_rates(inc: Dictionary) -> Array:
	var dk: float = float(g._drain_k())
	var base: float = float(g.BASE_DRAIN["oxygen"]) * dk * (1.0 - float(g.STATION_DRAIN_CUT) * float(g.st_lvl.get("O", 0)))
	var extra: float = 0.0
	if str(inc["cause"]) == "leak" and g.breach:
		extra = float(g.BREACH_OXY) * dk
	else:
		extra = float(extra_drain().get("oxygen", 0.0)) * dk
	return [base, extra]


func readings(inc: Dictionary, key: String) -> Array:
	var kind: String = str(inc["kind"])
	var cause: String = str(inc["cause"])
	var hrs: float = float(inc["elapsed"]) / 60.0
	var out: Array = []
	match key:
		"pressure":
			if cause == "leak":
				var p: float = 101.3 - minf(9.0, 1.2 + 0.7 * hrs)
				out.append(_ln(Lang.t("Presión de HAB-01: %s kPa") % _f1(p), "bad"))
				out.append(_ln(Lang.t("Rango operativo (simulación): 98 a 103 kPa. Está por debajo."), "bad"))
			elif cause == "sensor":
				out.append(_ln(Lang.t("Sensor A: 94,1 kPa (bajo)  ·  Sensor B: 101,3 kPa (normal)"), "warn"))
			else:
				out.append(_ln(Lang.t("Presión de HAB-01: 101,2 kPa (normal)"), "ok"))
		"o2":
			var r: Array = _o2_rates(inc)
			out.append(_ln(Lang.t("Oxígeno disponible: %d %%") % int(round(float(g.res["oxygen"]))), "ok" if float(g.res["oxygen"]) >= 40.0 else "warn"))
			out.append(_ln(Lang.t("Consumo medido: -%d %% al día (esperado: -%d %% al día)") % [int(round(float(r[0]) + float(r[1]))), int(round(float(r[0])))], "bad" if float(r[1]) > 0.5 else "ok"))
		"co2":
			if cause == "filter":
				out.append(_ln(Lang.t("CO₂ del aire: 0,9 % (alto; normal: menos de 0,5 %)"), "bad"))
			else:
				out.append(_ln(Lang.t("CO₂ del aire: 0,3 % (normal)"), "ok"))
		"sensors":
			if cause == "leak":
				out.append(_ln(Lang.t("Los sensores A y B coinciden: presión baja."), "bad"))
			elif cause == "sensor":
				out.append(_ln(Lang.t("Los sensores A y B NO coinciden entre sí."), "warn"))
			else:
				out.append(_ln(Lang.t("Los sensores A y B coinciden: presión normal."), "ok"))
		"filters":
			var fc: float = cond("filters")
			out.append(_ln(Lang.t("Estado de los filtros de aire: %d %%") % int(round(fc)), _cond_status(fc)))
		"grid":
			if cause == "overload":
				out.append(_ln(Lang.t("Carga de la red: 121 % de su capacidad (sobrecarga)"), "bad"))
			elif cause == "circuit":
				out.append(_ln(Lang.t("Carga de la red: 64 % de su capacidad (normal)"), "ok"))
			else:
				out.append(_ln(Lang.t("Carga de la red: 70 % de su capacidad (normal)"), "ok"))
		"gen":
			var expect: int = 60 if g._solar_penalty() else 100
			var meas: int = int(round(float(expect) * (0.5 if cause == "panel" else 0.96)))
			out.append(_ln(Lang.t("Generación esperada hoy: %d %% (noche lunar, tormenta de polvo o noche marciana la reducen)") % expect, "ok"))
			out.append(_ln(Lang.t("Generación medida: %d %% de la nominal") % meas, "bad" if cause == "panel" else "ok"))
		"lines":
			if cause == "circuit":
				out.append(_ln(Lang.t("Línea 3 (laboratorio): cortocircuito, cortada por la protección."), "bad"))
				out.append(_ln(Lang.t("Líneas 1, 2 y 4: normales."), "ok"))
			else:
				out.append(_ln(Lang.t("Líneas 1 a 4: normales, sin cortocircuitos."), "ok"))
		"sys":
			if cause == "circuit":
				out.append(_ln(Lang.t("Sin energía: invernadero y banco de trabajo."), "bad"))
			elif cause == "overload":
				out.append(_ln(Lang.t("Cortes intermitentes en varias estaciones a la vez."), "warn"))
			else:
				out.append(_ln(Lang.t("Ninguna estación averiada; la energía almacenada baja."), "warn"))
		"maint_power":
			var pc: float = cond("power")
			out.append(_ln(Lang.t("Mantenimiento del sistema eléctrico: %d %%") % int(round(pc)), _cond_status(pc)))
		"tank":
			var dk: float = float(g._drain_k())
			var base: float = float(g.BASE_DRAIN["water"]) * dk * (1.0 - float(g.STATION_DRAIN_CUT) * float(g.st_lvl.get("W", 0)))
			var ex: float = float(extra_drain().get("water", 0.0)) * dk
			out.append(_ln(Lang.t("Reserva de agua: %d %%") % int(round(float(g.res["water"]))), "ok" if float(g.res["water"]) >= 40.0 else "warn"))
			out.append(_ln(Lang.t("Balance medido: -%d %% al día (esperado: -%d %% al día)") % [int(round(base + ex)), int(round(base))], "bad" if ex > 0.5 else "ok"))
		"recycler":
			if cause == "recycler":
				out.append(_ln(Lang.t("Rendimiento del reciclador: 41 % (bajo)"), "bad"))
			else:
				out.append(_ln(Lang.t("Rendimiento del reciclador: 96 % (normal)"), "ok"))
		"pipes":
			if cause == "leak":
				out.append(_ln(Lang.t("Tramo 2 del conducto: humedad alta y presión baja."), "bad"))
			else:
				out.append(_ln(Lang.t("Conductos secos y con presión normal."), "ok"))
		"usage":
			out.append(_ln(Lang.t("Consumo de la tripulación: normal (dentro de ±5 % de lo esperado)."), "ok"))
		"maint_water":
			var wc: float = cond("water")
			out.append(_ln(Lang.t("Mantenimiento del reciclador de agua: %d %%") % int(round(wc)), _cond_status(wc)))
		"status":
			out.append(_ln(Lang.t("Moral de la tripulación: %d %%") % int(round(float(g.res["morale"]))), "ok" if float(g.res["morale"]) >= 50.0 else "warn"))
			out.append(_ln(Lang.t("Días con síntomas: %d. Sin tratamiento, la moral baja cada día.") % maxi(1, int(g.ill_days)), "warn"))
			out.append(_ln(Lang.t("Horas despierto: %d") % int(round(float(g.awake_min) / 60.0)), "ok" if int(g.awake_min) < 960 else "warn"))
		"symptoms":
			out.append(_ln(str(_case(inc)["sym"]), "warn"))
		"ask":
			out.append(_ln(_advice_text(inc), "ok"))
		"kit":
			var n: int = int(g.tools.get("medkit", 0))
			out.append(_ln(Lang.t("Botiquines disponibles: %d") % n, "ok" if n > 0 else "bad"))
			if n == 0:
				out.append(_ln(Lang.t("Sin botiquín solo puedes dar reposo. Fabrica uno con polímero y circuitos."), "warn"))
		"rad":
			var rem: int = remaining(inc)
			var tot: int = int(Data.FLARE_MINS[diff_i()])
			var lvl: float = 1.0 + 5.0 * (1.0 - float(rem) / float(maxi(tot, 1)))
			out.append(_ln(Lang.t("Radiación: %sx el nivel normal (simulación)") % _f1(lvl), "bad" if lvl > 3.0 else "warn"))
			out.append(_ln(Lang.t("La oleada llega en %d min.") % rem, "warn"))
		"shield":
			var sh: float = float(g.res["shield"])
			out.append(_ln(Lang.t("Escudo de la base: %d %%") % int(round(sh)), "ok" if sh >= 50.0 else "warn"))
		"plan":
			if kind == "flare":
				out.append(_ln(Lang.t("Sin protección, el impacto quitaría unos 15 puntos de escudo y bajaría la moral."), "warn"))
			else:
				var h: int = int(round(float(remaining(inc)) / 60.0))
				out.append(_ln(Lang.t("Tormenta prevista en unas %d horas.") % h, "warn"))
				out.append(_ln(Lang.t("Sin preparación, bajará la energía y el rendimiento solar."), "warn"))
		"solar":
			var sc: float = cond("power")
			out.append(_ln(Lang.t("Mantenimiento de los paneles y la red: %d %%") % int(round(sc)), _cond_status(sc)))
			out.append(_ln(Lang.t("Filtros de polvo en inventario: %d") % int(g.tools.get("filter", 0)), "ok" if int(g.tools.get("filter", 0)) > 0 else "warn"))
	return out


# Lecturas tras reparar (paso de verificacion)
func verify_lines(inc: Dictionary) -> Array:
	var out: Array = []
	var kind: String = str(inc["kind"])
	var cause: String = str(inc["cause"])
	match kind:
		"oxygen":
			if cause == "leak":
				out.append(Lang.t("Presión de HAB-01: 101,3 kPa (estable)"))
				out.append(Lang.t("La pérdida de oxígeno se ha detenido."))
			elif cause == "filter":
				out.append(Lang.t("CO₂ del aire: 0,3 % (normal)"))
			else:
				out.append(Lang.t("Los sensores A y B coinciden: presión normal."))
		"power":
			out.append(Lang.t("Red estable: la energía deja de caer por esta avería."))
		"water":
			out.append(Lang.t("Balance de agua normal: ya no se pierde agua por esta avería."))
		"medical":
			out.append(Lang.t("El tripulante se recupera y los síntomas ceden."))
	return out


# ---------------------------------------------------------------- cierre e historial

func _fmt_dur(m: int) -> String:
	return str(g.call("_fmt_dur", m))


func close(inc: Dictionary, result: String, iv: Dictionary) -> Dictionary:
	var kind: String = str(inc["kind"])
	var kd: Dictionary = Data.kind_def(kind)
	var cause: String = str(inc["cause"])
	var cd: Dictionary = {}
	if (kd["causes"] as Dictionary).has(cause):
		cd = kd["causes"][cause]
	var what: String
	var why: String
	var learn: String
	var tip: String
	if kind == "medical":
		var cs: Dictionary = _case(inc)
		what = str(cs["title"]) + ". " + str(cs["sym"])
		why = str(cs["w1"])
		learn = str(cs["w2"])
		tip = Lang.t("Pide ayuda a la Dra. Yarisbel en cuanto aparezcan los síntomas y ten un botiquín fabricado.")
	elif is_env(inc):
		var ls: Dictionary = kd["lesson"]
		what = Lang.t(str(ls["what"]))
		why = Lang.t(str(ls["why"]))
		learn = Lang.t(str(ls["learn"]))
		tip = Lang.t(str(ls["tip"]))
	else:
		what = Lang.t(str(cd.get("what", "")))
		why = Lang.t(str(cd.get("why", "")))
		learn = Lang.t(str(cd.get("learn", "")))
		tip = Lang.t(str(cd.get("tip", "")))
	var did: Array = []
	var nc: int = 0
	for c in (inc["consulted"] as Array):
		if not str(c).begins_with("done_"):
			nc += 1
	did.append(Lang.t("Consultaste %d instrumento(s).") % nc)
	if has_diag_step(inc):
		if int(inc["diag_wrong"]) == 0:
			did.append(Lang.t("Tu diagnóstico fue correcto a la primera."))
		else:
			did.append(Lang.t("Acertaste el diagnóstico tras %d intento(s) fallido(s); cada uno costó tiempo.") % int(inc["diag_wrong"]))
	if not iv.is_empty():
		did.append(Lang.t("Intervención: %s.") % Lang.t(str(iv["n"])))
		if str(iv.get("q", "")) == "partial":
			did.append(Lang.t("Fue una solución parcial: resuelve el problema, pero deja un costo."))
	elif is_env(inc):
		if float(inc["mit"]) < 1.0:
			did.append(Lang.t("Te preparaste antes del impacto y redujiste el daño."))
		else:
			did.append(Lang.t("No te preparaste a tiempo: recibiste el golpe completo."))
	if int(inc["iv_wrong"]) > 0:
		did.append(Lang.t("Probaste %d intervención(es) equivocada(s): perdiste tiempo y recursos.") % int(inc["iv_wrong"]))
	did.append(Lang.t("Tiempo de trabajo: %s.") % _fmt_dur(int(inc["mins"])))
	var tip2: String = tip
	if has_diag_step(inc) and int(inc["diag_wrong"]) > 0:
		tip2 += " " + Lang.t("Antes de elegir una causa, comprueba que las lecturas la respalden.")
	var hyps_out: Array = []
	if kind == "medical" or not (inc["hyps"] as Array).is_empty():
		for h in (inc["hyps"] as Array):
			var st: String = "ok" if str(h) == cause else ("wrong" if (inc["wrong"] as Array).has(h) else "seen")
			hyps_out.append({"t": hyp_text(inc, str(h)), "s": st})
	var sym: Array = [Lang.t(str(kd["alert"])), Lang.t(str(kd["intro"]))]
	for c in (inc["consulted"] as Array):
		if str(c).begins_with("done_"):
			continue
		for ln in readings(inc, str(c)):
			sym.append(str(ln["t"]))
	var entry: Dictionary = {
		"id": int(inc["id"]), "kind": kind, "name": name_of(inc), "sys": Lang.t(str(Data.SYS_NAMES.get(str(inc["sys"]), ""))),
		"day": int(inc["day"]), "clock": int(inc["clock"]), "day1": int(g.day), "clock1": int(g.clock),
		"sym": sym, "hyps": hyps_out,
		"diag": hyp_text(inc, str(inc["diag"])) if str(inc["diag"]) != "" else "",
		"iv": Lang.t(str(iv["n"])) if not iv.is_empty() else "",
		"mins": int(inc["mins"]), "used": (inc["used"] as Dictionary).duplicate(),
		"result": result, "sev": int(inc["sev"]),
		"diag_wrong": int(inc["diag_wrong"]), "iv_wrong": int(inc["iv_wrong"]),
		"lesson": {"what": what, "why": why, "did": " ".join(did), "learn": learn, "tip": tip2},
		"verify": verify_lines(inc) if result != "failed" else []
	}
	active.erase(inc)
	history.append(entry)
	report = entry
	match result:
		"resolved":
			cnt["resolved"] = int(cnt.get("resolved", 0)) + 1
		"partial":
			cnt["partial"] = int(cnt.get("partial", 0)) + 1
		_:
			cnt["failed"] = int(cnt.get("failed", 0)) + 1
	g.call("_emg_on_close", entry)
	return entry


# ---------------------------------------------------------------- guardado

func serialize() -> Dictionary:
	return {"seq": seq, "active": active.duplicate(true), "history": history.duplicate(true), "maint": maint.duplicate(), "cnt": cnt.duplicate()}


func _ints(a: Variant) -> Array:
	var out: Array = []
	if typeof(a) == TYPE_ARRAY:
		for x in (a as Array):
			out.append(int(x))
	return out


func restore(d: Dictionary) -> void:
	reset()
	seq = int(d.get("seq", 0))
	var m: Variant = d.get("maint", {})
	if typeof(m) == TYPE_DICTIONARY:
		for s in Data.SYS_ORDER:
			if (m as Dictionary).has(s):
				maint[s] = float((m as Dictionary)[s])
	var c: Variant = d.get("cnt", {})
	if typeof(c) == TYPE_DICTIONARY:
		for k in (c as Dictionary):
			cnt[k] = int((c as Dictionary)[k])
	for e in d.get("active", []):
		if typeof(e) != TYPE_DICTIONARY:
			continue
		var inc: Dictionary = e
		for k in ["id", "day", "clock", "elapsed", "sev", "mins", "case", "deadline", "diag_wrong", "iv_wrong"]:
			inc[k] = int(inc.get(k, 0))
		inc["mit"] = float(inc.get("mit", 1.0))
		inc["perm1"] = _ints(inc.get("perm1", []))
		inc["perm2"] = _ints(inc.get("perm2", []))
		var used: Dictionary = {}
		for k in (inc.get("used", {}) as Dictionary):
			used[k] = int(inc["used"][k])
		inc["used"] = used
		if not Data.KINDS.has(str(inc.get("kind", ""))) or has_kind(str(inc["kind"])):
			continue
		active.append(inc)
	for h in d.get("history", []):
		if typeof(h) == TYPE_DICTIONARY:
			var he: Dictionary = h
			for k in ["id", "day", "clock", "day1", "clock1", "mins", "sev", "diag_wrong", "iv_wrong"]:
				he[k] = int(he.get(k, 0))
			history.append(he)


# Al cargar: si el guardado se hizo en mitad de una intervencion, se completa (los materiales ya se habian gastado).
func resume_pending() -> void:
	for inc in active.duplicate():
		if str(inc["pending"]) != "":
			finish_iv(inc)
