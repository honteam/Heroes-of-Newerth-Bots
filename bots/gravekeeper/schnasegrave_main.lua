--[[
Gravekeeper v1.0b by Schnarchnase

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


BotEcho('loading schnasegrave_main...')

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


----------------------
-- altered vers for last hitting. Using Defiling Touch for Damage Amp
-- credits base version: paradox870
----------------
 local function funcValidateCreepTarget(nDamageMin, unitCreepTarget, tAttackingCreeps, tAttackingTowers)
	if not unitCreepTarget then 
		return
	end

	local unitSelf = core.unitSelf
	local nTargetHealth = unitCreepTarget:GetHealth()
	local nExpectedCreepDamage = 0
	local nExpectedTowerDamage = 0
	local vecSelfPosition = unitSelf:GetPosition()
	local nProjectileSpeed = unitSelf:GetAttackProjectileSpeed()

	local vecTargetPos = unitCreepTarget:GetPosition()
	local nProjectileTravelTime = Vector3.Distance2D(vecSelfPosition, vecTargetPos) / nProjectileSpeed

	--Determine the damage expected on the creep by other creeps
	for i, unitCreep in pairs(tAttackingCreeps) do
		if unitCreep:GetAttackTarget() == unitCreepTarget then
			local nCreepAttacks = 1 + math.floor(unitCreep:GetAttackSpeed() * nProjectileTravelTime)
			nExpectedCreepDamage = nExpectedCreepDamage + unitCreep:GetFinalAttackDamageMin() * nCreepAttacks
		end
	end

	--Determine the damage expected on the creep by towers
	for i, unitTower in pairs(tAttackingTowers) do
		if unitTower:GetAttackTarget() == unitCreepTarget then
			local nTowerAttacks = 1 + math.floor(unitTower:GetAttackSpeed() * nProjectileTravelTime)
			nExpectedTowerDamage = nExpectedTowerDamage + unitTower:GetFinalAttackDamageMin() * nTowerAttacks
		end
	end
	 --Only attack if, by the time our attack reaches the target
	-- the damage done by other sources brings the target's health
	-- below our minimum damage
	if nDamageMin >= (nTargetHealth - nExpectedCreepDamage - nExpectedTowerDamage) then

		return unitCreepTarget
	end

	return
 end

local function GetCreepAttackTarget(botBrain, unitEnemyCreep, unitAllyCreep) --called pretty much constantly

  local unitSelf = core.unitSelf
	local nDamageMin = unitSelf:GetFinalAttackDamageMin()
	local unitCreepTarget = nil

	if unitEnemyCreep and core.CanSeeUnit(botBrain, unitEnemyCreep) then
		local nDefileDamage = 0 
		
		--increase dmgMin
		if (skills.abilDefilingTouch:GetCharges() > 0) then
			nDefileDamage = skills.abilDefilingTouch:GetLevel() * 15
		end
		
		local tAttackingCreeps = core.localUnits['AllyCreeps']
		local tAttackingTowers = core.localUnits['AllyTowers']
		unitCreepTarget = funcValidateCreepTarget(nDamageMin + nDefileDamage, unitEnemyCreep, tAttackingCreeps, tAttackingTowers)
	end

	--if there is no creep to last hit, check for deny
	if unitAllyCreep and not unitCreepTarget then
		local tAttackingCreeps = core.localUnits['EnemyCreeps']
		local tAttackingTowers = core.localUnits['EnemyTowers']
		unitCreepTarget = funcValidateCreepTarget(nDamageMin, unitAllyCreep, tAttackingCreeps, tAttackingTowers)
	end

	return unitCreepTarget

end
 object.GetCreepAttackTargetOld = behaviorLib.GetCreepAttackTarget
 behaviorLib.GetCreepAttackTarget = GetCreepAttackTarget

local function AttackCreepsExecuteOverride(botBrain)
	--TODO: Fix/Generalize
	local unitSelf = core.unitSelf
	local unitCreepTarget = core.unitCreepTarget
	local vecSelfPos = unitSelf:GetPosition()

	if unitCreepTarget and core.CanSeeUnit(botBrain, unitCreepTarget) then
		--Get info about the target we are about to attack
		local vecTargetPos = unitCreepTarget:GetPosition()
		local nDistSq = Vector3.Distance2DSq(vecSelfPos, vecTargetPos)
		local nAttackRangeSq = core.GetAbsoluteAttackRangeToUnit(unitSelf, currentTarget, true)
		local nTargetHealth = unitCreepTarget:GetHealth()
		local nDamageMin = unitSelf:GetFinalAttackDamageMin()


		--Get projectile info
		local nProjectileSpeed = unitSelf:GetAttackProjectileSpeed()
		local nProjectileTravelTime = Vector3.Distance2D(vecSelfPos, vecTargetPos) / nProjectileSpeed
		if bDebugEchos then BotEcho ("Projectile travel time: " .. nProjectileTravelTime ) end

		local nExpectedCreepDamage = 0
		local nExpectedTowerDamage = 0
		local tNearbyAttackingCreeps = nil
		local tNearbyAttackingTowers = nil


		--Get the creeps and towers on the opposite team
		-- of our target
		if unitCreepTarget:GetTeam() == unitSelf:GetTeam() then
			tNearbyAttackingCreeps = core.localUnits['EnemyCreeps']
			tNearbyAttackingTowers = core.localUnits['EnemyTowers']
		else
			tNearbyAttackingCreeps = core.localUnits['AllyCreeps']
			tNearbyAttackingTowers = core.localUnits['AllyTowers']
			if (skills.abilDefilingTouch:GetCharges() > 0) then
				nDamageMin = nDamageMin + skills.abilDefilingTouch:GetLevel() * 15
			end
		end

		--Determine the damage expected on the creep by other creeps
		for i, unitCreep in pairs(tNearbyAttackingCreeps) do
			if unitCreep:GetAttackTarget() == unitCreepTarget then
				local nCreepAttacks = 1 + math.floor(unitCreep:GetAttackSpeed() * nProjectileTravelTime)
				nExpectedCreepDamage = nExpectedCreepDamage + unitCreep:GetFinalAttackDamageMin() * nCreepAttacks
			end
		end

		--Determine the damage expected on the creep by other towers
		for i, unitTower in pairs(tNearbyAttackingTowers) do
			if unitTower:GetAttackTarget() == unitCreepTarget then
				local nTowerAttacks = 1 + math.floor(unitTower:GetAttackSpeed() * nProjectileTravelTime)
				nExpectedTowerDamage = nExpectedTowerDamage + unitTower:GetFinalAttackDamageMin() * nTowerAttacks
			end
		end



		--Only attack if, by the time our attack reaches the target
		-- the damage done by other sources brings the target's health
		-- below our minimum damage, and we are in range and can attack right now
		if nDistSq < nAttackRangeSq and unitSelf:IsAttackReady() and nDamageMin >= (nTargetHealth - nExpectedCreepDamage - nExpectedTowerDamage) then
			core.OrderAttackClamp(botBrain, unitSelf, unitCreepTarget)


		--Otherwise get within 70% of attack range if not already
		-- This will decrease travel time for the projectile
		elseif (nDistSq > nAttackRangeSq * 0.5) then
			local vecDesiredPos = core.AdjustMovementForTowerLogic(vecTargetPos)
			core.OrderMoveToPosClamp(botBrain, unitSelf, vecDesiredPos, false)


		--If within a good range, just hold tight
		else
			core.OrderHoldClamp(botBrain, unitSelf, false)
		end
	else
		--TODO: Separate into a different behavior
		local abilDefilingTouch = skills.abilDefilingTouch
		if abilDefilingTouch:GetLevel() > 0 and abilDefilingTouch:GetCharges() == 0 then
			local tCorpses = HoN.GetUnitsInRadius(vecSelfPos, 400, core.UNIT_MASK_CORPSE + core.UNIT_MASK_UNIT)
			if core.NumberElements(tCorpses) > 0 then
				local closestCorpse = nil
				local nClosestCorpseDistSq = 9999*9999
				for key, v in pairs(tCorpses) do
					local vecCorpsePosition = v:GetPosition()
					--"safe" corpses aren't toward the opponents.
					if not behaviorLib.vecLaneForward or abs(core.RadToDeg(core.AngleBetween(vecCorpsePosition - vecSelfPos, -behaviorLib.vecLaneForward)) ) < 130 then
						local nDistSq = Vector3.Distance2DSq(vecCorpsePosition, vecSelfPos)
						if nDistSq < nClosestCorpseDistSq then
							closestCorpse = v
							nClosestCorpseDistSq = nDistSq
						end
					end
				end
				if closestCorpse then
					vecDesiredPos = closestCorpse:GetPosition()
				end
				behaviorLib.MoveExecute(botBrain, vecDesiredPos)
			end
		end
	end
end
object.AttackCreepsExecuteOld = behaviorLib.AttackCreepsBehavior["Execute"]
behaviorLib.AttackCreepsBehavior["Execute"] = AttackCreepsExecuteOverride


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
			  -- curse your magic numbers! you can totally represent the 0.75 <= y <= 2 portion with a linear function
			  -- To see the graph, punch "graph y = (3 * ((-1) * x^2+ 112810000)) / (4 * (  19 * x^2 +  32810000))" into Google.
	
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
	if nUtilityOld > nUtility +4 then
		nUtility = nUtilityOld -4
	end

	--bonus of allies decrease fear
	local allies = core.localUnits["AllyHeroes"]
	local nAllies = core.NumberElements(allies) + 1

	--get enemy heroes
	local tEnemyTeam = core.teamBotBrain.tEnemyHeroes

	--calculate the threat-value and increase utility value
	local nThreatUtility = 0
	for id, enemy in pairs(tEnemyTeam) do
	--BotEcho (id.." Hero "..enemy:GetTypeName())
		nThreatUtility = nThreatUtility + funcGetThreatOfEnemy(enemy)
	end
	
	nUtility = nUtility + nThreatUtility / nAllies
	
	return Clamp(nUtility, 0, 100)

end
object.RetreatFromThreatUtilityOld =  behaviorLib.RetreatFromThreatUtility
behaviorLib.RetreatFromThreatBehavior["Utility"] = CustomRetreatFromThreatUtilityFnOverride


------------------------------------------------------------------
--Retreat execute
------------------------------------------------------------------
--  this is a great function to override with using retreating skills, such as blinks, travels, stuns or slows.
function behaviorLib.CustomRetreatExecute(botBrain)
	bActionTaken = false
	local unitSelf = core.unitSelf
	local unitTarget = behaviorLib.heroTarget
	local nlastRetreatUtil = behaviorLib.lastRetreatUtil
	local bCanSeeAggressor = unitTarget and core.CanSeeUnit(botBrain, unitTarget)
	local vecPos = behaviorLib.PositionSelfBackUp()
	
	--Counting the enemies
	local tEnemies = core.localUnits["EnemyHeroes"]
	local nCount = 0
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
				return core.OrderItemPosition(botBrain, unitSelf, itemPortalKey, vecPos)
			end
		end

		if bCanSeeAggressor then
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
						return core.OrderItemEntityClamp(botBrain, unitSelf, itemSheepstick, unitTarget)
					end
				end
			end

			--Stun
			local abilCorpseToss = skills.abilCorpseToss
			local nNow = HoN.GetGameTime()
			if abilCorpseToss:CanActivate() and nNow > (object.nOneCorpseTossUseTime + 900) then
				if not bTargetVuln or nNow < (object.nOneCorpseTossUseTime + 1050) then
					local nRange = abilCorpseToss:GetRange()
					if nTargetDistanceSq < (nRange * nRange) then
						return core.OrderAbilityEntity(botBrain, abilCorpseToss, unitTarget)
					end
				end
			end

			--Frostfield Plate
			local itemFrostfieldPlate = core.itemFrostfieldPlate
			if itemFrostfieldPlate then
				local nRange = itemFrostfieldPlate:GetTargetRadius()
				if itemFrostfieldPlate:CanActivate()  then
					if nTargetDistanceSq < (nRange * nRange) then
						return core.OrderItemClamp(botBrain, unitSelf, itemFrostfieldPlate)
					end
				end
			end
		end
	end

	--Activate ghost marchers if we can
	local itemGhostMarchers = core.itemGhostMarchers
	if itemGhostMarchers and itemGhostMarchers:CanActivate() then
		if behaviorLib.lastRetreatUtil >= behaviorLib.retreatGhostMarchersThreshold then
			return core.OrderItemClamp(botBrain, core.unitSelf, itemGhostMarchers)
		end
	end

	--Just use Tablet if you are in great danger
	local itemTablet = core.itemTablet
	if itemTablet then
		if itemTablet:CanActivate() and nlastRetreatUtil >= object.nTabletRetreatTreshold then
			--TODO: check heading when that's exposed in the API
			return core.OrderItemEntityClamp(botBrain, unitSelf, itemTablet, unitSelf)
		end
	end

	--Use Sacreficial Stone
	local itemSacStone = core.itemSacStone
	if itemSacStone and itemSacStone:CanActivate() then
		return core.OrderItemClamp(botBrain, unitSelf, itemSacStone)
	end
	
	return false
end

--TODO: I feel like there are alltogether too many places where we're turning on Sac Stone. Perhaps it should be 
--  its own behavior that's like 99 as long as it's off (since its cooldown matches its duration)

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
	local utility = 0
	local hpPercent = core.unitSelf:GetHealthPercent()
	local mpPercent = core.unitSelf:GetManaPercent()

	--low hp increases wish to go home
	if hpPercent < 0.90 then
		local wellPos = core.allyWell and core.allyWell:GetPosition() or Vector3.Create()
		local nDist = Vector3.Distance2D(wellPos, core.unitSelf:GetPosition())

		utility = behaviorLib.WellHealthUtility(hpPercent) + behaviorLib.WellProximityUtility(nDist)
	end
	
	--low mana increases wish to go home
	if mpPercent < 0.90 then
		utility = utility + mpPercent * 10
	end

	return Clamp(utility, 0, 50)
end
object.HealAtWellUtilityOld =  behaviorLib.HealAtWellUtility
behaviorLib.HealAtWellBehavior["Utility"] = CustomHealAtWellUtilityFnOverride


------------------------------------------------------------------
--Heal at well execute
------------------------------------------------------------------
local function HealAtWellExecuteFnOverride(botBrain)
	--BotEcho("Returning to well!")
	local wellPos = core.allyWell and core.allyWell:GetPosition() or behaviorLib.PositionSelfBackUp()
	local distanceWellSq =  Vector3.Distance2DSq(core.unitSelf:GetPosition(), wellPos)

	--Activate ghost marchers if we can
	local itemGhostMarchers = core.itemGhostMarchers
	if itemGhostMarchers and itemGhostMarchers:CanActivate() and distanceWellSq > (500 * 500) then
		core.OrderItemClamp(botBrain, core.unitSelf, itemGhostMarchers)
		return
	end

	--Just use Tablet
	local itemTablet = core.itemTablet
	if itemTablet then
		if itemTablet:CanActivate() and distanceWellSq > (500 * 500) then
		--TODO: check heading when that's exposed in the API
			core.OrderItemEntityClamp(botBrain, core.unitSelf, itemTablet, core.unitSelf)
			return
		end
	end

			--Portal Key: Port away
	local itemPortalKey = core.itemPortalKey
	if itemPortalKey then
		if itemPortalKey:CanActivate()  and distanceWellSq > (1000 * 1000) then
			core.OrderItemPosition(botBrain, unitSelf, itemPortalKey, wellPos)
			return
		end
	end

	core.OrderMoveToPosAndHoldClamp(botBrain, core.unitSelf, wellPos, false)
end
object.HealAtWellExecuteOld = behaviorLib.HealAtWellExecute
behaviorLib.HealAtWellBehavior["Execute"] = HealAtWellExecuteFnOverride


--Function removes any item that is not valid
local function funcRemoveInvalidItems()
	core.ValidateItem(core.itemPostHaste)
	core.ValidateItem(core.itemTablet)
	core.ValidateItem(core.itemPortalKey)
	core.ValidateItem(core.itemHellFlower)
	core.ValidateItem(core.itemSheepstick)
	core.ValidateItem(core.itemFrostfieldPlate)
	core.ValidateItem(core.itemSteamboots)
	core.ValidateItem(core.itemSacStone)
	core.ValidateItem(core.itemGhostMarchers)
end

----------------------------------
--  FindItems Override
----------------------------------
local function funcFindItemsOverride(botBrain)

--local bUpdated = object.FindItemsOld(botBrain)

	--Alternate item wasn't checked, so you don't need to look for new items.
	if core.bCheckForAlternateItems then 
		return 
	end

	funcRemoveInvalidItems()

	--We only need to know about our current inventory. Stash items are not important.
	local inventory = core.unitSelf:GetInventory(false)
	for slot = 1, 6, 1 do
		local curItem = inventory[slot]
		if curItem then
			if core.itemPostHaste == nil and curItem:GetName() == "Item_PostHaste" then
				core.itemPostHaste = core.WrapInTable(curItem)
			elseif core.itemTablet == nil and curItem:GetName() == "Item_PushStaff" then
				core.itemTablet = core.WrapInTable(curItem)
			elseif core.itemPortalKey == nil and curItem:GetName() == "Item_PortalKey" then
				core.itemPortalKey = core.WrapInTable(curItem)
			elseif core.itemFrostfieldPlate == nil and curItem:GetName() == "Item_FrostfieldPlate" then
				core.itemFrostfieldPlate = core.WrapInTable(curItem)
			elseif core.itemSheepstick == nil and curItem:GetName() == "Item_Morph" then
				core.itemSheepstick = core.WrapInTable(curItem)
			elseif core.itemHellFlower == nil and curItem:GetName() == "Item_Silence" then
				core.itemHellFlower = core.WrapInTable(curItem)
			elseif core.itemSteamboots == nil and curItem:GetName() == "Item_Steamboots" then
				core.itemSteamboots = core.WrapInTable(curItem)
			elseif core.itemSacStone == nil and curItem:GetName() == "Item_SacrificialStone" then
				core.itemSacStone = core.WrapInTable(curItem)
			elseif core.itemGhostMarchers == nil and curItem:GetName() == "Item_EnhancedMarchers" then
				core.itemGhostMarchers = core.WrapInTable(curItem)
				core.itemGhostMarchers.expireTime = 0
				core.itemGhostMarchers.duration = 6000
				core.itemGhostMarchers.msMult = 0.12
			end

		end
	end
end
object.FindItemsOld = core.FindItems
core.FindItems = funcFindItemsOverride


--Check for alternate items before shopping
local function funcCheckforAlternateItemBuild(botbrain)

	--no further check till next shopping round
	core.bCheckForAlternateItems = false

	local unitSelf = core.unitSelf

	--initialize item choices
	if unitSelf.getPK == nil then
		--BotEcho("Initialize item choices")
		unitSelf.getSteamboots = false
		unitSelf.getPushStaff = false
		unitSelf.getPK = false
	end


	local nGPM = botbrain:GetGPM()
	local nXPM = unitSelf:GetXPM()
	local nMatchTime = HoN.GetMatchTime()
	local bBuyStateLow = behaviorLib.buyState < 3

	--Bad early game: skip GhostMarchers and go for more defensive items
	if bBuyStateLow and nXPM < 170 and nMatchTime > 300000  and not unitSelf.getSteamboots   then
		--BotEcho("My early Game sucked. I will go for a defensive Build.")
		unitSelf.getSteamboots = true
		behaviorLib.MidItems =
			{"Item_Steamboots", "Item_MysticVestments", "Item_Scarab",  "Item_SacrificialStone", "Item_Silence"}

	--Boots finished
	elseif core.itemGhostMarchers or core.itemSteamboots then

		--Mid game: Bad farm, so go for a tablet
		if unitSelf:GetLevel() > 10 and nGPM < 240 and not unitSelf.getPushStaff then
			--BotEcho("Well, it's not going as expected. Let's try a Tablet!")
			unitSelf.getPushStaff = true
			tinsert(behaviorLib.curItemList, 1, "Item_PushStaff")

		--Good farm and you finished your Boots. Now it is time to pick a portal key
		elseif nGPM >= 300 and not unitSelf.getPK then
			--BotEcho("The Game is going good. Soon I will kill them with a fresh PK!")
			unitSelf.getPK = true
			tinsert(behaviorLib.curItemList, 1, "Item_PortalKey")
		end

	end
end


----------------------------------
--      Gravekeeper Standard Item Build
----------------------------------
--[[ list code:
	"# Item" is "get # of these"
	"Item #" is "get this level of the item" --]]

behaviorLib.StartingItems =
	{"Item_RunesOfTheBlight", "2 Item_MarkOfTheNovice", "2 Item_MinorTotem", "Item_HealthPotion"}
behaviorLib.LaneItems =
	{"Item_Marchers","Item_GraveLocket"}
behaviorLib.MidItems =
	{"Item_EnhancedMarchers", "Item_Silence"}
behaviorLib.LateItems =
	{"Item_Morph", "Item_FrostfieldPlate", "Item_PostHaste", "Item_Freeze", "Item_Damage9"}




--[[
Shopping Override:
At start of shopping check for alternate items
Usual Shopping
After finished check for new Items
--]]

core.bCheckForAlternateItems = true
local function funcShopExecuteOverride(botBrain)
	--check item choices
	if core.bCheckForAlternateItems then
		--BotEcho("Checking Alternate Builds")
		funcCheckforAlternateItemBuild(botBrain)
	end

	local oldShopping = object.ShopExecuteOld (botBrain)

	--update item links and reset the check
	if behaviorLib.finishedBuying then
		core.FindItems()
		core.bCheckForAlternateItems = true
		--BotEcho("FindItems")
	end

	return oldShopping
end
object.ShopExecuteOld = behaviorLib.ShopExecute
behaviorLib.ShopBehavior["Execute"] = funcShopExecuteOverride


--####################################################################
--####################################################################
--#								 									##
--#   CHAT FUNCTIONSS					       						##
--#																	##
--####################################################################
--####################################################################



object.tCustomKillKeys = {
	"schnarchnase_grave_kill1",
	"schnarchnase_grave_kill2",
	"schnarchnase_grave_kill3",
	"schnarchnase_grave_kill4",
	"schnarchnase_grave_kill5",
	"schnarchnase_grave_kill6",
	"schnarchnase_grave_kill7"  }

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
	"schnarchnase_grave_death4",
	"schnarchnase_grave_death5"  }

local function GetDeathKeysOverride(unitSource)
	local tChatKeys = object.funcGetDeathKeysOld(unitSource)
	core.InsertToTable(tChatKeys, object.tCustomDeathKeys)
	return tChatKeys
end
object.funcGetDeathKeysOld = core.GetDeathKeys
core.GetDeathKeys = GetDeathKeysOverride

BotEcho('finished loading schnasegrave_main')