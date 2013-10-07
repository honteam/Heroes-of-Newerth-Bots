--------------------------------------------------------------
-- Hiruma's Valk Bot v 1.0
--------------------------------------------------------------

--------------------------------------------------------------
--	Bot initiation boilerplate
--------------------------------------------------------------

local _G = getfenv(0)
local object = _G.object

object.myName = object:GetName()

object.bRunLogic		= true
object.bRunBehaviors	= true
object.bUpdates			= true
object.bUseShop			= true

object.bRunCommands		= true 
object.bMoveCommands	= true
object.bAttackCommands	= true
object.bAbilityCommands	= true
object.bOtherCommands	= true

object.bReportBehavior	= false
object.bDebugUtility	= false

object.logger = {}
object.logger.bWriteLog = false
object.logger.bVerboseLog = false

object.core	= {}
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
local ceil, floor, pi, tan, atan, atan2, abs, cos, sin, acos, max, random
	= _G.math.ceil, _G.math.floor, _G.math.pi, _G.math.tan, _G.math.atan, _G.math.atan2, _G.math.abs, _G.math.cos, _G.math.sin, _G.math.acos, _G.math.max, _G.math.random

local BotEcho, VerboseLog, BotLog = core.BotEcho, core.VerboseLog, core.BotLog
local Clamp = core.Clamp

local sqrtTwo = math.sqrt(2) -- sqrt!

BotEcho(object:GetName()..' loading valkyrie_main...')

--------------------------------------------------------------
-- Bot constant definitions
--------------------------------------------------------------

-- Set the object's hero name
object.heroName = 'Hero_Valkyrie'

-- Item buy list
behaviorLib.StartingItems  = 
			{"Item_RunesOfTheBlight", "2 Item_MinorTotem", "Item_HealthPotion", "2 Item_DuckBoots"}
behaviorLib.LaneItems  = 
			{"Item_PowerSupply", "Item_Steamboots", "Item_MysticVestments", "Item_HomecomingStone"}
behaviorLib.MidItems  = 
			{"Item_Soulscream", "Item_Energizer", "Item_Lightbrand"} -- StrengthAgility == Frostburn
behaviorLib.LateItems  = 
			{"Item_Dawnbringer", "Item_ManaBurn1 2", "Item_Weapon3", "Item_Evasion"} -- ManaBurn1 == Nullfire Blade, Weapon3 == Savage Mace
																					-- Evasion == Wingbow

-- Skillbuild table, 0=q, 1=w, 2=e, 3=r, 4=attri
object.tSkills = {
	2, 1, 0, 0, 0,
	1, 0, 1, 1, 3, 
	3, 2, 2, 2, 4,
	3, 4, 4, 4, 4,
	4, 4, 4, 4, 4,
}

-- Bonus agression points if a skill/item is available for use
object.nCallUp = 25
object.nArrowUp = 30
object.nLeapUp = 30
object.nUltUp = 15
object.nEnergUp = 10

-- Bonus agression points that are applied to the bot upon successfully using a skill/item
object.nCallUse = 35
object.nArrowUse = 40
object.nLeapUse = 10
object.nUltUse = 0
object.nEnergUse = 10

-- Thresholds of aggression the bot must reach to use these abilities
object.nCallThreshold = 30
object.nArrowThreshold = 25
object.nLeapThreshold = 95
object.nUltThreshold = 30
object.nEnergThreshold = 35
object.nNullThreshold = 45

-- Used to track game time, initialized at 0 to avoid invalid operations
object.nTime = 0

--------------------------------------------------------------
-- Skillbuild function override, ensures proper selection of
-- skills based on object.tSkills
--------------------------------------------------------------
-- @param: 	none
-- @return:	none
function object:SkillBuild()
	core.VerboseLog("skillbuild()")

-- takes care at load/reload, <name_#> to be replaced by some convinient name.
	local unitSelf = self.core.unitSelf
	if  skills.abilCall == nil then
		skills.abilCall = unitSelf:GetAbility(0)
		skills.abilArrow = unitSelf:GetAbility(1)
		skills.abilLeap = unitSelf:GetAbility(2)
		skills.abilUlt = unitSelf:GetAbility(3)
		skills.abilAttributeBoost = unitSelf:GetAbility(4)
	end
	if unitSelf:GetAbilityPointsAvailable() <= 0 then
		return
	end


	local nlev = unitSelf:GetLevel()
	local nlevpts = unitSelf:GetAbilityPointsAvailable()
	for i = nlev, nlev+nlevpts do
	unitSelf:GetAbility( object.tSkills[i] ):LevelUp()
	end
end

--------------------------------------------------------------
-- FindItemsOverride
-- Used to wrap energizer, power supply, mana battery and
-- nullfire for use later
--------------------------------------------------------------
-- @param:	botBrain
local function funcFindItemsOverride(botBrain)
	local bUpdated = object.FindItemsOld(botBrain)

	if core.itemEnergize ~= nil and not core.itemEnergize:IsValid() then
		core.itemEnergize = nil
	end
	if core.itemPowSup ~= nil and not core.itemPowSup:IsValid() then
		core.itemPowSup = nil
	end
	if core.itemManaBat ~= nil and not core.itemManaBat:IsValid() then
		core.itemManaBat = nil
	end
	if core.itemNullfire ~= nil and not core.itemNullfire:IsValid() then
		core.itemNullfire = nil
	end
	if bUpdated then
		--only update if we need to
		if core.itemEnergize and core.itemPowSup and core.itemManaBat then
			return
		end

		local inventory = core.unitSelf:GetInventory(true)
			for slot = 1, 12, 1 do
			local curItem = inventory[slot]
			if curItem then
				if core.itemEnergize == nil and curItem:GetName() == "Item_Energizer" then
					core.itemEnergize = core.WrapInTable(curItem)
				end
				if core.itemPowSup == nil and curItem:GetName() == "Item_PowerSupply" then
					core.itemPowSup = core.WrapInTable(curItem)
				end
				if core.itemManaBat == nil and curItem:GetName() == "Item_ManaBattery" then
					core.itemManaBat = core.WrapInTable(curItem)
				end
				if core.itemNullfire == nil and curItem:GetName() == "Item_ManaBurn1" then
					core.itemNullfire = core.WrapInTable(curItem)
				end
			end
		end
	end
end
object.FindItemsOld = core.FindItems
core.FindItems = funcFindItemsOverride
 
--------------------------------------------------------------
-- onthinkOverride, doesn't do anything right now.
-- Just absolutely nothing.
--------------------------------------------------------------
-- @param: tGameVariables
-- @return: none
function object:onthinkOverride(tGameVariables)
	self:onthinkOld(tGameVariables)
	
end

object.onthinkOld = object.onthink
object.onthink  = object.onthinkOverride
 
 
--------------------------------------------------------------
-- oncombateventOverride, this function is used to add
-- aggression points  when an ability is used and junk
--------------------------------------------------------------
-- @param: eventdata
-- @return: none
function object:oncombateventOverride(EventData)
	self:oncombateventOld(EventData)
	local nAddBonus = 0
	
	if EventData.Type == "Ability" then
		if EventData.InflictorName == "Ability_Valkyrie1" then
			nAddBonus = nAddBonus + object.nCallUse
		elseif EventData.InflictorName == "Ability_Valkyrie2" then
			nAddBonus = nAddBonus + object.nArrowUse
		elseif EventData.InflictorName == "Ability_Valkyrie3" then
			nAddBonus = nAddBonus + object.nLeapUse
		elseif EventData.InflictorName == "Ability_Valkyrie4" then
			nAddBonus = nAddBonus + object.nUltUse
		end
	elseif EventData.Type == "Item" then
		if core.itemEnergize ~= nil and EventData.SourceUnit == core.unitSelf:GetUniqueID() then
			nAddBonus = nAddBonus + self.nEnergUse
		end
	end
	
	if nAddBonus > 0 then
		core.DecayBonus(self)
		core.nHarassBonus = core.nHarassBonus + nAddBonus
	end
end
-- override combat event trigger function.
object.oncombateventOld = object.oncombatevent
object.oncombatevent = object.oncombateventOverride

--------------------------------------------------------------
-- CustomHarassUtilityFnOverride, all this currently does
-- is provide bonuses for having skills available for use
--------------------------------------------------------------
-- @param:  iunitentity hero
-- @return: number
local function CustomHarassUtilityFnOverride(hero)
	local nUtil = 0

	if skills.abilQ:CanActivate() then
		nUtil = nUtil + object.nCallUp
	end
	if skills.abilW:CanActivate() then
		nUtil = nUtil + object.nArrowUp
	end
	if skills.abilE:CanActivate() then
		nUtil = nUtil + object.nLeapUp
	end
	if skills.abilR:CanActivate() then
		nUtil = nUtil + object.nUltUp
	end
	if object.itemEnergize and object.itemEnergize:CanActivate() then
		nUtil = nUtil + object.nEnergUp
	end

	return nUtil
end
-- assisgn custom Harrass function to the behaviourLib object
behaviorLib.CustomHarassUtilityFn = CustomHarassUtilityFnOverride   

--------------------------------------------------------------
-- ClearToTarget function
-- Original authorship credit to [S2]BlacRyu
--------------------------------------------------------------
-- @param: 	vecOrigin - the source of the skillshot
--			vecTarget - the target's position vector
--			tCandidates - a table of candidates the skillshot
--					could collide with
--			nDistanceThreshold - the hit radius of the
--					skillshot
-- @return: true if clear path exists, otherwise false
function ClearToTarget(vecOrigin, vecTarget, tCandidates, nDistanceThreshold)
	local bDebugLines = false
	
	local nOriginToTargetDistanceSq = Vector3.Distance2DSq(vecOrigin, vecTarget)
	local nDistanceThresholdSq = nDistanceThreshold * nDistanceThreshold
	for index, candidate in pairs(tCandidates) do
		-- If the candidate unit is farther away than the target position, skip it
		if candidate and candidate:GetPosition() ~= vecTarget and Vector3.Distance2DSq(vecOrigin, candidate:GetPosition()) < nOriginToTargetDistanceSq then
			-- Nearest, furthest, what's the difference?
			local vecNearestPointOnLine = core.GetFurthestPointOnLine(candidate:GetPosition(), vecOrigin, vecTarget)
			local nCandidateRadius = candidate:GetBoundsRadius() * sqrtTwo -- not sure if this multiply is necessary, but it's better to overestimate here
			local nCandidateRadiusSq = nCandidateRadius * nCandidateRadius
			
			if Vector3.Distance2DSq(candidate:GetPosition(), vecNearestPointOnLine) <= nDistanceThresholdSq + nCandidateRadiusSq then
			
				if bDebugLines then
					core.DrawXPosition(candidate:GetPosition(), 'red')
					core.DrawDebugLine(vecOrigin, candidate:GetPosition(), 'red')
				end
				
				return false
			end
		end
	end
	if bDebugLines then
		core.DrawXPosition(vecTarget, 'green')
		core.DrawDebugLine(vecOrigin, vecTarget, 'green')
	end
	return true
end

--------------------------------------------------------------
-- DangerClose
-- Determines whether or not an ability should be used based
-- on enemy hero positioning
--------------------------------------------------------------
-- @param:	vecHero - the hero's current position
--			tEnemyHeroes - A table of all enemy heroes
--			nType - A type flag for which kind of check we are
--			making. 0 is for an ult check, 1 is for a defensive
--			check, 2 is for a Call check
-- @return:	true - if an enemy is found to be close
--			false - if no enemy is within a dangerous range
function DangerClose(vecHero, tEnemyHeroes, nType)
	local nDangerCloseDefSqd = 650 * 650
	local nDangerCloseOffSqd = 900 * 900
	local nEnemyNum1 = 0
	local nEnemyNum2 = 0
	local nDangerDist = 0

	for index, danger in pairs(tEnemyHeroes) do
		local dangerpos = danger:GetPosition()
		if dangerpos then
			nDangerDist = Vector3.Distance2DSq(vecHero, dangerpos)
		end
		if danger and nDangerDist <= nDangerCloseOffSqd and nType == 0 then
			nEnemyNum1 = nEnemyNum1 + 1
			if nEnemyNum1 >= 3 then
				return true
			end
		elseif danger and nDangerDist <= nDangerCloseDefSqd and nType == 1 then
			return true
		elseif danger and nDangerDist <= nDangerCloseOffSqd and nType == 2 then
			nEnemyNum2 = nEnemyNum2 + 1
			if nEnemyNum2 >= 2 then
				return true
			end
		end
	end
	
	return false
end

--------------------------------------------------------------
-- TurnTheShip
-- Used to turn heroes and ensure proper facing before
-- taking facing-reliant actions, such as Leap
--------------------------------------------------------------
-- @params:	botBrain, passed in from either retreat or harass
--			fuctions
--			vecHero, the hero's position vector
--			vecEnemy, enemy's position vector
--			nType, 0 if an offensive turn and 1 if a 
--			defensive turn
-- @return:	true once turn delay has triggered
--			false if something has gone terribly wrong
function TurnTheShip(botBrain, vecHero, vecEnemy, nType)
	local unitSelf = core.unitSelf
	local nDelay = 300
	local vecNegEnemy = vecEnemy * -1
	local bActionTaken = false
	local nCurTime = 0
	object.nTime = HoN.GetGameTime()
	
	if nType == 0 then
		bActionTaken = core.OrderMoveToUnitClamp(botBrain, unitSelf, vecEnemy)
	end
	if nType == 1 then
		bActionTaken = core.OrderMoveToUnitClamp(botBrain, unitSelf, vecNegEnemy)
	end
	
	for nCurTime = HoN.GetGameTime(), object.nTime + 500 do
		if nCurTime - object.nTime >= nDelay then
			return true
		end
		nCurTime = HoN.GetGameTime()
	end
	
	return false
end
		
	
	
--------------------------------------------------------------
-- Function to determine the utility of using Prism,
-- followed by the execution of Prism
--------------------------------------------------------------
function behaviorLib.PrismUtility(botBrain)
	local nUtility = 0
	local nHowToSaveALife = 40
	local abilUlt = skills.abilUlt
	local nBadIdea = 1

	if abilUlt:CanActivate() then
		local tAllies = HoN.GetHeroes(core.myTeam)
		for index, health in pairs(tAllies) do
			local lowhealth = health:GetHealthPercent()
			if lowhealth <= 0.4 and lowhealth > 0 then
				local vecAlly = health:GetPosition()
				local tEnemies = HoN.GetHeroes(core.enemyTeam)
				if DangerClose(vecAlly, tEnemies, 1) then
					nUtility = nHowToSaveALife
					return nUtility
				end
			end
		end
	end
	
	nUtility = nBadIdea
	
	return nUtility
end

function behaviorLib.PrismExecute(botBrain)
	local abilUlt = skills.abilUlt
	
	if abilUlt:CanActivate() then
		core.OrderAbility(botBrain, abilUlt)
	end
end

behaviorLib.PrismBehavior = {}
behaviorLib.PrismBehavior["Utility"] = behaviorLib.PrismUtility
behaviorLib.PrismBehavior["Execute"] = behaviorLib.PrismExecute
behaviorLib.PrismBehavior["Name"] = "Prism"
tinsert(behaviorLib.tBehaviors, behaviorLib.PrismBehavior)

--------------------------------------------------------------
-- Utility and execution for power supply
--------------------------------------------------------------
function behaviorLib.PowSupUtility(botBrain)
	local nUtility = 0
	local nPowerUse = 40
	local itemPowSup = core.itemPowSup
	local unitSelf = core.unitSelf
	local nBadIdea = 1

	if itemPowSup and itemPowSup:CanActivate() then
		local nHPercent = unitSelf:GetHealthPercent()
		local nMPercent = unitSelf:GetManaPercent()
		if nHPercent <= 0.5 and itemPowSup:GetCharges() >= 10 then
			nUtility = nPowerUse
			return nUtility
		elseif nMPercent <= 0.6 and itemPowSup:GetCharges() >= 10 then
			nUtility = nPowerUse
			return nUtility
		elseif nHPercent <= 0.2 and itemPowSup:GetCharges() >= 1 then
			nUtility = nPowerUse
			return nUtility
		end
	end
	
	nUtility = nBadIdea
	
	return nUtility
end

function behaviorLib.PowSupExecute(botBrain)
	local itemPowSup = core.itemPowSup
	
	if itemPowSup:CanActivate() then
		core.OrderItemClamp(botBrain, unitSelf, itemPowSup)
	end
end

behaviorLib.PowSupBehavior = {}
behaviorLib.PowSupBehavior["Utility"] = behaviorLib.PowSupUtility
behaviorLib.PowSupBehavior["Execute"] = behaviorLib.PowSupExecute
behaviorLib.PowSupBehavior["Name"] = "PowSup"
tinsert(behaviorLib.tBehaviors, behaviorLib.PowSupBehavior)

--------------------------------------------------------------
-- Utility and execution for mana battery
--------------------------------------------------------------
function behaviorLib.ManaBatUtility(botBrain)
	local nUtility = 0
	local nBatUse = 40
	local itemManaBat = core.itemManaBat
	local unitSelf = core.unitSelf
	local nBadIdea = 1

	if itemManaBat and itemManaBat:CanActivate() then
		local nHPercent = unitSelf:GetHealthPercent()
		local nMPercent = unitSelf:GetManaPercent()
		if nHPercent <= 0.5 and itemManaBat:GetCharges() >= 10 then
			nUtility = nBatUse
			bActionTaken = true
		elseif nMPercent <= 0.6 and itemManaBat:GetCharges() >= 10 then
			nUtility = nBatUse
			bActionTaken = true
		elseif nHPercent <= 0.2 and itemManaBat:GetCharges() >= 1 then
			nUtility = nBatUse
			return nUtility
		end
	end

	nUtility = nBadIdea
		
	return nUtility
end

function behaviorLib.ManaBatExecute(botBrain)
	local itemPowSup = core.itemPowSup
	
	if itemPowSup:CanActivate() then
		core.OrderItemClamp(botBrain, unitSelf, itemPowSup)
	end
end

behaviorLib.ManaBatBehavior = {}
behaviorLib.ManaBatBehavior["Utility"] = behaviorLib.ManaBatUtility
behaviorLib.ManaBatBehavior["Execute"] = behaviorLib.ManaBatExecute
behaviorLib.ManaBatBehavior["Name"] = "ManaBat"
tinsert(behaviorLib.tBehaviors, behaviorLib.ManaBatBehavior)

--------------------------------------------------------------
-- Function to determine utility of using Call in
-- farming situations.
--------------------------------------------------------------
function behaviorLib.CallUtility(botBrain)
	local unitSelf = core.unitSelf
	local nUtility = 0
	local nHowToFarmACreep = 40
	local abilCall = skills.abilCall
	local nCallRangeSqd = 400 * 400
	local nCandPos = 0
	local nRangeCheck = 0
	local nNumCand = 0
	local bDC = false
	local nBadIdea = 1

	if abilCall:CanActivate() then
		local tCreepin = core.CopyTable(core.localUnits["EnemyCreeps"])
		local tCloseHeroes = HoN.GetHeroes(core.enemyTeam)
		local nManaCheck = unitSelf:GetManaPercent()
		bDC = DangerClose(unitSelf:GetPosition(), tCloseHeroes, 2)
		if not bDC then
			for index, candidate in pairs(tCreepin) do
				if candidate then
					nCandPos = candidate:GetPosition()
					if nCandPos then
						nRangeCheck = Vector3.Distance2DSq(unitSelf:GetPosition(), nCandPos)
					end
				end
				if nRangeCheck and nRangeCheck <= nCallRangeSqd then
					nNumCand = nNumCand + 1
				end
				if nNumCand >= 3 and nManaCheck > 0.6 then
					nUtility = nHowToFarmACreep
					return nUtility
				end
			end
		end
	end

	nUtility = nBadIdea
	
	return nUtility
end

function behaviorLib.CallExecute(botBrain)
	local abilCall = skills.abilCall

	if abilCall:CanActivate() then
		core.OrderAbility(botBrain, abilCall)
	end
end

behaviorLib.CallBehavior = {}
behaviorLib.CallBehavior["Utility"] = behaviorLib.CallUtility
behaviorLib.CallBehavior["Execute"] = behaviorLib.CallExecute
behaviorLib.CallBehavior["Name"] = "Call"
tinsert(behaviorLib.tBehaviors, behaviorLib.CallBehavior)

--------------------------------------------------------------
-- Harassment override, needs to be updated to harass heroes
-- with good old-fashioned auto-attacks
--------------------------------------------------------------
-- @params: botBrain
-- @return: none
--
local function HarassHeroExecuteOverride(botBrain)
	local unitTarget = behaviorLib.heroTarget
	if unitTarget == nil then
		return object.harassExecuteOld(botBrain) --Target is invalid, move on to the next behavior
	end
	
	local unitSelf = core.unitSelf
	local vecMyPosition = unitSelf:GetPosition() 
	local nAttackRange = core.GetAbsoluteAttackRangeToUnit(unitSelf, unitTarget)
	local nMyExtraRange = core.GetExtraRange(unitSelf)
 
	local vecTargetPosition = unitTarget:GetPosition()
	local nTargetExtraRange = core.GetExtraRange(unitTarget)
	local nTargetDistanceSq = Vector3.Distance2DSq(vecMyPosition, vecTargetPosition)
 
	local nLastHarassUtility = behaviorLib.lastHarassUtil
	local bCanSee = core.CanSeeUnit(botBrain, unitTarget)
	local bActionTaken = false

	--- Insert abilities code here, set bActionTaken to true 
	--- if an ability command has been given successfully
	local bTargetVuln = unitTarget:IsStunned() or unitTarget:IsImmobilized()
	local abilCall = skills.abilCall
	local abilArrow = skills.abilArrow
	local abilLeap = skills.abilLeap
	local abilUlt = skills.abilUlt
	local nTimeThreshold = 500
	local nCallRangeSqd = 400 * 400
	local nArrowRadiusSqd = 110
	local bComboing = false
	local itemEnergize = core.itemEnergize
	local itemNullfire = core.itemNullfire
	local nCurTime = 0
	
	--Arrow checks, largely borrowed from [S2]BlacRyu's guttling hook checks for devobot
	if core.CanSeeUnit(botBrain, unitTarget) then
		if not bActionTaken and not bTargetVuln then
			if abilArrow:CanActivate() and nLastHarassUtility > botBrain.nArrowThreshold then
				if unitTarget.storedPosition and unitTarget.lastStoredPosition then
					local nRange = abilArrow:GetRange()
					local vecTargetVelocity = unitTarget.storedPosition - unitTarget.lastStoredPosition
					local vecTargetPosition = vecTargetPosition + vecTargetVelocity
					local tCandidateUnits = core.CopyTable(core.localUnits["AllyCreeps"])
					for key, unit in pairs(core.localUnits["EnemyCreeps"]) do
						tCandidateUnits[key] = unit
					end
					for key, unit in pairs(core.localUnits["AllyHeroes"]) do
						tCandidateUnits[key] = unit
					end
					
					if nTargetDistanceSq < (nRange * nRange) and ClearToTarget(unitSelf:GetPosition(), vecTargetPosition, tCandidateUnits, nArrowRadiusSqd) then
						bActionTaken = core.OrderAbilityPosition(botBrain, abilArrow, vecTargetPosition)
					end
				end
			end
		end	
	
		if not bActionTaken and bTargetVuln then
			if abilLeap:CanActivate() and nLastHarassUtility > botBrain.nLeapThreshold then
				local nRange = ((abilLeap:GetRange() * abilLeap:GetRange()) + nCallRangeSqd)
				if nTargetDistanceSq < nRange and nTargetDistanceSq > 300 then
					if TurnTheShip(botBrain, unitSelf:GetPosition(), vecTargetPosition, 0) then
						bActionTaken = core.OrderAbility(botBrain, abilLeap)
						object.nTime = HoN.GetGameTime()
						bComboing = true
						core.bAttackStart = false
					end
				end
			end
		end
	
		if not bActionTaken then
			if abilLeap:CanActivate() and nLastHarassUtility > botBrain.nLeapThreshold then
				local nRange = ((abilLeap:GetRange() * abilLeap:GetRange()) + nCallRangeSqd)
				if nTargetDistanceSq < nRange and nTargetDistanceSq > 300 then
					if TurnTheShip(botBrain, unitSelf:GetPosition(), vecTargetPosition, 0) then
						bActionTaken = core.OrderAbility(botBrain, abilLeap)
						object.nTime = HoN.GetGameTime()
						bComboing = true
						core.bAttackStart = false
					end
				end
			end
		end
		
		if not bActionTaken then
			if abilCall:CanActivate() and nLastHarassUtility > botBrain.nCallThreshold then
				if nTargetDistanceSq < nCallRangeSqd then
					bActionTaken = core.OrderAbility(botBrain, abilCall)
				end
			end
		end
	
		if not bActionTaken then 
			if abilUlt:CanActivate() and nLastHarassUtility > botBrain.nUltThreshold then
				local tEnemyHeroes = core.CopyTable(core.localUnits["EnemyHeroes"])
				if DangerClose(unitSelf:GetPosition(), tEnemyHeroes, 0) then
					bActionTaken = core.OrderAbility(botBrain, abilUlt)
				end
			end
		end
		
		if not bActionTaken then
			if itemEnergize and itemEnergize:CanActivate() and nLastHarassUtility > botBrain.nEnergThreshold then
				bActionTaken = core.OrderItemClamp(botBrain, unitSelf, itemEnergize)
			end
		end
		
		if not bActionTaken then
			if itemNullfire and itemNullfire:CanActivate() and nLastHarassUtility > botBrain.nNullThreshold then
				bActionTaken = core.OrderItemEntityClamp(botBrain, unitSelf, itemNullfire, unitTarget)
			end
		end
	end

	if not bActionTaken then
		return object.harassExecuteOld(botBrain)
	end
end
-- overload the behaviour stock function with custom 
object.harassExecuteOld = behaviorLib.HarassHeroBehavior["Execute"]
behaviorLib.HarassHeroBehavior["Execute"] = HarassHeroExecuteOverride

--------------------------------------------------------------
-- Valkyrie-specific retreat logic
-- Mostly here to leap and ult when in trouble, possibly other
-- uses later, such as using energizer
--------------------------------------------------------------
local function RetreatFromThreatExecuteOverride(botBrain)
	local unitSelf = core.unitSelf
	local abilLeap = skills.abilLeap
	local abilUlt = skills.abilUlt
	local abilArrow = skills.abilArrow
	local itemEnergize = core.itemEnergize
	local itemNullfire = core.itemNullfire
	local nDangerCloseSqd = 650 * 650
	local bActionTaken = false
	
	if not bActionTaken then
		local tEnemyHeroes = HoN.GetHeroes(core.enemyTeam)
		if abilLeap:CanActivate() and DangerClose(unitSelf:GetPosition(), tEnemyHeroes, 1) then
			for index, danger in pairs(tEnemyHeroes) do
				if danger then
					local dangerpos = danger:GetPosition()
					if dangerpos then
						nDangerDist = Vector3.Distance2DSq(unitSelf:GetPosition(), dangerpos)
					end
					if nDangerDist and nDangerDist <= nDangerCloseSqd then
						if TurnTheShip(botBrain, unitSelf:GetPosition(), dangerpos, 1) then
							bActionTaken = core.OrderAbility(botBrain, abilLeap)
						end
					end
				end
			end
		end
	end
	
	if not bActionTaken then
		if itemEnergize and itemEnergize:CanActivate() then
			local tEnemyHeroes = HoN.GetHeroes(core.enemyTeam)
			if DangerClose(unitSelf:GetPosition(), tEnemyHeroes, 1) then
				bActionTaken = core.OrderItemClamp(botBrain, unitSelf, itemEnergize)
				core.bIsFirstRetreat = true
			end
		end
	end
	
	if not bActionTaken then
		if itemNullfire and itemNullfire:CanActivate() then
			local tEnemyHeroes = core.CopyTable(core.localUnits["EnemyHeroes"])
			for index, danger in pairs(tEnemyHeroes) do
				if danger then
					local dangerpos = danger:GetPosition()
					if dangerpos then
						nDangerDist = Vector3.Distance2DSq(unitSelf:GetPosition(), dangerpos)
					end
					if nDangerDist and nDangerDist <= nDangerCloseSqd then
						bActionTaken = core.OrderItemEntityClamp(botBrain, unitSelf, itemNullfire, danger)
					end
				end
			end
		end
	end
	
	if not bActionTaken then
		object.retreatFromThreatOld(botBrain)
	end
end
object.retreatFromThreatOld = behaviorLib.RetreatFromThreatBehavior["Execute"]
behaviorLib.RetreatFromThreatBehavior["Execute"] = RetreatFromThreatExecuteOverride

