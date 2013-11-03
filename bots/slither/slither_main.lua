-------------------------------------------------------------------
-------------------------------------------------------------------
--  _____ __    _____ _____ _____ _____ _____ _____ _____ _____  --
-- |   __|  |  |     |_   _|  |  |   __| __  | __  |     |_   _| --
-- |__   |  |__|-   -| | | |     |   __|    -| __ -|  |  | | |   --
-- |_____|_____|_____| |_| |__|__|_____|__|__|_____|_____| |_|   --
--                                                               --
-------------------------------------------------------------------
-------------------------------------------------------------------
-- SlitherBot 0.7
-- Basic SlitherBot mainly for my personal use of learning 
-- uses code from many sources including
-- Scorcherbot Glaciusbot Rhapsodybot and probably more
-- TODO: UPDATE WITH PROPER CREDITS

--####################################################################
--####################################################################
--#                                                                 ##
--#                       Bot Initiation                            ##
--#                                                                 ##
--####################################################################
--####################################################################

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


BotEcho(object:GetName()..' loading <hero>_main...')




--####################################################################
--####################################################################
--#                                                                 ##
--#                  bot constant definitions                       ##
--#                                                                 ##
--####################################################################
--####################################################################

-- hero_<hero>  to reference the internal hon name of a hero, Hero_Yogi ==wildsoul
object.heroName = 'Hero_Ebulus'


--   item buy order. internal names
----------------------------------
--	Slither items
----------------------------------
--[[ list code:
	"# Item" is "get # of these"
	"Item #" is "get this level of the item" --]]
behaviorLib.StartingItems = 
	{"Item_DuckBoots", "Item_DuckBoots", "Item_MinorTotem", "Item_MinorTotem", "Item_RunesOfTheBlight", "Item_RunesOfTheBlight"} --"Item_ManaPotion" wont use manapotion yet
behaviorLib.LaneItems = 
	{"Item_Marchers", "Item_Striders", "Item_ManaRegen3", "Item_IronShield", "Item_MajorTotem", "Item_NomesWisdom"} --ManaRegen3 is Ring of the Teacher
behaviorLib.MidItems = 
	{"Item_Regen", "Item_Steamstaff", "Item_Confluence", "Item_Protect"} --Protect is nullstone
behaviorLib.LateItems = 
	{"Item_Evasion", "Item_Intelligence7"} --Int7 is staff of master


-- skillbuild table, 0=q, 1=w, 2=e, 3=r, 4=attri
object.tSkills = {
    1, 0, 0, 2, 0,
    3, 0, 1, 2, 1, 
    3, 2, 2, 2, 4,
    3, 4, 4, 4, 4,
    4, 4, 4, 4, 4,
}

-- These are bonus agression points if a skill/item is available for use
object.nQUp = 20
object.nEUp = 12 
object.nRUp = 35
-- These are bonus agression points that are applied to the bot upon successfully using a skill/item
object.nQUse = 40
object.nEUse = 10
object.nRUse = 65
--These are thresholds of aggression the bot must reach to use these abilities
object.nQThreshold = 20
object.nEThreshold = 10
object.nRThreshold = 60


--####################################################################
--####################################################################
--#                                                                 ##
--#   bot function overrides                                        ##
--#                                                                 ##
--####################################################################
--####################################################################

------------------------------
--     skills               --
------------------------------
-- @param: none
-- @return: none
function object:SkillBuild()
    core.VerboseLog("skillbuild()")

-- takes care at load/reload, <name_#> to be replaced by some convinient name.
    local unitSelf = self.core.unitSelf
    if  skills.abilQ == nil then
        skills.abilQ = unitSelf:GetAbility(0)
        skills.abilW = unitSelf:GetAbility(1)
        skills.abilE = unitSelf:GetAbility(2)
        skills.abilR = unitSelf:GetAbility(3)
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

------------------------------------------------------
--            onthink override                      --
-- Called every bot tick, custom onthink code here  --
------------------------------------------------------
-- @param: tGameVariables
-- @return: none
function object:onthinkOverride(tGameVariables)
    self:onthinkOld(tGameVariables)

    -- custom code here
end
object.onthinkOld = object.onthink
object.onthink 	= object.onthinkOverride




----------------------------------------------
-- OncombatEvent Override --
-- Use to check for Infilictors (fe. Buffs) --
----------------------------------------------
-- @param: EventData
-- @return: none 
function object:oncombateventOverride(EventData)
self:oncombateventOld(EventData)
local nAddBonus = 0
if EventData.Type == "Ability" then
if EventData.InflictorName == "Ability_Ebulus1" then
nAddBonus = nAddBonus + object.nQUse
elseif EventData.InflictorName == "Ability_Ebulus3" then
nAddBonus = nAddBonus + object.nEUse
elseif EventData.InflictorName == "Ability_Ebulus4" then
nAddBonus = nAddBonus + object.nRUse
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




------------------------------------------------------
--            CustomHarassUtility Override          --
-- Change Utility according to usable spells here   --
------------------------------------------------------
-- @param: IunitEntity hero
-- @return: number
local function CustomHarassUtilityFnOverride(hero)
    local nUtil = 0
    
    if skills.abilQ:CanActivate() then
        nUtil = nUtil + object.nQUp
    end

    if skills.abilE:CanActivate() then
        nUtil = nUtil + object.nEUp
    end

    if skills.abilR:CanActivate() then
        nUtil = nUtil + object.nRUp
    end

    return nUtil
end
-- assisgn custom Harrass function to the behaviourLib object
behaviorLib.CustomHarassUtilityFn = CustomHarassUtilityFnOverride   



--------------------------------------------------------------
--                    Harass Behavior                       --
-- All code how to use abilities against enemies goes here  --
--------------------------------------------------------------
-- @param botBrain: CBotBrain
-- @return: none
--
function object.GetBurstRadius()
	return 800
end

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
    
-- Poison Spray
if not bActionTaken then
   local abilSpray = skills.abilQ
   if abilSpray:CanActivate() and nLastHarassUtility > botBrain.nQThreshold then
      local nRange = abilSpray:GetRange()
      if nTargetDistanceSq < (nRange * nRange) then
         bActionTaken = core.OrderAbilityPosition(botBrain, abilSpray, vecTargetPosition)
      else
         bActionTaken = core.OrderMoveToUnitClamp(botBrain, unitSelf, unitTarget)
      end
   end
end
    
-- Toxin Ward
if not bActionTaken then
   local abilWard = skills.abilE
   if abilWard:CanActivate() and nLastHarassUtility > botBrain.nEThreshold then
      local nRange = abilWard:GetRange()
      if nTargetDistanceSq < (nRange * nRange) then
         bActionTaken = core.OrderAbilityPosition(botBrain, abilWard, vecTargetPosition)
      else
         bActionTaken = core.OrderMoveToUnitClamp(botBrain, unitSelf, unitTarget)
      end
   end
end

--ult

if not bActionTaken then
		local abilBurst = skills.abilR --honestly seems to work better without threshold check
		if abilBurst:CanActivate() then
			--get the target well within the radius
			local nRadius = botBrain.GetBurstRadius()
			local nHalfRadiusSq = nRadius * nRadius * 0.25
			if nTargetDistanceSq <= nHalfRadiusSq and unitTarget:GetHealthPercent() > .2 then --TEST: potential fix to ulti already dead heroes
				bActionTaken = core.OrderAbility(botBrain, abilBurst)
			elseif not unitSelf:IsAttackReady() then
				--move in when we aren't attacking
				core.OrderMoveToUnit(botBrain, unitSelf, unitTarget)
				bActionTaken = true
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
--              	  PushExecute Override     		        --
--    make slither use toxin wards when pushing             --
--    using code from RhapsodyBot by fane_maciuca			--
--------------------------------------------------------------
------------ Function for finding the center of a group 
------------ Kudos to Stolen_id for this
	local function groupCenter(tGroup, nMinCount)
		if nMinCount == nil then nMinCount = 1 end
		 
		if tGroup ~= nil then
			local vGroupCenter = Vector3.Create()
			local nGroupCount = 0
			for id, creep in pairs(tGroup) do
				vGroupCenter = vGroupCenter + creep:GetPosition()
				nGroupCount = nGroupCount + 1
			end
			 
			if nGroupCount < nMinCount then
				return nil
			else
				return vGroupCenter/nGroupCount-- center vector
			end
		else
			return nil   
		end
	end
	
local function funcPushBehaviorExecuteOverride(botBrain)
	local bDebugEchos = true
	local unitSelf = core.unitSelf
    local vecMyPosition = unitSelf:GetPosition()	
	local nLastPushUtil = behaviorLib:PushUtility()
	local bActionTaken = false
	
	if nLastPushUtil ~= nil then
	
	if not bActionTaken then
		local abilWard = skills.abilE
		local vCreepCenter = groupCenter(core.localUnits["EnemyCreeps"], 2) -- the 2 basicly wont allow abilities under 2 creeps
        if abilWard:CanActivate() and vCreepCenter then 	--spam regardless of mana for now
              bActionTaken = core.OrderAbilityPosition(botBrain, abilWard, vCreepCenter)
      end
   end
   
   	if not bActionTaken then
		local abilWard = skills.abilE
		local tEnemyBuildings = core.localUnits.EnemyBuildings
		for key, building in pairs(tEnemyBuildings) do
			local vecTowerPos = building:GetPosition()
			if botBrain:CanSeeUnit(building) then --If near enemy tower/building drop a ward
					bActionTaken = core.OrderAbilityPosition(botBrain, abilWard, vecTowerPos)
      end
   end
   end
   
   end
	if not bActionTaken then
		return object.PushBehaviorExecuteOld(botBrain)
	end
end
object.PushBehaviorExecuteOld = behaviorLib.PushExecute
behaviorLib.PushBehavior["Execute"] = funcPushBehaviorExecuteOverride

--------------------------------------------------------------
--                RetreatFromThreat Override     	        --
--  		     --Use spray defensively--			    	--
--------------------------------------------------------------
function funcRetreatFromThreatExecuteOverride(botBrain)
	local bDebugEchos = true
	local bActionTaken = false
	local unitSelf = core.unitSelf
	local abilSpray = skills.abilQ

	if not bActionTaken then --spray if low health or slowed or immobilized or disarmed
		if abilSpray:CanActivate() and unitSelf:GetHealthPercent() < .4 or unitSelf:GetMoveSpeed() < 290 or unitSelf:IsImmobilized() or unitSelf:IsDisarmed() then
			--if bDebugEchos then BotEcho ("LOW HEALTH! PANIC!") end
				local tTargets = core.localUnits["EnemyHeroes"]
				if tTargets then
					local vecMyPosition = unitSelf:GetPosition() 
					local nRange = abilSpray:GetRange()					
					for key, hero in pairs(tTargets) do
						local heroPos = hero:GetPosition()
						local nTargetDistanceSq = Vector3.Distance2DSq(vecMyPosition, heroPos)
						if nTargetDistanceSq < (nRange * nRange) and abilSpray:CanActivate() then
							core.OrderAbilityPosition(botBrain, abilSpray, heroPos)
							--if bDebugEchos then BotEcho ("SPRAY!!!") end
						end

					end
				end	
		end
	end
--[[if not bActionTaken then
   local abilSpray = skills.abilQ
   if abilSpray:CanActivate() and nLastHarassUtility > botBrain.nQThreshold then
      local nRange = abilSpray:GetRange()
      if nTargetDistanceSq < (nRange * nRange) then
         bActionTaken = core.OrderAbilityPosition(botBrain, abilSpray, vecTargetPosition)
      else
         bActionTaken = core.OrderMoveToUnitClamp(botBrain, unitSelf, unitTarget)
      end
   end
end	]]

	if not bActionTaken then
		return object.RetreatFromThreatExecuteOld(botBrain)
	end
end
object.RetreatFromThreatExecuteOld = behaviorLib.RetreatFromThreatExecute
behaviorLib.RetreatFromThreatBehavior["Execute"] = funcRetreatFromThreatExecuteOverride

--------------------------------------------------
--    SoulReapers's Predictive Last Hitting Helper
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
 
 
    --Get info about the target we are about to attack
    local vecSelfPos = unitSelf:GetPosition()
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
 
 
    return nExpectedCreepDamage + nExpectedTowerDamage
end
 
 
function behaviorLib.GetCreepAttackTarget(botBrain, unitEnemyCreep, unitAllyCreep) --called pretty much constantly
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
             
            -- [Tutorial] Hellbourne *will* deny creeps after **** gets real
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
 
 
function AttackCreepsExecuteOverride(botBrain)
    local unitSelf = core.unitSelf
    local unitCreepTarget = core.unitCreepTarget
 
 
    if unitCreepTarget and core.CanSeeUnit(botBrain, unitCreepTarget) then     
        --Get info about the target we are about to attack
        local vecSelfPos = unitSelf:GetPosition()
        local vecTargetPos = unitCreepTarget:GetPosition()
        local nDistSq = Vector3.Distance2DSq(vecSelfPos, vecTargetPos)
        local nAttackRangeSq = core.GetAbsoluteAttackRangeToUnit(unitSelf, currentTarget, true)       
        local nTargetHealth = unitCreepTarget:GetHealth()
        local nDamageMin = unitSelf:GetFinalAttackDamageMin()
     
        --Only attack if, by the time our attack reaches the target
        -- the damage done by other sources brings the target's health
        -- below our minimum damage, and we are in range and can attack right now
        if nDistSq < nAttackRangeSq and unitSelf:IsAttackReady() and nDamageMin >= (nTargetHealth - GetAttackDamageOnCreep(botBrain, unitCreepTarget)) then
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