--DampeerBot v0.76412523

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

BotEcho('loading dampeer_main...')

--------------------------------
-- Lanes
--------------------------------
core.tLanePreferences = {Jungle = 0, Mid = 5, ShortSolo = 3, LongSolo = 1, ShortSupport = 0, LongSupport = 2, ShortCarry = 4, LongCarry = 4}

object.heroName = 'Hero_Dampeer'

--------------------------------
-- Leveling Order | Skills
--------------------------------
object.tSkills = {
    1, 0, 0, 1, 0,
    3, 0, 1, 1, 2, 
    3, 2, 2, 2, 4,
    3, 4, 4, 4, 4,
    4, 4, 4, 4, 4,
}

---------------------------------
-- Skill Declare
---------------------------------
local bSkillsValid = false
function object:SkillBuild()
-- takes care at load/reload, <name_#> to be replaced by some convinient name.
    local unitSelf = self.core.unitSelf
	
    if not bSkillsValid then
        skills.abilTerrorize 	  = unitSelf:GetAbility(0)
        skills.abilVampFlight	  = unitSelf:GetAbility(1)
        skills.abilBloodthirst	  = unitSelf:GetAbility(2)
        skills.abilConsume 		  = unitSelf:GetAbility(3)
		skills.abilAttributeBoost = unitSelf:GetAbility(4)

		if skills.abilTerrorize and skills.abilVampFlight and skills.abilBloodthirst and skills.abilConsume and skills.abilAttributeBoost then
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
--	Dampeer items
----------------------------------
behaviorLib.StartingItems = 
	{"Item_LoggersHatchet", "Item_IronBuckler", "Item_ManaPotion", "Item_RunesOfTheBlight"}
behaviorLib.LaneItems = 
	{"Item_BloodChalice", "Item_Marchers", "Item_GraveLocket", "Item_EnhancedMarchers"}
behaviorLib.MidItems = 
	{"Item_Lightbrand", "Item_Sicarius", "Item_Strength6"} 
behaviorLib.LateItems = 
	{"Item_Wingbow", "Item_BehemothsHeart", 'Item_Damage9'}


---------------------------------------------------
--                   Overrides                   --
---------------------------------------------------

--[[for testing
function object:onthinkOverride(tGameVariables)
	self:onthinkOld(tGameVariables)
	
	core.unitSelf:TeamShare()
	
	-- Insert code here
end
object.onthinkOld = object.onthink
object.onthink 	= object.onthinkOverride
--]]

----------------------------------
--	Dampeer specific harass bonuses
--
--  Abilities off cd increase harass util
--  Ability use increases harass util for a time
----------------------------------

object.nTerrorizeUp			= 35
object.nVampFlightUp 		= 35	
object.nConsumeUp			= 40


object.nTerrorizeUseBonus	= 40
object.nVampFlightUseBonus	= 45
object.nConsumeUseBonus		= 50

object.nTerrorizeThreshold 	= 30
object.nVampFlightThreshold = 35
object.nConsumeThreshold 	= 40


local function AbilitiesUpUtilityFn()
	local nUtility = 0
	
	if skills.abilTerrorize:CanActivate() then
		nUtility = nUtility + object.nTerrorizeUpBonus
	end
	
	if skills.abilVampFlight:CanActivate() then
		nUtility = nUtility + object.nVampFlightUpBonus
	end
		
	if skills.abilConsume:CanActivate() then
		nUtility = nUtility + object.nConsumeUpBonus
	end
	

	return nUtility
end

--ability use gives bonus to harass util for a while
function object:oncombateventOverride(EventData)
	self:oncombateventOld(EventData)
	
	local nAddBonus = 0
	if EventData.Type == "Ability" then
			
		if EventData.InflictorName == "Ability_Dampeer1" then
			nAddBonus = nAddBonus + object.nTerrorizeUseBonus
		end
		if EventData.InflictorName == "Ability_Dampeer2" then
			nAddBonus = nAddBonus + object.nVampFlightUseBonus
		end
		if EventData.InflictorName == "Ability_Dampeer4" then
			nAddBonus = nAddBonus + object.nConsumeUseBonus
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

----------------------------------
--	Dampeer harass actions
----------------------------------
local function HarassHeroExecuteOverride(botBrain)
	local bDebugEchos = false
	
	local unitTarget = behaviorLib.heroTarget
	if unitTarget == nil or not unitTarget:IsValid() then
		return false --can not execute, move on to the next behavior
	end
	
	local unitSelf = core.unitSelf
	local vecMyPosition = unitSelf:GetPosition()
	
	local vecTargetPosition = unitTarget:GetPosition()
	local nTargetDistanceSq = Vector3.Distance2DSq(vecMyPosition, vecTargetPosition)
	
	local nLastHarassUtil = behaviorLib.lastHarassUtil
	local bCanSee = core.CanSeeUnit(botBrain, unitTarget)	
	
	local bActionTaken = false
	
	local abilVampFlight = skills.abilVampFlight
	local abilTerrorize = skills.abilTerrorize
	local abilConsume = skills.abilConsume

	--Vampiric Flight
	if abilVampFlight:CanActivate() and bCanSee then
		local nRange = abilVampFlight:GetRange()
		if nLastHarassUtil > botBrain.nVampFlightThreshold  and abilTerrorize:CanActivate() and nTargetDistanceSq < (nRange * nRange) then
			bActionTaken = core.OrderAbilityEntity(botBrain, abilVampFlight, unitTarget)
		end	
	end
	
	--Terrorize
	if not bActionTaken and abilTerrorize:CanActivate() then
		local nRange = abilTerrorize:GetRange()
		if nTargetDistanceSq < (300 * 300) then
			if nLastHarassUtil > botBrain.nTerrorizeThreshold or unitSelf:GetManaPercent() > .8 then 
				bActionTaken = core.OrderAbility(botBrain, abilTerrorize)
			end
		end
	end

	--Consume
		if not bActionTaken and abilConsume:CanActivate() and bCanSee then
			local nRange = abilConsume:GetRange()
			if nLastHarassUtil > botBrain.nConsumeThreshold and nTargetDistanceSq < (nRange * nRange) then
				bActionTaken = core.OrderAbilityEntity(botBrain, abilConsume, unitTarget)
			end
		end

	if not bActionTaken then
		return object.harassExecuteOld(botBrain)
	end
end
object.harassExecuteOld = behaviorLib.HarassHeroBehavior["Execute"]
behaviorLib.HarassHeroBehavior["Execute"] = HarassHeroExecuteOverride

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
	rainbows motherfucker
	invisible
--]]

BotEcho('finished loading dampeer_main')