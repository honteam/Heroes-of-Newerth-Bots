local _G = getfenv(0)
local object = _G.object

object.myName = object:GetName()

object.bRunLogic		 = true
object.bRunBehaviors	= true
object.bUpdates 		= true
object.bUseShop 		= true

object.bRunCommands 	= true 
object.bMoveCommands	 = true
object.bAttackCommands     = true
object.bAbilityCommands = true
object.bOtherCommands     = true

object.bReportBehavior = false
object.bDebugUtility = false

object.logger = {}
object.logger.bWriteLog = false
object.logger.bVerboseLog = false

object.core 		= {}
object.eventsLib	 = {}
object.metadata 	= {}
object.behaviorLib     = {}
object.skills   	  = {}

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

BotEcho(object:GetName()..' loading blacksmith...')


--####################################################################
--####################################################################
--# 																##
--# 				 bot constant definitions   					##
--# 																##
--####################################################################
--####################################################################

-- hero_ < hero >  to reference the internal hon name of a hero, Hero_Yogi == wildsoul
object.heroName = 'Hero_DwarfMagi'


--   item buy order. internal names  
behaviorLib.StartingItems  = {"Item_RunesOfTheBlight", "Item_IronBuckler", "Item_LoggersHatchet"}
behaviorLib.LaneItems  = {"Item_Marchers", "Item_Replenish", "Item_EnhancedMarchers"}
behaviorLib.MidItems  = {"Item_Nuke 3"}
behaviorLib.LateItems  = {"Item_Morph", "Item_Nuke 5"}


-- skillbuild table, 0 = Stun, 1 = Slow, 2 = Frenzy, 3 = ult, 4 = attri
object.tSkills = {
	0, 1, 0, 1, 0, 
	3, 0, 1, 1, 2, 
	3, 2, 2, 2, 4, 
	3, 4, 4, 4, 4, 
	4, 4, 4, 4, 4, 
}

-- bonus agression points if a skill/item is available for use
object.abilStunUp = 10
object.abilSlowUp = 10
object.abilFrenzyUp = 15
object.nNukeUp = 20
object.nSheepUp = 18
-- bonus agression points that are applied to the bot upon successfully using a skill/item
object.abilStunUse = 10
object.abilSlowUse = 10
object.abilFrenzyUse = 15
object.nNukeUse = 10
object.nSheepUse = 18
--thresholds of aggression the bot must reach to use these abilities
object.abilStunThreshold = 20
object.abilSlowThreshold = 20
object.abilFrenzyThreshold = 16
object.nNukeThreshold = 40
object.nSheepThreshold = 20

------------------------------
--     skills   			--
------------------------------
function object:SkillBuild()
	local unitSelf = self.core.unitSelf
	if  skills.abilStun == nil then
		skills.abilStun = unitSelf:GetAbility(0)
		skills.abilSlow = unitSelf:GetAbility(1)
		skills.abilFrenzy = unitSelf:GetAbility(2)
		skills.abilUlt = unitSelf:GetAbility(3)
		skills.abilAttributeBoost = unitSelf:GetAbility(4)
	end
	if unitSelf:GetAbilityPointsAvailable() <= 0 then
		return
	end
   
	local nlev = unitSelf:GetLevel()
	local nlevpts = unitSelf:GetAbilityPointsAvailable()
	for i = nlev, nlev + nlevpts do
		unitSelf:GetAbility( object.tSkills[i] ):LevelUp()
	end
end

----------------------------------------------
--  		  oncombatevent override		--
-- use to check for infilictors (fe. buffs) --
----------------------------------------------
function object:oncombateventOverride(EventData)
   self:oncombateventOld(EventData)
   local bDebugEchos = false
   local addBonus = 0
   
   if EventData.Type == "Ability" then
   if bDebugEchos then BotEcho(" ABILITY EVENT! InflictorName: "..EventData.InflictorName) end
		if EventData.InflictorName == "Ability_DwarfMagi1" then
			addBonus = addBonus + object.abilStunUse
   elseif EventData.InflictorName == "Ability_DwarfMagi2" then
			addBonus = addBonus + object.abilSlowUse
	 end
	 elseif EventData.Type == "Item" then
		if core.itemNuke ~= nil and EventData.SourceUnit == core.unitSelf:GetUniqueID() and EventData.InflictorName == core.itemNuke:GetName() then
			nAddBonus = nAddBonus + object.nNukeUse
		end
		if core.itemSheepstick ~= nil and EventData.SourceUnit == core.unitSelf:GetUniqueID() and EventData.InflictorName == core.itemSheepstick:GetName() then
			nAddBonus = nAddBonus + object.nSheepUse
		end
   end
   if addBonus > 0 then
		core.DecayBonus(self)
		core.nHarassBonus = core.nHarassBonus + addBonus
	end
end
object.oncombateventOld = object.oncombatevent
object.oncombatevent	 = object.oncombateventOverride

------------------------------------------------------
--  		  customharassutility override  		--
-- change utility according to usable spells here   --
------------------------------------------------------
function behaviorLib.CustomHarassUtility(hero)
	local nUtility = 0
	local unitSelf = core.unitSelf
	if skills.abilStun:CanActivate() then
		nUtility = nUtility + object.abilStunUp
	end
	if skills.abilSlow:CanActivate() then
		nUtility = nUtility + object.abilSlowUp
	end
	if skills.abilStun:CanActivate() then
		nUtility = nUtility + object.abilStunUp
	end
	if object.itemNuke and object.itemNuke:CanActivate() then
		nUtility = nUtility + object.nNukeUp
	end
	if object.itemSheepstick and object.itemSheepstick:CanActivate() then
		nUtility = nUtility + object.nSheepStickUp
	end
	return Clamp(nUtility, 0, 100)
end

--------------------------------------------------------------
--  				  Harass Behavior   					--
-- All code how to use abilities against enemies goes here  --
--------------------------------------------------------------
local function HarassHeroExecuteOverride(botBrain)
	local unitTarget = behaviorLib.heroTarget
	if unitTarget == nil then
		return false --Target is invalid, move on to the next behavior
	end
	
	local unitSelf = core.unitSelf
	local vecMyPosition = unitSelf:GetPosition()
	local vecTargetPosition = unitTarget:GetPosition()
	local nTargetDistanceSq = Vector3.Distance2DSq(vecMyPosition, vecTargetPosition)
	
	local nLastHarassUtility = behaviorLib.lastHarassUtil
	local bActionTaken = false
	
	if core.CanSeeUnit(botBrain, unitTarget) then
		local bTargetVuln = unitTarget:IsStunned() or unitTarget:IsImmobilized() or unitTarget:IsPerplexed()
		
		--sheepstick
		core.FindItems()
		local itemSheepstick = core.getItem("Item_Morph")
		if itemSheepstick then
			local nRange = itemSheepstick:GetRange()
			if itemSheepstick:CanActivate() and nLastHarassUtility > botBrain.nSheepThreshold then
				if nTargetDistanceSq < (nRange * nRange) then
					if bDebugEchos then BotEcho("Using sheepstick") end
					bActionTaken = core.OrderItemEntityClamp(botBrain, unitSelf, itemSheepstick, unitTarget)
				end
			end
		end
		
		--dot/slow
		if not bActionTaken then
			local abilSlow = skills.abilSlow
			if abilSlow:CanActivate() and nLastHarassUtility > botBrain.abilSlowThreshold then
				local nRange = abilSlow:GetRange()
				if nTargetDistanceSq < (nRange * nRange) then
					bActionTaken = core.OrderAbilityEntity(botBrain, abilSlow, unitTarget)
				end
			end
		end
		
		--stun/nuke
		if not bActionTaken then
			local abilStun = skills.abilStun
			if abilStun:CanActivate() and nLastHarassUtility > botBrain.abilStunThreshold then
				local nRange = abilStun:GetRange()
				if nTargetDistanceSq < (nRange * nRange) then
					bActionTaken = core.OrderAbilityEntity(botBrain, abilStun, unitTarget)
				end
			end
		end
		
		--codex
		if not bActionTaken then
			local itemNuke = core.getItem("Item_Nuke")
			if itemNuke then
				local nNukeRange = itemNuke:GetRange()
				if itemNuke:CanActivate() and nLastHarassUtility > botBrain.nNukeThreshold then
					if nTargetDistanceSq <= (nNukeRange * nNukeRange) then
						bActionTaken = core.OrderItemEntityClamp(botBrain, unitSelf, itemNuke, unitTarget)
					elseif nTargetDistanceSq > (nNukeRange * nNukeRange) then
						bActionTaken = core.OrderMoveToUnitClamp(botBrain, unitSelf, unitTarget)
					end
				end
			end
		end
		
		if bActionTaken then
			return bActionTaken
		else
			return object.harassExecuteOld(botBrain)
		end
	end
	return false
end
object.harassExecuteOld = behaviorLib.HarassHeroBehavior["Execute"]
behaviorLib.HarassHeroBehavior["Execute"] = HarassHeroExecuteOverride