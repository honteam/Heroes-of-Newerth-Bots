-------------------------------------------------------------------
-------------------------------------------------------------------
--   ____     __               ___    ____             __        --
--  /\  _`\  /\ \             /\_ \  /\  _`\          /\ \__     --
--  \ \,\L\_\\ \ \/'\       __\//\ \ \ \ \L\ \    ___ \ \ ,_\    --
--   \/_\__ \ \ \ , <     /'__`\\ \ \ \ \  _ <'  / __`\\ \ \/    --
--     /\ \L\ \\ \ \\`\  /\  __/ \_\ \_\ \ \L\ \/\ \L\ \\ \ \_   --
--     \ `\____\\ \_\ \_\\ \____\/\____\\ \____/\ \____/ \ \__\  --
--      \/_____/ \/_/\/_/ \/____/\/____/ \/___/  \/___/   \/__/  --
-------------------------------------------------------------------
-------------------------------------------------------------------
-- Skelbot v0.0000008
-- This bot represent the BARE minimum required for HoN to spawn a bot
-- and contains some very basic overrides you can fill in
--

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

local gold = 0

BotEcho(object:GetName()..' loading Aluna_main...')




--####################################################################
--####################################################################
--#                                                                 ##
--#                  bot constant definitions                       ##
--#                                                                 ##
--####################################################################
--####################################################################

object.heroName = 'Hero_Aluna'

behaviorLib.StartingItems  = {"Item_RunesOfTheBlight", "Item_RunesOfTheBlight", "Item_MinorTotem", "Item_MinorTotem", "Item_MinorTotem", "Item_MinorTotem", "Item_GuardianRing"}
behaviorLib.LaneItems  = {"Item_ManaRegen3", "Item_Marchers", "Item_Steamboots"}
behaviorLib.MidItems  = {"Item_Silence"}
behaviorLib.LateItems  = {"Item_Protect", "Item_Lightning2"}


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
function object:SkillBuild()
    core.VerboseLog("skillbuild()")

    local unitSelf = self.core.unitSelf
    if  skills.abillight == nil then
        skills.abillight = unitSelf:GetAbility(0)
        skills.abilthrow = unitSelf:GetAbility(1)
        skills.abildejavu = unitSelf:GetAbility(2)
        skills.abilred = unitSelf:GetAbility(3)
        skills.abilAttributeBoost = unitSelf:GetAbility(4)
    end
    if unitSelf:GetAbilityPointsAvailable() <= 0 then
        return
    end
    
	if skills.abilthrow:CanLevelUp() then
		skills.abilthrow:LevelUp()
	elseif skills.abillight:GetLevel() < 1 then
		skills.abillight:LevelUp()
	elseif skills.abildejavu:GetLevel() < 1 then
		skills.abildejavu:LevelUp()
	elseif skills.abilred:CanLevelUp() then
		skills.abilred:LevelUp()
	elseif skills.abildejavu:CanLevelUp() then
		skills.abildejavu:LevelUp()
	elseif skills.abillight:CanLevelUp() then
		skills.abillight:LevelUp()
	else 
		skills.abilAttributeBoost:LevelUp()
	end
	
  
end

----------------------------------
--	Aluna's specific harass bonuses
----------------------------------

object.nLightUp = 20
object.nThrowUp = 20
object.nDejaUp = 30

object.nThrowEz = 5
object.nThrowTreshold = 25
object.nThrowCk = 20
object.nLightTreshold = 40
object.nLightChannel = 5
object.nDejaRetreatTreshold = 80
object.nDejaTreshold = 50
object.nSnipeTreshold = 10
object.nThrowKillTreshold = 1
object.nSilenceChannel = 5

object.nThrowUse = 10
object.nLightUse = 40
object.nDejaUse = 25

------------------------------------------------------
--            onthink override                      --
-- Called every bot tick, custom onthink code here  --
------------------------------------------------------

function object:onthinkOverride(tGameVariables)
    self:onthinkOld(tGameVariables)

   
end
object.onthinkOld = object.onthink
object.onthink 	= object.onthinkOverride




----------------------------------------------
--            oncombatevent override        --
-- use to check for infilictors (fe. buffs) --
----------------------------------------------

function object:oncombateventOverride(EventData)
	self:oncombateventOld(EventData)
	
	local nAddBonus = 0
	
	if EventData.Type == "Ability" then
		if EventData.InflictorName == "Ability_Aluna1" then
			nAddBonus = nAddBonus + object.nLightUse
		elseif EventData.InflictorName == "Ability_Aluna2" then
			nAddBonus = nAddBonus + object.nThrowUse
		elseif EventData.InflictorName == "Ability_Aluna3" then
			nAddBonus = nAddBonus + object.nDejaUse
		end
	end
	
	if nAddBonus > 0 then
		core.DecayBonus(self)
		core.nHarassBonus = core.nHarassBonus + nAddBonus
	end
	
end
-- override combat event trigger function.
object.oncombateventOld = object.oncombatevent
object.oncombatevent     = object.oncombateventOverride



------------------------------------------------------
--            customharassutility override          --
-- change utility according to usable spells here   --
------------------------------------------------------

local function CustomHarassUtilityFnOverride(hero)
    local nUtil = 0
	
	if skills.abillight:CanActivate() then
		nUtil = nUtil + object.nLightUp
	end
	
	if skills.abilthrow:CanActivate() then
		nUtil = nUtil + object.nThrowUp
	end
	
	return nUtil
end
-- assisgn custom Harrass function to the behaviourLib object
behaviorLib.CustomHarassUtilityFn = CustomHarassUtilityFnOverride   

----------------------------------
--  FindItems Override
----------------------------------

local function funcFindItemsOverride(botBrain)
	local bUpdated = object.FindItemsOld(botBrain)
	
	if core.itemMarchers ~= nil and not core.itemMarchers:IsValid() then
		core.itemMarchers = nil
	end
	if core.itemSteams ~= nil and not core.itemSteams:IsValid() then
		core.itemSteams = nil
	end
	if core.itemManaRegen3 ~= nil and not core.itemManaRegen3:IsValid() then
		core.itemManaRegen3 = nil
	end
	if core.itemSilence ~= nil and not core.itemSilence:IsValid() then
		core.itemSilence = nil
	end
	
	if bUpdated then
		--only update if we need to
		if core.itemMarchers and core.itemSteams and core.itemManaRegen3 and core.itemSilence then
			return
		end
		
		local inventory = core.unitSelf:GetInventory(true)
		for slot = 1, 12, 1 do
			local curItem = inventory[slot]
			if curItem then
				if core.itemMarchers == nil and curItem:GetName() == "Item_Marchers" then
					core.itemMarchers = core.WrapInTable(curItem)
				elseif core.itemSteams == nil and curItem:GetName() == "Item_Steamboots" then
					core.itemSteams = core.WrapInTable(curItem)
				elseif core.itemManaRegen3 == nil and curItem:GetName() == "Item_ManaRegen3" then
					core.itemManaRegen3 = core.WrapInTable(curItem)
				elseif core.itemSilence == nil and curItem:GetName() == "Item_Silence" then
					core.itemSilence = core.WrapInTable(curItem)
				end
			end
		end
	end
end

--------------------------------------------------------------
--                    Harass Behavior                       --
-- All code how to use abilities against enemies goes here  --
--------------------------------------------------------------

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
	
	local bDebugEchos = true
    
	
	--- Power Throw if target is rooted
	local abilred = skills.abilred
	local abilthrow = skills.abilthrow
	local bTargetRooted = unitTarget:IsStunned() or unitTarget:IsImmobilized() or unitTarget:GetMoveSpeed() < 200
	local nMana = abilthrow:GetManaCost() + abilred:GetManaCost()
	local nMagicResistance = unitTarget:GetMagicResistance()
	if not bActionTaken and bTargetRooted then
		--- Cast if target is rooted
		if abilthrow:CanActivate() and nLastHarassUtility > botBrain.nThrowEz then
			local nRange = abilthrow:GetRange()
			if nTargetDistanceSq < (nRange * nRange) then
				bActionTaken = core.OrderAbilityPosition(botBrain, abilthrow, vecTargetPosition)
			end
		end
	end
		
	--- Power Throw Harass
	if not bActionTaken and abilthrow:CanActivate() and nLastHarassUtility > botBrain.nThrowTreshold then
		local nRange = abilthrow:GetRange()
		if nTargetDistanceSq < (nRange * nRange) and nTargetDistanceSq > 600000 then	
			bActionTaken = core.OrderAbilityPosition(botBrain, abilthrow, vecTargetPosition)
		end
	end
	
	--]]
	--[[ Red Throw Snipe
	if not bActionTaken and abilthrow:CanActivate() and abilred:CanActivate() then
		if unitSelf:GetMana() > nMana then
			if abilthrow:GetLevel() == 3 then
				nDamage = 280
			elseif abilthrow:GetLevel() == 4 then
				nDamage = 350
			end
		
			local nDamageMultiplier = 1 - nMagicResistance
			local nEstimatedDamage = nDamage * nDamageMultiplier
			local nRange = abilthrow:GetRange()
			if nTargetDistanceSq > (nRange * nRange) then
				if nEstimatedDamage > unitTarget:GetHealth() then
					BotEcho("  Using redthrow")
					bActionTaken = core.OrderAbility(botBrain, abilred)
					bActionTaken = core.OrderAbilityPosition(botBrain, abilthrow, vecTargetPosition)
				end
			end
		end
	end
	--]]
	
	--- Dejavu
	local abildeja = skills.abildejavu
	if not bActionTaken and nTargetDistanceSq > nAttackRange and abildeja:CanActivate() and nLastHarassUtility > botBrain.nDejaTreshold and not abildeja:IsActive() then
		bActionTaken = core.OrderAbility(botBrain, abildeja)
	end
	
	--- Emerald Lightning
    if core.CanSeeUnit(botBrain, unitTarget) then
		local bTargetChannel = unitTarget:IsChanneling()
		local bTargetRooted = unitTarget:IsStunned() or unitTarget:IsImmobilized() or unitTarget:GetMoveSpeed() < 200
		local abillight = skills.abillight
		local abildeja = skills.abildejavu
		local nMana2 = abillight:GetManaCost() + abildeja:GetManaCost()
		--- Stun
		if not bActionTaken and abillight:CanActivate() and nLastHarassUtility > botBrain.nLightTreshold and not bTargetRooted then
			local nRange = abillight:GetRange()
			if nTargetDistanceSq < (nRange * nRange) then
				bActionTaken = core.OrderAbilityEntity(botBrain, abillight, unitTarget)
			end
		--- Stun if target is channeling
		elseif not bActionTaken and abillight:CanActivate() and nLastHarassUtility > botBrain.nLightChannel and bTargetChannel then
			local nRange = abillight:GetRange()
			if nTargetDistanceSq < (nRange * nRange) then
				bActionTaken = core.OrderAbilityEntity(botBrain, abillight, unitTarget)
			else
                bActionTaken = core.OrderMoveToUnitClamp(botBrain, unitSelf, unitTarget)
				if unitSelf:GetMana() > nMana2 and not abildeja:IsActive() and abildeja:CanActivate() then
					bActionTaken = core.OrderAbility(botBrain, abildeja)
				end
			end
		end
    end
	
	--- Hellflower
	if core.CanSeeUnit(botBrain, unitTarget) then
		local bTargetChannel = unitTarget:IsChanneling()
		local abildeja = skills.abildejavu
		core.FindItems()
		local itemSilence = core.itemSilence
		if not bActionTaken and bTargetChannel and itemSilence then
			local nRange = itemSilence:GetRange()
			if itemSilence:CanActivate() and nLastHarassUtility > botBrain.nSilenceChannel then
				if nTargetDistanceSq < (nRange * nRange) then
					bActionTaken = core.OrderItemEntityClamp(botBrain, unitSelf, itemSilence, unitTarget)
				else 
					bActionTaken = core.OrderMoveToUnitClamp(botBrain, unitSelf, unitTarget)
					local nMana = itemSilence:GetManaCost() + abildeja:GetManaCost()
					if unitSelf:GetMana() > nMana and not abildeja:IsActive() and abildeja:CanActivate() then
						bActionTaken = core.OrderAbility(botBrain, abildeja)
					end
				end
			end
		end
		
	end
    if not bActionTaken then
        return object.harassExecuteOld(botBrain)
    end
end	

function behaviorLib.GetCreepAttackTarget(botBrain, unitEnemyCreep, unitAllyCreep)
	
	--- Checks for items to gold, and moves back to well if importans items + tp is available
	local unitSelf = core.unitSelf
	gold = botBrain:GetGold()
	core.FindItems()
    local itemMarchers = core.itemMarchers
	local itemSteams = core.itemSteams
	local itemManaRegen3 = core.itemManaRegen3
	local itemSilence = core.itemSilence
	local bActionTaken = false
	local abildeja = skills.abildejavu
	
	if not itemMarchers and gold > 1910 then
		local wellPos = core.allyWell and core.allyWell:GetPosition() or behaviorLib.PositionSelfBackUp()
		core.OrderMoveToPosAndHoldClamp(botBrain, unitSelf, wellPos, false)
		if not bActionTaken and abildeja:CanActivate() then
			bActionTaken = core.OrderAbility(botBrain, abildeja)
		end
	end
	
	if itemSteams and not itemManaRegen3 and gold > 1710 then
		local wellPos = core.allyWell and core.allyWell:GetPosition() or behaviorLib.PositionSelfBackUp()
		core.OrderMoveToPosAndHoldClamp(botBrain, unitSelf, wellPos, false)
		if not bActionTaken and abildeja:CanActivate() then
			bActionTaken = core.OrderAbility(botBrain, abildeja)
		end
	end
	
	if itemSteams and not itemSilence and gold > 4725 then
		local wellPos = core.allyWell and core.allyWell:GetPosition() or behaviorLib.PositionSelfBackUp()
		core.OrderMoveToPosAndHoldClamp(botBrain, unitSelf, wellPos, false)
		if not bActionTaken and abildeja:CanActivate() then
			bActionTaken = core.OrderAbility(botBrain, abildeja)
		end
	end
	
	if itemSilence and gold > 3500 then
		local wellPos = core.allyWell and core.allyWell:GetPosition() or behaviorLib.PositionSelfBackUp()
		core.OrderMoveToPosAndHoldClamp(botBrain, unitSelf, wellPos, false)
		if not bActionTaken and abildeja:CanActivate() then
			bActionTaken = core.OrderAbility(botBrain, abildeja)
		end
	end
	
	-- Lasthitting
	local nDamage = unitSelf:GetFinalAttackDamageMin() + 1
	if unitEnemyCreep and core.CanSeeUnit(botBrain, unitEnemyCreep) then
		local nTargetHealth = unitEnemyCreep:GetHealth()
		if nDamage >= nTargetHealth then
			return unitEnemyCreep
		end
	end
	
	if unitAllyCreep then
		local nTargetHealth = unitAllyCreep:GetHealth()
		if nDamage >= nTargetHealth then
			return unitAllyCreep
		end
	end

	return nil
end

function AttackCreepsExecuteOverride(botBrain)
	local unitSelf = core.unitSelf
	local currentTarget = core.unitCreepTarget
	if currentTarget and core.CanSeeUnit(botBrain, currentTarget) then
		local vecTargetPos = currentTarget:GetPosition()
		local nDistSq = Vector3.Distance2DSq(unitSelf:GetPosition(), vecTargetPos)
		local nAttackRangeSq = core.GetAbsoluteAttackRangeToUnit(unitSelf, currentTarget, true)
		local nDamage = unitSelf:GetFinalAttackDamageMin() + 1
		if currentTarget ~= nil then
			if nDistSq < nAttackRangeSq and unitSelf:IsAttackReady() and nDamage >= currentTarget:GetHealth() then
				core.OrderAttackClamp(botBrain, unitSelf, currentTarget)
			end
		end
	else
		return false
	end
end

---------------------------------------------
-- Retreat From Threat Override
---------------------------------------------
local function RetreatFromThreatExecuteOverride(botBrain)
	local bActionTaken = false
	local nlastRetreatUtil = behaviorLib.lastRetreatUtil
	local unitSelf = core.unitSelf
	local abildeja = skills.abildejavu
	--- Uses Dejavu when escaping
	if not bActionTaken and abildeja:CanActivate() and nlastRetreatUtil > botBrain.nDejaRetreatTreshold and not abildeja:IsActive() then
		bActionTaken = core.OrderAbility(botBrain, abildeja)
	end
	
	
end

---------------------------------------------
-- HarassHeroUtility Override
---------------------------------------------
--]]
--[[
local function HarassHeroUtilityOverride(botBrain)

	local oldHeroes = core.localUnits["EnemyHeroes"]
	local unitSelf = core.unitSelf
	local abilred = skills.abilred
	local abilthrow = skills.abilthrow
	local nMana = abilthrow:GetManaCost() + abilred:GetManaCost()
	
	if unitSelf:GetMana() > nMana and abilthrow:CanActivate() and abilred:CanActivate() then
		local vecMyPosition = core.unitSelf:GetPosition()		
		local tAllHeroes = HoN.GetUnitsInRadius(vecMyPosition, 9999999, core.UNIT_MASK_ALIVE + core.UNIT_MASK_HERO)
		local tEnemyHeroes = {}
		local nEnemyTeam = core.enemyTeam
		for key, hero in pairs(tAllHeroes) do
			if hero:GetTeam() == nEnemyTeam then
				tinsert(tEnemyHeroes, hero)
			end
		end
		
		core.teamBotBrain:AddMemoryUnitsToTable(tEnemyHeroes, nEnemyTeam, vecMyPosition, 9999999)
		core.localUnits["EnemyHeroes"] = tEnemyHeroes
	end
	
	local nUtility = object.HarassHeroUtilityOld(botBrain)	
	
	core.localUnits["EnemyHeroes"] = oldHeroes
	return nUtility
	
	
end
--]]
-- object.HarassHeroUtilityOld = behaviorLib.HarassHeroBehavior["Utility"] 
-- behaviorLib.HarassHeroBehavior["Utility"]  = HarassHeroUtilityOverride

-- overload the behaviour stock function with custom 
object.harassExecuteOld = behaviorLib.HarassHeroBehavior["Execute"]
behaviorLib.HarassHeroBehavior["Execute"] = HarassHeroExecuteOverride





