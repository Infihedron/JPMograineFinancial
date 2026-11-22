--[[ JP Mograine Financial - Copyright (C) 2026 Infihedron. Licensed under the GNU GPL v3 or later; see LICENSE.
     Pages: Dashboard, Accounts, Forecast, Ledger, Wishlist, Statement, Settings. ]]

local _, ns = ...
local UI = ns.UI
local C = UI.C
local floor, max, min, abs = math.floor, math.max, math.min, math.abs

local function TextPool(owner)
  local pool = { owner = owner, list = {}, n = 0 }
  function pool:Reset() for _, t in ipairs(self.list) do t:Hide() end; self.n = 0 end
  function pool:Get(size, color, font)
    self.n = self.n + 1
    local t = self.list[self.n]
    if not t then t = UI.Text(self.owner, size, color, font); self.list[self.n] = t end
    t:SetFont(font or UI.FONT, size or 11, "")
    color = color or C.muted
    t:SetTextColor(color[1], color[2], color[3])
    t:ClearAllPoints()
    t:Show()
    return t
  end
  return pool
end

local function Card(parent, w, h, title)
  local f = UI.Box(parent, C.panel, C.line)
  f:SetSize(w, h)
  if title then
    f.title = UI.Text(f, 10.5, C.muted)
    f.title:SetPoint("TOPLEFT", 12, -10)
    f.title:SetText(title:upper())
  end
  return f
end

local function Popup(key, text, onAccept, hasEditBox)
  StaticPopupDialogs[key] = {
    text = text, button1 = ACCEPT or "Accept", button2 = CANCEL or "Cancel",
    hasEditBox = hasEditBox, timeout = 0, whileDead = true, hideOnEscape = true, preferredIndex = 3,
    OnAccept = function(self, data)
      local box = self.editBox or self.EditBox
      ns.Safe(onAccept, data, box and box:GetText())
    end,
    EditBoxOnEnterPressed = function(self)
      local parent = self:GetParent()
      local box = parent.editBox or parent.EditBox
      ns.Safe(onAccept, parent.data, box and box:GetText())
      parent:Hide()
    end,
  }
end

---------------------------------------------------------------------------
-- Shared forecast chart
---------------------------------------------------------------------------
local nowDots = {}
local function DrawForecast(holder, lines, texts, w, h, levels, compact)
  lines:Reset(); texts:Reset()
  local pts, gph, hpl = ns.Forecast(levels)
  local padL, padB, padT, padR = 44, 22, 14, 14
  local cw, ch = w - padL - padR, h - padB - padT
  if not ns.HasPace() then
    if nowDots[holder] then nowDots[holder]:Hide() end
    local t = texts:Get(12, C.muted)
    t:SetPoint("CENTER", holder, "CENTER")
    t:SetText("Morgrim needs about 30 minutes of play data before he can project your gold.")
    return
  end
  local goals, cum = {}, 0
  for _, g in ipairs(ns.char.goals) do
    if g.kind ~= "training" then
      local own = ns.GoalTarget(g)
      cum = cum + own
      if own > 0 then goals[#goals + 1] = { name = g.name, own = own, amount = cum } end
    end
  end
  -- the chart never goes below zero; a shortfall is reported in words instead
  local ymax, ymin = 0, 0
  local short, shortLevel = 0, nil
  for _, p in ipairs(pts) do
    ymax = max(ymax, p.peak)
    if p.after < short then short, shortLevel = p.after, p.level end
  end
  for _, g in ipairs(goals) do ymax = max(ymax, g.amount) end
  -- the last two levels you actually played, drawn solid to the left of "now"
  local cur = pts[1].level
  local hist = {}
  for _, h in ipairs(ns.LevelHistory()) do
    if h.level >= cur - 2 and h.level <= cur then hist[#hist + 1] = h; ymax = max(ymax, h.gold) end
  end
  ymax = max(ymax * 1.1, 10000)
  -- "now" sits partway through your current level, by experience
  local frac = 0
  if UnitXP and UnitXPMax then
    local ok, xp, mx = pcall(function() return UnitXP("player"), UnitXPMax("player") end)
    if ok and type(xp) == "number" and type(mx) == "number" and mx > 0 then frac = min(0.95, xp / mx) end
  end
  local nowX = cur + frac
  local L0, L1 = (#hist > 0 and hist[1].level or cur), pts[#pts].level
  local function X(l)
    if l == cur then l = nowX end
    return padL + (L1 > L0 and (l - L0) / (L1 - L0) or 0) * cw
  end
  local function XL(l) return padL + (L1 > L0 and (l - L0) / (L1 - L0) or 0) * cw end
  local function Y(v) return padB + (max(v, 0) - ymin) / (ymax - ymin) * ch end

  -- gridlines and gold ticks
  for i = 0, 4 do
    local v = ymin + (ymax - ymin) * i / 4
    lines:Line(padL, Y(v), padL + cw, Y(v), C.grid, 1)
    local t = texts:Get(10, C.muted, UI.NUM)
    t:SetPoint("RIGHT", holder, "BOTTOMLEFT", padL - 6, Y(v))
    t:SetText(floor(v / 10000) .. "g")
  end
  local step = (L1 - L0) > 10 and 2 or 1
  for l = L0, L1, step do
    local t = texts:Get(10, C.muted, UI.NUM)
    t:SetPoint("TOP", holder, "BOTTOMLEFT", XL(l), padB - 4)
    t:SetText(l == L0 and ("Lv " .. l) or tostring(l))
  end
  -- history: gold as you reached each recent level, then on to now
  for i, h in ipairs(hist) do
    local nx, ny
    if hist[i + 1] then nx, ny = XL(hist[i + 1].level), Y(hist[i + 1].gold) else nx, ny = X(cur), Y(pts[1].peak) end
    lines:Line(XL(h.level), Y(h.gold), nx, ny, C.text, 2)
    local tick = texts:Get(9, C.muted, UI.NUM)
    tick:SetPoint("BOTTOM", holder, "BOTTOMLEFT", XL(h.level), Y(h.gold) + 4)
    tick:SetText(ns.Money(h.gold))
  end
  if #hist > 0 and not compact then
    local lab = texts:Get(10, C.muted)
    lab:SetPoint("BOTTOMLEFT", holder, "BOTTOMLEFT", XL(hist[1].level) + 2, padB + 4)
    lab:SetText("your last levels")
  end
  -- goal lines
  for _, g in ipairs(goals) do
    if g.amount <= ymax then
      UI.Dashed(lines, padL, Y(g.amount), padL + cw, Y(g.amount), C.goldDim, 1.5, 6, 5)
      local t = texts:Get(compact and 10 or 11, C.gold)
      t:SetPoint("BOTTOMLEFT", holder, "BOTTOMLEFT", padL + 4, Y(g.amount) + 2)
      t:SetText(g.name .. " \194\183 " .. ns.Money(g.own))
      local eta = ns.ArrivalLevel(g.amount, pts)
      if eta and eta <= L1 then
        local ring = texts:Get(16, C.gold)
        ring:SetPoint("CENTER", holder, "BOTTOMLEFT", X(eta), Y(g.amount))
        ring:SetText("o")
      end
    end
  end
  -- the projection: rise between levels, step down for each level's costs
  for i = 2, #pts do
    local a, b = pts[i - 1], pts[i]
    UI.Dashed(lines, X(a.level), Y(a.after), X(b.level), Y(b.peak), C.mint, 2.5, 7, 5)
    if b.debit > 0 then
      lines:Line(X(b.level), Y(b.peak), X(b.level), Y(b.after), C.red, 2)
      if not compact and b.spend then
        local t = texts:Get(10, C.red)
        t:SetPoint("RIGHT", holder, "BOTTOMLEFT", X(b.level) - 6, Y(b.after) + 6)
        t:SetText("account purchase")
      end
    end
  end
  if pts[1].debit > 0 then lines:Line(X(L0), Y(pts[1].peak), X(L0), Y(pts[1].after), C.red, 2) end
  -- "now" marker: a drawn dot (the game font has no circle glyph)
  local dot = nowDots[holder]
  if not dot then
    dot = holder:CreateTexture(nil, "OVERLAY", nil, 7)
    dot:SetSize(10, 10)
    dot:SetColorTexture(C.mint[1], C.mint[2], C.mint[3], 1)
    nowDots[holder] = dot
  end
  dot:ClearAllPoints()
  dot:SetPoint("CENTER", holder, "BOTTOMLEFT", X(L0), Y(pts[1].peak))
  dot:Show()
  local nowLabel = texts:Get(10, C.mint)
  nowLabel:SetPoint("TOP", holder, "BOTTOMLEFT", X(L0) + 14, Y(pts[1].peak) - 8)
  nowLabel:SetText("now")
  if shortLevel then
    local warn = texts:Get(compact and 11 or 12.5, C.red)
    warn:SetPoint("BOTTOMRIGHT", holder, "BOTTOMLEFT", X(shortLevel) - 8, padB + 8)
    warn:SetText(("Short by about %s at level %d"):format(ns.Money(-short), shortLevel))
  end
  return pts, gph, hpl
end
ns.DrawForecast = DrawForecast

---------------------------------------------------------------------------
-- Dashboard
---------------------------------------------------------------------------
ns.RegisterPage("Dashboard", function(page, f)
  local gold = Card(f, 230, 112, "Net worth"); gold:SetPoint("TOPLEFT", 0, 0)
  gold.value = UI.Text(gold, 22, { 0.953, 0.863, 0.561 }, UI.NUM); gold.value:SetPoint("TOPLEFT", 12, -28)
  gold.seg = UI.SegBar(gold, 206, 8); gold.seg:SetPoint("TOPLEFT", gold, "TOPLEFT", 12, -58)
  gold.sub = UI.Text(gold, 11, C.muted); gold.sub:SetPoint("TOPLEFT", 12, -72); gold.sub:SetWidth(206)
  -- items are shown apart from net worth, which stays the gold you actually have
  gold.assets = UI.Text(gold, 10.5, C.muted); gold.assets:SetPoint("TOPLEFT", 12, -90); gold.assets:SetWidth(206)

  local net = Card(f, 230, 80, "Net, last 7 days"); net:SetPoint("TOPLEFT", gold, "BOTTOMLEFT", 0, -10)
  net.value = UI.Text(net, 20, C.green, UI.NUM); net.value:SetPoint("TOPLEFT", 12, -28)
  net.sub = UI.Text(net, 11, C.muted); net.sub:SetPoint("TOPLEFT", 12, -56)

  local rate = Card(f, 230, 80, "Your pace"); rate:SetPoint("TOPLEFT", net, "BOTTOMLEFT", 0, -10)
  rate.value = UI.Text(rate, 20, C.text, UI.NUM); rate.value:SetPoint("TOPLEFT", 12, -28)
  rate.sub = UI.Text(rate, 11, C.muted); rate.sub:SetPoint("TOPLEFT", 12, -56)

  local deb = Card(f, 230, 174, "Upcoming costs"); deb:SetPoint("TOPLEFT", rate, "BOTTOMLEFT", 0, -10)
  deb.pool = TextPool(deb)

  local fc = Card(f, 430, 270, "Forecast"); fc:SetPoint("TOPLEFT", 242, 0)
  local chart = CreateFrame("Frame", nil, fc); chart:SetPoint("TOPLEFT", 4, -26); chart:SetSize(422, 240)
  local lines, texts = UI.LinePool(chart), TextPool(chart)

  local led = Card(f, 430, 196, "This week's ledger"); led:SetPoint("TOPLEFT", fc, "BOTTOMLEFT", 0, -10)
  led.rows = {}
  for i = 1, 8 do
    local r = {}
    r.name = UI.Text(led, 11.5, C.text); r.name:SetPoint("TOPLEFT", 12, -14 - i * 20); r.name:SetWidth(120)
    r.bar = UI.Bar(led, 190, 8); r.bar:SetPoint("TOPLEFT", led, "TOPLEFT", 136, -18 - i * 20)
    r.amt = UI.Text(led, 11.5, C.text, UI.NUM); r.amt:SetPoint("TOPRIGHT", -12, -14 - i * 20); r.amt:SetJustifyH("RIGHT")
    led.rows[i] = r
  end

  local gc = Card(f, 236, 250, "Accounts"); gc:SetPoint("TOPLEFT", 684, 0)
  gc.rows = {}
  for i = 1, 3 do
    local r = {}
    r.name = UI.Text(gc, 12, C.text); r.name:SetPoint("TOPLEFT", 12, -12 - i * 48 + 18)
    r.amt = UI.Text(gc, 10.5, C.muted, UI.NUM); r.amt:SetPoint("TOPRIGHT", -12, -12 - i * 48 + 18); r.amt:SetJustifyH("RIGHT")
    r.bar = UI.Bar(gc, 212, 9); r.bar:SetPoint("TOPLEFT", gc, "TOPLEFT", 12, -12 - i * 48 + 2)
    r.sub = UI.Text(gc, 10.5, C.muted); r.sub:SetPoint("TOPLEFT", 12, -12 - i * 48 - 10)
    gc.rows[i] = r
  end
  gc.freeName = UI.Text(gc, 12, C.text); gc.freeName:SetPoint("TOPLEFT", 12, -176); gc.freeName:SetText("Free to spend")
  gc.freeAmt = UI.Text(gc, 12, C.text, UI.NUM); gc.freeAmt:SetPoint("TOPRIGHT", -12, -176); gc.freeAmt:SetJustifyH("RIGHT")
  local manage = UI.Button(gc, "Manage accounts", 212, 24, function() ns.ShowPage("Accounts") end)
  manage:SetPoint("BOTTOMLEFT", 12, 10)

  local mg = UI.Box(f, { 0.106, 0.090, 0.063 }, C.trim); mg:SetSize(236, 206)
  mg:SetPoint("TOPLEFT", gc, "BOTTOMLEFT", 0, -10)
  local who = UI.Text(mg, 13, C.gold); who:SetPoint("TOPLEFT", 12, -10); who:SetText("Morgrim Stanley")
  mg.quote = UI.Text(mg, 11.5, { 0.902, 0.863, 0.761 }); mg.quote:SetPoint("TOPLEFT", 12, -30)
  mg.quote:SetWidth(212); mg.quote:SetJustifyV("TOP"); mg.quote:SetHeight(130)
  local go = UI.Button(mg, "Planning session", 212, 24, function() ns.OpenPlanning(true) end)
  go:SetPoint("BOTTOMLEFT", 12, 10)

  function page:Refresh()
    local saved = ns.Balances()
    local segs, held, free = UI.WorthSegments()
    gold.value:SetText(ns.Money(GetMoney(), true))
    gold.seg:Set(segs)
    if free < 0 then
      gold.sub:SetText(("|cfff08b80Overdrawn by %s|r"):format(ns.Money(-free)))
    else
      gold.sub:SetText(("%s in accounts \194\183 %s free"):format(ns.Money(held), ns.Money(free)))
    end

    local st = ns.Statement(7)
    net.value:SetText((st.net >= 0 and "+" or "") .. ns.Money(st.net))
    local c = st.net >= 0 and C.green or C.red
    net.value:SetTextColor(c[1], c[2], c[3])
    net.sub:SetText(("Earned %s \194\183 spent %s"):format(ns.Money(st.income), ns.Money(-st.spend)))

    local vendor = ns.Assets()
    gold.assets:SetText(("Assets: %s in items (separate)"):format(ns.Money(vendor)))
    local gph, overridden = ns.GoldPerHour()
    local fNet, _, info = ns.PerLevelPace()
    if fNet and ns.acct.settings.pace ~= "hour" and not overridden then
      local cur = UnitLevel("player")
      rate.value:SetText(ns.Money(fNet(cur)) .. " / level")
      rate.sub:SetText(("About %s by level %d (from %d levels)"):format(ns.Money(fNet(min(cur + 5, 60))), min(cur + 5, 60), info.levels))
    else
      rate.value:SetText(gph and (ns.Money(gph) .. " / hour") or "--")
      rate.sub:SetText(overridden and "Your override" or gph and "Last 14 days, training excluded"
        or "Gathering data: finish two levels for gold per level")
    end

    deb.pool:Reset()
    local d, cur, y = ns.Debits(), UnitLevel("player"), -30
    local lvls = {}
    for l in pairs(d) do if l >= cur then lvls[#lvls + 1] = l end end
    for _, g in ipairs(ns.char.goals) do if g.spend and g.level and g.level >= cur then lvls[#lvls + 1] = -g.id end end
    table.sort(lvls, function(a, b) return abs(a) < abs(b) end)
    local shown = 0
    for _, l in ipairs(lvls) do
      if shown >= 6 then break end
      local label, amount
      if l > 0 then
        label, amount = (l == cur and "Due now" or ("Lv %d class training"):format(l)), d[l]
      else
        for _, g in ipairs(ns.char.goals) do if g.id == -l then label, amount = ("Lv %d %s"):format(g.level, g.name), ns.GoalTarget(g) end end
      end
      if label then
        local a = deb.pool:Get(11.5, C.text); a:SetPoint("TOPLEFT", 12, y); a:SetText(label)
        local b = deb.pool:Get(11.5, C.red, UI.NUM); b:SetPoint("TOPRIGHT", -12, y); b:SetText("-" .. ns.Money(amount))
        y, shown = y - 20, shown + 1
      end
    end
    if shown == 0 then
      local a = deb.pool:Get(11, C.muted); a:SetPoint("TOPLEFT", 12, y); a:SetWidth(206)
      a:SetText("Visit your class trainer once and your upcoming training costs appear here.")
    elseif ns.char.debits.scannedAt then
      local a = deb.pool:Get(10, C.muted); a:SetPoint("BOTTOMLEFT", 12, 10)
      a:SetText("Trainer prices from " .. ns.Ago(ns.char.debits.scannedAt))
    end

    DrawForecast(chart, lines, texts, 422, 240, 8, true)

    local rows = {}
    for _, e in ipairs(st.cats) do rows[#rows + 1] = e end
    table.sort(rows, function(a, b) return abs(a.p + a.n) > abs(b.p + b.n) end)
    local biggest = 1
    for _, e in ipairs(rows) do biggest = max(biggest, abs(e.p + e.n)) end
    for i, r in ipairs(led.rows) do
      local e = rows[i]
      if e then
        local v = e.p + e.n
        r.name:SetText(e.cat); r.amt:SetText((v >= 0 and "+" or "") .. ns.Money(v))
        local col = v >= 0 and C.green or C.red
        r.amt:SetTextColor(col[1], col[2], col[3])
        r.bar:Set(abs(v) / biggest, col)
        r.name:Show(); r.amt:Show(); r.bar:SetShown(true); r.bar:Set(abs(v) / biggest, col)
      else
        r.name:Hide(); r.amt:Hide(); r.bar:SetShown(false)
      end
    end
    if #rows == 0 then led.rows[1].name:SetText("No gold has moved yet this week."); led.rows[1].name:Show() end

    local pts = ns.Forecast(15)
    for i, r in ipairs(gc.rows) do
      local g = ns.char.goals[i]
      if g then
        local t = ns.GoalTarget(g)
        local s = saved[g.id] or 0
        local col = UI.AccountColor(i, g)
        r.name:SetText(g.name)
        r.amt:SetText(t > 0 and (ns.Money(s) .. " / " .. ns.Money(t)) or ns.Money(s))
        local eta = (t > 0 and s < t) and ns.GoalArrival(g, pts)
        local bits = {}
        if g.rule then bits[#bits + 1] = ("Auto %d%%"):format(g.rule) end
        if g.kind == "training" and t > 0 then
          local _, lvl = ns.NextTraining()
          if lvl then bits[#bits + 1] = lvl <= UnitLevel("player") and "Train now" or ("For Lv " .. lvl) end
        end
        if t <= 0 then
          bits[#bits + 1] = g.kind == "training" and "Visit your class trainer" or "No target"
        elseif s >= t then
          bits[#bits + 1] = "Funded"
        else
          bits[#bits + 1] = ("%d%%"):format(floor(s / t * 100))
          if ns.CanFillNow(g) then bits[#bits + 1] = "Can fill now"
          elseif eta then bits[#bits + 1] = ("ETA Lv %.1f"):format(eta) end
        end
        r.sub:SetText(table.concat(bits, " \194\183 "))
        r.name:Show(); r.amt:Show(); r.sub:Show(); r.bar:SetShown(true)
        r.bar:Set(t > 0 and s / t or (s > 0 and 1 or 0), col)
      else
        r.name:SetShown(i == 1); r.amt:Hide(); r.sub:Hide(); r.bar:SetShown(false)
        if i == 1 then r.name:SetText("No accounts yet. A mount fund is the classic.") end
      end
    end
    local _, _, freeNow = ns.Balances()
    gc.freeAmt:SetText(ns.Money(freeNow))
    local fc2 = freeNow < 0 and C.red or C.text
    gc.freeAmt:SetTextColor(fc2[1], fc2[2], fc2[3])
    gc.freeName:SetText(freeNow < 0 and "Overdrawn" or "Free to spend")

    local quote = ns.MorgrimLines()
    mg.quote:SetText("\"" .. (quote[3] or quote[1] or "") .. "\"")
  end
end)

---------------------------------------------------------------------------
-- Accounts
---------------------------------------------------------------------------
ns.RegisterPage("Accounts", function(page, f)
  local head = UI.Heading(f, "Accounts"); head:SetPoint("TOPLEFT", 0, 0)
  local how = UI.Text(f, 11, C.muted); how:SetPoint("LEFT", head, "RIGHT", 12, -1); how:SetWidth(760)
  how:SetText("Your gold is one pile; accounts set shares of it aside. Deposits come from Free. Auto rules take a percent of everything you earn.")

  -- summary strip: net worth, the split, and Free
  local sum = Card(f, 918, 40); sum:SetPoint("TOPLEFT", 0, -26)
  sum.text = UI.Text(sum, 12, C.text, UI.NUM); sum.text:SetPoint("LEFT", 12, 0); sum.text:SetWidth(640)
  sum.seg = UI.SegBar(sum, 240, 12); sum.seg:SetPoint("RIGHT", sum, "RIGHT", -12, 0)

  local function Selected() return ns.FindAccount(page.pick) end
  Popup("JPMF_SET_TARGET", "Target for this account (for example 90g or 12g 50s). Leave empty for no target:", function(id, text)
    local g = ns.FindAccount(id); if not g then return end
    if not text or text:match("^%s*$") then g.target = 0
    else
      local v = ns.ParseMoney(text)
      if not v then ns.Say("I could not read that amount."); return end
      g.target = v
    end
    ns.Fire("JPMF_GOALS_CHANGED")
  end, true)
  Popup("JPMF_DEPOSIT", "Deposit how much from Free? (for example 5g, or \"all\")", function(id, text)
    local v = (text or ""):lower():match("^%s*all%s*$") and math.huge or ns.ParseMoney(text)
    if not v then ns.Say("I could not read that amount."); return end
    local g = ns.FindAccount(id)
    if g and v == math.huge then v = math.min(ns.AccountRoom(g), math.max(0, ns.Free())) end
    local done = ns.Deposit(id, v)
    if done <= 0 then ns.Say("Nothing free to deposit.") end
  end, true)
  Popup("JPMF_WITHDRAW", "Withdraw how much back to Free? (for example 5g, or \"all\")", function(id, text)
    local v = (text or ""):lower():match("^%s*all%s*$") and math.huge or ns.ParseMoney(text)
    if not v then ns.Say("I could not read that amount."); return end
    ns.Withdraw(id, v)
  end, true)
  Popup("JPMF_RULE", "Auto-deposit what percent of everything you earn? (0 turns it off)", function(id, text)
    local want = tonumber((text or ""):match("([%d%.]+)")) or 0
    local got = ns.SetRule(id, want)
    if want > 0 and (got or 0) < math.floor(want + 0.5) then
      ns.Say(("Your rules together can't pass 100%%, so this one is set to %d%%."):format(got or 0))
    end
  end, true)
  local function Ask(key, id)
    local dlg = StaticPopup_Show(key)
    if dlg then dlg.data = id end
  end

  local rows = {}
  for i = 1, 6 do
    local r = UI.Box(f, C.panel, C.line)
    r:SetSize(918, 44); r:SetPoint("TOPLEFT", 0, -74 - (i - 1) * 46)
    r.swatch = r:CreateTexture(nil, "OVERLAY"); r.swatch:SetSize(4, 36); r.swatch:SetPoint("LEFT", 4, 0)
    r.rank = UI.Text(r, 13, C.gold, UI.NUM); r.rank:SetPoint("LEFT", 14, 0)
    r.name = UI.Text(r, 12.5, C.text); r.name:SetPoint("TOPLEFT", 36, -7); r.name:SetWidth(200)
    r.note = UI.Text(r, 10.5, C.muted); r.note:SetPoint("TOPLEFT", 36, -25); r.note:SetWidth(210)
    r.bar = UI.Bar(r, 150, 10); r.bar:SetPoint("LEFT", r, "LEFT", 240, 6)
    r.amt = UI.Text(r, 11, C.muted, UI.NUM); r.amt:SetPoint("TOPLEFT", 240, -25)
    r.eta = UI.Text(r, 11, C.text); r.eta:SetPoint("LEFT", 398, 0); r.eta:SetWidth(112)
    local x = -6
    local function Btn(label, w, fn)
      local b = UI.Button(r, label, w, 22, fn); b:SetPoint("RIGHT", x, 0); x = x - w - 4
      return b
    end
    r.del = Btn("Close", 50, function() ns.RemoveAccount(r.goalId) end)
    r.set = Btn("Target", 56, function() Ask("JPMF_SET_TARGET", r.goalId) end)
    r.rule = Btn("Auto %", 56, function() Ask("JPMF_RULE", r.goalId) end)
    r.out = Btn("Withdraw", 70, function() Ask("JPMF_WITHDRAW", r.goalId) end)
    r.inn = Btn("Deposit", 62, function() Ask("JPMF_DEPOSIT", r.goalId) end)
    r.down = Btn("Down", 44, function() ns.MoveAccount(r.goalId, 1) end)
    r.up = Btn("Up", 32, function() ns.MoveAccount(r.goalId, -1) end)
    rows[i] = r
  end
  local more = UI.Text(f, 10.5, C.muted); more:SetPoint("TOPLEFT", 0, -74 - 6 * 46 - 2)

  local presets = UI.Text(f, 11, C.muted); presets:SetPoint("BOTTOMLEFT", 0, 96); presets:SetText("OPEN AN ACCOUNT")
  for i, p in ipairs(ns.PRESETS) do
    local b = UI.Button(f, p.name, 176, 24, function()
      local g = ns.AddAccount(p)
      if not p.auto and not p.target then Ask("JPMF_SET_TARGET", g.id) end
      if p.note then ns.Say(p.name .. ": " .. p.note) end
    end)
    -- two rows of five
    local col, row = (i - 1) % 5, floor((i - 1) / 5)
    b:SetPoint("BOTTOMLEFT", col * 184, 66 - row * 30)
  end
  local cl = UI.Text(f, 11, C.muted); cl:SetPoint("BOTTOMLEFT", 0, 8); cl:SetText("CUSTOM")
  local nameBox = UI.EditBox(f, 260); nameBox:SetPoint("BOTTOMLEFT", 60, 2)
  local amtBox = UI.EditBox(f, 120); amtBox:SetPoint("LEFT", nameBox, "RIGHT", 8, 0)
  local hint = UI.Text(f, 10.5, C.muted); hint:SetPoint("LEFT", amtBox, "RIGHT", 140, 0)
  hint:SetWidth(320); hint:SetText("Target like 15g, or leave it empty for plain savings")
  local add = UI.Button(f, "Open account", 110, 24, function()
    local n, raw = nameBox:GetText(), amtBox:GetText()
    local v = raw:match("^%s*$") and 0 or ns.ParseMoney(raw)
    if n == "" or not v then ns.Say("Give the account a name, and a target like 15g or nothing."); return end
    ns.AddAccount(nil, n, v)
    nameBox:SetText(""); amtBox:SetText("")
  end)
  add:SetPoint("LEFT", amtBox, "RIGHT", 8, 0)

  function page:Refresh()
    local segs, held, free = UI.WorthSegments()
    sum.seg:Set(segs)
    sum.text:SetText(("Net worth %s   \194\183   In accounts %s   \194\183   %s   \194\183   Assets %s"):format(
      ns.Money(GetMoney(), true), ns.Money(held, true),
      free < 0 and ("|cfff08b80Overdrawn %s|r"):format(ns.Money(-free)) or ("Free %s"):format(ns.Money(free, true)),
      ns.Money((ns.Assets()), true)))
    local saved = ns.Balances()
    local pts = ns.Forecast(15)
    local list = ns.char.goals
    for i, r in ipairs(rows) do
      local g = list[i]
      r:SetShown(g ~= nil)
      if g then
        r.goalId = g.id
        local col = UI.AccountColor(i, g)
        r.swatch:SetColorTexture(col[1], col[2], col[3], 1)
        local t, s = ns.GoalTarget(g), saved[g.id] or 0
        r.rank:SetText(i)
        r.name:SetText(g.name)
        local note = {}
        if g.rule then note[#note + 1] = ("Auto %d%% of income"):format(g.rule) end
        if g.kind == "training" then
          local _, lvl = ns.NextTraining()
          note[#note + 1] = not lvl and "pays your training"
            or lvl <= UnitLevel("player") and "train now"
            or ("for level %d"):format(lvl)
        elseif g.level then note[#note + 1] = "spent at level " .. g.level end
        r.note:SetText(#note > 0 and table.concat(note, ", ") or "Savings")
        r.bar:Set(t > 0 and s / t or (s > 0 and 1 or 0), col)
        r.amt:SetText(t > 0 and (ns.Money(s) .. " of " .. ns.Money(t)) or ns.Money(s))
        local eta = (t > 0 and s < t) and ns.GoalArrival(g, pts)
        r.eta:SetText(t <= 0 and (g.kind == "training" and "Visit your trainer" or "") or s >= t and "|cff5fd08aFunded|r" or
          ns.CanFillNow(g) and "|cff5fd08aCan fill now|r" or eta and ("Full around Lv %.1f"):format(eta) or ns.NoArrivalReason(g))
        r.up:SetEnabled(i > 1); r.down:SetEnabled(i < #list)
        r.set:SetShown(g.kind ~= "training")
        r.out:SetEnabled(s > 0)
      end
    end
    more:SetText(#list > #rows and ("+%d more accounts not shown"):format(#list - #rows) or "")
  end
end)

---------------------------------------------------------------------------
-- History chart: gold by level reached, or by day
---------------------------------------------------------------------------
local function LevelOn(t)
  local lvl = 1
  for L, rec in pairs(ns.char.levelGold or {}) do
    if rec.t and rec.t <= t and L > lvl then lvl = L end
  end
  return lvl
end

function ns.DrawHistory(holder, lines, texts, hover, w, h, mode, range, card1, card2)
  lines:Reset(); texts:Reset()
  for _, b in ipairs(hover) do b:Hide() end
  local padL, padB, padT, padR = 44, 22, 14, 14
  local cw, ch = w - padL - padR, h - padB - padT
  local pts = {}
  if mode == "level" then
    for _, r in ipairs(ns.LevelHistory()) do pts[#pts + 1] = { x = r.level, gold = r.gold, rec = r } end
    pts[#pts + 1] = { x = UnitLevel("player") + 0.5, gold = GetMoney(), now = true }
  else
    for _, r in ipairs(ns.DailyHistory(range)) do pts[#pts + 1] = { x = r.t, gold = r.gold, rec = r } end
  end
  if #pts < 2 then
    local t = texts:Get(12, C.muted)
    t:SetPoint("CENTER", holder, "CENTER")
    t:SetText(mode == "level" and "Your gold at each level shows here once you have reached a level or two with the addon running."
      or "Your daily gold history builds up as you play.")
    card1.text:SetText(""); card2.text:SetText("")
    return
  end
  local x0, x1, ymax = pts[1].x, pts[#pts].x, 0
  for _, p in ipairs(pts) do ymax = max(ymax, p.gold) end
  ymax = max(ymax * 1.1, 10000)
  local function X(x) return padL + (x1 > x0 and (x - x0) / (x1 - x0) or 0) * cw end
  local function Y(v) return padB + max(v, 0) / ymax * ch end
  for i = 0, 4 do
    local v = ymax * i / 4
    lines:Line(padL, Y(v), padL + cw, Y(v), C.grid, 1)
    local t = texts:Get(10, C.muted, UI.NUM)
    t:SetPoint("RIGHT", holder, "BOTTOMLEFT", padL - 6, Y(v))
    t:SetText(floor(v / 10000) .. "g")
  end
  -- axis labels: every level, or about six dates
  if mode == "level" then
    for _, p in ipairs(pts) do
      if not p.now then
        local t = texts:Get(10, C.muted, UI.NUM)
        t:SetPoint("TOP", holder, "BOTTOMLEFT", X(p.x), padB - 4)
        t:SetText(tostring(p.x))
      end
    end
  else
    local every = max(1, floor(#pts / 6))
    for i = 1, #pts, every do
      local t = texts:Get(10, C.muted, UI.NUM)
      t:SetPoint("TOP", holder, "BOTTOMLEFT", X(pts[i].x), padB - 4)
      t:SetText(date("%b %d", pts[i].x))
    end
  end
  -- the line, then a hover spot on each point
  for i = 2, #pts do
    local a, b = pts[i - 1], pts[i]
    if b.now then
      UI.Dashed(lines, X(a.x), Y(a.gold), X(b.x), Y(b.gold), C.gold, 2, 5, 4)
    else
      lines:Line(X(a.x), Y(a.gold), X(b.x), Y(b.gold), C.gold, 2.5)
    end
  end
  for i, p in ipairs(pts) do
    local b = hover[i]
    if not b then
      b = CreateFrame("Frame", nil, holder)
      b:SetSize(14, 14)
      b.dot = b:CreateTexture(nil, "OVERLAY")
      b.dot:SetSize(6, 6); b.dot:SetPoint("CENTER")
      b:EnableMouse(true)
      b:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_TOP")
        for _, line in ipairs(self.tip or {}) do GameTooltip:AddLine(line[1], line[2], line[3], line[4], true) end
        GameTooltip:Show()
      end)
      b:SetScript("OnLeave", function() GameTooltip:Hide() end)
      hover[i] = b
    end
    local col = p.now and C.mint or C.gold
    b.dot:SetColorTexture(col[1], col[2], col[3], 1)
    b:ClearAllPoints()
    b:SetPoint("CENTER", holder, "BOTTOMLEFT", X(p.x), Y(p.gold))
    local tip = {}
    local function add(text, c) c = c or C.text; tip[#tip + 1] = { text, c[1], c[2], c[3] } end
    if p.now then
      add("Now: " .. ns.Money(p.gold, true), C.mint)
    elseif mode == "level" then
      local r = p.rec
      add(("Reached level %d%s"):format(r.level, r.t and (" on " .. date("%b %d", r.t)) or " (estimated)"), C.gold)
      add("Gold then: " .. ns.Money(r.gold, true))
      local lb = ns.char.levelBook[r.level - 1]
      if lb then
        local net = 0
        for cat, e in pairs(lb.cats or {}) do
          if not cat:find("training$") and cat ~= "Riding" and cat ~= "Talents" then net = net + e[1] + e[2] end
        end
        add(("Level %d brought in %s over %.1f hours"):format(r.level - 1, ns.Money(net), (lb.secs or 0) / 3600), C.muted)
      end
    else
      local r = p.rec
      add(date("%A, %b %d", r.t), C.gold)
      add("Gold at day's end: " .. ns.Money(r.gold, true))
      add(("Level %d"):format(LevelOn(r.t + 43200)), C.muted)
      if r.net ~= 0 then add(("Change that day: %s%s"):format(r.net > 0 and "+" or "", ns.Money(r.net)), r.net > 0 and C.mint or C.red) end
      local gain, spend = ns.DayExtremes(r.day)
      if gain then add(("Biggest gain: %s, %s"):format(gain[1], ns.Money(gain[2])), C.muted) end
      if spend then add(("Biggest spend: %s, %s"):format(spend[1], ns.Money(spend[2])), C.muted) end
    end
    b.tip = tip
    b:Show()
  end
  -- the cards: change over the range, and the standouts
  local first, last = pts[1], pts[#pts]
  local change = last.gold - first.gold
  if mode == "level" then
    local steps = max(1, #pts - 1)
    card1.text:SetText(("From level %d with %s to now with %s\n%s%s since then\nAbout %s per level on average"):format(
      first.x, ns.Money(first.gold), ns.Money(last.gold), change >= 0 and "+" or "", ns.Money(change), ns.Money(change / steps)))
    local best, worst
    for i = 2, #pts do
      if not pts[i].now then
        local d = pts[i].gold - pts[i - 1].gold
        if not best or d > best[2] then best = { pts[i - 1].x, d } end
        if not worst or d < worst[2] then worst = { pts[i - 1].x, d } end
      end
    end
    card2.text:SetText(best and ("Best level: %d, %s%s\nToughest level: %d, %s%s\nEstimated points are levels from before history was recorded."):format(
      best[1], best[2] >= 0 and "+" or "", ns.Money(best[2]), worst[1], worst[2] >= 0 and "+" or "", ns.Money(worst[2]))
      or "Reach another level to compare levels.")
  else
    local days = max(1, #pts - 1)
    card1.text:SetText(("%s: %s\nToday: %s\n%s%s over %d days, about %s a day"):format(
      date("%b %d", first.x), ns.Money(first.gold), ns.Money(last.gold), change >= 0 and "+" or "", ns.Money(change), days, ns.Money(change / days)))
    local best, worst
    for _, p in ipairs(pts) do
      if not best or p.rec.net > best.rec.net then best = p end
      if not worst or p.rec.net < worst.rec.net then worst = p end
    end
    card2.text:SetText(("Best day: %s, %s%s\nBiggest spending day: %s, %s"):format(
      date("%b %d", best.x), best.rec.net >= 0 and "+" or "", ns.Money(best.rec.net), date("%b %d", worst.x), ns.Money(worst.rec.net)))
  end
end

---------------------------------------------------------------------------
-- Forecast
---------------------------------------------------------------------------
ns.RegisterPage("Forecast", function(page, f)
  -- two views in one place: where your gold is going, and where it has been
  page.view = "forecast"
  local fcBtn, hiBtn
  fcBtn = UI.Button(f, "Forecast", 96, 22, function() page.view = "forecast"; page:Refresh() end)
  fcBtn:SetPoint("TOPLEFT", 0, 2)
  hiBtn = UI.Button(f, "History", 96, 22, function() page.view = "history"; page:Refresh() end)
  hiBtn:SetPoint("LEFT", fcBtn, "RIGHT", 4, 0)
  local sub = UI.Text(f, 11, C.muted); sub:SetPoint("LEFT", hiBtn, "RIGHT", 12, -1); sub:SetWidth(700)
  local box = Card(f, 918, 330); box:SetPoint("TOPLEFT", 0, -26)
  local chart = CreateFrame("Frame", nil, box); chart:SetPoint("TOPLEFT", 6, -6); chart:SetSize(906, 318)
  local lines, texts = UI.LinePool(chart), TextPool(chart)

  local a = Card(f, 450, 140, "Assumptions"); a:SetPoint("TOPLEFT", box, "BOTTOMLEFT", 0, -10)
  -- pace: by level (your own rising curve) or by hour
  local byLevel, byHour
  byLevel = UI.Button(a, "By level", 76, 20, function() ns.acct.settings.pace = "level"; ns.Fire("JPMF_GOALS_CHANGED"); page:Refresh() end)
  byLevel:SetPoint("TOPRIGHT", -88, -6)
  byHour = UI.Button(a, "By hour", 76, 20, function() ns.acct.settings.pace = "hour"; ns.Fire("JPMF_GOALS_CHANGED"); page:Refresh() end)
  byHour:SetPoint("TOPRIGHT", -8, -6)
  a.rate = UI.Text(a, 12, C.text); a.rate:SetPoint("TOPLEFT", 12, -30); a.rate:SetWidth(426)
  local rateBox = UI.EditBox(a, 90); rateBox:SetPoint("TOPLEFT", 12, -52)
  UI.Button(a, "Override", 76, 24, function()
    ns.acct.settings.rateOverride = ns.ParseMoney(rateBox:GetText()); rateBox:SetText(""); page:Refresh()
  end):SetPoint("LEFT", rateBox, "RIGHT", 6, 0)
  UI.Button(a, "Auto", 56, 24, function() ns.acct.settings.rateOverride = nil; page:Refresh() end)
    :SetPoint("LEFT", rateBox, "RIGHT", 88, 0)
  a.hpl = UI.Text(a, 12, C.text); a.hpl:SetPoint("TOPLEFT", 12, -86)
  local hplBox = UI.EditBox(a, 90); hplBox:SetPoint("TOPLEFT", 12, -106)
  UI.Button(a, "Override", 76, 24, function()
    ns.acct.settings.hplOverride = tonumber(hplBox:GetText()); hplBox:SetText(""); page:Refresh()
  end):SetPoint("LEFT", hplBox, "RIGHT", 6, 0)
  UI.Button(a, "Auto", 56, 24, function() ns.acct.settings.hplOverride = nil; page:Refresh() end)
    :SetPoint("LEFT", hplBox, "RIGHT", 88, 0)

  local d = Card(f, 458, 140, "Planned costs by level"); d:SetPoint("TOPLEFT", a, "TOPRIGHT", 10, 0)
  d.pool = TextPool(d)

  -- history view: its own chart and cards in the same places
  local hbox = Card(f, 918, 330); hbox:SetPoint("TOPLEFT", 0, -26)
  local hchart = CreateFrame("Frame", nil, hbox); hchart:SetPoint("TOPLEFT", 6, -6); hchart:SetSize(906, 318)
  local hlines, htexts = UI.LinePool(hchart), TextPool(hchart)
  page.hmode, page.hrange = "level", 30
  local hm = {}
  local function HBtn(label, w, fn) local b = UI.Button(hbox, label, w, 20, fn); return b end
  hm.level = HBtn("By level", 72, function() page.hmode = "level"; page:Refresh() end)
  hm.level:SetPoint("TOPRIGHT", hbox, "TOPRIGHT", -330, -8)
  hm.date = HBtn("By date", 72, function() page.hmode = "date"; page:Refresh() end)
  hm.date:SetPoint("LEFT", hm.level, "RIGHT", 4, 0)
  local ranges = { { "7d", 7 }, { "30d", 30 }, { "90d", 90 }, { "All", false } }
  hm.ranges = {}
  for i, r in ipairs(ranges) do
    local b = HBtn(r[1], 40, function() page.hrange = r[2]; page:Refresh() end)
    b:SetPoint("LEFT", i == 1 and hm.date or hm.ranges[i - 1], "RIGHT", i == 1 and 16 or 4, 0)
    b.range = r[2]
    hm.ranges[i] = b
  end
  local h1 = Card(f, 450, 140, "Over this range"); h1:SetPoint("TOPLEFT", hbox, "BOTTOMLEFT", 0, -10)
  h1.text = UI.Text(h1, 12, C.text, UI.NUM); h1.text:SetPoint("TOPLEFT", 12, -30); h1.text:SetWidth(426); h1.text:SetJustifyV("TOP")
  local h2 = Card(f, 458, 140, "Notable"); h2:SetPoint("TOPLEFT", h1, "TOPRIGHT", 10, 0)
  h2.text = UI.Text(h2, 12, C.text, UI.NUM); h2.text:SetPoint("TOPLEFT", 12, -30); h2.text:SetWidth(434); h2.text:SetJustifyV("TOP")
  local hover = {}

  function page:Refresh()
    local hist = page.view == "history"
    fcBtn:SetSelected(not hist); hiBtn:SetSelected(hist)
    box:SetShown(not hist); a:SetShown(not hist); d:SetShown(not hist)
    hbox:SetShown(hist); h1:SetShown(hist); h2:SetShown(hist)
    if hist then
      sub:SetText("Where your gold has been. Hover a point for the details.")
      hm.level:SetSelected(page.hmode == "level"); hm.date:SetSelected(page.hmode == "date")
      for _, b in ipairs(hm.ranges) do
        b:SetShown(page.hmode == "date"); b:SetSelected(b.range == page.hrange)
      end
      ns.DrawHistory(hchart, hlines, htexts, hover, 906, 318, page.hmode, page.hrange or nil, h1, h2)
      return
    end
    sub:SetText("Projected gold by level. Training and account purchases (like your mount) step the line down at their level.")
    local pts, gph, hpl = DrawForecast(chart, lines, texts, 906, 318, 12, false)
    local g, go = ns.GoldPerHour()
    local h, ho = ns.HoursPerLevel()
    local fNet, _, info = ns.PerLevelPace()
    local levelMode = ns.acct.settings.pace ~= "hour"
    byLevel:SetSelected(levelMode); byHour:SetSelected(not levelMode)
    if levelMode and fNet and not go then
      local cur = UnitLevel("player")
      a.rate:SetText(("By level: about %s at %d, rising to %s at %d (from your last %d levels). Hourly figures below are for reference."):format(
        ns.Money(fNet(cur)), cur, ns.Money(fNet(min(cur + 6, 60))), min(cur + 6, 60), info.levels))
    elseif levelMode and not go then
      a.rate:SetText(("By level needs two finished levels; until then, by hour: %s."):format(g and ns.Money(g) or "not enough data"))
    else
      a.rate:SetText(("Gold per hour: %s%s"):format(g and ns.Money(g) or "not enough data", go and " (your override, so pacing by hour)" or ""))
    end
    a.hpl:SetText(("Hours per level: %.1f%s"):format(h, ho and " (your override)" or ""))
    d.pool:Reset()
    local y = -28
    for _, p in ipairs(pts or {}) do
      if p.debit > 0 and y > -130 then
        local l = d.pool:Get(11.5, C.text); l:SetPoint("TOPLEFT", 12, y)
        l:SetText(("Level %d%s"):format(p.level, p.spend and " (includes an account purchase)" or ""))
        local v = d.pool:Get(11.5, C.red, UI.NUM); v:SetPoint("TOPRIGHT", -12, y); v:SetText("-" .. ns.Money(p.debit))
        y = y - 18
      end
    end
    if y == -28 then
      local l = d.pool:Get(11, C.muted); l:SetPoint("TOPLEFT", 12, y); l:SetWidth(430)
      l:SetText("No planned costs yet. Visit your class trainer, or open an account with a level such as Riding at 40.")
    end
  end
end)

---------------------------------------------------------------------------
-- Ledger
---------------------------------------------------------------------------
ns.RegisterPage("Ledger", function(page, f)
  local head = UI.Heading(f, "Ledger"); head:SetPoint("TOPLEFT", 0, 0)
  local periods = { { "Session", -1 }, { "Today", 0 }, { "7 days", 7 }, { "30 days", 30 }, { "All time", nil } }
  page.period = 7
  local btns = {}
  for i, p in ipairs(periods) do
    local b = UI.Button(f, p[1], 80, 24, function() page.period = p[2]; page.label = p[1]; page:Refresh() end)
    b:SetPoint("TOPLEFT", 120 + (i - 1) * 86, 2)
    btns[i] = { b = b, v = p[2], label = p[1] }
  end
  page.label = "7 days"
  page.view = "category"
  local viewBtn
  viewBtn = UI.Button(f, "By zone", 90, 24, function()
    page.view = page.view == "zone" and "category" or "zone"
    page:Refresh()
  end)
  viewBtn:SetPoint("TOPLEFT", 120 + #periods * 86 + 20, 2)
  local levelBtn = UI.Button(f, "By level", 90, 24, function()
    page.view = page.view == "level" and "category" or "level"
    page:Refresh()
  end)
  levelBtn:SetPoint("LEFT", viewBtn, "RIGHT", 4, 0)
  local exportBtn = UI.Button(f, "Export CSV", 96, 24, function() ns.ShowCopy("Ledger export (CSV)", ns.ExportCSV()) end)
  exportBtn:SetPoint("LEFT", levelBtn, "RIGHT", 4, 0)
  local cats = Card(f, 450, 440, "By category"); cats:SetPoint("TOPLEFT", 0, -34)
  cats.rows = {}
  for i = 1, 16 do
    local r = {}
    r.name = UI.Text(cats, 11.5, C.text); r.name:SetPoint("TOPLEFT", 12, -14 - i * 22); r.name:SetWidth(140)
    r.bar = UI.Bar(cats, 180, 8); r.bar:SetPoint("TOPLEFT", cats, "TOPLEFT", 156, -18 - i * 22)
    r.amt = UI.Text(cats, 11.5, C.text, UI.NUM); r.amt:SetPoint("TOPRIGHT", -12, -14 - i * 22); r.amt:SetJustifyH("RIGHT")
    cats.rows[i] = r
  end
  cats.total = UI.Text(cats, 12, C.gold, UI.NUM); cats.total:SetPoint("BOTTOMLEFT", 12, 10)
  local recent = Card(f, 458, 440, "Recent transactions"); recent:SetPoint("TOPLEFT", cats, "TOPRIGHT", 10, 0)
  recent.pool = TextPool(recent)

  function page:Refresh()
    for _, b in ipairs(btns) do b.b:SetSelected(b.label == page.label) end
    local byCat, inc, out
    if page.period == -1 then
      byCat, inc, out = {}, 0, 0
      for cat, v in pairs(ns.session.byCat) do
        byCat[cat] = { max(v, 0), min(v, 0) }
        if v >= 0 then inc = inc + v else out = out + v end
      end
    elseif page.period == nil then
      byCat, inc, out = ns.SumAll()
    else
      byCat, inc, out = ns.Sum(page.period)
    end
    local rows, biggest = {}, 1
    viewBtn:SetSelected(page.view == "zone")
    levelBtn:SetSelected(page.view == "level")
    if page.view == "level" then
      cats.title:SetText("BY LEVEL (AFTER RUNNING COSTS)")
      local lr, cur = ns.LevelRows(), UnitLevel("player")
      for i = #lr, 1, -1 do
        local r = lr[i]
        rows[#rows + 1] = { cat = ("Level %d%s"):format(r.level, r.level == cur and " (now)" or ""), v = r.net,
          note = (" \194\183 %.1fh"):format(r.secs / 3600) }
        biggest = max(biggest, abs(r.net))
      end
    elseif page.view == "zone" then
      cats.title:SetText("BY ZONE")
      local days = page.period == nil and 400 or page.period == -1 and 0 or page.period
      for _, z in ipairs(ns.ZoneReport(days)) do
        if z.p ~= 0 or z.n ~= 0 then rows[#rows + 1] = { cat = z.zone, v = z.net,
          note = z.perHour and (" \194\183 " .. ns.Money(z.perHour) .. "/h") or "" } end
        biggest = max(biggest, abs(z.net))
      end
    else
      cats.title:SetText("BY CATEGORY")
      for cat, e in pairs(byCat) do rows[#rows + 1] = { cat = cat, v = e[1] + e[2] }; biggest = max(biggest, abs(e[1] + e[2])) end
      table.sort(rows, function(a, b) return abs(a.v) > abs(b.v) end)
    end
    for i, r in ipairs(cats.rows) do
      local e = rows[i]
      r.name:SetShown(e ~= nil); r.amt:SetShown(e ~= nil); r.bar:SetShown(e ~= nil)
      if e then
        local col = e.v >= 0 and C.green or C.red
        r.name:SetText(e.cat); r.amt:SetText((e.v >= 0 and "+" or "") .. ns.Money(e.v) .. (e.note or ""))
        r.amt:SetTextColor(col[1], col[2], col[3]); r.bar:Set(abs(e.v) / biggest, col)
      end
    end
    cats.total:SetText(("Earned %s   Spent %s   Net %s"):format(ns.Money(inc), ns.Money(-out), ns.Money(inc + out)))

    recent.pool:Reset()
    local raw, y = ns.char.raw, -30
    for i = #raw, max(1, #raw - 18), -1 do
      local e = raw[i]
      local t = recent.pool:Get(11, C.muted, UI.NUM); t:SetPoint("TOPLEFT", 12, y); t:SetText(date("%m-%d %H:%M", e.t))
      local cname = recent.pool:Get(11.5, C.text); cname:SetPoint("TOPLEFT", 100, y); cname:SetText(e.c)
      local z = recent.pool:Get(10.5, C.muted); z:SetPoint("TOPLEFT", 236, y); z:SetText(e.z or ""); z:SetWidth(120)
      local col = e.a >= 0 and C.green or C.red
      local a = recent.pool:Get(11.5, col, UI.NUM); a:SetPoint("TOPRIGHT", -12, y); a:SetText((e.a >= 0 and "+" or "") .. ns.Money(e.a))
      y = y - 21
    end
    if #raw == 0 then
      local t = recent.pool:Get(11, C.muted); t:SetPoint("TOPLEFT", 12, y); t:SetText("Nothing recorded yet.")
    end
  end
end)

---------------------------------------------------------------------------
-- Wishlist (the Gadgetzan Sachs desk)
---------------------------------------------------------------------------
ns.RegisterPage("Wishlist", function(page, f)
  local head = UI.Heading(f, "Wishlist"); head:SetPoint("TOPLEFT", 0, 0)
  local sub = UI.Text(f, 11, C.muted); sub:SetPoint("LEFT", head, "RIGHT", 12, -1)
  sub:SetText("Gadgetzan Sachs records prices whenever you open a vendor or browse the auction house.")
  local linkBox = UI.EditBox(f, 300); linkBox:SetPoint("TOPLEFT", 0, -30)
  local linkHint = UI.Text(f, 10.5, C.muted); linkHint:SetPoint("TOPLEFT", linkBox, "BOTTOMLEFT", 2, -2)
  linkHint:SetText("Click here, then shift-click an item")
  local tBox = UI.EditBox(f, 100); tBox:SetPoint("LEFT", linkBox, "RIGHT", 8, 0)
  local tHint = UI.Text(f, 10.5, C.muted); tHint:SetPoint("TOPLEFT", tBox, "BOTTOMLEFT", 2, -2); tHint:SetText("Target price")
  local sBox = UI.EditBox(f, 200); sBox:SetPoint("LEFT", tBox, "RIGHT", 8, 0)
  local sHint = UI.Text(f, 10.5, C.muted); sHint:SetPoint("TOPLEFT", sBox, "BOTTOMLEFT", 2, -2); sHint:SetText("Source note (optional)")
  UI.Button(f, "Add to wishlist", 130, 24, function()
    local w = ns.Watch(linkBox:GetText(), ns.ParseMoney(tBox:GetText()), sBox:GetText())
    if not w then ns.Say("Shift-click an item into the first box."); return end
    linkBox:SetText(""); tBox:SetText(""); sBox:SetText("")
  end):SetPoint("LEFT", sBox, "RIGHT", 8, 0)

  local function Insert(link)
    if linkBox:HasFocus() then linkBox:SetText(link); return true end
  end
  if ChatEdit_InsertLink then hooksecurefunc("ChatEdit_InsertLink", function(link) ns.Safe(Insert, link) end) end
  if ChatFrameUtil and ChatFrameUtil.InsertLink then
    hooksecurefunc(ChatFrameUtil, "InsertLink", function(link) ns.Safe(Insert, link) end)
  end

  local rows = {}
  for i = 1, 8 do
    local r = UI.Box(f, C.panel, C.line)
    r:SetSize(918, 46); r:SetPoint("TOPLEFT", 0, -78 - (i - 1) * 50)
    r.icon = r:CreateTexture(nil, "ARTWORK"); r.icon:SetSize(30, 30); r.icon:SetPoint("LEFT", 10, 0)
    r.name = UI.Text(r, 12.5, C.text); r.name:SetPoint("TOPLEFT", 50, -8); r.name:SetWidth(260)
    r.src = UI.Text(r, 10.5, C.muted); r.src:SetPoint("TOPLEFT", 50, -26); r.src:SetWidth(260)
    r.price = UI.Text(r, 13, C.text, UI.NUM); r.price:SetPoint("TOPLEFT", 330, -8)
    r.seen = UI.Text(r, 10.5, C.muted); r.seen:SetPoint("TOPLEFT", 330, -26)
    r.spark = CreateFrame("Frame", nil, r); r.spark:SetSize(200, 30); r.spark:SetPoint("LEFT", 520, 0)
    r.lines = UI.LinePool(r.spark)
    r.badge = UI.Text(r, 11.5, C.green); r.badge:SetPoint("LEFT", 740, 0)
    r.del = UI.Button(r, "Remove", 64, 24, function() ns.Unwatch(r.itemId) end); r.del:SetPoint("RIGHT", -8, 0)
    rows[i] = r
  end
  local empty = UI.Text(f, 12, C.muted); empty:SetPoint("TOPLEFT", 0, -90)
  empty:SetText("Nothing on your wishlist yet. Add an item above, or type /jpm watch and shift-click one.")

  function page:Refresh()
    local list = {}
    for id, w in pairs(ns.acct.wishlist) do list[#list + 1] = { id = id, w = w } end
    table.sort(list, function(a, b) return (a.w.added or 0) < (b.w.added or 0) end)
    empty:SetShown(#list == 0)
    local iconFn = (C_Item and C_Item.GetItemIconByID) or GetItemIcon
    for i, r in ipairs(rows) do
      local e = list[i]
      r:SetShown(e ~= nil)
      if e then
        local w = e.w
        r.itemId = e.id
        r.icon:SetTexture(iconFn and iconFn(e.id) or "Interface\\Icons\\INV_Misc_QuestionMark")
        r.name:SetText(w.link or w.name)
        r.src:SetText((w.source and (w.source .. " \194\183 ") or "") .. (w.target and ("target " .. ns.Money(w.target)) or "no target"))
        r.price:SetText(w.last and ns.Money(w.last, true) or "--")
        r.seen:SetText(w.last and ((w.lastSrc == "AH" and "AH, " or "vendor, ") .. ns.Ago(w.lastAt)) or "not seen yet")
        local below = w.last and w.target and w.last <= w.target
        r.badge:SetText(below and "Buy signal" or "")
        r.lines:Reset()
        local pts = w.points or {}
        if #pts >= 2 then
          local lo, hi = math.huge, 0
          for _, p in ipairs(pts) do lo = min(lo, p.p); hi = max(hi, p.p) end
          if w.target then lo = min(lo, w.target); hi = max(hi, w.target) end
          if hi == lo then hi = lo + 1 end
          local function Y(v) return 3 + (v - lo) / (hi - lo) * 24 end
          if w.target then UI.Dashed(r.lines, 0, Y(w.target), 200, Y(w.target), C.goldDim, 1, 4, 4) end
          for j = 2, #pts do
            r.lines:Line((j - 2) / (#pts - 1) * 200, Y(pts[j - 1].p), (j - 1) / (#pts - 1) * 200, Y(pts[j].p),
              below and C.green or C.red, 1.5)
          end
        end
      end
    end
  end
end)

---------------------------------------------------------------------------
-- Statement
---------------------------------------------------------------------------
local function StatementText()
  local st = ns.Statement(7)
  local out = {}
  local function add(s) out[#out + 1] = s end
  add(("Weekly statement  |  %s to %s  |  %s"):format(date("%b %d", time() - 6 * 86400), date("%b %d"), ns.CharKey()))
  add("")
  add("INCOME")
  for _, e in ipairs(st.cats) do if e.p > 0 then add(("  %-22s %s"):format(e.cat, ns.Money(e.p))) end end
  add("SPENDING")
  for _, e in ipairs(st.leaks) do add(("  %-22s %s"):format(e.cat, ns.Money(-e.n))) end
  for _, e in ipairs(st.cats) do
    if e.n < 0 and e.cat:find("training$") then add(("  %-22s %s"):format(e.cat, ns.Money(-e.n))) end
  end
  add("")
  add(("Net for the week: %s over %.1f hours played"):format(ns.Money(st.net), st.played / 3600))
  if st.adjustments ~= 0 then
    add(("Adjustments: %s (gold that changed while the addon was not running)"):format(ns.Money(st.adjustments)))
  end
  if st.transfers ~= 0 then
    add(("Transfers with your other characters: %s"):format(ns.Money(st.transfers)))
  end
  local zones = ns.ZoneReport(st.days)
  if #zones > 0 then
    add("")
    add("WHERE YOU EARNED")
    local shown = 0
    for _, z in ipairs(zones) do
      if shown >= 5 then break end
      if z.p ~= 0 or z.n ~= 0 then shown = shown + 1
      add(("  %-22s %s%s"):format(z.zone, ns.Money(z.net),
        z.perHour and ("  (%s per hour over %.1f hours)"):format(ns.Money(z.perHour), z.secs / 3600) or ""))
      end
    end
  end
  local saved, held, free = ns.Balances()
  add("")
  add("ACCOUNTS")
  for _, g in ipairs(ns.char.goals) do
    local t = ns.GoalTarget(g)
    add(("  %-22s %s%s%s"):format(g.name, ns.Money(saved[g.id] or 0), t > 0 and (" of " .. ns.Money(t)) or "",
      g.rule and ("  (auto %d%%)"):format(g.rule) or ""))
  end
  if #ns.char.goals == 0 then add("  none yet") end
  add(("  %-22s %s"):format(free < 0 and "Overdrawn" or "Free to spend", ns.Money(free)))
  local auto = ns.AutoDeposits(st.days)
  if auto > 0 then add(("  Auto-deposited this week: %s"):format(ns.Money(auto))) end
  add("  " .. ns.AssetsLine() .. " (not counted in net worth)")
  local lr, shownL = ns.LevelRows(), 0
  if #lr > 0 then
    add("")
    add("BY LEVEL (earned / running costs / net / hours)")
    for i = #lr, 1, -1 do
      if shownL >= 5 then break end
      local r = lr[i]
      add(("  Level %-3d %s  /  %s  /  %s  /  %.1fh%s"):format(r.level, ns.Money(r.income), ns.Money(r.costs),
        ns.Money(r.net), r.secs / 3600, r.level == UnitLevel("player") and "  (in progress)" or ""))
      shownL = shownL + 1
    end
  end
  add("")
  add("FROM YOUR ADVISOR")
  for _, l in ipairs(ns.MorgrimLines()) do add("  " .. l) end
  add("")
  add("Morgrim Stanley, Senior Advisor, JP Mograine Financial")
  return table.concat(out, "\n")
end
ns.StatementText = StatementText

ns.RegisterPage("Statement", function(page, f)
  local head = UI.Heading(f, "Statement"); head:SetPoint("TOPLEFT", 0, 0)
  local paper = UI.Box(f, { 0.110, 0.094, 0.067 }, C.trim); paper:SetPoint("TOPLEFT", 0, -28); paper:SetSize(918, 420)
  -- the statement scrolls inside the paper (mouse wheel, or the bar when the game provides one)
  local ok, scroll = pcall(CreateFrame, "ScrollFrame", nil, paper, "UIPanelScrollFrameTemplate")
  if not ok or not scroll then scroll = CreateFrame("ScrollFrame", nil, paper) end
  scroll:SetPoint("TOPLEFT", 18, -14); scroll:SetPoint("BOTTOMRIGHT", -34, 12)
  local body = CreateFrame("Frame", nil, scroll); body:SetSize(860, 400)
  scroll:SetScrollChild(body)
  scroll:EnableMouseWheel(true)
  scroll:SetScript("OnMouseWheel", function(self, delta)
    local maxV = math.max(0, body:GetHeight() - self:GetHeight())
    self:SetVerticalScroll(math.max(0, math.min(maxV, self:GetVerticalScroll() - delta * 40)))
  end)
  local text = UI.Text(body, 12, { 0.902, 0.863, 0.761 }, UI.NUM)
  text:SetPoint("TOPLEFT", 0, 0); text:SetWidth(860); text:SetJustifyV("TOP")
  UI.Button(f, "Planning session", 150, 26, function() ns.OpenPlanning(true) end):SetPoint("TOPLEFT", paper, "BOTTOMLEFT", 0, -10)
  UI.Button(f, "Copy statement", 140, 26, function() ns.ShowCopy("Weekly statement", StatementText()) end)
    :SetPoint("TOPLEFT", paper, "BOTTOMLEFT", 160, -10)
  function page:Refresh()
    text:SetText(StatementText())
    body:SetHeight((text:GetStringHeight() or 400) + 20)
  end
end)

---------------------------------------------------------------------------
-- Settings and data
---------------------------------------------------------------------------
ns.RegisterPage("Settings", function(page, f)
  local s = function() return ns.acct.settings end
  local head = UI.Heading(f, "Settings"); head:SetPoint("TOPLEFT", 0, 0)
  local checks = {
    { "Weekly planning session on login", function() return s().autoPlan end, function(v) s().autoPlan = v end },
    { "Minimap button", function() return not s().minimap.hide end, function(v) s().minimap.hide = not v; ns.UpdateMinimap() end },
    { "Include profession training in the forecast", function() return s().includeProfTraining end,
      function(v) s().includeProfTraining = v; ns.Fire("JPMF_GOALS_CHANGED") end },
    { "Include pet trainer skills in the forecast", function() return s().includePetTraining ~= false end,
      function(v) s().includePetTraining = v; ns.Fire("JPMF_GOALS_CHANGED") end },
    { "When overdrawn, cover it from my lowest-priority accounts", function() return s().overdraft == "pull" end,
      function(v) s().overdraft = v and "pull" or "hold"; ns.Fire("JPMF_GOALS_CHANGED") end },
    { "Debug log (for bug reports)", function() return s().debug end, function(v) s().debug = v end },
  }
  -- two columns of three, so the cards below have room
  for i, c in ipairs(checks) do
    local col, row = floor((i - 1) / 3), (i - 1) % 3
    UI.Check(f, c[1], c[2], c[3]):SetPoint("TOPLEFT", col * 460, -30 - row * 30)
  end

  local data = Card(f, 450, 300, "Your data"); data:SetPoint("TOPLEFT", 0, -150)
  data.size = UI.Text(data, 12, C.text); data.size:SetPoint("TOPLEFT", 12, -30); data.size:SetWidth(426)
  local keep = UI.Text(data, 11.5, C.muted); keep:SetPoint("TOPLEFT", 12, -78); keep:SetText("Keep every transaction for:")
  local keepBtns = {}
  for i, d in ipairs({ 7, 14, 30, 60, 90 }) do
    local b = UI.Button(data, d .. " days", 76, 24, function() s().rawDays = d; ns.Prune(); page:Refresh() end)
    b:SetPoint("TOPLEFT", 12 + (i - 1) * 82, -98)
    keepBtns[d] = b
  end
  local keepNote = UI.Text(data, 10.5, C.muted); keepNote:SetPoint("TOPLEFT", 12, -128); keepNote:SetWidth(426)
  keepNote:SetText("Older transactions fold into daily totals (kept a year) and monthly totals (kept forever).")

  Popup("JPMF_DELETE_OLDER", "Delete this character's records older than %s days? This cannot be undone.",
    function(days) ns.DeleteOlderThan(days); page:Refresh() end)
  Popup("JPMF_RESET_CHAR", "Erase all of this character's financial history? Accounts and the wishlist are kept.",
    function() ns.ResetCharacter(); page:Refresh() end)
  local delBox = UI.EditBox(data, 60); delBox:SetPoint("TOPLEFT", 12, -170); delBox:SetText("90")
  UI.Button(data, "Delete records older than these days", 250, 24, function()
    local d = tonumber(delBox:GetText())
    if not d or d < 1 then return end
    local dlg = StaticPopup_Show("JPMF_DELETE_OLDER", d)
    if dlg then dlg.data = d end
  end):SetPoint("LEFT", delBox, "RIGHT", 8, 0)
  UI.Button(data, "Reset this character's history", 250, 24, function() StaticPopup_Show("JPMF_RESET_CHAR") end)
    :SetPoint("TOPLEFT", 12, -204)
  UI.Button(data, "Diagnostic report", 130, 24, function() ns.ShowCopy("Diagnostic report", ns.Report()) end)
    :SetPoint("TOPLEFT", 12, -246)
  UI.Button(data, "Debug log", 100, 24, function() SlashCmdList.JPMOGRAINE("log") end)
    :SetPoint("TOPLEFT", 150, -246)

  local house = Card(f, 458, 300, "Household (your characters)"); house:SetPoint("TOPLEFT", data, "TOPRIGHT", 10, 0)
  house.pool = TextPool(house)
  house.btns = {}

  local about = UI.Text(f, 10.5, C.muted); about:SetPoint("TOPLEFT", data, "BOTTOMLEFT", 0, -10); about:SetWidth(918)
  about:SetText("JP Mograine Financial\226\132\162 " .. ns.VERSION .. " is a product of Infihedron. \194\169 2026 Infihedron. Free software under the GNU GPL v3. " ..
    "JP Mograine Financial, Morgrim Stanley and Gadgetzan Sachs are parody names, not affiliated with any real financial institution. " ..
    "Not affiliated with or endorsed by Blizzard Entertainment. Morgrim Stanley is not a licensed financial advisor, in Azeroth or anywhere else.\n" ..
    "Commands: /jpm  \194\183  /jpm plan  \194\183  /jpm watch <item> [target]  \194\183  /jpm report  \194\183  /jpm debug  \194\183  /jpm log")

  function page:Refresh()
    local bytes, n = ns.StorageEstimate()
    data.size:SetText(("About %d KB saved for this character: %d transactions, %d days, %d months, %d price points.")
      :format(math.ceil(bytes / 1024), n.raw, n.days, n.months, n.prices))
    for d, b in pairs(keepBtns) do b:SetSelected(s().rawDays == d) end
    house.pool:Reset()
    for _, b in ipairs(house.btns) do b:Hide() end
    local list, total = {}, 0
    for key, h in pairs(ns.acct.household) do list[#list + 1] = { key = key, h = h }; total = total + (h.gold or 0) end
    table.sort(list, function(a, b) return (a.h.gold or 0) > (b.h.gold or 0) end)
    local y = -30
    for i, e in ipairs(list) do
      if i > 9 then break end
      local nm = house.pool:Get(11.5, C.text); nm:SetPoint("TOPLEFT", 12, y)
      nm:SetText(("%s (%d)"):format(e.h.name or e.key, e.h.level or 0))
      local g = house.pool:Get(11.5, C.text, UI.NUM); g:SetPoint("TOPLEFT", 190, y); g:SetText(ns.Money(e.h.gold or 0, true))
      local seen = house.pool:Get(10.5, C.muted); seen:SetPoint("TOPLEFT", 300, y); seen:SetText(ns.Ago(e.h.seen))
      if e.key ~= ns.CharKey() then
        local b = house.btns[i]
        if not b then b = UI.Button(house, "Forget", 60, 20); house.btns[i] = b end
        b:SetScript("OnClick", function() ns.acct.household[e.key] = nil; page:Refresh() end)
        b:ClearAllPoints(); b:SetPoint("TOPRIGHT", -10, y + 3); b:Show()
      end
      y = y - 24
    end
    local t = house.pool:Get(12, C.gold, UI.NUM); t:SetPoint("BOTTOMLEFT", 12, 12)
    t:SetText("Household total: " .. ns.Money(total, true))
  end
end)
