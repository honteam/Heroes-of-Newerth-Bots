----------------------------------------------------------------------------
----------------------------------------------------------------------------
--  (                                                                  -----
--  )\ )                                                (          )   -----
--  (()/((    (          )      )             (  (     ( )\      ( /(  -----
--   /(_))\ ) )(   (    (    ( /(  (     (   ))\ )(    )((_)  (  )\()) -----
--  (_))(()/((()\  )\   )\  ')(_)) )\ )  )\ /((_|()\  ((_)_   )\(_))/  -----
--  | _ \)(_))((_)((_)_((_))((_)_ _(_/( ((_|_))  ((_)  | _ ) ((_) |_   -----
--  |  _/ || | '_/ _ \ '  \() _` | ' \)) _|/ -_)| '_|  | _ \/ _ \  _|  -----
--  |_|  \_, |_| \___/_|_|_|\__,_|_||_|\__|\___||_|    |___/\___/\__|  -----
--       |__/                                                          -----
----------------------------------------------------------------------------
----------------------------------------------------------------------------
--Pyromancer bot v1.1
--By CuvelClark

--Changelog
--v1.1:
--Increased Dragonfire threshold slightly
--Replaced FindItems function with core.GetItem calls.
--Removed superflous attribute bonus reference.

------------------------------------------
--  		Bot Initialization  		--
------------------------------------------ 

local _G = getfenv(0)
local object = _G.object

object.myName = object:GetName()

object.bRunLogic         = true
object.bRunBehaviors    = true
object.bUpdates         = true
object.bUseShop         = true

object.bRunCommands     = true 
object.bMoveCommands     = true
object.bAttackCommands     = true
object.bAbilityCommands = true
object.bOtherCommands     = true

object.bReportBehavior = false
object.bDebugUtility = false

object.logger = {}
object.logger.bWriteLog = false
object.logger.bVerboseLog = false

object.core         = {}
object.eventsLib     = {}
object.metadata     = {}
object.behaviorLib     = {}
object.skills         = {}

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


BotEcho(object:GetName()..' loading pyromancer_main...')


--####################################################################
--####################################################################
--#                                                                 ##
--#                  bot constant definitions                       ##
--#                                                                 ##
--####################################################################
--####################################################################

object.heroName = 'Hero_Pyromancer'

--------------------------------
-- Lanes
--------------------------------

core.tLanePreferences = {Jungle = 0, Mid = 5, ShortSolo = 4, LongSolo = 3, ShortSupport = 3, LongSupport = 3, ShortCarry = 3, LongCarry = 2}

--   item buy order. internal names  
behaviorLib.StartingItems  = {"Item_RunesOfTheBlight", "Item_ManaBattery", "Item_MarkOfTheNovice", "2 Item_MinorTotem"}
behaviorLib.LaneItems  = {"Item_Marchers", "Item_PowerSupply", "Item_ApprenticesRobe", "Item_Steamboots", "Item_Scarab"}
behaviorLib.MidItems  = {"Item_Weapon1", "Item_PortalKey", "Item_Weapon1"}
behaviorLib.LateItems  = {"Item_Silence", "Item_Beastheart", "Item_AxeOfTheMalphai", "Item_BehemothsHeart", "Item_Confluence", "Item_Morph"}


-- skillbuild table, 0=q, 1=w, 2=e, 3=r, 4=attri
object.tSkills = {
    1, 0, 0, 1, 0,
    3, 0, 1, 1, 2, 
    3, 2, 2, 2, 4,
    3, 4, 4, 4, 4,
    4, 4, 4, 4, 4,
}

-- Blazing Strike damage table
object.tBlazingDmg = {
	0, 450, 675, 950,
}

-- Phoenix Wave damage table
object.tPhoenixDmg = {
	0, 100, 170, 240, 310,
}

-- Blazing Strike damage table
object.tDragonDmg = {
	0, 100, 160, 220, 280,
}

-- Fervor AS table
object.tFervorAttackSpeed = {
	0, .2, .3, .4, .5,
}

-- Fervor CS table 
object.tFervorCastSpeed = {
	0, .1, .2, .3, .4
}

object.nPhoenixSpeed = 1200
object.nDragonDelay = 500

-- utility agression points if a skill/item is available for use
object.nPhoenixUp = 15
object.nDragonUp = 17
object.nBlazingUp = 27
object.nSheepUp = 20
object.nHellUp = 12

-- utility agression points that are applied to the bot upon successfully using a skill/item
object.nDragonUse = 24
object.nPhoenixUse = 14
object.nBlazingUse = 26
object.nHellUse = 14
object.nSheepUse = 17

--thresholds of aggression the bot must reach to use these abilities
object.nPhoenixThreshold = 30
object.nDragonThreshold = 23
object.nBlazingThreshold = 60
object.nPKThreshold = 27
object.nHellThreshold = 25
object.nSheepThreshold = 30


--threshold of retreat skill usage
object.nHellRetreatThreshold = 25
object.nSheepRetreatThreshold = 30

-- Additional Modifiers
object.nPushSkillThreshold = 22
object.nFarmingSkillThreshold = 43

--weight overrides
behaviorLib.nCreepPushbackMul = 0.9
behaviorLib.nTargetPositioningMul = 1

--####################################################################
--####################################################################
--#                                                                 ##
--#   bot function overrides                                        ##
--#                                                                 ##
--####################################################################
--####################################################################


local function CustomHarassUtilityOverride(unitTargetEnemyHero) 
	local utility = 0
	if skills.Phoenix:CanActivate() then
		utility = utility + object.nPhoenixUp
	end
	if skills.Dragon:CanActivate() then
		utility = utility + object.nDragonUp
	end
	if skills.Blazing:CanActivate() then
		utility = utility + object.nBlazingUp
	end
	itemHell = core.GetItem("Item_Silence")
	if itemHell and itemHell:CanActivate() then
		utility = utility + object.nHellUp
	end
	itemSheep = core.GetItem("Item_Morph")
	if itemSheep and itemSheep:CanActivate() then
		utility = utility + object.nSheepUp
	end
	
	return utility
end
-- assisgn custom Harrass function to the behaviourLib object
behaviorLib.CustomHarassUtility = CustomHarassUtilityOverride  

------------------------------
--     skills               --
------------------------------
-- @param: none
-- @return: none
function object:SkillBuild()
    core.VerboseLog("skillbuild()")

    local unitSelf = self.core.unitSelf
    if  skills.Phoenix == nil then
        skills.Phoenix = unitSelf:GetAbility(0)
        skills.Dragon = unitSelf:GetAbility(1)
        skills.Fervor = unitSelf:GetAbility(2)
        skills.Blazing = unitSelf:GetAbility(3)
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

----------------------------------------------
--            oncombatevent override        --
-- use to check for infilictors (fe. buffs) --
----------------------------------------------
-- @param: eventdata
-- @return: none
function object:oncombateventOverride(EventData)
	self:oncombateventOld(EventData)
	
	local utility = 0
	
	if EventData.Type == "Ability" then
		if EventData.InflictorName == "Ability_Pyromancer1" then
			utility = utility + object.nPhoenixUse
		end
		if EventData.InflictorName == "Ability_Pyromancer2" then
			utility = utility + object.nDragonUse
		end
		if EventData.InflictorName == "Ability_Pyromancer4" then
			utility = utility + object.nBlazingUse
		end
		itemSheep = core.GetItem("Item_Morph")
	elseif EventData.Type == "Item" then
		if itemSheep ~= nil  and EventData.SourceUnit == core.unitSelf:GetUniqueID() and EventData.InflictorName == itemSheep:GetName() then
			utility = utility + object.nSheepUse
		end
		itemHell = core.GetItem("Item_Silence")
		if itemHell ~= nil  and EventData.SourceUnit == core.unitSelf:GetUniqueID() and EventData.InflictorName == itemHell:GetName() then
			utility = utility + object.nHellUse
		end
	end
	
	if utility > 0 then
		core.DecayBonus(self)
		core.nHarassBonus = core.nHarassBonus + utility
	end
end
-- override combat event trigger function.
object.oncombateventOld = object.oncombatevent
object.oncombatevent     = object.oncombateventOverride

function ProxToEnemyTowerUtilityOverride(unit, unitClosestEnemyTower)
	local bDebugEchos = false
	
	local nUtility = 0

	if unitClosestEnemyTower then
		local nDist = Vector3.Distance2D(unitClosestEnemyTower:GetPosition(), unit:GetPosition())
		local nTowerRange = core.GetAbsoluteAttackRangeToUnit(unitClosestEnemyTower, unit)
		local nBuffers = unit:GetBoundsRadius() + unitClosestEnemyTower:GetBoundsRadius()

		nUtility = -1 * core.ExpDecay((nDist - nBuffers), 100, nTowerRange, 2)
		
		--This has been greatly increased since Pyro is a bad hero for fighting near towers.
		nUtility = nUtility * 0.56
	end
	
	nUtility = Clamp(nUtility, -100, 0)

	return nUtility
end
behaviorLib.ProxToEnemyTowerUtility = ProxToEnemyTowerUtilityOverride

--Handles Mana Battery and Power Supply usage
local function UseBatterySupplyUtilityOverride(botBrain)
	local itemBatterySupply = behaviorLib.GetBatterySupplyFromInventory()
	if not itemBatterySupply then
		return 0
	end
	if itemBatterySupply:CanActivate() then
		local nUtility = 0
		local unitSelf = core.unitSelf
		local nHealth = unitSelf:GetHealth()
		local nMana = unitSelf:GetMana()
		local nMaxHealth = unitSelf:GetMaxHealth()
		local nMaxMana = unitSelf:GetMaxMana()
		local nHealthPerCharge = 10
		local nManaPerCharge = 15
		local nCharges = itemBatterySupply:GetCharges()
		local nMaxCharges = itemBatterySupply:GetMaxCharges()
		local nHealthHeal = nHealthPerCharge * nCharges
		local nManaHeal = nManaPerCharge * nCharges
		--Use if we have max charges and it won't waste potential healing
		if nCharges == nMaxCharges and nHealth + nHealthHeal <= nMaxHealth and nMana + nManaHeal <= nMaxMana then
			nUtility = nUtility + 500
		--Use if health or mana is critical
		else
			nUtility = nUtility + (1 - unitSelf:GetHealthPercent()) * 60 + (1 - unitSelf:GetManaPercent()) * 40
		end
		return nUtility
	end
	return 0
end
behaviorLib.tItemBehaviors["Item_ManaBattery"]["Utility"] = UseBatterySupplyUtilityOverride

----------------------------------------------
--            Misc      					--
----------------------------------------------
--Used for skill prediction
local function PredictPosition(unitTarget, nSkillDelay)
	local vecStoredPosition = unitTarget.storedPosition
	local vecLastStoredPosition = unitTarget.lastStoredPosition 
	if unitTarget.bIsMemoryUnit and vecStoredPosition and vecLastStoredPosition then
		local unitTarget = behaviorLib.heroTarget
		local nTargetSpeed = unitTarget:GetMoveSpeed()
		--Don't predict for stationary targets
		if unitTarget:IsStunned() or unitTarget:IsImmobilized() then
			return unitTarget:GetPosition()
		else
			local vecDirection = Vector3.Normalize(vecStoredPosition - vecLastStoredPosition)
			--Prediction vector is reduced by 40% since perfect prediction frequently overshoots
			return unitTarget:GetPosition() + (vecDirection * nTargetSpeed * nSkillDelay / 1000) * .6
		end
	--No stored information, unable to predict
	else 
		return unitTarget:GetPosition()
	end
end

local function DragonfirePrediction(unitTarget)
	local nSkillDelay = skills.Dragon:GetCastActionTime() + object.nDragonDelay * (1 - object.tFervorCastSpeed[skills.Fervor:GetLevel() + 1])
	return PredictPosition(unitTarget, nSkillDelay)
end

local function PhoenixWavePrediction(unitTarget)
	local nTravelTime = Vector3.Distance2D(core.unitSelf:GetPosition(), unitTarget:GetPosition()) / object.nPhoenixSpeed
	local nSkillDelay = skills.Phoenix:GetCastTime() * (1 - object.tFervorCastSpeed[skills.Fervor:GetLevel() + 1]) + nTravelTime
	return PredictPosition(unitTarget, nSkillDelay)
end

--Used for deciding when to expend mana on creeps
local function GetManaSustain()
		local unitSelf = core.unitSelf
		local nManaSustain = unitSelf:GetMana() + unitSelf:GetManaRegen() * 30
		if core.itemRoS then
			nManaSustain = nManaSustain + 90
		end
		--Blazing Strike is not ready, this means less kill potential and more room for creep killing
		if skills.Blazing:GetLevel() > 0 and not skills.Blazing:CanActivate() then
			nManaSustain = nManaSustain * 1.5
		end
		return nManaSustain / 100
end

--Calculate potential combo damage including auto attacks
local function CalculateCombo(unitTarget)
		local unitSelf = core.unitSelf
		local nSelfMana = unitSelf:GetMana()
		
		local bTargetVuln = unitTarget:IsStunned() or unitTarget:IsImmobilized()
		local nTargetMagicResistance = unitTarget:GetMagicResistance()
		local nTargetPhysResistance = unitTarget:GetPhysicalResistance()
		local nTargetHealth = unitTarget:GetHealth()
		
		local nAttackDamage = unitSelf:GetFinalAttackDamageMin() * (1 - nTargetPhysResistance)
		local nAttackSpeed = unitSelf:GetAttackSpeed()
		
		local abilDragon = skills.Dragon
		local abilPhoenix = skills.Phoenix
		local abilBlazing = skills.Blazing
		
		local nPhoenixDamage = object.tPhoenixDmg[abilPhoenix:GetLevel() + 1]  * (1 - nTargetMagicResistance)
		local nDragonDamage = object.tDragonDmg[abilDragon:GetLevel() + 1]  * (1 - nTargetMagicResistance)
		local nBlazingDamage = object.tBlazingDmg[abilBlazing:GetLevel() + 1]  * (1 - nTargetMagicResistance)
		
		local nComboDamage = 0
		local nComboCost = 0
		local nComboCount = 0
		
		if abilDragon:CanActivate() and nSelfMana >= abilDragon:GetManaCost() + nComboCost then
			nComboDamage = nComboDamage + nDragonDamage
			nComboCost = nComboCost + abilDragon:GetManaCost()
			nComboCount = nComboCount + 1
		end
		if abilPhoenix:CanActivate() and nSelfMana >= abilPhoenix:GetManaCost() + nComboCost then
			nComboDamage = nComboDamage + nPhoenixDamage
			nComboCost = nComboCost + abilPhoenix:GetManaCost()
			nComboCount = nComboCount + 1
		end
		if abilBlazing:CanActivate() and nSelfMana >= abilBlazing:GetManaCost() + nComboCost then
			nComboDamage = nComboDamage + nBlazingDamage
			nComboCost = nComboCost + abilBlazing:GetManaCost()
			nComboCount = nComboCount + 1
		end

		--Check if combo is lethal
		local nFervorAS = object.tFervorAttackSpeed[skills.Fervor:GetLevel() + 1]
		nComboDamage = nComboDamage * (1 - nTargetMagicResistance) + (nComboCount * nFervorAS + nAttackSpeed) * nAttackDamage * 3
		local bComboIsLethal = nComboDamage >= nTargetHealth
		
		return bComboIsLethal, nComboCount
end

--Returns the closest hero target
local function GetRetreatHeroTarget()
	local vecMyPosition = core.unitSelf:GetPosition()
	local tLocalEnemies = core.localUnits["EnemyHeroes"]
	local nShortestDist = -1
	local unitClosestEnemy = nil
	for nID, unitEnemy in pairs(tLocalEnemies) do
		local nDist = Vector3.Distance2DSq(vecMyPosition, unitEnemy:GetPosition())
		if nDist < nShortestDist or nShortestDist == -1 then
			nShortestDist = nDist
			unitClosestEnemy = unitEnemy
		end
	end
	return unitClosestEnemy
end

--------------------------------------------------------------
--                    Farming Behavior                      --
--------------------------------------------------------------
-- @param botBrain: CBotBrain
-- @return: none
--
local function AttackCreepExecuteOverride(botBrain)
	local unitTarget = core.unitEnemyCreepTarget
	local bActionTaken = false
	
	if unitTarget then
		local vecTargetPosition = unitTarget:GetPosition()
		local abilDragon = skills.Dragon
		local abilPhoenix = skills.Phoenix
		local nPhoenixDamage = object.tPhoenixDmg[abilPhoenix:GetLevel() + 1]
		local nDragonDamage = object.tDragonDmg[abilDragon:GetLevel() + 1]
		local nPhoenixCost = abilPhoenix:GetManaCost()
		local nDragonCost = abilDragon:GetManaCost()
		local tEnemyCreeps = core.localUnits["EnemyCreeps"]
		local nNumberEnemyCreeps = core.NumberElements(tEnemyCreeps)
		local nPhoenixPotentialKills = 0
		local nDragonPotentialKills = 0
		local avgCreepHP = 0
		for _, unit in pairs(tEnemyCreeps) do
			if not unit:IsInvulnerable() and not unit:IsHero() and unit:GetOwnerPlayerID() ~= nil then
				local unitHealth = unit:GetHealth()
				avgCreepHP = avgCreepHP + unitHealth
				if unitHealth <= nPhoenixDamage then
					nPhoenixPotentialKills = nPhoenixPotentialKills + 1
				end
				if unitHealth <= nDragonDamage then
					nDragonPotentialKills = nDragonPotentialKills + 1
				end
			end
		end
		avgCreepHP = avgCreepHP / nNumberEnemyCreeps
		if nNumberEnemyCreeps > object.nFarmingSkillThreshold / GetManaSustain() then
			local bCanCombo = core.unitSelf:GetMana() > nPhoenixCost + nDragonCost
			--Add Phoenix Wave damage to Dragonfire damage to enable combo farming
			if bCanCombo then
				nDragonDamage = nDragonDamage + nPhoenixDamage
			end
			if not bActionTaken then
				if abilDragon:CanActivate() and nDragonDamage >= avgCreepHP or nDragonPotentialKills > 2 then
					bActionTaken = core.OrderAbilityPosition(botBrain, abilDragon, vecTargetPosition)
				end
			end
			if not bActionTaken then
				if abilPhoenix:CanActivate() and nPhoenixDamage >= avgCreepHP or nPhoenixPotentialKills > 2 then
					bActionTaken = core.OrderAbilityPosition(botBrain, abilPhoenix, vecTargetPosition)
				end
			end
		end
	end
	
    if not bActionTaken then
        return object.attackCreepsExecuteOld(botBrain)
    end 
end
-- overload the behaviour stock function with custom 
object.attackCreepsExecuteOld = behaviorLib.AttackCreepsBehavior["Execute"]
behaviorLib.AttackCreepsBehavior["Execute"] = AttackCreepExecuteOverride

--------------------------------------------------------------
--                    Harass Behavior                       --
-- All code how to use abilities against enemies goes here  --
--------------------------------------------------------------
-- @param botBrain: CBotBrain
-- @return: none
--
local function HarassHeroExecuteOverride(botBrain)
    
    local unitTarget = behaviorLib.heroTarget
    if unitTarget == nil or not unitTarget:IsValid() then
        return false
    end
	
	local bActionTaken = false
    	
    local unitSelf = core.unitSelf
    local vecMyPosition = unitSelf:GetPosition() 
    
    local vecTargetPosition = unitTarget:GetPosition()
    local nTargetDistanceSq = Vector3.Distance2DSq(vecMyPosition, vecTargetPosition)
	
	local nLastHarassUtility = behaviorLib.lastHarassUtil
	local bCanSee = core.CanSeeUnit(botBrain, unitTarget)   
	
	local abilDragon = skills.Dragon
	local abilPhoenix = skills.Phoenix
	local abilBlazing = skills.Blazing
	local nDragonThresholdTmp = object.nDragonThreshold
	
	if bCanSee then
		local bTargetVuln = unitTarget:IsStunned() or unitTarget:IsImmobilized()
		local nTargetPhysResistance = unitTarget:GetPhysicalResistance()
		local nTargetHealth = unitTarget:GetHealth()
		
		local nAttackDamage = unitSelf:GetFinalAttackDamageMin() * (1 - nTargetPhysResistance)
		local nAttackSpeed = unitSelf:GetAttackSpeed()
		
		local nFervorAS = object.tFervorAttackSpeed[skills.Fervor:GetLevel() + 1]
		
		bComboIsLethal, nComboCount = CalculateCombo(unitTarget)
		
		--Dragonfire
		if not bActionTaken and abilDragon:CanActivate() then
			--An already stunned target is more attractive
			if bTargetVuln then
				nDragonThresholdTmp = nDragonThresholdTmp * .5
			end
			local nRange = abilDragon:GetRange()
			if nTargetDistanceSq < (nRange * nRange) then
				if nLastHarassUtility > nDragonThresholdTmp or bComboIsLethal then
					bActionTaken = core.OrderAbilityPosition(botBrain, abilDragon, DragonfirePrediction(unitTarget))
				end
			else --Not in range, try to get closer
				--The long cast time makes diving with the stun very risky
				local nDragonDiveThreshold = 125
				if nLastHarassUtility > (behaviorLib.diveThreshold * nDragonDiveThreshold) then
					bActionTaken = core.OrderMoveToPosClamp(botBrain, unitSelf, vecTargetPosition, false)
				else
					local vecMoveToPos = core.AdjustMovementForTowerLogic(vecTargetPosition, false)
					bActionTaken = core.OrderMoveToPosClamp(botBrain, unitSelf, vecMoveToPos, false)
				end
			end
		end
		
		--Phoenix Wave
		if not bActionTaken and abilPhoenix:CanActivate() then
			local nRange = abilPhoenix:GetRange()
			if nTargetDistanceSq < (nRange * nRange) then
				if nLastHarassUtility > object.nPhoenixThreshold or  bComboIsLethal then
					bActionTaken = core.OrderAbilityPosition(botBrain, abilPhoenix, PhoenixWavePrediction(unitTarget))
				end
			end
		end
		
		--Blazing Strike
		if not bActionTaken and bCanSee and abilBlazing:CanActivate() then
			--Don't waste ult on low health targets that can be finished with other attacks
			if not bTargetVuln and nTargetHealth >= nAttackDamage * nComboCount * (nAttackSpeed + nFervorAS) then
				local nRange = abilBlazing:GetRange()
				if nTargetDistanceSq < (nRange * nRange) then
					if nLastHarassUtility > object.nBlazingThreshold or bComboIsLethal then
						bActionTaken = core.OrderAbilityEntity(botBrain, abilBlazing, unitTarget)
					end
				end
			end
		end
		
		--Hellflower
		if not bActionTaken and not bTargetVuln and not unitTarget:IsPerplexed() then
			local itemHell = core.GetItem("Item_Silence")
			if itemHell and itemHell:CanActivate() and nLastHarassUtility > object.nHellThreshold then
				local nRange = itemHell:GetRange()
				if nTargetDistanceSq < (nRange * nRange) then
					bActionTaken = core.OrderItemEntityClamp(botBrain, unitSelf, itemHell, unitTarget)
				end
			end
		end
		
		--Sheepstick
		if not bActionTaken and not bTargetVuln then
			local itemSheep = core.GetItem("Item_Morph")
			if itemSheep and itemSheep:CanActivate() and nLastHarassUtility > object.nSheepThreshold then
				local nRange = itemSheep:GetRange()
				if nTargetDistanceSq < (nRange * nRange) then
					bActionTaken = core.OrderItemEntityClamp(botBrain, unitSelf, itemSheep, unitTarget)
				end
			end
		end
	end
	
	--Portal Key
	if not bActionTaken and core.itemPK and core.itemPK:CanActivate() then
		local itemPK = core.GetItem("Item_PortalKey")
		if itemPK then
			local nPKMinRange = 250
			--Adding min range to compensate for offsetting target position
			local nPKRange = itemPK:GetRange() + nPKMinRange
			local nDragonRange = abilDragon:GetRange()
			--Reducing stun range slighly for more aggressive PK usage
			local nDragonRangeSq = nDragonRange * nDragonRange * .8
			if nLastHarassUtility > object.nPKThreshold or bComboIsLethal then
				if nTargetDistanceSq > nDragonRangeSq and nTargetDistanceSq < (nPKRange * nPKRange + nDragonRangeSq) then
					--Don't blink right on top of targets
					local vecPKPosition = vecTargetPosition - Vector3.Normalize(vecTargetPosition - vecMyPosition) * nPKMinRange
					bActionTaken = core.OrderItemPosition(botBrain, unitSelf, itemPK, vecPKPosition)
				end
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

----------------------------------------
--  	Push Behaviour   	  --
----------------------------------------
local function PushExecuteFnOverride(botBrain)

	if core.unitSelf:IsChanneling() then
		return
	end

	local bActionTaken = false

	local unitSelf = core.unitSelf
	local abilDragon = skills.Dragon
	local abilPhoenix = skills.Phoenix
	local unitTarget = core.unitEnemyCreepTarget
	local nNumberEnemyCreeps = core.NumberElements(core.localUnits["EnemyCreeps"])
	
	if unitTarget then
		local vecTargetPosition = unitTarget:GetPosition()
		local nManaSustain = GetManaSustain()
		if nNumberEnemyCreeps > (object.nPushSkillThreshold / nManaSustain) then
			if not bActionTaken and abilPhoenix:CanActivate() then
				bActionTaken = core.OrderAbilityPosition(botBrain, abilPhoenix, vecTargetPosition)
			end
			--Low level stun is not worth using for pushing
			if not bActionTaken and abilDragon:CanActivate() and abilDragon:GetLevel() > 1 then
				bActionTaken = core.OrderAbilityPosition(botBrain, abilDragon, vecTargetPosition)
			end
		end
	end
	
	if not bActionTaken then
		object.PushExecuteOld(botBrain)
	end
end
object.PushExecuteOld = behaviorLib.PushExecute
behaviorLib.PushBehavior["Execute"] = PushExecuteFnOverride

----------------------------------------
--  	Retreat Behaviour   	  	  --
----------------------------------------
function behaviorLib.CustomRetreatExecute(botBrain)
	bActionTaken = false

	local unitSelf = core.unitSelf
	local unitTarget = GetRetreatHeroTarget()
	local bCanSee = unitTarget and core.CanSeeUnit(botBrain, unitTarget)
	local nLastRetreatUtil = behaviorLib.lastRetreatUtil

	--Portal Key away
	local itemPK = core.GetItem("Item_PortalKey")
	if not bActionTaken then
		if itemPK and itemPK:CanActivate() then
			local vecTarget = behaviorLib.GetSafeBlinkPosition(core.allyWell:GetPosition(), itemPK:GetRange())
			bActionTaken = core.OrderItemPosition(botBrain, unitSelf, itemPK, vecTarget)
		end
	end

	if bCanSee then
		local nTargetDistanceSq = Vector3.Distance2DSq(unitSelf:GetPosition(), unitTarget:GetPosition())
		
		local abilDragon = skills.Dragon
		local abilPhoenix = skills.Phoenix
		local abilBlazing = skills.Blazing
		
		local bTargetVuln = unitTarget:IsStunned() or unitTarget:IsImmobilized()
		
		bComboIsLethal, nComboCount = CalculateCombo(unitTarget)
		
		--Use Dragonfire
		if not bActionTaken and abilDragon:CanActivate() then
			local nRange = abilDragon:GetRange()
			if nTargetDistanceSq <= (nRange * nRange) then
				bActionTaken = core.OrderAbilityPosition(botBrain, abilDragon, DragonfirePrediction(unitTarget))
			end
		end
		
		--Phoenix Wave - Used only when a kill is guaranteed
		if not bActionTaken and abilPhoenix:CanActivate() then
			if bComboIsLethal then
				local nRange = abilPhoenix:GetRange()
				if nTargetDistanceSq < (nRange * nRange) then
					bActionTaken = core.OrderAbilityPosition(botBrain, abilDragon, PhoenixWavePrediction(unitTarget))
				end
			end
		end
		
		--Blazing Strike - Used only when a kill is guaranteed
		if not bActionTaken and abilBlazing:CanActivate() then
			if bComboIsLethal then
				local nRange = abilBlazing:GetRange()
				if nTargetDistanceSq < (nRange * nRange) then
					bActionTaken = core.OrderAbilityEntity(botBrain, abilBlazing, unitTarget)
				end
			end
		end
		
		--Use Hellflower
		if not bActionTaken and not unitTarget:IsPerplexed() then
			local itemHell = core.GetItem("Item_Silence")
			if itemHell and itemHell:CanActivate() and nLastRetreatUtil >= object.nHellRetreatThreshold then
				local nRange = itemHell:GetRange()
				if nTargetDistanceSq <= (nRange * nRange) then
					bActionTaken = core.OrderItemEntityClamp(botBrain, unitSelf, itemHell, unitTarget)
				end
			end
		end
		
		--Sheepstick
		if not bActionTaken and not bTargetVuln then
			local itemSheep = core.GetItem("Item_Morph")
			if itemSheep and itemSheep:CanActivate() and nLastHarassUtility > object.nSheepRetreatThreshold then
				local nRange = itemSheep:GetRange()
				if nTargetDistanceSq < (nRange * nRange) then
					bActionTaken = core.OrderItemEntityClamp(botBrain, unitSelf, itemSheep, unitTarget)
				end
			end
		end
	end
	
	return bActionTaken
end

------------------------------------------------------------------
--Heal at well execute
------------------------------------------------------------------
function behaviorLib.CustomReturnToWellExecute(botBrain)
	return core.OrderBlinkItemToEscape(botBrain, core.unitSelf, core.itemPK, true)
end
----------------------------------------
--  	Healing well utiliy      	  --
----------------------------------------
local function CustomHealAtWellUtilityFnOverride(botBrain)
	local nUtility = 0
	local nGold = botBrain:GetGold()
	local nLevel = core.unitSelf:GetLevel()
	
	--Gold buildup increases wish to go home
	nUtility = nUtility + nGold / (5 + nLevel * 20)

	return nUtility + object.HealAtWellUtilityOld(botBrain)
end
object.HealAtWellUtilityOld =  behaviorLib.HealAtWellUtility
behaviorLib.HealAtWellBehavior["Utility"] = CustomHealAtWellUtilityFnOverride

BotEcho('finished loading blazter_main')