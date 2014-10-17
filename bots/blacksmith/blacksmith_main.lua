local _G = getfenv(0)
local object = _G.object

object.myName = object:GetName()

object.bRunLogic	 = true
object.bRunBehaviors	= true
object.bUpdates 		= true
object.bUseShop 		= true

object.bRunCommands 	= true 
object.bMoveCommands	 = true
object.bAttackCommands	 = true
object.bAbilityCommands = true
object.bOtherCommands	 = true

object.bReportBehavior = false
object.bDebugUtility = false

object.logger = {}
object.logger.bWriteLog = false
object.logger.bVerboseLog = false

object.core 		= {}
object.eventsLib	 = {}
object.metadata 	= {}
object.behaviorLib	 = {}
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
behaviorLib.MidItems  = {"Item_Nuke 3","Item_Morph"}
behaviorLib.LateItems  = {"Item_Nuke 5","Item_Dawnbringer","Item_Intelligence6","Item_Damage9"}


-- skillbuild table, 0 = Stun, 1 = Slow, 2 = Frenzy, 3 = ult, 4 = attri
object.tSkills = {
	0, 1, 0, 1, 0, 
	3, 0, 1, 1, 2, 
	3, 2, 2, 2, 4, 
	3, 4, 4, 4, 4, 
	4, 4, 4, 4, 4, 
}

-- bonus agression points if a skill/item is available for use
object.nAbilStunUp = 10
object.nAbilSlowUp = 10
object.nNukeUp = 20
object.nSheepStickUp = 18
-- bonus agression points that are applied to the bot upon successfully using a skill/item
object.nAbilStunUse = 10
object.nAbilSlowUse = 10
object.nNukeUse = 10
object.nSheepUse = 18
--thresholds of aggression the bot must reach to use these abilities
object.nAbilStunThreshold = 20
object.nAbilSlowThreshold = 20
object.nNukeThreshold = 40
object.nSheepThreshold = 20

--Frenzy Utility
object.nFrenzyUtility = 50

------------------------------
--	 skills   			--
------------------------------
local bSkillsValid = false
function object:SkillBuild()
	local unitSelf = self.core.unitSelf
	if not bSkillsValid then
		skills.abilStun = unitSelf:GetAbility(0)
		skills.abilSlow = unitSelf:GetAbility(1)
		skills.abilFrenzy = unitSelf:GetAbility(2)
	
		if skills.abilStun and skills.abilSlow and skills.abilFrenzy then
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
			addBonus = addBonus + object.nAbilStunUse
		elseif EventData.InflictorName == "Ability_DwarfMagi2" then
			addBonus = addBonus + object.nAbilSlowUse
	end
	elseif EventData.Type == "Item" and EventData.SourceUnit == core.unitSelf:GetUniqueID() then
		local sInflictorName = EventData.InflictorName
		local itemNuke = core.GetItem ("Item_Nuke")
		local itemSheepstick = core.GetItem("Item_Morph")
		if itemNuke and  sInflictorName  == itemNuke:GetName() then
			nAddBonus = nAddBonus + object.nNukeUse
		end
		if itemSheepstick and sInflictorName == itemSheepstick:GetName() then
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
	if skills.abilStun:CanActivate() then
		nUtility = nUtility + object.nAbilStunUp
	end
	if skills.abilSlow:CanActivate() then
		nUtility = nUtility + object.nAbilSlowUp
	end
	
	local itemNuke = core.GetItem ("Item_Nuke")
	if itemNuke and itemNuke:CanActivate() then
		nUtility = nUtility + object.nNukeUp
	end
	
	local itemSheepstick = core.GetItem("Item_Morph")
	if itemSheepstick and itemSheepstick:CanActivate() then
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
	
	if core.CanSeeUnit(botBrain, unitTarget) and not unitTarget:isMagicImmune() then
		local bTargetVuln = unitTarget:IsStunned() or unitTarget:IsImmobilized()
		--sheepstick
		local itemSheepstick = core.GetItem("Item_Morph")
		if itemSheepstick then
			local nRange = itemSheepstick:GetRange()
			if itemSheepstick:CanActivate() and nLastHarassUtility > botBrain.nSheepThreshold and not bTargetVuln and nTargetDistanceSq < (nRange * nRange) then
				if bDebugEchos then BotEcho("Using sheepstick") end
				bActionTaken = core.OrderItemEntityClamp(botBrain, unitSelf, itemSheepstick, unitTarget)
			end
		end
		
		--dot/slow
		if not bActionTaken then
			local abilSlow = skills.abilSlow
			if abilSlow:CanActivate() and nLastHarassUtility > botBrain.nAbilSlowThreshold then
				local nRange = abilSlow:GetRange()
				if nTargetDistanceSq < (nRange * nRange) then
					bActionTaken = core.OrderAbilityEntity(botBrain, abilSlow, unitTarget)
				end
			end
		end 
		
		--stun/nuke
		if not bActionTaken then
			local abilStun = skills.abilStun
			if abilStun:CanActivate() and nLastHarassUtility > botBrain.nAbilStunThreshold and not bTargetVuln then
				local nRange = abilStun:GetRange()
				if nTargetDistanceSq < (nRange * nRange) then
					bActionTaken = core.OrderAbilityEntity(botBrain, abilStun, unitTarget)
				end
			end
		end 
		
		--codex
		if not bActionTaken then
			local itemNuke = core.GetItem ("Item_Nuke")
			if itemNuke then
				local nNukeRange = itemNuke:GetRange()
				if itemNuke:CanActivate() and nLastHarassUtility > botBrain.nNukeThreshold then
					if nTargetDistanceSq <= (nNukeRange * nNukeRange) then
						bActionTaken = core.OrderItemEntityClamp(botBrain, unitSelf, itemNuke, unitTarget)
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

local function FrenzyUtility(botBrain)
	
	local abilFrenzy = skills.abilFrenzy
	if not abilFrenzy:CanActivate() then
		return 0
	end
	
	local unitSelf = core.unitSelf
	
	local nMostDPS = core.GetFinalAttackDamageAverage(unitSelf) * core.GetAttacksPerSecond(unitSelf)
	object.unitFrenzyTarget = unitSelf
	
	local tTargets = core.localUnits["AllyHeroes"]
	
	for _, unitAlly in pairs (tTargets) do
		if not unitAlly:IsStunned() then
			local nDPS = core.GetFinalAttackDamageAverage(unitAlly) * core.GetAttacksPerSecond(unitAlly)
			
			if not unitAlly:IsBotControlled() then
				nDPS = nDPS + 1000
			end
			
			if nDPS > nMostDPS then
				nMostDPS = nDPS
				object.unitFrenzyTarget = unitAlly
			end
		end
	end
	
	return object.nFrenzyUtility
end

local function FrenzyExecute (botBrain)
	local bActionTaken = false

	local unitFrenzyTarget = object.unitFrenzyTarget
	if not object.unitFrenzyTarget then
		return bActionTaken
	end
	
	local abilFrenzy = skills.abilFrenzy
	if abilFrenzy:CanActivate() then
		bActionTaken = core.OrderAbilityEntity(botBrain, abilFrenzy, unitFrenzyTarget)
	end
	
	return bActionTaken
end

behaviorLib.FrenzyBehavior = {}
behaviorLib.FrenzyBehavior["Utility"] = FrenzyUtility
behaviorLib.FrenzyBehavior["Execute"] = FrenzyExecute
behaviorLib.FrenzyBehavior["Name"] = "Frenzy"
tinsert(behaviorLib.tBehaviors, behaviorLib.FrenzyBehavior)
