extends Node
## Ranked ladder + IQ-point maths.
##
## Eight ranks, each split into three divisions (Bronze 1 → Bronze 2 → Bronze 3
## → Silver 1 → …), twenty-four steps in total.
##
## A round is scored on two things: how far the player got (heavily weighted) and
## how fast they got there (bonus only, never a penalty). Everything is scaled by
## the player's rank: low ranks climb quickly and fall slowly, high ranks the
## other way round.

const RANKS: Array[Dictionary] = [
	{"name": "Bronze",      "iq": 0,    "color": Color("#c17a41")},
	{"name": "Silver",      "iq": 700,  "color": Color("#9aa8b8")},
	{"name": "Gold",        "iq": 1500, "color": Color("#e3a725")},
	{"name": "Platinum",    "iq": 2400, "color": Color("#3fc6c9")},
	{"name": "Diamond",     "iq": 3400, "color": Color("#5aa9ff")},
	{"name": "Master",      "iq": 4500, "color": Color("#a273f2")},
	{"name": "Grandmaster", "iq": 5700, "color": Color("#ff5f8a")},
	{"name": "Champion",    "iq": 7000, "color": Color("#ffc94d")},
]

const DIVISIONS := 3
## The top rank is open-ended, so its divisions get a fixed width.
const CHAMPION_DIVISION_SPAN := 800

## Per-rank reward shaping. Bronze gains a lot and bleeds little; Champion the
## inverse. Index matches RANKS.
const GAIN_MULT: PackedFloat32Array = [1.35, 1.20, 1.06, 0.96, 0.87, 0.79, 0.72, 0.65]
const LOSS_MULT: PackedFloat32Array = [0.50, 0.68, 0.84, 1.00, 1.14, 1.26, 1.38, 1.50]

## Levels needed to reach maximum puzzle difficulty. A Bronze player meets hard
## puzzles far later in a run than a Diamond player does.
const RAMP_LEVELS: PackedInt32Array = [46, 41, 36, 31, 27, 24, 21, 18]

const POINTS_PER_LEVEL := 34.0
## Baseline the player is measured against: 5 cleared levels at 0 IQ,
## ~34 cleared levels at Champion entry.
const BASE_EXPECTED := 5.0
const EXPECTED_PER_IQ := 0.0042
## Average share of the per-puzzle time budget we expect to be left over.
const EXPECTED_TIME_LEFT := 0.35
const SPEED_BONUS_SCALE := 85.0
const SPEED_BONUS_CAP := 55.0


func tier_of(iq_value: int) -> int:
	var tier := 0
	for i in RANKS.size():
		if iq_value >= int(RANKS[i]["iq"]):
			tier = i
	return tier


## Lowest IQ that still belongs to `tier`/`division` (both zero-based).
func division_floor(tier: int, division: int) -> int:
	var base := int(RANKS[tier]["iq"])
	if tier >= RANKS.size() - 1:
		return base + division * CHAMPION_DIVISION_SPAN
	var span := int(RANKS[tier + 1]["iq"]) - base
	return base + int(round(float(span) * float(division) / float(DIVISIONS)))


func division_of(iq_value: int) -> int:
	var tier := tier_of(iq_value)
	var division := 0
	for d in DIVISIONS:
		if iq_value >= division_floor(tier, d):
			division = d
	return division


## "Gold 2" -- the label the player actually sees.
func rank_name(iq_value: int) -> String:
	var tier := tier_of(iq_value)
	return "%s %d" % [String(RANKS[tier]["name"]), division_of(iq_value) + 1]


func rank_color(iq_value: int) -> Color:
	return RANKS[tier_of(iq_value)]["color"]


## Everything the menu needs to draw the "IQ until the next division" bar.
func rank_progress(iq_value: int) -> Dictionary:
	var tier := tier_of(iq_value)
	var division := division_of(iq_value)
	var is_max := tier >= RANKS.size() - 1 and division >= DIVISIONS - 1

	var floor_iq := division_floor(tier, division)
	var next_tier := tier
	var next_division := division + 1
	if next_division >= DIVISIONS:
		next_division = 0
		next_tier += 1
	var ceil_iq := floor_iq if is_max else division_floor(mini(next_tier, RANKS.size() - 1), next_division)
	if is_max:
		ceil_iq = floor_iq + CHAMPION_DIVISION_SPAN

	var span := maxi(1, ceil_iq - floor_iq)
	var next_name := ""
	if not is_max:
		next_name = "%s %d" % [String(RANKS[next_tier]["name"]), next_division + 1]

	return {
		"tier": tier,
		"division": division,
		"name": rank_name(iq_value),
		"color": RANKS[tier]["color"] as Color,
		"next_name": next_name,
		"ratio": 1.0 if is_max else clampf(float(iq_value - floor_iq) / float(span), 0.0, 1.0),
		"to_next": 0 if is_max else maxi(0, ceil_iq - iq_value),
		"is_max": is_max,
	}


## 0.0 = easiest, 1.0 = hardest. `level` is 1-based and counts the puzzle the
## player is currently on.
func difficulty(level: int, iq_value: int) -> float:
	var ramp := float(RAMP_LEVELS[tier_of(iq_value)])
	return clampf((float(level) - 1.0) / ramp, 0.0, 1.0)


func expected_levels(iq_value: int) -> float:
	return BASE_EXPECTED + float(iq_value) * EXPECTED_PER_IQ


## Score one finished round.
## `cleared` = puzzles solved, `avg_time_left` = mean share of the time budget
## still on the clock when each solved puzzle was answered (0..1).
func score_round(iq_value: int, cleared: int, avg_time_left: float) -> Dictionary:
	var tier := tier_of(iq_value)
	var expected := expected_levels(iq_value)
	var raw := (float(cleared) - expected) * POINTS_PER_LEVEL

	var level_delta := 0.0
	if raw >= 0.0:
		level_delta = raw * GAIN_MULT[tier]
	else:
		level_delta = raw * LOSS_MULT[tier]

	# Speed is upside only: being slow never subtracts IQ.
	var speed_delta := 0.0
	if cleared > 0 and avg_time_left > EXPECTED_TIME_LEFT:
		speed_delta = minf(
			(avg_time_left - EXPECTED_TIME_LEFT) * SPEED_BONUS_SCALE * GAIN_MULT[tier],
			SPEED_BONUS_CAP)

	var total := int(round(level_delta + speed_delta))
	var new_iq := maxi(0, iq_value + total)
	var step_before := tier * DIVISIONS + division_of(iq_value)
	var step_after := tier_of(new_iq) * DIVISIONS + division_of(new_iq)
	return {
		"tier": tier,
		"expected": expected,
		"level_delta": int(round(level_delta)),
		"speed_delta": int(round(speed_delta)),
		"delta": new_iq - iq_value,
		"new_iq": new_iq,
		"rank_before": rank_name(iq_value),
		"rank_after": rank_name(new_iq),
		"promoted": step_after > step_before,
		"demoted": step_after < step_before,
	}
