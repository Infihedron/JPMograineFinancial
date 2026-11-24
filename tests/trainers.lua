-- 1.2.3: no trainer can replace another kind's plan; every kind is tracked on its own
local G = 10000
LEVEL = 36
MONEY = 40 * G
local ns = {}
for _, f in ipairs({"Core","Ledger","Planner","Market","Assets","UI","Pages","Morgrim","Broker"}) do assert(loadfile(DIR .. f .. ".lua"))("JPMograineFinancial", ns) end
local function FIRE(ev, ...) ns.Fire(ev, ...) end
FIRE("ADDON_LOADED", "JPMograineFinancial"); FIRE("PLAYER_LOGIN")
local TITLE, PROF, LINE = nil, false, nil
C_TooltipInfo = { GetUnit = function() return { lines = { { leftText = "Somebody" }, TITLE and { leftText = TITLE } or nil } } end }
IsTradeskillTrainer = function() return PROF end
GetTrainerServiceSkillLine = function() return LINE end
local function visit(title, list, prof, line)
  TITLE, PROF, LINE, TRAINER = title, prof or false, line, list
  FIRE("TRAINER_SHOW"); FIRE("TRAINER_CLOSED")
  return ns.TrainerKind()
end
local d = JPMF_CharDB.debits
SPELLBOOK = { "Aimed Shot", "Serpent Sting" }

-- hunter trainer builds the class plan
assert(visit("Hunter Trainer", { {"Aimed Shot","unavailable",32000,38,nil,"Rank 4"}, {"Volley","unavailable",50000,40,nil,"Rank 1"} }) == "class")
assert(d.class[38] == 32000 and d.class[40] == 50000); print("hunter trainer planned 38 and 40")

-- none of these may touch it
local k = visit("Weapon Master", { {"Thrown","available",900,0,nil,""} })
assert(k == "weapon" and d.class[38] == 32000 and d.weapon.Thrown == 900)
k = visit("Portal Trainer", { {"Teleport: Darnassus","available",2000,0,nil,"Rank 1"} })
assert(k == "other" and d.class[38] == 32000)
k = visit("Warrior Trainer", { {"Sunder Armor","unavailable",9000,38,nil,"Rank 4"} })
assert(k == "other" and d.class[38] == 32000)
k = visit("Riding Trainer", { {"Apprentice Riding","unavailable",900000,40,nil,""} })
assert(k == "riding" and d.class[40] == 50000)
k = visit("Pet Trainer", { {"Great Stamina","unavailable",25,36,nil,"Rank 6"} })
assert(k == "pet" and d.class[38] == 32000)
assert(d.petSuspect and next(d.pet) == nil, "copper pet prices are not planned")
k = visit("Pet Trainer", { {"Great Stamina","unavailable",4500,40,nil,"Rank 6"} })
assert(d.pet[40] == 4500 and not d.petSuspect, "real pet prices are planned")
print("weapon, portal, other class, riding and pet trainers left the class plan alone")

-- professions are kept apart
k = visit("Leatherworking Trainer", { {"Barbaric Harness","unavailable",1800,0,nil,""} }, true, "Leatherworking")
k = visit("Skinning Trainer", { {"Journeyman Skinning","available",500,0,nil,""} }, true, "Skinning")
assert(d.profs.Leatherworking.costs[36] == 1800 and d.profs.Skinning.costs[36] == 500)
print("leatherworking and skinning kept separately")

-- no title shown: a list of skills you know still counts as class, a stranger's list does not
k = visit(nil, { {"Serpent Sting","available",8000,36,nil,"Rank 5"} })
assert(k == "class")
k = visit(nil, { {"Mystery","available",100,0,nil,""} })
assert(k == "other")
print(ns.Report():match("Weapon master scan[^\n]+"))
print(ns.Report():match("Leatherworking trainer scan[^\n]+"))
print("errors", #JPMF_DB.errors); for _, e in ipairs(JPMF_DB.errors) do print(e.msg) end
