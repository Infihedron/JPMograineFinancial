-- 1.2.1: riding trainers are not class trainers; their price sets the riding account target
local G = 10000
LEVEL = 35
MONEY = 30 * G
-- a 1.2.0 character whose class scan was overwritten by the riding trainer
JPMF_CharDB = { schema = 3, nextGoalId = 3, debits = { class = { [40] = 900000, [60] = 9000000 }, prof = {}, pet = {} },
  scannedAt = 1, goals = {
    { id = 1, kind = "training", name = "Training reserve", target = 0, balance = 3 * G },
    { id = 2, kind = "riding40", name = "Riding at 40", target = 100 * G, level = 40, spend = true, balance = 10 * G } } }
JPMF_DB = { schema = 3, trainerDumps = { class = { npc = "Jartsam", sample = { "Apprentice Riding ; rank nil ; unavailable ; 900000 ; level 40 ; counted" } } } }
local ns = {}
for _, f in ipairs({"Core","Ledger","Planner","Market","Assets","UI","Pages","Morgrim","Broker"}) do assert(loadfile(DIR .. f .. ".lua"))("JPMograineFinancial", ns) end
local function FIRE(ev, ...) ns.Fire(ev, ...) end
local function money(d) MONEY = MONEY + d; FIRE("PLAYER_MONEY") end
FIRE("ADDON_LOADED", "JPMograineFinancial"); FIRE("PLAYER_LOGIN")
print("after migration: class debits empty:", next(JPMF_CharDB.debits.class) == nil, "| riding dump moved:", JPMF_DB.trainerDumps.riding ~= nil and JPMF_DB.trainerDumps.class == nil)
print("training reserve target now:", ns.Money(ns.GoalTarget(JPMF_CharDB.goals[1])))
-- visit the riding trainer
TRAINER = { {"Apprentice Riding","unavailable",900000,40,nil,""}, {"Journeyman Riding","unavailable",9000000,60,nil,""} }
FIRE("TRAINER_SHOW")
print("kind:", ns.TrainerKind(), "| class debits still empty:", next(JPMF_CharDB.debits.class) == nil)
print("Riding at 40 target:", ns.Money(JPMF_CharDB.goals[2].target), "| riding scan:", ns.char.debits.riding["Apprentice Riding"])
-- buying riding at 40 pays from the riding account
LEVEL = 40; ADV(1); money(-90 * G); FIRE("TRAINER_CLOSED")
print("riding purchase category:", JPMF_CharDB.raw[#JPMF_CharDB.raw].c, "| riding account balance:", ns.Money(JPMF_CharDB.goals[2].balance))
-- class trainer with a dual spec line: dual spec is skipped
LEVEL = 35
TRAINER = { {"Aimed Shot","unavailable",11700,36,nil,"Rank 3"}, {"Dual Talent Specialization","unavailable",500000,40,nil,""} }
SPELLBOOK = { "Aimed Shot" }
FIRE("TRAINER_SHOW"); FIRE("TRAINER_CLOSED")
print("class scan:", ns.char.debits.class[36], ns.char.debits.class[40])
print(ns.Report():match("Riding trainer scan[^\n]+"))
print("errors", #JPMF_DB.errors); for _, e in ipairs(JPMF_DB.errors) do print(e.msg) end
