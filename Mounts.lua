local myAddonName, ns = ...

local function isDebug()
  return ns.AddonOptions.db.mounts.debug
end

local f = CreateFrame("Frame")

function f:OnEvent(event, ...)
	self[event](self, event, ...)
end


function ns.hex2rgb(hexString)
  local t = {}
  for component in string.gmatch(hexString, "..") do
    table.insert(t, tonumber(component, 16))
  end
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
      flying = { ns.hex2rgb("64ab22") }
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


local mounts = {}
do
  local mountsMeta = {
    __index = {
      types = { [230] = {},
                [248] = {},
                [402] = {} },
      isMountUsable = function (self, isFactionSpecific, faction)
        if not isFactionSpecific then return true end
      
        local englishFaction, localizedFaction = UnitFactionGroup("player")
    
        return factionMap[englishFaction] == faction
      end,
      debug = function (self)
        for mountTypeID, mounts in pairs(self.types) do
          print(format("#%s = %d", typeMap[mountTypeID], #mounts))
        end
      end,
      isZoneForDragonriding = function (self)
        local mapID = C_Map.GetBestMapForUnit("player")
        local mapInfo = C_Map.GetMapInfo(mapID)
        while mapInfo.mapID ~= 1978 and mapInfo.parentMapID ~= 0 do
          mapInfo = C_Map.GetMapInfo(mapInfo.parentMapID)
          if mapInfo.mapID == 1978 then return true end
        end
  
        return false
      end,
      random = function (self, type)
        local meta = getmetatable(self)
        local mountTypeID = typeMap[type]
  
        local mountID, name, isFactionSpecific, faction
        local max = #self.types[mountTypeID]
        local canUse, tries, randomIndex = false, 0, math.random(max)
        for i = randomIndex, randomIndex + max do
          local index = i % max + 1
          mountID, name, isFactionSpecific, faction = unpack(self.types[mountTypeID][index])
          canUse = self:isMountUsable(isFactionSpecific, faction)

          if canUse then break end
          tries = tries + 1
  
          if isDebug() then
            ns.print(format("skipped: %s, faction = %s", name, tostring(factionMap[faction])), colours(type))
          end
        end
        if not canUse then print("No mount at all!") return end
  
        ns.print(format("summoning %s (%s, start: %d, tries: %d)", name, type, randomIndex, tries), colours(type))
        C_MountJournal.SummonByID(mountID)
      end
    },
    __call = function (self, mountTypeID, mountID, name, isFactionSpecific, faction)
      if not self.types[mountTypeID] then return end
      if self[mountID] then return end
  
      self[mountID] = mountID
      table.insert(self.types[mountTypeID], { mountID, name, isFactionSpecific, faction })
    end
  }
  setmetatable(mounts, mountsMeta)
end

local function readMounts()
  if mounts.scanned then return end

  local any = false
  for _, mountID in ipairs(C_MountJournal.GetMountIDs()) do
    local name, spellID, icon, isActive, isUsable, sourceType, isFavorite, isFactionSpecific, faction, shouldHideOnChar, isCollected, mountID, isForDragonriding = C_MountJournal.GetMountInfoByID(mountID)
    if isCollected then
      local creatureDisplayInfoID, description, source, isSelfMount, mountTypeID, uiModelSceneID, animID, spellVisualKitID, disablePlayerMountPreview = C_MountJournal.GetMountInfoExtraByID(mountID)
      mounts(mountTypeID, mountID, name, isFactionSpecific, faction)
      any = true
    end
  end
  mounts.scanned = any
end

function f:ADDON_LOADED(event, addOnName)
  if addOnName == myAddonName then
    print(format("Hello %s! Mounts.lua loaded.", UnitName("player")))
    readMounts()
  end
end

function f:MOUNT_JOURNAL_USABILITY_CHANGED(event)
  readMounts()
end

SLASH_AU_MOUNT1 = "/aumount"

SlashCmdList["AU_MOUNT"] = function (message, editBox)
  readMounts()

  if IsIndoors() then return end

  -- print(format("IsAltKeyDown() = %s, IsShiftKeyDown() = %s", tostring(IsAltKeyDown()), tostring(IsShiftKeyDown())))
  if message == "info" then
    ns.print("Mounts info:")
    mounts:debug()
  elseif IsAltKeyDown() then
    mounts:random("ground")
  elseif IsShiftKeyDown() then
    ns.print("Dismount!", colours("dismount"))
    Dismount()
  elseif IsAdvancedFlyableArea() then
    mounts:random("advflying")
  else
    mounts:random("flying")
  end
end

f:RegisterEvent("ADDON_LOADED")
f:RegisterEvent("MOUNT_JOURNAL_USABILITY_CHANGED")
f:SetScript("OnEvent", f.OnEvent)
