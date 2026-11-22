--[[ JP Mograine Financial - Copyright (C) 2026 Infihedron. Licensed under the GNU GPL v3 or later; see LICENSE.
     Ledger: records every gold change, decides its category, reconciles at login,
     keeps daily and monthly books, and fades old detail into summaries. ]]

local _, ns = ...
local floor, max = math.floor, math.max

ns.CATEGORIES = {
  "Quests", "Loot", "Vendor sales", "Auction house", "Mail", "Trade",
  "Class training", "Pet training", "Profession training", "Weapon training", "Riding", "Talents", "Flights", "Repairs",
  "Ammo", "Food & drink", "Crafting materials", "Reagents", "Vendor purchases",
  "Stable", "Bank", "Transfers", "Unreconciled", "Other",
}

---------------------------------------------------------------------------
-- What is open right now, and what just happened
---------------------------------------------------------------------------
local ctx = { merchant = false, taxi = false, trainer = false, trainerKind = "class", mail = false,
              ah = false, trade = false, loot = false, stable = false, quest = false, bank = false }
local mark = { repair = 0, flight = 0, quest = 0, loot = 0, mailAH = 0, buy = 0, transferIn = 0, transferOut = 0,
               talents = 0, gossip = 0 }
local buyCat
ns.ctx = ctx

local function Open(key, val) return function() ctx[key] = val end end
ns.On("MERCHANT_SHOW", Open("merchant", true));       ns.On("MERCHANT_CLOSED", Open("merchant", false))
ns.On("TAXIMAP_OPENED", Open("taxi", true));          ns.On("TAXIMAP_CLOSED", Open("taxi", false))
ns.On("MAIL_SHOW", Open("mail", true));               ns.On("MAIL_CLOSED", Open("mail", false))
ns.On("AUCTION_HOUSE_SHOW", Open("ah", true));        ns.On("AUCTION_HOUSE_CLOSED", Open("ah", false))
ns.On("TRADE_SHOW", Open("trade", true));             ns.On("TRADE_CLOSED", Open("trade", false))
ns.On("LOOT_OPENED", Open("loot", true))
-- with auto-loot the window can close before gold updates, so remember when it closed
ns.On("LOOT_CLOSED", function() ctx.loot = false; mark.loot = GetTime() end)
ns.On("LOOT_SLOT_CLEARED", function() mark.loot = GetTime() end)
ns.On("PET_STABLE_SHOW", Open("stable", true));       ns.On("PET_STABLE_CLOSED", Open("stable", false))
ns.On("QUEST_COMPLETE", Open("quest", true));         ns.On("QUEST_FINISHED", Open("quest", false))
ns.On("BANKFRAME_OPENED", Open("bank", true));        ns.On("BANKFRAME_CLOSED", Open("bank", false))
ns.On("TRAINER_SHOW", function()
  ctx.trainer = true
end)
ns.On("TRAINER_CLOSED", Open("trainer", false))
ns.On("QUEST_TURNED_IN", function() mark.quest = GetTime() end)

-- Talents: a respec or dual specialization, bought through a trainer's dialogue and a
-- confirmation window (not the training window). Watch the confirmations, and keep a
-- short memory of the last dialogue in case the window has another name.
ns.On("GOSSIP_SHOW", function() ctx.gossip = true end)
ns.On("GOSSIP_CLOSED", function() ctx.gossip = false; mark.gossip = GetTime() end)
if ConfirmTalentWipe then hooksecurefunc("ConfirmTalentWipe", function() mark.talents = GetTime() end) end
if StaticPopup_Show then
  hooksecurefunc("StaticPopup_Show", function(which)
    if type(which) == "string" and (which:find("TALENT") or which:find("SPEC")) then mark.talents = GetTime() end
  end)
end
-- a whole number of gold between 1g and 60g, the shape of respec and dual spec prices
local function TalentPrice(delta)
  return delta < 0 and -delta % 10000 == 0 and -delta >= 10000 and -delta <= 600000
end
ns.On("CHAT_MSG_MONEY", function() mark.loot = GetTime() end)

if RepairAllItems then hooksecurefunc("RepairAllItems", function() mark.repair = GetTime() end) end
if TakeTaxiNode then hooksecurefunc("TakeTaxiNode", function() mark.flight = GetTime() end) end

-- Is this name one of your other characters (anyone the household has seen)?
local function IsMyCharacter(name)
  if type(name) ~= "string" or not ns.acct then return false end
  name = name:match("^([^%-]+)")
  if not name or name == UnitName("player") then return false end
  for key in pairs(ns.acct.household) do
    if key:match("^([^%-]+)") == name then return true end
  end
  return false
end
ns.IsMyCharacter = IsMyCharacter

local function MailHook(index)
  if GetInboxInvoiceInfo then
    local ok, invoiceType = pcall(GetInboxInvoiceInfo, index)
    if ok and invoiceType == "seller" then mark.mailAH = GetTime() end
  end
  if GetInboxHeaderInfo then
    local ok, _, _, sender = pcall(GetInboxHeaderInfo, index)
    if ok and IsMyCharacter(sender) then mark.transferIn = GetTime() end
  end
end
if TakeInboxMoney then hooksecurefunc("TakeInboxMoney", MailHook) end
if AutoLootMailItem then hooksecurefunc("AutoLootMailItem", MailHook) end
if SendMail then
  hooksecurefunc("SendMail", function(recipient)
    if GetSendMailMoney and (GetSendMailMoney() or 0) > 0 and IsMyCharacter(recipient) then mark.transferOut = GetTime() end
  end)
end

-- What kind of thing is being bought from a vendor? Ammo, food, crafting materials, reagents.
local function PurchaseCategory(index)
  local link = GetMerchantItemLink and GetMerchantItemLink(index)
  if not link then return nil end
  local info = (C_Item and C_Item.GetItemInfoInstant) or GetItemInfoInstant
  local classID, subID
  if info then
    local ok, _, _, _, _, _, c, s = pcall(info, link)
    if ok then classID, subID = c, s end
  end
  if classID == 6 then return "Ammo" end
  if classID == 5 then return "Reagents" end
  if classID == 7 then return "Crafting materials" end
  if classID == 0 then
    if subID == 5 then return "Food & drink" end
    -- older item data files food as plain "Consumable"; the tooltip tells
    if C_TooltipInfo and C_TooltipInfo.GetMerchantItem then
      local ok, data = pcall(C_TooltipInfo.GetMerchantItem, index)
      for _, l in ipairs(ok and data and data.lines or {}) do
        local t = l.leftText
        if type(t) == "string" and (t:find("seated while eating") or t:find("seated while drinking")) then
          return "Food & drink"
        end
      end
    end
  end
  return nil
end
if BuyMerchantItem then
  hooksecurefunc("BuyMerchantItem", function(index)
    buyCat = PurchaseCategory(index)
    mark.buy = GetTime()
  end)
end

local function ContextString()
  local open = {}
  for k, v in pairs(ctx) do if v == true then open[#open + 1] = k end end
  table.sort(open)
  return #open > 0 and table.concat(open, ",") or "nothing open"
end

function ns.Classify(delta)
  local now = GetTime()
  if delta < 0 and (now - mark.repair < 2 or (ctx.merchant and InRepairMode and InRepairMode())) then return "Repairs" end
  if delta < 0 and (ctx.taxi or now - mark.flight < 3) then return "Flights" end
  if delta > 0 and (now - mark.quest < 2 or ctx.quest) then return "Quests" end
  local busy = ctx.merchant or ctx.ah or ctx.mail or ctx.trade or ctx.bank or ctx.taxi or ctx.trainer or ctx.stable
  if delta < 0 and (now - mark.talents < 30
      or (not busy and (ctx.gossip or now - mark.gossip < 30) and TalentPrice(delta))) then
    return "Talents"
  end
  if ctx.trainer and delta < 0 then
    local kind = ns.TrainerKind and ns.TrainerKind() or "class"
    return kind == "profession" and "Profession training" or kind == "pet" and "Pet training"
      or kind == "riding" and "Riding" or kind == "weapon" and "Weapon training" or "Class training"
  end
  if ctx.stable and delta < 0 then return "Stable" end
  if ctx.ah then return "Auction house" end
  if (delta > 0 and now - mark.transferIn < 2) or (delta < 0 and now - mark.transferOut < 5) then return "Transfers" end
  if ctx.mail then return (now - mark.mailAH < 2) and "Auction house" or "Mail" end
  if ctx.trade then return "Trade" end
  if ctx.bank and delta < 0 then return "Bank" end
  if ctx.merchant then
    if delta < 0 and buyCat and now - mark.buy < 2 then return buyCat end
    return delta > 0 and "Vendor sales" or "Vendor purchases"
  end
  if delta > 0 and (ctx.loot or now - mark.loot < 3) then return "Loot" end
  return "Other"
end

---------------------------------------------------------------------------
-- Books: raw entries (recent), daily totals (a year), monthly totals (forever)
---------------------------------------------------------------------------
local function DayKey(t) return date("%Y-%m-%d", t) end
local function MonthKey(t) return date("%Y-%m", t) end

local function Bump(book, key, cat, amount)
  local day = book[key]
  if not day then day = {}; book[key] = day end
  local e = day[cat]
  if not e then e = { 0, 0 }; day[cat] = e end
  if amount >= 0 then e[1] = e[1] + amount else e[2] = e[2] + amount end
end

ns.session = { start = time(), byCat = {} }

function ns.Record(amount, cat, note)
  local c, t = ns.char, time()
  c.raw[#c.raw + 1] = { t = t, a = amount, c = cat, z = GetRealZoneText and GetRealZoneText() or "" }
  Bump(c.daily, DayKey(t), cat, amount)
  Bump(c.monthly, MonthKey(t), cat, amount)
  c.daily[DayKey(t)]._close = GetMoney()   -- gold at the end of the day, for history
  -- by character level: what you earned and spent while at this level
  -- (adjustments and transfers are kept apart, only so gold history adds up)
  do
    local L = UnitLevel("player") or 0
    local lb = c.levelBook[L]
    if not lb then lb = { secs = 0, cats = {} }; c.levelBook[L] = lb end
    if cat == "Unreconciled" or cat == "Transfers" then lb.adj = (lb.adj or 0) + amount end
  end
  if cat ~= "Unreconciled" and cat ~= "Transfers" then
    local L = UnitLevel("player") or 0
    local lb = c.levelBook[L]
    local e = lb.cats[cat]
    if not e then e = { 0, 0 }; lb.cats[cat] = e end
    if amount >= 0 then e[1] = e[1] + amount else e[2] = e[2] + amount end
  end
  -- by zone (not adjustments or transfers, which are not earned anywhere)
  if cat ~= "Unreconciled" and cat ~= "Transfers" then
    local day = c.daily[DayKey(t)]
    local zone = GetRealZoneText and GetRealZoneText() or ""
    if zone == "" then zone = "Unknown" end
    day._z = day._z or {}
    local e = day._z[zone]
    if not e then e = { 0, 0 }; day._z[zone] = e end
    if amount >= 0 then e[1] = e[1] + amount else e[2] = e[2] + amount end
  end
  local s = ns.session.byCat
  s[cat] = (s[cat] or 0) + amount
  if cat == "Other" then
    local u = ns.acct.uncat
    u[#u + 1] = { t = t, a = amount, ctx = note or ContextString() }
    while #u > 50 do table.remove(u, 1) end
  end
  ns.Log("%s %s (%s)", cat, ns.Money(amount), note or ContextString())
  ns.Fire("JPMF_LEDGER_CHANGED", amount, cat)
end

ns.On("PLAYER_MONEY", function()
  local c = ns.char
  if not c then return end
  local now = GetMoney()
  local delta = now - (c.gold or now)
  c.gold = now
  if delta ~= 0 then ns.Record(delta, ns.Classify(delta)) end
  ns.UpdateHousehold()
end)

---------------------------------------------------------------------------
-- Login: reconcile, prune, start the played-time clock
---------------------------------------------------------------------------
function ns.UpdateHousehold()
  if not ns.acct then return end
  local _, class = UnitClass("player")
  ns.acct.household[ns.CharKey()] = {
    name = UnitName("player"), realm = GetRealmName(), class = class,
    level = UnitLevel("player"), gold = GetMoney(), seen = time(),
  }
end

function ns.Prune()
  local c, s = ns.char, ns.acct.settings
  local cutoff = time() - (s.rawDays or 14) * 86400
  local keep = {}
  for _, e in ipairs(c.raw) do if e.t >= cutoff then keep[#keep + 1] = e end end
  c.raw = keep
  local dayCut = DayKey(time() - 400 * 86400)
  for k in pairs(c.daily) do if k < dayCut then c.daily[k] = nil end end
end

-- Delete everything older than a number of days (Settings > Data).
function ns.DeleteOlderThan(days)
  local c, t = ns.char, time() - days * 86400
  local dk, mk = DayKey(t), MonthKey(t)
  local keep = {}
  for _, e in ipairs(c.raw) do if e.t >= t then keep[#keep + 1] = e end end
  c.raw = keep
  for k in pairs(c.daily) do if k < dk then c.daily[k] = nil end end
  for k in pairs(c.monthly) do if k < mk then c.monthly[k] = nil end end
  ns.Fire("JPMF_LEDGER_CHANGED", 0, "")
end

function ns.ResetCharacter()
  local c = ns.char
  c.raw, c.daily, c.monthly = {}, {}, {}
  c.gold = GetMoney()
  ns.session.byCat = {}
  ns.Fire("JPMF_LEDGER_CHANGED", 0, "")
end

local lastTick
local function Tick()
  local now = time()
  local d = now - (lastTick or now)
  lastTick = now
  if d <= 0 or d > 600 then return end
  local c = ns.char
  c.played = (c.played or 0) + d
  local day = DayKey(now)
  c.daily[day] = c.daily[day] or {}
  c.daily[day]._played = (c.daily[day]._played or 0) + d
  local L = UnitLevel("player") or 0
  c.levelBook[L] = c.levelBook[L] or { secs = 0, cats = {} }
  c.levelBook[L].secs = c.levelBook[L].secs + d
  local zone = GetRealZoneText and GetRealZoneText() or ""
  if zone == "" then zone = "Unknown" end
  c.daily[day]._zt = c.daily[day]._zt or {}
  c.daily[day]._zt[zone] = (c.daily[day]._zt[zone] or 0) + d
end

ns.On("PLAYER_LOGIN", function()
  local c = ns.char
  local now = GetMoney()
  if c.gold and c.gold ~= now then
    ns.Record(now - c.gold, "Unreconciled", "gold changed while the addon was not watching")
  end
  c.gold = now
  c.created = c.created or time()
  ns.Prune()
  ns.UpdateHousehold()
  lastTick = time()
  if C_Timer and C_Timer.NewTicker then C_Timer.NewTicker(30, function() ns.Safe(Tick) end) end
end)
ns.On("PLAYER_LOGOUT", function() ns.Safe(Tick); ns.UpdateHousehold() end)

ns.On("PLAYER_LEVEL_UP", function(_, level)
  ns.Safe(Tick)
  ns.char.levels[level] = ns.char.played
  ns.char.levelGold[level] = { g = GetMoney(), t = time() }
  ns.Log("level %d reached at %.1f hours played", level, ns.char.played / 3600)
end)

---------------------------------------------------------------------------
-- Queries
---------------------------------------------------------------------------
-- Sum the books for the last `days` days (days = 0: today). Returns byCat {p, n}, income, spend, played.
function ns.Sum(days)
  local c = ns.char
  local byCat, inc, out, played = {}, 0, 0, 0
  local first = DayKey(time() - (days or 0) * 86400)
  for key, day in pairs(c.daily) do
    if key >= first then
      for cat, e in pairs(day) do
        if cat == "_played" then
          played = played + e
        elseif cat:sub(1, 1) ~= "_" then
          local b = byCat[cat] or { 0, 0 }
          b[1], b[2] = b[1] + e[1], b[2] + e[2]
          byCat[cat] = b
          inc, out = inc + e[1], out + e[2]
        end
      end
    end
  end
  return byCat, inc, out, played
end

function ns.SumAll()
  local byCat, inc, out = {}, 0, 0
  for _, month in pairs(ns.char.monthly) do
    for cat, e in pairs(month) do
      local b = byCat[cat] or { 0, 0 }
      b[1], b[2] = b[1] + e[1], b[2] + e[2]
      byCat[cat] = b
      inc, out = inc + e[1], out + e[2]
    end
  end
  return byCat, inc, out, ns.char.played or 0
end

-- Net gold per hour played over the last two weeks: your earning pace.
-- Left out: training (the forecast plans it separately), adjustments, transfers
-- between your characters, and auction house purchases (one-off upgrades, not a
-- running cost). A pace below zero is treated as zero: the forecast plans your
-- known costs and does not assume you keep losing gold.
function ns.GoldPerHour()
  local o = ns.acct.settings.rateOverride
  if o then return o, true end
  local byCat, _, _, played = ns.Sum(14)
  if played < 1800 then return nil end
  local net = 0
  for cat, e in pairs(byCat) do
    if not cat:find("training$")
      and cat ~= "Riding" and cat ~= "Talents" and cat ~= "Unreconciled" and cat ~= "Transfers" then
      net = net + e[1] + (cat == "Auction house" and 0 or e[2])
    end
  end
  return max(0, net / (played / 3600)), false
end

-- Average hours per level from the last few levels this addon saw.
function ns.HoursPerLevel()
  local o = ns.acct.settings.hplOverride
  if o then return o, true end
  local lv = ns.char.levels
  local cur = UnitLevel("player")
  local sum, n = 0, 0
  for l = cur, cur - 3, -1 do
    if lv[l] and lv[l - 1] and lv[l] > lv[l - 1] then
      sum, n = sum + (lv[l] - lv[l - 1]), n + 1
    end
  end
  if n == 0 then return 1.5, false end
  return sum / n / 3600, false
end

-- Earnings by zone over the last `days` days: net, income, spending and hours there.
function ns.ZoneReport(days)
  local first = DayKey(time() - (days or 7) * 86400)
  local by = {}
  for key, day in pairs(ns.char.daily) do
    if key >= first then
      for zone, e in pairs(day._z or {}) do
        local z = by[zone] or { zone = zone, p = 0, n = 0, secs = 0 }
        z.p, z.n = z.p + e[1], z.n + e[2]
        by[zone] = z
      end
      for zone, secs in pairs(day._zt or {}) do
        local z = by[zone] or { zone = zone, p = 0, n = 0, secs = 0 }
        z.secs = z.secs + secs
        by[zone] = z
      end
    end
  end
  local list = {}
  for _, z in pairs(by) do
    z.net = z.p + z.n
    z.perHour = z.secs >= 600 and z.net / (z.secs / 3600) or nil
    list[#list + 1] = z
  end
  table.sort(list, function(a, b) return a.net > b.net end)
  return list
end

---------------------------------------------------------------------------
-- Gold per level
---------------------------------------------------------------------------
-- Costs that come with leveling and keep coming. Training is planned separately;
-- auction house buys and stable slots are one-off choices, so they are left out.
ns.RUNNING_COSTS = { Repairs = true, Ammo = true, ["Food & drink"] = true, Flights = true,
  ["Vendor purchases"] = true, Reagents = true, ["Crafting materials"] = true, Mail = true,
  Bank = true, Other = true }

-- One row per character level: income, running costs, net, other spending, hours.
-- A level is complete once you have passed it and spent at least ten minutes in it.
function ns.LevelRows()
  local cur, rows = UnitLevel("player"), {}
  for L, e in pairs(ns.char.levelBook or {}) do
    local inc, run, other = 0, 0, 0
    for cat, v in pairs(e.cats or {}) do
      inc = inc + v[1]
      if ns.RUNNING_COSTS[cat] then run = run + v[2] else other = other + v[2] end
    end
    rows[#rows + 1] = { level = L, income = inc, costs = run, other = other, net = inc + run,
                        secs = e.secs or 0, complete = L < cur and (e.secs or 0) >= 600 }
  end
  table.sort(rows, function(a, b) return a.level < b.level end)
  return rows
end

-- Fit your net gold per level against level, so the forecast expects income to
-- rise as you level. Uses your last eight complete levels; needs at least two.
-- Returns fNet(level), fIncome(level) and a note, or nil.
function ns.PerLevelPace()
  local pts = {}
  for _, r in ipairs(ns.LevelRows()) do
    if r.complete then pts[#pts + 1] = r end
  end
  if #pts < 2 then return nil end
  while #pts > 8 do table.remove(pts, 1) end
  local function Fit(key)
    local n, sx, sy, sxx, sxy = #pts, 0, 0, 0, 0
    for _, r in ipairs(pts) do
      sx, sy = sx + r.level, sy + r[key]
      sxx, sxy = sxx + r.level * r.level, sxy + r.level * r[key]
    end
    -- with four or more levels, a straight line; with fewer, proportional to level
    if n >= 4 and n * sxx - sx * sx > 0 then
      local b = (n * sxy - sx * sy) / (n * sxx - sx * sx)
      if b >= 0 then
        local a = (sy - b * sx) / n
        return function(L) return max(0, a + b * L) end, "line"
      end
    end
    local k = sx > 0 and sy / sx or 0
    return function(L) return max(0, k * L) end, "ratio"
  end
  local fNet, how = Fit("net")
  local fInc = Fit("income")
  return fNet, fInc, { levels = #pts, how = how }
end

-- Is there any pace to forecast with (per level or per hour)?
function ns.HasPace()
  if ns.acct.settings.pace ~= "hour" and not ns.acct.settings.rateOverride and ns.PerLevelPace() then return true end
  return ns.GoldPerHour() ~= nil
end

---------------------------------------------------------------------------
-- Export: the ledger as spreadsheet text (copied from the copy window)
---------------------------------------------------------------------------
local function Q(v)
  v = tostring(v == nil and "" or v)
  if v:find('[,"\n]') then v = '"' .. v:gsub('"', '""') .. '"' end
  return v
end
local function Row(...)
  local out = {}
  for i = 1, select("#", ...) do out[i] = Q((select(i, ...))) end
  return table.concat(out, ",")
end

function ns.ExportCSV()
  local c, out = ns.char, {}
  out[#out + 1] = "# JP Mograine Financial export, " .. ns.CharKey() .. ", " .. date("%Y-%m-%d %H:%M")
  out[#out + 1] = "# Amounts in copper (10000 copper = 1 gold). Spending is negative."
  out[#out + 1] = ""
  out[#out + 1] = "# Transactions (the last " .. (ns.acct.settings.rawDays or 14) .. " days)"
  out[#out + 1] = Row("date", "time", "category", "copper", "amount", "zone")
  for _, e in ipairs(c.raw) do
    out[#out + 1] = Row(date("%Y-%m-%d", e.t), date("%H:%M:%S", e.t), e.c, e.a, ns.Money(e.a), e.z or "")
  end
  out[#out + 1] = ""
  out[#out + 1] = "# Daily totals"
  out[#out + 1] = Row("date", "category", "earned_copper", "spent_copper")
  local days = {}
  for k in pairs(c.daily) do days[#days + 1] = k end
  table.sort(days)
  for _, k in ipairs(days) do
    local cats = {}
    for cat in pairs(c.daily[k]) do if cat:sub(1, 1) ~= "_" then cats[#cats + 1] = cat end end
    table.sort(cats)
    for _, cat in ipairs(cats) do
      local e = c.daily[k][cat]
      out[#out + 1] = Row(k, cat, e[1], e[2])
    end
  end
  out[#out + 1] = ""
  out[#out + 1] = "# By character level"
  out[#out + 1] = Row("level", "earned_copper", "running_costs_copper", "other_spending_copper", "net_copper", "hours")
  for _, r in ipairs(ns.LevelRows()) do
    out[#out + 1] = Row(r.level, r.income, r.costs, r.other, r.net, ("%.2f"):format(r.secs / 3600))
  end
  return table.concat(out, "\n")
end

---------------------------------------------------------------------------
-- Gold history
---------------------------------------------------------------------------
local function DayNet(day)
  local n = 0
  for cat, e in pairs(day) do
    if cat:sub(1, 1) ~= "_" then n = n + e[1] + e[2] end
  end
  return n
end

-- Your gold at the end of each day, oldest first, back to `days` days ago (nil: all
-- kept days). Days with a saved closing balance use it; older ones are worked back
-- from today using each day's recorded changes. Quiet days carry the last balance.
function ns.DailyHistory(days)
  local c = ns.char
  local keys = {}
  for k in pairs(c.daily) do keys[#keys + 1] = k end
  table.sort(keys)
  if #keys == 0 then return {} end
  local close, gold = {}, GetMoney()
  -- walk backwards: a day's close is the next day's close minus the next day's net
  for i = #keys, 1, -1 do
    local k, d = keys[i], c.daily[keys[i]]
    if i == #keys then
      close[k] = (k == date("%Y-%m-%d")) and gold or (d._close or gold)
    else
      local nk = keys[i + 1]
      close[k] = d._close or (close[nk] - DayNet(c.daily[nk]))
    end
  end
  local first = keys[1]
  if days then
    local cut = date("%Y-%m-%d", time() - days * 86400)
    if cut > first then first = cut end
  end
  -- every calendar day from first to today
  local out, t, last = {}, nil, nil
  local y, m, dd = first:match("(%d+)-(%d+)-(%d+)")
  t = time({ year = tonumber(y), month = tonumber(m), day = tonumber(dd), hour = 12 })
  local today = date("%Y-%m-%d")
  for k in pairs(close) do if k < first and (not last or k > last) then last = k end end
  last = last and close[last] or nil
  while true do
    local k = date("%Y-%m-%d", t)
    if close[k] then last = close[k] end
    if last then out[#out + 1] = { day = k, t = t, gold = last, net = c.daily[k] and DayNet(c.daily[k]) or 0 } end
    if k >= today then break end
    t = t + 86400
  end
  return out
end

-- Biggest gain and biggest spend in one day's books.
function ns.DayExtremes(dayKey)
  local d, gain, spend = ns.char.daily[dayKey], nil, nil
  for cat, e in pairs(d or {}) do
    if cat:sub(1, 1) ~= "_" then
      if e[1] > 0 and (not gain or e[1] > gain[2]) then gain = { cat, e[1] } end
      if e[2] < 0 and (not spend or e[2] < spend[2]) then spend = { cat, e[2] } end
    end
  end
  return gain, spend
end

-- Your gold as you reached each level, oldest first. Levels reached since 1.2.2
-- are recorded; earlier ones are worked back from the per-level books (estimated).
function ns.LevelHistory()
  local c, cur = ns.char, UnitLevel("player")
  local out, gold = {}, GetMoney()
  -- start of the current level = now minus what changed during it, and so on back
  local startGold = {}
  local g = gold
  for L = cur, 1, -1 do
    local lb = c.levelBook[L]
    if not lb then break end
    local change = lb.adj or 0
    for _, e in pairs(lb.cats or {}) do change = change + e[1] + e[2] end
    g = g - change
    startGold[L] = g
  end
  for L = 1, cur do
    local rec = c.levelGold[L]
    if rec then
      out[#out + 1] = { level = L, gold = rec.g, t = rec.t, estimated = false }
    elseif startGold[L] and L > 1 and c.levelBook[L - 1] then
      out[#out + 1] = { level = L, gold = startGold[L], estimated = true }
    end
  end
  return out
end

