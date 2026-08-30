extends Node
## Ranked ladder + MMR maths.
##
## A round is scored on two things: how far the player got (heavily weighted)
## and how fast they got there (bonus only, never a penalty).
## Everything is scaled by the player's current tier: low ranks climb quickly
## and fall slowly, high ranks the other way round.

const RANKS: Array[Dictionary] = [
	{"name": "Bronze",      "mmr": 0,    "color": Color("#c17a41")},
	{"name": "Silver",      "mmr": 700,  "color": Color("#9aa8b8")},
	{"name": "Gold",        "mmr": 1500, "color": Color("#e3a725")},
	{"name": "Platinum",    "mmr": 2400, "color": Color("#3fc6c9")},
	{"name": "Diamond",     "mmr": 3400, "color": Color("#5aa9ff")},
	{"name": "Master",      "mmr": 4500, "color": Color("#a273f2")},
	{"name": "Grandmaster", "mmr": 5700, "color": Color("#ff5f8a")},
	{"name": "Champion",    "mmr": 7000, "color": Color("#ffc94d")},
]

## Per-tier reward shaping. Bronze gains a lot and bleeds little; Champion the
## inverse. Index matches RANKS.
const GAIN_MULT: PackedFloat32Array = [1.35, 1.20, 1.06, 0.96, 0.87, 0.79, 0.72, 0.65]
const LOSS_MULT: PackedFloat32Array = [0.50, 0.68, 0.84, 1.00, 1.14, 1.26, 1.38, 1.50]

## Levels needed to reach maximum puzzle difficulty. A Bronze player meets hard
## puzzles far later in a run than a Diamond player does.
const RAMP_LEVELS: PackedInt32Array = [46, 41, 36, 31, 27, 24, 21, 18]

const POINTS_PER_LEVEL := 26.0
## Baseline the player is measured against: 5 cleared levels at 0 MMR,
## ~41 cleared levels at Champion entry.
const BASE_EXPECTED := 5.0
const EXPECTED_PER_MMR := 0.0055
## Average share of the per-puzzle time budget we expect to be left over.
const EXPECTED_TIME_LEFT := 0.35
const SPEED_BONUS_SCALE := 70.0
const SPEED_BONUS_CAP := 40.0


func tier_of(mmr_value: int) -> int:
	var tier := 0
	for i in RANKS.size():
		if mmr_value >= int(RANKS[i]["mmr"]):
			tier = i
	return tier


func rank_name(mmr_value: int) -> String:
	return RANKS[tier_of(mmr_value)]["name"]


func rank_color(mmr_value: int) -> Color:
	return RANKS[tier_of(mmr_value)]["color"]


## Everything the main menu needs to draw the "MMR until next rank" bar.
func rank_progress(mmr_value: int) -> Dictionary:
	var tier := tier_of(mmr_value)
	var floor_mmr := int(RANKS[tier]["mmr"])
	var is_max := tier >= RANKS.size() - 1
	var ceil_mmr := floor_mmr if is_max else int(RANKS[tier + 1]["mmr"])
	var span := maxi(1, ceil_mmr - floor_mmr)
	return {
		"tier": tier,
		"name": String(RANKS[tier]["name"]),
		"color": RANKS[tier]["color"] as Color,
		"next_name": "" if is_max else String(RANKS[tier + 1]["name"]),
		"ratio": 1.0 if is_max else clampf(float(mmr_value - floor_mmr) / float(span), 0.0, 1.0),
		"to_next": 0 if is_max else maxi(0, ceil_mmr - mmr_value),
		"is_max": is_max,
	}


## 0.0 = easiest, 1.0 = hardest. `level` is 1-based and counts the puzzle the
## player is currently on.
func difficulty(level: int, mmr_value: int) -> float:
	var ramp := float(RAMP_LEVELS[tier_of(mmr_value)])
	return clampf((float(level) - 1.0) / ramp, 0.0, 1.0)


func expected_levels(mmr_value: int) -> float:
	return BASE_EXPECTED + float(mmr_value) * EXPECTED_PER_MMR


## Score one finished round.
## `cleared` = puzzles solved, `avg_time_left` = mean share of the time budget
## still on the clock when each solved puzzle was answered (0..1).
func score_round(mmr_value: int, cleared: int, avg_time_left: float) -> Dictionary:
	var tier := tier_of(mmr_value)
	var expected := expected_levels(mmr_value)
	var raw := (float(cleared) - expected) * POINTS_PER_LEVEL

	var level_delta := 0.0
	if raw >= 0.0:
		level_delta = raw * GAIN_MULT[tier]
	else:
		level_delta = raw * LOSS_MULT[tier]

	# Speed is upside only: being slow never subtracts MMR.
	var speed_delta := 0.0
	if cleared > 0 and avg_time_left > EXPECTED_TIME_LEFT:
		speed_delta = minf(
			(avg_time_left - EXPECTED_TIME_LEFT) * SPEED_BONUS_SCALE * GAIN_MULT[tier],
			SPEED_BONUS_CAP)

	var total := int(round(level_delta + speed_delta))
	var new_mmr := maxi(0, mmr_value + total)
	return {
		"tier": tier,
		"expected": expected,
		"level_delta": int(round(level_delta)),
		"speed_delta": int(round(speed_delta)),
		"delta": new_mmr - mmr_value,
		"new_mmr": new_mmr,
		"rank_before": String(RANKS[tier]["name"]),
		"rank_after": rank_name(new_mmr),
		"promoted": tier_of(new_mmr) > tier,
		"demoted": tier_of(new_mmr) < tier,
	}
