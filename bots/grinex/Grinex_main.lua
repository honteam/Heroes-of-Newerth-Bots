-----------------------------------------------------
--   _____      _                 ____        _    --
--  / ____|    (_)               |  _ \      | |   --
-- | |  __ _ __ _ _ __   _____  _| |_) | ___ | |_  --
-- | | |_ | '__| | '_ \ / _ \ \/ /  _ < / _ \| __| --
-- | |__| | |  | | | | |  __/>  <| |_) | (_) | |_  --
--  \_____|_|  |_|_| |_|\___/_/\_\____/ \___/ \__| --
--                          -By: DarkFire-         --
-----------------------------------------------------

------------------------------------------
--          Bot Initialization          --
------------------------------------------

local _G = getfenv(0)
local object = _G.object

object.myName = object:GetName()

object.bRunLogic = true
object.bRunBehaviors = true
object.bUpdates = true
object.bUseShop = true

object.bRunCommands = true 
object.bMoveCommands = true
object.bAttackCommands = true
object.bAbilityCommands = true
object.bOtherCommands = true

object.bReportBehavior = false
object.bDebugUtility = false

object.logger = {}
object.logger.bWriteLog = false
object.logger.bVerboseLog = false

object.core = {}
object.eventsLib = {}
object.metadata = {}
object.behaviorLib = {}
object.skills = {}

runfile "bots/core.lua"
runfile "bots/botbraincore.lua"
runfile "bots/eventsLib.lua"
runfile "bots/metadata.lua"
runfile "bots/behaviorLib.lua"

local core, eventsLib, behaviorLib, metadata, skills = object.core, object.eventsLib, object.behaviorLib, object.metadata, object.skills

local print, ipairs, pairs, string, table, next, type, tinsert, tremove, tsort, format, tostring, tonumber, strfind, strsub
	= _G.print, _G.ipairs, _G.pairs, _G.string, _G.table, _G.next, _G.type, _G.table.insert, _G.table.remove, _G.table.sort, _G.string.format, _G.tostring, _G.tonumber, _G.string.find, _G.string.sub
local ceil, floor, pi, tan, atan, atan2, abs, cos, sin, acos, asin, max, random
	= _G.math.ceil, _G.math.floor, _G.math.pi, _G.math.tan, _G.math.atan, _G.math.atan2, _G.math.abs, _G.math.cos, _G.math.sin, _G.math.acos, _G.math.asin, _G.math.max, _G.math.random

local BotEcho, VerboseLog, BotLog = core.BotEcho, core.VerboseLog, core.BotLog
local Clamp = core.Clamp

BotEcho('loading Grinex_main...')

---------------------------------
--          Constants          --
---------------------------------

-- Grinex
object.heroName = 'Hero_Grinex'

-- Lane Preferences
core.tLanePreferences = {
	Jungle = 0,
	Mid = 2, 
	ShortSolo = 3, 
	LongSolo = 1, 
	ShortSupport = 3, 
	LongSupport = 3, 
	ShortCarry = 4, 
	LongCarry = 5
}

-- Item buy order. internal names  
behaviorLib.StartingItems = {"Item_IronBuckler", "Item_RunesOfTheBlight", "Item_LoggersHatchet"}
behaviorLib.LaneItems = {"Item_Marchers", "Item_Steamboots", "Item_Lightbrand", "Item_Searinglight"}
behaviorLib.MidItems = {"Item_Pierce 3", "Item_Critical1 4"}
behaviorLib.LateItems = {"Item_Weapon3", "Item_DaemonicBreastplate"}

-- Skillbuild table, 0=q, 1=w, 2=e, 3=r, 4=attri
object.tSkills = {
	0, 2, 2, 1, 2,
	3, 2, 0, 0, 0,
	3, 1, 1, 1, 4,
	3, 4, 4, 4, 4,
	4, 4, 4, 4, 4
}

-- Bonus agression points if a skill/item is available for use

object.nStepUp = 20
object.nStalkUp = 12
object.nAssaultUp = 38

object.nStrike1Up = 6
object.nStrike2Up = 9
object.nStrike3Up = 13
object.nStrike4Up = 18

-- Bonus agression points that are applied to the bot upon successfully using a skill/item

object.nStepUse = 30
object.nStalkUse = 20
object.nAssaultUse = 44

-- Thresholds of aggression the bot must reach to use these abilities

object.nStepThreshold = 28
object.nStalkThreshold = 22
object.nAssaultThreshold = 48

-- Other variables

behaviorLib.nCreepPushbackMul = 0.5
behaviorLib.nTargetPositioningMul = 0.6

------------------------------
--          Skills          --
------------------------------

function object:SkillBuild()
	local unitSelf = self.core.unitSelf
	if  skills.abilStep == nil then
		skills.abilStep = unitSelf:GetAbility(0)
		skills.abilStalk = unitSelf:GetAbility(1)
		skills.abilStrike = unitSelf:GetAbility(2)
		skills.abilAssault = unitSelf:GetAbility(3)
		skills.abilAttributeBoost = unitSelf:GetAbility(4)
	end
	
	local nPoints = unitSelf:GetAbilityPointsAvailable()
	if nPoints <= 0 then
		return
	end
	
	local nLevel = unitSelf:GetLevel()
	for i = nLevel, (nLevel + nPoints) do
		unitSelf:GetAbility( self.tSkills[i] ):LevelUp()
	end
end

----------------------------------------
--          OnThink Override          --
----------------------------------------

function object:onthinkOverride(tGameVariables)
	self:onthinkOld(tGameVariables)

	-- Toggle Steamboots for more Health/Mana
	local itemSteamboots = core.GetItem("Item_Steamboots")
	if itemSteamboots and itemSteamboots:CanActivate() then
		local unitSelf = core.unitSelf
		local nHealthPercent = unitSelf:GetHealthPercent()
		local nManaPercent = unitSelf:GetManaPercent()
		local sKey = itemSteamboots:GetActiveModifierKey()
		if sKey == "str" then
			-- Toggle away from STR if health is high enough
			if nHealthPercent > .65 then
				self:OrderItem(itemSteamboots.object, false)
			end
		elseif sKey == "agi" then
			-- Toggle away from AGI if health or mana is low
			if nHealthPercent < .45 or nManaPercent < .6 then
				self:OrderItem(itemSteamboots.object, false)
			end
		elseif sKey == "int" then
			-- Toggle away from INT if health gets too low or mana is close to full
			if nHealthPercent < .45 or nManaPercent > .85 then
				self:OrderItem(itemSteamboots.object, false)
			end
		end
	end
end

object.onthinkOld = object.onthink
object.onthink = object.onthinkOverride

----------------------------------------------
--          OnCombatEvent Override          --
----------------------------------------------

function object:oncombateventOverride(EventData)
	self:oncombateventOld(EventData)

	local nAddBonus = 0
	if EventData.Type == "Ability" then
		if EventData.InflictorName == "Ability_Grinex1" then
			nAddBonus = nAddBonus + self.nStepUse
		elseif EventData.InflictorName == "Ability_Grinex2" then
			nAddBonus = nAddBonus + self.nStalkUse
		elseif EventData.InflictorName == "Ability_Grinex4" then
			nAddBonus = nAddBonus + self.nAssaultUse
		end
	end
 
	if nAddBonus > 0 then
		core.DecayBonus(self)
		core.nHarassBonus = core.nHarassBonus + nAddBonus
	end
end

object.oncombateventOld = object.oncombatevent
object.oncombatevent = object.oncombateventOverride

----------------------------------------------------
--          CustomHarassUtility Override          --
----------------------------------------------------

local function CustomHarassUtilityFnOverride(hero)
	local nUtility = 0
	
	if skills.abilStep:CanActivate() then
		nUtility = nUtility + object.nStepUp
	end
	
	if skills.abilStalk:CanActivate() then
		nUtility = nUtility + object.nStalkUp
	end
	
	if skills.abilAssault:CanActivate() then
		nUtility = nUtility + object.nAssaultUp
	end

	-- Use diiferent Utility values for each level of Nether Strike
	local nStrikeLevel = skills.abilStrike:GetLevel()
	if nStrikeLevel == 1 then
		nUtility = nUtility + object.nStrike1Up
	elseif nStrikeLevel == 2 then
		nUtility = nUtility + object.nStrike2Up
	elseif nStrikeLevel == 3 then
		nUtility = nUtility + object.nStrike3Up
	elseif nStrikeLevel == 4 then
		nUtility = nUtility + object.nStrike4Up
	end
	
	return nUtility
end

behaviorLib.CustomHarassUtility = CustomHarassUtilityFnOverride   

-----------------------------------------
--          Shadow Step Logic          --
-----------------------------------------

-- Filters a group to be within a given range. Modified from St0l3n_ID's Chronos bot
local function filterGroupRange(tGroup, vecCenter, nRange)
	if tGroup and vecCenter and nRange then
		local tResult = {}
		for _, unitTarget in pairs(tGroup) do
			if Vector3.Distance2DSq(unitTarget:GetPosition(), vecCenter) <= (nRange * nRange) then
				tinsert(tResult, unitTarget)
			end
		end	
	
		if #tResult > 0 then
			return tResult
		end
	end
	
	return nil
end

-- Cycles through the table to find the closest target to the position, then returns the direction to that target
-- Used for casting entity vector skills towards a moving target
local function getBestPushDirectionFromTable(unitPushTarget, vecPushTargetPosition, tUnitTable)
	local nDistanceSq = nil
	local nBestDistanceSq = (375 * 375)
	local vecTargetPosition = nil
	local vecBestTargetPosition = nil
	local unitBestTarget = nil

	-- Find the closest unit from tUnitTable
	for _, unitHitTarget in pairs(tUnitTable) do
		vecTargetPosition = unitHitTarget:GetPosition()
		nDistanceSq = Vector3.Distance2DSq(vecPushTargetPosition, vecTargetPosition)
		if nDistanceSq <= nBestDistanceSq and unitHitTarget ~= unitPushTarget then
			vecBestTargetPosition = vecTargetPosition
			nBestDistanceSq = nDistanceSq
			unitBestTarget = unitHitTarget
		end
	end

	if unitBestTarget and vecBestTargetPosition then
		-- Reserve full prediction for hard mode bots
		if core.nDifficulty ~= core.nHARD_DIFFICULTY or not unitBestTarget.bIsMemoryUnit then
			return Vector3.Normalize(vecBestTargetPosition - vecPushTargetPosition)
		else
			local vecBestTargetHeading = Vector3.Normalize(unitBestTarget.storedPosition - unitBestTarget.lastStoredPosition)
			return Vector3.Normalize(vecBestTargetPosition + vecBestTargetHeading * 110 - vecPushTargetPosition)
		end
	end
	
	return nil
end

-- Find the best direction to cast Shadow Step
local function getStepDirection(botBrain, unitTarget)
	local vecDirection = nil
	local vecTargetPosition = unitTarget:GetPosition()
	
	-- No prediction for easy mode bots
	if core.nDifficulty ~= core.nEASY_DIFFCULTY and unitTarget.bIsMemoryUnit then
		local vecTargetHeading = unitTarget:GetHeading() or Vector3.Create()
		vecTargetPosition = vecTargetPosition + vecTargetHeading * 85
	end

	local tLocalUnits = core.localUnits
	if tLocalUnits then
		-- Check Enemy Heroes
		if not vecDirection then
			local tLocalEnemyHeroes = filterGroupRange(tLocalUnits["EnemyHeroes"], vecTargetPosition, 375)
			if core.NumberElements(tLocalEnemyHeroes) > 1 then
				vecDirection = getBestPushDirectionFromTable(unitTarget, vecTargetPosition, tLocalEnemyHeroes)
			end
		end
		
		-- Check Allied Heroes
		if not vecDirection then
			local tLocalAllyHeroes = filterGroupRange(tLocalUnits["AllyHeroes"], vecTargetPosition, 375)
			if core.NumberElements(tLocalAllyHeroes) > 0 then
				vecDirection = getBestPushDirectionFromTable(unitTarget, vecTargetPosition, tLocalAllyHeroes)
			end
		end
		
		-- Check Enemy Buildings
		if not vecDirection then
			local tLocalEnemyBuildings = filterGroupRange(tLocalUnits["EnemyBuildings"], vecTargetPosition, 375)
			if core.NumberElements(tLocalEnemyBuildings) > 0 then
				vecDirection = getBestPushDirectionFromTable(unitTarget, vecTargetPosition, tLocalEnemyBuildings)
			end
		end
		
		-- Check Allied Buildings
		if not vecDirection then
			local tLocalAllyBuildings = filterGroupRange(tLocalUnits["AllyBuildings"], vecTargetPosition, 375)
			if core.NumberElements(tLocalAllyBuildings) > 0 then
				vecDirection = getBestPushDirectionFromTable(unitTarget, vecTargetPosition, tLocalAllyBuildings)
			end
		end
	end
	
	-- Check Trees
	if not vecDirection then
		local tLocalTrees = HoN.GetTreesInRadius(vecTargetPosition, 375)
		if tLocalTrees then
			if core.NumberElements(tLocalTrees) > 0 then
				vecDirection = getBestPushDirectionFromTable(unitTarget, vecTargetPosition, tLocalTrees)
			end
		end
	end 

	-- Cliff checking would go here if it were possible
	
	-- Push Towards Ally Well
	if not vecDirection then
		local unitAllyWell = core.allyWell
		if unitAllyWell then
			vecDirection = Vector3.Normalize(unitAllyWell:GetPosition() - vecTargetPosition)
		end
	end

	return vecDirection
end

----------------------------------------------
--          Illusory Assault Logic          --
----------------------------------------------

local function getAssaultDamage()
	local nSkillLevel = skills.abilAssault:GetLevel()

	if nSkillLevel == 1 then
		return 200
	elseif nSkillLevel == 2 then
		return 360
	elseif nSkillLevel == 3 then
		return 560
	else
		return nil
	end
end

-----------------------------------
--          Combo Logic          --
-----------------------------------

local function getComboManaCost()
	local nCost = skills.abilStalk:GetManaCost()
	
	local abilStep = skills.abilStep
	if abilStep:GetLevel() > 0 then
		nCost = nCost + abilStep:GetManaCost()
	end
	
	local abilAssault = skills.abilAssault
	if abilAssault:GetLevel() > 0 and abilAssault:CanActivate() then
		nCost = nCost + abilAssault:GetManaCost()
	end
	
	return nCost
end

---------------------------------------
--          Harass Behavior          --
---------------------------------------

local function HarassHeroExecuteOverride(botBrain)
	
	local unitTarget = behaviorLib.heroTarget
	if unitTarget == nil then
		return object.harassExecuteOld(botBrain)
	end
	
	local unitSelf = core.unitSelf
	local vecMyPosition = unitSelf:GetPosition()
	
	local vecTargetPosition = unitTarget:GetPosition()
	local nTargetDistanceSq = Vector3.Distance2DSq(vecMyPosition, vecTargetPosition)
	local bCanSeeTarget = core.CanSeeUnit(botBrain, unitTarget)
	local nTargetPhysicalEHP = 9999
	if bCanSeeTarget then
		nTargetPhysicalEHP = unitTarget:GetHealth() / (1 - unitTarget:GetPhysicalResistance())
	end
	
	local nLastHarassUtility = behaviorLib.lastHarassUtil
	local bActionTaken = false
	
	-- Stop the bot from trying to harass heroes while dead
	if not bActionTaken and not unitSelf:IsAlive() then
		bActionTaken = true
	end
	
	-- Don't cast spells while the bot has the Nether Strike buff
	if unitSelf:HasState("State_Grinex_Ability3") then
		return object.harassExecuteOld(botBrain)
	end
	
	-- Rift Stalk (Out of Shadow Step range)
	if not bActionTaken then
		local abilStalk = skills.abilStalk
		if abilStalk:CanActivate() and nLastHarassUtility > object.nStalkThreshold and bCanSeeTarget and ((nTargetDistanceSq > (450 * 450) and unitSelf:GetMana() > getComboManaCost()) or nTargetPhysicalEHP < (core.GetFinalAttackDamageAverage(unitSelf) * 2)) then
			bActionTaken = core.OrderAbility(botBrain, abilStalk)
		end
	end
	
	-- Shadow Step
	if not bActionTaken then
		local abilStep = skills.abilStep
		if abilStep:CanActivate() and bCanSeeTarget and not unitTarget:IsStunned() and nLastHarassUtility > object.nStepThreshold and nTargetDistanceSq < (450 * 450) then
			local vecPushDirection = getStepDirection(botBrain, unitTarget)
			if vecPushDirection then
				bActionTaken = core.OrderAbilityEntityVector(botBrain, abilStep, unitTarget, vecPushDirection * 100)
			end
		end
	end	
	
	-- Illusory Assault
	if not bActionTaken then
		local abilAssault = skills.abilAssault
		if abilAssault:CanActivate() and nLastHarassUtility > object.nAssaultThreshold and (nTargetDistanceSq < (300 * 300) or (nTargetDistanceSq < (1200 * 1200) and nTargetPhysicalEHP < getAssaultDamage())) then
			bActionTaken = core.OrderAbility(botBrain, abilAssault)
		end
	end
	
	-- Rift Stalk (In Shadow Step range)
	if not bActionTaken then
		local abilStalk = skills.abilStalk
		if abilStalk:CanActivate() and nLastHarassUtility > object.nStalkThreshold then
			-- Don't use if Shadow Step is up
			local abilStep = skills.abilStep
			if not abilStep:CanActivate() then
				bActionTaken = core.OrderAbility(botBrain, abilStalk)
			end
		end
	end

	if not bActionTaken then
		return object.harassExecuteOld(botBrain)
	end
	
	return bActionTaken
end

object.harassExecuteOld = behaviorLib.HarassHeroBehavior["Execute"]
behaviorLib.HarassHeroBehavior["Execute"] = HarassHeroExecuteOverride

--------------------------------------------------
--          RetreatFromThreat Override          --
--------------------------------------------------

local function funcRetreatFromThreatExecuteOverride(botBrain)
	local bActionTaken = false
	local nHealthPercent = core.unitSelf:GetHealthPercent()
	
	-- Use Rift Stalk to retreat if possible
	if not core.unitSelf:HasState("State_Grinex_Ability2") then
		local abilStalk = skills.abilStalk
		if abilStalk:CanActivate() and nHealthPercent < .625 then
			bActionTaken = core.OrderAbility(botBrain, abilStalk)
		end

		local abilAssault = skills.abilAssault
		if abilAssault:CanActivate() and nHealthPercent < .25 then
				bActionTaken = core.OrderAbility(botBrain, abilAssault)
		end
	end
	
	if not bActionTaken then
		return object.RetreatFromThreatExecuteOld(botBrain)
	end
end

object.RetreatFromThreatExecuteOld = behaviorLib.RetreatFromThreatExecute
behaviorLib.RetreatFromThreatBehavior["Execute"] = funcRetreatFromThreatExecuteOverride

-------------------------------------------------
--          HealAtWellExecute Overide          --
-------------------------------------------------

local function HealAtWellOveride(botBrain)
	local bActionTaken = false
 
	-- Use Rift Stalk on way to well
	local abilStalk = skills.abilStalk
	if abilStalk:CanActivate() and Vector3.Distance2DSq(core.unitSelf:GetPosition(), core.allyWell:GetPosition()) > (1000 * 1000) then
		bActionTaken = core.OrderAbility(botBrain, abilStalk)
	end
 
	if not bActionTaken then
		return object.HealAtWellBehaviorOld(botBrain)
	end
end

object.HealAtWellBehaviorOld = behaviorLib.HealAtWellBehavior["Execute"]
behaviorLib.HealAtWellBehavior["Execute"] = HealAtWellOveride

BotEcho(object:GetName()..' finished loading Grinex_main')
