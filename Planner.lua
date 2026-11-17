--[[ JP Mograine Financial - Copyright (C) 2026 Infihedron. Licensed under the GNU GPL v3 or later; see LICENSE.
     Planner: accounts and auto-deposits, trainer scans, the forecast, the weekly
     statement, and Morgrim Stanley's words. ]]

local _, ns = ...
local floor, min, max = math.floor, math.min, math.max
local G = 10000

---------------------------------------------------------------------------
-- Account presets
---------------------------------------------------------------------------
-- Preset amounts are WoW: Forever prices as reported at launch (November 2026);
-- the player can change any target. Reputation discounts are not applied.
ns.PRESETS = {
  { kind = "riding40",   name = "Riding at 40",        target = 100 * G,  level = 40, spend = true,
    note = "100g for riding, and your first mount comes with it. Honored with your home city is reported to take 10% off." },
  { kind = "dualspec",   name = "Dual spec at 40",     target = 50 * G,   level = 40, spend = true,
    note = "Reported at 50g from your class trainer. If your trainer scan already shows it, you can close this account." },
  { kind = "riding60",   name = "Riding at 60",        target = 1000 * G, level = 60, spend = true,
    note = "1,000g for fast riding. An epic mount is reported at about 200g more; raise the target if you want one." },
  { kind = "training",   name = "Training reserve",    auto = true,
    note = "Fills itself from your class trainer's prices for your next six levels." },
  { kind = "stable",     name = "Stable slot",         target = 5 * G,
    note = "The extra hunter stable slot: 5g in WoW: Forever, with no reputation discount." },
  { kind = "profession", name = "Profession training", target = nil,
    note = "Expert or Artisan training. Enter the trainer's price." },
  { kind = "bag",        name = "Bag upgrade",         target = nil,
    note = "Enter the price of the bags you want." },
  { kind = "raid",       name = "Raid week",           target = nil,
    note = "Consumables and repairs for one raid week." },
  { kind = "purchase",   name = "Special purchase",    target = nil,
    note = "Anything you are saving for." },
}

---------------------------------------------------------------------------
-- Accounts. Your gold is one pile; accounts are named shares of it, each with
-- a balance, an optional target and an optional auto-deposit rule (a percent
-- of everything you earn). Free = gold on hand minus every balance.
-- Saved in ns.char.goals, so 1.0 goals carry over as accounts.
---------------------------------------------------------------------------
local NOT_INCOME = { Unreconciled = true, Transfers = true }

local function Find(id)
  for _, g in ipairs(ns.char.goals) do if g.id == id then return g end end
end
ns.FindAccount = Find

local function Note(g, amount, why)
  local log = ns.char.acctLog
  log[#log + 1] = { t = time(), id = g.id, name = g.name, a = amount, why = why }
  while #log > 200 do table.remove(log, 1) end
  ns.Log("account %s %s (%s)", g.name, ns.Money(amount), why)
end

function ns.AddGoal(spec, name, target, itemID)
  local c = ns.char
  local g = {
    id = c.nextGoalId, kind = spec and spec.kind or "custom",
    name = name or (spec and spec.name) or "Account",
    target = target or (spec and spec.target) or 0,
    level = spec and spec.level, spend = spec and spec.spend, itemID = itemID,
    balance = 0,
  }
  c.nextGoalId = c.nextGoalId + 1
  table.insert(c.goals, g)
  ns.Fire("JPMF_GOALS_CHANGED")
  return g
end
ns.AddAccount = ns.AddGoal

-- Closing an account returns its balance to Free.
function ns.RemoveGoal(id)
  for i, g in ipairs(ns.char.goals) do
    if g.id == id then table.remove(ns.char.goals, i); break end
  end
  ns.Fire("JPMF_GOALS_CHANGED")
end
ns.RemoveAccount = ns.RemoveGoal

function ns.MoveGoal(id, dir)
  local list = ns.char.goals
  for i, g in ipairs(list) do
    if g.id == id then
      local j = i + dir
      if j >= 1 and j <= #list then list[i], list[j] = list[j], list[i] end
      break
    end
  end
  ns.Fire("JPMF_GOALS_CHANGED")
end
ns.MoveAccount = ns.MoveGoal

-- Planned class training (and optionally profession training) by level.
function ns.Debits()
  local c, s = ns.char, ns.acct.settings
  local out = {}
  for lvl, cost in pairs(c.debits.class or {}) do out[lvl] = (out[lvl] or 0) + cost end
  if s.includeProfTraining then
    for lvl, cost in pairs(c.debits.prof or {}) do out[lvl] = (out[lvl] or 0) + cost end
  end
  if s.includePetTraining ~= false then
    for lvl, cost in pairs(c.debits.pet or {}) do out[lvl] = (out[lvl] or 0) + cost end
  end
  return out
end

function ns.GoalTarget(g)
  if g.kind == "training" then
    local cur, total = UnitLevel("player"), 0
    for lvl, cost in pairs(ns.Debits()) do
      if lvl >= cur and lvl <= cur + 6 then total = total + cost end
    end
    return total
  end
  return g.target or 0
end

-- Balances by account id, total held in accounts, and Free (negative = overdrawn).
function ns.Balances()
  local saved, held = {}, 0
  for _, g in ipairs(ns.char.goals) do
    local b = g.balance or 0
    saved[g.id] = b
    held = held + b
  end
  return saved, held, GetMoney() - held
end
ns.Allocate = ns.Balances   -- 1.0 name

function ns.Free()
  local _, _, free = ns.Balances()
  return free
end

-- How much more an account can take before it reaches its target.
function ns.AccountRoom(g)
  local t = ns.GoalTarget(g)
  if not t or t <= 0 then return math.huge end
  return max(0, t - (g.balance or 0))
end

-- Move gold from Free into an account (never more than Free holds).
function ns.Deposit(id, amount, why)
  local g = Find(id)
  if not g or not amount or amount <= 0 then return 0 end
  amount = min(floor(amount), max(0, ns.Free()))
  if amount <= 0 then return 0 end
  g.balance = (g.balance or 0) + amount
  Note(g, amount, why or "deposit")
  ns.Fire("JPMF_GOALS_CHANGED")
  return amount
end

-- Move gold from an account back to Free.
function ns.Withdraw(id, amount, why)
  local g = Find(id)
  if not g or not amount or amount <= 0 then return 0 end
  amount = min(floor(amount), g.balance or 0)
  if amount <= 0 then return 0 end
  g.balance = g.balance - amount
  Note(g, -amount, why or "withdrawal")
  ns.Fire("JPMF_GOALS_CHANGED")
  return amount
end

function ns.RuleTotal(exceptId)
  local t = 0
  for _, g in ipairs(ns.char.goals) do
    if g.id ~= exceptId and g.rule then t = t + g.rule end
  end
  return t
end

-- Set an auto-deposit rule: pct of every gold gain. All rules together stay at or under 100.
function ns.SetRule(id, pct)
  local g = Find(id)
  if not g then return nil end
  pct = tonumber(pct)
  if not pct or pct <= 0 then
    g.rule = nil
  else
    pct = min(floor(pct + 0.5), 100 - ns.RuleTotal(id))
    g.rule = pct > 0 and pct or nil
  end
  ns.Fire("JPMF_GOALS_CHANGED")
  return g.rule
end

-- Every gold change: run auto-deposit rules on income, pay training from the
-- training account, and cover an overdraft if the player chose that.
ns.On("JPMF_LEDGER_CHANGED", function(_, amount, cat)
  if not ns.char or not amount or amount == 0 then return end
  local changed = false
  if amount > 0 and not NOT_INCOME[cat] then
    for _, g in ipairs(ns.char.goals) do
      if g.rule then
        local want = min(floor(amount * g.rule / 100), ns.AccountRoom(g), max(0, ns.Free()))
        if want > 0 then
          g.balance = (g.balance or 0) + want
          Note(g, want, ("auto %d%% of %s"):format(g.rule, (cat or "income"):lower()))
          changed = true
        end
      end
    end
  elseif amount < 0 and type(cat) == "string" and cat:find("training$") then
    for _, g in ipairs(ns.char.goals) do
      if g.kind == "training" and (g.balance or 0) > 0 then
        local pay = min(-amount, g.balance)
        g.balance = g.balance - pay
        Note(g, -pay, "paid " .. cat:lower())
        changed = true
        break
      end
    end
  end
  local free = ns.Free()
  if free < 0 and ns.acct.settings.overdraft == "pull" then
    local list = ns.char.goals
    for i = #list, 1, -1 do
      if free >= 0 then break end
      local g = list[i]
      local take = min(g.balance or 0, -free)
      if take > 0 then
        g.balance = g.balance - take
        free = free + take
        Note(g, -take, "covered an overdraft")
        changed = true
      end
    end
  end
  if changed then ns.Fire("JPMF_GOALS_CHANGED") end
end)

-- 1.0 goals had no balances: give each the share the old top-down fill gave it,
-- so nothing suddenly lands in Free. Runs after the ledger's login reconciliation.
ns.On("PLAYER_LOGIN", function()
  local avail = GetMoney()
  for _, g in ipairs(ns.char.goals) do avail = avail - (g.balance or 0) end
  for _, g in ipairs(ns.char.goals) do
    if g.balance == nil then
      local b = max(0, min(ns.GoalTarget(g), avail))
      g.balance = b
      avail = avail - b
    end
  end
end)

-- Gross income per hour played (two weeks), for auto-deposit arrival estimates.
function ns.IncomePerHour()
  local byCat, _, _, played = ns.Sum(14)
  if played < 1800 then return nil end
  local inc = 0
  for cat, e in pairs(byCat) do if not NOT_INCOME[cat] then inc = inc + e[1] end end
  return inc / (played / 3600)
end

-- Auto-deposits over the last `days` days: total and per account name.
function ns.AutoDeposits(days)
  local since, total, by = time() - (days or 7) * 86400, 0, {}
  for _, e in ipairs(ns.char.acctLog or {}) do
    if e.t >= since and e.a > 0 and e.why:find("^auto") then
      total = total + e.a
      by[e.name] = (by[e.name] or 0) + e.a
    end
  end
  return total, by
end

---------------------------------------------------------------------------
-- Trainer scan: record what upcoming levels will cost
---------------------------------------------------------------------------
-- Names of every spell in the player's spellbook (modern and classic APIs).
local function KnownSpells()
  local known = {}
  local function Walk(get)
    for i = 1, 1000 do
      local ok, name = pcall(get, i)
      if not ok or not name then break end
      known[name] = true
    end
  end
  if C_SpellBook and C_SpellBook.GetSpellBookItemName and Enum and Enum.SpellBookSpellBank then
    Walk(function(i) return C_SpellBook.GetSpellBookItemName(i, Enum.SpellBookSpellBank.Player) end)
  end
  if not next(known) and GetSpellBookItemName then
    Walk(function(i) return GetSpellBookItemName(i, BOOKTYPE_SPELL or "spell") end)
  end
  if not next(known) and GetSpellName then
    Walk(function(i) return GetSpellName(i, BOOKTYPE_SPELL or "spell") end)
  end
  return known
end

-- What kind of trainer is open: "profession", "pet" or "class".
-- The game reports pet trainers like class trainers, so look at the NPC's title
-- ("<Pet Trainer>") and at what is for sale.
local PET_SKILLS = { ["Great Stamina"] = true, ["Natural Armor"] = true, ["Growl"] = true,
  ["Arcane Resistance"] = true, ["Fire Resistance"] = true, ["Frost Resistance"] = true,
  ["Nature Resistance"] = true, ["Shadow Resistance"] = true }
function ns.TrainerKind()
  if IsTradeskillTrainer and IsTradeskillTrainer() then return "profession" end
  if C_TooltipInfo and C_TooltipInfo.GetUnit then
    local ok, data = pcall(C_TooltipInfo.GetUnit, "npc")
    for _, line in ipairs(ok and data and data.lines or {}) do
      if type(line.leftText) == "string" and line.leftText:find("Pet Trainer") then return "pet" end
    end
  end
  local pet, total = 0, 0
  for i = 1, (GetNumTrainerServices and GetNumTrainerServices() or 0) do
    local name = GetTrainerServiceInfo(i)
    if name then
      total = total + 1
      if PET_SKILLS[name] then pet = pet + 1 end
    end
  end
  if total > 0 and pet * 2 >= total then return "pet" end
  return "class"
end

local scanning, lastScan = false, 0
local function ScanTrainer()
  if scanning or not GetNumTrainerServices or not GetTrainerServiceLevelReq then return end
  scanning = true
  local changed = false
  if GetTrainerServiceTypeFilter and SetTrainerServiceTypeFilter then
    local f = GetTrainerServiceTypeFilter("unavailable")
    if not f or f == 0 then
      SetTrainerServiceTypeFilter("unavailable", 1)   -- show future skills, restored below
      changed = true
    end
  end
  local kind = ns.TrainerKind()
  local isProf = kind == "profession"
  local cur = UnitLevel("player")
  local n = GetNumTrainerServices() or 0
  local known = KnownSpells()
  local nKnown = 0
  for _ in pairs(known) do nKnown = nKnown + 1 end
  local CATS = { available = true, unavailable = true, used = true, header = true }
  local hasReqAPI = GetTrainerServiceNumAbilityReq and GetTrainerServiceAbilityReq and true or false
  local dumps = ns.acct.trainerDumps or {}
  ns.acct.trainerDumps, ns.acct.trainerDump = dumps, nil
  -- a record of exactly what this trainer reported, shown in /jpm report
  local dump = { t = time(), n = n, npc = UnitName and UnitName("npc") or "?",
                 filter = tostring(GetTrainerServiceTypeFilter and GetTrainerServiceTypeFilter("unavailable")),
                 spellbook = nKnown, reqAPI = hasReqAPI, cats = {}, sample = {}, raw = {}, skipped = {} }

  if n == 0 then
    -- nothing listed (a pet trainer, or the list has not loaded): change nothing
    if changed then SetTrainerServiceTypeFilter("unavailable", 0) end
    scanning = false
    lastScan = GetTime()
    dump.kind = kind
    dumps.empty = dump
    return
  end

  -- pass 1: read every service. Status and rank are found by value, not position,
  -- because WoW: Forever puts an icon where Classic puts the status.
  local list, lowestRank = {}, {}
  for i = 1, n do
    local v = { GetTrainerServiceInfo(i) }
    local name, category, rank = v[1], nil, nil
    for k = 2, #v do
      if CATS[v[k]] then category = category or v[k] end
      if type(v[k]) == "string" and not rank then rank = tonumber(v[k]:match("(%d+)%s*$") or "") end
    end
    if #dump.raw < 3 then
      local parts = {}
      for k = 1, 6 do parts[k] = tostring(v[k]) end
      dump.raw[#dump.raw + 1] = table.concat(parts, " ; ")
    end
    local e = { name = name, cat = category, rank = rank, cost = GetTrainerServiceCost(i) or 0,
                lvl = tonumber(GetTrainerServiceLevelReq(i)) }
    -- does the game say you are missing the previous rank of this same skill?
    if hasReqAPI and name then
      for r = 1, GetTrainerServiceNumAbilityReq(i) or 0 do
        local ability, met = GetTrainerServiceAbilityReq(i, r)
        if ability and not met and ability:gsub("%s*%(.-%)%s*$", "") == name then e.missingPrev = true end
      end
    end
    local cat = tostring(category)
    dump.cats[cat] = (dump.cats[cat] or 0) + 1
    if name and category ~= "header" and rank and (not lowestRank[name] or rank < lowestRank[name].rank) then
      lowestRank[name] = e
    end
    list[#list + 1] = e
  end

  -- pass 2: a talent's first rank is never sold by a trainer. A skill counts as
  -- talent-locked only when every available sign agrees: its lowest rank here is
  -- above 1, it is not in your spellbook, and the game says you lack the rank before.
  local skip, why = {}, {}
  if (nKnown > 0 or hasReqAPI) and kind ~= "pet" then
    for name, e in pairs(lowestRank) do
      local talent = e.rank > 1
      if nKnown > 0 and known[name] then talent = false end
      if hasReqAPI and not e.missingPrev then talent = false end
      if talent then skip[name] = true; why[name] = "talent" end
    end
  end
  for name in pairs(ns.char.trainerIgnore or {}) do skip[name] = true; why[name] = why[name] or "you" end
  for name, w in pairs(why) do
    if w == "talent" then dump.skipped[#dump.skipped + 1] = name end
  end
  table.sort(dump.skipped)

  local byLevel, count = {}, 0
  for _, e in ipairs(list) do
    if e.cat ~= "header" and #dump.sample < 10 then
      dump.sample[#dump.sample + 1] = ("%s ; rank %s ; %s ; %s ; level %s ; %s"):format(tostring(e.name), tostring(e.rank),
        tostring(e.cat), tostring(e.cost), tostring(e.lvl), skip[e.name] and "skipped" or e.cat == "used" and "learned" or "counted")
    end
    -- count anything not learned, not a header, and not skipped
    if e.cat ~= "header" and e.cat ~= "used" and e.cost > 0 and not skip[e.name] then
      local lvl = max(e.lvl or cur, cur)
      byLevel[lvl] = (byLevel[lvl] or 0) + e.cost
      count = count + 1
    end
  end
  dump.counted = count
  if changed then SetTrainerServiceTypeFilter("unavailable", 0) end
  scanning = false
  lastScan = GetTime()
  dumps[kind] = dump
  -- class, pet and profession scans are kept apart; "scannedAt" is the class trainer's.
  -- (Pet skill level requirements are your pet's level, close enough to yours to plan by.)
  local d = ns.char.debits
  if kind == "profession" then
    d.prof, d.profAt = byLevel, time()
  elseif kind == "pet" then
    d.pet, d.petAt = byLevel, time()
  else
    d.class, d.scannedAt, d.scannedLevel = byLevel, time(), cur
  end
  ns.Log("trainer scan (%s): %d services, %d future costs", kind, n, count)
  ns.Fire("JPMF_GOALS_CHANGED")
end
-- scan right away, again a moment later, and whenever the list changes
-- (the first look at a trainer often comes back empty while it loads)
local updates = 0
ns.On("TRAINER_SHOW", function()
  updates = 0
  if C_Timer then
    C_Timer.After(0.3, function() ns.Safe(ScanTrainer) end)
    C_Timer.After(1.5, function() ns.Safe(ScanTrainer) end)
  else
    ScanTrainer()
  end
end)
ns.On("TRAINER_UPDATE", function()
  -- our own filter changes also fire this, so ignore it during and just after a scan
  if scanning or GetTime() - lastScan < 1 or updates >= 5 or not C_Timer then return end
  updates = updates + 1
  C_Timer.After(0.3, function() ns.Safe(ScanTrainer) end)
end)

---------------------------------------------------------------------------
-- Forecast
---------------------------------------------------------------------------
-- Points by level: peak (before that level's costs) and after (once paid).
function ns.Forecast(levels)
  local cur = UnitLevel("player")
  local maxL = min(cur + (levels or 10), 60)
  local gph = ns.GoldPerHour() or 0
  local hpl = ns.HoursPerLevel()
  local perLevel = gph * hpl
  -- by level (the default): your own per-level curve, rising as you level.
  -- An hourly override, or the "by hour" setting, uses gold per hour instead.
  local s = ns.acct.settings
  local fNet, _, info
  if s.pace ~= "hour" and not s.rateOverride then fNet, _, info = ns.PerLevelPace() end
  local debits = ns.Debits()
  local spendAt = {}
  for _, g in ipairs(ns.char.goals) do
    if g.spend and g.level and g.level > cur then
      spendAt[g.level] = (spendAt[g.level] or 0) + ns.GoalTarget(g)
    end
  end
  local gold = GetMoney()
  local due = debits[cur] or 0
  local pts = { { level = cur, peak = gold, after = gold - due, debit = due } }
  gold = gold - due
  for lvl = cur + 1, maxL do
    gold = gold + (fNet and fNet(lvl - 1) or perLevel)
    local d = (debits[lvl] or 0) + (spendAt[lvl] or 0)
    pts[#pts + 1] = { level = lvl, peak = gold, after = gold - d, debit = d, spend = spendAt[lvl] }
    gold = gold - d
  end
  return pts, gph, hpl, fNet and info or nil
end

-- When does the forecast first hold `amount`? Returns a fractional level or nil.
function ns.ArrivalLevel(amount, pts)
  pts = pts or ns.Forecast(15)
  if pts[1].peak >= amount then return pts[1].level end
  for i = 2, #pts do
    local a, b = pts[i - 1].after, pts[i].peak
    if b >= amount and b > a then
      return pts[i].level - 1 + (amount - a) / (b - a)
    end
  end
  return nil
end

-- Per-goal arrival: the cumulative target up to this goal, ignoring the
-- training reserve (the forecast already pays training at each level).
function ns.GoalArrival(goal, pts)
  -- an auto-deposit rule fills the account at its share of your income
  if goal.rule then
    local room, iph, cur = ns.AccountRoom(goal), ns.IncomePerHour(), UnitLevel("player")
    if room == 0 then return cur end
    local s = ns.acct.settings
    local _, fInc = nil, nil
    if s.pace ~= "hour" and not s.rateOverride then _, fInc = ns.PerLevelPace() end
    if fInc and room < math.huge then
      -- walk the levels ahead, depositing the rule's share of each level's income
      local filled = 0
      for L = cur, 60 do
        local add = fInc(L) * goal.rule / 100
        if add > 0 and filled + add >= room then return L + (room - filled) / add end
        filled = filled + add
      end
      return nil
    end
    if iph and iph > 0 and room < math.huge then
      local lvl = cur + room / (iph * goal.rule / 100) / ns.HoursPerLevel()
      return lvl <= 60 and lvl or nil
    end
  end
  -- otherwise: when will your gold cover the other accounts plus what this one still needs?
  -- The training reserve is left out: the forecast already spends it on training.
  local room = ns.AccountRoom(goal)
  if room == math.huge then return nil end
  if room == 0 then return UnitLevel("player") end
  local held = 0
  for _, g in ipairs(ns.char.goals) do
    if g.kind ~= "training" then held = held + (g.balance or 0) end
  end
  pts = pts or ns.Forecast(15)
  -- A purchase at a set level (like the mount at 40) is already a step in the
  -- forecast: it arrives when the gold peaks high enough before that step.
  if goal.spend and goal.level then return ns.ArrivalLevel(held + room, pts) end
  -- Anything else is safe to fill only once your gold stays above it through
  -- every planned cost still ahead in the forecast.
  local need = held + room
  for i = 1, #pts do
    local low = math.huge
    for j = i, #pts do low = min(low, pts[j].after) end
    if low >= need then return pts[i].level end
  end
  return nil
end

-- Why an account has no arrival estimate, in a few words for the screen.
function ns.NoArrivalReason(goal)
  if ns.AccountRoom(goal) == math.huge then return "No target" end
  if not ns.HasPace() then return "Needs play data" end
  local gph = ns.GoldPerHour() or 0
  if gph <= 0 and not ns.PerLevelPace() then return "Not at this pace" end
  -- if planned training drains the forecast, that is the reason
  for _, p in ipairs(ns.Forecast(15)) do
    if p.after < 0 then return ("Short at Lv %d"):format(p.level) end
  end
  return "15+ levels away"
end

-- True when Free already holds enough to fill this account today.
function ns.CanFillNow(goal)
  local room = ns.AccountRoom(goal)
  return room > 0 and room < math.huge and ns.Free() >= room
end

---------------------------------------------------------------------------
-- Weekly statement and Morgrim Stanley's lines
---------------------------------------------------------------------------
function ns.Statement(days)
  days = days or 7
  local byCat, inc, out, played = ns.Sum(days)
  -- adjustments (gold that moved while the addon was off) are reported apart, not as income
  local adj = 0
  if byCat["Unreconciled"] then
    local e = byCat["Unreconciled"]
    adj = e[1] + e[2]
    inc, out = inc - e[1], out - e[2]
    byCat["Unreconciled"] = nil
  end
  -- gold moved between your own characters is neither earned nor spent
  local transfers = 0
  if byCat["Transfers"] then
    local e = byCat["Transfers"]
    transfers = e[1] + e[2]
    inc, out = inc - e[1], out - e[2]
    byCat["Transfers"] = nil
  end
  local cats = {}
  for cat, e in pairs(byCat) do cats[#cats + 1] = { cat = cat, p = e[1], n = e[2] } end
  table.sort(cats, function(a, b) return (a.p + a.n) > (b.p + b.n) end)
  local leaks = {}
  for _, e in ipairs(cats) do
    if e.n < 0 and e.cat ~= "Class training" and e.cat ~= "Pet training" and e.cat ~= "Unreconciled" then leaks[#leaks + 1] = e end
  end
  table.sort(leaks, function(a, b) return a.n < b.n end)
  return { days = days, cats = cats, income = inc, spend = out, net = inc + out,
           played = played, leaks = leaks, adjustments = adj, transfers = transfers }
end

local TIPS = {
  ["Flights"] = "Set your hearthstone near where you quest and ride the short hops.",
  ["Repairs"] = "Fewer deaths, fewer repair bills. Easy for me to say, I know.",
  ["Vendor purchases"] = "Check whether any of those purchases could be looted or crafted instead.",
  ["Ammo"] = "Ammunition is a hunter's rent. Buy it in bulk, and buy the cheaper kind when the mobs allow it.",
  ["Food & drink"] = "Food is fuel, but looted and cooked food is cheaper fuel.",
  ["Crafting materials"] = "Materials are an investment only if what you make is worth more than what you paid.",
  ["Reagents"] = "Reagents are a cost of doing business. Buy what you will use this week, not this year.",
  ["Auction house"] = "The auction house rewards patience. Watch a price for a few days before buying.",
  ["Pet training"] = "A well-trained companion is a capital asset. Spend accordingly.",
  ["Profession training"] = "Professions pay back over time. A sound investment, within reason.",
  ["Stable"] = "A stable slot is a one-time cost. I will not hold it against you.",
  ["Trade"] = "Gold handed to friends is gold I cannot forecast. I trust they will repay you.",
}

function ns.MorgrimLines()
  local st = ns.Statement(7)
  local name = UnitName("player") or "friend"
  local lines = {}
  if st.income == 0 and st.spend == 0 then
    lines[1] = ("Welcome to JP Mograine Financial, %s. Our books are new. Play a while and I will have numbers for you."):format(name)
  else
    lines[1] = ("Good to see you, %s. This week you earned %s and spent %s, a net of %s."):format(
      name, ns.Money(st.income), ns.Money(-st.spend), ns.Money(st.net))
  end
  local leak = st.leaks[1]
  if leak then
    lines[#lines + 1] = ("Your largest expense was %s at %s. %s"):format(
      leak.cat:lower(), ns.Money(-leak.n), TIPS[leak.cat] or "Worth keeping an eye on.")
  end
  -- accounts: overdraft first, then what the auto-deposits did this week
  local _, held, free = ns.Balances()
  if free < 0 then
    lines[#lines + 1] = ("Your accounts hold %s, but you only have %s. You are overdrawn by %s. Withdraw from an account to set the books straight."):format(
      ns.Money(held), ns.Money(GetMoney()), ns.Money(-free))
  elseif held > 0 then
    lines[#lines + 1] = ("You have %s set aside in accounts and %s free to spend."):format(ns.Money(held), ns.Money(free))
  end
  local auto, by = ns.AutoDeposits(7)
  if auto > 0 then
    local parts = {}
    for name, a in pairs(by) do parts[#parts + 1] = ("%s to %s"):format(ns.Money(a), name) end
    table.sort(parts)
    lines[#lines + 1] = ("Your standing orders moved %s this week: %s. Paying yourself first. I approve."):format(
      ns.Money(auto), table.concat(parts, ", "))
  end
  local pts = ns.Forecast(15)
  local saved = ns.Allocate()
  local top = ns.char.goals[1]
  if top then
    local t = ns.GoalTarget(top)
    local s = saved[top.id] or 0
    if t > 0 and s >= t then
      lines[#lines + 1] = ("Your %s account is fully funded at %s. Well done."):format(top.name, ns.Money(t))
    elseif t > 0 then
      local eta = ns.GoalArrival(top, pts)
      local when = ns.CanFillNow(top) and " You have enough free gold to fill it today, if you wish."
        or eta and (" At your pace it fills around level %.1f."):format(eta)
        or (ns.NoArrivalReason(top) == "Needs play data" and " I need more play time before I can date it."
          or " At your current pace it does not fill in the next fifteen levels. A standing order would help.")
      lines[#lines + 1] = ("Your %s account stands at %s of %s, %d percent.%s"):format(top.name, ns.Money(s), ns.Money(t),
        floor(s / t * 100), when)
    end
  else
    lines[#lines + 1] = "You have no accounts yet. Shall we open one? A mount fund for level 40 is the classic."
  end
  local debits, cur, nextL = ns.Debits(), UnitLevel("player"), nil
  for lvl in pairs(debits) do if lvl > cur and (not nextL or lvl < nextL) then nextL = lvl end end
  if nextL then
    lines[#lines + 1] = ("Training at level %d will cost about %s. I have planned for it."):format(nextL, ns.Money(debits[nextL]))
  elseif not ns.char.debits.scannedAt then
    lines[#lines + 1] = "Visit your class trainer once, so I can see what your next levels will cost."
  end
  -- the first level where the plan runs out of gold, explained in its parts
  local short
  for _, p in ipairs(pts) do if p.after < 0 then short = p; break end end
  if short then
    local what = {}
    for _, g in ipairs(ns.char.goals) do
      if g.spend and g.level == short.level then what[#what + 1] = g.name end
    end
    local train = short.debit - (short.spend or 0)
    if train > 0 then table.insert(what, 1, "training") end
    lines[#lines + 1] = ("A word of caution: at level %d you should have about %s, and %s there will cost %s. That leaves you about %s short. Earn a little more, spend a little less, or adjust an account."):format(
      short.level, ns.Money(math.max(0, short.peak)), #what > 0 and table.concat(what, " and ") or "your plans",
      ns.Money(short.debit), ns.Money(math.min(-short.after, short.debit)))
  end
  local gph = ns.GoldPerHour()
  local fNet, _, info = ns.PerLevelPace()
  if fNet and ns.acct.settings.pace ~= "hour" then
    local rows, last = ns.LevelRows(), nil
    for _, r in ipairs(rows) do if r.complete then last = r end end
    lines[#lines + 1] = ("Your level %d brought in %s after running costs. At this rate, level %d should bring about %s. Income rises as you climb; plan accordingly."):format(
      last.level, ns.Money(last.net), cur + 3, ns.Money(fNet(cur + 3)))
  elseif gph and gph > 0 then
    lines[#lines + 1] = ("You are clearing %s per hour played. Steady work."):format(ns.Money(gph))
  end
  -- best ground: the zone with the best net per hour, given at least half an hour there
  local best
  for _, z in ipairs(ns.ZoneReport and ns.ZoneReport(7) or {}) do
    if z.perHour and z.secs >= 1800 and (not best or z.perHour > best.perHour) then best = z end
  end
  if best and best.perHour > 0 then
    lines[#lines + 1] = ("Your most profitable ground this week was %s, at %s per hour."):format(best.zone, ns.Money(best.perHour))
  end
  return lines
end
