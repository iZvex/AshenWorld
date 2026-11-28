extends RefCounted

# Связывает локальный профиль с игровым состоянием: загрузка при старте,
# миграция, офлайн-награды, автосохранение и сохранение при выходе.
# Формулы и настройки читаются только через save_catalog.gd.

const SaveCatalog = preload("res://scripts/save/save_catalog.gd")
const SaveManager = preload("res://scripts/save/save_manager.gd")

var balance: Dictionary = {}
var manager
var campaign
var now_override: int = -1
var format_version: int = 8
var autosave_interval: float = 15.0
var autosave_timer: float = 0.0
var profile: Dictionary = {}
var startup_status: String = "new"
var startup_message: String = ""
var last_saved_at: int = 0
var last_save_result: Dictionary = {}
var last_offline_report: Dictionary = {}
var startup_log_lines: Array = []
var total_saves: int = 0


func _init(data: Dictionary, path: String = "", now_unix: int = -1) -> void:
	balance = data
	manager = SaveManager.new(balance, path)
	format_version = SaveCatalog.format_version(balance)
	autosave_interval = SaveCatalog.autosave_interval_seconds(balance)
	now_override = now_unix


func current_now() -> int:
	return now_override if now_override >= 0 else int(Time.get_unix_time_from_system())


func settings() -> Dictionary:
	return SaveCatalog.normalize_settings(profile.get("settings", {}), balance)


func set_setting(key: String, value: Variant) -> void:
	var current: Dictionary = settings()
	current[key] = value
	profile["settings"] = SaveCatalog.normalize_settings(current, balance)


func set_now(value: int) -> void:
	now_override = maxi(0, value)


func bootstrap(state) -> Dictionary:
	campaign = state
	var loaded: Dictionary = manager.load_profile()
	startup_status = str(loaded.get("status", "new"))
	startup_message = str(loaded.get("message", ""))
	var loaded_payload: Variant = loaded.get("payload", {})
	var loaded_profile: Variant = {}
	if loaded_payload is Dictionary:
		loaded_profile = (loaded_payload as Dictionary).get("profile", {})
	profile = SaveCatalog.normalize_profile(loaded_profile, int(loaded.get("saved_at", 0)), balance)
	if bool(loaded.get("success", false)):
		campaign.import_state(loaded_payload as Dictionary)
		last_saved_at = int(loaded.get("saved_at", 0))
		last_offline_report = collect_offline()
	else:
		profile = SaveCatalog.default_profile(current_now(), balance)
		last_saved_at = current_now()
		if startup_status == "future":
			last_save_result = {"success": false, "reason": "Сохранение будущей версии оставлено без изменений"}
		else:
			last_save_result = save("новый профиль")
	startup_log_lines = _build_startup_lines()
	return get_report()


func _build_startup_lines() -> Array:
	var lines: Array = []
	var status_label: String = SaveManager.status_text(startup_status)
	lines.append("Профиль %s · версия %d · автосохранение %d с" % [
		status_label,
		format_version,
		int(autosave_interval),
	])
	if startup_status == "recovered":
		lines.append("Основной файл повреждён, использована резервная копия")
	elif startup_status == "corrupted":
		lines.append("Сохранение не прошло проверку, начат новый профиль")
	elif startup_status == "future":
		lines.append("Сохранение будущей версии не перезаписано")
	if bool(last_offline_report.get("eligible", false)):
		lines.append(SaveCatalog.reward_text(last_offline_report))
	return lines


func collect_offline() -> Dictionary:
	if campaign == null:
		return {"eligible": false, "reason": "Состояние кампании не подключено"}
	var now: int = current_now()
	var claim_from: int = int(profile.get("last_offline_claim_at", last_saved_at))
	var report: Dictionary = SaveCatalog.offline_rewards(balance, claim_from, now, int(campaign.highest_stage))
	profile["last_seen_at"] = now
	if bool(report.get("eligible", false)):
		report["applied"] = campaign.apply_offline_rewards(report)
		profile["last_offline_claim_at"] = now
		profile["total_offline_seconds"] = int(profile.get("total_offline_seconds", 0)) + int(report.get("credited_seconds", 0))
		profile["total_offline_claims"] = int(profile.get("total_offline_claims", 0)) + 1
	elif now < claim_from:
		# Часы перевели назад: переносим точку отсчёта, чтобы время не копилось вечно.
		profile["last_offline_claim_at"] = now
	report["save"] = save("получение офлайн-наград")
	last_offline_report = report
	return report


func save(reason: String) -> Dictionary:
	if campaign == null:
		return {"success": false, "reason": "Состояние кампании не подключено"}
	var now: int = current_now()
	profile["last_seen_at"] = now
	var payload: Dictionary = campaign.export_state()
	payload["profile"] = profile.duplicate(true)
	payload["profile_version"] = format_version
	payload["balance_version"] = int(balance.get("version", 0))
	var result: Dictionary = manager.save_profile(payload, now)
	result["reason_event"] = reason
	last_save_result = result
	if bool(result.get("success", false)):
		last_saved_at = int(result.get("saved_at", now))
		total_saves += 1
	return result


func tick(delta: float) -> void:
	autosave_timer += maxf(0.0, delta)
	if autosave_timer >= autosave_interval:
		autosave_timer = 0.0
		save("автосохранение")


func on_pause() -> Dictionary:
	autosave_timer = 0.0
	return save("пауза приложения")


func on_resume() -> Dictionary:
	autosave_timer = 0.0
	var report: Dictionary = collect_offline()
	last_offline_report = report
	return report


func hint_text() -> String:
	return "Профиль %s · сохранение в память устройства каждые %d с · офлайн до %d ч" % [
		SaveManager.status_text(startup_status),
		int(autosave_interval),
		SaveCatalog.limit_hours(balance),
	]


func get_report() -> Dictionary:
	return {
		"status": startup_status,
		"status_text": SaveManager.status_text(startup_status),
		"message": startup_message,
		"saved_at": last_saved_at,
		"format_version": format_version,
		"autosave_interval": autosave_interval,
		"total_saves": total_saves,
		"offline": last_offline_report.duplicate(true),
		"save": last_save_result.duplicate(true),
		"profile": profile.duplicate(true),
		"log_lines": startup_log_lines.duplicate(true),
	}
