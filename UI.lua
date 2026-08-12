--[[
	UI.lua

	The /ayb config window: a "Browse" tab to check off buffs from the
	built-in database (grouped by category, with search), a "My Buffs" tab
	to manage what you've picked (toggle required/optional, remove, add a
	custom spell ID by hand), and an "Options" tab for alert behavior.

	Built with plain Blizzard widgets only - no Ace3 or other library
	dependency, so this addon is a single self-contained folder.
]]

AreYouBuffed = AreYouBuffed or {}
local AYB = AreYouBuffed
AYB.UI = AYB.UI or {}
local UI = AYB.UI

local WINDOW_WIDTH = 480
local WINDOW_HEIGHT = 520
local ROW_HEIGHT = 22

--------------------------------------------------------------------------
-- Shared row widgets
--------------------------------------------------------------------------

local function CreateBrowseRow(parent)
	local row = CreateFrame("Frame", nil, parent)
	row:SetSize(300, ROW_HEIGHT)

	local check = CreateFrame("CheckButton", nil, row, "UICheckButtonTemplate")
	check:SetSize(20, 20)
	check:SetPoint("LEFT", 0, 0)
	check:SetScript("OnClick", function(self)
		local group = self.group
		if not group then
			return
		end
		if self:GetChecked() then
			AYB:AddTracked(group, true)
		else
			AYB:RemoveTracked(group.name)
		end
		UI:PopulateMyBuffsList()
	end)
	row.check = check

	local label = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
	label:SetPoint("LEFT", check, "RIGHT", 4, 0)
	label:SetWidth(220)
	label:SetJustifyH("LEFT")
	row.label = label

	local warn = row:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
	warn:SetPoint("LEFT", label, "RIGHT", 2, 0)
	row.warn = warn

	row:SetScript("OnEnter", function(self)
		local group = self.check.group
		if not group then
			return
		end
		GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
		GameTooltip:SetText(group.name)
		GameTooltip:AddLine("Spell ID(s): " .. table.concat(group.ids, ", "), 0.8, 0.8, 0.8)
		local validation = AYB.validation and AYB.validation[group.name]
		if validation then
			if validation.ok then
				GameTooltip:AddLine("Recognized as: " .. table.concat(validation.resolvedNames, " / "), 0.6, 1, 0.6, true)
			else
				GameTooltip:AddLine("None of these IDs were recognized by your client - this entry may be outdated. Please verify on Wowhead and add the correct ID manually if needed.", 1, 0.4, 0.4, true)
			end
		end
		GameTooltip:Show()
	end)
	row:SetScript("OnLeave", function()
		GameTooltip:Hide()
	end)

	return row
end

local function CreateTrackedRow(parent)
	local row = CreateFrame("Frame", nil, parent)
	row:SetSize(380, ROW_HEIGHT)

	local check = CreateFrame("CheckButton", nil, row, "UICheckButtonTemplate")
	check:SetSize(20, 20)
	check:SetPoint("LEFT", 0, 0)
	check:SetScript("OnClick", function(self)
		if self.entryName then
			AYB:SetRequired(self.entryName, self:GetChecked() and true or false)
		end
	end)
	row.check = check

	local label = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
	label:SetPoint("LEFT", check, "RIGHT", 4, 0)
	label:SetWidth(280)
	label:SetJustifyH("LEFT")
	row.label = label

	local removeButton = CreateFrame("Button", nil, row, "UIPanelButtonTemplate")
	removeButton:SetSize(20, 20)
	removeButton:SetPoint("RIGHT", 0, 0)
	removeButton:SetText("x")
	removeButton:SetScript("OnClick", function(self)
		if self.entryName then
			AYB:RemoveTracked(self.entryName)
			UI:PopulateMyBuffsList()
			UI:PopulateBrowseList()
		end
	end)
	row.removeButton = removeButton

	return row
end

--------------------------------------------------------------------------
-- Browse tab
--------------------------------------------------------------------------

function UI:PopulateBrowseList()
	local content = self.browseContent
	local rows = self.browseRows
	if not content then
		return
	end

	local list = {}
	local filter = strtrim(self.searchBox:GetText() or ""):lower()

	if filter ~= "" then
		for _, category in ipairs(AYB.Database.categories) do
			for _, group in ipairs(category.groups) do
				if group.name:lower():find(filter, 1, true) then
					table.insert(list, group)
				end
			end
		end
	else
		local category = AYB.Database.categories[self.selectedCategoryIndex or 1]
		if category then
			for _, group in ipairs(category.groups) do
				table.insert(list, group)
			end
		end
	end

	for index, group in ipairs(list) do
		local row = rows[index]
		if not row then
			row = CreateBrowseRow(content)
			rows[index] = row
		end
		row:ClearAllPoints()
		row:SetPoint("TOPLEFT", 4, -((index - 1) * ROW_HEIGHT) - 4)
		row.check:SetChecked(AYB:IsTracked(group.name) ~= nil)
		row.check.group = group
		row.label:SetText(group.name)

		local validation = AYB.validation and AYB.validation[group.name]
		row.warn:SetText((validation and not validation.ok) and "|cffff5555(unverified)|r" or "")

		row:Show()
	end

	for index = #list + 1, #rows do
		rows[index]:Hide()
	end

	content:SetHeight(math.max(1, #list * ROW_HEIGHT + 8))
end

local function CreateCategoryButtons(panel)
	local buttons = {}
	for index, category in ipairs(AYB.Database.categories) do
		local btn = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
		btn:SetSize(120, 22)
		btn:SetText(category.label)
		btn:GetFontString():SetFontObject("GameFontHighlightSmall")
		btn:SetPoint("TOPLEFT", 0, -((index - 1) * 24))
		btn:SetScript("OnClick", function()
			UI.selectedCategoryIndex = index
			UI.searchBox:SetText("")
			UI:PopulateBrowseList()
		end)
		buttons[index] = btn
	end
	return buttons
end

local function CreateBrowsePanel(parent)
	local panel = CreateFrame("Frame", nil, parent)
	panel:SetAllPoints()

	local searchLabel = panel:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
	searchLabel:SetPoint("TOPLEFT", 130, -2)
	searchLabel:SetText("Search:")

	local searchBox = CreateFrame("EditBox", nil, panel, "InputBoxTemplate")
	searchBox:SetSize(220, 20)
	searchBox:SetAutoFocus(false)
	searchBox:SetPoint("LEFT", searchLabel, "RIGHT", 8, 0)
	searchBox:SetScript("OnTextChanged", function()
		UI:PopulateBrowseList()
	end)
	searchBox:SetScript("OnEscapePressed", function(self)
		self:ClearFocus()
	end)
	UI.searchBox = searchBox

	CreateCategoryButtons(panel)

	local scrollFrame = CreateFrame("ScrollFrame", "AreYouBuffedBrowseScroll", panel, "UIPanelScrollFrameTemplate")
	scrollFrame:SetPoint("TOPLEFT", 130, -28)
	scrollFrame:SetPoint("BOTTOMRIGHT", -28, 8)

	local content = CreateFrame("Frame", nil, scrollFrame)
	content:SetSize(300, 1)
	scrollFrame:SetScrollChild(content)
	UI.browseContent = content
	UI.browseRows = {}

	UI.selectedCategoryIndex = 1

	return panel
end

--------------------------------------------------------------------------
-- My Buffs tab
--------------------------------------------------------------------------

function UI:PopulateMyBuffsList()
	local content = self.myBuffsContent
	local rows = self.myBuffsRows
	if not content then
		return
	end

	local tracked = AreYouBuffedCharDB.tracked

	for index, entry in ipairs(tracked) do
		local row = rows[index]
		if not row then
			row = CreateTrackedRow(content)
			rows[index] = row
		end
		row:ClearAllPoints()
		row:SetPoint("TOPLEFT", 4, -((index - 1) * ROW_HEIGHT) - 4)

		row.check:SetChecked(entry.required)
		row.check.entryName = entry.name
		row.removeButton.entryName = entry.name

		local tag = ""
		if entry.type == "weaponEnchant" then
			tag = entry.slot == "off" and "  |cff999999(off-hand enchant)|r" or "  |cff999999(weapon enchant)|r"
		end
		row.label:SetText(entry.name .. tag)

		row:Show()
	end

	for index = #tracked + 1, #rows do
		rows[index]:Hide()
	end

	content:SetHeight(math.max(1, #tracked * ROW_HEIGHT + 8))
end

local function CreateMyBuffsPanel(parent)
	local panel = CreateFrame("Frame", nil, parent)
	panel:SetAllPoints()

	local hint = panel:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
	hint:SetPoint("TOPLEFT", 4, -2)
	hint:SetText("Buffs you're tracking. Uncheck \"required\" to just watch a buff without blocking ready checks.")
	hint:SetWidth(440)
	hint:SetJustifyH("LEFT")

	local scrollFrame = CreateFrame("ScrollFrame", "AreYouBuffedMyBuffsScroll", panel, "UIPanelScrollFrameTemplate")
	scrollFrame:SetPoint("TOPLEFT", 4, -32)
	scrollFrame:SetPoint("BOTTOMRIGHT", -28, 76)

	local content = CreateFrame("Frame", nil, scrollFrame)
	content:SetSize(380, 1)
	scrollFrame:SetScrollChild(content)
	UI.myBuffsContent = content
	UI.myBuffsRows = {}

	-- custom add-by-id row
	local addLabel = panel:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
	addLabel:SetPoint("BOTTOMLEFT", 8, 46)
	addLabel:SetText("Add custom spell ID (paste from Wowhead):")

	local addBox = CreateFrame("EditBox", nil, panel, "InputBoxTemplate")
	addBox:SetSize(80, 20)
	addBox:SetAutoFocus(false)
	addBox:SetNumeric(true)
	addBox:SetPoint("TOPLEFT", addLabel, "BOTTOMLEFT", 4, -4)

	local weaponCheck = CreateFrame("CheckButton", nil, panel, "UICheckButtonTemplate")
	weaponCheck:SetSize(20, 20)
	weaponCheck:SetPoint("LEFT", addBox, "RIGHT", 55, 0)
	local weaponLabel = panel:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
	weaponLabel:SetPoint("LEFT", weaponCheck, "RIGHT", 2, 0)
	weaponLabel:SetText("Weapon enchant")

	local offhandCheck = CreateFrame("CheckButton", nil, panel, "UICheckButtonTemplate")
	offhandCheck:SetSize(20, 20)
	offhandCheck:SetPoint("LEFT", weaponLabel, "RIGHT", 10, 0)
	local offhandLabel = panel:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
	offhandLabel:SetPoint("LEFT", offhandCheck, "RIGHT", 2, 0)
	offhandLabel:SetText("Off-hand")

	local addButton = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
	addButton:SetSize(70, 22)
	addButton:SetText("Add")
	addButton:SetPoint("LEFT", addBox, "LEFT", 0, -26)
	addButton:SetScript("OnClick", function()
		local ok = AYB:AddCustom(addBox:GetText(), true, weaponCheck:GetChecked(), offhandCheck:GetChecked() and "off" or "main")
		if ok then
			addBox:SetText("")
			UI:PopulateMyBuffsList()
			UI:PopulateBrowseList()
		end
	end)

	local defaultsButton = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
	defaultsButton:SetSize(150, 22)
	defaultsButton:SetText("Load Class Defaults")
	defaultsButton:SetPoint("BOTTOMLEFT", 8, 4)
	defaultsButton:SetScript("OnClick", function()
		AYB:LoadClassDefaults()
		UI:PopulateMyBuffsList()
		UI:PopulateBrowseList()
	end)

	return panel
end

--------------------------------------------------------------------------
-- Options tab
--------------------------------------------------------------------------

local function CreateOptionCheckbox(panel, label, yOffset, key)
	local check = CreateFrame("CheckButton", nil, panel, "UICheckButtonTemplate")
	check:SetSize(22, 22)
	check:SetPoint("TOPLEFT", 8, yOffset)
	check:SetScript("OnClick", function(self)
		AreYouBuffedDB[key] = self:GetChecked() and true or false
	end)

	local text = panel:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
	text:SetPoint("LEFT", check, "RIGHT", 4, 0)
	text:SetWidth(400)
	text:SetJustifyH("LEFT")
	text:SetText(label)

	check.dbKey = key
	return check
end

local function CreateOptionsPanel(parent)
	local panel = CreateFrame("Frame", nil, parent)
	panel:SetAllPoints()

	local checks = {}
	table.insert(checks, CreateOptionCheckbox(panel, "Play a sound when a ready check finds a missing required buff", -4, "sound"))
	table.insert(checks, CreateOptionCheckbox(panel, "Automatically click \"No\" on ready checks when something required is missing", -30, "autoDeclineReadyCheck"))

	panel.checks = checks
	return panel
end

function UI:RefreshOptionsPanel()
	if not self.optionsPanel then
		return
	end
	for _, check in ipairs(self.optionsPanel.checks) do
		check:SetChecked(AreYouBuffedDB[check.dbKey] and true or false)
	end
end

--------------------------------------------------------------------------
-- Window shell / tabs
--------------------------------------------------------------------------

local TABS = { "Browse", "My Buffs", "Options" }

local function SelectTab(index)
	local ui = UI
	for tabIndex, panel in ipairs(ui.panels) do
		if tabIndex == index then
			panel:Show()
			ui.tabButtons[tabIndex]:Disable()
		else
			panel:Hide()
			ui.tabButtons[tabIndex]:Enable()
		end
	end
	ui.activeTab = index
	if index == 1 then
		ui:PopulateBrowseList()
	elseif index == 2 then
		ui:PopulateMyBuffsList()
	elseif index == 3 then
		ui:RefreshOptionsPanel()
	end
end

function UI:Init()
	if self.frame then
		return
	end

	local frame = CreateFrame("Frame", "AreYouBuffedFrame", UIParent, "BackdropTemplate")
	self.frame = frame
	frame:SetSize(WINDOW_WIDTH, WINDOW_HEIGHT)
	frame:SetPoint("CENTER")
	frame:SetFrameStrata("HIGH")
	frame:SetMovable(true)
	frame:EnableMouse(true)
	frame:RegisterForDrag("LeftButton")
	frame:SetScript("OnDragStart", frame.StartMoving)
	frame:SetScript("OnDragStop", frame.StopMovingOrSizing)
	frame:Hide()

	if frame.SetBackdrop then
		frame:SetBackdrop({
			bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
			edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
			tile = true,
			tileSize = 32,
			edgeSize = 32,
			insets = { left = 11, right = 12, top = 12, bottom = 11 },
		})
	end

	local title = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
	title:SetPoint("TOP", 0, -16)
	title:SetText("AreYouBuffed")

	local closeButton = CreateFrame("Button", nil, frame, "UIPanelCloseButton")
	closeButton:SetPoint("TOPRIGHT", -4, -4)
	closeButton:SetScript("OnClick", function()
		frame:Hide()
	end)

	self.tabButtons = {}
	self.panels = {}

	for index, tabName in ipairs(TABS) do
		local btn = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
		btn:SetSize(100, 22)
		btn:SetText(tabName)
		btn:SetPoint("TOPLEFT", 20 + (index - 1) * 104, -40)
		btn:SetScript("OnClick", function()
			SelectTab(index)
		end)
		self.tabButtons[index] = btn
	end

	local contentArea = CreateFrame("Frame", nil, frame)
	contentArea:SetPoint("TOPLEFT", 16, -68)
	contentArea:SetPoint("BOTTOMRIGHT", -16, 16)

	self.panels[1] = CreateBrowsePanel(contentArea)
	self.panels[2] = CreateMyBuffsPanel(contentArea)
	self.optionsPanel = CreateOptionsPanel(contentArea)
	self.panels[3] = self.optionsPanel

	for _, panel in ipairs(self.panels) do
		panel:Hide()
	end

	table.insert(UISpecialFrames, "AreYouBuffedFrame")

	SelectTab(1)
end

function UI:Toggle()
	self:Init()
	if self.frame:IsShown() then
		self.frame:Hide()
	else
		self.frame:Show()
		SelectTab(self.activeTab or 1)
	end
end

function UI:RefreshIfShown()
	if self.frame and self.frame:IsShown() and self.activeTab == 2 then
		self:PopulateMyBuffsList()
	end
end
