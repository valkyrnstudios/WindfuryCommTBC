local addonName, _ = ...

local GetAddOnMetadata = C_AddOns and C_AddOns.GetAddOnMetadata or _G.GetAddOnMetadata
local SendChatMessage = C_ChatInfo and C_ChatInfo.SendChatMessage or _G.SendChatMessage

wfc = CreateFrame("Frame", "WindfuryComm")

wfc.eventReg = wfc.eventReg or CreateFrame("Frame")
wfc.eventReg:RegisterEvent("PLAYER_ENTERING_WORLD")
wfc.eventReg:RegisterEvent("GROUP_ROSTER_UPDATE")
wfc.eventReg:RegisterEvent("CHAT_MSG_ADDON")
wfc.eventReg:RegisterEvent("ADDON_LOADED")
wfc.eventReg:RegisterEvent("ENCOUNTER_START")
wfc.eventReg:RegisterEvent("ENCOUNTER_END")
wfc.eventReg:RegisterEvent("CHAT_MSG_PARTY")
wfc.eventReg:RegisterEvent("CHAT_MSG_PARTY_LEADER")

wfc.partyVersion = {}
wfc.encounter = nil

wfc.version = GetAddOnMetadata(addonName, "Version")
if not wfc.version or string.match(wfc.version, 'project') then wfc.version = '1.0.0' end

-- "2.1.3" -> 20103
wfc.numericalVersion = tonumber(string.gsub(wfc.version, ".", "0"))

wfc.lib = LibStub("LibWFcomm")

local newVersionAlerted = false
local pClass = select(2, UnitClass("player"))
local isShaman = pClass == "SHAMAN"
local isMelee = pClass == "WARRIOR" or pClass == "ROGUE"

local CTL = _G.ChatThrottleLib
local COMM_PREFIX_VERSION = "WFC_VERSION"
local COMM_PREFIX_PING = "WFC_PING"
local COMM_PREFIX_PONG = "WFC_PONG"
C_ChatInfo.RegisterAddonMessagePrefix(COMM_PREFIX_VERSION)
C_ChatInfo.RegisterAddonMessagePrefix(COMM_PREFIX_PING)
C_ChatInfo.RegisterAddonMessagePrefix(COMM_PREFIX_PONG)

local function out(text, ...)
	print(" |cffff8800{|cffffbb00WFCTBC|cffff8800}|r "..text, ...)
end
wfc.out = out

local function debug(text, ...)
	if wfcdb.debug then
		out(text, ...)
	end
end
wfc.debug = debug

function wfc:GetFullName(unit)
	local name, realm = UnitFullName(unit)
	if realm and realm ~= "" then
		return name .. "-" .. realm
	else
		return name .. "-" .. (select(2, UnitFullName("player")) or "")
	end
end
local myFullName = wfc:GetFullName("player")

local wasInGroup = IsInGroup()
local function BroadcastVersionIfNeeded()
	local inGroup = IsInGroup()
	local joinedParty = inGroup and not wasInGroup
	if joinedParty and CTL then
		CTL:SendAddonMessage("BULK", COMM_PREFIX_VERSION, tostring(wfc.numericalVersion), 'RAID')
	end
	wasInGroup = inGroup
	return joinedParty
end

local function SendPing()
	CTL:SendAddonMessage("NORMAL", COMM_PREFIX_PING, tostring(wfc.numericalVersion), 'RAID')
end

local function SendPong(target)
	CTL:SendAddonMessage("NORMAL", COMM_PREFIX_PONG, tostring(wfc.numericalVersion), 'WHISPER', target)
end

function wfc:ShowUI(onload)
	wfcdbc.shown = true
	if isShaman then
		WFCShamanFrame:ShowUI()
	elseif isMelee and not onload then
		WFCMeleeFrame:ShowUI()
	end
end

function wfc:HideUI()
	wfcdbc.shown = false
	if isShaman then
		WFCShamanFrame:HideUI()
	elseif isMelee then
		WFCMeleeFrame:HideUI()
	end
	out("UI hidden, write |cffff8800/wfc show|r to show it again")
end

function wfc:InitSavedVariables()
	wfcdb = wfcdb or {
		version = wfc.numericalVersion,
		size = 37,
		space = 4,
		yspace = 0,
		xspace = 1,
	}
	wfcdbc = wfcdbc or {
		version = wfc.numericalVersion,
		shown = true,
	}
	if not wfcdb.version then wfcdb.version = wfc.numericalVersion end
	if not wfcdbc.version then wfcdbc.version = wfc.numericalVersion end
	if not wfcdbc.ignore then wfcdbc.ignore = {} end
	if wfcdb.autoRespondWFDropped == nil then wfcdb.autoRespondWFDropped = false end
end

function wfc:InitUI()
	if isShaman then
		WFCShamanFrame:Init() -- initiate frames early
	elseif isMelee then
		WFCMeleeFrame:Init()
	end
	if wfcdbc.shown == nil or wfcdbc.shown then
		self:ShowUI(true)
	else
		self:HideUI()
	end
end

function wfc:ADDON_LOADED()
	self.eventReg:UnregisterEvent("ADDON_LOADED")
	self:InitSavedVariables()
	self:InitUI()
	out("WindfuryComm++ v"..wfc.version.." loaded")
	if isShaman and not wfcdb.autoRespondWFDropped then
		if wfcdb.autoRespondWFInfo then
			out("|cffffbbff Tired of these silly WINDFURY MISSING!!!!! spam? SPAM'EM BACK! Write '/wfc nowf' to auto-whisper the spammer that you're aware of that.")
		else
			wfcdb.autoRespondWFInfo = true
			C_Timer.After(3, function()
				out("|cffffbbff Tired of these silly WINDFURY MISSING!!!!! spam? SPAM'EM BACK! Write '/wfc nowf' to auto-whisper the spammer that you're aware of that.")
			end)
		end
	end
end

function wfc:CHAT_MSG_ADDON(prefix, message, channel, sender)
	if prefix == COMM_PREFIX_PING then
		if (sender ~= myFullName) then
			SendPong(sender)
		end
	elseif prefix == COMM_PREFIX_PONG then
		out("PONG", "|cff3399dd"..sender.."|r", "|cffffff00"..message)
	elseif prefix == COMM_PREFIX_VERSION then
		local otherVersion = tonumber(message)
		if not newVersionAlerted and otherVersion and otherVersion > wfc.numericalVersion then
			newVersionAlerted = true
			out("|cff00bbffThere's a newer version of WindfuryComm++, please update.|r")
		end
	elseif isShaman then
		WFCShamanFrame:CHAT_MSG_ADDON(prefix, message, channel, sender)
	end
end

function wfc:ENCOUNTER_START(encounterId, encounterName)
	wfc.debug("ENCOUNTER_START", encounterId, encounterName)
	wfc.encounter = {
		id = encounterId,
		name = encounterName,
		start = GetTime(),
	}
end

function wfc:ENCOUNTER_END(encounterId)
	wfc.debug("ENCOUNTER_END", encounterId)
	if wfc.encounter then
		if encounterId == wfc.encounter.id then
			wfc.encounter.finish = GetTime()
		else
			wfc.encounter = nil
		end
	end
end

local wfMissingPatterns = {
	"wf dropped",
	"wf missing",
	"windfury dropped",
	"windfury missing",
	"windfury is missing",
	"no wf!",
	"no windfury"
}

local wfDroppedResponseCooldown = {}
function wfc:CHAT_MSG_PARTY(message, sender)
	if not isShaman or not wfcdb.autoRespondWFDropped or sender == myFullName then return end
	local messageLower = string.lower(message)

	local isWFMissingMessage = false
	for _, pattern in ipairs(wfMissingPatterns) do
		if string.find(messageLower, pattern, 1, true) then
			isWFMissingMessage = true
			break
		end
	end

	if isWFMissingMessage then
		local now = GetTime()
		if not wfDroppedResponseCooldown[sender] or now - wfDroppedResponseCooldown[sender] >= 1 then
			wfDroppedResponseCooldown[sender] = now
			SendChatMessage("I am aware of that, please disable this WA as I'm using WindfuryComm++ and see a big visible red square when you don't have WF.", "WHISPER", nil, sender)
		end
	end
end

local function WFCSlashCommands(entry)
	local arg1, arg2 = strsplit(" ", entry)
	if isShaman and arg1 == "orientation" and (arg2 == "horizontal" or arg2 == "vertical") then
		WFCShamanFrame:FlipLayout()
	elseif isShaman and arg1 == "spacing" and tonumber(arg2) then
		WFCShamanFrame:SetSpacing(arg2)
	elseif isShaman and arg1 == "size" and tonumber(arg2) then
		WFCShamanFrame:SetScale(arg2)
	elseif isShaman and arg1 == "warn" and tonumber(arg2) then
		WFCShamanFrame:SetWarnSize(arg2)
	elseif arg1 == "ping" then
		SendPing()
	elseif isMelee and arg1 == "reset" then
		WFCMeleeFrame:ResetStats()
	elseif arg1 == "resetpos" then
		if isShaman then
			WFCShamanFrame:ResetPos()
		elseif isMelee then
			WFCMeleeFrame:ResetPos()
		end
	elseif isShaman and arg1 == "print" then
		wfcdb.printCredit = not wfcdb.printCredit
		out("Totem uptime for party print is now " .. (wfcdb.printCredit and "|cff00ff00enabled" or "|cffff0000disabled|r"))
	elseif arg1 == "debug" then
		if arg2 == "status" then
			wfcdb.debugStatus = not wfcdb.debugStatus
			out("Debug print for WF_STATUS is now " .. (wfcdb.debugStatus and "|cff00ff00enabled|r" or "|cffff0000disabled|r"))
		else
			wfcdb.debug = not wfcdb.debug
			out("Debug print is now " .. (wfcdb.debug and "|cff00ff00enabled|r" or "|cffff0000disabled|r"))
		end
	elseif arg1 == "ignore" then
		-- insert target unit into wfcdb.ignore list
		local target = UnitFullName("target")
		if target then
			if not wfcdbc.ignore[target] then
				wfcdbc.ignore[target] = true
				out("Ignoring "..target)
			else
				wfcdbc.ignore[target] = nil
				out("No longer ignoring "..target)
			end
		else
			out("No target")
		end
	elseif arg1 == "ver" then
		out("Your version: "..wfc.version)
		out("Party versions: ")
		for k, v in pairs(wfc.partyVersion) do
			local name = GetUnitName(k)
			if name then
				out("  "..name .. ": " .. v)
			end
		end
	elseif arg1 == "nowf" then
		wfcdb.autoRespondWFDropped = not wfcdb.autoRespondWFDropped
		out("Auto-respond to WF dropped messages is now " .. (wfcdb.autoRespondWFDropped and "|cff00ff00enabled|r" or "|cffff0000disabled|r"))
	elseif arg1 == "show" then
		wfc:ShowUI()
	elseif arg1 == "lock" then
		wfcdbc.locked = not wfcdbc.locked
		out("Window is now " .. (wfcdbc.locked and "|cffff0000locked|r" or "|cff00ff00unlocked|r"))
	elseif arg1 == "hide" then
		wfc:HideUI()
	else
		out("|cffff8877WindfuryComm++ v"..wfc.version.." commands:")
		out("|cFF00FFaa/wfc <hide/show>|r show or hide UI ("..(wfcdbc.shown and "|cff00ff00shown|r" or "|cffff0000hidden|r")..")")
		if isMelee then
			out("|cFF00FFaa/wfc reset|r reset stats")
		end
		out("|cFF00FFaa/wfc resetpos|r reset window position")
		out("|cFF00FFaa/wfc lock|r toggle lock/unlock window position ("..(wfcdbc.locked and "|cffff0000locked|r" or "|cff00ff00unlocked|r")..")")
		out("|cFF00FFaa/wfc nowf|r toggle auto-respond to WF dropped messages ("..(wfcdb.autoRespondWFDropped and "|cff00ff00enabled|r" or "|cffff0000disabled|r")..")")
		if isShaman then
			out("|cFF00FFaa/wfc orientation <horizontal/vertical>|r layout of icons ("..(wfcdb.orientation == "horizontal" and "|cff00ff00horizontal|r" or "|cffff0000vertical|r")..")")
			out("|cFF00FFaa/wfc size <integer>|r set size of icons (|cff00bbff" .. wfcdb.size .. "|r)")
			out("|cFF00FFaa/wfc spacing <integer>|r set spacing between icons (|cff00bbff" .. wfcdb.space .. "|r)")
			out("|cFF00FFaa/wfc print|r toggle printing of party totem uptime (" .. tostring(wfcdb.printCredit and "|cff00ff00enabled|r" or "|cffff0000disabled|r") .. ")")
			out("|cFF00FFaa/wfc warn <integer>|r size of warning border (|cff00bbff" .. tostring(wfcdb.warnsize or 0) .. "|r)")
		end
	end
end

wfc.eventReg:SetScript("OnEvent", function(self, event, ...)
	if event == "ADDON_LOADED" then
		wfc:ADDON_LOADED(...)
	end
	if event == "GROUP_ROSTER_UPDATE" then
		local joinedParty = BroadcastVersionIfNeeded()
		if isShaman then
			WFCShamanFrame:GROUP_ROSTER_UPDATE(joinedParty)
		elseif isMelee then
			WFCMeleeFrame:GROUP_ROSTER_UPDATE(joinedParty)
		end
	elseif event == "PLAYER_ENTERING_WORLD" then
		if isShaman then
			WFCShamanFrame:GROUP_ROSTER_UPDATE(...)
		end
	elseif event == "CHAT_MSG_ADDON" then
		wfc:CHAT_MSG_ADDON(...)
	elseif event == "CHAT_MSG_PARTY" or event == "CHAT_MSG_PARTY_LEADER" then
		wfc:CHAT_MSG_PARTY(...)
	elseif event == "ENCOUNTER_START" then
		wfc:ENCOUNTER_START(...)
	elseif event == "ENCOUNTER_END" then
		wfc:ENCOUNTER_END(...)
	end
end)

SLASH_WFC1 = "/wfc"
SlashCmdList["WFC"] = WFCSlashCommands
