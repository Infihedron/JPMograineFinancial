--[[ JP Mograine Financial
     Copyright (C) 2026 Infihedron

     This program is free software: you can redistribute it and/or modify it under the terms
     of the GNU General Public License as published by the Free Software Foundation, either
     version 3 of the License, or (at your option) any later version. It is distributed
     WITHOUT ANY WARRANTY; see the LICENSE file for details.

     The names JP Mograine Financial, Morgrim Stanley, Gadgetzan Sachs and Infihedron, and
     their branding, are not licensed under the GPL; see NOTICE.md. Not affiliated with or
     endorsed by Blizzard Entertainment or any real financial institution.

     Core: saved data, events, error capture, debug log, slash commands, diagnostics. ]]

local ADDON, ns = ...
ns.VERSION = "1.1.1"
ns.SCHEMA = 2
ns.NAME = "JP Mograine Financial"
ns.GOLD_HEX = "e9c86a"

---------------------------------------------------------------------------
-- Money helpers (all amounts are copper)
---------------------------------------------------------------------------
local floor, abs = math.floor, math.abs

function ns.Money(c, color)
  c = floor((c or 0) + 0.5)
  local neg = c < 0
  c = abs(c)
  local g, s, cp = floor(c / 10000), floor(c / 100) % 100, c % 100
  local parts = {}
  local gc, sc, cc = "", "", ""
  if color then gc, sc, cc = "|cffffd100", "|cffc7c7cf", "|cffeda55f" end
  local e = color and "|r" or ""
  if g > 0 then parts[#parts + 1] = g .. gc .. "g" .. e end
  if s > 0 then parts[#parts + 1] = s .. sc .. "s" .. e end
  if cp > 0 or #parts == 0 then
    if g < 100 then parts[#parts + 1] = cp .. cc .. "c" .. e end
  end
  if #parts == 0 then parts[1] = "0" .. cc .. "c" .. e end
  return (neg and "-" or "") .. table.concat(parts, " ")
end

-- "90", "90g", "90g 50s", "1.5", "50s", "12c" -> copper (nil if nothing usable)
function ns.ParseMoney(str)
  if type(str) ~= "string" then return nil end
  str = str:lower():gsub(",", "")
  local total, found = 0, false
  for num, unit in str:gmatch("([%d%.]+)%s*([gsc])") do
    local n = tonumber(num)
    if n then
      found = true
      total = total + n * (unit == "g" and 10000 or unit == "s" and 100 or 1)
    end
  end
  if not found then
    local n = tonumber(str:match("^%s*([%d%.]+)%s*$") or "")
    if not n then return nil end
    total = n * 10000
  end
  return floor(total + 0.5)
end

function ns.Ago(t)
  if not t then return "never" end
  local d = time() - t
  if d < 3600 then return floor(d / 60) .. "m ago" end
  if d < 86400 then return floor(d / 3600) .. "h ago" end
  return floor(d / 86400) .. "d ago"
end

function ns.Say(msg)
  print("|cff" .. ns.GOLD_HEX .. "JP Mograine|r: " .. msg)
end

---------------------------------------------------------------------------
-- Saved data
---------------------------------------------------------------------------
local ACCOUNT_DEFAULTS = {
  settings = {
    rawDays = 14, debug = false, autoPlan = true, includeProfTraining = false, includePetTraining = true, overdraft = "hold",
    minimap = { angle = 215, hide = false }, morgrimCreature = 2455,
    rateOverride = nil, hplOverride = nil,
  },
  wishlist = {}, household = {}, log = {}, errors = {}, uncat = {},
}

local CHAR_DEFAULTS = {
  raw = {}, daily = {}, monthly = {}, goals = {}, debits = { class = {}, prof = {}, pet = {} },
  played = 0, levels = {}, lastPlan = 0, nextGoalId = 1, acctLog = {}, trainerIgnore = {},
}

local function Fill(t, d)
  for k, v in pairs(d) do
    if t[k] == nil then
      if type(v) == "table" then t[k] = {}; Fill(t[k], v) else t[k] = v end
    elseif type(v) == "table" and type(t[k]) == "table" then
      Fill(t[k], v)
    end
  end
end

-- Schema migrations: each step moves saved data forward one version.
local MIGRATIONS = {
  -- 2: versions before 1.0.7 filed pet trainer prices as class training; rescan
  [2] = function(db)
    if db.debits then db.debits.class = {}; db.debits.scannedAt = nil end
  end,
}

local function Migrate(db)
  db.schema = db.schema or ns.SCHEMA
  while db.schema < ns.SCHEMA do
    local step = MIGRATIONS[db.schema + 1]
    if step then step(db) end
    db.schema = db.schema + 1
  end
end

---------------------------------------------------------------------------
-- Debug log and error capture
---------------------------------------------------------------------------
local LOG_MAX, ERR_MAX = 500, 20

function ns.Log(fmt, ...)
  if not (ns.acct and ns.acct.settings.debug) then return end
  local ok, line = pcall(string.format, fmt, ...)
  if not ok then line = tostring(fmt) end
  local log = ns.acct.log
  log[#log + 1] = date("%m-%d %H:%M:%S ") .. line
  while #log > LOG_MAX do table.remove(log, 1) end
end

local function ErrorHandler(err)
  local where = debugstack and debugstack(3, 2, 0) or ""
  if ns.acct then
    local e = ns.acct.errors
    e[#e + 1] = { t = time(), msg = tostring(err), where = where }
    while #e > ERR_MAX do table.remove(e, 1) end
  end
  ns.Log("ERROR %s", tostring(err))
  return err
end

-- Run fn safely: our errors are recorded, never thrown into the player's game.
function ns.Safe(fn, ...)
  local args, n = { ... }, select("#", ...)
  return xpcall(function() return fn(unpack(args, 1, n)) end, ErrorHandler)
end

---------------------------------------------------------------------------
-- Events
---------------------------------------------------------------------------
local handlers = {}
local frame = CreateFrame("Frame")
ns.eventFrame = frame

function ns.On(event, fn)
  if not handlers[event] then
    handlers[event] = {}
    if not event:find("^JPMF_") then pcall(frame.RegisterEvent, frame, event) end
  end
  table.insert(handlers[event], fn)
end

function ns.Fire(event, ...)
  local list = handlers[event]
  if not list then return end
  for _, fn in ipairs(list) do ns.Safe(fn, event, ...) end
end

frame:SetScript("OnEvent", function(_, event, ...) ns.Fire(event, ...) end)

ns.On("ADDON_LOADED", function(_, name)
  if name ~= ADDON then return end
  JPMF_DB = JPMF_DB or {}
  JPMF_CharDB = JPMF_CharDB or {}
  Fill(JPMF_DB, ACCOUNT_DEFAULTS)
  Fill(JPMF_CharDB, CHAR_DEFAULTS)
  Migrate(JPMF_DB)
  Migrate(JPMF_CharDB)
  ns.acct, ns.char = JPMF_DB, JPMF_CharDB
  ns.Fire("JPMF_DATA_READY")
end)

function ns.CharKey()
  return (UnitName("player") or "?") .. "-" .. (GetRealmName() or "?")
end

---------------------------------------------------------------------------
-- Diagnostics
---------------------------------------------------------------------------
local function Count(t) local n = 0 for _ in pairs(t or {}) do n = n + 1 end return n end

function ns.StorageEstimate()
  local c = ns.char
  local raw, days, months = #c.raw, Count(c.daily), Count(c.monthly)
  local prices = 0
  for _, w in pairs(ns.acct.wishlist) do prices = prices + #(w.points or {}) end
  -- rough bytes as written to the saved-variables file
  local bytes = raw * 70 + days * 360 + months * 260 + prices * 40 + #ns.acct.log * 70
  return bytes, { raw = raw, days = days, months = months, prices = prices, log = #ns.acct.log }
end

function ns.Report()
  local lines = {}
  local function add(fmt, ...) lines[#lines + 1] = string.format(fmt, ...) end
  local v, build, _, iface = GetBuildInfo()
  add("JP Mograine Financial %s (schema %d)", ns.VERSION, ns.SCHEMA)
  add("Game %s build %s, interface %s", tostring(v), tostring(build), tostring(iface))
  add("Character %s, level %d", ns.CharKey(), UnitLevel("player") or 0)
  add("APIs: classicAH=%s modernAH=%s trainerLevelReq=%s createLine=%s tooltipProcessor=%s",
    tostring(GetAuctionItemInfo ~= nil), tostring(C_AuctionHouse ~= nil),
    tostring(GetTrainerServiceLevelReq ~= nil), tostring(UIParent.CreateLine ~= nil),
    tostring(TooltipDataProcessor ~= nil))
  local bytes, n = ns.StorageEstimate()
  add("Storage ~%d KB: raw %d, days %d, months %d, price points %d, log %d",
    math.floor(bytes / 1024), n.raw, n.days, n.months, n.prices, n.log)
  add("Settings: rawDays=%d debug=%s autoPlan=%s", ns.acct.settings.rawDays,
    tostring(ns.acct.settings.debug), tostring(ns.acct.settings.autoPlan))
  local d = ns.char.debits
  local function Levels(t)
    local parts = {}
    for l, c in pairs(t or {}) do parts[#parts + 1] = ("%d=%s"):format(l, ns.Money(c)) end
    table.sort(parts)
    return #parts > 0 and table.concat(parts, ", ") or "none"
  end
  add("Class trainer scan: %s / %s", d.scannedAt and date("%m-%d %H:%M", d.scannedAt) or "never", Levels(d.class))
  add("Pet trainer scan: %s / %s", d.petAt and date("%m-%d %H:%M", d.petAt) or "never", Levels(d.pet))
  add("Profession trainer scan: %s / %s", d.profAt and date("%m-%d %H:%M", d.profAt) or "never", Levels(d.prof))
  local ign = {}
  for name in pairs(ns.char.trainerIgnore or {}) do ign[#ign + 1] = name end
  table.sort(ign)
  add("Skipped by you: %s", #ign > 0 and table.concat(ign, ", ") or "none")
  for _, kind in ipairs({ "class", "pet", "profession", "empty" }) do
    local td = (ns.acct.trainerDumps or {})[kind]
    if td then
      local cats = {}
      for k, c in pairs(td.cats or {}) do cats[#cats + 1] = k .. "=" .. c end
      table.sort(cats)
      add("Last %s trainer: %s at %s, %d services, %s counted, spellbook %s, requirement info %s, filter=%s, status: %s",
        kind, tostring(td.npc), date("%m-%d %H:%M", td.t), td.n or 0, tostring(td.counted or 0),
        tostring(td.spellbook), tostring(td.reqAPI), tostring(td.filter), #cats > 0 and table.concat(cats, ", ") or "none")
      if kind ~= "empty" then
        add("  talent-locked, left out: %s", #(td.skipped or {}) > 0 and table.concat(td.skipped, ", ") or "none")
        for _, r in ipairs(td.raw or {}) do add("  raw: %s", r) end
        for _, r in ipairs(td.sample or {}) do add("  %s", r) end
      end
    end
  end
  add("Uncategorized gold changes: %d recorded", #ns.acct.uncat)
  for i = math.max(1, #ns.acct.uncat - 4), #ns.acct.uncat do
    local u = ns.acct.uncat[i]
    if u then add("  %s %s [%s]", date("%m-%d %H:%M", u.t), ns.Money(u.a), u.ctx) end
  end
  add("Errors: %d recorded", #ns.acct.errors)
  for i = math.max(1, #ns.acct.errors - 4), #ns.acct.errors do
    local e = ns.acct.errors[i]
    if e then add("  %s %s / %s", date("%m-%d %H:%M", e.t), e.msg, (e.where or ""):gsub("\n", " ")) end
  end
  return table.concat(lines, "\n")
end

---------------------------------------------------------------------------
-- Slash commands
---------------------------------------------------------------------------
SLASH_JPMOGRAINE1, SLASH_JPMOGRAINE2 = "/jpm", "/mograine"
SlashCmdList.JPMOGRAINE = function(msg)
  msg = msg or ""
  local cmd, rest = msg:match("^(%S*)%s*(.-)$")
  cmd = (cmd or ""):lower()
  if cmd == "" then
    if ns.ToggleMain then ns.ToggleMain() end
  elseif cmd == "debug" then
    ns.acct.settings.debug = not ns.acct.settings.debug
    ns.Say("debug log " .. (ns.acct.settings.debug and "ON" or "off") .. ". /jpm log to view it.")
  elseif cmd == "log" then
    if rest == "clear" then wipe(ns.acct.log); ns.Say("log cleared"); return end
    ns.ShowCopy("Debug log", #ns.acct.log > 0 and table.concat(ns.acct.log, "\n")
      or "(empty: turn it on with /jpm debug, play a while, then /jpm log)")
  elseif cmd == "report" then
    ns.ShowCopy("Diagnostic report", ns.Report())
  elseif cmd == "plan" then
    if ns.OpenPlanning then ns.OpenPlanning(true) end
  elseif cmd == "watch" then
    if ns.WatchFromSlash then ns.WatchFromSlash(rest) end
  elseif cmd == "skip" or cmd == "unskip" then
    -- leave a trainer skill out of planned costs (a talent you will never take)
    local name = rest:match("|h%[(.-)%]|h") or rest:match("^%s*(.-)%s*$")
    local ign = ns.char.trainerIgnore
    if name == "" then
      local list = {}
      for n in pairs(ign) do list[#list + 1] = n end
      table.sort(list)
      ns.Say("Skipped trainer skills: " .. (#list > 0 and table.concat(list, ", ") or "none")
        .. ". /jpm skip <name> to add, /jpm unskip <name> to remove.")
      return
    end
    ign[name] = (cmd == "skip") or nil
    ns.Say(("%s will %s counted in planned training. Visit your trainer to update the totals."):format(
      name, cmd == "skip" and "no longer be" or "again be"))
  elseif cmd == "morgrim" then
    local id = tonumber(rest)
    if rest:lower() == "target" then
      -- cast Morgrim from whoever you are targeting: "Creature-0-x-x-x-<npcID>-x"
      local guid = UnitGUID("target")
      local kind, _, _, _, _, npc = strsplit("-", guid or "")
      id = (kind == "Creature" or kind == "Vehicle") and tonumber(npc) or nil
      if not id then ns.Say("Target an NPC first, then type /jpm morgrim target."); return end
    end
    if id then
      ns.acct.settings.morgrimCreature = id
      ns.Say(("Morgrim will now appear as creature %d%s."):format(id,
        UnitExists("target") and (" (" .. (UnitName("target") or "?") .. ")") or ""))
      if ns.OpenPlanning then ns.OpenPlanning(true) end
    else
      ns.Say("Target the NPC you want as Morgrim and type /jpm morgrim target (or /jpm morgrim <creature id>).")
    end
  else
    ns.Say("/jpm - open | /jpm plan - planning session | /jpm watch <item link> [target]")
    ns.Say("/jpm debug | /jpm log | /jpm report | /jpm skip <trainer skill> | /jpm morgrim target")
  end
end
