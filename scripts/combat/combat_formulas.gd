extends RefCounted

# Все формулы боя собраны здесь и читают коэффициенты из единого файла баланса.
# Дублировать расчёты в других скриптах запрещено.

const DEFAULT_REDUCTION_PER_POINT: float = 0.02
const DEFAULT_MAX_REDUCTION: float = 0.6
const DEFAULT_CRITICAL_MULTIPLIER: float = 1.5


static func defense_reduction(defense: float, balance: Dictionary) -> float:
	var per_point: float = float(balance.get("defense_reduction_per_point", DEFAULT_REDUCTION_PER_POINT))
	var cap: float = float(balance.get("max_defense_reduction", DEFAULT_MAX_REDUCTION))
	return clampf(maxf(0.0, defense) * per_point, 0.0, cap)


static func calculate_damage(attack: float, target_defense: float, multiplier: float, is_critical: bool, balance: Dictionary) -> float:
	var reduction: float = defense_reduction(target_defense, balance)
	var damage: float = maxf(0.0, attack) * (1.0 - reduction) * maxf(0.0, multiplier)
	if is_critical:
		damage *= float(balance.get("critical_multiplier", DEFAULT_CRITICAL_MULTIPLIER))
	return maxf(0.0, damage)


static func roll_critical(crit_chance: float, rng: RandomNumberGenerator) -> bool:
	return rng.randf() < clampf(crit_chance, 0.0, 1.0)
