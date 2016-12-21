--Accursed Bot v0.1
-- by Sparks1992

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
object.bDebugExecute = false

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

BotEcho('loading accursed_main...')

--------------------------------
-- Lanes
--------------------------------
core.tLanePreferences = {Jungle = 0, Mid = 1, ShortSolo = 4, LongSolo = 3, ShortSupport = 5, LongSupport = 4, ShortCarry = 2, LongCarry = 1}


object.heroName = 'Hero_Accursed'

----------------------------------
--	Accursed items
----------------------------------
--[[ list code:
	"# Item" is "get # of these"
	"Item #" is "get this level of the item" --]]
behaviorLib.StartingItems = {"Item_Scarab", "2 Item_RunesOfTheBlight", "Item_ManaPotion"}
behaviorLib.LaneItems = {"Item_Steamboots", "Item_PortalKey"} --Item_Silence is hell flower
behaviorLib.MidItems = {"Item_Spellshards", "Item_Silence", "Item_Weapon3" } --Item_Lightning2 is charged hammer, Item_Weapon3 is savage mace, Item_Critical1 is riftshards
behaviorLib.LateItems = {"Item_Critical1 4", "Item_HarkonsBlade", "Item_Sasuke", "Item_Evasion"} --Item_Freeze is frostwolf, Item_Sasuke is Genjuro, Item_Evasion is wingbow

--------------------------------
-- Skills
--------------------------------
local bSkillsValid = false
object.tSkills = {
    1, 0, 1, 0, 	-- Levels 1-4 -> Max Shield and Cauterize
	1, 3, 1, 0,     -- Levels 5-8 -> Lvl up Ultimate at lvl 6
	0, 2, 3, 2,     -- Levels 9-12 -> then level the passive Sear
	2, 2, 4, 		-- Levels 13-15 -> 
	3, 4, 4, 4, 4, 4, 4, 4, 4, 4,	-- Levels 17-25 -> Attribute Points
}
function object:SkillBuild()

	local unitSelf = self.core.unitSelf

	if not bSkillsValid then
		skills.abilCauterize = unitSelf:GetAbility(0)   -- 1st Skill -> Cauterize
		skills.abilShield = unitSelf:GetAbility(1)  -- 2nd Skill -> Fire Shield
		skills.abilSear = unitSelf:GetAbility(2)  -- 3rd Skill -> Sear
		skills.abilFlameConsumption = unitSelf:GetAbility(3)  -- Ultimate -> Flame Consumption
		
		if skills.abilCauterize and skills.abilShield and skills.abilSear and skills.abilFlameConsumption then
			bSkillsValid = true
		else
			return
		end
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

----------------------------------
--	Accursed specific harass bonuses
--
--  Abilities off cd increase harass util
--
--  Ability use increases harass util for a time
----------------------------------

object.nCauterizeUp = 12
object.nShieldUp = 16
object.nSearUp = 10
object.nFlameConsumptionUp = 25

object.nCauterizeUse = 15
object.nShieldUse = 10
object.nFlameConsumptionUse = 20


--Accursed abilities use gives bonus to harass util for a while
function object:oncombateventOverride(EventData)
	self:oncombateventOld(EventData)
	
	local addBonus = 0
	if EventData.Type == "Ability" then
		
		if EventData.InflictorName == "Ability_Accursed1" then  -- Using Cauterize will add bonus points to harass util
			addBonus = addBonus + object.nCauterizeUse
		end
		if EventData.InflictorName == "Ability_Accursed2" then  -- Using Fire Shield will add bonus points to harass util
			addBonus = addBonus + object.nShieldUse
		end
		if EventData.InflictorName == "Ability_Accursed4" then  -- Using Flame Consumption will add bonus points to harass util
			addBonus = addBonus + object.nFlameConsumptionUse
		end
		
	end
	
	if addBonus > 0 then
		core.DecayBonus(self)
		core.nHarassBonus = core.nHarassBonus + addBonus
	end
end
object.oncombateventOld = object.oncombatevent
object.oncombatevent 	= object.oncombateventOverride

--Util calc override
local function CustomHarassUtilityOverride(hero)
	local nUtility = 0
	
	if skills.abilCauterize:CanActivate() then
		nUtility = nUtility + object.nCauterizeUp  -- Cauterize off CD will add bonus harass util
	end
	if skills.abilShield:CanActivate() then
		nUtility = nUtility + object.nShieldUp   -- Fire Shield off CD will add bonus harass util
	end
	if skills.abilSear:CanActivate() then
		nUtility = nUtility + object.nSearUp       -- Sear is always off CD, so when leveling it, hte bot will become more aggresive
	end
	if skills.abilFlameConsumption:CanActivate() then
		nUtility = nUtility + object.nFlameConsumptionUp   -- Flame Consumption off CD will add bonus harass util
	end
	return nUtility
end
behaviorLib.CustomHarassUtility = CustomHarassUtilityOverride   


----------------------------------
--	Accursed harass actions
----------------------------------
local function HarassHeroExecuteOverride(botBrain)
	local bDebugEchos = false
		
	local unitSelf = core.unitSelf
	local unitTarget = behaviorLib.heroTarget 
	
	local bActionTaken = false
	
	local nDistSq = Vector3.Distance2DSq(unitSelf:GetPosition(), unitTarget:GetPosition())
	local bTargetMagicImmune = unitTarget:IsMagicImmune()
	local vecTargetPosition = unitTarget:GetPosition()
	
	
	
	--since we are using an old pointer, ensure we can still see the target for entity targeting
	if unitTarget ~= nil then 				
		
		
		
		-- 1st Skill -> Cauterize Enemy if enemy is NOT MAGIC IMMUNE
		if not bTargetMagicImmune then
			if not bActionTaken then
				local abilCauterize = skills.abilCauterize
				if abilCauterize:CanActivate() and nDistSq < 700 * 700 then
					bActionTaken = core.OrderAbilityEntity(botBrain, abilCauterize, unitTarget)
				end
			end
		end
		
		-- 2nd Skill -> Use Fire Shield to Debuff Allies
		
		if not bActionTaken then
			if abilShield and abilShield:CanActivate() then
				local tTargets = core.CopyTable(core.localUnits["AllyHeroes"])
				local nOwnID = unitSelf:GetUniqueID()

				tTargets[nOwnID] = unitSelf --I am also a target
				for key, hero in pairs(tTargets) do

					if hero:IsVulnerable() or hero:IsSilenced() or hero:IsPerplexed() then 
						bActionTaken = core.OrderAbilityEntity(botBrain, abilShield, hero)
					end
				end
			end
		end
		
	end
	
	

	
	if not bActionTaken then
		return object.harassExecuteOld(botBrain)
	end
end
object.harassExecuteOld = behaviorLib.HarassHeroBehavior["Execute"]
behaviorLib.HarassHeroBehavior["Execute"] = HarassHeroExecuteOverride


----------------------------------
--	Accursed Help behavior
--
--	Utility:
--	Execute: Use Shield/Cauterize
----------------------------------
behaviorLib.nHealUtilityMul = 0.8
behaviorLib.nHealHealthUtilityMul = 1.0
behaviorLib.nHealTimeToLiveUtilityMul = 0.5

function behaviorLib.HealHealthUtilityFn(unitHero)
	local nUtility = 0
	
	local nYIntercept = 100
	local nXIntercept = 100
	local nOrder = 2

	nUtility = core.ExpDecay(unitHero:GetHealthPercent() * 100, nYIntercept, nXIntercept, nOrder)
	
	return nUtility
end

function behaviorLib.TimeToLiveUtilityFn(unitHero)
	--Increases as your time to live based on your damage velocity decreases
	local nUtility = 0
	
	local nHealthVelocity = unitHero:GetHealthVelocity()
	local nHealth = unitHero:GetHealth()
	local nTimeToLive = 9999
	if nHealthVelocity < 0 then
		nTimeToLive = nHealth / (-1 * nHealthVelocity)
		
		local nYIntercept = 100
		local nXIntercept = 20
		local nOrder = 2
		nUtility = core.ExpDecay(nTimeToLive, nYIntercept, nXIntercept, nOrder)
	end
	
	nUtility = Clamp(nUtility, 0, 100)
	
	return nUtility, nTimeToLive
end

behaviorLib.unitHealTarget = nil
behaviorLib.nHealTimeToLive = nil
function behaviorLib.HealUtility(botBrain)
	local bDebugEchos = false
	
	local nUtility = 0

	local unitSelf = core.unitSelf
	behaviorLib.unitHealTarget = nil
	
	local abilShield = skills.abilShield
	local abilCauterize = skills.abilCauterize
	
	local nHighestUtility = 0
	local unitTarget = nil
	local nTargetTimeToLive = nil
	if abilShield:CanActivate() or abilCauterize:CanActivate() then
		local tTargets = core.CopyTable(core.localUnits["AllyHeroes"])
		local nOwnID = unitSelf:GetUniqueID()
		local bHealthLow = unitSelf:GetHealthPercent() < 0.20
		local bHealAtWell = core.GetCurrentBehaviorName(botBrain) == "HealAtWell"

		tTargets[nOwnID] = unitSelf --I am also a target
		for key, hero in pairs(tTargets) do
			--Don't heal ourself if we are going to head back to the well anyway,
			-- as it could cause us to retrace half a walkback,
			-- unless it our health is below 20%
			if hero:GetUniqueID() ~= nOwnID or not bHealAtWell or bHealthLow then
				local nCurrentUtility = 0
				
				local nHealthUtility = behaviorLib.HealHealthUtilityFn(hero) * behaviorLib.nHealHealthUtilityMul
				local nTimeToLiveUtility = nil
				local nCurrentTimeToLive = nil
				nTimeToLiveUtility, nCurrentTimeToLive = behaviorLib.TimeToLiveUtilityFn(hero)
				nTimeToLiveUtility = nTimeToLiveUtility * behaviorLib.nHealTimeToLiveUtilityMul
				nCurrentUtility = nHealthUtility + nTimeToLiveUtility
				
				if nCurrentUtility > nHighestUtility then
					nHighestUtility = nCurrentUtility
					nTargetTimeToLive = nCurrentTimeToLive
					unitTarget = hero
				end
			end
		end

		if unitTarget then
			nUtility = nHighestUtility
		
			behaviorLib.unitHealTarget = unitTarget
			behaviorLib.nHealTimeToLive = nTargetTimeToLive
		end
	end
	
	nUtility = nUtility * behaviorLib.nHealUtilityMul
	
	if botBrain.bDebugUtility == true and nUtility ~= 0 then
		BotEcho(format("  HelpUtility: %g", nUtility))
	end
	
	return nUtility
end



function behaviorLib.HealExecute(botBrain)
	local abilShield = skills.abilShield
	local abilCauterize = skills.abilCauterize

	if not abilShield then BotEcho("Can't find abilShield") end
	if not abilCauterize then BotEcho("Can't find abilCauterize") end
	
	local unitHealTarget = behaviorLib.unitHealTarget
	local nHealTimeToLive = behaviorLib.nHealTimeToLive
	
	if unitHealTarget and (abilShield:CanActivate() or abilCauterize:CanActivate())then 
		local unitSelf = core.unitSelf
		local vecTargetPosition = unitHealTarget:GetPosition()
		local nDistanceSq = Vector3.Distance2DSq(unitSelf:GetPosition(), vecTargetPosition)
		local nSkillSq = 700 * 700		
		if nDistanceSq < nSkillSq then
			core.OrderAbilityEntity(botBrain, abilShield, unitHealTarget)
			core.OrderAbilityEntity(botBrain, abilCauterize, unitHealTarget)	
		end
	else
		return false
	end
	
	return true
end

behaviorLib.HealBehavior = {}
behaviorLib.HealBehavior["Utility"] = behaviorLib.HealUtility
behaviorLib.HealBehavior["Execute"] = behaviorLib.HealExecute
behaviorLib.HealBehavior["Name"] = "Heal"
tinsert(behaviorLib.tBehaviors, behaviorLib.HealBehavior)
-----------------------
-- Return to well
-----------------------

-- Escape combo for running away

function behaviorLib.CustomReturnToWellExecute(botBrain)
	local unitSelf = core.unitSelf
	local abilShield = skills.abilShield
	local abilFlameConsumption = skills.abilFlameConsumption
	if abilFlameConsumption and abilFlameConsumption:CanActivate() then
			return core.OrderAbility(botBrain, abilFlameConsumption)
		else if abilShield and abilShield:CanActivate() then
			return core.OrderAbilityEntity(botBrain, abilShield, unitSelf)
		end
	end
end



BotEcho('finished loading accursed_main')

