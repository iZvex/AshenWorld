extends RefCounted

# Единые правила шестого этапа: настройки локального профиля, лимит AFK,
# эффективность по последнему достигнутому этапу и формула офлайн-наград.
# Здесь же находятся подписи для интерфейса, чтобы не дублировать их в main.gd.

const DEFAULT_LIMIT_HOURS: float = 12.0
const DEFAULT_TICK_SECONDS: int = 300
const DEFAULT_MIN_SECONDS: int = 300
const DEFAULT_AFK_EFFICIENCY: float = 0.35
const DEFAULT_ACTIVE_EFFICIENCY: float = 1.0
const DEFAULT_STAGE_EFFICIENCY: float = 0.1
const DEFAULT_MAX_STAGE_MULTIPLIER: float = 1.5
const DEFAULT_AUTOSAVE_SECONDS: float = 15.0
const DEFAULT_FORMAT_VERSION: int = 6
const DEFAULT_MAX_PROFILE_BYTES: int = 1048576


static func save_settings(balance: Dictionary) -> Dictionary:
	var value: Variant = balance.get("save", {})
	return value as Dictionary if value is Dictionary else {}


static func afk_settings(balance: Dictionary) -> Dictionary:
	var value: Variant = balance.get("afk", {})
	return value as Dictionary if value is Dictionary else {}


static func format_version(balance: Dictionary) -> int:
	return maxi(1, int(save_settings(balance).get("format_version", DEFAULT_FORMAT_VERSION)))


static func profile_path(balance: Dictionary) -> String:
	var path: String = str(save_settings(balance).get("profile_path", "user://ashenworld_profile.json"))
	return path if path != "" else "user://ashenworld_profile.json"


static func temp_suffix(balance: Dictionary) -> String:
	var suffix: String = str(save_settings(balance).get("temp_suffix", ".tmp"))
	return suffix if suffix != "" else ".tmp"


static func backup_suffix(balance: Dictionary) -> String:
	var suffix: String = str(save_settings(balance).get("backup_suffix", ".bak"))
	return suffix if suffix != "" else ".bak"


static func max_profile_bytes(balance: Dictionary) -> int:
	return maxi(1024, int(save_settings(balance).get("max_profile_bytes", DEFAULT_MAX_PROFILE_BYTES)))


static func autosave_interval_seconds(balance: Dictionary) -> float:
	return clampf(float(save_settings(balance).get("autosave_interval_seconds", DEFAULT_AUTOSAVE_SECONDS)), 1.0, 300.0)


static func default_settings(balance: Dictionary) -> Dictionary:
	var configured: Variant = save_settings(balance).get("default_settings", {})
	var result: Dictionary = {
		"sound_enabled": true,
		"particles_enabled": true,
		"target_fps": 60,
	}
	if configured is Dictionary:
		for key in result.keys():
			result[str(key)] = (configured as Dictionary).get(str(key), result[str(key)])
	return result


static func fps_options(balance: Dictionary) -> Array:
	var configured: Variant = save_settings(balance).get("fps_options", [])
	var options: Array = []
	if configured is Array:
		for value in (configured as Array):
			var fps: int = int(value)
			if fps > 0 and not options.has(fps):
				options.append(fps)
	return options if not options.is_empty() else [30, 60, 90]


static func normalize_settings(value: Variant, balance: Dictionary) -> Dictionary:
	var result: Dictionary = default_settings(balance)
	if value is Dictionary:
		for key in result.keys():
			result[str(key)] = (value as Dictionary).get(str(key), result[str(key)])
	result["sound_enabled"] = bool(result.get("sound_enabled", true))
	result["particles_enabled"] = bool(result.get("particles_enabled", true))
	var options: Array = fps_options(balance)
	var target: int = maxi(1, int(result.get("target_fps", 60)))
	if not options.has(target):
		var closest: int = int(options[0])
		var distance: int = absi(closest - target)
		for option in options:
			var candidate: int = int(option)
			var candidate_distance: int = absi(candidate - target)
			if candidate_distance < distance:
				closest = candidate
				distance = candidate_distance
		target = closest
	result["target_fps"] = target
	return result


static func next_target_fps(balance: Dictionary, current_fps: int) -> int:
	var options: Array = fps_options(balance)
	var index: int = options.find(int(current_fps))
	return int(options[(index + 1) % options.size()]) if index >= 0 else int(options[0])


static func default_profile(created_at: int, balance: Dictionary) -> Dictionary:
	var time: int = maxi(0, created_at)
	return {
		"created_at": time,
		"last_seen_at": time,
		"last_offline_claim_at": time,
		"total_offline_seconds": 0,
		"total_offline_claims": 0,
		"settings": default_settings(balance),
	}


static func normalize_profile(value: Variant, fallback_time: int, balance: Dictionary) -> Dictionary:
	var result: Dictionary = default_profile(fallback_time, balance)
	if value is Dictionary:
		var source: Dictionary = value as Dictionary
		for key in result.keys():
			if source.has(str(key)):
				result[str(key)] = source[str(key)]
	result["created_at"] = maxi(0, int(result.get("created_at", fallback_time)))
	result["last_seen_at"] = maxi(0, int(result.get("last_seen_at", fallback_time)))
	result["last_offline_claim_at"] = maxi(0, int(result.get("last_offline_claim_at", fallback_time)))
	result["total_offline_seconds"] = maxi(0, int(result.get("total_offline_seconds", 0)))
	result["total_offline_claims"] = maxi(0, int(result.get("total_offline_claims", 0)))
	result["settings"] = normalize_settings(result.get("settings", {}), balance)
	return result


static func limit_hours(balance: Dictionary) -> int:
	return maxi(1, int(round(float(afk_settings(balance).get("limit_hours", DEFAULT_LIMIT_HOURS)))))


static func limit_seconds(balance: Dictionary) -> int:
	return limit_hours(balance) * 3600


static func tick_seconds(balance: Dictionary) -> int:
	return maxi(1, int(afk_settings(balance).get("tick_seconds", DEFAULT_TICK_SECONDS)))


static func min_seconds(balance: Dictionary) -> int:
	return maxi(0, int(afk_settings(balance).get("min_seconds", DEFAULT_MIN_SECONDS)))


static func active_efficiency(balance: Dictionary) -> float:
	return clampf(float(afk_settings(balance).get("active_efficiency", DEFAULT_ACTIVE_EFFICIENCY)), 0.0, 1.0)


static func stage_multiplier(balance: Dictionary, highest_stage: int) -> float:
	var settings: Dictionary = afk_settings(balance)
	var per_stage: float = maxf(0.0, float(settings.get("stage_efficiency_per_stage", DEFAULT_STAGE_EFFICIENCY)))
	var maximum: float = maxf(1.0, float(settings.get("max_stage_multiplier", DEFAULT_MAX_STAGE_MULTIPLIER)))
	var stage: int = maxi(1, highest_stage)
	return clampf(1.0 + float(stage - 1) * per_stage, 1.0, maximum)


static func afk_efficiency(balance: Dictionary) -> float:
	return clampf(float(afk_settings(balance).get("afk_efficiency", DEFAULT_AFK_EFFICIENCY)), 0.0, 1.0)


static func efficiency(balance: Dictionary, highest_stage: int) -> float:
	return clampf(afk_efficiency(balance) * stage_multiplier(balance, highest_stage), 0.0, 1.0)


static func offline_rewards(balance: Dictionary, last_saved_at: int, now_unix: int, highest_stage: int) -> Dictionary:
	var elapsed: int = maxi(0, now_unix - last_saved_at)
	var limit: int = limit_seconds(balance)
	var credited: int = mini(elapsed, limit)
	var minimum: int = min_seconds(balance)
	var eligible: bool = elapsed > 0 and credited >= minimum
	var stage: int = maxi(1, highest_stage)
	var multiplier: float = stage_multiplier(balance, stage)
	var passive: float = efficiency(balance, stage)
	var active: float = active_efficiency(balance)
	var tick: int = tick_seconds(balance)
	var ratio: float = float(credited) / float(tick) if eligible else 0.0
	var configured: Variant = afk_settings(balance).get("rewards_per_tick", {})
	var rewards: Dictionary = configured as Dictionary if configured is Dictionary else {}
	var experience: int = int(floor(float(rewards.get("experience", 0)) * ratio * passive)) if eligible else 0
	var gold: int = int(floor(float(rewards.get("gold", 0)) * ratio * passive)) if eligible else 0
	var materials: int = int(floor(float(rewards.get("materials", 0)) * ratio * passive)) if eligible else 0
	var status: String = "начислено"
	if elapsed == 0:
		status = "время не изменилось"
	elif not eligible:
		status = "мало времени отсутствия"
	elif elapsed > limit:
		status = "учтён лимит"
	return {
		"eligible": eligible,
		"elapsed_seconds": elapsed,
		"credited_seconds": credited,
		"limit_seconds": limit,
		"capped": elapsed > limit,
		"min_seconds": minimum,
		"tick_seconds": tick,
		"tick_ratio": ratio,
		"stage_number": stage,
		"stage_multiplier": multiplier,
		"efficiency": passive,
		"active_efficiency": active,
		"active_is_better": active > passive,
		"experience": experience,
		"gold": gold,
		"materials": materials,
		"status": status,
	}


static func format_duration(seconds: int) -> String:
	var total: int = maxi(0, seconds)
	var hours: int = int(floor(float(total) / 3600.0))
	var minutes: int = int(floor(float(total - hours * 3600) / 60.0))
	if hours > 0:
		return "%d ч %d мин" % [hours, minutes]
	if minutes > 0:
		return "%d мин" % minutes
	return "менее минуты"


static func reward_text(report: Dictionary) -> String:
	var duration: String = format_duration(int(report.get("credited_seconds", 0)))
	var suffix: String = " · лимит" if bool(report.get("capped", false)) else ""
	return "Офлайн %s: +%d опыта, +%d золота, +%d пепла%s" % [
		duration,
		int(report.get("experience", 0)),
		int(report.get("gold", 0)),
		int(report.get("materials", 0)),
		suffix,
	]
