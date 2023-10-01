local myAddonName, ns = ...

local DEFAULTS = { inferno = { active = true, debug = true },
                   auras = { active = true, debug = true, expirations = true },
                   mounts = { debug = true } }

local function initDB()
  AshranUtilitiesDB = AshranUtilitiesDB or {}
end

local AddonOptions = CreateFrame("Frame")

ns.AddonOptions = AddonOptions

function ns.log(message)
  AshranUtilitiesDB.log = AshranUtilitiesDB.log or {}
  table.insert(AshranUtilitiesDB.log, message)
end

function ns.print(message, red, green, blue)
  local prefix = "> "
  DEFAULT_CHAT_FRAME:AddMessage(prefix..message, red or 219 / 255 , green or 171 / 255, blue or 42 / 255)
end

local function debugErrors()
  local errors = AshranUtilitiesDB.errors or {}
  if #errors > 0 then
    ns.print(format("Logged %d errors.", #errors))
  end
end

function AddonOptions:CreateCheckbox(id, option, label, parent, updateFunc)
  local cb = CreateFrame("CheckButton", nil, parent, "InterfaceOptionsCheckButtonTemplate")
  cb.Text:SetText(label)
  local function UpdateOption(value)
    self.db[id][option] = value
    cb:SetChecked(value)
    if updateFunc then
      updateFunc(value)
    end
  end
  UpdateOption(self.db[id][option])
  -- there already is an existing OnClick script that plays a sound, hook it
  cb:HookScript("OnClick", function (_, btn, down)
    UpdateOption(cb:GetChecked())
  end)
  EventRegistry:RegisterCallback("AshranUtils.AddonOptions.OnReset", function ()
    UpdateOption(DEFAULTS[id][option])
  end, cb)

  return cb
end

function AddonOptions:Initialize()
  self.db = AshranUtilitiesDB

  for k, v in pairs(DEFAULTS) do
    self.db[k] = self.db[k] or {}
    for kk, vv in pairs(v) do
      if self.db[k][kk] == nil then
        self.db[k][kk] = vv
      end
    end
  end

  self.panel_main = CreateFrame("Frame")
  self.panel_main.name = myAddonName

  local auras_active = self:CreateCheckbox("auras", "active", "Auras announce", self.panel_main)
  auras_active:SetPoint("TOPLEFT", 20, -20)

  local auras_debug = self:CreateCheckbox("auras", "debug", "Auras debug", self.panel_main)
  auras_debug:SetPoint("TOPLEFT", auras_active, 0, -30)

  local auras_expirations = self:CreateCheckbox("auras", "expirations", "Auras expirations", self.panel_main)
  auras_expirations:SetPoint("TOPLEFT", auras_debug, 0, -30)

  local inferno_active = self:CreateCheckbox("inferno", "active", "Inferno announce", self.panel_main)
  inferno_active:SetPoint("TOPLEFT", auras_expirations, 0, -30)

  local inferno_debug = self:CreateCheckbox("inferno", "debug", "Inferno debug", self.panel_main)
  inferno_debug:SetPoint("TOPLEFT", inferno_active, 0, -30)

  local mounts_debug = self:CreateCheckbox("mounts", "debug", "Mounts debug", self.panel_main)
  mounts_debug:SetPoint("TOPLEFT", inferno_debug, 0, -30)

  local auras_reset = CreateFrame("Button", nil, self.panel_main, "UIPanelButtonTemplate")
  auras_reset:SetPoint("TOPLEFT", mounts_debug, 0, -40)
  auras_reset:SetText(RESET)
  auras_reset:SetWidth(100)
  auras_reset:SetScript("OnClick", function ()
    AshranUtilitiesDB = CopyTable(DEFAULTS)
    self.db = AshranUtilitiesDB
    EventRegistry:TriggerEvent("AshranUtils.AddonOptions.OnReset")
  end)

  InterfaceOptions_AddCategory(self.panel_main)

  -- sub panel
  -- local panel_inferno = CreateFrame("Frame")
  -- panel_inferno.name = "Inferno"
  -- panel_inferno.parent = self.panel_main.name

  -- InterfaceOptions_AddCategory(panel_inferno)
  -- InterfaceAddOnsList_Update()
end

SLASH_AddonOptions1 = "/auui"

SlashCmdList.AddonOptions = function (msg, editBox)
	ns.wrap(function ()
    InterfaceOptionsFrame_OpenToCategory(AddonOptions.panel_main)
  end)
end

local f = CreateFrame("Frame")

function ns.wrap(func, ...)
  local ok, message = pcall(func, ...)
  if not ok then
    ns.print("!!!", ns.hex2rgb("ff0000"))
    ns.print(format("Error: %s", message), ns.hex2rgb("ff0000"))
    ns.print("!!!", ns.hex2rgb("ff0000"))
    if AshranUtilitiesDB then
      AshranUtilitiesDB.errors = AshranUtilitiesDB.errors or {}
      table.insert(AshranUtilitiesDB.errors, message)
    end
  end
end

function f:OnEvent(event, ...)
	ns.wrap(self[event], self, event, ...)
end

function f:ADDON_LOADED(event, addOnName)
  if addOnName == myAddonName then
    ns.print("AshranUtils.lua loaded.")
    initDB()
    debugErrors()
    AddonOptions:Initialize()
  end
end


-- /dump GetSpellInfo("Erdschild")
-- /dump GetSpellInfo(171249)
-- Rolle des Schutzes: 171249
-- Einsamer Wolf: 164273
-- Geisterwolf: 2645 (regular) , 260881 (dmg red)
-- Erdschild: 974
-- Lebenszyklus (Beleben): 197916
-- Lebenszyklus (Einhüllender Nebel): 197919
-- /say {rt5} xxx
-- Springflut: 61295
-- [357650] = "Urtümliche Wut"
-- /dump IsOutdoors()


-- /dump GetInstanceInfo()
-- /dump C_Map.GetBestMapForUnit("player")

-- areaPoiIDs = C_AreaPoiInfo.GetAreaPOIForMap(1478)
-- /dump C_AreaPoiInfo.GetAreaPOIForMap(1478)
-- secondsLeft = C_AreaPoiInfo.GetAreaPOISecondsLeft(6493)
-- /dump C_AreaPoiInfo.GetAreaPOISecondsLeft(6493)
-- Ashran Battleground 1191
-- /dump C_Map.GetMapInfo(4445)
-- /dump C_Map.GetMapInfo(603)
-- /dump C_Map.GetMapInfo(1191)


local function makeTowerInfo(pattern)
  return { pattern = pattern, duration = 0, faction = nil }
end

-- %s wird angegriffen! die %s ihn erobern
-- %s wird angegriffen! ihn zerstören
-- Eisblutturm
-- Turmstellung
-- der östlicher Frostwolfturm
-- der westliche Frostwolfturm
-- Nordbunker von Dun Baldar
-- Südbunder von Dun Baldar
-- Eisschwingenbunker
-- Steinbruchbunker

-- erobert
-- zerstört
local towersMeta = {
  __index = function (self, id)
    for _k, v in pairs(self.store) do
      for towerId, towerInfo in pairs(v) do
        if towerId == id then return towerInfo end
      end
    end
    return nil
  end,
  __call = function (self, text, playerName)
    if playerName ~= "Herold" then return end

    print(format("who: %s, what: %s", playerName, text))
    if text:find("Horde") then
      for id, towerInfo in pairs(self.store) do
        if text:find(towerInfo.pattern) then
          towerInfo.faction = "Horde"
          if text:find("erobert") then
            print(format("%s erobert!", towerInfo.pattern))
            -- reset
            towerInfo.duration = 0
          elseif text:find("erobern") then
            print(format("%s tapped!", towerInfo.pattern))
            -- started capturing
            towerInfo.duration = GetServerTime()
          else
            print(format("%s reset!", towerInfo.pattern))
            -- reset
            towerInfo.duration = 0
          end
        end
      end
    elseif text:find("Allianz") then
      for id, towerInfo in pairs(self.store) do
        if text:find(towerInfo.pattern) then
          towerInfo.faction = "Allianz"
          if text:find("zerstört") then
            print(format("%s erobert!", towerInfo.pattern))
            -- destroyed
            towerInfo.duration = -1
          elseif text:find("zerstören") then
            print(format("%s tapped!", towerInfo.pattern))
            -- started capturing
            towerInfo.duration = GetServerTime()
          else
            print(format("%s reset!", towerInfo.pattern))
            -- reset
            towerInfo.duration = 0
          end
        end
      end
    end
  end
}
local towers = setmetatable({ 
  reset = function (self)
    for _id, towerInfo in pairs(self.store) do
      towerInfo.duration = 0
    end
  end,
  store = {
    ["SH"] = makeTowerInfo("Steinbruchbunker"),
    ["IW"] = makeTowerInfo("Eisschwingenbunker"),
    ["south"] = makeTowerInfo("Südbunder von Dun Baldar"),
    ["north"] = makeTowerInfo("Nordbunker von Dun Baldar"),
    ["IB"] = makeTowerInfo("Eisblutturm"),
    ["TP"] = makeTowerInfo("Turmstellung"),
    ["east"] = makeTowerInfo("östlicher? Frostwolfturm"),
    ["west"] = makeTowerInfo("westlicher? Frostwolfturm")
  }
}, towersMeta)
local towerIds = (function (towers)
  local tmp = {}
  for id, towerInfo in pairs(towers.store) do
    tmp[id] = true
  end
  return tmp
end)(towers)

local function isTowerArg(message)
  return towerIds[message]
end

local function formatSeconds(diff)
  local m = 60
  local minutes = math.modf(diff / m)
  local seconds = math.floor(math.fmod (diff, m))

  return format("%d:%d", minutes, seconds)
end

local function debugTower(towerInfo)
  if towerInfo.duration < 0 then
    print(format("%s destroyed tower %s", towerInfo.faction, towerInfo.pattern))
  elseif towerInfo.duration == 0 then
    print(format("(%a) tower %s not attacked", towerInfo.faction, towerInfo.pattern))
  else
    local diff = GetServerTime() - towerInfo.duration
    print(format("%s rttower %s: %s", towerInfo.faction, towerInfo.pattern, formatSeconds(diff)))
  end
end

SLASH_AU_TOWERS1 = "/autowers"
SlashCmdList["AU_TOWERS"] = function (message, _editBox)
  if message == "" then
    for faction, v in pairs(towers.store) do
      for id, towerInfo in pairs(v) do
        debugTower(towerInfo)
      end
    end
  elseif message == "reset" then
    towers:reset()
  elseif isTowerArg(message) then
    for _k, v in pairs(towers.store) do
      for k, towerInfo in pairs(v) do
        if k == message then
          debugTower(towerInfo)
        end
      end
    end
  else
    print("AU_TOWERS: unknown command")
  end
end

function f:CHAT_MSG_MONSTER_YELL(event, text, playerName, languageName, channelName, playerName2, specialFlags, zoneChannelID, channelIndex, channelBaseName, languageID, lineID, guid, bnSenderID, isMobile, isSubtitle, hideSenderInLetterbox, supressRaidIcons)
  if GetRealZoneText() ~= "Alteractal" then return end

  towers(text, playerName)
end

SLASH_AU_POI1 = "/aupoi"

SlashCmdList["AU_POI"] = function (message, _editBox)
  ns.wrap(function ()
    local uiMapID = C_Map.GetBestMapForUnit("player")
    for _, areaPoiID in ipairs(C_AreaPoiInfo.GetAreaPOIForMap(uiMapID)) do
      local areaPOIInfo = C_AreaPoiInfo.GetAreaPOIInfo(uiMapID, areaPoiID)
      print(format("poi: %s", areaPOIInfo.name))
      if C_AreaPoiInfo.IsAreaPOITimed(areaPoiID) then
        print(format("time left: %d seconds", C_AreaPoiInfo.GetAreaPOISecondsLeft(areaPoiID)))
      else
        print("not timed")
        print(format("time left: %d seconds", C_AreaPoiInfo.GetAreaPOISecondsLeft(areaPoiID)))
      end
    end
  end)
end

local DraggableFrame = { buttons = {} }
ns.DraggableFrame = DraggableFrame

local function savePosition(f)
  local point, relativeTo, relativePoint, offsetX, offsetY = f:GetPoint()
  if type(relativeTo) ~= "nil" then
    relativeTo = relativeTo:GetName()
  end
  AshranUtilitiesDB.savedPosition = {
    isLocked = f.isLocked,
    point = { point, relativeTo, relativePoint, offsetX, offsetY }
  }
end


local function makeRandomBySearchButton(f, clickFunc)
  local actionButton = CreateFrame("Button", nil, f, "ActionBarButtonTemplate")
  actionButton:RegisterForClicks("AnyUp")

  local function makeTexture()
    local texture = actionButton:CreateTexture()
    texture:SetTexture(134400) -- question mark
    return texture
  end

  actionButton:SetNormalTexture(makeTexture())
  local pt = makeTexture()
  pt:SetDesaturation(0.85)

  actionButton:SetPushedTexture(pt)
  actionButton:SetHighlightTexture(makeTexture())

  local function clickButton()
    if clickFunc then clickFunc() end
  end

  actionButton:SetScript("OnClick", clickButton)
  actionButton:SetPoint("BOTTOMRIGHT", -10, 10)
  actionButton:SetSize(40, 40)
end


function DraggableFrame.makeDraggableFrame()
  if DraggableFrame.frame then
    EventRegistry:TriggerEvent("AshranUtils.Widget.OnReset")
    DraggableFrame.frame:Show()
    return
  end

  local f = CreateFrame("Frame", nil, UIParent, "BackdropTemplate")
  DraggableFrame.frame = f
  if type(AshranUtilitiesDB.savedPosition) == "table" then
    local point, relativeTo, relativePoint, offsetX, offsetY = unpack(AshranUtilitiesDB.savedPosition.point)
    if type(relativeTo) == "string" then
      relativeTo = _G[relativeTo]
    end
    f.isLocked = AshranUtilitiesDB.savedPosition.isLocked
    f:SetPoint(point, relativeTo, relativePoint, offsetX, offsetY)
  else
    f:SetPoint("CENTER")
  end
  f:SetSize(200, 200)
  f:SetBackdrop(BACKDROP_TUTORIAL_16_16)

  f.isLocked = f.isLocked or false

  local anchorButton = CreateFrame("CheckButton", nil, f, "InterfaceOptionsCheckButtonTemplate")
  anchorButton:SetPoint("TOPRIGHT", -22, -2.5)
  anchorButton:SetChecked(f.isLocked)
  anchorButton:HookScript("OnClick", function (self, button, down)
    f.isLocked = self:GetChecked()
    savePosition(f)
  end)

  local closeButton = CreateFrame("Button", nil, f, "FloatingFrameCloseButtonDefaultAnchors")
  closeButton:SetPoint("TOPRIGHT", -5, -5)
  closeButton:SetSize(20, 20)
  closeButton:SetScript("OnClick", function(self, button, down)
    if down then f:Hide() end
  end)
  closeButton:RegisterForClicks("AnyDown", "AnyUp")

  local textField = CreateFrame("EditBox", nil, f, "SearchBoxTemplate")
  textField:SetPoint("TOPLEFT", 15, -2.5)
  textField:SetSize(100, 30)

  local outputPane = CreateFrame("Frame", nil, f)
  outputPane:SetSize(100, 60)
  outputPane:SetPoint("TOP", textField, 0, -40)
  outputPane.outputFS = outputPane.outputFS or outputPane:CreateFontString(nil, "OVERLAY", "GameTooltipText")
  outputPane.outputFS:SetPoint("TOPLEFT", outputPane)
  outputPane.outputFS:SetText("")

  textField:SetScript("OnEnterPressed", function (self)
    if ns.Mounts then
      local results = ns.Mounts.search(self:GetText())
      outputPane.outputFS:SetText(format("%d results", #results))
    end
    self:ClearFocus()
  end)
  textField:SetScript("OnTextSet", function (self)
    if self:GetText() == "" then
      outputPane.outputFS:SetText("")
    end
  end)

  makeRandomBySearchButton(f, function ()
    ns.Mounts.filtered(textField:GetText())
  end)

  for _, maker in ipairs(DraggableFrame.buttons) do
    maker(f)
  end

  local function reset()
    closeButton:SetButtonState("NORMAL")
    textField:SetText("")
    f:SetMovable(true)
  end

  EventRegistry:RegisterCallback("AshranUtils.Widget.OnReset", reset, f)
  f:SetMovable(true)
  local function debugPoint(type)
    local point, relativeTo, relativePoint, offsetX, offsetY = f:GetPoint()
    print(format("%s: (point = %s, relativePoint = %s) offsetX = %d, offsetY = %d", type, point, relativePoint, offsetX, offsetY))
    if relativeTo then
      print(format("name? %s", tostring(relativeTo:GetName())))
    end
  end
  f:SetScript("OnMouseDown", function (self, button)
    -- debugPoint("down")
    if f.isLocked then return end

    self:StartMoving()
  end)
  f:SetScript("OnMouseUp", function (self, button)
    -- debugPoint("up")
    if f.isLocked then savePosition(f) return end

    self:StopMovingOrSizing()
    savePosition(f)
  end)
end

function AshranUtils_CompartmentFunc()
  ns.wrap(DraggableFrame.makeDraggableFrame)
end

function f:CHAT_MSG_WHISPER(event, text, playerName, languageName, channelName, playerName2, specialFlags, zoneChannelID, channelIndex, channelBaseName, languageID, lineID, guid, bnSenderID, isMobile, isSubtitle, hideSenderInLetterbox, supressRaidIcons)
  ns.wrap(function ()
    if string.find(string.lower(text), "enter") then
      local message = format("%s whispered: %s", playerName, text)
      -- SendChatMessage(message, "PARTY")
      ns.print(message)
    end
  end)
end

f:RegisterEvent("ADDON_LOADED")
f:RegisterEvent("CHAT_MSG_MONSTER_YELL")
f:RegisterEvent("CHAT_MSG_WHISPER")
f:SetScript("OnEvent", f.OnEvent)
