--[[
	Database.lua

	Built-in, curated list of common raid/consumable buffs for TBC content,
	organized into browsable categories.

	Every spell ID below was cross-checked against a harvested dump of the
	full TBC spell list (~28,650 spells, pulled from tbc.warcraftdb.com's
	data API on 2026-08-12, saved at data/tbc_spells.json) - matched by
	EXACT spell name, not typed from memory. Where a name has multiple
	ranks/variants (e.g. every rank of "Battle Shout", or faction/version
	duplicates of a flask), ALL matching ids are included in that group's
	`ids` array - matching ANY id in the array counts as "active", so an
	extra id that's a harmless duplicate costs nothing.

	This is still a third-party community database, not Blizzard's own
	files, so it can still be stale/wrong occasionally - Core.lua validates
	every id against the client's own spell data at login and flags groups
	that don't resolve. A couple of categories from the first draft of this
	file (Scrolls, Dire Maul Runes) were dropped entirely because no exact
	name match could be found in the harvested data at all - rather than
	ship guessed ids for those, use "+ Add custom spell ID" in the UI if you
	need them.
]]

AreYouBuffed = AreYouBuffed or {}
local AYB = AreYouBuffed

-- entry.type:
--   "aura"          - detected via the player's buff list (UnitBuff / C_UnitAuras)
--   "weaponEnchant" - detected via GetWeaponEnchantInfo (temporary weapon buffs:
--                     oils, stones, shaman weapon imbues - these never show up
--                     as normal auras)
-- entry.slot (weaponEnchant only): "main" or "off" (default "main")

AYB.Database = {
	categories = {
		{
			key = "flasks",
			label = "Flasks",
			groups = {
				{ name = "Flask of the Titans", ids = { 17626, 17635 } },
				{ name = "Flask of Distilled Wisdom", ids = { 17636 } },
				{ name = "Flask of Supreme Power", ids = { 17637 } },
				{ name = "Flask of Chromatic Resistance", ids = { 17638 } },
				{ name = "Flask of Petrification", ids = { 17634 } },
				{ name = "Flask of Relentless Assault", ids = { 28520, 28589, 28604 } },
				{ name = "Flask of Mighty Restoration", ids = { 28519, 28588, 28603 } },
				{ name = "Flask of Pure Death", ids = { 28540, 28591, 28607 } },
				{ name = "Flask of Blinding Light", ids = { 28521, 28590, 28606 } },
				{ name = "Flask of Fortification", ids = { 28518, 28587, 28602 } },
			},
		},
		{
			key = "elixirs_battle",
			label = "Battle Elixirs",
			groups = {
				{ name = "Elixir of the Mongoose", ids = { 17538, 17571 } },
				{ name = "Juju Power", ids = { 16323 } },
				{ name = "Greater Arcane Elixir", ids = { 16889, 17539, 17573 } },
				{ name = "Elixir of Frost Power", ids = { 21923 } },
				{ name = "Elixir of Demonslaying", ids = { 11406, 11477 } },
				{ name = "Elixir of Greater Firepower", ids = { 26277 } },
				{ name = "Adept's Elixir", ids = { 33721, 33740 } },
				{ name = "Elixir of Major Strength", ids = { 28544 } },
				{ name = "Elixir of Major Agility", ids = { 28553 } },
				{ name = "Elixir of Major Shadow Power", ids = { 28558 } },
				{ name = "Elixir of Giant Growth", ids = { 8240 } },
				{ name = "Onslaught Elixir", ids = { 33720, 33738 } },
			},
		},
		{
			key = "elixirs_guardian",
			label = "Guardian Elixirs",
			groups = {
				{ name = "Elixir of Fortitude", ids = { 3450, 3593 } },
				{ name = "Elixir of Superior Defense", ids = { 17554 } },
				{ name = "Elixir of Camouflage", ids = { 28543 } },
				{ name = "Elixir of Major Defense", ids = { 28557 } },
				{ name = "Elixir of Draenic Wisdom", ids = { 39627, 39638 } },
				{ name = "Elixir of Ironskin", ids = { 39628, 39639 } },
				{ name = "Elixir of Healing Power", ids = { 28545 } },
			},
		},
		{
			key = "food",
			label = "Food & Drink Buffs",
			groups = {
				-- Every food/drink item grants a buff literally named "Well
				-- Fed" regardless of which stats it gives, so any one of
				-- these ~38 ids means "some food buff is active".
				{
					name = "Well Fed",
					ids = {
						19705, 19706, 19708, 19709, 19710, 19711, 24799, 24870, 25694, 25941,
						33254, 33256, 33257, 33259, 33261, 33263, 33265, 33268, 33272, 35272,
						40323, 42293, 43764, 43771, 45245, 45619, 46682, 46687, 46899,
						44097, 44098, 44099, 44100, 44101, 44102, 44104, 44105, 44106,
					},
				},
			},
		},
		{
			key = "weapon_enchants",
			label = "Weapon Enchants",
			groups = {
				{ name = "Elemental Sharpening Stone", ids = { 22757 }, type = "weaponEnchant" },
				{ name = "Dense Sharpening Stone", ids = { 16641 }, type = "weaponEnchant" },
				{ name = "Adamantite Sharpening Stone", ids = { 29656 }, type = "weaponEnchant" },
				{ name = "Adamantite Weightstone", ids = { 34608 }, type = "weaponEnchant" },
				{ name = "Brilliant Wizard Oil", ids = { 25122, 25129 }, type = "weaponEnchant" },
				{ name = "Brilliant Mana Oil", ids = { 25123, 25130 }, type = "weaponEnchant" },
				{ name = "Blessed Wizard Oil", ids = { 28898 }, type = "weaponEnchant" },
				{ name = "Shadow Oil", ids = { 3449, 3594 }, type = "weaponEnchant" },
				{ name = "Windfury Weapon", ids = { 8232, 8235, 10486, 16362, 25505, 32911, 35886 }, type = "weaponEnchant" },
				{ name = "Flametongue Weapon", ids = { 8024, 8027, 8030, 16339, 16341, 16342, 25489 }, type = "weaponEnchant" },
				{ name = "Frostbrand Weapon", ids = { 8033, 8038, 10456, 16355, 16356, 25500 }, type = "weaponEnchant" },
				{
					name = "Rockbiter Weapon",
					type = "weaponEnchant",
					ids = {
						8017, 8018, 8019, 10399, 16314, 16315, 16316, 25479, 25485, 33640,
						36494, 36495, 36496, 36497, 36498, 36499, 36502, 36744, 36750, 36751,
						36752, 36753, 36754, 36755, 36756, 36757, 36758, 36759, 36760, 36761,
						36762, 36763, 36764, 36765, 36766, 36767, 36768, 36769, 36770, 36771,
						36772, 36773, 36774, 36775, 36776, 36777,
					},
				},
			},
		},
		{
			key = "class_buffs",
			label = "Class / Group Buffs",
			groups = {
				{ name = "Fortitude (Power Word: Fortitude / Prayer of Fortitude)", match = { "Power Word: Fortitude", "Prayer of Fortitude" }, ids = { 1243, 1244, 1245, 2791, 10937, 10938, 13864, 23947, 23948, 25389, 36004, 21562, 21564, 25392, 39231 } },
				{ name = "Spirit (Divine Spirit / Prayer of Spirit)", match = { "Divine Spirit", "Prayer of Spirit" }, ids = { 14752, 14818, 14819, 16875, 25312, 27841, 39234, 27681, 32999 } },
				{ name = "Intellect (Arcane Intellect / Arcane Brilliance)", match = { "Arcane Intellect", "Arcane Brilliance" }, ids = { 1459, 1460, 1461, 10156, 10157, 13326, 16876, 27126, 36880, 39235, 23028, 27127 } },
				{ name = "Mark of the Wild / Gift of the Wild", match = { "Mark of the Wild", "Gift of the Wild" }, ids = { 1126, 5232, 5234, 6756, 8907, 9884, 9885, 16878, 24752, 26990, 39233, 21849, 21850, 26991 } },
				{ name = "Thorns", ids = { 467, 782, 1075, 8914, 9756, 9910, 15438, 16877, 21335, 21337, 22128, 22351, 22696, 25640, 25777, 26992, 31271, 33907, 34343, 34663, 35361, 43420 } },
				{ name = "Blessing of Kings", ids = { 20217 } },
				{ name = "Blessing of Wisdom", ids = { 19742, 19850, 19852, 19853, 19854, 25290, 27142 } },
				{ name = "Blessing of Might", ids = { 19740, 19834, 19835, 19836, 19837, 19838, 25291, 27140 } },
				{ name = "Blessing of Sanctuary", ids = { 20911, 20912, 20913, 20914, 27168 } },
				{ name = "Blessing of Salvation", ids = { 1038 } },
				{ name = "Battle Shout", ids = { 2048, 5242, 6192, 6673, 9128, 11549, 11550, 11551, 24438, 25101, 25289, 26043, 26099, 27578, 30635, 30833, 30931, 31403, 32064, 38232, 42247, 46763 } },
				{ name = "Trueshot Aura", ids = { 19506, 20905, 20906, 27066, 31519 } },
				{ name = "Leader of the Pack", ids = { 17007, 24932 } },
				{ name = "Moonkin Aura", ids = { 24907 } },
				{ name = "Devotion Aura", ids = { 465, 643, 1032, 8258, 10290, 10291, 10292, 10293, 17232, 27149, 41452 } },
				{ name = "Retribution Aura", ids = { 7294, 8990, 10298, 10299, 10300, 10301, 13008, 27150 } },
				{ name = "Sanctity Aura", ids = { 20218 } },
				{ name = "Shadow Protection", ids = { 976, 7235, 7241, 7242, 7243, 7244, 10957, 10958, 16874, 16891, 17548, 25433, 28537 } },
				{ name = "Windfury Totem", ids = { 8512, 8516, 10608, 10610, 10613, 10614, 25585, 25587, 27621 } },
				{ name = "Grace of Air Totem", ids = { 8835, 10627, 25359 } },
				{ name = "Strength of Earth Totem", ids = { 8075, 8160, 8161, 10442, 25361, 25528, 31633 } },
				{ name = "Mana Spring Totem", ids = { 5675, 10495, 10496, 10497, 24854, 25570 } },
				{ name = "Healing Stream Totem", ids = { 5394, 5396, 6375, 6377, 10462, 10463, 25567, 35199 } },
				{ name = "Stoneskin Totem", ids = { 8071, 8073, 8154, 8155, 10406, 10407, 10408, 25508, 25509, 38115 } },
			},
		},
		{
			key = "world_buffs",
			label = "World Buffs",
			groups = {
				{ name = "Rallying Cry of the Dragonslayer", ids = { 22888, 355363 } },
				{ name = "Warchief's Blessing", ids = { 16609, 355366 } },
				{ name = "Spirit of Zandalar", ids = { 24425, 355365 } },
				{ name = "Songflower Serenade", ids = { 15366 } },
				{ name = "Sayge's Dark Fortune", ids = { 23735, 23736, 23737, 23738, 23766, 23767, 23768, 23769, 353694 } },
				{ name = "Slip'kik's Savvy", ids = { 22820 } },
				{ name = "Fengus' Ferocity", ids = { 22817 } },
				{ name = "Mol'dar's Moxie", ids = { 22818 } },
			},
		},
	},

	-- Suggested starting sets per class, used by the "Load class defaults"
	-- button in the config UI. These reference group names above (must match
	-- exactly) and are only a starting point - fully editable afterwards.
	classDefaults = {
		WARRIOR = { "Fortitude (Power Word: Fortitude / Prayer of Fortitude)", "Battle Shout", "Blessing of Might", "Blessing of Kings", "Elixir of the Mongoose", "Windfury Weapon" },
		PALADIN = { "Fortitude (Power Word: Fortitude / Prayer of Fortitude)", "Blessing of Kings", "Blessing of Wisdom", "Intellect (Arcane Intellect / Arcane Brilliance)" },
		HUNTER = { "Fortitude (Power Word: Fortitude / Prayer of Fortitude)", "Trueshot Aura", "Blessing of Might", "Elixir of the Mongoose", "Windfury Weapon" },
		ROGUE = { "Fortitude (Power Word: Fortitude / Prayer of Fortitude)", "Blessing of Kings", "Elixir of the Mongoose", "Windfury Weapon" },
		PRIEST = { "Fortitude (Power Word: Fortitude / Prayer of Fortitude)", "Spirit (Divine Spirit / Prayer of Spirit)", "Intellect (Arcane Intellect / Arcane Brilliance)", "Blessing of Wisdom" },
		SHAMAN = { "Fortitude (Power Word: Fortitude / Prayer of Fortitude)", "Strength of Earth Totem", "Mana Spring Totem", "Intellect (Arcane Intellect / Arcane Brilliance)" },
		MAGE = { "Fortitude (Power Word: Fortitude / Prayer of Fortitude)", "Intellect (Arcane Intellect / Arcane Brilliance)", "Blessing of Wisdom", "Spirit (Divine Spirit / Prayer of Spirit)" },
		WARLOCK = { "Fortitude (Power Word: Fortitude / Prayer of Fortitude)", "Intellect (Arcane Intellect / Arcane Brilliance)", "Blessing of Wisdom" },
		DRUID = { "Fortitude (Power Word: Fortitude / Prayer of Fortitude)", "Mark of the Wild / Gift of the Wild", "Intellect (Arcane Intellect / Arcane Brilliance)" },
	},
}

-- Look up a group definition by its display name (used for class defaults
-- and for re-resolving saved entries against the current database).
function AYB:FindGroupByName(name)
	for _, category in ipairs(self.Database.categories) do
		for _, group in ipairs(category.groups) do
			if group.name == name then
				return group, category
			end
		end
	end
	return nil
end
