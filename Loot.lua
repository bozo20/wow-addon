local myAddonName, ns = ...

local f = CreateFrame("Frame")

function f:OnEvent(event, ...)
	ns.wrap(self[event], self, event, ...)
end

function f:ADDON_LOADED(event, addOnName)
  if addOnName == myAddonName then
    print(format("Hello %s! Loot.lua loaded.", UnitName("player")))
  end
end

local loot = {}
do
  -- name of item as it would appear in CHAT_MSG_LOOT = internal identifier
  local items = { ["Rolle des Schutzes"] = "prot",
                  ["Zauberstab der arkanen Gefangenschaft"] = "prison",
                  ["Frostwyrmei"] = "egg",
                  ["Nesingwarys verlorenes Horn"] = "horn",
                  ["Beschwörungsschriftrolle für Yu'lon, die Jadeschlange"] = "yulon" }
  -- debug
  items["Wolliger Bergpelz"] = "Bergpelz"
  items["gespaltener Huf"] = "Huf"
  items["Bestienauge"] = "Bestienauge"

  local byId = {}

  -- DevTools_Dump(data)
  local lootMeta = {
    __index = {
      reset = function (self)
        for k, v in pairs(self) do self[k] = nil end
        for k, v in pairs(byId) do byId[k] = nil end
      end,
      debug = function (self, onlyById)
        onlyById = onlyById or false

        if not onlyById then
          ns.print("loot:")
          for playerName, data in pairs(self) do
            ns.print(format("%s looted:", playerName))
            for id, amount in pairs(data) do
              ns.print(format("  %d %s", amount, id))
            end
          end
        end

        ns.print("byId:")
        for id, playerNames in pairs(byId) do
          ns.print(format("%s looted by:", id))
          local total = 0
          for playerName, amount in pairs(playerNames) do
            ns.print(format("  %s got %d", playerName, amount))
            total = total + amount
          end
          ns.print(format("  %d total", total))
        end
      end
    },
    __call = function (self, text, playerName)
      for name, id in pairs(items) do
        if string.find(text, name) then
          local m = text:match("x(%d)") or 1
          local amount = tonumber(m, 10)
          self[{ playerName, id }] = amount

          byId[id] = byId[id] or {}
          byId[id][playerName] = (byId[id][playerName] or 0) + amount

          break
        end
      end
    end,
    __newindex = function (self, playerNameAndId, amount)
      local playerName, id = unpack(playerNameAndId)
      local data = rawget(self, playerName) or {}
      data[id] = (data[id] or 0) + amount
      rawset(self, playerName, data)
    end
  }

  setmetatable(loot, lootMeta)
end

function f:CHAT_MSG_LOOT(event, text, playerName, languageName, channelName, playerName2, specialFlags, zoneChannelID, channelIndex, channelBaseName, languageID, lineID, guid, bnSenderID, isMobile, isSubtitle, hideSenderInLetterbox, supressRaidIcons)
  if UnitInBattleground("player") then
    -- loot(text, playerName)
  end
  loot(text, playerName)
end

-- /auloot = show whole store
-- /auloot on = 
-- /auloot off = off
-- /auloot ids = show all tracked ids
-- /auloot $id = show who looted $id
SLASH_AU_LOOT1 = "/auloot"

SlashCmdList["AU_LOOT"] = function (message, _editBox)
  ns.wrap(function ()
    if message == "" then
      ns.print("Loot debug")
      loot:debug()
    elseif message == "id" then
      loot:debug(true)
    elseif message == "reset" then
      ns.print("Loot reset")
      loot:reset()
    end
  end)
end



f:RegisterEvent("ADDON_LOADED")
f:RegisterEvent("CHAT_MSG_LOOT")
f:SetScript("OnEvent", f.OnEvent)
