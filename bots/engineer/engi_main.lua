-- EngiBot v 1.0

-- By community member V1P3R`

-- This Bot has been designed to be an aggressive early game harasser, and transition
-- into a powerful team presence bot.
--
--
-- How the skills work

-- EngiBot is fairly accurate with his Keg stuns and enjoys pressuring heroes from
-- a very early stage. This allows the laning bot or player to follow up with another
-- stun or ability in order to finish the enemy.
-- When retreating, EngiBot will toss a Keg to halt the enemies chasing.

-- Along with Keg stuns, EngiBot will attempt to place the turret.
-- positioned "at the feet" or "next to" the enemy unit.
-- Immediately after, EngiBot will follow up with a Keg Stun.
-- When retreating, EngiBot will deploy a Steam Turret to slow down the opposition.
-- If possible, EngiBot will then move into position, and use his Energy Field in
-- order to maximize damage.

-- Spider Mines are now implemented. When in range, EngiBot will drop a spider mine.
-- Additionally, after landing a Keg stun, EngiBot will attempt to move into range and
-- drop a spider mine resulting in a more efficient combination.
-- When retreating, EngiBot will plant Spider Mines for a nasty surprise
-- on enemies who dare chase him.

-- EngiBot is still a work in progress and I am always looking to implement new
-- features and ideas. Please report any ideas or comments,
-- as well as issues to me via PM or email at nlagueruela@yahoo.com.

-- Upcoming impelementations
-- Continued Turret tinkering to maximize efficiency.
-- Portal Key initiation?
-- Your suggestions!

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
object.bDebugExecute	= false


object.logger = {}
object.logger.bWriteLog = false
object.logger.bVerboseLog = false

object.core			= {}
object.eventsLib	= {}
object.metadata		= {}
object.behaviorLib	= {}
object.skills		= {}

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

BotEcho('loading engineer_main...')

object.heroName = 'Hero_Engineer'

--[[for testing
function object:onthinkOverride(tGameVariables)
	self:onthinkOld(tGameVariables)
	
	core.unitSelf:TeamShare()
end
object.onthinkOld = object.onthink
object.onthink 	= object.onthinkOverride
--]]

object.tSkills = {
	0, 1, 1, 0, 1, -- Keg lvl 2 Turret lvl 3
	3, 1, 0, 0, 4, -- Ultimate lvl 1 Keg lvl 4 Turret lvl 4 Attributes lvl 1
	3, 2, 2, 2, 2, -- Ultimate lvl 2 Spider Mines lvl 4
	3, 4, 4, 4, 4, -- Ultimate lvl 3 Attributes lvl 5
	4, 4, 4, 4, 4, -- Attributes lvl 10
}

--------------------------------
-- Skills
--------------------------------
function object:SkillBuild()
local unitSelf = self.core.unitSelf

	if skills.abilKeg == nil then
		skills.abilKeg		= unitSelf:GetAbility(0)
		skills.abilTurret	= unitSelf:GetAbility(1)
		skills.abilSpiderMine	= unitSelf:GetAbility(2)
		skills.abilEnergyField	= unitSelf:GetAbility(3)
		skills.abilAttributeBoost	= unitSelf:GetAbility(4)
	end

	if unitSelf:GetAbilityPointsAvailable() <= 0 then
		return
	end

	local nLev = unitSelf:GetLevel()
	local nLevPts = unitSelf:GetAbilityPointsAvailable()
	for i = nLev, (nLev + nLevPts) do
		unitSelf:GetAbility( object.tSkills[i] ):LevelUp()
	end
end

-------------------------------------------------
--	EngiBot's specific harass bonuses
--
--  Abilities off cd increase harass util
--  Ability use increases harass util for a time
-------------------------------------------------
-- These are bonus agression points if a skill or item is available for use
object.nKegUpBonus = 15
object.nTurretUpBonus = 18
object.nSpiderMineUpBonus = 10
object.nEnergyFieldUpBonus = 60
object.nSheepstickUp = 12

-- These are bonus agression points that are applied to the bot upon successfully using a skill or item
object.nKegUseBonus = 20
object.nTurretUseBonus = 20
object.nSpiderMineUseBonus = 50
object.nEnergyFieldUseBonus = 60
object.nSheepstickUse = 16

-- These are thresholds of aggression the bot must reach to use these abilities
object.nKegThreshold = 40
object.nTurretThreshold = 40
object.nSpiderMineThreshold = 30
object.nEnergyFieldThreshold = 40
object.nSheepstickThreshold = 30

-- Skill function
local function AbilitiesUpUtilityFn()
	local nUtility = 0

	if skills.abilKeg:CanActivate() then
		nUtility = nUtility + object.nKegUpBonus
	end

	if skills.abilTurret:CanActivate() then
		nUtility = nUtility + object.nTurretUpBonus
	end

	if skills.abilSpiderMine:CanActivate() then
		nUtility = nUtility + object.nSpiderMineUpBonus
	end

	if skills.abilEnergyField:CanActivate() then
		nUtility = nUtility + object.nEnergyFieldUpBonus
	end

	if object.itemSheepstick and object.itemSheepstick:CanActivate() then
		nUtility = nUtility + object.nSheepstickUp
	end

	return nUtility
end

--ability use gives bonus to harass util for a while
function object:oncombateventOverride(EventData)
	self:oncombateventOld(EventData)

	local nAddBonus = 0

	if EventData.Type == "Ability" then
		if EventData.InflictorName == "Ability_Engineer1" then
			nAddBonus = nAddBonus + object.nKegUseBonus
		elseif EventData.InflictorName == "Ability_Engineer2" then
			nAddBonus = nAddBonus + object.nTurretUseBonus
		elseif EventData.InflictorName == "Ability_Engineer3" then
			nAddBonus = nAddBonus + object.nSpiderMineUseBonus
		elseif EventData.InflictorName == "Ability_Engineer4" then
			nAddBonus = nAddBonus + object.nEnergyFieldUseBonus
		end
	elseif EventData.Type == "Item" then
		if core.itemSheepstick ~= nil and EventData.InflictorName == core.itemSheepstick:GetName() and EventData.SourceUnit == core.unitSelf:GetUniqueID() then
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
object.oncombatevent	= object.oncombateventOverride

--Utility calc override
local function CustomHarassUtilityOverride(hero)
	local nUtility = AbilitiesUpUtilityFn()

	return nUtility
end
behaviorLib.CustomHarassUtility = CustomHarassUtilityOverride


----------------------------------
--    EngiBot's harass actions
----------------------------------
function object.GetKegRadius()
	return 200
end

function object.GetTurretRadius()
	return 400
end

function object.GetSpiderMineRadius()
	return 550
end

function object.GetEnergyFieldRadius()
	return 575
end


local function HarassHeroExecuteOverride(botBrain)
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
	local nDistance = Vector3.Distance2D(vecMyPosition, vecTargetPosition)
	local nTargetDistanceSq = Vector3.Distance2DSq(vecMyPosition, vecTargetPosition)

	local bTargetRooted = unitTarget:IsStunned() or unitTarget:IsImmobilized() or unitTarget:GetMoveSpeed() < 200

	local vecTurretPosition = Vector3.Normalize(vecTargetPosition - vecMyPosition)
	local vecTurretTarget = vecMyPosition + vecTurretPosition *(nDistance + 250)
	
	local targetHealthPercentage = unitTarget:GetHealthPercent()

	local nLastHarassUtil = behaviorLib.lastHarassUtil
	local bCanSee = core.CanSeeUnit(botBrain, unitTarget)

	if bDebugEchos then BotEcho("Engineer HarassHero at "..nLastHarassUtil) end
	local bActionTaken = false

	--since we are using an old pointer, be sure to ensure we can still see the target for entity targeting
	
	--Sheepstick usage
	if core.CanSeeUnit(botBrain, unitTarget) and not bActionTaken and not bTargetRooted then
		local itemSheepstick = core.itemSheepstick
		if itemSheepstick then
			local nRange = itemSheepstick:GetRange()
			if itemSheepstick:CanActivate() and nLastHarassUtil > object.nSheepstickThreshold then
				if nTargetDistanceSq < (nRange * nRange) then
					bActionTaken = core.OrderItemEntityClamp(botBrain, unitSelf, itemSheepstick, unitTarget)
				end
			end
		end
	end
	
	--Keg usage
	if not bActionTaken and nLastHarassUtil > botBrain.nKegThreshold then
		if bDebugEchos then BotEcho("  No action yet, checking Keg") end
		local abilKeg = skills.abilKeg
		if abilKeg and abilKeg:CanActivate() then
			local nRadius = botBrain.GetKegRadius()
			local nRange = abilKeg:GetRange()
			local vecTarget = core.AoETargeting(unitSelf, nRange, nRadius, true, unitTarget, core.enemyTeam, nil)

			if vecTarget then
				bActionTaken = core.OrderAbilityPosition(botBrain, abilKeg, vecTarget)
			end
		end
	end
	
	--Turret using Vector targetting.
	if not bActionTaken and nLastHarassUtil > botBrain.nTurretThreshold and bCanSee then
		if bDebugEchos then BotEcho("  No action yet, checking Turret") end
		local abilTurret = skills.abilTurret
		if abilTurret and abilTurret:CanActivate() then
			if targetHealthPercentage <= 0.4 then
				--If enemy is under 40%, use "Smart" targetting (at their position, angled from me to them)
				bActionTaken = botBrain:OrderAbilityVector(skills.abilTurret, vecTargetPosition, vecTargetPosition + vecTargetPosition - vecMyPosition)
				--bActionTaken = botBrain:OrderAbilityVector(skills.abilTurret, vecTargetPosition, vecTargetPosition)
			else
				--Place turret at an angle behind enemy unit to "pull" towards
				bActionTaken = botBrain:OrderAbilityVector(skills.abilTurret, vecTurretTarget, vecTargetPosition)
			end
		end
	end

	-- Energy Field
	if not bActionTaken and nLastHarassUtil > botBrain.nEnergyFieldThreshold then
		if bDebugEchos then BotEcho("  No action yet, checking Energy Field.") end
		local abilEnergyField = skills.abilEnergyField
		if abilEnergyField:CanActivate() then
			--Get the target well within the radius for maximum efficiency
			local nRadius = botBrain.GetEnergyFieldRadius()
			local nHalfRadiusSq = nRadius * nRadius * 0.25
			if nTargetDistanceSq <= nHalfRadiusSq then
				bActionTaken = core.OrderAbility(botBrain, abilEnergyField)
			elseif not unitSelf:IsAttackReady() then
				--If not attacking, move into position
				bActionTaken = core.OrderMoveToUnit(botBrain, unitSelf, unitTarget)
			end
		end
	end

	-- Spider Mine detection similar to Energy Field code.
	if not bActionTaken and nLastHarassUtil > botBrain.nSpiderMineThreshold then
		if bDebugEchos then BotEcho("  No action yet, checking Spider Mine.") end
		local abilSpiderMine = skills.abilSpiderMine
		if abilSpiderMine:CanActivate() then
			--Get the target well within the radius for maximum efficiency
			local nRadius = botBrain.GetSpiderMineRadius()
			local nHalfRadiusSq = nRadius * nRadius * 0.25
			if nTargetDistanceSq <= nHalfRadiusSq then
				bActionTaken = core.OrderAbility(botBrain, abilSpiderMine)
			elseif not unitSelf:IsAttackReady() then
				--If not attacking, move into position
				bActionTaken = core.OrderMoveToUnit(botBrain, unitSelf, unitTarget)
			end
		end
	end
	
	if not bActionTaken then
		if bDebugEchos then BotEcho("No action yet, proceeding with normal harass execute.") end
		return object.harassExecuteOld(botBrain)
	end
end
object.harassExecuteOld = behaviorLib.HarassHeroBehavior["Execute"]
behaviorLib.HarassHeroBehavior["Execute"] = HarassHeroExecuteOverride


----------------------------------
--  FindItems Override
----------------------------------
local function funcFindItemsOverride(botBrain)
	object.FindItemsOld(botBrain)

	core.ValidateItem(core.itemSheepstick)
		
	if core.itemSheepstick then
		return
	end

	local inventory = core.unitSelf:GetInventory(false)
	for slot = 1, 6, 1 do
		local curItem = inventory[slot]
		if curItem then
			if core.itemSheepstick == nil and curItem:GetName() == "Item_Morph" then
				core.itemSheepstick = core.WrapInTable(curItem)
			end
		end
	end
end
object.FindItemsOld = core.FindItems
core.FindItems = funcFindItemsOverride


--------------------------------------------------
--    EngiBot's Predictive Last Hitting
--    First seen in Pradox870's SoulReaper Bot
--    
--    Assumes that you have vision on the creep
--    passed in to the function
--
--    Developed by paradox870
--------------------------------------------------
local function GetAttackDamageOnCreep(botBrain, unitCreepTarget)

	if not unitCreepTarget or not core.CanSeeUnit(botBrain, unitCreepTarget) then
		return nil
	end

	local unitSelf = core.unitSelf

	--Get positioning information
	local vecSelfPos = unitSelf:GetPosition()
	local vecTargetPos = unitCreepTarget:GetPosition() 

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
	end

	--Determine the damage expected on the creep by other creeps
	for i, unitCreep in pairs(tNearbyAttackingCreeps) do
		if unitCreep:GetAttackTarget() == unitCreepTarget then
			local nCreepAttacks = ceil(unitCreep:GetAttackSpeed() * nProjectileTravelTime)
			nExpectedCreepDamage = nExpectedCreepDamage + unitCreep:GetFinalAttackDamageMin() * nCreepAttacks
		end
	end

	--Determine the damage expected on the creep by other towers
	for i, unitTower in pairs(tNearbyAttackingTowers) do
		if unitTower:GetAttackTarget() == unitCreepTarget then
			local nTowerAttacks = ceil(unitTower:GetAttackSpeed() * nProjectileTravelTime)
			nExpectedTowerDamage = nExpectedTowerDamage + unitTower:GetFinalAttackDamageMin() * nTowerAttacks
		end
	end

	return nExpectedCreepDamage + nExpectedTowerDamage
end

function GetCreepAttackTargetOverride(botBrain, unitEnemyCreep, unitAllyCreep) --called pretty much constantly
	local bDebugEchos = false

	--Get info about self
	local unitSelf = core.unitSelf
	local nDamageMin = unitSelf:GetFinalAttackDamageMin()

	if unitEnemyCreep and core.CanSeeUnit(botBrain, unitEnemyCreep) then
		local nTargetHealth = unitEnemyCreep:GetHealth()
		--Only attack if, by the time our attack reaches the target
		-- the damage done by other sources brings the target's health
		-- below our minimum damage
		if nDamageMin >= (nTargetHealth - GetAttackDamageOnCreep(botBrain, unitEnemyCreep)) then
			if bDebugEchos then BotEcho("Returning an enemy") end
			return unitEnemyCreep
		end
	end

	if unitAllyCreep then
		local nTargetHealth = unitAllyCreep:GetHealth()

		--Only attack if, by the time our attack reaches the target
		-- the damage done by other sources brings the target's health
		-- below our minimum damage
		if nDamageMin >= (nTargetHealth - GetAttackDamageOnCreep(botBrain, unitAllyCreep)) then
			local bActuallyDeny = true
			
			--[Difficulty: Easy] Don't deny
			if core.nDifficulty == core.nEASY_DIFFICULTY then
				bActuallyDeny = false
			end         
			
			-- [Tutorial] Hellbourne *will* deny creeps after shit gets real
			if core.bIsTutorial and core.bTutorialBehaviorReset == true and core.myTeam == HoN.GetHellbourneTeam() then
				bActuallyDeny = true
			end
			
			if bActuallyDeny then
				if bDebugEchos then BotEcho("Returning an ally") end
				return unitAllyCreep
			end
		end
	end

	return nil
end

-- overload the behaviour stock function with custom 
object.getCreepAttackTargetOld = behaviorLib.GetCreepAttackTarget
behaviorLib.GetCreepAttackTarget = GetCreepAttackTargetOverride

function AttackCreepsExecuteOverride(botBrain)
	local unitSelf = core.unitSelf
	local unitCreepTarget = core.unitCreepTarget

	if unitCreepTarget and core.CanSeeUnit(botBrain, unitCreepTarget) then      
		--Get info about the target we are about to attack
		local vecSelfPos = unitSelf:GetPosition()
		local vecTargetPos = unitCreepTarget:GetPosition()
		local nDistSq = Vector3.Distance2DSq(vecSelfPos, vecTargetPos)
		local nAttackRangeSq = core.GetAbsoluteAttackRangeToUnit(unitSelf, currentTarget, true)
	
		--Only attack if, by the time our attack reaches the target
		-- the damage done by other sources brings the target's health
		-- below our minimum damage, and we are in range and can attack right now
		if nDistSq < nAttackRangeSq and unitSelf:IsAttackReady() then
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
		return false
	end
end
object.AttackCreepsExecuteOld = behaviorLib.HarassHeroBehavior["Execute"]
behaviorLib.AttackCreepsBehavior["Execute"] = AttackCreepsExecuteOverride

 
----------------------------------
--	EngiBot's Retreating Tactics
--
--	As seen in Spennerino's ScoutBot
--	with variations from Rheged's Emerald Warden Bot
----------------------------------
object.nRetreatKegThreshold = 15
object.nRetreatSpiderMineThreshold = 10
object.nRetreatTurretThreshold = 10

function funcRetreatFromThreatExecuteOverride(botBrain)
	local bDebugEchos = false
	local bActionTaken = false
	local unitSelf = core.unitSelf
	local unitTarget = behaviorLib.heroTarget
	local vecMyPosition = unitSelf:GetPosition()

	local nlastRetreatUtil = behaviorLib.lastRetreatUtil

	local tEnemies = core.localUnits["EnemyHeroes"]
	local bHeroesPresent = false

	for id, unitEnemy in pairs(tEnemies) do
		if core.CanSeeUnit(botBrain, unitEnemy) then
			bHeroesPresent = true
			break
		end
	end


	if unitSelf:GetHealthPercent() < 0.4 and bHeroesPresent then
		--When retreating, will Keg himself to push them back
		--as well as create some distance between enemies
		if not bActionTaken then
			local abilKeg = skills.abilKeg

			if behaviorLib.lastRetreatUtil >= object.nRetreatKegThreshold and abilKeg:CanActivate() then
				if bDebugEchos then BotEcho("Backing...Tossing Keg") end
				bActionTaken = core.OrderAbilityPosition(botBrain, abilKeg, vecMyPosition)
			end
		end

		-- When retreating, will deploy a turret in front of him facing the opposite direction to slow enemies down.
		if not bActionTaken then
			local abilTurret = skills.abilTurret
			if behaviorLib.lastRetreatUtil >= object.nRetreatTurretThreshold and abilTurret:CanActivate() and core.myTeam == HoN.GetHellbourneTeam() then
				if bDebugEchos then BotEcho ("Backing...Depolying Turret") end
				bActionTaken = botBrain:OrderAbilityVector(skills.abilTurret, Vector3.Create(vecMyPosition.x+200, vecMyPosition.y+200), vecMyPosition)
			elseif behaviorLib.lastRetreatUtil >= object.nRetreatTurretThreshold and abilTurret:CanActivate() then
				if bDebugEchos then BotEcho ("Backing...Deploying Turret") end
				bActionTaken = botBrain:OrderAbilityVector(skills.abilTurret, Vector3.Create(vecMyPosition.x-200, vecMyPosition.y-200), vecMyPosition)
			end
		end

		-- When retreating, will plant Spider Mines to cap some kills on enemies chasing.
		if not bActionTaken then
			local abilSpiderMine = skills.abilSpiderMine
			if behaviorLib.lastRetreatUtil >= object.nRetreatSpiderMineThreshold and abilSpiderMine:CanActivate() then
				if bDebugEchos then BotEcho("Backing...Planting Mine") end
				bActionTaken = core.OrderAbility(botBrain, abilSpiderMine)
			end
		end
	end

	if not bActionTaken then
		return object.RetreatFromThreatExecuteOld(botBrain)
	end

end
object.RetreatFromThreatExecuteOld = behaviorLib.RetreatFromThreatExecute
behaviorLib.RetreatFromThreatBehavior["Execute"] = funcRetreatFromThreatExecuteOverride

--------------------
-- Chat Functions
--------------------
object.tCustomKillKeys = {
	"viper_engineer_kill1",
	"viper_engineer_kill2",
	"viper_engineer_kill3",
	"viper_engineer_kill4",
	"viper_engineer_kill5",
	"viper_engineer_kill6" }

local function GetKillKeysOverride(unitTarget)
	local tChatKeys = object.funcGetKillKeysOld(unitTarget)
	core.InsertToTable(tChatKeys, object.tCustomKillKeys)
	return tChatKeys
end
object.funcGetKillKeysOld = core.GetKillKeys
core.GetKillKeys = GetKillKeysOverride


----------------------------------
--	Engineer items
----------------------------------
--[[ list code:
	"# Item" is "get # of these"
	"Item #" is "get this level of the item" --]]
behaviorLib.StartingItems =
	{"Item_PretendersCrown", "Item_MinorTotem", "Item_MinorTotem", "Item_MinorTotem", "Item_RunesOfTheBlight", "Item_RunesOfTheBlight", "Item_MinorTotem"}
behaviorLib.LaneItems =
	{"Item_ManaRegen3", "Item_Marchers", "Item_Striders", "Item_MysticVestments", "Item_Replenish", "Item_Manatube"} --ManaRegen3 is Ring of the Teacher, Replenish is Ring of Sorcery
behaviorLib.MidItems =
	{"Item_Morph", "Item_MagicArmor2"}
behaviorLib.LateItems =
	{"Item_BehemothsHeart", "Item_LightBrand"}

BotEcho('finished loading engineer_main')