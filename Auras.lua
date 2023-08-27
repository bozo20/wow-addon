local f = CreateFrame("Frame")

f.active = true

function f:OnEvent(event, ...)
  if not f.active then return end

	self[event](self, event, ...)
end

function f:ADDON_LOADED(event, addOnName)
  if addOnName == "AshranUtils" then
    print(format("Hello %s! Auras.lua loaded.", UnitName("player")))
  end
end

local function makeBuff(track, name, channel, banner, itemID)
  return { track = track, name = name, channel = channel or "SAY", banner = banner or false, itemID = itemID }
end

local buffs = { --[383648] = makeBuff(false, "Erdschild"),
                [274834] = makeBuff(false, "phalanx", nil, true),
                [28418] = makeBuff(true, "General's Warcry 10 %", nil, true),
                [28419] = makeBuff(true, "General's Warcry 20 %", nil, true),
                [28420] = makeBuff(true, "General's Warcry 30 %", nil, true),
                [171250] = makeBuff(true, "scroll of speed", nil, false, 116410),
                [388035] = makeBuff(false, "Fortitude of the Bear"),
                [171249] = makeBuff(true, "prot", "INSTANCE_CHAT", false, 116411),
                [357650] = makeBuff(false, "mini BL"),
                [157504] = makeBuff(false, "cloudburst totem"),
                --[197916] = { false, "Lebenszyklus (Beleben)" },
                --[197919] = { false, "Lebenszyklus (Einhüllender Nebel)" },
                --[164273] = makeBuff(false, "Einsamer Wolf"),
                --[2645] = { false, "Geisterwolf" },
                [61295] = makeBuff(false, "Springflut", nil, false, 116411)
}
local function makeOnceExpiration(id, after)
  local expiration = { expires = expires, type = "once" }
  local function callback()
    local aura = C_UnitAuras.GetPlayerAuraBySpellID(id)
    if not aura then return end

    local message = format("%s in %d seconds!", aura.name, aura.duration - after)
    RaidNotice_AddMessage(RaidWarningFrame, message, ChatTypeInfo["RAID_WARNING"])
    PlaySound(8959)
  end
  expiration.makeCallback = function ()
    C_Timer.After(after, callback)
  end

  return expiration
end

local function makeRepeatingExpiration(id, after, announce)
  local expiration = { expires = expires, type = "countdown" }
  local function callback()
    local aura = C_UnitAuras.GetPlayerAuraBySpellID(id)
    if not aura then return end

    local seconds = aura.expirationTime - GetTime()
    local message = format("%s for %d more seconds", GetSpellLink(id), seconds)
    if announce and UnitInBattleground("player") then
      SendChatMessage(message, "SAY")
    end
    print(message)
    expiration.makeCallback()
  end
  expiration.makeCallback = function ()
    C_Timer.After(after, callback)
  end

  return expiration
end

local expirations = {
  -- cloudburst
  [157504] = makeOnceExpiration(157504, 10),
  -- Springflut
  [61295] = makeRepeatingExpiration(61295, 6),
  -- prot
  [171249] = makeRepeatingExpiration(171249, 5, true),
  -- speed
  [171250] = makeRepeatingExpiration(171250, 5, true)
}
local aurasMeta = {
  __index = function (self, auraInstanceID)
    return self.store[auraInstanceID]
  end,
  __newindex = function (self, auraInstanceID, pair)
    self.store[auraInstanceID] = self.store[auraInstanceID] or {}
    table.insert(self.store[auraInstanceID], pair)
  end,
  __call = function (self, auraInstanceID)
    return table.remove(self.store[auraInstanceID], 1)
  end
}
local auras = setmetatable({ store = {}, debug = false }, aurasMeta)

-- /auaura
SLASH_AU_AURA1 = "/auau"

SlashCmdList["AU_AURA"] = function (message, _editBox)
  if message == "off" then
    f.active = false
  elseif message == "on" then
    f.active = true
  end
  print(format("Aura tracking active? %s", tostring(f.active)))
end

local function debugAura(unitTarget, auraData)
  print(format("LOCAL: %s start, target = %s, source = %s, spellId = %s, auraInstanceID = %s", auraData.name, UnitName(unitTarget), auraData.sourceUnit, auraData.spellId, auraData.auraInstanceID))
end

function f:UNIT_AURA(event, unitTarget, updateInfo)
  if not updateInfo then return end
  if updateInfo.isFullUpdate then return end

  if updateInfo.addedAuras and next(updateInfo.addedAuras) then
    for _, auraData in ipairs(updateInfo.addedAuras) do
      if auras.debug then debugAura(unitTarget, auraData) end

      local buff = buffs[auraData.spellId]
      if buff then
        --debugAura(unitTarget, auraData)
        local source = UnitName(auraData.sourceUnit)
        if buff.banner then source = 'banner' end
        auras[auraData.auraInstanceID] = { source, buff }

        local message = format("%s used %s", source, buff.name)
        if buff.track and UnitInBattleground("player") then
          local message = format("{rt4} %s", message)
          if buff.itemID then
            message = format("%s (%s)", message, (select(2, GetItemInfo(buff.itemID))))
          end

          if unitTarget == "player" then
            SendChatMessage(message, buff.channel)
          else
            local message = format("%s %s", message, unitTarget)
            SendChatMessage(message, "SAY")
          end
        end

        print(format("LOCAL: %s, track? %s", message, tostring(buff.track)))
      end

      local expiration = expirations[auraData.spellId]
      if expiration then
        expiration.makeCallback()
      end
    end
  elseif updateInfo.updatedAuraInstanceIDs and next(updateInfo.updatedAuraInstanceIDs) then
    for _, auraInstanceID in ipairs(updateInfo.updatedAuraInstanceIDs) do
      
    end
  elseif updateInfo.removedAuraInstanceIDs and next(updateInfo.removedAuraInstanceIDs) then
    for _, auraInstanceID in ipairs(updateInfo.removedAuraInstanceIDs) do
      if auras[auraInstanceID] then
        -- using __call
        local source, buff = unpack(auras(auraInstanceID))
        if not source or not buff then return end

        if buff.track and not buff.banner and UnitInBattleground("player") then
          -- "PARTY", "INSTANCE_CHAT", "SAY"
          SendChatMessage(format("{rt7} %s expired", buff.name), buff.channel)
        end
        print(format("LOCAL: %s by %s expired", buff.name, source))
      end
    end
  end
end

f:RegisterEvent("ADDON_LOADED")
--f:RegisterEvent("UNIT_AURA")
f:RegisterUnitEvent("UNIT_AURA", "player", "Simeoa-TwistingNether")
f:SetScript("OnEvent", f.OnEvent)
