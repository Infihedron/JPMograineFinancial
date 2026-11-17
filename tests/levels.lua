-- 1.2: gold per level, rising forecast, assets, CSV export, status-bar readout
local G = 10000
LEVEL = 30
MONEY = 10 * G
-- a status-bar host (Titan Panel and friends load LibDataBroker)
LibStub = function(name) if name == "LibDataBroker-1.1" then
  return { NewDataObject = function(_, n, t) LDBOBJ = t; return t end } end end
local ns = {}
for _, f in ipairs({"Core","Ledger","Planner","Market","Assets","UI","Pages","Morgrim","Broker"}) do assert(loadfile(DIR .. f .. ".lua"))("JPMograineFinancial", ns) end
local function FIRE(ev, ...) ns.Fire(ev, ...) end
local function money(d) MONEY = MONEY + d; FIRE("PLAYER_MONEY") end
local function play(minutes) for i = 1, minutes * 2 do ADV(30); for _, t in ipairs(TICKERS) do t() end end end
FIRE("ADDON_LOADED", "JPMograineFinancial"); FIRE("PLAYER_LOGIN"); FIRE("PLAYER_ENTERING_WORLD", true)

print("before any levels: pace", ns.PerLevelPace() and "yes" or "none", "| reason:", ns.NoArrivalReason({ target = 90 * G, balance = 0 }))
-- level 30 to 34: loot and quests grow each level; repairs and ammo too
for L = 30, 33 do
  LEVEL = L
  for i = 1, 6 do
    play(10)
    ADV(1); FIRE("CHAT_MSG_MONEY"); money((L - 25) * 900)           -- loot
    ADV(5); FIRE("QUEST_TURNED_IN"); money((L - 25) * 1200)         -- quests
  end
  ADV(5); FIRE("MERCHANT_SHOW"); MERCH = { {"|Hitem:2515::|h[Arrow]|h", 2000, 200} }; ITEMCLASS[2515] = {6, 2}
  BuyMerchantItem(1, 1); money(-(L - 25) * 300); FIRE("MERCHANT_CLOSED")
  ADV(5); FIRE("AUCTION_HOUSE_SHOW"); money(-5 * G); FIRE("AUCTION_HOUSE_CLOSED")  -- a one-off gear buy
  FIRE("PLAYER_LEVEL_UP", L + 1)
end
LEVEL = 34
for _, r in ipairs(ns.LevelRows()) do
  print(("level %d: earned %s, running costs %s, other %s, net %s, %.1fh, complete=%s"):format(
    r.level, ns.Money(r.income), ns.Money(r.costs), ns.Money(r.other), ns.Money(r.net), r.secs / 3600, tostring(r.complete)))
end
local fNet, fInc, info = ns.PerLevelPace()
print(("pace: %d levels (%s): net at 34 %s, at 40 %s; income at 40 %s"):format(info.levels, info.how,
  ns.Money(fNet(34)), ns.Money(fNet(40)), ns.Money(fInc(40))))
local pts, gph, hpl, pinfo = ns.Forecast(8)
print("forecast uses per level:", pinfo ~= nil, "| hourly pace for comparison:", ns.Money(gph or 0))
local line = {}
for _, p in ipairs(pts) do line[#line + 1] = ("%d:%s"):format(p.level, ns.Money(p.peak)) end
print("forecast peaks: " .. table.concat(line, "  "))
ns.acct.settings.pace = "hour"
local pts2 = ns.Forecast(8)
print("by hour, level 40 peak:", ns.Money(pts2[7].peak), "| by level:", ns.Money(pts[7].peak))
ns.acct.settings.pace = "level"

-- rule-based arrival walks the rising income
local acct = ns.AddAccount(nil, "Mount Fund", 90 * G)
ns.SetRule(acct.id, 50)
print("Mount Fund at 50% of income fills around level", ns.GoalArrival(acct))

-- assets: bags now, bank only when opened
CONTAINERS = { [0] = { {"|Hitem:4234::|h[Heavy Leather]|h", 20, 4234}, {"|Hitem:9999::|h[Uncached]|h", 1, 9999} },
               [-1] = { {"|Hitem:4304::|h[Thick Leather]|h", 10, 4304} } }
SELLPRICE = { [4234] = 50, [4304] = 100 }
ns.acct.wishlist[4234] = { id = 4234, last = 400, points = {} }
FIRE("BAG_UPDATE_DELAYED")
local v, ah, bankAt = ns.Assets()
print("assets bags only:", ns.Money(v), "ah", ns.Money(ah), "bank seen", tostring(bankAt), "| missing", ns.char.assets.missing)
FIRE("BANKFRAME_OPENED"); FIRE("BANKFRAME_CLOSED")
v, ah, bankAt = ns.Assets()
print("with bank:", ns.Money(v), "|", ns.AssetsLine())
print("net worth is still only gold:", ns.Money(GetMoney()))

-- CSV
local csv = ns.ExportCSV()
local n = 0; for _ in csv:gmatch("\n") do n = n + 1 end
print("csv lines", n, "| level section:", csv:match("# By character level\n[^\n]+\n([^\n]+)"))

-- screens
ns.ToggleMain()
for _, p in ipairs(ns.UI.pageOrder) do ns.ShowPage(p.name) end
ns.UI.pages.Ledger.view = "level"; ns.UI.pages.Ledger:Refresh()
print(ns.StatementText():match("BY LEVEL.-\n\n"))
for _, l in ipairs(ns.MorgrimLines()) do if l:find("brought in") then print("M:", l) end end
print("status bar:", LDBOBJ and LDBOBJ.text)
local tt = { lines = {} }
function tt:AddLine(t) self.lines[#self.lines + 1] = t end
function tt:AddDoubleLine(a, b) self.lines[#self.lines + 1] = a .. " = " .. b end
LDBOBJ.OnTooltipShow(tt); print("tooltip:", table.concat(tt.lines, " | "))
print("errors", #JPMF_DB.errors); for _, e in ipairs(JPMF_DB.errors) do print(e.msg) end
