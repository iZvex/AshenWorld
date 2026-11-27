extends RefCounted

# Локальный профиль ASHEN WORLD: JSON в user://, контрольная сумма, версия
# формата, миграция v6/v7→v8, состояние режимов, резервная копия и атомарная
# замена основного файла. Никаких сетевых зависимостей и секретов: профиль
# целиком офлайн.

const SaveCatalog = preload("res://scripts/save/save_catalog.gd")
const ModeCatalog = preload("res://scripts/campaign/mode_catalog.gd")

const FORMAT_LABEL: String = "ashenworld-profile"
const FNV_OFFSET: int = 2166136261
const FNV_PRIME: int = 16777619

var balance: Dictionary = {}
var format_version: int = 8
var profile_path: String = "user://ashenworld_profile.json"
var temp_path: String = "user://ashenworld_profile.tmp"
var backup_path: String = "user://ashenworld_profile.bak"
var max_bytes: int = 1048576


func _init(data: Dictionary, path: String = "") -> void:
	balance = data
	format_version = SaveCatalog.format_version(balance)
	profile_path = path if path != "" else SaveCatalog.profile_path(balance)
	temp_path = _derive_path(SaveCatalog.temp_suffix(balance))
	backup_path = _derive_path(SaveCatalog.backup_suffix(balance))
	max_bytes = SaveCatalog.max_profile_bytes(balance)


func _derive_path(suffix: String) -> String:
	if profile_path.ends_with(".json"):
		return profile_path.substr(0, profile_path.length() - 5) + suffix
	return profile_path + suffix


static func _absolute_path(path: String) -> String:
	return ProjectSettings.globalize_path(path) if path.begins_with("user://") else path


static func _canonical_value(value: Variant) -> Variant:
	# JSON не различает целые и дробные числа: после чтения все числа становятся
	# float. Приводим целочисленные значения к одному виду до подписи и записи,
	# иначе контрольная сумма файла изменилась бы после перезапуска игры.
	match typeof(value):
		TYPE_FLOAT:
			var number: float = float(value)
			if not is_nan(number) and not is_inf(number) and number == floori(number) and absf(number) < 9007199254740992.0:
				return int(number)
			return number
		TYPE_DICTIONARY:
			var result: Dictionary = {}
			for key in (value as Dictionary).keys():
				result[str(key)] = _canonical_value((value as Dictionary)[key])
			return result
		TYPE_ARRAY:
			var result: Array = []
			for item in (value as Array):
				result.append(_canonical_value(item))
			return result
	return value


static func canonical_envelope(envelope: Dictionary) -> Dictionary:
	return _canonical_value(envelope) as Dictionary


static func canonical_text(envelope: Dictionary) -> String:
	var copy: Dictionary = canonical_envelope(envelope)
	copy.erase("checksum")
	return JSON.stringify(copy, "", true)


static func checksum_for(envelope: Dictionary) -> String:
	var value: int = FNV_OFFSET
	for byte in canonical_text(envelope).to_utf8_buffer():
		value = ((value ^ int(byte)) * FNV_PRIME) & 0xffffffff
	return "%08x" % value


static func build_envelope(payload: Dictionary, saved_at: int, version: int) -> Dictionary:
	var envelope: Dictionary = {
		"format": FORMAT_LABEL,
		"version": maxi(1, version),
		"saved_at": maxi(0, saved_at),
		"checksum": "",
		"payload": payload.duplicate(true),
	}
	envelope["checksum"] = checksum_for(envelope)
	return envelope


static func store_envelope(envelope: Dictionary, path: String) -> bool:
	var absolute: String = _absolute_path(path)
	var file: FileAccess = FileAccess.open(absolute, FileAccess.WRITE)
	if file == null:
		return false
	file.store_string(JSON.stringify(canonical_envelope(envelope), "\t", true))
	file.flush()
	file.close()
	return true


static func status_text(status: String) -> String:
	match status:
		"new":
			return "создан"
		"loaded":
			return "загружен"
		"migrated":
			return "обновлён"
		"recovered":
			return "восстановлен"
		"corrupted":
			return "повреждён"
		"future":
			return "будущей версии"
	return "неизвестен"


func file_paths() -> Dictionary:
	return {
		"main": profile_path,
		"temp": temp_path,
		"backup": backup_path,
	}


func clear_files() -> void:
	for path in [temp_path, backup_path, profile_path]:
		var absolute: String = _absolute_path(str(path))
		if FileAccess.file_exists(absolute):
			DirAccess.remove_absolute(absolute)


func normalize_payload(payload: Dictionary, source_version: int, saved_at: int) -> Dictionary:
	var result: Dictionary = payload.duplicate(true)
	var profile_value: Variant = result.get("profile", {})
	var profile_source: Dictionary = profile_value.duplicate(true) if profile_value is Dictionary else {}
	if result.has("settings"):
		var top_value: Variant = result.get("settings", {})
		if top_value is Dictionary:
			var existing_value: Variant = profile_source.get("settings", {})
			var merged: Dictionary = existing_value.duplicate(true) if existing_value is Dictionary else {}
			for key in (top_value as Dictionary).keys():
				if not merged.has(str(key)):
					merged[str(key)] = (top_value as Dictionary)[str(key)]
			profile_source["settings"] = merged
	var profile: Dictionary = SaveCatalog.normalize_profile(profile_source, saved_at, balance)
	result["profile"] = profile
	result.erase("settings")
	result["highest_stage"] = maxi(1, int(result.get("highest_stage", 1)))
	result["modes"] = ModeCatalog.state_from_snapshot(result, balance, int(result.get("highest_stage", 1)))
	result.erase("active_mode")
	result.erase("mode_index")
	if source_version < format_version:
		result["balance_version"] = int(balance.get("version", 0))
		result["migrated_from"] = source_version
	else:
		result["balance_version"] = int(result.get("balance_version", balance.get("version", 0)))
	result["profile_version"] = format_version
	return result


func _parse_envelope(path: String) -> Dictionary:
	var absolute: String = _absolute_path(path)
	if not FileAccess.file_exists(absolute):
		return {"valid": false, "reason": "Файл отсутствует"}
	var text: String = FileAccess.get_file_as_string(absolute)
	if text.to_utf8_buffer().size() > max_bytes:
		return {"valid": false, "reason": "Файл сохранения слишком большой"}
	# Используем экземпляр JSON: статический parse_string выводит ERROR в лог
	# для намеренно повреждённых файлов, а точечной проверке нужен чистый лог.
	var parser: JSON = JSON.new()
	if parser.parse(text) != OK or not parser.data is Dictionary:
		return {"valid": false, "reason": "Некорректный JSON"}
	var envelope: Dictionary = parser.data as Dictionary
	if str(envelope.get("format", "")) != FORMAT_LABEL:
		return {"valid": false, "reason": "Неизвестный формат сохранения"}
	var version: int = int(envelope.get("version", 0))
	if version > format_version:
		return {"valid": false, "reason": "Версия сохранения новее игры", "future": true}
	if version < 1:
		return {"valid": false, "reason": "Некорректная версия сохранения"}
	if str(envelope.get("checksum", "")) != checksum_for(envelope):
		return {"valid": false, "reason": "Контрольная сумма не совпадает"}
	var payload_value: Variant = envelope.get("payload", {})
	if not payload_value is Dictionary:
		return {"valid": false, "reason": "Полезные данные повреждены"}
	var saved_at: int = maxi(0, int(envelope.get("saved_at", 0)))
	var payload: Dictionary = normalize_payload(payload_value as Dictionary, version, saved_at)
	return {
		"valid": true,
		"reason": "",
		"envelope": envelope,
		"payload": payload,
		"version": version,
		"saved_at": saved_at,
		"migrated": version < format_version,
	}


func load_profile() -> Dictionary:
	var main_absolute: String = _absolute_path(profile_path)
	var backup_absolute: String = _absolute_path(backup_path)
	var main: Dictionary = _parse_envelope(main_absolute)
	if bool(main.get("valid", false)):
		return {
			"success": true,
			"status": "migrated" if bool(main.get("migrated", false)) else "loaded",
			"message": "Профиль загружен",
			"source": "main",
			"payload": main["payload"] as Dictionary,
			"saved_at": int(main["saved_at"]),
			"version": int(main["version"]),
			"migrated": bool(main["migrated"]),
		}
	var backup: Dictionary = _parse_envelope(backup_absolute)
	if bool(backup.get("valid", false)):
		var restored: bool = store_envelope(backup["envelope"] as Dictionary, profile_path)
		return {
			"success": true,
			"status": "recovered",
			"message": "Профиль восстановлен из резервной копии",
			"source": "backup",
			"payload": backup["payload"] as Dictionary,
			"saved_at": int(backup["saved_at"]),
			"version": int(backup["version"]),
			"migrated": bool(backup.get("migrated", false)),
			"restored": restored,
		}
	if not FileAccess.file_exists(main_absolute) and not FileAccess.file_exists(backup_absolute):
		return {
			"success": false,
			"status": "new",
			"message": "Создан новый локальный профиль",
			"source": "new",
			"payload": {},
			"saved_at": 0,
		}
	return {
		"success": false,
		"status": "corrupted" if not bool(main.get("future", false)) else "future",
		"message": str(main.get("reason", "Профиль повреждён")),
		"source": "none",
		"payload": {},
		"saved_at": 0,
	}


func save_profile(payload: Dictionary, now_unix: int = -1) -> Dictionary:
	var now: int = now_unix if now_unix >= 0 else int(Time.get_unix_time_from_system())
	var normalized: Dictionary = normalize_payload(payload, format_version, now)
	var envelope: Dictionary = build_envelope(normalized, now, format_version)
	var main_absolute: String = _absolute_path(profile_path)
	var temp_absolute: String = _absolute_path(temp_path)
	var backup_absolute: String = _absolute_path(backup_path)

	var main_check: Dictionary = _parse_envelope(main_absolute)
	if FileAccess.file_exists(main_absolute) and bool(main_check.get("future", false)):
		return {"success": false, "reason": "Нельзя перезаписать сохранение будущей версии", "saved_at": now}

	if FileAccess.file_exists(temp_absolute):
		DirAccess.remove_absolute(temp_absolute)
	if not store_envelope(envelope, temp_path):
		return {"success": false, "reason": "Не удалось записать временный файл", "saved_at": now}
	var temp_check: Dictionary = _parse_envelope(temp_absolute)
	if not bool(temp_check.get("valid", false)):
		DirAccess.remove_absolute(temp_absolute)
		return {"success": false, "reason": "Временный файл не прошёл проверку", "saved_at": now}

	var backup_updated: bool = false
	if bool(main_check.get("valid", false)):
		if FileAccess.file_exists(backup_absolute):
			DirAccess.remove_absolute(backup_absolute)
		var old_text: String = FileAccess.get_file_as_string(main_absolute)
		var backup_file: FileAccess = FileAccess.open(backup_absolute, FileAccess.WRITE)
		if backup_file == null:
			DirAccess.remove_absolute(temp_absolute)
			return {"success": false, "reason": "Не удалось обновить резервную копию", "saved_at": now}
		backup_file.store_string(old_text)
		backup_file.flush()
		backup_file.close()
		backup_updated = true

	var rename_error: int = DirAccess.rename_absolute(temp_absolute, main_absolute)
	if rename_error != OK:
		if FileAccess.file_exists(temp_absolute):
			DirAccess.remove_absolute(temp_absolute)
		return {"success": false, "reason": "Не удалось заменить основной файл", "saved_at": now}
	return {
		"success": true,
		"reason": "",
		"saved_at": now,
		"path": profile_path,
		"checksum": str(envelope.get("checksum", "")),
		"backup_updated": backup_updated,
	}
