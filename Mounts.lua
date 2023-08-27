local f = CreateFrame("Frame")

function f:OnEvent(event, ...)
	self[event](self, event, ...)
end

function f:ADDON_LOADED(event, addOnName)
  if addOnName == "AshranUtils" then
    print(format("Hello %s! Mounts.lua loaded.", UnitName("player")))
  end
end

SLASH_AU_MOUNT1 = "/aumount"

SlashCmdList["AU_MOUNT"] = function (message, _editBox)
  C_MountJournal.SummonByID(0)

  if true then return end

  for _, mountID in ipairs(C_MountJournal.GetMountIDs()) do
    local creatureName, spellID, icon, active, isUsable, sourceType, isFavorite, isFactionSpecific, faction, hideOnChar, isCollected = C_MountJournal.GetMountInfoByID(mountID)
    if isCollected then
      print(format("got mount %s", creatureName))
    end
  end
end

f:RegisterEvent("ADDON_LOADED")
f:SetScript("OnEvent", f.OnEvent)
