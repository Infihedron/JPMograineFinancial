local ns = {}
local files = {"Core","Ledger","Planner","Market","UI","Pages","Morgrim"}
for _, f in ipairs(files) do
  local chunk = assert(loadfile(DIR .. f .. ".lua"))
  chunk("JPMograineFinancial", ns)
end
function FIRE(ev, ...) ns.Fire(ev, ...) end
FIRE("ADDON_LOADED", "JPMograineFinancial")
FIRE("PLAYER_LOGIN")
FIRE("PLAYER_ENTERING_WORLD", true, false)
-- money events
local function money(delta) MONEY = MONEY + delta; FIRE("PLAYER_MONEY") end
FIRE("QUEST_TURNED_IN", 1, 100, 8400); money(8400)
ADV(10); FIRE("CHAT_MSG_MONEY"); money(310)
ADV(10); FIRE("MERCHANT_SHOW"); money(4600); money(-900); RepairAllItems(); money(-1100); FIRE("MERCHANT_CLOSED")
ADV(10); FIRE("TAXIMAP_OPENED"); TakeTaxiNode(); money(-2400); FIRE("TAXIMAP_CLOSED")
ADV(10); FIRE("MAIL_SHOW"); TakeInboxMoney(1); money(5000); ADV(5); TakeInboxMoney(2); money(300); FIRE("MAIL_CLOSED")
ADV(10); money(-77)  -- nothing open -> Other
-- trainer scan
TRAINER = { {"Arcane Shot","available",2200,32,nil,"Rank 4"}, {"Raptor","unavailable",2600,34,nil,"Rank 4"}, {"Hawk","unavailable",3100,36,nil,"Rank 1"}, {"Old","used",999,20,nil,"Rank 1"}, {"hdr","header",0,0}, {"Counterattack","unavailable",6840,30,{{"Counterattack (Rank 1)",false}},"Rank 2"}, {"Counterattack","unavailable",9000,42,nil,"Rank 3"}, {"Trueshot Aura","unavailable",9000,32,{{"Trueshot Aura (Rank 1)",false}},"Rank 2"}, {"Aimed Shot","unavailable",11700,36,{{"Aimed Shot (Rank 2)",false}},"Rank 3"}, {"Serpent Sting","unavailable",5000,36,nil,"Rank 5"}, {"Volley","unavailable",20000,40,nil,"Rank 1"} }
FIRE("TRAINER_SHOW"); money(-2200); FIRE("TRAINER_CLOSED")
TRAINER[1][2] = "used"
FIRE("TRAINER_SHOW"); FIRE("TRAINER_CLOSED")
assert(UNAVAIL == 0, "filter restored")
-- played time: tick for 2 hours
for i = 1, 240 do ADV(30); for _, t in ipairs(TICKERS) do t() end end
-- goals
ns.AddGoal(ns.PRESETS[3])   -- training reserve
ns.AddGoal(ns.PRESETS[1])   -- riding 40
ns.AddGoal(nil, "Quillshooter", 150000)
-- wishlist + merchant + AH
local link = "|cff0070dd|Hitem:10567::::::::|h[Quillshooter]|h|r"
SlashCmdList.JPMOGRAINE("watch " .. link .. " 15g")
MERCH = { { link, 200000, 1 } }
FIRE("MERCHANT_SHOW"); FIRE("MERCHANT_CLOSED")
AH = { {id=10567, count=1, buyout=140000}, {id=10567, count=2, buyout=300000}, {id=999, count=1, buyout=5} }
FIRE("AUCTION_ITEM_LIST_UPDATE")
print("classic AH", JPMF_DB.wishlist[10567].last)
ADV(5); MAH_BROWSE = { {itemKey={itemID=10567}, minPrice=130000}, {itemKey={itemID=5}, minPrice=1} }
FIRE("AUCTION_HOUSE_BROWSE_RESULTS_UPDATED")
print("modern browse", JPMF_DB.wishlist[10567].last)
MAH_ITEM = { {buyoutAmount=125000}, {buyoutAmount=160000}, {bidAmount=1} }
FIRE("ITEM_SEARCH_RESULTS_UPDATED", {itemID=10567})
print("modern item", JPMF_DB.wishlist[10567].last)
MAH_COMM = { {unitPrice=120000} }
FIRE("COMMODITY_SEARCH_RESULTS_UPDATED", 10567)
print("modern commodity", JPMF_DB.wishlist[10567].last)
-- auto-loot: window closes before the money event
ADV(30); FIRE("LOOT_OPENED"); FIRE("LOOT_CLOSED"); ADV(1); money(55)
print("autoloot cat", JPMF_CharDB.raw[#JPMF_CharDB.raw].c)
ADV(30); money(12)
print("later stray cat", JPMF_CharDB.raw[#JPMF_CharDB.raw].c)
-- level up
LEVEL = 33; FIRE("PLAYER_LEVEL_UP", 33)
-- UI
ns.ToggleMain()
for _, p in ipairs(ns.UI.pageOrder) do ns.ShowPage(p.name) end
ns.OpenPlanning(true)
SlashCmdList.JPMOGRAINE("report")
-- reconcile on next login
MONEY = MONEY + 12345
FIRE("PLAYER_LOGIN")
-- results (before retention)
print("== RAW ==")
for _, e in ipairs(JPMF_CharDB.raw) do print(e.c, e.a) end
local byCat, inc, out, played = ns.Sum(7)
print("inc", inc, "out", out, "played", played)
print("== FORECAST ==")
local pts, gph, hpl = ns.Forecast(8)
print("gph", gph, "hpl", hpl)
for _, p in ipairs(pts) do print(p.level, math.floor(p.peak), math.floor(p.after), p.debit) end
for _, g in ipairs(JPMF_CharDB.goals) do print("goal", g.name, ns.GoalTarget(g), ns.GoalArrival(g, pts)) end
print("== MORGRIM ==") for _, l in ipairs(ns.MorgrimLines()) do print(l) end
print("== STATEMENT ==") print(ns.StatementText())
SlashCmdList.JPMOGRAINE("skip Hawk"); FIRE("TRAINER_SHOW"); FIRE("TRAINER_CLOSED")
-- pet trainer: first look empty, then the list loads
local saved = TRAINER
TRAINER = {}
FIRE("TRAINER_SHOW")
TRAINER = { {"Great Stamina","unavailable",2520,36,nil,"Rank 6"}, {"Natural Armor","unavailable",2520,36,nil,"Rank 6"}, {"Growl","unavailable",3240,40,nil,"Rank 5"}, {"Great Stamina","available",1800,34,nil,"Rank 5"} }
ADV(2); FIRE("TRAINER_UPDATE")
money(-1800); FIRE("TRAINER_CLOSED")
print("pet spend cat", JPMF_CharDB.raw[#JPMF_CharDB.raw].c)
print("debits at 36 (class+pet)", ns.Debits()[36])
TRAINER = saved
print("== REPORT ==") print(ns.Report())

-- retention: move time 30 days ahead and prune
SET_TIME(time() + 30*86400); ns.Prune(); print("raw after prune", #JPMF_CharDB.raw); ns.DeleteOlderThan(10); local n=0 for _ in pairs(JPMF_CharDB.daily) do n=n+1 end print("days after delete", n)

-- results
print("== RAW ==")
for _, e in ipairs(JPMF_CharDB.raw) do print(e.c, e.a) end
local byCat, inc, out, played = ns.SumAll()
print("== ALL TIME ==")
for c, e in pairs(byCat) do print(c, e[1], e[2]) end
print("inc", inc, "out", out, "played", JPMF_CharDB.played)
print("== DEBITS ==") for l, c in pairs(JPMF_CharDB.debits.class) do print(l, c) end
print("== FORECAST (as of test end) ==")
local pts, gph, hpl = ns.Forecast(8)
print("gph", gph, "hpl", hpl)
for _, p in ipairs(pts) do print(p.level, math.floor(p.peak), math.floor(p.after), p.debit) end
print("== WISH ==") local w = JPMF_DB.wishlist[10567]; print(w.last, w.lastSrc, #w.points)
print("== ERRORS ==", #JPMF_DB.errors) for _, e in ipairs(JPMF_DB.errors) do print(e.msg) end
print("== UNCAT ==", #JPMF_DB.uncat)
print("== MORGRIM ==") for _, l in ipairs(ns.MorgrimLines()) do print(l) end
print("== MONEY FMT ==", ns.Money(371240), ns.Money(-2400), ns.Money(0), ns.ParseMoney("90g 50s"), ns.ParseMoney("1.5"), ns.ParseMoney("50s"), ns.ParseMoney("x"))
