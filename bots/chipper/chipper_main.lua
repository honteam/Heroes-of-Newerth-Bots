---ChipperBot aka BusDriverBot v0.1

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

local sqrtTwo = math.sqrt(2)
BotEcho(object:GetName()..' loading <hero>_main...')


-- hero_<hero>  to reference the internal hon name of a hero, Hero_Yogi ==wildsoul
object.heroName = 'Hero_Chipper'


--   item buy order. internal names  
behaviorLib.StartingItems  = {"2 Item_RunesOfTheBlight", "Item_MinorTotem", "Item_MinorTotem", "Item_MarkOfTheNovice", "Item_MarkOfTheNovice"}
behaviorLib.LaneItems  = {"Item_Marchers", "Item_GraveLocket", "Item_EnhancedMarchers"}
behaviorLib.MidItems  = {"Item_Intelligence7", "Item_Silence"}
behaviorLib.LateItems  = {"Item_SpellShards 3", "Item_Morph", "Item_PortalKey"}


-- skillbuild table, 0=q, 1=w, 2=e, 3=r, 4=attri
object.tSkills = {
    0, 1, 0, 1, 0,
    3, 0, 1, 1, 2, 
    3, 2, 2, 2, 4,
    3, 4, 4, 4, 4,
    4, 4, 4, 4, 4,
}

-- bonus agression points if a skill/item is available for use
object.abilQUp = 10
object.abilWUp = 10
object.abilEUp = 8
object.abilRUp = 40
object.nImmunityUp = 18
object.nIllusionUp = 20
object.nEnergizerUp = 10
object.nSilenceUp = 15
-- bonus agression points that are applied to the bot upon successfully using a skill/item
object.abilQUse = 10
object.abilWUse = 15
object.abilRUse = 60
object.abilEUse = 10
object.nImmunityUse = 18
object.nIllusionUse = 20
object.nEnergizerUse = 10
object.nSilenceUse = 10
--thresholds of aggression the bot must reach to use these abilities
object.abilQThreshold = 25
object.abilWThreshold = 26
object.abilEThreshold = 16
object.abilRThreshold = 50
object.nImmunityThreshold = 20
object.nIllusionThreshold = 30
object.nEnergizerThreshold = 10
object.nSilenceThreshold = 15
object.nTime = 0
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
--            oncombatevent override        --
-- use to check for infilictors (fe. buffs) --
----------------------------------------------
-- @param: eventdata
-- @return: none
function object:oncombateventOverride(EventData)
   self:oncombateventOld(EventData)
   
   local bDebugEchos = false
   local addBonus = 0
   
   if EventData.Type == "Ability" then
   if bDebugEchos then BotEcho(" ABILITY EVENT! InflictorName: "..EventData.InflictorName) end
        if EventData.InflictorName == "Ability_Chipper1" then
            addBonus = addBonus + object.abilQUse
			object.abilQUseTime = EventData.TimeStamp
			--BotEcho(object.abilQUseTime)
    elseif EventData.InflictorName == "Ability_Chipper2" then
            addBonus = addBonus + object.abilWUse
			object.abilWUseTime = EventData.TimeStamp
			--BotEcho(object.abilWUseTime)
	elseif EventData.InflictorName == "Ability_Chipper3" then
            addBonus = addBonus + object.abilEUse
			object.abilEUseTime = EventData.TimeStamp
			--BotEcho(object.abilEUseTime)		
	elseif EventData.InflictorName == "Ability_Chipper4" then
            addBonus = addBonus + object.abilRUse
			object.abilRUseTime = EventData.TimeStamp
			--BotEcho(object.abilRUseTime)
     end
	 elseif EventData.Type == "Item" then
			if core.itemPortalkey ~= nil and EventData.SourceUnit == core.unitSelf:GetUniqueID() and EventData.InflictorName == core.itemPortalkey:GetName() then
            nAddBonus = nAddBonus + self.nPortalkeyUse
			end
			if core.itemImmunity ~= nil and EventData.SourceUnit == core.unitSelf:GetUniqueID() and EventData.InflictorName == core.itemImmunity:GetName() then
            nAddBonus = nAddBonus + self.nImmunityUse
			end
			if core.itemIllusion ~= nil and EventData.SourceUnit == core.unitSelf:GetUniqueID() and EventData.InflictorName == core.itemIllusion:GetName() then
			addBonus = addBonus + self.nIllusion
			end
			if core.itemSilence ~= nil and EventData.SourceUnit == core.unitSelf:GetUniqueID() and EventData.InflictorName == core.itemSilence:GetName() then
			addBonus = addBonus + self.nSilence
			end
   end
   if addBonus > 0 then
        core.DecayBonus(self)
        core.nHarassBonus = core.nHarassBonus + addBonus

	end
end		
-- override combat event trigger function.
object.oncombateventOld = object.oncombatevent
object.oncombatevent     = object.oncombateventOverride

------------------------------------------------------
--            customharassutility override          --
-- change utility according to usable spells here   --
------------------------------------------------------
-- @param: iunitentity hero
-- @return: number
local function AbilitiesUpUtility(hero)
local nUtility = 0

local unitSelf = core.unitSelf

    if skills.abilQ:CanActivate() then
        nUtility = nUtility + object.abilQUp
    end

    if skills.abilW:CanActivate() then
        nUtility = nUtility + object.abilWUp
    end
	
	if skills.abilE:CanActivate() then
        nUtility = nUtility + object.abilEUp
    end
 
	if skills.abilR:CanActivate() then
        nUtility = nUtility + object.abilRUp
    end
	
	if object.itemPortalkey and object.itemPortalkey:CanActivate() then
        nUtility = nUtility + object.nPortalkeyUp
    end
	
	if object.itemSilence and object.itemSilence:CanActivate() then
        nUtility = nUtility + object.nSilenceUp
    end

    return nUtility
end

local function CustomHarassUtilityFnOverride(hero)
	local nUtility = AbilitiesUpUtility(hero)	
	
	return Clamp(nUtility, 0, 100)
end

-- assisgn custom Harrass function to the behaviourLib object
behaviorLib.CustomHarassUtility = CustomHarassUtilityFnOverride
object.UseBlade = false


--------------------------------------------------------------
-- ClearToTarget function
-- Original authorship credit to [S2]BlacRyu
--------------------------------------------------------------
-- @param: vecOrigin - the source of the skillshot
--         vecTarget - the target's position vector
--         tCandidates - a table of candidates the skillshot
--                       could collide with
--         nDistanceThreshold - the hit radius of the
--                              skillshot
-- @return: true if clear path exists, otherwise false
local function funcClearToTarget(vecOrigin, vecTarget, tCandidates, nDistanceThreshold)
    local bDebugLines = true
     
    local nOriginToTargetDistanceSq = Vector3.Distance2DSq(vecOrigin, vecTarget)
    local nDistanceThresholdSq = 78 * 78
    for index, candidate in pairs(tCandidates) do
        -- If the candidate unit is farther away than the target position, skip it
        if candidate and candidate:GetPosition() ~= vecTarget and Vector3.Distance2DSq(vecOrigin, candidate:GetPosition()) < nOriginToTargetDistanceSq then
            -- Nearest, furthest, what's the difference?
            local vecNearestPointOnLine = core.GetFurthestPointOnLine(candidate:GetPosition(), vecOrigin, vecTarget)
            local nCandidateRadius = candidate:GetBoundsRadius() * sqrtTwo -- not sure if this multiply is necessary, but it's better to overestimate here
            local nCandidateRadiusSq = nCandidateRadius * nCandidateRadius
             
            if Vector3.Distance2DSq(candidate:GetPosition(), vecNearestPointOnLine) <= nDistanceThresholdSq + nCandidateRadiusSq and not candidate:IsUnitType("Mechanical") then
             
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
 


--Find Items
local function funcFindItemsOverride(botBrain)
	local bUpdated = object.FindItemsOld(botBrain)

	if bUpdated then
		--toDo Run File if inventory changed

		local inventory = core.unitSelf:GetInventory(true)
		for slot = 1, 6, 1 do
			local curItem = inventory[slot]
			if curItem then
				if core.itemNuke == nil and curItem:GetName() == "Item_Nuke" then
					core.itemNuke = core.WrapInTable(curItem)
				elseif core.itemTablet == nil and curItem:GetName() == "Item_PushStaff" then
					core.itemTablet = core.WrapInTable(curItem)
				elseif core.itemPortalKey == nil and curItem:GetName() == "Item_PortalKey" then
					core.itemPortalKey = core.WrapInTable(curItem)
				elseif core.itemFrostfieldPlate == nil and curItem:GetName() == "Item_FrostfieldPlate" then
					core.itemFrostfieldPlate = core.WrapInTable(curItem)
				elseif core.itemSheepstick == nil and curItem:GetName() == "Item_Morph" then
					core.itemSheepstick = core.WrapInTable(curItem)					
				elseif core.itemSilence == nil and curItem:GetName() == "Item_Silence" then
					core.itemSilence = core.WrapInTable(curItem)
				elseif core.itemReplenish == nil and curItem:GetName() == "Item_Replenish" then
					core.itemReplenish = core.WrapInTable(curItem)
				elseif core.itemSacStone == nil and curItem:GetName() == "Item_SacrificialStone" then
					core.itemSacStone = core.WrapInTable(curItem)
				end
				
			end
		end
	end
end


object.FindItemsOld = core.FindItems
core.FindItems = funcFindItemsOverride


--------------------------------------------------------------
--                    Harass Behavior                       --
-- All code how to use abilities against enemies goes here  --
--------------------------------------------------------------
-- @param botBrain: CBotBrain
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
    local targetPosition = unitTarget:GetPosition()
    local vecTargetPosition = unitTarget:GetPosition()
    local nTargetExtraRange = core.GetExtraRange(unitTarget)
    local nTargetDistanceSq = Vector3.Distance2DSq(vecMyPosition, vecTargetPosition)
    
    local nLastHarassUtility = behaviorLib.lastHarassUtil
    local bCanSee = core.CanSeeUnit(botBrain, unitTarget)    
    local bActionTaken = false
    
    if core.CanSeeUnit(botBrain, unitTarget) then
    local bTargetVuln = unitTarget:IsStunned() or unitTarget:IsImmobilized() or unitTarget:IsPerplexed()
    local nRocketRadius = 85
    local bComboing = false
    
	if not bActionTaken then 
			core.FindItems()
			local itemSilence = core.itemSilence 
			if itemSilence then
				local nRange = itemSilence:GetRange()
				if itemSilence:CanActivate() and nLastHarassUtility > botBrain.nSilenceThreshold and not bTargetVuln and not unitTarget:IsSilenced() then
					if nTargetDistanceSq < (nRange * nRange) then
						bActionTaken = core.OrderItemEntityClamp(botBrain, unitSelf, itemSilence, unitTarget)
					end
				end
			end
		end
	
    if not bActionTaken then
        local abilBuffer = skills.abilE
        if abilBuffer:CanActivate() and nLastHarassUtility > botBrain.abilEThreshold then
            local nRange = 700
            if nTargetDistanceSq < (nRange * nRange) then
                bActionTaken = core.OrderAbilityEntity(botBrain, abilBuffer, unitSelf)
            end
        end
    end		
	
	
    if not bActionTaken then
		local abilRocket = skills.abilQ
		if abilRocket:CanActivate() and nLastHarassUtility > botBrain.abilQThreshold then
			if unitTarget.storedPosition and unitTarget.lastStoredPosition then
			local nRange = abilRocket:GetRange()
			local vecTargetVelocity = unitTarget.storedPosition - unitTarget.lastStoredPosition
			local vecTargetPosition = vecTargetPosition + vecTargetVelocity
			local tCandidateUnits = core.CopyTable(core.localUnits["EnemyCreeps"])
			for key, unit in pairs(core.localUnits["EnemyCreeps"]) do
				tCandidateUnits[key] = unit
			end
			--for key, unit in pairs(core.localUnits["AllyHeroes"]) do
				--tCandidateUnits[key] = unit
			--end
					
				if nTargetDistanceSq < (nRange * nRange) and funcClearToTarget(unitSelf:GetPosition(), vecTargetPosition, tCandidateUnits, nRockerRadius) then
					bActionTaken = core.OrderAbilityPosition(botBrain, abilRocket, vecTargetPosition)
				end            
            end
		end
	end	
		
	if not bActionTaken then 
		local abilTar = skills.abilW
        if abilTar:CanActivate() and nLastHarassUtility > botBrain.abilWThreshold and unitSelf:GetMana() > 150 then
		local nRange = skills.abilW and skills.abilW:GetRange() or nil
		local nRadius = 200
		local vecTarget = core.AoETargeting(unitSelf, nRange, nRadius, true, unitTarget, core.enemyTeam, nil)
            if vecTarget then
				bActionTaken = core.OrderAbilityPosition(botBrain, abilTar, vecTarget)	
            end
        end
    end 

	if not bActionTaken then
		local vecTargetVelocity = unitTarget.storedPosition - unitTarget.lastStoredPosition
        local abilBlade = skills.abilR
		local abilR = skills.abilR
		local nRange = abilBlade:GetRange()
		local potentialDamage = (skills.abilR:GetLevel()*100+100+150)
        if skills.abilR:CanActivate() and nLastHarassUtility > botBrain.abilRThreshold and unitTarget:GetHealth() <= potentialDamage then
		--if nTargetDistanceSq < (nRange * nRange) then
            botBrain:OrderAbilityVector(abilBlade, vecTargetPosition, vecTargetPosition + vecTargetVelocity )
            --botBrain:OrderAbilityVector(abilBlade, Vector3.Create(targetPosition.x-100, targetPosition.y-100), targetPosition)
            bActionTaken = true
			
        --end
        end
		object.UseBlade = false
    end	

		
        return object.harassExecuteOld(botBrain)
    end 
end
-- overload the behaviour stock function with custom 
object.harassExecuteOld = behaviorLib.HarassHeroBehavior["Execute"]
behaviorLib.HarassHeroBehavior["Execute"] = HarassHeroExecuteOverride


----------------------------------
-- Retreating tactics as seen in Spennerino's ScoutBot 
-- with variations from Rheged's Emerald Warden Bot
----------------------------------
object.nRetreatTarThreshold = 15
object.nRetreatBufferThreshold = 10
function funcRetreatFromThreatExecuteOverride(botBrain)
	local bDebugEchos = false
	local bActionTaken = false
	local unitSelf = core.unitSelf
	local vecMyPosition = unitSelf:GetPosition()
	local nlastRetreatUtil = behaviorLib.lastRetreatUtil
	local unitTarget = behaviorLib.heroTarget
	local tEnemies = core.localUnits["EnemyHeroes"]
	local nCount = 0
	
	if unitSelf:GetHealthPercent() < .4 then
	for id, unitEnemy in pairs(tEnemies) do
		if core.CanSeeUnit(botBrain, unitEnemy) then
			nCount = nCount + 1
		end
	end
	
	if nCount > 0 then
		local vecTargetPosition = unitTarget:GetPosition()
		local unitTarget = behaviorLib.heroTarget
			if not bActionTaken then
				local abilTar = skills.abilW
					if behaviorLib.lastRetreatUtil >= object.nRetreatTarThreshold and abilTar:CanActivate() then  
					if bDebugEchos then BotEcho("Backing...Tossing Tar") end
					bActionTaken = core.OrderAbilityPosition(botBrain, abilTar, (vecMyPosition/2+vecTargetPosition/2))
				end
			end
		
		-- When retreating, will deploy a turret in front of him facing the opposite direction to slow enemies down.
			if not bActionTaken then
				local abilBuffer = skills.abilE
				if behaviorLib.lastRetreatUtil >= object.nRetreatBufferThreshold and abilBuffer:CanActivate() then
					if bDebugEchos then BotEcho ("Backing...Using Buffer") end
					bActionTaken = core.OrderAbilityEntity(botBrain, abilBuffer, unitSelf)
				end
			end
			
		end
	end
	if unitTarget == nil then
     	return object.RetreatFromThreatExecuteOld(botBrain)
		end
	if not bActionTaken then
		return object.RetreatFromThreatExecuteOld(botBrain)
	end
end
object.RetreatFromThreatExecuteOld = behaviorLib.RetreatFromThreatExecute
behaviorLib.RetreatFromThreatBehavior["Execute"] = funcRetreatFromThreatExecuteOverride



function behaviorLib.GetCreepAttackTarget(botBrain, unitEnemyCreep, unitAllyCreep) --called pretty much constantly
    local unitSelf = core.unitSelf
    if botBrain:GetGold() > 3000 or (unitSelf:GetMana()< 10 and unitSelf:GetManaRegen() < 2)  then
        local wellPos = core.allyWell and core.allyWell:GetPosition() or behaviorLib.PositionSelfBackUp()
        core.OrderMoveToPosAndHoldClamp(botBrain, unitSelf, wellPos, false)
    end

    core.nHarassBonus = 0

    local bDebugEchos = false
    -- no predictive last hitting, just wait and react when they have 1 hit left
    -- prefers LH over deny

    local unitSelf = core.unitSelf
    local nDamageMin = unitSelf:GetFinalAttackDamageMin()
    
    core.FindItems(botBrain)

    local nProjectileSpeed = unitSelf:GetAttackProjectileSpeed()

    if unitEnemyCreep and core.CanSeeUnit(botBrain, unitEnemyCreep) then
        local nTargetHealth = unitEnemyCreep:GetHealth()
        local tNearbyAllyCreeps = core.localUnits['AllyCreeps']
        local tNearbyAllyTowers = core.localUnits['AllyTowers']
        local nExpectedCreepDamage = 0
        local nExpectedTowerDamage = 0

        local vecTargetPos = unitEnemyCreep:GetPosition()
        local nProjectileTravelTime = Vector3.Distance2D(unitSelf:GetPosition(), vecTargetPos) / nProjectileSpeed
        if bDebugEchos then BotEcho ("Projectile travel time: " .. nProjectileTravelTime ) end 
        
        --Determine the damage expcted on the creep by other creeps
        for i, unitCreep in pairs(tNearbyAllyCreeps) do
            if unitCreep:GetAttackTarget() == unitEnemyCreep then
                --if unitCreep:IsAttackReady() then
                    local nCreepAttacks = 1 + math.floor(unitCreep:GetAttackSpeed() * nProjectileTravelTime)
                    nExpectedCreepDamage = nExpectedCreepDamage + unitCreep:GetFinalAttackDamageMin() * nCreepAttacks
                --end
            end
        end

        for i, unitTower in pairs(tNearbyAllyTowers) do
            if unitTower:GetAttackTarget() == unitEnemyCreep then
                --if unitTower:IsAttackReady() then

                    local nTowerAttacks = 1 + math.floor(unitTower:GetAttackSpeed() * nProjectileTravelTime)
                    nExpectedTowerDamage = nExpectedTowerDamage + unitTower:GetFinalAttackDamageMin() * nTowerAttacks
                --end
            end
        end
        
        if bDebugEchos then BotEcho ("Excpecting ally creeps to damage enemy creep for " .. nExpectedCreepDamage .. " - using this to anticipate lasthit time") end
        
        if nDamageMin >= (nTargetHealth - nExpectedCreepDamage - nExpectedTowerDamage) then
            local bActuallyLH = true
            
            -- [Tutorial] Make DS not mess with your last hitting before shit gets real
            if core.bIsTutorial and core.bTutorialBehaviorReset == false and core.unitSelf:GetTypeName() == "Hero_Shaman" then
                bActuallyLH = false
            end
            
            if bActuallyLH then
                if bDebugEchos then BotEcho("Returning an enemy") end
                return unitEnemyCreep
            end
        end
    end
	
	if unitAllyCreep then
        local nTargetHealth = unitAllyCreep:GetHealth()
        local tNearbyEnemyCreeps = core.localUnits['EnemyCreeps']
        local tNearbyEnemyTowers = core.localUnits['EnemyTowers']
        local nExpectedCreepDamage = 0
        local nExpectedTowerDamage = 0

        local vecTargetPos = unitAllyCreep:GetPosition()
        local nProjectileTravelTime = Vector3.Distance2D(unitSelf:GetPosition(), vecTargetPos) / nProjectileSpeed
        if bDebugEchos then BotEcho ("Projectile travel time: " .. nProjectileTravelTime ) end 
        
        --Determine the damage expcted on the creep by other creeps
        for i, unitCreep in pairs(tNearbyEnemyCreeps) do
            if unitCreep:GetAttackTarget() == unitAllyCreep then
                --if unitCreep:IsAttackReady() then
                    local nCreepAttacks = 1 + math.floor(unitCreep:GetAttackSpeed() * nProjectileTravelTime)
                    nExpectedCreepDamage = nExpectedCreepDamage + unitCreep:GetFinalAttackDamageMin() * nCreepAttacks
                --end
            end
        end
		
		for i, unitTower in pairs(tNearbyEnemyTowers) do
            if unitTower:GetAttackTarget() == unitAllyCreep then 
                --if unitTower:IsAttackReady() then

                    local nTowerAttacks = 1 + math.floor(unitTower:GetAttackSpeed() * nProjectileTravelTime)
                    nExpectedTowerDamage = nExpectedTowerDamage + unitTower:GetFinalAttackDamageMin() * nTowerAttacks
                --end
            end
        end
        
        if nDamageMin >= (nTargetHealth - nExpectedCreepDamage - nExpectedTowerDamage) then
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

function AttackCreepsExecuteOverride(botBrain)
    local unitSelf = core.unitSelf
    local unitCreepTarget = core.unitCreepTarget

    if unitCreepTarget and core.CanSeeUnit(botBrain, unitCreepTarget) then      
        local vecTargetPos = unitCreepTarget:GetPosition()
        local nDistSq = Vector3.Distance2DSq(unitSelf:GetPosition(), vecTargetPos)
        local nAttackRangeSq = core.GetAbsoluteAttackRangeToUnit(unitSelf, currentTarget, true)
        
        local nDamageMin = unitSelf:GetFinalAttackDamageMin()

        if unitCreepTarget ~= nil then
            local nProjectileSpeed = unitSelf:GetAttackProjectileSpeed()            
            local nTargetHealth = unitCreepTarget:GetHealth()

            local vecTargetPos = unitCreepTarget:GetPosition()
            local nProjectileTravelTime = Vector3.Distance2D(unitSelf:GetPosition(), vecTargetPos) / nProjectileSpeed
            if bDebugEchos then BotEcho ("Projectile travel time: " .. nProjectileTravelTime ) end 
            
            local nExpectedCreepDamage = 0
            local nExpectedTowerDamage = 0
            local tNearbyAttackingCreeps = nil
            local tNearbyAttackingTowers = nil

            if unitCreepTarget:GetTeam() == unitSelf:GetTeam() then
                tNearbyAttackingCreeps = core.localUnits['EnemyCreeps']
                tNearbyAttackingTowers = core.localUnits['EnemyTowers']
            else
                tNearbyAttackingCreeps = core.localUnits['AllyCreeps']
                tNearbyAttackingTowers = core.localUnits['AllyTowers']
            end
        
            --Determine the damage expcted on the creep by other creeps
            for i, unitCreep in pairs(tNearbyAttackingCreeps) do
                if unitCreep:GetAttackTarget() == unitCreepTarget then
                    --if unitCreep:IsAttackReady() then
                        local nCreepAttacks = 1 + math.floor(unitCreep:GetAttackSpeed() * nProjectileTravelTime)
                        nExpectedCreepDamage = nExpectedCreepDamage + unitCreep:GetFinalAttackDamageMin() * nCreepAttacks
                    --end
                end
            end
        
            --Determine the damage expcted on the creep by other creeps
            for i, unitTower in pairs(tNearbyAttackingTowers) do
                if unitTower:GetAttackTarget() == unitCreepTarget then
                    --if unitTower:IsAttackReady() then
                        local nTowerAttacks = 1 + math.floor(unitTower:GetAttackSpeed() * nProjectileTravelTime)
                        nExpectedTowerDamage = nExpectedTowerDamage + unitTower:GetFinalAttackDamageMin() * nTowerAttacks
                    --end
                end
            end

            if nDistSq < nAttackRangeSq and unitSelf:IsAttackReady() and nDamageMin>=(unitCreepTarget:GetHealth() - nExpectedCreepDamage - nExpectedTowerDamage) then --only kill if you can get gold
                --only attack when in nRange, so not to aggro towers/creeps until necessary, and move forward when attack is on cd
                core.OrderAttackClamp(botBrain, unitSelf, unitCreepTarget)
            elseif (nDistSq > nAttackRangeSq * 0.6) then 
                --SR is a ranged hero - get somewhat closer to creep to slow down projectile travel time
                --BotEcho("MOVIN OUT")
                local vecDesiredPos = core.AdjustMovementForTowerLogic(vecTargetPos)
                core.OrderMoveToPosClamp(botBrain, unitSelf, vecDesiredPos, false)
            else
                core.OrderHoldClamp(botBrain, unitSelf, false)
            end
        end
    else
        return false
    end
end
object.AttackCreepsExecuteOld = behaviorLib.HarassHeroBehavior["Execute"]
behaviorLib.AttackCreepsBehavior["Execute"] = AttackCreepsExecuteOverride

