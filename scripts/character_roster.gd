extends RefCounted
## Stable IDs and presentation/gameplay metadata. Callers receive copies so a
## preview or run cannot mutate shared definitions for subsequent runs.
const DEFAULT_ID = "centipede"
const DEFINITIONS = {
	"centipede": {
		"id": "centipede", "display_name": "蜈蚣", "label": "移动火力列车",
		"slot_cap": 60, "health_multiplier": 1.0, "speed_multiplier": 1.0,
		"skill_cooldown": 10.0, "skill_name": "盘绕", "passive": "邻接协同",
		"weakness": "身体越长，转向和避险越困难", "unlock_hint": "初始角色",
		"equipment_rule": "每节一个模块，成长增加挂点"
	},
	"spider": {
		"id": "spider", "display_name": "蜘蛛", "label": "控场与牵引",
		"slot_cap": 32, "health_multiplier": 0.9, "speed_multiplier": 1.1,
		"skill_cooldown": 7.0, "skill_name": "软丝牵引", "passive": "八足延展",
		"weakness": "生命较低，丝线数量和长度有限", "unlock_hint": "蜈蚣单局获得 3 个支援模块",
		"equipment_rule": "8 条腿，每腿最多 4 个模块；安装伸长，损毁缩短"
	}
}

static func ids() -> Array:
	return ["centipede", "spider"]

static func has_character(id: String) -> bool:
	return DEFINITIONS.has(id)

static func config(id: String) -> Dictionary:
	return DEFINITIONS.get(id, DEFINITIONS[DEFAULT_ID]).duplicate(true)

## Offensive drones, mines, weapons, HQ cores and walls are not support modules.
static func is_support(source, core_id: String) -> bool:
	var core: Dictionary = source.asset(core_id)
	if str(core.get("class", "")) in ["ShieldCore", "FuelCore", "RepairCore", "ChipCore"]:
		return true
	return str(core.get("name", "")) in ["Core_Clocking", "Core_Drones_Scrapper", "Core_Drones_Engineer"]
