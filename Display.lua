--[[
	Display.lua

	A checklist popup, not an always-on-screen tracker: it's hidden at login
	and stays hidden until you run /buffed (or /ayb check), at which point it
	shows one icon per tracked buff - green border only on a confirmed match,
	red for anything else (missing, or a weapon enchant that's on but can't be
	identified) - and hides itself again 10 seconds later. Drag the header to
	move it, click it to open the config window.
]]

AreYouBuffed = AreYouBuffed or {}
local AYB = AreYouBuffed
AYB.Display = AYB.Display or {}
local Display = AYB.Display

local ICON_SIZE = 28
local ICON_SPACING = 4
local HEADER_HEIGHT = 16
local MAX_PER_ROW = 12
local VISIBLE_SECONDS = 10

local iconPool = {}

local function AcquireIcon(index)
	local button = iconPool[index]
	if button then
		return button
	end

	button = CreateFrame("Button", nil, Display.frame)
	button:SetSize(ICON_SIZE, ICON_SIZE)

	button.border = button:CreateTexture(nil, "BACKGROUND")
	button.border:SetPoint("TOPLEFT", -2, 2)
	button.border:SetPoint("BOTTOMRIGHT", 2, -2)
	button.border:SetColorTexture(1, 1, 1, 1)

	button.icon = button:CreateTexture(nil, "ARTWORK")
	button.icon:SetAllPoints()
	button.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)

	button:SetScript("OnEnter", function(self)
		GameTooltip:SetOwner(self, "ANCHOR_TOP")
		GameTooltip:SetText(self.entryName or "?")
		if self.entryStatus == "active" then
			GameTooltip:AddLine("Active", 0.2, 1, 0.2)
		elseif self.entryStatus == "unknown" then
			GameTooltip:AddLine("A weapon enchant is applied, but this client couldn't identify which one - probably fine.", 1, 0.85, 0.2, true)
		else
			GameTooltip:AddLine("Missing", 1, 0.3, 0.3)
		end
		GameTooltip:Show()
	end)
	button:SetScript("OnLeave", function()
		GameTooltip:Hide()
	end)

	iconPool[index] = button
	return button
end

function Display:Init()
	if self.frame then
		return
	end

	local frame = CreateFrame("Frame", "AreYouBuffedDisplay", UIParent, "BackdropTemplate")
	self.frame = frame
	frame:SetSize(200, 50)
	frame:SetClampedToScreen(true)
	frame:SetFrameStrata("MEDIUM")
	frame:SetMovable(true)
	frame:EnableMouse(true)

	frame:Hide()

	if frame.SetBackdrop then
		frame:SetBackdrop({
			bgFile = "Interface\\Buttons\\WHITE8x8",
			edgeFile = "Interface\\Buttons\\WHITE8x8",
			edgeSize = 1,
		})
		frame:SetBackdropColor(0, 0, 0, 0.35)
		frame:SetBackdropBorderColor(0, 0, 0, 0.6)
	end

	local header = CreateFrame("Button", nil, frame)
	header:SetPoint("TOPLEFT")
	header:SetPoint("TOPRIGHT")
	header:SetHeight(HEADER_HEIGHT)
	self.header = header

	local label = header:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
	label:SetPoint("LEFT", 2, 0)
	label:SetText("AreYouBuffed")

	header:RegisterForDrag("LeftButton")
	header:SetScript("OnDragStart", function()
		if not AreYouBuffedDB.lockDisplay then
			frame:StartMoving()
		end
	end)
	header:SetScript("OnDragStop", function()
		frame:StopMovingOrSizing()
		local point, _, relPoint, x, y = frame:GetPoint()
		AreYouBuffedDB.displayPoint = { point = point, relPoint = relPoint, x = x, y = y }
	end)
	header:SetScript("OnClick", function(_, button)
		if button == "LeftButton" and AYB.UI and AYB.UI.Toggle then
			AYB.UI:Toggle()
		end
	end)
	header:SetScript("OnEnter", function(self)
		GameTooltip:SetOwner(self, "ANCHOR_TOP")
		GameTooltip:SetText("AreYouBuffed")
		GameTooltip:AddLine("Click to configure. Drag to move. |cff999999/ayb lock|r to stop dragging.", 1, 1, 1, true)
		GameTooltip:Show()
	end)
	header:SetScript("OnLeave", function()
		GameTooltip:Hide()
	end)

	self:ApplyPosition()
end

function Display:ApplyPosition()
	local frame = self.frame
	if not frame then
		return
	end
	local p = AreYouBuffedDB.displayPoint or { point = "CENTER", relPoint = "CENTER", x = 0, y = 220 }
	frame:ClearAllPoints()
	frame:SetPoint(p.point, UIParent, p.relPoint, p.x, p.y)
end

-- Draws one icon per entry in `results` (every tracked buff for this
-- character, not just the missing ones) and sizes the frame to fit. Does NOT
-- touch visibility - callers decide when the frame should actually be shown.
function Display:RenderIcons(results)
	local columns = math.min(MAX_PER_ROW, #results)
	local rows = math.ceil(#results / MAX_PER_ROW)

	for index, result in ipairs(results) do
		local button = AcquireIcon(index)
		local row = math.floor((index - 1) / MAX_PER_ROW)
		local col = (index - 1) % MAX_PER_ROW

		button:ClearAllPoints()
		button:SetPoint(
			"TOPLEFT",
			self.frame,
			"TOPLEFT",
			col * (ICON_SIZE + ICON_SPACING) + ICON_SPACING,
			-(HEADER_HEIGHT + row * (ICON_SIZE + ICON_SPACING) + ICON_SPACING)
		)

		local entry = result.entry
		local icon = result.icon
		if not icon and entry.ids and entry.ids[1] then
			local _, dbIcon = AYB:ResolveSpell(entry.ids[1])
			icon = dbIcon
		end
		button.icon:SetTexture(icon or "Interface\\Icons\\INV_Misc_QuestionMark")
		button.entryName = entry.name
		button.entryStatus = result.status

		if result.status == "active" then
			button.border:SetColorTexture(0.2, 0.85, 0.2, 1)
			button.icon:SetDesaturated(false)
			button:SetAlpha(1)
		else
			button.border:SetColorTexture(0.85, 0.15, 0.15, 1)
			button.icon:SetDesaturated(true)
			button:SetAlpha(0.9)
		end

		button:Show()
	end

	for index = #results + 1, #iconPool do
		iconPool[index]:Hide()
	end

	self.frame:SetSize(
		math.max(120, columns * (ICON_SIZE + ICON_SPACING) + ICON_SPACING),
		HEADER_HEIGHT + rows * (ICON_SIZE + ICON_SPACING) + ICON_SPACING
	)
end

-- Called by /buffed (and /ayb check): shows the full checklist for this
-- character - every tracked buff, green if active, red if missing - then
-- hides itself again after VISIBLE_SECONDS. Re-triggering while already
-- shown just restarts the countdown instead of stacking timers.
function Display:Trigger(results)
	if not self.frame then
		return
	end
	if #results == 0 then
		self.frame:Hide()
		return
	end

	self:RenderIcons(results)
	self.frame:Show()

	if self.hideTimer then
		self.hideTimer:Cancel()
	end
	self.hideTimer = C_Timer.NewTimer(VISIBLE_SECONDS, function()
		self.hideTimer = nil
		self.frame:Hide()
	end)
end

-- Called on every background refresh (login, periodic ticker, aura change).
-- Deliberately does NOT show or hide the frame - it only keeps the icons
-- that are already on screen in sync while the post-/buffed window is open.
function Display:Update(results)
	if not self.frame or not self.frame:IsShown() then
		return
	end
	self:RenderIcons(results)
end
