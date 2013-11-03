--DevoBot by BlacRyu

-- To add:
-- Activate decay while channeling
-- Exclude seige creeps from hook and decay checks
-- Don't use decay against magic immune heroes

-- Completed to some degree:
-- Last hitting with Decay
-- Don't hook if there is an obstruction
-- Predict target's movement when hooking
-- Randomize first skill point between Hook/Decay
-- Use decay defensively to slow enemy
-- Use Ultimate defensively when running away

local _G = getfenv(0)
local object = _G.object

object.myName = object:GetName()

object.bRunLogic 		= true
object.bRunBehaviors	= true
object.bUpdates 		= true
object.bUseShop 		= true

object.bRunCommands 	= true
object.bMoveCommands 	= true
object.bAttackCommands 	= true
object.bAbilityCommands = true
object.bOtherCommands 	= true

object.bReportBehavior = false
object.bDebugUtility = false

object.nDenySelfHealthPercentThreshold = 0.04


object.logger = {}
object.logger.bWriteLog = false
object.logger.bVerboseLog = false

object.core 		= {}
object.eventsLib 	= {}
object.metadata 	= {}
object.behaviorLib 	= {}
object.skills 		= {}

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

local sqrtTwo = math.sqrt(2)

BotEcho('loading devourer_main...')

object.heroName = 'Hero_Devourer'

 
--------------------------------
-- Misc. Functions
--------------------------------

--------------------------------------------------------------------------------------------------------------------------------
-- determines if any of the candidate units are within the given distance from a line that intersects the origin and target positions.
--------------------------------------------------------------------------------------------------------------------------------
local function funcClearToTarget(vecOrigin, vecTarget, tCandidates, nDistanceThreshold)
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

---------------------------------------------------
-- Finds the closest ally tower to the given position
---------------------------------------------------
local function funcGetClosestAllyTower(vecPos, nMaxDist)
	nMaxDist = nMaxDist ~= nil and nMaxDist or 99999
	
	local nMaxDistanceSq = nMaxDist * nMaxDist
	
	local unitClosestTower = nil
	local nClosestTowerDistSq = 99999*99999
	for id, unitTower in pairs(core.allyTowers) do
		if unitTower ~= nil then
			local nDistanceSq = Vector3.Distance2DSq(unitTower:GetPosition(), vecPos)
	 		if nDistanceSq < nClosestTowerDistSq and nDistanceSq < nMaxDistanceSq then
				nClosestTowerDistSq = nDistanceSq
				unitClosestTower = unitTower
			end
		end
	end
	
	return unitClosestTower
end

------------------------------------------------------------------------------
-- Determines if the unit has any regeneration buffs that are cancelled on damage
------------------------------------------------------------------------------
local function funcHasDamageCancellableBuff(unit)
	return unit:HasState("State_HealthPotion") or unit:HasState("State_ManaPotion") or unit:HasState("State_PowerupRegen") or unit:HasState("State_Bottle")
end



--------------------------------
-- Skills
--------------------------------
function object:SkillBuild()
	--core.VerboseLog("SkillBuild()")
	
	local unitSelf = self.core.unitSelf

	if skills.abilGuttlingHook == nil then
		skills.abilGuttlingHook		= unitSelf:GetAbility(0)
		skills.abilDecay	= unitSelf:GetAbility(1)
		skills.abilCadaverArmor	= unitSelf:GetAbility(2)
		skills.abilDevour	= unitSelf:GetAbility(3)
		skills.abilAttributeBoost	= unitSelf:GetAbility(4)
	end

	if unitSelf:GetAbilityPointsAvailable() <= 0 then
		return
	end
	--At level 1, choose randomly between Decay and Hook
	if unitSelf:GetLevel() == 1 then
		local rand = random(2)
		if rand == 1 then
			skills.abilDecay:LevelUp()
		else
			skills.abilGuttlingHook:LevelUp()
		end
	--specific level 1-3 skills
	elseif skills.abilDecay:GetLevel() < 1 then
		skills.abilDecay:LevelUp()
	elseif skills.abilGuttlingHook:GetLevel() < 1 then
		skills.abilGuttlingHook:LevelUp()
	elseif skills.abilCadaverArmor:GetLevel() < 1 then
		skills.abilCadaverArmor:LevelUp()
	--max in this order {devour, guttling hook, decay, cadaver armor, stats}
	elseif skills.abilDevour:CanLevelUp() then
		skills.abilDevour:LevelUp()
	elseif skills.abilGuttlingHook:CanLevelUp() then
		skills.abilGuttlingHook:LevelUp()
	elseif skills.abilDecay:CanLevelUp() then
		skills.abilDecay:LevelUp()
	elseif skills.abilCadaverArmor:CanLevelUp() then
		skills.abilCadaverArmor:LevelUp()
	else
		skills.abilAttributeBoost:LevelUp()
	end	
end

---------------------------------------------------
--                   Overrides                   --
---------------------------------------------------

----------------------------------
--	Devourer specific harass bonuses
--
--  Abilities off cd increase harass util
--  Ability use increases harass util for a time
--  If we are close to a tower and can hook, harass util increases drastically
--  Harass util adjusted based on Devourer's current magic armor.
----------------------------------

object.nGuttlingHookUpBonus = 15
object.nDevourUpBonus = 15

object.nGuttlingHookUseBonus = 40
object.nDevourUseBonus = 65

--------------------------------------------------------------
-- Returns a bonus utility value when abilities are off cooldown
--------------------------------------------------------------
local function AbilitiesUpUtilityFn()
	local val = 0
	
	if skills.abilGuttlingHook:CanActivate() then
		val = val + object.nGuttlingHookUpBonus
	end
	
	if skills.abilDevour:CanActivate() then
		val = val + object.nDevourUpBonus
	end
	
	return val
end

-----------------------------------------------------------
-- Returns extra utility when devourer is near an ally tower.
-----------------------------------------------------------
local function ProxToAllyTowerUtility()
	local bDebugEchos = false
	
	local unitSelf = core.unitSelf
	local unitClosestAllyTower = funcGetClosestAllyTower(unitSelf:GetPosition())
	local nUtility = 0

	if unitClosestAllyTower then
		local nDist = Vector3.Distance2D(unitClosestAllyTower:GetPosition(), unitSelf:GetPosition())
		local nTowerRange = core.GetAbsoluteAttackRangeToUnit(unitClosestAllyTower, unitSelf)
		local nBuffers = unitSelf:GetBoundsRadius() + unitClosestAllyTower:GetBoundsRadius()

		nUtility = core.ExpDecay((nDist - nBuffers), 100, nTowerRange, 2)
	
		nUtility = Clamp(nUtility, 0, 40)
		
		if bDebugEchos then BotEcho(format("util: %d  nDistance: %d  nTowerRange: %d", nUtility, (nDist - nBuffers), nTowerRange)) end
	end

	return nUtility
end

------------------------------------------------------------------
-- Returns a bonus utility value based on Devourer's current magic armor.
------------------------------------------------------------------
local function MagicArmorUtilityFn()
	local unitSelf = core.unitSelf
	
	return (unitSelf:GetMagicArmor() - 5.5) * 2
end
	
	

---------------------------------------------------------------
-- Adds a bonus to harass util for a while after using an ability.
---------------------------------------------------------------
function object:oncombateventOverride(EventData)
	self:oncombateventOld(EventData)
	
	local nAddBonus = 0
	
	if EventData.Type == "Ability" then
		--BotEcho("ABILILTY EVENT!  InflictorName: "..EventData.InflictorName)		
		if EventData.InflictorName == "Ability_Devourer1" then
			nAddBonus = nAddBonus + object.nGuttlingHookUseBonus
		elseif EventData.InflictorName == "Ability_Devourer4" then
			nAddBonus = nAddBonus + object.nDevourUseBonus
		end
	end
	
	if nAddBonus > 0 then
		--decay before we add
		core.DecayBonus(self)
	
		core.nHarassBonus = core.nHarassBonus + nAddBonus
	end
end
object.oncombateventOld = object.oncombatevent
object.oncombatevent 	= object.oncombateventOverride

-----------------------
-- Utility calc override
-----------------------
local function CustomHarassUtilityFnOverride(hero)
	local bDebugEchos = false
	
	local util = 0
	util = util + AbilitiesUpUtilityFn() + MagicArmorUtilityFn()
	
	if bDebugEchos then
		local unitTarget = behaviorLib.heroTarget
		if unitTarget ~= nil then
			local nRadius = object.GetHookRadius()
			local vecTargetVelocity = unitTarget.storedPosition - unitTarget.lastStoredPosition
			local vecTargetPosition = unitTarget:GetPosition() + vecTargetVelocity
			local tCandidateUnits = core.CopyTable(core.localUnits["AllyCreeps"])
			for key, unit in pairs(core.localUnits["EnemyCreeps"]) do
				tCandidateUnits[key] = unit
			end
			for key, unit in pairs(core.localUnits["AllyHeroes"]) do
				tCandidateUnits[key] = unit
			end
			BotEcho(format("Clear to target: %s", tostring(funcClearToTarget(core.unitSelf:GetPosition(),vecTargetPosition,tCandidateUnits,nRadius))))
		end
	end
	
	-- if we can hook and are near a tower, then pull dem fukers in
	if skills.abilGuttlingHook:CanActivate() then
		util = util + ProxToAllyTowerUtility()
	end
	
	return util
end
behaviorLib.CustomHarassUtility = CustomHarassUtilityFnOverride  


----------------------------------
--	Devourer harass actions
---------------------------------- 
object.nGuttlingHookThreshold = 15
object.nDecayThreshold = 0
object.nDevourThreshold = 15

function object.GetHookRadius()
	return 75
end

function object.GetDecayRadius()
	local nRadius = 250
	
	local unitSelf = core.unitSelf
	local abilDecay = skills.abilDecay
	local abilDevour = skills.abilDevour
	
	local nDevourLevel = abilDevour:GetLevel()
	
	-- Check for ultimate radius boost
	if nDevourLevel == 1 then
		if unitSelf:HasState("State_Devourer_Ability4_Stage1") then
			nRadius = 280
		elseif unitSelf:HasState("State_Devourer_Ability4_Stage2") then
			nRadius = 310
		elseif unitSelf:HasState("State_Devourer_Ability4_Stage3") then
			nRadius = 340
		end
	elseif nDevourLevel == 2 then
		if unitSelf:HasState("State_Devourer_Ability4_Stage1") then
			nRadius = 290
		elseif unitSelf:HasState("State_Devourer_Ability4_Stage2") then
			nRadius = 330
		elseif unitSelf:HasState("State_Devourer_Ability4_Stage3") then
			nRadius = 370
		end
	elseif nDevourLevel == 3 then
		if unitSelf:HasState("State_Devourer_Ability4_Stage1") then
			nRadius = 300
		elseif unitSelf:HasState("State_Devourer_Ability4_Stage2") then
			nRadius = 350
		elseif unitSelf:HasState("State_Devourer_Ability4_Stage3") then
			nRadius = 400
		end
	end
	
	return nRadius
end

---------------------------------------------------------------------------------------
-- If Devourer is this close to an enemy, just walk up and ult them and don't bother hooking
---------------------------------------------------------------------------------------
function object.GetDevourAggroRange()
	return 300
end

local function HarassHeroExecuteOverride(botBrain)
	--VerboseLog("HarassHeroExecuteOverride("..tostring(botBrain)..")")
	local bDebugEchos = false
	
	local unitTarget = behaviorLib.heroTarget
	if unitTarget == nil then
		return false --can not execute, move on to the next behavior
	end
	
	local unitSelf = core.unitSelf
	local vecMyPosition = unitSelf:GetPosition()
	local nMyExtraRange = core.GetExtraRange(unitSelf)
	
	local vecTargetPosition = unitTarget:GetPosition()
	local nTargetExtraRange = core.GetExtraRange(unitTarget)
	local nTargetDistanceSq = Vector3.Distance2DSq(vecMyPosition, vecTargetPosition)
	
	local nLastHarassUtil = behaviorLib.lastHarassUtil
	local bCanSee = core.CanSeeUnit(botBrain, unitTarget)	
	
	if bDebugEchos then BotEcho("Devourer HarassHero at "..nLastHarassUtil) end
	local bActionTaken = false
	
	if unitSelf:IsChanneling() then
		--continue to do so
		return
	end
	
	
	
	--decay
	if not bActionTaken and nLastHarassUtil > botBrain.nDecayThreshold then
		if bDebugEchos then BotEcho("  No action yet, checking decay") end
		local abilDecay = skills.abilDecay
		if abilDecay:CanActivate() and not unitSelf:HasState("State_Devourer_Ability2_Self") then
			local nRadius = botBrain.GetDecayRadius()
				
			if nTargetDistanceSq < (nRadius * nRadius) then
				bActionTaken = core.OrderAbility(botBrain, abilDecay)
			end
		end
	end
	
	--ult
	if not bActionTaken and nLastHarassUtil > botBrain.nDevourThreshold then
		if bDebugEchos then BotEcho("  No action yet, checking devour.") end
		local abilDevour = skills.abilDevour
		if abilDevour:CanActivate() then
			nRange = botBrain.GetDevourAggroRange()
			if nTargetDistanceSq <= nRange * nRange then
				bActionTaken = core.OrderAbilityEntity(botBrain, abilDevour, unitTarget)
			end
		end
	end
	
	--guttling hook
	if not bActionTaken and nLastHarassUtil > botBrain.nGuttlingHookThreshold - ProxToAllyTowerUtility() / 2.0 then
		if bDebugEchos then BotEcho("  No action yet, checking guttling hook") end
		local abilGuttlingHook = skills.abilGuttlingHook
		if abilGuttlingHook:CanActivate() then
			
			-- Hook Prediction
			if unitTarget.bIsMemoryUnit then
				if unitTarget.storedPosition and unitTarget.lastStoredPosition then
					local nRange = abilGuttlingHook:GetRange()
					local nRadius = botBrain.GetHookRadius()
					local vecTargetVelocity = unitTarget.storedPosition - unitTarget.lastStoredPosition
					local vecTargetPosition = vecTargetPosition + vecTargetVelocity
					local tCandidateUnits = core.CopyTable(core.localUnits["AllyCreeps"])
					for key, unit in pairs(core.localUnits["EnemyCreeps"]) do
						tCandidateUnits[key] = unit
					end
					for key, unit in pairs(core.localUnits["AllyHeroes"]) do
						tCandidateUnits[key] = unit
					end
					
					-- Only hook if the target is in range and no creeps are between devo and the target
					if nTargetDistanceSq < (nRange * nRange) and funcClearToTarget(unitSelf:GetPosition(),vecTargetPosition,tCandidateUnits,nRadius) then
						bActionTaken = core.OrderAbilityPosition(botBrain, abilGuttlingHook, vecTargetPosition)
					else
						if bDebugEchos then BotEcho("  Target too far away or no clear path.") end
					end
				end
			end
		end
	end
	
	if not bActionTaken then
		if bDebugEchos then BotEcho("  No action yet, proceeding with normal harass execute.") end
		object.harassExecuteOld(botBrain)
	end
end
object.harassExecuteOld = behaviorLib.HarassHeroBehavior["Execute"]
behaviorLib.HarassHeroBehavior["Execute"] = HarassHeroExecuteOverride




----------------------------------
-- Devourer specific retreat from threat logic.
--
-- Utility: unchanged
-- Execute: Enable decay if we want to slow the enemy or suicide, use ultimate if only one hero is chasing us, otherwise use old behavior
----------------------------------
local function RetreatFromThreatExecuteOverride(botBrain)
	
	local unitSelf = core.unitSelf
	local vecSelfPos = unitSelf:GetPosition()
	local abilDecay = skills.abilDecay
	local abilDevour = skills.abilDevour
	local bActionTaken = false
	
	local nClosestEnemyHeroDistSq = 99999999
	local nSecondClosestEnemyHeroDistSq = 99999999
	
	if unitSelf:IsChanneling() then
		--continue to do so
		return
	end
	
	-- Check to see if I should turn on Decay
	if not unitSelf:HasState("State_Devourer_Ability2_Self") and abilDecay:CanActivate() then	
		if object.bDebugUtility then 
			BotEcho("  considering using decay defensively.")
		end
		
		-- Are there any enemies in range that I should slow?
		if not funcHasDamageCancellableBuff(unitSelf) then
			local nRadiusSq = botBrain.GetDecayRadius() * botBrain.GetDecayRadius()
			for id, unit in pairs(core.localUnits["EnemyHeroes"]) do
				if bActionTaken then
					break
				end
				local nDistSq = Vector3.Distance2DSq(vecSelfPos, unit:GetPosition())
				if nDistSq <= nRadiusSq and not unit:HasState("State_Devourer_Ability2_Other") then
					bActionTaken = core.OrderAbility(botBrain, abilDecay)
				end
				if nDistSq < nClosestEnemyHeroDistSq then
					nSecondClosestEnemyHeroDistSq = nClosestEnemyHeroDistSq
					nClosestEnemyHeroDistSq = nDistSq
				elseif nDistSq < nSecondClosestEnemyHeroDistSq then
					nSecondClosestEnemyHeroDistSq = nDistSq
				end
			end
		end
	end
		
	if not bActionTaken then
		-- Should I defensively ult?
		if abilDevour:CanActivate() and nClosestEnemyHeroDistSq < botBrain.GetDevourAggroRange() and nSecondClosestEnemyHeroDistSq > 1000000 then
			bActionTaken = core.OrderAbilityEntity(botBrain, abilDevour, unitTarget)
		-- Should I try to suicide?
		elseif unitSelf:GetHealthPercent() < object.nDenySelfHealthPercentThreshold and abilDecay:CanActivate() and not unitSelf:HasState("State_Devourer_Ability2_Self") then
			bActionTaken = core.OrderAbility(botBrain, abilDecay)
		end
	end
	
	-- If I'm not suiciding or trying to slow the enemy, then make sure decay is off
	if not bActionTaken and not (unitSelf:GetHealthPercent() < object.nDenySelfHealthPercentThreshold) and unitSelf:HasState("State_Devourer_Ability2_Self") and abilDecay:CanActivate() then
		bActionTaken = core.OrderAbility(botBrain, abilDecay)
	end
	
	-- None of Devourer's retreat logic activated, so use the common retreat logic
	if not bActionTaken then
		if bDebugEchos then BotEcho("  No action yet, proceeding with normal retreat execute.") end
		object.retreatFromThreatOld(botBrain)
	end
end
object.retreatFromThreatOld = behaviorLib.RetreatFromThreatBehavior["Execute"]
behaviorLib.RetreatFromThreatBehavior["Execute"] = RetreatFromThreatExecuteOverride


----------------------------------
-- Devourer specific attack creeps logic
--
-- Utility: unchanged
-- Execute: Enable decay when creeps are almost dead and we aren't attacking to snag extra last hits.
----------------------------------
local function AttackCreepsExecuteOverride(botBrain)
	local unitSelf = core.unitSelf
	local vecSelfPos = unitSelf:GetPosition()
	local abilDecay = skills.abilDecay
	local abilDevour = skills.abilDevour
	local bActionTaken = false
	local nCreepHealthPercentThreshold = .08
	local nSelfHealthPercentThreshold = .1
	local sAttackSequence = core.GetAttackSequenceProgress(unitSelf)
	
	-- Check to see if I should turn on Decay
	if unitSelf:GetHealthPercent() >= nSelfHealthPercentThreshold and sAttackSequence ~= "windup" then
		if object.bDebugUtility then 
			BotEcho("  considering using decay to last hit.")
		end
		
		-- Are there any enemies in range that I should kill?
		local bTargetFound = false
		local nRadiusSq = botBrain.GetDecayRadius() * botBrain.GetDecayRadius()
		for id, creep in pairs(core.localUnits["EnemyCreeps"]) do
			local nDistSq = Vector3.Distance2DSq(vecSelfPos, creep:GetPosition())
			if creep:GetHealthPercent() <= nCreepHealthPercentThreshold and nDistSq <= nRadiusSq then
				bTargetFound = true
			end
		end
		
		if bTargetFound and not unitSelf:HasState("State_Devourer_Ability2_Self") and abilDecay:CanActivate() and not funcHasDamageCancellableBuff(unitSelf) then
			if object.bDebugUtility then
				BotEcho("  Found nearby low health creep(s), activating decay to last hit")
			end
			bActionTaken = core.OrderAbility(botBrain, abilDecay)
		elseif not bTargetFound and unitSelf:HasState("State_Devourer_Ability2_Self") and abilDecay:CanActivate() then
			if object.bDebugUtility then
				BotEcho("  No low health creeps found, deactivating decay")
			end
			bActionTaken = core.OrderAbility(botBrain, abilDecay)
		end
	end
	
	
	-- None of Devourer's attack creep logic activated, so use the common attack creeps logic
	if not bActionTaken then
		if bDebugEchos then BotEcho("  No action yet, proceeding with normal attack creeps execute.") end
		object.attackCreepsOld(botBrain)
	end
end
object.attackCreepsOld = behaviorLib.AttackCreepsBehavior["Execute"]
behaviorLib.AttackCreepsBehavior["Execute"] = AttackCreepsExecuteOverride




----------------------------------
--	Deactivate Decay Behavior
--	This behavior exists to make sure we never get stuck with decay enabled
--	in a behavior which has no logic to deactivate it.
--	
--	Utility: 99 if Devourer no longer needs Decay turned on and isn't silenced
--	Execute: Disable Decay
----------------------------------
local function DeactivateDecayUtility(botBrain)
	--VerboseLog("DeactivateDecayUtility("..tostring(botBrain)..")")
	local nUtility = 0
	
	local unitSelf = core.unitSelf
	local vecSelfPos = unitSelf:GetPosition()
	local abilDecay = skills.abilDecay
	
	--get closest enemy hero
	local unitClosestEnemyHero = nil
	local nClosestEnemyHeroDistSq = 9999*9999

	-- Check to see if we should turn off Decay
	if unitSelf:HasState("State_Devourer_Ability2_Self") and abilDecay:CanActivate() then	
		if object.bDebugUtility then 
			BotEcho("  considering deactivating decay.")
		end
		local nRadiusSq = botBrain.GetDecayRadius() * botBrain.GetDecayRadius()
		for id, unit in pairs(core.localUnits["EnemyUnits"]) do
			local distSq = Vector3.Distance2DSq(vecSelfPos, unit:GetPosition())
			if distSq < nClosestEnemyHeroDistSq then
				unitClosestEnemyHero = unit
				nClosestEnemyHeroDistSq = distSq
			end
		end
		
		if (unitClosestEnemyHero == nil or nClosestEnemyHeroDistSq > nRadiusSq) and unitSelf:GetHealthPercent() > object.nDenySelfHealthPercentThreshold then
			nUtility = 99
		end
	end
	

	return nUtility
end

local function DeactivateDecayExecute(botBrain)
	--VerboseLog("DontBreakChannelExecute("..tostring(botBrain)..")")
	
	local unitSelf = core.unitSelf
	
	local abilDecay = skills.abilDecay
	if unitSelf:HasState("State_Devourer_Ability2_Self") and abilDecay:CanActivate() then	
		if object.bDebugUtility == true then
			BotEcho("  Deactivating Decay.")
		end
		core.OrderAbility(botBrain, abilDecay)
	end
	
	return
end

behaviorLib.DeactivateDecayBehavior = {}
behaviorLib.DeactivateDecayBehavior["Utility"] = DeactivateDecayUtility
behaviorLib.DeactivateDecayBehavior["Execute"] = DeactivateDecayExecute
behaviorLib.DeactivateDecayBehavior["Name"] = "DeactivateDecay"
tinsert(behaviorLib.tBehaviors, behaviorLib.DeactivateDecayBehavior)


----------------------------------
--	Items
----------------------------------
--[[ list code:
	"# Item" is "get # of these"
	"Item #" is "get this level of the item" --]]
behaviorLib.StartingItems = 
	{"Item_IronBuckler", "Item_ManaPotion", "Item_HealthPotion", "2 Item_RunesOfTheBlight"}
behaviorLib.LaneItems = 
	{"Item_Marchers", "Item_Striders", "Item_MysticVestments"}
behaviorLib.MidItems = 
	{"Item_MagicArmor2"} 
behaviorLib.LateItems = 
	{"Item_PostHaste", "Item_BehemothsHeart", "Item_Morph", "Item_Intelligence7"} --Morph is Sheepstick.



--[[ colors:
	red
	aqua == cyan
	gray
	navy
	teal
	blue
	lime
	black
	brown
	green
	olive
	white
	silver
	purple
	maroon
	yellow
	orange
	fuchsia == magenta
	invisible
--]]

BotEcho('finished loading devourer_main')