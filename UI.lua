--[[ JP Mograine Financial - Copyright (C) 2026 Infihedron. Licensed under the GNU GPL v3 or later; see LICENSE.
     UI: the theme (a goblin trading terminal in a dwarven ledger), widgets, the main
     window and its tabs, the minimap button and the copy window. ]]

local _, ns = ...
local UI = {}
ns.UI = UI

UI.C = {
  ground = { 0.051, 0.071, 0.078 }, panel = { 0.071, 0.102, 0.114 }, line = { 0.141, 0.204, 0.227 },
  grid = { 0.086, 0.125, 0.141 }, frame = { 0.071, 0.063, 0.047 }, title = { 0.165, 0.129, 0.078 },
  trim = { 0.541, 0.416, 0.165 }, gold = { 0.914, 0.784, 0.416 }, goldDim = { 0.831, 0.651, 0.251 },
  green = { 0.373, 0.816, 0.541 }, red = { 0.941, 0.545, 0.502 }, mint = { 0.498, 0.839, 0.698 },
  text = { 0.925, 0.898, 0.824 }, muted = { 0.624, 0.690, 0.678 },
}
local C = UI.C
UI.FONT = STANDARD_TEXT_FONT or "Fonts\\FRIZQT__.TTF"
UI.NUM = "Fonts\\ARIALN.TTF"
local BACKDROP_T = BackdropTemplateMixin and "BackdropTemplate" or nil
local WHITE = "Interface\\Buttons\\WHITE8x8"

function UI.Box(parent, bg, edge, a)
  local f = CreateFrame("Frame", nil, parent, BACKDROP_T)
  f:SetBackdrop({ bgFile = WHITE, edgeFile = WHITE, edgeSize = 1 })
  bg = bg or C.panel
  edge = edge or C.line
  f:SetBackdropColor(bg[1], bg[2], bg[3], a or 1)
  f:SetBackdropBorderColor(edge[1], edge[2], edge[3], 1)
  return f
end

function UI.Text(parent, size, color, font, flags)
  local fs = parent:CreateFontString(nil, "OVERLAY")
  fs:SetFont(font or UI.FONT, size or 12, flags or "")
  color = color or C.text
  fs:SetTextColor(color[1], color[2], color[3])
  fs:SetJustifyH("LEFT")
  fs:SetShadowOffset(1, -1)
  fs:SetShadowColor(0, 0, 0, 0.8)
  return fs
end

function UI.Heading(parent, text, size)
  local fs = UI.Text(parent, size or 15, C.gold, UI.FONT, "")
  fs:SetText(text)
  return fs
end

function UI.Button(parent, label, w, h, onClick)
  local b = CreateFrame("Button", nil, parent, BACKDROP_T)
  b:SetSize(w or 100, h or 24)
  b:SetBackdrop({ bgFile = WHITE, edgeFile = WHITE, edgeSize = 1 })
  b:SetBackdropColor(C.title[1], C.title[2], C.title[3], 1)
  b:SetBackdropBorderColor(C.trim[1], C.trim[2], C.trim[3], 1)
  b.label = UI.Text(b, 12, C.gold)
  b.label:SetPoint("CENTER")
  b.label:SetJustifyH("CENTER")
  b.label:SetText(label)
  b:SetScript("OnEnter", function(self) self:SetBackdropBorderColor(C.gold[1], C.gold[2], C.gold[3], 1) end)
  b:SetScript("OnLeave", function(self)
    if not self.selected then self:SetBackdropBorderColor(C.trim[1], C.trim[2], C.trim[3], 1) end
  end)
  if onClick then b:SetScript("OnClick", function(self, ...) ns.Safe(onClick, self, ...) end) end
  function b:SetSelected(on)
    self.selected = on
    if on then
      -- solid gold tab with dark lettering: the one you are on reads at a glance
      self:SetBackdropColor(C.gold[1], C.gold[2], C.gold[3], 1)
      self:SetBackdropBorderColor(1, 0.92, 0.65, 1)
      self.label:SetTextColor(0.10, 0.08, 0.05)
      self.label:SetShadowColor(0, 0, 0, 0)
    else
      self:SetBackdropColor(C.title[1], C.title[2], C.title[3], 1)
      self:SetBackdropBorderColor(C.trim[1], C.trim[2], C.trim[3], 1)
      self.label:SetTextColor(C.gold[1], C.gold[2], C.gold[3])
      self.label:SetShadowColor(0, 0, 0, 0.8)
    end
  end
  return b
end

function UI.Bar(parent, w, h)
  local bg = parent:CreateTexture(nil, "ARTWORK")
  bg:SetSize(w, h)
  bg:SetColorTexture(0.106, 0.157, 0.173, 1)
  local fill = parent:CreateTexture(nil, "OVERLAY")
  fill:SetPoint("TOPLEFT", bg, "TOPLEFT")
  fill:SetHeight(h)
  local bar = { bg = bg, fill = fill, w = w }
  function bar:Set(frac, color)
    frac = math.max(0, math.min(1, frac or 0))
    color = color or C.goldDim
    self.fill:SetColorTexture(color[1], color[2], color[3], 1)
    self.fill:SetWidth(math.max(1, self.w * frac))
    self.fill:SetShown(frac > 0)
  end
  function bar:SetPoint(...) self.bg:SetPoint(...) end
  function bar:SetShown(on) self.bg:SetShown(on); self.fill:SetShown(on) end
  return bar
end

-- A bar split into colored segments: bar:Set({ { fraction, color }, ... })
function UI.SegBar(parent, w, h)
  local bg = parent:CreateTexture(nil, "ARTWORK")
  bg:SetSize(w, h)
  bg:SetColorTexture(0.106, 0.157, 0.173, 1)
  local bar = { bg = bg, w = w, h = h, segs = {}, used = 0 }
  function bar:Set(list)
    local x = 0
    for i, s in ipairs(list) do
      local t = self.segs[i]
      if not t then t = parent:CreateTexture(nil, "OVERLAY"); self.segs[i] = t end
      local width = math.floor(self.w * math.max(0, math.min(1, s[1] or 0)) + 0.5)
      width = math.min(width, self.w - x)
      t:ClearAllPoints()
      t:SetPoint("TOPLEFT", self.bg, "TOPLEFT", x, 0)
      t:SetSize(math.max(width, 1), self.h)
      t:SetColorTexture(s[2][1], s[2][2], s[2][3], 1)
      t:SetShown(width > 0)
      x = x + width
    end
    for i = #list + 1, #self.segs do self.segs[i]:Hide() end
    self.used = #list
  end
  function bar:SetPoint(...) self.bg:SetPoint(...) end
  function bar:SetShown(on)
    self.bg:SetShown(on)
    if not on then for _, t in ipairs(self.segs) do t:Hide() end end
  end
  return bar
end

-- Account colors, in priority order; the training reserve is always mint.
UI.ACCOUNT_COLORS = {
  { 0.914, 0.784, 0.416 }, { 0.553, 0.659, 0.906 }, { 0.741, 0.580, 0.890 },
  { 0.941, 0.678, 0.400 }, { 0.400, 0.780, 0.820 }, { 0.851, 0.522, 0.659 },
}
UI.FREE_COLOR = { 0.282, 0.341, 0.357 }
function UI.AccountColor(i, g)
  if g and g.kind == "training" then return C.mint end
  return UI.ACCOUNT_COLORS[((i - 1) % #UI.ACCOUNT_COLORS) + 1]
end

-- Segments for gold on hand: each account, then Free.
function UI.WorthSegments()
  local saved, held, free = ns.Balances()
  local total = math.max(GetMoney(), held, 1)
  local list = {}
  for i, g in ipairs(ns.char.goals) do
    if (saved[g.id] or 0) > 0 then list[#list + 1] = { saved[g.id] / total, UI.AccountColor(i, g) } end
  end
  if free > 0 then list[#list + 1] = { free / total, UI.FREE_COLOR } end
  return list, held, free
end

function UI.EditBox(parent, w, numeric)
  local e = CreateFrame("EditBox", nil, parent, BACKDROP_T)
  e:SetSize(w or 120, 24)
  e:SetBackdrop({ bgFile = WHITE, edgeFile = WHITE, edgeSize = 1 })
  e:SetBackdropColor(0.04, 0.05, 0.06, 1)
  e:SetBackdropBorderColor(C.line[1], C.line[2], C.line[3], 1)
  e:SetFont(UI.FONT, 12, "")
  e:SetTextColor(C.text[1], C.text[2], C.text[3])
  e:SetTextInsets(6, 6, 0, 0)
  e:SetAutoFocus(false)
  e:SetScript("OnEscapePressed", e.ClearFocus)
  e:SetScript("OnEnterPressed", e.ClearFocus)
  return e
end

function UI.Check(parent, label, get, set)
  local b = CreateFrame("CheckButton", nil, parent, "UICheckButtonTemplate")
  b:SetSize(24, 24)
  local t = UI.Text(b, 12, C.text)
  t:SetPoint("LEFT", b, "RIGHT", 4, 0)
  t:SetText(label)
  b:SetScript("OnShow", function(self) self:SetChecked(get()) end)
  b:SetScript("OnClick", function(self) ns.Safe(set, self:GetChecked() and true or false) end)
  return b
end

-- Lines for charts (pooled per owner frame).
function UI.LinePool(owner)
  local pool = { owner = owner, lines = {}, n = 0 }
  function pool:Reset() for _, l in ipairs(self.lines) do l:Hide() end; self.n = 0 end
  function pool:Line(x1, y1, x2, y2, color, thick, alpha)
    self.n = self.n + 1
    local l = self.lines[self.n]
    if not l then l = self.owner:CreateLine(nil, "OVERLAY"); self.lines[self.n] = l end
    l:SetStartPoint("BOTTOMLEFT", self.owner, x1, y1)
    l:SetEndPoint("BOTTOMLEFT", self.owner, x2, y2)
    l:SetThickness(thick or 2)
    l:SetColorTexture(color[1], color[2], color[3], alpha or 1)
    l:Show()
    return l
  end
  return pool
end

-- Dashed line made of short segments.
function UI.Dashed(pool, x1, y1, x2, y2, color, thick, dash, gap)
  local dx, dy = x2 - x1, y2 - y1
  local len = math.sqrt(dx * dx + dy * dy)
  if len < 1 then return end
  dash, gap = dash or 6, gap or 4
  local pos = 0
  while pos < len do
    local e = math.min(pos + dash, len)
    pool:Line(x1 + dx * pos / len, y1 + dy * pos / len, x1 + dx * e / len, y1 + dy * e / len, color, thick)
    pos = e + gap
  end
end

---------------------------------------------------------------------------
-- Main window
---------------------------------------------------------------------------
local main, pages, tabs, current = nil, {}, {}, nil
UI.pageOrder = {}
UI.pages = pages   -- built pages by name (diagnostics and tests)

function ns.RegisterPage(name, build)
  table.insert(UI.pageOrder, { name = name, build = build })
end

local function ShowPage(name)
  for n, p in pairs(pages) do p.frame:SetShown(n == name) end
  for n, b in pairs(tabs) do b:SetSelected(n == name) end
  current = name
  if pages[name] and pages[name].Refresh then ns.Safe(pages[name].Refresh, pages[name]) end
end
ns.ShowPage = ShowPage

function ns.RefreshMain()
  if main and main:IsShown() and current and pages[current] and pages[current].Refresh then
    ns.Safe(pages[current].Refresh, pages[current])
  end
end

local function BuildMain()
  main = CreateFrame("Frame", "JPMFMainFrame", UIParent, BACKDROP_T)
  main:SetSize(960, 640)
  main:SetPoint("CENTER")
  main:SetFrameStrata("HIGH")
  main:SetBackdrop({ bgFile = WHITE, edgeFile = WHITE, edgeSize = 2 })
  main:SetBackdropColor(C.frame[1], C.frame[2], C.frame[3], 0.98)
  main:SetBackdropBorderColor(C.trim[1], C.trim[2], C.trim[3], 1)
  main:SetMovable(true); main:EnableMouse(true); main:SetClampedToScreen(true)
  main:RegisterForDrag("LeftButton")
  main:SetScript("OnDragStart", main.StartMoving)
  main:SetScript("OnDragStop", main.StopMovingOrSizing)
  tinsert(UISpecialFrames, "JPMFMainFrame")

  local title = UI.Box(main, C.title, C.trim)
  title:SetPoint("TOPLEFT", 2, -2); title:SetPoint("TOPRIGHT", -2, -2); title:SetHeight(48)
  local crest = title:CreateTexture(nil, "ARTWORK")
  crest:SetSize(30, 30); crest:SetPoint("LEFT", 12, 0)
  crest:SetTexture("Interface\\Icons\\INV_Misc_Coin_02")
  crest:SetTexCoord(0.08, 0.92, 0.08, 0.92)
  local name = UI.Text(title, 18, C.gold); name:SetPoint("TOPLEFT", crest, "TOPRIGHT", 10, 2)
  name:SetText("JP Mograine Financial")
  local sub = UI.Text(title, 11, { 0.725, 0.671, 0.541 }); sub:SetPoint("TOPLEFT", name, "BOTTOMLEFT", 0, -2)
  main.subtitle = sub
  local close = UI.Button(title, "X", 28, 28, function() main:Hide() end)
  close:SetPoint("RIGHT", -10, 0)

  local body = UI.Box(main, C.ground, C.line)
  body:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 8, -8)
  body:SetPoint("BOTTOMRIGHT", -10, 48)
  -- faint trading-screen grid
  for x = 32, 940, 32 do
    local t = body:CreateTexture(nil, "BACKGROUND", nil, 1)
    t:SetColorTexture(C.grid[1], C.grid[2], C.grid[3], 1)
    t:SetPoint("TOPLEFT", x, 0); t:SetPoint("BOTTOMLEFT", x, 0); t:SetWidth(1)
  end
  for y = 32, 560, 32 do
    local t = body:CreateTexture(nil, "BACKGROUND", nil, 1)
    t:SetColorTexture(C.grid[1], C.grid[2], C.grid[3], 1)
    t:SetPoint("TOPLEFT", 0, -y); t:SetPoint("TOPRIGHT", 0, -y); t:SetHeight(1)
  end
  main.body = body

  local x = 12
  for _, p in ipairs(UI.pageOrder) do
    local frame = CreateFrame("Frame", nil, body)
    frame:SetPoint("TOPLEFT", 12, -12); frame:SetPoint("BOTTOMRIGHT", -12, 12)
    frame:Hide()
    local page = { frame = frame }
    ns.Safe(p.build, page, frame)
    pages[p.name] = page
    local b = UI.Button(main, p.name, 96, 30, function() ShowPage(p.name) end)
    b:SetPoint("BOTTOMLEFT", x, 10)
    tabs[p.name] = b
    x = x + 100
  end
  local foot = UI.Text(main, 10, { 0.604, 0.545, 0.408 })
  foot:SetPoint("BOTTOMRIGHT", -14, 18)
  foot:SetText("JP Mograine Financial\226\132\162 \194\183 \194\169 2026 Infihedron")

  main:SetScript("OnShow", function()
    main.subtitle:SetText(("Private banking for adventurers \194\183 %s, level %d"):format(UnitName("player") or "", UnitLevel("player") or 0))
    ShowPage(current or UI.pageOrder[1].name)
  end)
end

function ns.ToggleMain(page)
  if not main then BuildMain() end
  if page then
    current = page
    if main:IsShown() then ShowPage(page) else main:Show() end
  else
    main:SetShown(not main:IsShown())
  end
end

for _, ev in ipairs({ "JPMF_LEDGER_CHANGED", "JPMF_GOALS_CHANGED", "JPMF_WISHLIST_CHANGED" }) do
  ns.On(ev, function() ns.RefreshMain() end)
end

---------------------------------------------------------------------------
-- Copy window (debug log, report)
---------------------------------------------------------------------------
local copy
function ns.ShowCopy(titleText, text)
  if not copy then
    copy = CreateFrame("Frame", "JPMFCopyFrame", UIParent, BACKDROP_T)
    copy:SetSize(680, 400); copy:SetPoint("CENTER"); copy:SetFrameStrata("DIALOG")
    copy:SetBackdrop({ bgFile = WHITE, edgeFile = WHITE, edgeSize = 2 })
    copy:SetBackdropColor(C.frame[1], C.frame[2], C.frame[3], 0.98)
    copy:SetBackdropBorderColor(C.trim[1], C.trim[2], C.trim[3], 1)
    copy:SetMovable(true); copy:EnableMouse(true); copy:RegisterForDrag("LeftButton")
    copy:SetScript("OnDragStart", copy.StartMoving); copy:SetScript("OnDragStop", copy.StopMovingOrSizing)
    tinsert(UISpecialFrames, "JPMFCopyFrame")
    copy.title = UI.Text(copy, 14, C.gold); copy.title:SetPoint("TOPLEFT", 12, -10)
    local hint = UI.Text(copy, 11, C.muted); hint:SetPoint("TOPRIGHT", -44, -12)
    hint:SetText("Click the text, Ctrl+A, Ctrl+C")
    local x = UI.Button(copy, "X", 24, 24, function() copy:Hide() end); x:SetPoint("TOPRIGHT", -8, -6)
    local sf = CreateFrame("ScrollFrame", nil, copy, "UIPanelScrollFrameTemplate")
    sf:SetPoint("TOPLEFT", 12, -36); sf:SetPoint("BOTTOMRIGHT", -32, 12)
    local eb = CreateFrame("EditBox", nil, sf)
    eb:SetMultiLine(true); eb:SetAutoFocus(false); eb:SetFontObject(ChatFontNormal); eb:SetWidth(620)
    eb:SetScript("OnEscapePressed", function() copy:Hide() end)
    sf:SetScrollChild(eb)
    copy.eb = eb
  end
  copy.title:SetText(titleText)
  copy.eb:SetText(text or "")
  copy:Show()
  copy.eb:SetFocus(); copy.eb:HighlightText()
end

---------------------------------------------------------------------------
-- Minimap button and addon compartment
---------------------------------------------------------------------------
local mm
local function PlaceMinimap()
  local a = math.rad(ns.acct.settings.minimap.angle or 215)
  local r = (Minimap:GetWidth() / 2) + 10
  mm:ClearAllPoints()
  mm:SetPoint("CENTER", Minimap, "CENTER", math.cos(a) * r, math.sin(a) * r)
end

function ns.UpdateMinimap()
  if not mm then return end
  mm:SetShown(not ns.acct.settings.minimap.hide)
end

local function Tooltip(owner)
  GameTooltip:SetOwner(owner, "ANCHOR_LEFT")
  GameTooltip:AddLine("JP Mograine Financial", C.gold[1], C.gold[2], C.gold[3])
  local saved, _, free = ns.Balances()
  GameTooltip:AddDoubleLine("Net worth", ns.Money(GetMoney(), true), 1, 1, 1, 1, 1, 1)
  for i, g in ipairs(ns.char.goals) do
    local col = UI.AccountColor(i, g)
    GameTooltip:AddDoubleLine("  " .. g.name, ns.Money(saved[g.id] or 0, true), col[1], col[2], col[3], 1, 1, 1)
  end
  if free < 0 then
    GameTooltip:AddDoubleLine("Overdrawn", ns.Money(-free, true), C.red[1], C.red[2], C.red[3], 1, 1, 1)
  else
    GameTooltip:AddDoubleLine("Free to spend", ns.Money(free, true), 1, 1, 1, 1, 1, 1)
  end
  GameTooltip:AddLine("Left-click: open  |  Right-click: planning session", 0.62, 0.69, 0.68)
  GameTooltip:Show()
end

ns.On("PLAYER_LOGIN", function()
  mm = CreateFrame("Button", "JPMFMinimapButton", Minimap)
  mm:SetSize(31, 31); mm:SetFrameStrata("MEDIUM"); mm:SetFrameLevel(8)
  mm:RegisterForClicks("LeftButtonUp", "RightButtonUp"); mm:RegisterForDrag("LeftButton")
  local icon = mm:CreateTexture(nil, "BACKGROUND")
  icon:SetSize(20, 20); icon:SetPoint("CENTER", 0, 1)
  icon:SetTexture("Interface\\Icons\\INV_Misc_Coin_02")
  local border = mm:CreateTexture(nil, "OVERLAY")
  border:SetSize(53, 53); border:SetPoint("TOPLEFT")
  border:SetTexture("Interface\\Minimap\\MiniMap-TrackingBorder")
  mm:SetHighlightTexture("Interface\\Minimap\\UI-Minimap-ZoomButton-Highlight")
  mm:SetScript("OnClick", function(_, btn)
    if btn == "RightButton" then ns.OpenPlanning(true) else ns.ToggleMain() end
  end)
  mm:SetScript("OnDragStart", function(self)
    self:SetScript("OnUpdate", function()
      local mx, my = Minimap:GetCenter()
      local px, py = GetCursorPosition()
      local s = Minimap:GetEffectiveScale()
      ns.acct.settings.minimap.angle = math.deg(math.atan2(py / s - my, px / s - mx))
      PlaceMinimap()
    end)
  end)
  mm:SetScript("OnDragStop", function(self) self:SetScript("OnUpdate", nil) end)
  mm:SetScript("OnEnter", Tooltip)
  mm:SetScript("OnLeave", function() GameTooltip:Hide() end)
  PlaceMinimap()
  ns.UpdateMinimap()
end)

function JPMF_OnCompartmentClick(_, button)
  if button == "RightButton" then ns.OpenPlanning(true) else ns.ToggleMain() end
end
function JPMF_OnCompartmentEnter(_, btn) Tooltip(btn) end
function JPMF_OnCompartmentLeave() GameTooltip:Hide() end
