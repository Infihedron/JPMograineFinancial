--[[ JP Mograine Financial - Copyright (C) 2026 Infihedron. Licensed under the GNU GPL v3 or later; see LICENSE.
     Morgrim Stanley: the planning session. A framed 3D portrait that talks you
     through last week, your goals, upcoming costs and one recommendation. ]]

local _, ns = ...
local UI = ns.UI
local C = UI.C

local win, steps, step

-- The game only draws a creature it has details for. Those arrive from the server a
-- moment after we ask, so look again a few times and show the coin until he appears.
local function Loaded(m)
  local ok, id = pcall(m.GetModelFileID, m)
  if ok and id and id ~= 0 then return true end
  ok, id = pcall(m.GetModel, m)
  return ok and type(id) == "string" and id ~= ""
end

local function SetPortrait(tries)
  local m = win.model
  local id = ns.acct.settings.morgrimCreature
  local ok = id and pcall(m.SetCreature, m, id)
  local shown = ok and Loaded(m)
  win.fallback:SetShown(not shown)
  m:SetShown(ok and true or false)
  m:SetAlpha(shown and 1 or 0)
  if shown then
    pcall(m.SetPortraitZoom, m, 0.75)
    pcall(m.SetCamDistanceScale, m, 1.1)
  elseif ok and (tries or 0) < 6 and C_Timer then
    C_Timer.After(0.5 + (tries or 0) * 0.5, function()
      if win and win:IsShown() then SetPortrait((tries or 0) + 1) end
    end)
  end
end

local function Talk()
  if win.model:IsShown() then
    pcall(win.model.SetAnimation, win.model, 60)   -- talk
    if C_Timer then
      C_Timer.After(2.5, function() if win and win.model:IsShown() then pcall(win.model.SetAnimation, win.model, 0) end end)
    end
  end
end

local function Show(i)
  step = math.max(1, math.min(#steps, i))
  win.speech:SetText(steps[step])
  win.count:SetText(("%d of %d"):format(step, #steps))
  win.back:SetEnabled(step > 1)
  win.next.label:SetText(step < #steps and "Next" or "Done")
  Talk()
end

local function Build()
  win = CreateFrame("Frame", "JPMFPlanningFrame", UIParent, BackdropTemplateMixin and "BackdropTemplate" or nil)
  win:SetSize(560, 300); win:SetPoint("CENTER", 0, 80); win:SetFrameStrata("DIALOG")
  win:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8x8", edgeFile = "Interface\\Buttons\\WHITE8x8", edgeSize = 2 })
  win:SetBackdropColor(0.106, 0.090, 0.063, 0.98)
  win:SetBackdropBorderColor(C.trim[1], C.trim[2], C.trim[3], 1)
  win:SetMovable(true); win:EnableMouse(true); win:RegisterForDrag("LeftButton")
  win:SetScript("OnDragStart", win.StartMoving); win:SetScript("OnDragStop", win.StopMovingOrSizing)
  tinsert(UISpecialFrames, "JPMFPlanningFrame")

  local frameBox = UI.Box(win, { 0.141, 0.114, 0.071 }, C.goldDim)
  frameBox:SetSize(170, 220); frameBox:SetPoint("TOPLEFT", 16, -16)
  win.model = CreateFrame("PlayerModel", nil, frameBox)
  win.model:SetPoint("TOPLEFT", 3, -3); win.model:SetPoint("BOTTOMRIGHT", -3, 3)
  win.fallback = frameBox:CreateTexture(nil, "ARTWORK")
  win.fallback:SetSize(96, 96); win.fallback:SetPoint("CENTER")
  win.fallback:SetTexture("Interface\\Icons\\INV_Misc_Coin_02")
  local plate = UI.Text(win, 13, C.gold); plate:SetPoint("TOP", frameBox, "BOTTOM", 0, -8)
  plate:SetText("Morgrim Stanley"); plate:SetJustifyH("CENTER")
  local role = UI.Text(win, 10, C.muted); role:SetPoint("TOP", plate, "BOTTOM", 0, -2)
  role:SetText("Senior Advisor"); role:SetJustifyH("CENTER")

  local title = UI.Text(win, 15, C.gold); title:SetPoint("TOPLEFT", 206, -18)
  title:SetText("Your planning session")
  win.count = UI.Text(win, 11, C.muted); win.count:SetPoint("TOPRIGHT", -16, -20)
  local bubble = UI.Box(win, { 0.071, 0.063, 0.047 }, { 0.36, 0.28, 0.12 })
  bubble:SetPoint("TOPLEFT", 200, -46); bubble:SetPoint("BOTTOMRIGHT", -16, 56)
  win.speech = UI.Text(bubble, 13.5, { 0.937, 0.894, 0.784 })
  win.speech:SetPoint("TOPLEFT", 14, -14); win.speech:SetPoint("BOTTOMRIGHT", -14, 14)
  win.speech:SetJustifyV("TOP"); win.speech:SetSpacing(3)

  win.back = UI.Button(win, "Back", 80, 26, function() Show(step - 1) end)
  win.back:SetPoint("BOTTOMLEFT", 200, 16)
  win.next = UI.Button(win, "Next", 90, 26, function()
    if step < #steps then Show(step + 1) else
      ns.char.lastPlan = time()
      win:Hide()
    end
  end)
  win.next:SetPoint("BOTTOMRIGHT", -16, 16)
  local later = UI.Button(win, "Remind me tomorrow", 150, 26, function()
    ns.char.lastPlan = time() - 6 * 86400
    win:Hide()
  end)
  later:SetPoint("RIGHT", win.next, "LEFT", -8, 0)
end

function ns.OpenPlanning(manual)
  if not win then Build() end
  steps = ns.MorgrimLines()
  SetPortrait()
  win:Show()
  Show(1)
  ns.Log("planning session opened (%s)", manual and "manual" or "weekly")
end

-- Weekly, on login, once there is at least a day of data.
ns.On("PLAYER_ENTERING_WORLD", function(_, isLogin)
  if not isLogin or not ns.acct.settings.autoPlan then return end
  local c = ns.char
  if time() - (c.lastPlan or 0) < 7 * 86400 then return end
  if time() - (c.created or time()) < 86400 then return end
  if C_Timer then C_Timer.After(6, function() ns.Safe(ns.OpenPlanning, false) end) end
end)
