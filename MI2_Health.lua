--[[

	Name:		MobHealth2
	Author:		Wyv	& Skeeve
	Description:	Displays health	value for mobs.
	Original version by	Telo.
]]


-- remember previous font type and font size
local lOldFontId = 0
local lOldFontSize = 0

-- PERF: last health/mana texts shown in the target frame. MobHealth_Display()
-- runs on every UNIT_HEALTH/UNIT_MANA tick in combat; SetText is only
-- needed when the text actually changes.
local lLastHealthText, lLastManaText


--------------------------------------------------------------------------------------------------
-- external	functions for macros / scripts
--------------------------------------------------------------------------------------------------

-----------------------------------------------------------------------------
-- MobHealth_GetTargetCurHP()  
--
-- Return current health points	value for the current target as	an integer
-- value. Return nil if	there is no	current	target.
--
-- Example:
--	 local targetCurrentHealth = MobHealth_GetTargetCurHP()
--	 if	 targetCurrentHealth  then
--		.......
--	 end
-----------------------------------------------------------------------------
function MobHealth_GetTargetCurHP()
	if MI2_Target.curHealth then
		return MI2_Target.curHealth
	else
		return nil
	end
end	 --	of MobHealth_GetTargetCurHP()


-----------------------------------------------------------------------------
-- MobHealth_GetTargetMaxHP()  
--
-- Return maximum health points	value for the current target as	an integer
-- value. Return nil if	there is no	current	target.
--
-- Example:
--	 local targetMaxHealth = MobHealth_GetTargetMaxHP()
--	 if	 targetMaxHealth  then
--		.......
--	 end
-----------------------------------------------------------------------------
function MobHealth_GetTargetMaxHP()
	-- for compatibility to MobHealth-2: only return maxHP if there is a curHP
	if MI2_Target.curHealth then
		return MI2_Target.maxHealth
	else
		return nil
	end
end	 --	of MobHealth_GetTargetMaxHP()


-----------------------------------------------------------------------------
-- MobHealth_PPP( index	)  
--
-- Return the Points-Per-Percent (PPP) value for a Mob identified by its index.
-- The index is	the	concatination of the Mob name and the Mob level	(see
-- example below). 0 is	returned if	the	PPP	value is not available for
-- the given index.	The	example	also shows how to calculate	the	actual
-- health points from the health percentage	and	the	PPP	value
--
-- Example:
--	  local	name  =	UnitName("target")
--	  local	level =	UnitLevel("target")
--	  local	index =	name..":"..level
--	  local	ppp	= MobHealth_PPP( index )
--	  local	healthPercent =	UnitHealth("target")
--	  local	curHealth =	math.floor(	healthPercent *	ppp	+ 0.5)
--	  local	maxHealth =	math.floor(	100	* ppp +	0.5)
-----------------------------------------------------------------------------
function MobHealth_PPP(	index )
	if	index and MobHealthDB[index]  then
		local s, e, pts, pct = string.find(MobHealthDB[index], "^(%d+)/(%d+)$")
		if ( pts and pct ) then
			pts	= pts +	0
			pct	= pct +	0
			if ( pct ~=	0 )	then
				return pts / pct
			end
		end
	end
	return 0
end


-----------------------------------------------------------------------------
-- MI2_GetHealthData()
--
-- get health data for a given mob from the given health database
-- (ie. either mob health database or player health database)
-----------------------------------------------------------------------------
function MI2_GetHealthData( database, index )
	local s, e, pts, pct
	if database[index] then
		s, e, pts, pct = string.find(database[index], "^(%d+)/(%d+)$")
	end
	return ((pts or 0) + 0), ((pct or 0) + 0)
end -- MI2_GetHealthData()


-----------------------------------------------------------------------------
-- MobHealth_Set()
--
-- store pct and pts values for a given mob index in the given database
-----------------------------------------------------------------------------
function MobHealth_Set( database, index, pts, pct)
	if pts or pct then
		database[index] = (pts or 0).."/"..(pct or 0)
	else
		database[index] = nil
	end
end  -- MobHealth_Set()


-----------------------------------------------------------------------------
-- MI2_CalculateHealth()
--
-- (re)calculate current health and maximum for current target
-----------------------------------------------------------------------------
function MI2_CalculateHealth( updateMaxHealth )
	if MI2_Target.unitHealth > 0 then
		local curHealthMax = UnitHealthMax("target")  -- have to check because BeastLore changes maxhealth from percent to value
		-- PERF: real-health fast path. On Turtle WoW the server sends real
		-- health values (curHealthMax ~= 100), so the exact max health is
		-- written to the DB here and the PPP learning loop is skipped
		-- entirely (see MI2_EventUnitHealth, which does not accumulate
		-- totalDamage/totalPercent in this case).
		if curHealthMax ~= 100 then
			if MI2_Target.healthDB then
				MobHealth_Set( MI2_Target.healthDB, MI2_Target.index, curHealthMax * 25, 2500 )
				MI2_Target = { totalPercent = 0, maxHealth=curHealthMax }
				MI2_Target.unitHealth = UnitHealth("target")
			end
			MI2_Target.curHealth = MI2_Target.unitHealth
			MI2_Target.maxHealth = curHealthMax
			MI2_Target.unitHealth = math.floor(100.0 * MI2_Target.unitHealth / MI2_Target.maxHealth + 0.5)
			MI2_Target.showHealth = 1
		elseif MI2_Target.totalPercent > 0 then
			local ppp = MI2_Target.totalDamage / MI2_Target.totalPercent
			MI2_Target.curHealth = math.floor(MI2_Target.unitHealth * ppp + 0.5)
			if updateMaxHealth then
				MI2_Target.maxHealth = math.floor( (100 * ppp) + 0.5 )
			end
			MI2_Target.showHealth = 1
		end
	end
end -- MI2_CalculateHealth()


-----------------------------------------------------------------------------
-- MobHealth_Display()
--
-- display the values and percentage for health	/ mana in target frame
-----------------------------------------------------------------------------
function MobHealth_Display( )
	local healthText, manaText

	-- create health and percent text if showing is enabled
	if MI2_Target.showHealth then
		if  MobInfoConfig.TargetHealth == 1 then
			healthText = string.format("%d/%d", MI2_Target.curHealth, MI2_Target.maxHealth )
		end
		if	MobInfoConfig.HealthPercent	== 1 then
			if healthText then
				healthText = healthText..string.format(" (%d%%)", MI2_Target.unitHealth )
			else
				healthText = string.format("%d%%", MI2_Target.unitHealth )
			end
		end
	end

	-- create mana text based on mana show flags
	local maxmana =	UnitManaMax("target")
	if maxmana > 0 then
		local mana = UnitMana("target")
		if MobInfoConfig.TargetMana == 1 then
			manaText = string.format("%d/%d", mana, maxmana )
		end
		if MobInfoConfig.ManaPercent == 1 then
			if manaText then
				manaText = manaText..string.format(" (%d%%)", math.floor(100.0 * mana / maxmana))
			else
				manaText = string.format("%d%%", math.floor(100.0 * mana / maxmana))
			end
		end
	end

	-- PERF: only call SetText when the text changed; the display is
	-- refreshed on every UNIT_HEALTH/UNIT_MANA tick but the numbers
	-- usually stay the same between ticks.
	local newHealthText = healthText or ""
	local newManaText = manaText or ""
	if newHealthText ~= lLastHealthText then
		MI2_MobHealthText:SetText( newHealthText )
		lLastHealthText = newHealthText
	end
	if newManaText ~= lLastManaText then
		MI2_MobManaText:SetText( newManaText )
		lLastManaText = newManaText
	end
	-- SUPPRESS: keep the on-bar large text in sync with the estimate
	MI2_UpdateBarTextStrings()
end	 --	MobHealth_Display()


-----------------------------------------------------------------------------
-- SUPPRESS / LARGE TEXT: replace the bars' default TextString
--
-- Blizzard's default target health/mana text cannot be reliably hidden
-- with :Hide(): the game re-shows it on every status bar update, which
-- is why the old Hide-based suppression did not work in game.
-- ShaguTweaks solves this by REPLACING the bar's TextString with its
-- own font string, so the default text has nowhere to show. MobInfo2
-- does the same: while MobInfo2's own health/mana display is on, the
-- bar's TextString is swapped for a MobInfo2-owned font string, and
-- the original is restored when the display is off.
-- The owned strings also carry the optional large health text on the
-- player and target health bars (MobInfoConfig.LargeHealthText).
-----------------------------------------------------------------------------
local MI2_TargetHealthText, MI2_TargetManaText, MI2_PlayerHealthText
local MI2_BarTextStrings = {}  -- [statusBar] = { orig = <original TextString>, owned = <owned font string> }
local MI2_LastBarText = {}     -- [owned font string] = last text set on it
local MI2_BarTextHookInstalled = false

-- SUPPRESS: abbreviate a large number, ShaguTweaks style.
-- 1160 stays "1160", 12500 becomes "12.5k", 1500000 becomes "1.5m".
local function MI2_AbbreviateNumber( value )
	value = math.floor( value + 0.5 )
	if value >= 1000000 then
		return string.format( "%.1fm", value / 1000000 )
	elseif value >= 10000 then
		return string.format( "%.1fk", value / 1000 )
	else
		return tostring( value )
	end
end

-- SUPPRESS: swap a bar's TextString to the MobInfo2-owned string.
-- The original is saved the first time so it can be restored later.
-- NOTE: ShaguTweaks replaces unconditionally (no parent check) and works.
-- The old parent check (MI2_IsDefaultTargetStatusText) blocked the swap
-- in Turtle WoW, so it is gone: adopt whatever TextString the bar has
-- now, unless it is already one of ours. Restore puts it back.
local function MI2_ReplaceBarTextString( statusBar, ownedString )
	local entry = MI2_BarTextStrings[statusBar]
	if  not entry  then
		local current = statusBar.TextString
		if  not current or current == ownedString  then
			return  -- nothing to adopt, or already ours
		end
		entry = { orig = current, owned = ownedString }
		MI2_BarTextStrings[statusBar] = entry
	end
	if  statusBar.TextString == entry.orig  then
		statusBar.TextString = entry.owned
		-- SUPPRESS: the original string was already shown by the game
		-- before the swap, so it stays visible unless hidden here.
		-- Without this the bar shows both the original and ours.
		entry.orig:Hide()
		entry.orig:SetText("")
	end
end

-- SUPPRESS: restore a bar's original TextString (only if it is still ours).
local function MI2_RestoreBarTextString( statusBar )
	local entry = MI2_BarTextStrings[statusBar]
	if  entry and statusBar.TextString == entry.owned  then
		statusBar.TextString = entry.orig
		-- refresh the original's text and show it right away, so the
		-- bar does not stay empty until its value next changes
		TextStatusBar_UpdateTextString( statusBar )
	end
end

-- LARGE TEXT: text for the target health bar, ShaguTweaks style:
-- "cur - pct%" while below max, Abbreviate(cur) at full health.
-- Prefers MobInfo2's own health estimate; falls back to the bar values.
-- Returns "" when there is nothing to show (no target, dead, ghost).
local function MI2_GetTargetBarText()
	if  not UnitExists("target")  then
		return ""
	end
	if  UnitIsDead("target") or UnitIsGhost("target")  then
		return ""
	end
	local cur, max, percent
	if  MI2_Target.showHealth and MI2_Target.curHealth and MI2_Target.maxHealth and MI2_Target.maxHealth > 0  then
		cur = MI2_Target.curHealth
		max = MI2_Target.maxHealth
		percent = MI2_Target.unitHealth or math.floor( 100.0 * cur / max + 0.5 )
	else
		cur = TargetFrameHealthBar:GetValue()
		local _, maxVal = TargetFrameHealthBar:GetMinMaxValues()
		max = maxVal or 0
		if  max > 0  then
			percent = math.floor( cur / max * 100 )
		else
			percent = 0
		end
	end
	if  max == 0  then
		return ""
	end
	if  cur == percent  then
		-- the bar reports percent (0-100), not real health
		return percent .. "%"
	elseif  cur < max  then
		return MI2_AbbreviateNumber(cur) .. " - " .. percent .. "%"
	else
		return MI2_AbbreviateNumber(cur)
	end
end

-- SUPPRESS: set an owned string's text only when it changed, and
-- hide it when empty. Mirrors the PERF change-check in MobHealth_Display.
local function MI2_SetOwnedBarText( ownedString, newText )
	if  MI2_LastBarText[ownedString] ~= newText  then
		MI2_LastBarText[ownedString] = newText
		ownedString:SetText( newText )
	end
	if  newText == ""  then
		ownedString:Hide()
	else
		ownedString:Show()
	end
end

-- SUPPRESS: refresh the text of every bar whose TextString is ours.
-- Called after the game updates a bar, after config changes, and
-- after MobHealth_Display, so the on-bar text stays in sync.
function MI2_UpdateBarTextStrings()
	if  not MI2_TargetHealthText  then
		return  -- not set up yet
	end
	if  TargetFrameHealthBar.TextString == MI2_TargetHealthText  then
		if  MobInfoConfig.LargeHealthText == 1  then
			MI2_SetOwnedBarText( MI2_TargetHealthText, MI2_GetTargetBarText() )
		else
			MI2_SetOwnedBarText( MI2_TargetHealthText, "" )
		end
	end
	if  TargetFrameManaBar.TextString == MI2_TargetManaText  then
		-- suppression only, no large mana text
		MI2_SetOwnedBarText( MI2_TargetManaText, "" )
	end
	if  PlayerFrameHealthBar.TextString == MI2_PlayerHealthText  then
		if  MobInfoConfig.LargeHealthText == 1  then
			MI2_SetOwnedBarText( MI2_PlayerHealthText, MI2_AbbreviateNumber( UnitHealth("player") ) )
		else
			MI2_SetOwnedBarText( MI2_PlayerHealthText, "" )
		end
	end
end

-- SUPPRESS: replace or restore each managed bar's TextString according
-- to the current config. Target bars are replaced while MobInfo2's own
-- health/mana display is on (so the default text has nowhere to
-- show); the player bar is replaced only while LargeHealthText is on.
-- With a separate MobHealth addon present (DisableHealth == 2)
-- MobInfo2's own display is off, so everything is restored.
function MI2_ApplyBarTextStrings()
	if  not MI2_TargetHealthText  then
		return  -- not set up yet
	end
	if  MobInfoConfig.DisableHealth == 2  then
		MI2_RestoreBarTextString( TargetFrameHealthBar )
		MI2_RestoreBarTextString( TargetFrameManaBar )
		MI2_RestoreBarTextString( PlayerFrameHealthBar )
		return
	end
	if  MobInfoConfig.DisableHealth == 0 and (MobInfoConfig.TargetHealth == 1 or MobInfoConfig.HealthPercent == 1)  then
		MI2_ReplaceBarTextString( TargetFrameHealthBar, MI2_TargetHealthText )
	else
		MI2_RestoreBarTextString( TargetFrameHealthBar )
	end
	if  MobInfoConfig.DisableHealth == 0 and (MobInfoConfig.TargetMana == 1 or MobInfoConfig.ManaPercent == 1)  then
		MI2_ReplaceBarTextString( TargetFrameManaBar, MI2_TargetManaText )
	else
		MI2_RestoreBarTextString( TargetFrameManaBar )
	end
	if  MobInfoConfig.LargeHealthText == 1  then
		MI2_ReplaceBarTextString( PlayerFrameHealthBar, MI2_PlayerHealthText )
	else
		MI2_RestoreBarTextString( PlayerFrameHealthBar )
	end
	MI2_UpdateBarTextStrings()
end

-- SUPPRESS: install the TextStatusBar_UpdateTextString hook once.
-- The game writes into bar.TextString after every bar update; for
-- managed bars that is our owned string, so refresh it here. Bars we
-- do not own are left untouched.
local function MI2_InstallBarTextHook()
	if  MI2_BarTextHookInstalled  then
		return
	end
	MI2_BarTextHookInstalled = true
	local originalUpdateTextString = TextStatusBar_UpdateTextString
	TextStatusBar_UpdateTextString = function( statusBar )
		if  not statusBar  then
			statusBar = this
		end
		originalUpdateTextString( statusBar )
		MI2_UpdateBarTextStrings()
	end
end

-- SUPPRESS: create the owned font strings (once), install the hook,
-- and apply the current config. Called from MI2_VariablesLoaded.
-- Font and size match ShaguTweaks (STANDARD_TEXT_FONT, 10, OUTLINE).
function MI2_SetupBarTextStrings()
	if  not MI2_TargetHealthText  then
		local targetTexts = CreateFrame( "Frame", nil, TargetFrame )
		targetTexts:SetAllPoints( TargetFrame )
		MI2_TargetHealthText = targetTexts:CreateFontString( "MI2_TargetHealthBarText", "OVERLAY" )
		MI2_TargetHealthText:SetPoint( "TOP", TargetFrameHealthBar, "BOTTOM", -2, 23 )
		MI2_TargetHealthText:SetFontObject( "GameFontWhite" )
		MI2_TargetHealthText:SetFont( STANDARD_TEXT_FONT, 10, "OUTLINE" )
		MI2_TargetHealthText:SetHeight( 32 )
		MI2_TargetHealthText:SetJustifyH( "CENTER" )
		MI2_TargetManaText = targetTexts:CreateFontString( "MI2_TargetManaBarText", "OVERLAY" )
		MI2_TargetManaText:SetPoint( "TOP", TargetFrameManaBar, "BOTTOM", -2, 22 )
		MI2_TargetManaText:SetFontObject( "GameFontWhite" )
		MI2_TargetManaText:SetFont( STANDARD_TEXT_FONT, 10, "OUTLINE" )
		MI2_TargetManaText:SetHeight( 32 )
		MI2_TargetManaText:SetJustifyH( "CENTER" )
		local playerTexts = CreateFrame( "Frame", nil, PlayerFrame )
		playerTexts:SetAllPoints( PlayerFrame )
		MI2_PlayerHealthText = playerTexts:CreateFontString( "MI2_PlayerHealthBarText", "OVERLAY" )
		MI2_PlayerHealthText:SetPoint( "CENTER", PlayerFrameHealthBar, "CENTER", 0, 0 )
		MI2_PlayerHealthText:SetFontObject( "GameFontWhite" )
		MI2_PlayerHealthText:SetFont( STANDARD_TEXT_FONT, 10, "OUTLINE" )
		MI2_PlayerHealthText:SetHeight( 32 )
		MI2_PlayerHealthText:SetJustifyH( "CENTER" )
	end
	MI2_InstallBarTextHook()
	MI2_ApplyBarTextStrings()
end


-----------------------------------------------------------------------------
-- MI2_MobHealth_SetFont()
--
-- set new font	for	display	of health /	mana in	target frame
-----------------------------------------------------------------------------
local function MI2_MobHealth_SetFont( fontId, fontSize )
	local fontName

	if fontId ~= lOldFontId or fontSize ~= lOldFontSize then
		lOldFontId = fontId
		lOldFontSize = fontSize

		-- select font name	to use	
		if	fontId == 1	 then
			fontName = "Fonts\\ARIALN.TTF"  -- NumberFontNormal
		elseif	fontId == 2	 then
			fontName = "Fonts\\FRIZQT__.TTF"	 --	GameFontNormal
		else
			fontName = "Fonts\\MORPHEUS.TTF"	 --	ItemTextFontNormal
		end

		-- set font	for	health and mana	text
		MI2_MobHealthText:SetFont( fontName, fontSize )
		MI2_MobManaText:SetFont( fontName, fontSize )
		-- PERF: font changed, force the next display to re-set the texts
		lLastHealthText, lLastManaText = nil, nil
	end
  
end	 --	of MI2_MobHealth_SetFont()


-----------------------------------------------------------------------------
-- MI2_MobHealth_SetPos()
--
-- set position	and	font for mob health/mana texts
-----------------------------------------------------------------------------
function MI2_MobHealth_SetPos( )
	local font

	-- set poition for health	and	mana text
	MI2_MobHealthText:SetPoint( "TOP", "TargetFrameHealthBar", "BOTTOM", MobInfoConfig.HealthPosX, MobInfoConfig.HealthPosY )
	MI2_MobManaText:SetPoint( "TOP", "TargetFrameManaBar", "BOTTOM", MobInfoConfig.ManaPosX, MobInfoConfig.ManaPosY )

	-- update	font ID	and	font size
	MI2_MobHealth_SetFont( MobInfoConfig.TargetFont, MobInfoConfig.TargetFontSize	)

	-- redisplay health /	mana values
	MobHealth_Display()

	-- SUPPRESS: re-apply bar TextString replace/restore (config may
	-- have changed, e.g. the LargeHealthText toggle)
	MI2_ApplyBarTextStrings()
end	 --	of MI2_MobHealth_SetPos()


-----------------------------------------------------------------------------
-- MI2_MobHealth_Reset()
-----------------------------------------------------------------------------
function MI2_MobHealth_Reset()
	MI2_MobHealth_ClearTargetData()
	MobHealthDB	= {}
	MobHealthPlayerDB =	{}
end


-----------------------------------------------------------------------------
-- MI2_SaveTargetHealthData()
--
-- Save health data for current target in health database
-----------------------------------------------------------------------------
function MI2_SaveTargetHealthData()
	if MI2_Target.index and MI2_Target.totalPercent > 0 and MI2_Target.totalPercent < 10000 then
		MobHealth_Set( MI2_Target.healthDB, MI2_Target.index, MI2_Target.totalDamage, MI2_Target.totalPercent )
	end
end -- MI2_SaveTargetHealthData()


-----------------------------------------------------------------------------
-- MI2_MobHealth_ClearTargetData()
--
-- Clear mob health data for current target
-----------------------------------------------------------------------------
function MI2_MobHealth_ClearTargetData()
	if MI2_Target.index then
		MI2_Target.healthDB[MI2_Target.index] = nil
		MI2_Target = {}
		MobHealth_Display()
	end
end  -- MI2_MobHealth_ClearTargetData()

