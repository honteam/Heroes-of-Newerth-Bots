--Midas Bot v0.1
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

BotEcho('loading midas_main...')

--------------------------------
-- Lanes
--------------------------------
core.tLanePreferences = {Jungle = 0, Mid = 5, ShortSolo = 3, LongSolo = 4, ShortSupport = 3, LongSupport = 3, ShortCarry = 1, LongCarry = 1}
-- Jungle 0 -> Cannot jungle
-- Mid 5 -> Hero needs levels faster than laning with another hero
-- ShortSolo 3 -> Can solo a lane because of the Warp escape
-- LongSolo 4 -> Better to go Suicide if the team has a Jungler, because of the Warp ability (1st skill point goes in escape)
-- ShortSupport 3 -> Can support heroes after level 4 with Transmute stun
-- LongSupport 3 -> Can support heroes after level 4 with Transmute stun
-- ShortCarry 1 -> Item build will push him more towards Nuker than Carry
-- LongCarry 1 -> Item build will push him more towards Nuker than Carry

object.heroName = 'Hero_Midas'

----------------------------------
--	Midas items
----------------------------------
--[[ list code:
	"# Item" is "get # of these"
	"Item #" is "get this level of the item" --]]
behaviorLib.StartingItems = {"Item_Scarab", "2 Item_RunesOfTheBlight", "Item_ManaPotion"} -- Items: Scarab, 2 Runes Of The Blight, Mana Potion
behaviorLib.LaneItems = {"Item_Marchers", "Item_Steamboots", "Item_PortalKey"} -- Items: Marchers, Steamboots, Portal Key
behaviorLib.MidItems = {"Item_Spellshards", "Item_HealthMana2" } -- Items: Spell Shards, Icon Of The Goddes
behaviorLib.LateItems = {"Item_GrimoireOfPower", "Item_Morph"} -- Items: Grimoire Of Power, Kuldra Sheepstick

--------------------------------
-- Skills
--------------------------------
local bSkillsValid = false
object.tSkills = {
    2, 0, 1, 3, 	-- Levels 1-4 -> 1st point in Warp for escape then one point in each skill for Transmute
	0, 1, 0, 3,     -- Levels 5-8 -> Leveling 1st and 2nd skill equaly in case one skill misses to have hte same dmg output
	1, 0, 1, 3,     -- Levels 9-12 -> Same as in levels 5-8
	2, 2, 2, 		-- Levels 13-15 -> Finishing the skill points with max Warp (one level is enough until this point, because is only used to escape or chase)
	4, 4, 4, 4, 4, 4, 4, 4, 4, 4,	-- Levels 17-25 -> Attribute Points
}
function object:SkillBuild()

	local unitSelf = self.core.unitSelf

	if not bSkillsValid then
		skills.abilGoldenSalvo = unitSelf:GetAbility(0)   -- 1st Skill -> Golden Salvo
		skills.abilLionsPride = unitSelf:GetAbility(1)  -- 2nd Skill -> Lion's Pride
		skills.abilWarp = unitSelf:GetAbility(2)  -- 3rd Skill -> Elemental Warp
		skills.abilTransmute = unitSelf:GetAbility(3)  -- Ultimate -> Transmute
		
		if skills.abilGoldenSalvo and skills.abilLionsPride and skills.abilWarp and skills.abilTransmute then
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
--	Midas specific harass bonuses
--
--  Abilities off cd increase harass util
--
--  Ability use increases harass util for a time
----------------------------------

object.nGoldenSalvoUp = 8
object.nLionsPrideUp = 12
object.nWarpUp = 5
object.nTransmuteUp = 10

object.nGoldenSalvoUse = 15
object.nLionsPrideUse = 5
object.nWarpUse = 10



--Midas abilities use gives bonus to harass util for a while
function object:oncombateventOverride(EventData)
	self:oncombateventOld(EventData)
	
	local addBonus = 0
	if EventData.Type == "Ability" then
		
		if EventData.InflictorName == "Ability_Midas1" then  -- Using Golden Salvo will add bonus points to harass util
			addBonus = addBonus + object.nGoldenSalvoUse
		end
		if EventData.InflictorName == "Ability_Midas2" then  -- Using Lion's Pride will add bonus points to harass util
			addBonus = addBonus + object.nLionsPrideUse
		end
		if EventData.InflictorName == "Ability_Midas3" then  -- Using Elemental Warp will add bonus points to harass util
			addBonus = addBonus + object.nWarpUse
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
	
	if skills.abilGoldenSalvo:CanActivate() then
		nUtility = nUtility + object.nGoldenSalvoUp  -- Golden Salvo off CD will add bonus harass util
	end
	if skills.abilLionsPride:CanActivate() then
		nUtility = nUtility + object.nLionsPrideUp   -- Lion's Pride off CD will add bonus harass util
	end
	if skills.abilWarp:CanActivate() then
		nUtility = nUtility + object.nWarpUp         -- Elemental Warp off CD will add bonus harass util
	end
	if skills.abilTransmute:CanActivate() then
		nUtility = nUtility + object.nTransmuteUp    -- Transmute never goes on CD -> after leveling Ultimate Midas will become more aggresive because of the stun
	end
	return nUtility
end
behaviorLib.CustomHarassUtility = CustomHarassUtilityOverride   


----------------------------------
--	Midas harass actions
----------------------------------
local function HarassHeroExecuteOverride(botBrain)
	local bDebugEchos = false
		
	local unitSelf = core.unitSelf
	local unitTarget = behaviorLib.heroTarget 
	
	local bActionTaken = false
	
	local nDistSq = Vector3.Distance2DSq(unitSelf:GetPosition(), unitTarget:GetPosition())
	local bTargetMagicImmune = unitTarget:IsMagicImmune()
	local vecTargetPosition = unitTarget:GetPosition()
	local nLastHarassUtility = behaviorLib.lastHarassUtil
	local bCanSee = core.CanSeeUnit(botBrain, unitTarget)
	local itemPortalKey = core.GetItem("Item_PortalKey")
	local nMyExtraRange = core.GetExtraRange(unitSelf)
	
	
	--since we are using an old pointer, ensure we can still see the target for entity targeting
	if unitTarget ~= nil then 
		
		-- Portal Key -- Uses PK to close in ONLY if target is NOT MAGIC IMMUNE
		if bCanSee and not bTargetMagicImmune and itemPortalKey and itemPortalKey:CanActivate() then   
		if nDistSq > 800 * 800 then
			if nLastHarassUtility > behaviorLib.diveThreshold or core.NumberElements(core.GetTowersThreateningPosition(vecTargetPosition, nMyExtraRange, core.myTeam)) == 0 then
				local _, sortedTable = HoN.GetUnitsInRadius(vecTargetPosition, 1000, core.UNIT_MASK_HERO + core.UNIT_MASK_ALIVE, true)
				local EnemyHeroes = sortedTable.EnemyHeroes
				if core.NumberElements(EnemyHeroes) == 1 then
					bActionTaken = core.OrderItemPosition(botBrain, unitSelf, itemPortalKey, vecTargetPosition)
				end
			end
		end
	end
		
		-- Since all of Midas's skill are Magic Dmg, and Ultimate depends on whether they hit or not, Midas will use skill only when his target is NOT MAGIC IMMUNE
		
		-- 1st Skill -> Golden Salvo
		if not bTargetMagicImmune then
			if not bActionTaken then
				local abilGoldenSalvo = skills.abilGoldenSalvo
				if abilGoldenSalvo:CanActivate() then
					bActionTaken = core.OrderAbilityPosition(botBrain, abilGoldenSalvo, unitTarget:GetPosition())
				end
			end
		end
		
		-- 2nd Skill -> Lion's Pride
		if not bTargetMagicImmune then
			if not bActionTaken then
				local abilLionsPride = skills.abilLionsPride
				if abilLionsPride:CanActivate() then
					bActionTaken = core.OrderAbilityPosition(botBrain, abilLionsPride, unitTarget:GetPosition())
				end
			end
		end
		
		-- 3rd Skill -> Elemental Warp
		if not bTargetMagicImmune then
			if not bActionTaken then
				local abilWarp = skills.abilWarp
				if abilWarp:CanActivate() then
					bActionTaken = core.OrderAbilityPosition(botBrain, abilWarp, unitTarget:GetPosition())
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

-----------------------
-- HEAL -> Lion's Pride
-----------------------

-- Code taken from SoulReaperBot and modified to target location heal except self


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
	
	local abilLionsPride = skills.abilLionsPride
	
	local nHighestUtility = 0
	local unitTarget = nil
	local nTargetTimeToLive = nil
	if abilLionsPride and abilLionsPride:CanActivate() then
		local tTargets = core.CopyTable(core.localUnits["AllyHeroes"])
		local bHealthLow = unitSelf:GetHealthPercent() < 0.20
		local bHealAtWell = core.GetCurrentBehaviorName(botBrain) == "HealAtWell"

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
	local abilLionsPride = skills.abilLionsPride

	if not abilLionsPride then BotEcho("Can't find abilLionsPride") end
	
	local unitHealTarget = behaviorLib.unitHealTarget
	local nHealTimeToLive = behaviorLib.nHealTimeToLive
	
	if unitHealTarget and abilLionsPride and abilLionsPride:CanActivate() then 
		local unitSelf = core.unitSelf
		local vecTargetPosition = unitHealTarget:GetPosition()
		local nDistanceSq = Vector3.Distance2DSq(unitSelf:GetPosition(), vecTargetPosition)
		local nDistanceHealSq = 900 * 900
		
		if nDistanceSq < nDistanceHealSq then
			core.OrderAbilityPosition(botBrain, abilLionsPride, vecTargetPosition)
		else
			core.OrderMoveToUnitClamp(botBrain, unitSelf, unitHealTarget)
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
--this is a great function to override with using retreating skills, such as blinks, travels, stuns or slows.

-- Blink code taken from ChronosBot - Works really well with Elemental Warp

function behaviorLib.CustomReturnToWellExecute(botBrain)
	return core.OrderBlinkAbilityToEscape(botBrain, skills.abilWarp, true)
end

--------------------------------------------
--          PushExecute Override          --
--------------------------------------------

--  Pushing code taken from MyrmidonBot and modified
--  Uses Golden Salvo and Lion's Pride on creeps when pushing if he has more than 60% mana

local function CustomPushExecuteFnOverride(botBrain)
	local bActionTaken = false
	local nMinimumCreeps = 3

	local abilGoldenSalvo = skills.abilGoldenSalvo
	local abilLionsPride = skills.abilLionsPride
	if abilGoldenSalvo:CanActivate() and abilLionsPride:CanActivate() and core.unitSelf:GetManaPercent() > 0.60 then
		local tCreeps = core.localUnits["EnemyCreeps"]
		local nNumberCreeps =  core.NumberElements(tCreeps)
		if nNumberCreeps >= nMinimumCreeps then
			local vecTarget = core.GetGroupCenter(tCreeps)
			bActionTaken = core.OrderAbilityPosition(botBrain, abilGoldenSalvo, vecTarget)
			bActionTaken = core.OrderAbilityPosition(botBrain, abilLionsPride, vecTarget)
		end
	end

	return bActionTaken
end
behaviorLib.customPushExecute = CustomPushExecuteFnOverride

local function TeamGroupBehaviorOverride(botBrain)
	if not CustomPushExecuteFnOverride(botBrain) then
		return object.TeamGroupBehaviorOld(botBrain)
	end
end

object.TeamGroupBehaviorOld = behaviorLib.TeamGroupBehavior["Execute"]
behaviorLib.TeamGroupBehavior["Execute"] = TeamGroupBehaviorOverride


BotEcho('finished loading midas_main')
