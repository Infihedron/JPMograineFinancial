-- 1.2.2: weapon masters, scans that hide future skills, next-session training target, history views
local G = 10000
LEVEL = 36
MONEY = 40 * G
-- Valindra's 1.2.1 state: a weapon master's Thrown replaced the class plan
JPMF_CharDB = { schema = 4, nextGoalId = 2, debits = { class = { [36] = 900 }, prof = {}, pet = {}, scannedAt = 1000 },
  goals = { { id = 1, kind = "training", name = "Training reserve", target = 0, balance = 2 * G } } }
JPMF_DB = { schema = 4, trainerDumps = { class = { npc = "Ilyenia Moonfire", t = 1000,
  sample = { "Thrown ; rank nil ; available ; 900 ; level 0 ; counted" } } } }
local ns = {}
for _, f in ipairs({"Core","Ledger","Planner","Market","Assets","UI","Pages","Morgrim","Broker"}) do assert(loadfile(DIR .. f .. ".lua"))("JPMograineFinancial", ns) end
local function FIRE(ev, ...) ns.Fire(ev, ...) end
local function money(d) MONEY = MONEY + d; FIRE("PLAYER_MONEY") end
FIRE("ADDON_LOADED", "JPMograineFinancial"); FIRE("PLAYER_LOGIN")
local d = JPMF_CharDB.debits
assert(next(d.class) == nil, "weapon plan cleared"); assert(JPMF_DB.trainerDumps.weapon and not JPMF_DB.trainerDumps.class)
print("repair: weapon plan cleared, dump moved")

-- the weapon master again: plan untouched
d.class = { [38] = 30000, [40] = 45000 }
UNAVAIL = true
TRAINER = { {"Thrown","available",900,0,nil,""}, {"Staves","available",900,0,nil,""} }
FIRE("TRAINER_SHOW"); FIRE("TRAINER_CLOSED")
assert(ns.TrainerKind() == "weapon"); assert(d.class[38] == 30000 and d.class[40] == 45000)
print("weapon master leaves plan alone; filter stays boolean:", tostring(UNAVAIL))

-- next session: nothing to learn now, so level 38's cost
local t, lvl = ns.NextTraining()
assert(t == 30000 and lvl == 38, t .. " " .. tostring(lvl)); print("next session:", ns.Money(t), "at", lvl)
-- a class trainer whose list shows only what you can learn now keeps the future levels
TRAINER = { {"Serpent Sting","available",8000,36,nil,"Rank 5"} }
SPELLBOOK = { "Serpent Sting" }
FIRE("TRAINER_SHOW"); FIRE("TRAINER_CLOSED")
assert(d.class[36] == 8000 and d.class[38] == 30000 and d.class[40] == 45000)
t, lvl = ns.NextTraining(); assert(t == 8000 and lvl == 36); print("train now:", ns.Money(t))
-- a full list replaces everything
TRAINER = { {"Aimed Shot","unavailable",32000,38,nil,"Rank 4"}, {"Volley","unavailable",50000,40,nil,"Rank 1"} }
SPELLBOOK = { "Aimed Shot" }
FIRE("TRAINER_SHOW"); FIRE("TRAINER_CLOSED")
assert(d.class[36] == nil and d.class[38] == 32000); print("full rescan:", ns.Money(ns.GoalTarget(JPMF_CharDB.goals[1])))

-- history: level ups and days, then both views render
for i = 1, 5 do ADV(86400); money(3 * G); if i % 2 == 0 then LEVEL = LEVEL + 1; FIRE("PLAYER_LEVEL_UP", LEVEL) end end
ns.ToggleMain()
for _, p in ipairs(ns.UI.pageOrder) do ns.ShowPage(p.name) end
local fc = ns.UI.pages.Forecast
fc.view = "history"
for _, mode in ipairs({ "level", "date" }) do
  fc.hmode = mode
  for _, r in ipairs({ 7, 30, 90, false }) do fc.hrange = r; fc:Refresh() end
end
fc.view = "forecast"; fc:Refresh()
print("daily points:", #ns.DailyHistory(30), "| level points:", #ns.LevelHistory())
print("errors", #JPMF_DB.errors); for _, e in ipairs(JPMF_DB.errors) do print(e.msg) end
