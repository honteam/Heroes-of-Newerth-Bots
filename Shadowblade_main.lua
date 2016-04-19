--Shadowblade v0.5
--Coded by Sparks1992

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

BotEcho('loading shadowblade_main...')

--------------------------------
-- Lanes
--------------------------------
core.tLanePreferences = {Jungle = 0, Mid = 5, ShortSolo = 3, LongSolo = 1, ShortSupport = 0, LongSupport = 2, ShortCarry = 4, LongCarry = 4}

object.heroName = 'Hero_ShadowBlade'

--------------------------------
-- Leveling Order | Skills
--------------------------------
object.tSkills = {
    0, 1, 0, 2, 0,
    3, 0, 2, 2, 2, 
    3, 1, 1, 1, 4,
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
        skills.abilGargantuan 	  = unitSelf:GetAbility(0)
        skills.abilFeint	  = unitSelf:GetAbility(1)
        skills.abilSoul	  = unitSelf:GetAbility(2)
        skills.abilEssence 		  = unitSelf:GetAbility(3)
		skills.abilAttributeBoost = unitSelf:GetAbility(4)

		if skills.abilGargantuan and skills.abilFeint and skills.abilSoul and skills.abilEssence and skills.abilAttributeBoost then
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
--	Shadowblade items
----------------------------------
behaviorLib.StartingItems = 
	{"Item_LoggersHatchet", "Item_IronBuckler", "Item_ManaPotion", "Item_RunesOfTheBlight"}
behaviorLib.LaneItems = 
	{"Item_Marchers", "Item_Steamboots"} -- Items: Marchers, Upg Marchers to Steamboots
behaviorLib.MidItems = 
	{"Item_Lightbrand", "Item_Sicarius", "Item_Strength6", "Item_Intelligence7"} -- Items: Build Dawnbringer, Staff Of The Master
behaviorLib.LateItems = 
	{"Item_Evasion", "Item_BehemothsHeart", 'Item_Damage9'} -- Items: Wingbow, Behemoth's Heart, DoomBringer


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
--	Shadowblade specific harass bonuses
--
--  Abilities off cd increase harass util
--  Ability use increases harass util for a time
----------------------------------

object.nGargantuanUp = 20
object.nFeintUp = 20	
object.nSoulUp = 20


object.nGargantuanUseBonus = 16
object.nFeintUseBonus = 12
object.nSoulUseBonus = 10


--ability use gives bonus to harass util for a while
function object:oncombateventOverride(EventData)
	self:oncombateventOld(EventData)
	
	local nAddBonus = 0
	if EventData.Type == "Ability" then
			
		if EventData.InflictorName == "Ability_ShadowBlade1" then
			nAddBonus = nAddBonus + object.nGargantuanUseBonus
		end
		if EventData.InflictorName == "Ability_ShadowBlade2" then
			nAddBonus = nAddBonus + object.nFeintUseBonus
		end
		if EventData.InflictorName == "Ability_ShadowBlade3" then
			nAddBonus = nAddBonus + object.nSoulUseBonus
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
------------------------------------------------------
--            CustomHarassUtility Override          --
-- Change Utility according to usable spells here   --
------------------------------------------------------
-- @param: IunitEntity hero
-- @return: number
local function CustomHarassUtilityFnOverride(hero)
    local nUtil = 0
	 
    if skills.abilGargantuan:CanActivate() then
        nUtil = nUtil + object.nGargantuanUp
    end
 
    if skills.abilFeint:CanActivate() then
        nUtil = nUtil + object.nFeintUp
    end
 
    if skills.abilSoul:CanActivate() then
        nUtil = nUtil + object.nSoulUp
    end
	


    return nUtil
end
-- assign custom Harrass function to the behaviourLib object
behaviorLib.CustomHarassUtility = CustomHarassUtilityFnOverride
----------------------------------
--	Shadowblade harass actions
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
	
	local abilFeint = skills.abilFeint
	local abilGargantuan = skills.abilGargantuan
	local abilSoul = skills.abilSoul
	local abilEssence = skills.abilEssence
	
--[[	-- bonus aggresion points for missing enemy HP  ---- Doesn't work
    if bCanSee then
		local nTargetHealth = unitTarget:GetHealthPercent()
		nLastHarassUtil = nLastHarassUtil + (100 - nTargetHealth * 100)
	end


--]]

	--Feint
	if abilFeint:CanActivate() and bCanSee and unitSelf:GetMana() > 200 then
		local nRange = abilFeint:GetRange()
		if abilGargantuan:CanActivate() and nTargetDistanceSq < (nRange * nRange) then
			bActionTaken = core.OrderAbilityEntity(botBrain, abilFeint, unitTarget)
		end
	end

		--Gargantuan
	if not bActionTaken and abilGargantuan:CanActivate() then
		if nTargetDistanceSq < (300 * 300) then
			bActionTaken = core.OrderAbility(botBrain, abilGargantuan)
		--Soul is used only if Feint is on Cooldown, to be used in combo: Feint -> Gargantuan -> Soul
			if abilFeint:CanActivate() then
						bActionTaken = core.OrderAbilityEntity(botBrain, abilFeint, unitTarget)
				elseif abilSoul:CanActivate() then
						bActionTaken = core.OrderAbility(botBrain, abilSoul) 
				end
		end
	end	
		

	if not bActionTaken then
		return object.harassExecuteOld(botBrain)
	end
	
end
object.harassExecuteOld = behaviorLib.HarassHeroBehavior["Execute"]
behaviorLib.HarassHeroBehavior["Execute"] = HarassHeroExecuteOverride

-----------------------------
--	 Retreat execute	 --
-----------------------------

--Modelled after Pure`Light's Magebane custom retreat code.
--  this is a great function to override with using retreating skills, such as blinks, travels, stuns or slows.

function behaviorLib.CustomRetreatExecute(botBrain)
	bActionTaken = false

	local unitSelf = core.unitSelf
	local unitTarget = behaviorLib.heroTarget
	if unitTarget == nil or not unitTarget:IsValid() then
		return false
	end

	local vecMyPosition = unitSelf:GetPosition()       
	local vecTargetPosition = unitTarget:GetPosition()
	
	local nTargetDistanceSq = Vector3.Distance2DSq(vecMyPosition, vecTargetPosition)
	
	--Counting the enemies
	local tEnemies = core.localUnits["EnemyHeroes"]
	local nCount = 0

	local bCanSeeUnit = unitTarget and core.CanSeeUnit(botBrain, unitTarget)
	
	for id, unitEnemy in pairs(tEnemies) do
		if core.CanSeeUnit(botBrain, unitEnemy) then
			nCount = nCount + 1
		end
	end
	
	if unitSelf:GetHealthPercent() < .50 then
		local abilGargantuan = skills.abilGargantuan
		local abilEssence = skills.abilEssence
		local unitAlly = core.unitAllyHeroes
		local bCanSeeAlly = unitAlly and core.CanSeeAlly(botBrain, unitAlly)
		local abilFeint = skills.abilFeint
		-- BACK OFF!
		-- Use Gargantuan THEN Essence on SELF
		if bCanSeeUnit and abilGargantuan:CanActivate() and abilEssence:CanActivate() then
			bActionTaken = core.OrderAbility(botBrain, abilGargantuan)
			bActionTaken = core.OrderAbility(botBrain, abilEssence, unitSelf)
				
				if bActionTaken then
				object.bDefensiveGargantuan = true	-- Don't get aggressive if we're blinking away
				
				end
		-- If Essence is on Cooldown, use only Gargantuan
			elseif bCanSeeUnit and abilGargantuan:CanActivate() then
			bActionTaken = core.OrderAbility(botBrain, abilGargantuan)
				
				if bActionTaken then
				object.bDefensiveGargantuan = true	-- Don't get aggressive if we're blinking away
				
				end
			
		end
		if abilFeint:CanActivate() and bCanSeeAlly
			bActionTaken = core.OrderAbility(botBrain, abilFeint, unitAlly)
	end

	return bActionTaken
end

BotEcho('finished loading shadowblade_main')
