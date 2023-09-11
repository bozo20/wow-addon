local myAddonName, ns = ...

local f = CreateFrame("Frame")

function f:OnEvent(event, ...)
	self[event](self, event, ...)
end


local mountsMeta = {
  types = {
    -- (most) ground mounts 
    [230] = {},
    -- (most) flying mounts
    [248] = {}
  },
  lookup = {
    [230] = "ground",
    ["ground"] = 230,
    [248] = "flying",
    ["flying"] = 248
  },
  __index = {
    debug = function (self)
      local meta = getmetatable(self)
      
      for k, v in pairs(meta.types) do
        print(format("type %s: # = %d", meta.lookup[k], #v))
      end
    end,
    random = function (self, type)
      local meta = getmetatable(self)
      local mountTypeID = meta.lookup[type]

      local max = #meta.types[mountTypeID]
      local mountID, name
      local count = 0
      repeat
        local randomIndex = math.random(max)
        mountID, name = unpack(meta.types[mountTypeID][randomIndex])
        local name, spellID, icon, isActive, isUsable, sourceType, isFavorite, isFactionSpecific, faction, shouldHideOnChar, isCollected, mountID = C_MountJournal.GetMountInfoByID(mountID)
        count = count + 1
      until isUsable or count > max
      print(format("summoning %s (%s)", name, type))
      C_MountJournal.SummonByID(mountID)
    end
  },
  __call = function (self, mountTypeID, mountID, name)
    local meta = getmetatable(self)
    if not meta.types[mountTypeID] then return end

    table.insert(meta.types[mountTypeID], { mountID, name })
  end
}
local mounts = setmetatable({}, mountsMeta)

local function readMounts()
  for _, mountID in ipairs(C_MountJournal.GetMountIDs()) do
    local creatureName, spellID, icon, active, isUsable, sourceType, isFavorite, isFactionSpecific, faction, hideOnChar, isCollected = C_MountJournal.GetMountInfoByID(mountID)
    if isCollected then
      local creatureDisplayInfoID, description, source, isSelfMount, mountTypeID, uiModelSceneID, animID, spellVisualKitID, disablePlayerMountPreview = C_MountJournal.GetMountInfoExtraByID(mountID)
      mounts(mountTypeID, mountID, creatureName)
    end
  end
end

function f:ADDON_LOADED(event, addOnName)
  if addOnName == myAddonName then
    print(format("Hello %s! Mounts.lua loaded.", UnitName("player")))
    readMounts()
    mounts:debug()
  end
end

SLASH_AU_MOUNT1 = "/aumount"

SlashCmdList["AU_MOUNT"] = function (message, _editBox)
  if message == "info" then
    mounts:debug()
  else
    if UnitInBattleground("player") then
      mounts:random("ground")
    else
      mounts:random("flying")
    end
  end
end

f:RegisterEvent("ADDON_LOADED")
f:SetScript("OnEvent", f.OnEvent)
