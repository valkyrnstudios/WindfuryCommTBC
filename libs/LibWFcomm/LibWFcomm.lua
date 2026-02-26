assert(LibStub, "WindfuryComm requires LibStub")

local major, minor = "LibWFcomm", 4
local LibWFcomm = LibStub:NewLibrary(major, minor)
local CTL = _G.ChatThrottleLib
local COMM_PREFIX = "WF_STATUS"
local COMM_PREFIX_CREDIT = "WF_CREDIT"
local WF_ENCHANTS = { [2639] = 'WF5', [2638] = 'WF4', [564] = 'WF3', [563] = 'WF2', [1783] = 'WF1' }
local TRACKED_AURAS = {
    [25362] = "STR",
    [10441] = "STR",
    [8163] = "STR",
    [8162] = "STR",
    [8076] = "STR",
    [25360] = "AGI",
    [10626] = "AGI",
    [8836] = "AGI",
    [10535] = "FR",
    [10534] = "FR",
    [8185] = "FR",
    [10477] = "FrR",
    [10476] = "FrR",
    [8182] = "FrR",
    [8178] = "GND",
}
local TRACKED_AURA_NAMES = {
    ["STR"] = "Strength",
    ["AGI"] = "Agility",
    ["FR"] = "Fire Resistance",
    ["FrR"] = "Frost Resistance",
    ["GND"] = "Grounding Totem",
}
local TRACKED_AURAS_LIST = { "WF", "STR", "AGI", "FR", "FrR", "GND" }
local PERIODIC_UPDATE_SECONDS = 1

C_ChatInfo.RegisterAddonMessagePrefix(COMM_PREFIX)
C_ChatInfo.RegisterAddonMessagePrefix(COMM_PREFIX_CREDIT)

pGUID = UnitGUID("player")
pClass = select(2, UnitClass("player"))

local lastExpiration
local hasRefreshed = false
local myShaman
local cs = {
    ["start"] = {
        ["combat"] = nil,
        ["WF"] = nil,
    },
    ["time"] = {
        ["WF"] = 0,
    },
}
LibWFCombatStats = cs
local selfName = UnitName("player")
local periodicUpdate = GetTime()

local function ReportUptime(sendAddonMsg)
    for _, spellCategory in ipairs(TRACKED_AURAS_LIST) do
        if cs.start[spellCategory] then
            cs.time[spellCategory] = (cs.time[spellCategory] or 0) + (GetTime() - cs.start[spellCategory])
            cs.start[spellCategory] = GetTime()
        end
    end

    local type = 'LIVE'
    local combatTime = math.floor(GetTime() - cs.start.combat + 0.5)
    if myShaman and combatTime > 1 then
        -- report uptime
        local wfTime = math.min(math.floor((cs.time.WF or 0) + 0.5), combatTime)
        local strTime = math.min(math.floor((cs.time.STR or 0) + 0.5), combatTime)
        local agiTime = math.min(math.floor((cs.time.AGI or 0) + 0.5), combatTime)
        local frTime = math.min(math.floor((cs.time.FR or 0) + 0.5), combatTime)
        local frrTime = math.min(math.floor((cs.time.FrR or 0) + 0.5), combatTime)
        local gndTime = math.min(math.floor((cs.time.GND or 0) + 0.5), combatTime)
        if sendAddonMsg then
            local creditmsg = format("%d:%d:%s:%d:%d:%d:%d:%d", combatTime, wfTime, myShaman, strTime, agiTime, frTime, frrTime, gndTime)
            CTL:SendAddonMessage("BULK", COMM_PREFIX_CREDIT, creditmsg, 'RAID')
            type = 'FINAL'
        end
        if LibWFcomm and LibWFcomm.UptimeReportHook then
            LibWFcomm.UptimeReportHook(combatTime, wfTime, myShaman, strTime, agiTime, frTime, frrTime, gndTime, selfName, type)
        end
    end
end

local function CheckCombatStartOrEnd(combat)
    if not cs.start.combat and combat then
        -- combat started
        cs.start = {}
        cs.start.combat = GetTime()
        cs.time = {}
        cs.time.WF = 0
        periodicUpdate = GetTime()
    elseif cs.start.combat and not combat then
        -- combat ended
        ReportUptime(true)
        cs.start = {}
    end
end

local function CheckCombatWfStart(enchid)
    local spellName = WF_ENCHANTS[enchid]
    if spellName then
        if cs.start.combat and not cs.start.WF then
            -- combat started with wf, take time
            cs.start.WF = GetTime()
        end
    end
end

local function CheckCombatWfDrop()
    if cs.start.combat and cs.start.WF then
        cs.time.WF = (cs.time.WF or 0) + (GetTime() - cs.start.WF)
        -- wf dropped in combat, sum uptime
        cs.start.WF = nil
    end
end

local function WindfuryDurationCheck(forceBroadcast)
    local msg
    local _, _, lagHome, _ = GetNetStats()
    local mh, expiration, _, enchid, _, _, _, _ = GetWeaponEnchantInfo("player")
    local combat = InCombatLockdown() and "1" or "0"
    local isdead = UnitIsDeadOrGhost("player") and "1" or "0"

    CheckCombatStartOrEnd(combat == "1");

    if mh then
        -- report wf expiration time
        msg = format("%s:%d:%d:%d:%s:%s:%d", pGUID, enchid, expiration, lagHome, combat, isdead, minor)
        CheckCombatWfStart(enchid)
        if lastExpiration == nil or expiration > lastExpiration then
            hasRefreshed = true
        end
    else
        -- report expired wf
        msg = format("%s:nil:nil:%s:%s:%s:%d", pGUID, lagHome, combat, isdead, minor)
        CheckCombatWfDrop()
    end
    lastExpiration = expiration

    if CTL and msg and (lastStatus ~= mh or hasRefreshed or forceBroadcast) then
        CTL:SendAddonMessage("NORMAL", COMM_PREFIX, msg, 'PARTY')
        lastStatus = mh
    end
end

local function AuraPresenceCheck()
    -- check for presence of totem auras
    if cs.start.combat then
        local seenAuras = {}
        for i = 1, 40 do
            local name, _, _, _, _, _, _, _, _, spellId = UnitBuff("player", i)
            if not name then break end

            local spellCategory = TRACKED_AURAS[spellId]
            if spellCategory then
                seenAuras[spellCategory] = true
                if not cs.start[spellCategory] then
                    cs.start[spellCategory] = GetTime()
                end
            end
        end
        -- remove missing auras from combatStats.start
        for spellCategory, _ in pairs(TRACKED_AURA_NAMES) do
            if cs.start[spellCategory] and not seenAuras[spellCategory] then
                cs.time[spellCategory] = (cs.time[spellCategory] or 0) + (GetTime() - cs.start[spellCategory])
                cs.start[spellCategory] = nil
            end
        end
    end
end

local function CheckForShaman()
    myShaman = nil
    for index = 1, 4 do
        local pstring = "party" .. index
        local gclass = select(2, UnitClass(pstring))
        if (gclass == "SHAMAN") then
            myShaman = UnitName(pstring)
        end
    end
    return myShaman
end

function LibWFcomm:PLAYER_LOGIN()
    self.eventReg:RegisterEvent("GROUP_ROSTER_UPDATE")
    self.eventReg:RegisterEvent("PARTY_MEMBER_ENABLE")
    self:GROUP_ROSTER_UPDATE()
end

function LibWFcomm:PARTY_MEMBER_ENABLE(unitId)
    if (select(2, UnitClass(unitId)) == "SHAMAN") then
        self:GROUP_ROSTER_UPDATE()
    end
end

function LibWFcomm:GROUP_ROSTER_UPDATE()
    if (GetNumGroupMembers() ~= 0 and CheckForShaman()) then
        LibWFcomm.eventReg:RegisterUnitEvent("UNIT_INVENTORY_CHANGED", "player")
        LibWFcomm.eventReg:RegisterEvent("PLAYER_REGEN_DISABLED")
        LibWFcomm.eventReg:RegisterEvent("PLAYER_REGEN_ENABLED")
        LibWFcomm.eventReg:RegisterEvent("PLAYER_DEAD")
        LibWFcomm.eventReg:RegisterEvent("PLAYER_ALIVE")
        LibWFcomm.eventReg:RegisterEvent("UNIT_AURA")
        C_Timer.After(0.3, function()
            WindfuryDurationCheck(true)
        end)
    else
        LibWFcomm.eventReg:UnregisterEvent("UNIT_INVENTORY_CHANGED")
        LibWFcomm.eventReg:UnregisterEvent("PLAYER_REGEN_DISABLED")
        LibWFcomm.eventReg:UnregisterEvent("PLAYER_REGEN_ENABLED")
        LibWFcomm.eventReg:UnregisterEvent("PLAYER_DEAD")
        LibWFcomm.eventReg:UnregisterEvent("PLAYER_ALIVE")
        LibWFcomm.eventReg:UnregisterEvent("UNIT_AURA")
    end
end

function LibWFcomm:UNIT_INVENTORY_CHANGED()
    -- This event fires when:
    -- • You equip or unequip an item.
    -- • An item in your equipment slots is changed or swapped.
    -- • Your durability changes, which may affect certain gear-dependent stats.
    -- • A transmog change is applied (in some cases).
    -- • A trinket or weapon with charges has a state change.
    C_Timer.After(0.15, function()
        WindfuryDurationCheck()
    end)
end

function LibWFcomm:PLAYER_REGEN_DISABLED()
    C_Timer.After(0.15, function()
        WindfuryDurationCheck()
        AuraPresenceCheck()
    end)
end

function LibWFcomm:PLAYER_REGEN_ENABLED()
    C_Timer.After(0.15, function()
        WindfuryDurationCheck()
    end)
end

function LibWFcomm:PLAYER_DEAD()
    C_Timer.After(0.15, function()
        WindfuryDurationCheck()
    end)
end

function LibWFcomm:PLAYER_ALIVE()
    C_Timer.After(0.15, function()
        WindfuryDurationCheck()
    end)
end

function LibWFcomm:UNIT_AURA()
    C_Timer.After(0.15, function()
        AuraPresenceCheck()
    end)
end

local function OnEvent(self, event, ...)
    LibWFcomm[event](LibWFcomm, ...)
end

local function OnUpdate(self)
    if cs.start.combat and GetTime() - periodicUpdate > PERIODIC_UPDATE_SECONDS then
        periodicUpdate = GetTime()
        ReportUptime()
    end
end

if (pClass == "WARRIOR" or pClass == "ROGUE" or pClass == "PALADIN" or pClass == "HUNTER") then
    LibWFcomm.eventReg = LibWFcomm.eventReg or CreateFrame("Frame")
    LibWFcomm.eventReg:SetScript("OnEvent", OnEvent)
    LibWFcomm.eventReg:SetScript("OnUpdate", OnUpdate)
    if (not IsLoggedIn()) then
        LibWFcomm.eventReg:RegisterEvent("PLAYER_LOGIN")
    else
        LibWFcomm:PLAYER_LOGIN()
    end
end
