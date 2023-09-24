local myAddonName, ns = ...

local function isDebug()
  return ns.AddonOptions.db.mounts.debug
end

local f = CreateFrame("Frame")

function f:OnEvent(event, ...)
	ns.wrap(self[event], self, event, ...)
end


function ns.hex2rgb(hexString, alpha)
  local t = {}
  for component in string.gmatch(hexString, "..") do
    table.insert(t, tonumber(component, 16))
  end
  table.insert(t, alpha or 1)
  return ns.rgb(unpack(t))
end


local function makeLookupMap(...)
  local t = {}
  for _, pair in ipairs({ ... }) do
    local a, b = unpack(pair)
    t[a], t[b] = b, a
  end
  return t
end

local typeMap = makeLookupMap({ 230, "ground" },
                              { 248, "flying" },
                              { 402, "advflying" })
local factionMap = makeLookupMap({ 0, "Horde" },
                                 { 1, "Alliance" })

local colours = {}
do
  local coloursMeta = {
    __index = {
      dismount = { ns.hex2rgb("ff0000") },
      ground = { ns.hex2rgb("bd396d") },
      advflying = { ns.hex2rgb("d0d938") },
      flying = { ns.hex2rgb("64ab22") },
      swimming = { ns.hex2rgb("64ab22") },
      zoned = { ns.hex2rgb("64ab22") }
    },
    __call = function (self, typeOrName)
      local argType = type(typeOrName)
      if argType == "string" then
        return unpack(self[typeOrName])
      elseif argType == "number" then
        return unpack(self[typeMap[typeOrName]])
      end
    end
  }

  setmetatable(colours, coloursMeta)
end

local function makeIsMapFunction(targetMapID)
  return function ()
    local mapID = C_Map.GetBestMapForUnit("player")
    local mapInfo = C_Map.GetMapInfo(mapID)
    if mapID == targetMapID then return true end

    while mapInfo.mapID ~= targetMapID or mapInfo.parentMapID ~= 0 do
      mapInfo = C_Map.GetMapInfo(mapInfo.parentMapID)
      if not mapInfo then return false end
      if mapInfo.mapID == targetMapID then return true end
    end

    return false
  end
end

local isVashjir = makeIsMapFunction(203)
local isAhnQiraj = makeIsMapFunction(320)

local mounts = {}
do
  local types = {
    ["ground"] = { [230] = true, [412] = true },
    ["flying"] = { [247] = true, [248] = true, [424] = true },
    -- 424 NOT YET
    ["advflying"] = { [402] = true, [424] = not true },
    ["swimming"] = { [231] = true, [407] = true },
    ["zoned"] = { [232] = isVashjir,  [241] = isAhnQiraj }
  }
  local mountsMeta = {
    __index = {
      debug = function (self)
        for mountType, mounts in pairs(self.lists) do
          print(format("mounts2: #%s = %d", mountType, #mounts))
        end
      end,
      isFactionUsable = function (self, isFactionSpecific, faction)
        if not isFactionSpecific then return true end
      
        local englishFaction, localizedFaction = UnitFactionGroup("player")

        return factionMap[englishFaction] == faction
      end,
      random = function (self, type)
        local mounts = self.lists[type]

        local max = #mounts
        local randomIndex = math.random(max)
        local mountID, name, mountCreatureDisplayInfoLink
        local skipped = 0
        for i = randomIndex, randomIndex + max do
          local index = i % (max + 1)
          index = math.max(index, 1)
          mountID, name = unpack(mounts[index])
          local name, spellID, icon, isActive, isUsable, sourceType, isFavorite, isFactionSpecific, faction, shouldHideOnChar, isCollected, mountID, isForDragonriding = C_MountJournal.GetMountInfoByID(mountID)
          mountCreatureDisplayInfoLink = C_MountJournal.GetMountLink(spellID)
          if isActive then
            isUsable = false
          end
          if isUsable then break end

          ns.print(format("skipped: %s (id = %d, typeID = %d)", name, mountID, mountTypeID))
          skipped = skipped + 1
        end
        
        ns.print(format("summoning %s (%s, start: %d, skipped: %d)", mountCreatureDisplayInfoLink, type, randomIndex, skipped), colours(type))
        C_MountJournal.SummonByID(mountID)
      end,
      lists = {
        ["ground"] = {},
        ["flying"] = {},
        ["advflying"] = {},
        ["swimming"] = {},
        ["zoned"] = {}
      }
    },
    __call = function (self, mountTypeID, mountID, name)
      if self[mountID] then return end

      self[mountID] = true
      for k, v in pairs(types) do
        local mapping = v[mountTypeID]
        if mapping then
          local mappingType = type(mapping)
          if mappingType == "boolean" then
            table.insert(self.lists[k], { mountID, name })
          end
        end
      end
    end
  }

  setmetatable(mounts, mountsMeta)
end

local function readMounts()
  for _, mountID in ipairs(C_MountJournal.GetMountIDs()) do
    if not mounts[mountID] then
      local name, spellID, icon, isActive, isUsable, sourceType, isFavorite, isFactionSpecific, faction, shouldHideOnChar, isCollected, mountID, isForDragonriding = C_MountJournal.GetMountInfoByID(mountID)
      if isCollected and mounts:isFactionUsable(isFactionSpecific, faction) then
        local creatureDisplayInfoID, description, source, isSelfMount, mountTypeID, uiModelSceneID, animID, spellVisualKitID, disablePlayerMountPreview = C_MountJournal.GetMountInfoExtraByID(mountID)
        mounts(mountTypeID, mountID, name)
      end
    end
  end
end


function f:MOUNT_JOURNAL_USABILITY_CHANGED(event)
  readMounts()
end

function f:NEW_MOUNT_ADDED(event, mountID)
  local name, spellID, icon, isActive, isUsable, sourceType, isFavorite, isFactionSpecific, faction, shouldHideOnChar, isCollected, mountID, isForDragonriding = C_MountJournal.GetMountInfoByID(mountID)
  local creatureDisplayInfoID, description, source, isSelfMount, mountTypeID, uiModelSceneID, animID, spellVisualKitID, disablePlayerMountPreview = C_MountJournal.GetMountInfoExtraByID(mountID)
  mounts(mountTypeID, mountID, name)
end


SLASH_AU_MOUNT1 = "/aumount"

SlashCmdList["AU_MOUNT"] = function (message, editBox)
  ns.wrap(function ()
    readMounts()

    if UnitAffectingCombat("player") then ns.print("In combat!", ns.hex2rgb("cf0000")) return end

    if IsIndoors() then ns.print("Indoors!", colours("dismount")) return end
    if IsSwimming() or message == "swimming" then mounts:random("swimming") return end

    -- print(format("IsAltKeyDown() = %s, IsShiftKeyDown() = %s", tostring(IsAltKeyDown()), tostring(IsShiftKeyDown())))
    if message == "info" then
      ns.print("Mounts info:")
      mounts:debug()
    elseif IsAltKeyDown() or UnitInBattleground("player") then
      mounts:random("ground")
    elseif IsShiftKeyDown() then
      ns.print("Dismount!", colours("dismount"))
      Dismount()
    elseif IsControlKeyDown() then
      mounts:random("flying")
    elseif IsAdvancedFlyableArea() then
      mounts:random("advflying")
    else
      mounts:random("flying")
    end
  end)
end


local buttons = {
  -- Fossiler Raptor
  { icon = 456563, func = function () mounts:random("ground") end },
  -- Argentumhippogryph 
  { icon = 132265, func = function () mounts:random("flying") end },
  -- Windgeborener Velocidrache
  { icon = 4622500, func = function () mounts:random("advflying") end }
}

local function makeActionButton(index, f, icon, clickFunc)
  local actionButton = CreateFrame("Button", nil, f, "ActionBarButtonTemplate")
  actionButton:RegisterForClicks("AnyUp")
  local function makeTexture()
    local texture = actionButton:CreateTexture()
    texture:SetTexture(icon)
    return texture
  end

  actionButton:SetNormalTexture(makeTexture())
  local pt = makeTexture()
  pt:SetDesaturation(0.85)

  actionButton:SetPushedTexture(pt)
  actionButton:SetHighlightTexture(makeTexture())
  local function clickButton()
    print("clickButton "..index..", type = "..type(clickFunc))
    if clickFunc then clickFunc() end
  end
  actionButton:SetScript("OnClick", clickButton)
  actionButton:SetPoint("LEFT", 10 + 40 * (index - 1), -20)
  actionButton:SetSize(40, 40)
  return actionButton
end

local function makeButtons(f)
  for i, button in ipairs(buttons) do
    local actionButton = makeActionButton(i, f, button.icon, button.func)  
  end
end


function f:ADDON_LOADED(event, addOnName)
  if addOnName == myAddonName then
    print(format("Hello %s! Mounts.lua loaded.", UnitName("player")))
    readMounts()
    table.insert(ns.DraggableFrame.buttons, makeButtons)
  end
end

f:RegisterEvent("ADDON_LOADED")
f:RegisterEvent("MOUNT_JOURNAL_USABILITY_CHANGED")
f:RegisterEvent("NEW_MOUNT_ADDED")
f:SetScript("OnEvent", f.OnEvent)
