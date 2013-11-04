--[[
Gravekeeper v1.1 by Schnarchnase

The skills:

Corpse Toss:
Gravekeeper uses his Corpse Toss, if the targeted enemy hero is not rooted
or shortly after his first activation to ensure that the hero is beeing chainstunned.
In addition he will use the stun defensivly, if he is going to retreat.

Corpse Explosion:
For a really well CE implementation you would have to solve some mathematical problem.
As a simpler step he will look for corpses around the target in a radius of 225.
If the requried amount of corpses is reached, he will blast his enemies into pieces.
requried Corpses: 3 (No Zombie Apocalypse) / 4 (Zombie Apocalypse Up) / 5 (Zombie Apocalype Used)

Defiling Touch:
If Gravekeeper got a charge, he will be more likely to harrass.
What is more, he calculates his damage to get a creepkill much earlier.
On reposition (idle behavior) he will look for corpses near him and pick it up.

Zombie Apocalypse:
He will cast ZA, if the enemy has more than 30% of his life to ensure not to waste the cooldown.
If he is in danger (Less Hp than the opponent), he will use it, too.

Items:
Based on the actual performance in the game he may change his itembuild slightly.
If he has a bad start, he will pick some cheap survivability items before going for hellflower.
If he has reached the mid-game (Level 11+) and his farm is bad, he will go for a tablet.
If his game is going well, he will pick up a portal key for more killing power. (esp. vs humans)

credits:
-code examples from the S2 Bots (WitchSlayer as a template )
-Snippet Compedium by St0l3n_ID
-using code from Snippet Compedium
-V1P3R` Engi Bot (Kill Messages)
-using code paradoxon870 (Laning)

v1.1: update shoppingLib
v1.0b: initial bot
--]]
local _G = getfenv(0)
local object = _G.object

object.myName = object:GetName()

object.bRunLogic		= true
object.bRunBehaviors    = true
object.bUpdates		 = true
object.bUseShop		 = true

object.bRunCommands     = true
object.bMoveCommands    = true
object.bAttackCommands  = true
object.bAbilityCommands = true
object.bOtherCommands   = true

object.bReportBehavior = false
object.bDebugUtility = false
object.bDebugExecute = false

object.logger = {}
object.logger.bWriteLog = false
object.logger.bVerboseLog = false

object.core	     = {}
object.eventsLib	= {}
object.metadata	 = {}
object.behaviorLib      = {}
object.skills	   = {}

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

--shoppingLib implementation
local itemHandler = object.itemHandler
local shoppingLib = object.shoppingLib

--support ReloadBots (while testing)
shoppingLib.bDevelopeItemBuildSaver = true

BotEcho('loading gravekeeper_main...')

--------------------------------
-- Lanes
--------------------------------
core.tLanePreferences = {Jungle = 0, Mid = 4, ShortSolo = 3, LongSolo = 2, ShortSupport = 4, LongSupport = 3, ShortCarry = 4, LongCarry = 3}

object.heroName = 'Hero_Taint'

--------------------------------
-- Skills
--------------------------------

--[[
Gravekeeper will max Stun first.
At Level 2 he puts a pint into his Toss.
Afterwards maxing his Corpse Explosion before finishing his Toss.
Skills ZombieAcopalypse whenever possible.
--]]
function object:SkillBuild()

	local unitSelf = self.core.unitSelf

	if  skills.abilCorpseToss == nil then
		skills.abilCorpseToss		= unitSelf:GetAbility(0)
		skills.abilCorpseExplosion  = unitSelf:GetAbility(1)
		skills.abilDefilingTouch	= unitSelf:GetAbility(2)
		skills.abilZombieApocalypse	= unitSelf:GetAbility(3)
		skills.abilAttributeBoost	= unitSelf:GetAbility(4)
		skills.abilTaunt			= unitSelf:GetAbility(8)
	end

	if unitSelf:GetAbilityPointsAvailable() <= 0 then
		return
	end

	if skills.abilZombieApocalypse:CanLevelUp() then
		skills.abilZombieApocalypse:LevelUp()
	elseif skills.abilCorpseToss:CanLevelUp() then
		skills.abilCorpseToss:LevelUp()
	elseif skills.abilDefilingTouch:GetLevel() < 1 then
		skills.abilDefilingTouch:LevelUp()
	elseif skills.abilCorpseExplosion:CanLevelUp() then
		skills.abilCorpseExplosion:LevelUp()
	elseif skills.abilDefilingTouch:CanLevelUp() then
		skills.abilDefilingTouch:LevelUp()
	else
		skills.abilAttributeBoost:LevelUp()
	end
end



---------------------------------------------------
--				 Overrides			       --
---------------------------------------------------

--------------------------------
-- important variables
--------------------------------

--required corpses to use Corpse Explosion
object.nRequiredCorpses = 3

--cast timestamp of ultimate
object.nApocalyseUseTime = 0

--timestamp of last use of stun
object.nOneCorpseTossUseTime = 0



----------------------------------
--  Gravekeeper's specific harass bonuses
--
--  Abilities off cd increase harass util
--  Ability use increases harass util for a time
----------------------------------

----------------------------------
--CustomHarassUtility
----------------------------------
--Heroes near unitTarget
object.nHeroRangeSq = 1000 * 1000
-- utility malus per enemy hero near target
object.nEnemyThreat = 15
--ally bonus near yourself
object.nAllyBonus = 6
--Extra Malus for low life treshold (0..1)
object.nExtraHPMalusTreshold = 0.3
--max value for the malus
object.nExtraHPMalusMax = 50
--gradient of the malus function
object.nExtraFactor = (object.nExtraHPMalusTreshold > 0 and (object.nExtraHPMalusMax / object.nExtraHPMalusTreshold)) or 0
--max value of the Health Quotient (myHealthPercent / yourHP)
object.nHarassMaxHealthPercentQuotient = 2


----------------------------------
--Ability Up
----------------------------------
object.nCorpseTossUp = 13
object.nCorpseExplosionUp = 5
object.nDefilingTouchUp = 10
object.nZombieApocalypeUp  = 17
object.nSheepstickUp = 12
--object.nPortalKeyUp = 12
--object.nHFUp = 12

----------------------------------
--Ability Use
----------------------------------
object.nCorpseTossUse = 15
object.nCorpseExplosionUse = 10
object.nZombieApocalypeUse = 30
object.nSheepstickUse = 16

----------------------------------
--Harass Treshold
----------------------------------
object.nCorpseTossThreshold = 45
object.nCorpseExplosionThreshold = 40
object.nZombieApocalypeThreshold = 60
object.nSheepstickThreshold = 30
object.nHellflowerThreshold = 55
object.nPortalKeyThreshold = 70


local function AbilitiesUpUtility(hero)
	local nUtility = 0

	if skills.abilCorpseToss:CanActivate() then
		nUtility = nUtility + object.nCorpseTossUp
	end

	if skills.abilCorpseExplosion:CanActivate() then
		nUtility = nUtility + object.nCorpseExplosionUp
	end

	if skills.abilDefilingTouch:GetLevel() > 0  and skills.abilDefilingTouch:GetCharges() > 0 then
		nUtility = nUtility + object.nDefilingTouchUp
	end

	if skills.abilZombieApocalypse:CanActivate() then
		nUtility = nUtility + object.nZombieApocalypeUp
		object.nRequiredCorpses = 4
	end

	if object.itemSheepstick and object.itemSheepstick:CanActivate() then
		nUtility = nUtility + object.nSheepstickUp
	end
	
	return nUtility
end

--Gravekeeper ability use gives bonus to harass util for a while
function object:oncombateventOverride(EventData)
	self:oncombateventOld(EventData)

	local bDebugEchos = false
	local nAddBonus = 0

	if EventData.Type == "Ability" then
		if bDebugEchos then BotEcho("  ABILILTY EVENT!  InflictorName: "..EventData.InflictorName) end
		if EventData.InflictorName == "Ability_Taint1" then
			nAddBonus = nAddBonus + object.nCorpseTossUse
			object.nOneCorpseTossUseTime = EventData.TimeStamp
		elseif EventData.InflictorName == "Ability_Taint2" then
			nAddBonus = nAddBonus + object.nCorpseExplosionUse
		elseif EventData.InflictorName == "Ability_Taint4" then
			nAddBonus = nAddBonus + object.nZombieApocalypeUse
		end
	elseif EventData.Type == "Item" then
		if core.itemSheepstick ~= nil and EventData.SourceUnit == core.unitSelf:GetUniqueID() and EventData.InflictorName == core.itemSheepstick:GetName() then
			nAddBonus = nAddBonus + self.nSheepstickUse
		end
	end

	if nAddBonus > 0 then
		--decay before we add
		core.DecayBonus(self)

		core.nHarassBonus = core.nHarassBonus + nAddBonus
	end
end
object.oncombateventOld = object.oncombatevent
object.oncombatevent    = object.oncombateventOverride


--This function returns the position of the enemy hero.
--If he is not shown on map it returns the last visible spot
--as long as it is not older than 10s
object.tEnemyPosition = {}
object.tEnemyPositionTimestamp = {}
local function funcGetEnemyPosition(unitEnemy)

	if not unitEnemy then 
		--TODO: change this to nil and fix the rest of the code to recognize it as the failure case
		return Vector3.Create(20000, 20000) 
	end
	
	local tEnemyPosition = object.tEnemyPosition
	local tEnemyPositionTimestamp = object.tEnemyPositionTimestamp

	if core.IsTableEmpty(tEnemyPosition) then	
		local tEnemyTeam = HoN.GetHeroes(core.enemyTeam)
		
		--vector beyond map
		for x, hero in pairs(tEnemyTeam) do
			--TODO: Also here
			tEnemyPosition[hero:GetUniqueID()] = Vector3.Create(20000, 20000)
			tEnemyPositionTimestamp[hero:GetUniqueID()] = HoN.GetGameTime()
		end
	end

	local nUniqueID = unitEnemy:GetUniqueID()
	
	--enemy visible?
	if core.CanSeeUnit(object, unitEnemy) then
		--update table
		tEnemyPosition[nUniqueID] = unitEnemy:GetPosition()
		tEnemyPositionTimestamp[nUniqueID] = HoN.GetGameTime()
	end

	--return position, 10s memory
	if tEnemyPositionTimestamp[nUniqueID] <= HoN.GetGameTime() + 10000 then
		return tEnemyPosition[nUniqueID]
	else	
		--TODO: Also here
		return Vector3.Create(20000, 20000)
	end
end

------------------------
--CustomHarassUtility
------------------------
local function CustomHarassUtilityFnOverride(hero)

	--no target --> no harassment
	local unitTarget = behaviorLib.heroTarget
	if not unitTarget then 
		return 0
	end

	-- get skill agression
	local nUtility = AbilitiesUpUtility(hero)

	--bonus of allies
	local tAllies = core.localUnits["AllyHeroes"]
	local nAllies = core.NumberElements(tAllies)
	local nAllyBonus = object.nAllyBonus

	nUtility = nUtility + nAllies * nAllyBonus

	--number of enemies near target decrease utility
	local nEnemyThreat = object.nEnemyThreat
	local nHeroRangeSq = object.nHeroRangeSq

	local tEnemyTeam = HoN.GetHeroes(core.enemyTeam)

	--units close to unitTarget
	for id, enemy in pairs(tEnemyTeam) do
		if id ~= unitTarget:GetUniqueID() then
			if Vector3.Distance2DSq(unitTarget:GetPosition(), funcGetEnemyPosition(enemy)) < nHeroRangeSq then
				nUtility = nUtility - nEnemyThreat
			end
		end
	end

	--Change harasspotential based on the life of himself and his target. Go for easy kills
	local nUnitSelfHealth = core.unitSelf:GetHealthPercent()
	local nUnitTargetHealth = unitTarget:GetHealthPercent()
	local nXtraHealthMalus = 0
	if nUnitSelfHealth < object.nExtraHPMalusTreshold then
		nXtraHealthMalus = object.nExtraHPMalusMax - (object.nExtraFactor * nUnitSelfHealth)
	end

	local nHealthUtiltyMultiplier = Clamp(nUnitSelfHealth / nUnitTargetHealth, 0, object.nHarassMaxHealthPercentQuotient)
	nUtility = (nUtility * nHealthUtiltyMultiplier) - nXtraHealthMalus

	return Clamp(nUtility, 0, 100)
end
behaviorLib.CustomHarassUtility = CustomHarassUtilityFnOverride

----------------------------------
--      Gravekeeper harass actions
----------------------------------
local function HarassHeroExecuteOverride(botBrain)

	local unitTarget = behaviorLib.heroTarget
	if not unitTarget then
		return false --can not execute, move on to the next behavior
	end

	local unitSelf = core.unitSelf

	local vecMyPosition = unitSelf:GetPosition()
	local nAttackRangeSq = core.GetAbsoluteAttackRangeToUnit(unitSelf, unitTarget)
	nAttackRangeSq = nAttackRangeSq * nAttackRangeSq

	local vecTargetPosition = unitTarget:GetPosition()
	local nTargetDistanceSq = Vector3.Distance2DSq(vecMyPosition, vecTargetPosition)
	local bTargetRooted = unitTarget:IsStunned() or unitTarget:IsImmobilized() or unitTarget:GetMoveSpeed() < 200
	local bCanSeeUnit = core.CanSeeUnit(botBrain, unitTarget)

	local nLastHarassUtility = behaviorLib.lastHarassUtil

	local bActionTaken = false

	local nNow = HoN.GetGameTime()

	local abilCorpseToss = skills.abilCorpseToss
	local abilZombieApocalypse = skills.abilZombieApocalypse
	local abilCorpseExplosion =skills.abilCorpseExplosion
	
	--Sheepstick
	if not bActionTaken and bCanSeeUnit then
		local itemSheepstick = core.itemSheepstick
		if itemSheepstick and not bTargetRooted then
			if itemSheepstick:CanActivate() and nLastHarassUtility > object.nSheepstickThreshold then
				local nRange = itemSheepstick:GetRange()					
				if nTargetDistanceSq < (nRange * nRange) then
					bActionTaken = core.OrderItemEntityClamp(botBrain, unitSelf, itemSheepstick, unitTarget)
				end
			end
		end
	end

	--Stun
	if not bActionTaken and bCanSeeUnit then
		--don't use stun, if he is stunned to not overlap your charges
		if abilCorpseToss:CanActivate() and nLastHarassUtility > botBrain.nCorpseTossThreshold then
			if nNow > (object.nOneCorpseTossUseTime + 900) and (not bTargetRooted or nNow < object.nOneCorpseTossUseTime + 1050) then
				local nRange = abilCorpseToss:GetRange()
				if nTargetDistanceSq < (nRange * nRange) then
					bActionTaken = core.OrderAbilityEntity(botBrain, abilCorpseToss, unitTarget)
				end
			end
		end
	end

	--Zombie Apocalype
	if not bActionTaken then
		if abilZombieApocalypse:CanActivate() and nLastHarassUtility > botBrain.nZombieApocalypeThreshold then
			--only use it, if the enemy has plenty of Life left or we are in danger
			if bTargetRooted and (unitSelf:GetHealth() < unitTarget:GetHealth() or unitTarget:GetHealthPercent() > 0.3) then
				local nRange = abilZombieApocalypse:GetRange()
				if nTargetDistanceSq < (nRange * nRange) then
					--increase corpse amount for a short period of time
					object.nRequiredCorpses = 5
					object.nApocalyseUseTime = nNow
					bActionTaken = core.OrderAbilityPosition(botBrain, abilZombieApocalypse, vecTargetPosition)
				end
			end
		end
	end

StartProfile('CorpseExplosion')
	--Corpse Explosion	
	if not bActionTaken then		
		if abilCorpseExplosion:CanActivate() and nLastHarassUtility > botBrain.nCorpseExplosionThreshold then
			--No zombies around and ultimate is down. Set required Corpses to 3
			if (object.nApocalyseUseTime + 7500 < nNow and not abilZombieApocalypse:CanActivate()) then
				object.nRequiredCorpses = 3
			end
			
			local nRange = abilCorpseExplosion:GetRange()
			if nTargetDistanceSq < (nRange * nRange) then
				--looking for creep corpses (tCorpses) and summoned corpses (tPets) in range // no API = high costly
				local tCorpses = HoN.GetUnitsInRadius(vecTargetPosition, 225, core.UNIT_MASK_CORPSE + core.UNIT_MASK_UNIT)
				local tPets = HoN.GetUnitsInRadius(vecTargetPosition, 225, core.UNIT_MASK_ALIVE + core.UNIT_MASK_UNIT)
				local nNumberCorpses = core.NumberElements(tCorpses)

				for x, creep in pairs(tPets) do
					--Different summon types
					if creep:GetTypeName() == "Pet_Taint_Ability3" or creep:GetTypeName() == "Pet_Taint_Ability4_Explode"then
						nNumberCorpses = nNumberCorpses + 1
					end
				end
				
				--enough corpses in range?
				if nNumberCorpses >= object.nRequiredCorpses  then
					bActionTaken = core.OrderAbilityPosition(botBrain, abilCorpseExplosion, vecTargetPosition)
				end
			end
		end
	end
StopProfile()

	--Taunting!!!
	if not bActionTaken and bCanSeeUnit then		
		local abilTaunt = skills.abilTaunt
		if abilTaunt:CanActivate() and unitTarget:GetHealthPercent() < 0.3 then
			local nRange = 500
			if nTargetDistanceSq < (nRange * nRange) then
				bActionTaken = core.OrderAbilityEntity(botBrain, abilTaunt, unitTarget)
			end
		end
	end

	--Portal Key
	if not bActionTaken then
		local itemPortalKey = core.itemPortalKey
		if itemPortalKey then
			local nPortalKeyRange = itemPortalKey:GetRange()
			local nStunRange = abilCorpseToss:GetRange()
			if itemPortalKey:CanActivate() and behaviorLib.lastHarassUtil > object.nPortalKeyThreshold then
				if nTargetDistanceSq > (nStunRange * nStunRange) and nTargetDistanceSq < ((nPortalKeyRange * nPortalKeyRange) + (nStunRange * nStunRange)) then
					bActionTaken = core.OrderItemPosition(botBrain, unitSelf, itemPortalKey, vecTargetPosition)
				end
			end
		end
	end

	--hellflower
	if not bActionTaken and bCanSeeUnit then
		local itemHellflower = core.itemHellFlower
		if itemHellflower then
			if nNow < object.nOneCorpseTossUseTime + 1000 or (not abilCorpseToss:CanActivate() and not bTargetRooted ) then
				if itemHellflower:CanActivate() and nLastHarassUtility > object.nHellflowerThreshold then
					local nRange = itemHellflower:GetRange()
					if nTargetDistanceSq < (nRange * nRange) then
						bActionTaken = core.OrderItemEntityClamp(botBrain, unitSelf, itemHellflower, unitTarget)
					end
				end
			end
		end
	end

	--Tablet
	if not bActionTaken then
		local itemTablet = core.itemTablet
		if itemTablet then
			if itemTablet:CanActivate() then
				if nTargetDistanceSq > nAttackRangeSq and nTargetDistanceSq < (nAttackRangeSq + (500 * 500)) then
					bActionTaken = core.OrderItemEntityClamp(botBrain, unitSelf, itemTablet, unitSelf)
				end
			end
		end
	end

	--Frostfield Plate
	if not bActionTaken then
		local itemFrostfieldPlate = core.itemFrostfieldPlate
		if itemFrostfieldPlate then
			local nRange = itemFrostfieldPlate:GetTargetRadius()
			if itemFrostfieldPlate:CanActivate()  then
				if nTargetDistanceSq < (nRange * nRange) then
					bActionTaken = core.OrderItemClamp(botBrain, unitSelf, itemFrostfieldPlate)
				end
			end
		end
	end

	--Use Sacrificial Stone
	if not bActionTaken then
		--Todo: remove all sac stone usage into its own behavior		
		local itemSacStone = core.itemSacStone
		if itemSacStone and itemSacStone:CanActivate() then
			bActionTaken = core.OrderItemClamp(botBrain, unitSelf, itemSacStone, bActionTaken)
		end
	end

	if not bActionTaken then
		if bDebugEchos then BotEcho("  No action yet, proceeding with normal harass execute.") end
		return object.harassExecuteOld(botBrain)
	end

end
object.harassExecuteOld = behaviorLib.HarassHeroBehavior["Execute"]
behaviorLib.HarassHeroBehavior["Execute"] = HarassHeroExecuteOverride


local function GetAttackDamageMinOnCreep(unitCreepTarget)
	local unitSelf = core.unitSelf
	local nDamageMin = object.GetAttackDamageMinOnCreepOld(unitCreepTarget)

	if unitCreepTarget and unitCreepTarget:GetTeam() ~= unitSelf:GetTeam() then
		if (skills.abilDefilingTouch:GetCharges() > 0) then
			nDamageMin = nDamageMin + skills.abilDefilingTouch:GetLevel() * 15
		end
	end
	return nDamageMin
end
object.GetAttackDamageMinOnCreepOld = core.GetAttackDamageMinOnCreep
core.GetAttackDamageMinOnCreep = GetAttackDamageMinOnCreep


--------------------
-- Self Position Override
-- pick a corpse up if near
--------------------
local function CustomPositionSelfExecuteOverride(botBrain)

StartProfile("Get Corpses Behavior")
	local nCurrentTimeMS = HoN.GetGameTime()
	local unitSelf = core.unitSelf
	local vecMyPosition = unitSelf:GetPosition()

	if core.unitSelf:IsChanneling() then
		return
	end

	local vecDesiredPos = vecMyPosition
	local unitTarget = nil
	vecDesiredPos, unitTarget = behaviorLib.PositionSelfLogic(botBrain)


	--No Charge on Defiling Touch? Grab a corpse nearby // No API  = high cost
	local abilDefilingTouch = skills.abilDefilingTouch
	if abilDefilingTouch:GetLevel() > 0 and abilDefilingTouch:GetCharges() == 0 then
		local tCorpses = HoN.GetUnitsInRadius(vecMyPosition, 400, core.UNIT_MASK_CORPSE + core.UNIT_MASK_UNIT)
		if core.NumberElements(tCorpses) > 0 then
			local closestCorpse = nil
			local nClosestCorpseDistSq = 9999*9999
			for key, v in pairs(tCorpses) do
				local vecCorpsePosition = v:GetPosition()
				--"safe" corpses aren't toward the opponents.
				if not behaviorLib.vecLaneForward or abs(core.RadToDeg(core.AngleBetween(vecCorpsePosition - vecMyPosition, -behaviorLib.vecLaneForward)) ) < 130 then
					local nDistSq = Vector3.Distance2DSq(vecCorpsePosition, vecMyPosition)
					if nDistSq < nClosestCorpseDistSq then
						closestCorpse = v
						nClosestCorpseDistSq = nDistSq
					end
				end
			end
			if closestCorpse then
				vecDesiredPos = closestCorpse:GetPosition()
			end
		end
	end
StopProfile()

	if vecDesiredPos then
		behaviorLib.MoveExecute(botBrain, vecDesiredPos)
	else
		BotEcho("PositionSelfExecute - nil desired position")
		return false
	end
end
object.PositionSelfExecuteOld = behaviorLib.PositionSelfExecute
behaviorLib.PositionSelfBehavior["Execute"] = CustomPositionSelfExecuteOverride


----------------------------------
-- Retreating
-- Overrride
----------------------------------

----------------------------------
--Retreat
----------------------------------
--Decrease the value of the normal retreat behavior
object.nOldRetreatFactor = 0.9
--Base threat. Level differences and distance alter the actual threat level.
object.nEnemyBaseThreat = 6
--Ensure hero will not be too carefull
object.nMaxLevelDifference = 4
--use Tablet if Retreat-Utility is above 40
object.nTabletRetreatTreshold = 40
object.nPKTRetreathreshold = 35

---------------------------------------------------------------
--This function calculates how threatening an enemy hero is
--return the thread value
---------------------------------------------------------------
local function funcGetThreatOfEnemy(unitEnemy)
	--no unit selected or is dead
	if not unitEnemy or not unitEnemy:IsAlive() then return 0 end
	local unitSelf = core.unitSelf

	local vecMyPosition = unitSelf:GetPosition()
	local vecEnemyPosition = funcGetEnemyPosition(unitEnemy)
	local nDistanceSq = Vector3.Distance2DSq(vecMyPosition, vecEnemyPosition)

	--BotEcho("Distance: MyPosition"..tostring(vecMyPosition).." your position "..tostring(vecEnemyPosition).." Square "..nDistanceSq)

	--unit is probably far away
	if nDistanceSq > (2000 * 2000) then
		--BotEcho("UnitEnemy is"..unitEnemy:GetTypeName().."Distance"..nDistanceSq)
		return 0
	end

	local nMyLevel = unitSelf:GetLevel()
	local nEnemyLevel = unitEnemy:GetLevel()

	--Level differences increase / decrease actual nThreat
	local nThreat = object.nEnemyBaseThreat + Clamp(nEnemyLevel - nMyLevel, 0, object.nMaxLevelDifference)

	--Range-Formula to increase threat: T(x) = (a*x +b) / (c*x+d); x: distance, T(x): threat
	-- T(700²) = 2, T(1100²) = 1.5, T(2000²)= 0.75
	local y = (3 * ((-1) * nDistanceSq + 112810000)) / 
			  (4 * (  19 * nDistanceSq +  32810000))	
			  -- There's no reason for these magic numbers. You can totally represent the 0.75 <= y <= 2 portion 
			  -- of the resultant graph (which is the part you use) with a linear function. --[S2]malloc
			  -- To see the graph, punch "graph y = (3 * ((-1) * x^2+ 112810000)) / (4 * (  19 * x^2 +  32810000))" 
			  -- into Google.
	
	nThreat = Clamp (y, 0.75, 2) * nThreat

	return nThreat
end

------------------------------------------------------------------
--Retreat utility
------------------------------------------------------------------
local function CustomRetreatFromThreatUtilityFnOverride(botBrain)
	local bDebugEchos = false

	local nUtilityOld = behaviorLib.lastRetreatUtil
	--decrease old ThreatUtility
	local nUtility = object.RetreatFromThreatUtilityOld(botBrain) * object.nOldRetreatFactor

	--decay with a maximum of 4 utilitypoints per frame to ensure a longer retreat time
	if nUtilityOld > nUtility + 4 then
		nUtility = nUtilityOld -4
	end

	--bonus of allies decrease fear
	local allies = core.localUnits["AllyHeroes"]
	local nAllies = core.NumberElements(allies) + 1

	--get enemy heroes
	local tEnemyTeam = HoN.GetHeroes(core.enemyTeam)

	--calculate the threat-value and increase utility value
	for id, enemy in pairs(tEnemyTeam) do
	--BotEcho (id.." Hero "..enemy:GetTypeName())
		nUtility = nUtility + funcGetThreatOfEnemy(enemy) / nAllies
	end
	
	return Clamp(nUtility, 0, 100)
end
object.RetreatFromThreatUtilityOld =  behaviorLib.RetreatFromThreatUtility
behaviorLib.RetreatFromThreatBehavior["Utility"] = CustomRetreatFromThreatUtilityFnOverride


------------------------------------------------------------------
--Retreat execute
------------------------------------------------------------------
local function funcRetreatFromThreatExecuteOverride(botBrain)

	local unitSelf = core.unitSelf
	local unitTarget = behaviorLib.heroTarget

	local vecRetreatPos = behaviorLib.PositionSelfBackUp()
	local nlastRetreatUtil = behaviorLib.lastRetreatUtil

	--Counting the enemies
	local tEnemies = core.localUnits["EnemyHeroes"]
	local nCount = 0

	local bCanSeeUnit = unitTarget and core.CanSeeUnit(botBrain, unitTarget)
	for id, unitEnemy in pairs(tEnemies) do
		if core.CanSeeUnit(botBrain, unitEnemy) then
			nCount = nCount + 1
		end
	end

	-- More enemies or low on life
	if nCount > 1 or unitSelf:GetHealthPercent() < .4 then

		--Portal Key: Port away
		local itemPortalKey = core.itemPortalKey
		if itemPortalKey and nlastRetreatUtil >= object.nPKTRetreathreshold then
			if itemPortalKey:CanActivate()  then
				core.OrderItemPosition(botBrain, unitSelf, itemPortalKey, vecRetreatPos)
				return
			end
		end

		if bCanSeeUnit then
			local vecMyPosition = unitSelf:GetPosition()
			local vecTargetPosition = unitTarget:GetPosition()
			local nTargetDistanceSq = Vector3.Distance2DSq(vecMyPosition, vecTargetPosition)
			local bTargetVuln = unitTarget:IsStunned() or unitTarget:IsImmobilized()

			--Sheepstick
			local itemSheepstick = core.itemSheepstick
			if itemSheepstick and not bTargetVuln then
				local nRange = itemSheepstick:GetRange()
				if itemSheepstick:CanActivate() then
					if nTargetDistanceSq < (nRange * nRange) then
						core.OrderItemEntityClamp(botBrain, unitSelf, itemSheepstick, unitTarget)
						return
					end
				end
			end

			--Stun
			local abilCorpseToss = skills.abilCorpseToss
			local nNow = HoN.GetGameTime()
			if abilCorpseToss:CanActivate() and (nNow > object.nOneCorpseTossUseTime + 900) then
				if not bTargetVuln or (nNow < object.nOneCorpseTossUseTime + 1050) then
					local nRange = abilCorpseToss:GetRange()
					if nTargetDistanceSq < (nRange * nRange) then
						core.OrderAbilityEntity(botBrain, abilCorpseToss, unitTarget)
						return
					end
				end
			end

			--Frostfield Plate
			local itemFrostfieldPlate = core.itemFrostfieldPlate
			if itemFrostfieldPlate then
				local nRange = itemFrostfieldPlate:GetTargetRadius()
				if itemFrostfieldPlate:CanActivate() and nTargetDistanceSq < (nRange * nRange) then
					core.OrderItemClamp(botBrain, unitSelf, itemFrostfieldPlate)
					return
				end
			end
		end
		
	end -- critical situation

	--Activate ghost marchers if we can
	local itemGhostMarchers = core.itemGhostMarchers
	if itemGhostMarchers and itemGhostMarchers:CanActivate() and behaviorLib.lastRetreatUtil >= behaviorLib.retreatGhostMarchersThreshold then
		core.OrderItemClamp(botBrain, core.unitSelf, itemGhostMarchers)
		return
	end

	--Just use Tablet if you are in great danger
	local itemTablet = core.itemTablet
	if itemTablet then
		if itemTablet:CanActivate() and nlastRetreatUtil >= object.nTabletRetreatTreshold then
			--TODO: GetHeading math to ensure we're actually going backwards
			core.OrderItemEntityClamp(botBrain, unitSelf, itemTablet, unitSelf)
			return
		end
	end

	--Use Sacreficial Stone
	--TODO: remove all sac stone usage into its own behavior
	local itemSacStone = core.itemSacStone
	if itemSacStone and itemSacStone:CanActivate() then
		core.OrderItemClamp(botBrain, unitSelf, itemSacStone)
		return
	end

	core.OrderMoveToPosClamp(botBrain, core.unitSelf, vecRetreatPos, false)
end

object.RetreatFromThreatExecuteOld = behaviorLib.RetreatFromThreatExecute
behaviorLib.RetreatFromThreatBehavior["Execute"] = funcRetreatFromThreatExecuteOverride



----------------------------------
--Push
----------------------------------
object.nCorpseExplosionManaPercentTreshold = 0.85

------------------------------------------------------------------
--Push execute
------------------------------------------------------------------
local function PushExecuteFnOverride(botBrain)

	if core.unitSelf:IsChanneling() then
		return
	end

	local bActionTaken = false

	--Use Sacreficial Stone
	--Todo: remove all sac stone usage into its own behavior
	if not bActionTaken then
		local itemSacStone = core.itemSacStone
		if itemSacStone and itemSacStone:CanActivate() then
			bActionTaken = core.OrderItemClamp(botBrain, unitSelf, itemSacStone)
		end
	end

	if not bActionTaken then
		--use corpse explosion
		if skills.abilCorpseExplosion:CanActivate() and core.unitSelf:GetManaPercent() > object.nCorpseExplosionManaPercentTreshold then
			local nRange = skills.abilCorpseExplosion:GetRange()
			local unitTarget = core.unitEnemyCreepTarget
			local nNumberEnemyCreeps =  core.NumberElements(core.localUnits["EnemyCreeps"])
			if unitTarget and nNumberEnemyCreeps > object.nRequiredCorpses then
				local vecTargetPosition = unitTarget:GetPosition()
StartProfile('Push - LookForCorpses')
				--looking for creep corpses (tCorpses) and summoned corpses (tPets) in range // no API = high cost
				local tCorpses = HoN.GetUnitsInRadius(vecTargetPosition, 225, core.UNIT_MASK_CORPSE + core.UNIT_MASK_UNIT)
				local tPets = HoN.GetUnitsInRadius(vecTargetPosition, 225, core.UNIT_MASK_ALIVE + core.UNIT_MASK_UNIT)
				local nNumberCorpses = core.NumberElements(tCorpses)

				for x, creep in pairs(tPets) do
					--Different summon types
					if creep:GetTypeName() == "Pet_Taint_Ability3" or creep:GetTypeName() == "Pet_Taint_Ability4_Explode" then
						nNumberCorpses = nNumberCorpses + 1
					end
				end
StopProfile()				
				--enough corpses in range?
				if nNumberCorpses >= object.nRequiredCorpses  then
					bActionTaken = core.OrderAbilityPosition(botBrain, skills.abilCorpseExplosion, vecTargetPosition)
				end
			end
		end
	end

	if not bActionTaken then
		object.PushExecuteOld(botBrain)
	end
end

object.PushExecuteOld = behaviorLib.PushExecute
behaviorLib.PushBehavior["Execute"] = PushExecuteFnOverride


------------------------------------------------------------------
--Heal at well utility
------------------------------------------------------------------
local function CustomHealAtWellUtilityFnOverride(botBrain)
	local nUtility = 0
	local nHPPercent = core.unitSelf:GetHealthPercent()
	local nMPPercent = core.unitSelf:GetManaPercent()

	--low hp increases wish to go home
	if nHPPercent < 0.90 then
		local wellPos = core.allyWell and core.allyWell:GetPosition() or Vector3.Create()
		local nDist = Vector3.Distance2D(wellPos, core.unitSelf:GetPosition())

		nUtility = behaviorLib.WellHealthUtility(nHPPercent) + behaviorLib.WellProximityUtility(nDist)
	end
	
	--low mana increases wish to go home
	if nMPPercent < 0.90 then
		nUtility = nUtility + nMPPercent * 10
	end

	return Clamp(nUtility, 0, 50)
end
object.HealAtWellUtilityOld =  behaviorLib.HealAtWellUtility
behaviorLib.HealAtWellBehavior["Utility"] = CustomHealAtWellUtilityFnOverride


------------------------------------------------------------------
--Heal at well execute
------------------------------------------------------------------
local function HealAtWellExecuteFnOverride(botBrain)
	--BotEcho("Returning to well!")
	local vecWellPos = core.allyWell and core.allyWell:GetPosition() or behaviorLib.PositionSelfBackUp()
	local nDistanceWellSq =  Vector3.Distance2DSq(core.unitSelf:GetPosition(), vecWellPos)

	--Activate ghost marchers if we can
	local itemGhostMarchers = core.itemGhostMarchers
	if itemGhostMarchers and itemGhostMarchers:CanActivate() and nDistanceWellSq > (500 * 500) then
		core.OrderItemClamp(botBrain, core.unitSelf, itemGhostMarchers)
		return
	end

	--Just use Tablet
	local itemTablet = core.itemTablet
	if itemTablet then
		if itemTablet:CanActivate() and nDistanceWellSq > (500 * 500) then		
			--TODO: GetHeading math to ensure we're actually going in the right direction
			core.OrderItemEntityClamp(botBrain, core.unitSelf, itemTablet, core.unitSelf)
			return
		end
	end

	--Portal Key: Port away
	local itemPortalKey = core.itemPortalKey
	if itemPortalKey then
		if itemPortalKey:CanActivate() and nDistanceWellSq > (1000 * 1000) then
			core.OrderItemPosition(botBrain, unitSelf, itemPortalKey, vecWellPos)
			return
		end
	end

	core.OrderMoveToPosAndHoldClamp(botBrain, core.unitSelf, vecWellPos, false)
end
object.HealAtWellExecuteOld = behaviorLib.HealAtWellExecute
behaviorLib.HealAtWellBehavior["Execute"] = HealAtWellExecuteFnOverride


----------------------------------
--  FindItems Override
----------------------------------
local function funcFindItemsOverride(botBrain)
	object.FindItemsOld(botBrain)
	--shoppingLib update - call item by name (itemHandler)
	core.itemPostHaste = itemHandler:GetItem("Item_PostHaste") 
	core.itemTablet = itemHandler:GetItem("Item_PushStaff") 
	core.itemPortalKey = itemHandler:GetItem("Item_PortalKey") 
	core.itemFrostfieldPlate = itemHandler:GetItem("Item_FrostfieldPlate") 
	core.itemSacStone = itemHandler:GetItem("Item_SacrificialStone") 
	core.itemSheepstick = itemHandler:GetItem("Item_Morph") 
	core.itemHellFlower = itemHandler:GetItem("Item_Silence") 
end
object.FindItemsOld = core.FindItems
core.FindItems = funcFindItemsOverride

----------------------------------
--      Gravekeeper Item Build
----------------------------------
--[[ list code:
	"# Item" is "get # of these"
	"Item #" is "get this level of the item" --]]

--ItemBuild

--1.Starting items
shoppingLib.tStartingItems = {"Item_RunesOfTheBlight", "2 Item_MarkOfTheNovice", "2 Item_MinorTotem", "Item_HealthPotion"}

--2.Lane items
shoppingLib.tLaneItems = {"Item_Marchers","Item_GraveLocket"}

--3.1 item route bad
--shoppingLib.tMidItems =	{"Item_EnhancedMarchers", "Item_Silence"} --Ghost Marchers and Hellflower
	
--3.2 item route good
--shoppingLib.tMidItems = {"Item_Steamboots", "Item_MysticVestments", "Item_Scarab",  "Item_SacrificialStone", "Item_Silence"}

--4 late game items
shoppingLib.tLateItems = {"Item_Morph", "Item_FrostfieldPlate", "Item_PostHaste", "Item_Freeze", "Item_Damage9"}

--situational tablet
--poor farm (<240 gpm at lvl 11+ and boots finished)

--situational pk
--well farmed (>= 300 gpm after boots finished)

--Gravekeeper Shopping function
local function GravekeeperItemBuilder()
	--called everytime your bot runs out of items, should return false if you are done with shopping
	local debugInfo = false
    
	if debugInfo then BotEcho("Checking itembuilder of Gravekeeper") end
	
	--variable for new items / keep shopping
	local bNewItems = false
	  
	--get itembuild decision table 
	local tItemDecisions = shoppingLib.tItemDecisions
	if debugInfo then BotEcho("Found ItemDecisions"..type(tItemDecisions)) end
	
	--decision helper
	local nGPM = object:GetGPM()
	
	--early game (start items and lane items
	
	--If tItemDecisions["bStartingItems"] is not set yet, choose start and lane items
		if not tItemDecisions.bStartingItems then
			--insert decisions into our itembuild-table
			core.InsertToTable(shoppingLib.tItembuild, shoppingLib.tStartingItems)
			core.InsertToTable(shoppingLib.tItembuild, shoppingLib.tLaneItems)
			
					
			--we have implemented new items, so we can keep shopping
			bNewItems = true
					
			--remember our decision
			tItemDecisions.bStartingItems = true
		
	--If tItemDecisions["bItemBuildRoute"] is not set yet, choose boots and item route
		elseif not tItemDecisions.bItemBuildRoute then
			
			local sBootsChosen = nil
			local tMidItems = nil
			
			--decision helper
			local nMatchTime = HoN.GetMatchTime()
			local nXPM = core.unitSelf:GetXPM()
			
			--check  for agressive or passive route
			if nXPM <= 175 and nMatchTime > core.MinToMS(5) then
				--Bad early game: go for more defensive items
				sBootsChosen = "Item_Steamboots"
				tMidItems = {"Item_MysticVestments", "Item_Scarab",  "Item_SacrificialStone", "Item_Silence"}
			else
				--go aggressive
				sBootsChosen = "Item_EnhancedMarchers"
				tMidItems = {"Item_Silence"}
			end
			
			--insert decisions into our itembuild-table: the boots
			tinsert(shoppingLib.tItembuild, sBootsChosen)
			
			--insert items into default itemlist (Mid and Late-Game items)
			tItemDecisions.tItemList = {}
			tItemDecisions.nItemListPosition = 1
			core.InsertToTable(tItemDecisions.tItemList, tMidItems)
			core.InsertToTable(tItemDecisions.tItemList, shoppingLib.tLateItems)
					
			--we have implemented new items, so we can keep shopping
			bNewItems = true
					
			--remember our decision
			tItemDecisions.bItemBuildRoute = true
			
	--need Tablet?
		elseif not tItemDecisions.bGetTablet and core.unitSelf:GetLevel() > 10 and nGPM <= 250 then
			--Mid game: Bad farm, so go for a tablet
			
			--insert decisions into our itembuild-table
			tinsert(shoppingLib.tItembuild, "Item_PushStaff")
			
			--we have implemented new items, so we can keep shopping
			bNewItems = true
			
			--remember our decision
			tItemDecisions.bGetTablet = true
			
	--need Portal Key?	
		elseif not tItemDecisions.bGetPK and nGPM >= 300 then
			--Mid game: High farm, so go for pk 
			
			--insert decisions into our itembuild-table
			tinsert(shoppingLib.tItembuild, "Item_PortalKey")
			
			--we have implemented new items, so we can keep shopping
			bNewItems = true
			--remember our decision
			tItemDecisions.bGetPK = true
			
	--all other items
		else
		
			--put default items into the item build list (One after another)
			local tItemList = tItemDecisions.tItemList
			local nItemListPosition = tItemDecisions.nItemListPosition
			
			local sItemCode = tItemList[nItemListPosition]
			if sItemCode then
				--got a new item code 
				
				--insert decisions into our itembuild-table
				tinsert(shoppingLib.tItembuild, sItemCode)
				
				--next item position
				tItemDecisions.nItemListPosition = nItemListPosition + 1
				
				--we have implemented new items, so we can keep shopping
				bNewItems = true
			end
			
		end
	   
	if debugInfo then BotEcho("Reached end of itembuilder-function. Keep shopping? "..tostring(bNewItems)) end
	return bNewItems
end
object.oldItembuilder = shoppingLib.CheckItemBuild
shoppingLib.CheckItemBuild = GravekeeperItemBuilder

--####################################################################
--####################################################################
--#								 									##
--#   CHAT FUNCTIONSS					       						##
--#								 									##
--####################################################################
--####################################################################

object.tCustomKillKeys = {
	"schnarchnase_grave_kill1",
	"schnarchnase_grave_kill2",
	"schnarchnase_grave_kill3",
	"schnarchnase_grave_kill4",
	"schnarchnase_grave_kill5",
	"schnarchnase_grave_kill6",
	"schnarchnase_grave_kill7"   }

local function GetKillKeysOverride(unitTarget)
	local tChatKeys = object.funcGetKillKeysOld(unitTarget)
	core.InsertToTable(tChatKeys, object.tCustomKillKeys)
	return tChatKeys
end
object.funcGetKillKeysOld = core.GetKillKeys
core.GetKillKeys = GetKillKeysOverride


object.tCustomRespawnKeys = {
	"schnarchnase_grave_respawn1",
	"schnarchnase_grave_respawn2",
	"schnarchnase_grave_respawn3",
	"schnarchnase_grave_respawn4"	}

local function GetRespawnKeysOverride()
	local tChatKeys = object.funcGetRespawnKeysOld()
	core.InsertToTable(tChatKeys, object.tCustomRespawnKeys)
	return tChatKeys
end
object.funcGetRespawnKeysOld = core.GetRespawnKeys
core.GetRespawnKeys = GetRespawnKeysOverride


object.tCustomDeathKeys = {
	"schnarchnase_grave_death1",
	"schnarchnase_grave_death2",
	"schnarchnase_grave_death3",
	"schnarchnase_grave_death4"  }

local function GetDeathKeysOverride(unitSource)
	local tChatKeys = object.funcGetDeathKeysOld(unitSource)
	core.InsertToTable(tChatKeys, object.tCustomDeathKeys)
	return tChatKeys
end
object.funcGetDeathKeysOld = core.GetDeathKeys
core.GetDeathKeys = GetDeathKeysOverride

BotEcho('finished loading gravekeeper_main')
