--[[
	Core.lua

	Saved variables, the buff/weapon-enchant detection engine, the ready
	check hook, and slash commands. UI.lua and Display.lua build on top of
	the functions defined here.
]]

AreYouBuffed = AreYouBuffed or {}
local AYB = AreYouBuffed

--------------------------------------------------------------------------
-- Saved variable defaults
--------------------------------------------------------------------------

local DB_DEFAULTS = {
	sound = true,
	autoDeclineReadyCheck = true,
	lockDisplay = false,
	displayPoint = { point = "CENTER", relPoint = "CENTER", x = 0, y = 220 },
}

local CHAR_DB_DEFAULTS = {
	tracked = {},
}

local function CopyDefaults(defaults, target)
	for key, value in pairs(defaults) do
		if target[key] == nil then
			if type(value) == "table" then
				target[key] = CopyDefaults(value, {})
			else
				target[key] = value
			end
		elseif type(value) == "table" and type(target[key]) == "table" then
			CopyDefaults(value, target[key])
		end
	end
	return target
end

--------------------------------------------------------------------------
-- Spell resolution (works across API versions, and needs no network access -
-- the client already ships the name/icon for every real spell ID)
--------------------------------------------------------------------------

function AYB:ResolveSpell(id)
	if C_Spell and C_Spell.GetSpellInfo then
		local info = C_Spell.GetSpellInfo(id)
		if info and info.name then
			return info.name, info.iconID
		end
	end
	if GetSpellInfo then
		local name, _, icon = GetSpellInfo(id)
		if name then
			return name, icon
		end
	end
	return nil, nil
end

-- Checks every id in every database group against the client's own spell
-- data and remembers which groups didn't resolve, so the UI can flag them
-- instead of silently tracking a buff that can never match.
--
-- weaponEnchant groups are skipped here: their `ids` are weapon-enchant ids
-- (what GetWeaponEnchantInfo returns), a completely different id space from
-- spells - the client's spell API has no way to resolve or verify them, so
-- treating them as spell ids would just produce a wrong/misleading result.
-- The only thing worth flagging for those is "nobody ever filled in an id at
-- all" (see the weapon_enchants comment in Database.lua for known gaps).
function AYB:ValidateDatabase()
	self.validation = {}
	for _, category in ipairs(self.Database.categories) do
		for _, group in ipairs(category.groups) do
			if group.type == "weaponEnchant" then
				self.validation[group.name] = { ok = #group.ids > 0, resolvedNames = {} }
			else
				local resolved = {}
				for _, id in ipairs(group.ids) do
					local name = self:ResolveSpell(id)
					if name then
						table.insert(resolved, name)
					end
				end
				self.validation[group.name] = {
					ok = #resolved > 0,
					resolvedNames = resolved,
				}
			end
		end
	end
end

--------------------------------------------------------------------------
-- Buff / weapon enchant detection
--------------------------------------------------------------------------

local function GetPlayerBuffAt(index)
	if C_UnitAuras and C_UnitAuras.GetBuffDataByIndex then
		local aura = C_UnitAuras.GetBuffDataByIndex("player", index)
		if not aura then
			return nil
		end
		return aura.spellId, aura.icon, aura.expirationTime, aura.name
	elseif UnitBuff then
		local name, icon, _, _, _, expirationTime, _, _, _, spellId = UnitBuff("player", index)
		if not name then
			return nil
		end
		return spellId, icon, expirationTime, name
	end
	return nil
end

local function NameMatchesAny(name, patterns)
	if not name or not patterns then
		return false
	end
	local lowered = name:lower()
	for _, pattern in ipairs(patterns) do
		if lowered:find(pattern:lower(), 1, true) then
			return true
		end
	end
	return false
end

-- Ranks, "Greater" versions, and quiet Anniversary-realm duplicate spell ids
-- all keep the same displayed buff name (a "Greater Blessing of Kings" aura
-- literally contains the text "Blessing of Kings"), so matching by name is
-- far more durable than trying to enumerate every id variant ourselves. We
-- still honor an explicit `ids` list too (belt and suspenders, and it keeps
-- older saved tracked-entries working), but name matching is what actually
-- catches variants we never hardcoded.
function AYB:ResolveMatchPatterns(entry)
	if entry.match then
		return entry.match
	end
	local group = self:FindGroupByName(entry.name)
	if group and group.match then
		return group.match
	end
	return { entry.name }
end

function AYB:IsAuraActive(entry)
	local patterns = self:ResolveMatchPatterns(entry)
	local wantedIds = nil
	if entry.ids then
		wantedIds = {}
		for _, id in ipairs(entry.ids) do
			wantedIds[id] = true
		end
	end
	for index = 1, 60 do
		local spellId, icon, expirationTime, name = GetPlayerBuffAt(index)
		if not spellId and not name then
			break
		end
		if (wantedIds and spellId and wantedIds[spellId]) or NameMatchesAny(name, patterns) then
			return true, icon, expirationTime
		end
	end
	return false
end

-- Temporary weapon buffs (oils, stones, shaman weapon imbues) are NOT
-- regular auras - they only show up through GetWeaponEnchantInfo. On some
-- Classic client builds that API doesn't expose *which* enchant is applied,
-- only *that* one is - in that case we report "unknown" rather than a false
-- "missing" or a false "active".
function AYB:GetWeaponEnchant(slot)
	local hasMH, mhExpiration, _, mhEnchantID, hasOH, ohExpiration, _, ohEnchantID = GetWeaponEnchantInfo()
	if slot == "off" then
		return hasOH, ohEnchantID, ohExpiration
	end
	return hasMH, mhEnchantID, mhExpiration
end

-- Checks a single weapon slot ("main" or "off") against entry.ids, which for
-- weaponEnchant entries are weapon-enchant ids, NOT spell ids - the two live
-- in entirely separate id spaces (GetWeaponEnchantInfo's enchantID has no
-- relationship to any castable spell), so there is no name-based fallback
-- here the way IsAuraActive has for auras: an id match is the only thing
-- that can ever confirm a weapon enchant.
function AYB:CheckWeaponSlot(entry, slot)
	local has, enchantID, expiration = self:GetWeaponEnchant(slot)
	if not has then
		return "missing"
	end
	if not enchantID then
		-- client doesn't expose which enchant id is applied on this build;
		-- all we know is *something* is on, which might or might not be right.
		return "unknown", nil, expiration
	end
	if entry.ids then
		for _, id in ipairs(entry.ids) do
			if id == enchantID then
				return "active", nil, expiration
			end
		end
	end
	-- the client told us exactly which enchant is applied and it wasn't one
	-- of ours - a definite mismatch, which matters just as much as nothing
	-- being on the weapon at all.
	return "missing"
end

function AYB:CheckEntry(entry)
	if entry.type == "weaponEnchant" then
		if entry.slot == "both" then
			local mainStatus = self:CheckWeaponSlot(entry, "main")
			local offStatus = self:CheckWeaponSlot(entry, "off")
			if mainStatus == "active" and offStatus == "active" then
				return "active"
			end
			if mainStatus == "missing" or offStatus == "missing" then
				return "missing"
			end
			return "unknown"
		end
		return self:CheckWeaponSlot(entry, entry.slot or "main")
	end

	local active, icon, expiration = self:IsAuraActive(entry)
	if active then
		return "active", icon, expiration
	end
	return "missing"
end

function AYB:GetTrackedStatus()
	local results = {}
	for _, entry in ipairs(AreYouBuffedCharDB.tracked) do
		local status, icon, expiration = self:CheckEntry(entry)
		table.insert(results, { entry = entry, status = status, icon = icon, expiration = expiration })
	end
	return results
end

-- "unknown" (weapon enchant present but unidentified) deliberately does NOT
-- count as missing - we'd rather stay quiet than falsely tell you to reapply
-- a buff you already have on.
function AYB:GetMissingRequired()
	local missing = {}
	for _, result in ipairs(self:GetTrackedStatus()) do
		if result.entry.required and result.status == "missing" then
			table.insert(missing, result.entry)
		end
	end
	return missing
end

--------------------------------------------------------------------------
-- Tracked-list management
--------------------------------------------------------------------------

function AYB:IsTracked(name)
	for index, entry in ipairs(AreYouBuffedCharDB.tracked) do
		if entry.name == name then
			return index, entry
		end
	end
	return nil
end

function AYB:AddTracked(group, required)
	if self:IsTracked(group.name) then
		return
	end
	table.insert(AreYouBuffedCharDB.tracked, {
		name = group.name,
		ids = group.ids,
		match = group.match,
		type = group.type or "aura",
		slot = group.slot,
		required = required ~= false,
	})
	self:Refresh()
end

function AYB:RemoveTracked(name)
	local index = self:IsTracked(name)
	if index then
		table.remove(AreYouBuffedCharDB.tracked, index)
		self:Refresh()
	end
end

function AYB:SetRequired(name, required)
	local _, entry = self:IsTracked(name)
	if entry then
		entry.required = required
		self:Refresh()
	end
end

-- slot: "main", "off", or "both" (dual-wielders imbuing/oiling both weapons
-- with the same enchant - see AYB:CheckEntry). Only meaningful for
-- type == "weaponEnchant" entries.
function AYB:SetSlot(name, slot)
	local _, entry = self:IsTracked(name)
	if entry then
		entry.slot = slot
		self:Refresh()
	end
end

-- customName is only used (and required) for weapon enchants: their id is a
-- weapon-enchant id, not a spell id (see Database.lua's file header), so the
-- client has no way to look up a display name for it the way it can for a
-- regular spell id.
function AYB:AddCustom(idText, requiredFlag, isWeaponEnchant, slot, customName)
	local id = tonumber(idText)
	if not id then
		print("|cffff4444AreYouBuffed:|r that doesn't look like a numeric ID.")
		return false
	end

	local name
	if isWeaponEnchant then
		name = strtrim(customName or "")
		if name == "" then
			print("|cffff4444AreYouBuffed:|r weapon enchants need a name too - the client can't look one up from a weapon-enchant id.")
			return false
		end
	else
		name = self:ResolveSpell(id)
		if not name then
			print("|cffff4444AreYouBuffed:|r spell ID " .. id .. " isn't recognized by your client - double check it on Wowhead.")
			return false
		end
	end

	if self:IsTracked(name) then
		print("|cffffcc00AreYouBuffed:|r " .. name .. " is already tracked.")
		return false
	end
	table.insert(AreYouBuffedCharDB.tracked, {
		name = name,
		ids = { id },
		type = isWeaponEnchant and "weaponEnchant" or "aura",
		slot = slot,
		required = requiredFlag ~= false,
		custom = true,
	})
	self:Refresh()
	print("|cff33ff99AreYouBuffed:|r now tracking " .. name .. ".")
	return true
end

function AYB:LoadClassDefaults()
	local classToken = select(2, UnitClass("player"))
	local defaults = self.Database.classDefaults[classToken]
	if not defaults then
		return
	end
	for _, groupName in ipairs(defaults) do
		local group = self:FindGroupByName(groupName)
		if group then
			self:AddTracked(group, true)
		end
	end
end

--------------------------------------------------------------------------
-- Refresh / display glue
--------------------------------------------------------------------------

local pendingRefresh = false

function AYB:RequestRefresh()
	if pendingRefresh then
		return
	end
	pendingRefresh = true
	C_Timer.After(0.2, function()
		pendingRefresh = false
		AYB:Refresh()
	end)
end

function AYB:Refresh()
	local results = self:GetTrackedStatus()
	if self.Display and self.Display.Update then
		self.Display:Update(results)
	end
	if self.UI and self.UI.RefreshIfShown then
		self.UI:RefreshIfShown()
	end
	return results
end

--------------------------------------------------------------------------
-- Ready check hook - this is the whole point: don't let the raid ready up
-- while you're missing something you marked as required.
--------------------------------------------------------------------------

-- Shared alarm: chat warning + sound. Used by both the automatic ready-check
-- hook and a manual /buffed scan.
function AYB:AnnounceMissing(missing)
	local names = {}
	for _, entry in ipairs(missing) do
		table.insert(names, entry.name)
	end
	local list = table.concat(names, ", ")

	DEFAULT_CHAT_FRAME:AddMessage("|cffff4444[AreYouBuffed]|r Not ready - missing: " .. list)

	if AreYouBuffedDB.sound then
		local soundKit = SOUNDKIT and SOUNDKIT.RAID_WARNING or 8959
		PlaySound(soundKit, "Master")
	end
end

function AYB:OnReadyCheck()
	local missing = self:GetMissingRequired()
	if #missing == 0 then
		return
	end
	if AreYouBuffedDB.autoDeclineReadyCheck then
		ConfirmReadyCheck(false)
	end
	self:AnnounceMissing(missing)
end

-- The /buffed command: re-scans every tracked buff, recalculates what's
-- missing, and fires the same alarm a failed ready check would - on demand,
-- with no ready check required.
function AYB:RunBuffCheck()
	local results = self:Refresh()
	if self.Display and self.Display.Trigger then
		self.Display:Trigger(results)
	end

	local missing = self:GetMissingRequired()
	if #missing == 0 then
		print("|cff33ff99AreYouBuffed:|r all required buffs are active. You're good to go.")
		return true
	end
	self:AnnounceMissing(missing)
	return false
end

--------------------------------------------------------------------------
-- Events
--------------------------------------------------------------------------

local frame = CreateFrame("Frame")
AYB.eventFrame = frame

frame:RegisterEvent("ADDON_LOADED")
frame:RegisterEvent("PLAYER_LOGIN")
frame:RegisterEvent("READY_CHECK")
frame:RegisterEvent("UNIT_AURA")

frame:SetScript("OnEvent", function(_, event, ...)
	if event == "ADDON_LOADED" then
		local loadedAddon = ...
		if loadedAddon == "AreYouBuffed" then
			AreYouBuffedDB = CopyDefaults(DB_DEFAULTS, AreYouBuffedDB or {})
			AreYouBuffedCharDB = CopyDefaults(CHAR_DB_DEFAULTS, AreYouBuffedCharDB or {})
			frame:UnregisterEvent("ADDON_LOADED")
		end
	elseif event == "PLAYER_LOGIN" then
		AYB:ValidateDatabase()
		AYB.playerClass = select(2, UnitClass("player"))
		if AYB.Display and AYB.Display.Init then
			AYB.Display:Init()
		end
		if C_Timer then
			C_Timer.NewTicker(2, function()
				AYB:Refresh()
			end)
		end
		AYB:Refresh()
		print("|cff33ff99AreYouBuffed|r loaded. Type |cffffff00/ayb|r or |cffffff00/areyoubuffed|r to configure.")
	elseif event == "READY_CHECK" then
		AYB:OnReadyCheck()
	elseif event == "UNIT_AURA" then
		local unit = ...
		if unit == "player" then
			AYB:RequestRefresh()
		end
	end
end)

--------------------------------------------------------------------------
-- Slash commands
--------------------------------------------------------------------------

SLASH_AREYOUBUFFED1 = "/areyoubuffed"
SLASH_AREYOUBUFFED2 = "/ayb"

SlashCmdList["AREYOUBUFFED"] = function(msg)
	msg = strtrim(msg or ""):lower()

	if msg == "check" then
		AYB:RunBuffCheck()
	elseif msg == "lock" then
		AreYouBuffedDB.lockDisplay = true
		print("|cff33ff99AreYouBuffed:|r tracker display locked.")
	elseif msg == "unlock" then
		AreYouBuffedDB.lockDisplay = false
		print("|cff33ff99AreYouBuffed:|r tracker display unlocked - drag it to reposition.")
	elseif msg == "reset" then
		AreYouBuffedDB.displayPoint = { point = "CENTER", relPoint = "CENTER", x = 0, y = 220 }
		if AYB.Display and AYB.Display.ApplyPosition then
			AYB.Display:ApplyPosition()
		end
		print("|cff33ff99AreYouBuffed:|r tracker display position reset.")
	else
		if AYB.UI and AYB.UI.Toggle then
			AYB.UI:Toggle()
		end
	end
end

-- /buffed - re-scan everything you're tracking and fire the alarm (chat
-- warning + sound) if anything required is missing. Separate from /ayb so
-- it's a single, no-argument, "am I ready" button.
SLASH_AREYOUBUFFEDSCAN1 = "/buffed"

SlashCmdList["AREYOUBUFFEDSCAN"] = function()
	AYB:RunBuffCheck()
end
