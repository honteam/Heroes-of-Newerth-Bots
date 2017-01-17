--Emerald Warden Bot v0.1
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

BotEcho('loading warden_main...')

--------------------------------
-- Lanes
--------------------------------
core.tLanePreferences = {Jungle = 0, Mid = 5, ShortSolo = 0, LongSolo = 0, ShortSupport = 0, LongSupport = 0, ShortCarry = 5, LongCarry = 3}
-- Jungle 0 -> Cannot jungle
-- Mid 5 -> Easier to farm vs one hero
-- ShortSolo 0 -> Cannot solo because it has no good escape skill
-- LongSolo 0 -> Cannot solo because it has no good escape skill
-- ShortSupport 0 -> Cannot provide good support
-- LongSupport 0 -> Cannot provide good support
-- ShortCarry 5 -> Well...EW IS a carry...
-- LongCarry 3 -> Better played Carry on Short lane than long

object.heroName = 'Hero_EmeraldWarden'

----------------------------------
--	Warden items
----------------------------------
--[[ list code:
	"# Item" is "get # of these"
	"Item #" is "get this level of the item" --]]
behaviorLib.StartingItems = {"Item_HealthPotion", "Item_RunesOfTheBlight", "2 Item_ManaPotion", "Item_GuardianRing"} -- Items: Health Potion, Runes Of The Blight, 2 x Mana Potions, Guardian Ring
behaviorLib.LaneItems = {"Item_Marchers", "Item_EnhancedMarchers"} 													 -- Items: Marchers -> Ghost Marchers
behaviorLib.MidItems = {"Item_Protect", "Item_ArclightCrown", "Item_Critical1 4" } 									 -- Items: Null Stone, Arclight Crown, Riftshards Lvl 4
behaviorLib.LateItems = {"Item_LifeSteal4", "Item_Evasion"} 														 -- Items: Symbol Of Rage, Wingbow

--------------------------------
-- Skills
--------------------------------
local bSkillsValid = false
object.tSkills = {
    1, 0, 1, 2, 	-- Levels 1-4 -> Max Wolves skill for dmg output with one point in Silence and one point in Overgrowth for escape
	1, 3, 1, 0,     -- Levels 5-8 -> Then continue with maxing Silence
	0, 0, 3, 2,     -- Levels 9-12 -> Then finish maxing Overgrowth
	2, 2, 4, 		-- Levels 13-15 -> 
	3, 4, 4, 4, 4, 4, 4, 4, 4, 4,	-- Levels 17-25 -> Attribute Points
}
function object:SkillBuild()

	local unitSelf = self.core.unitSelf

	if not bSkillsValid then
		skills.abilSilence = unitSelf:GetAbility(0)   -- 1st Skill -> Silencing Shot
		skills.abilWolves = unitSelf:GetAbility(1)  -- 2nd Skill -> Hunter's Command
		skills.abilOvergrowth = unitSelf:GetAbility(2)  -- 3rd Skill -> Overgrowth
		skills.abilGawain = unitSelf:GetAbility(3)  -- Ultimate -> Summon Gawain
		skills.abilStrike = unitSelf:GetAbility(5) -- Ultimate -> Strike
		skills.abilHeal = unitSelf:GetAbility(6) -- Ultimate -> Heal
		skills.abilStorm = unitSelf:GetAbility(7) -- Ultimate -> Storm
		
		if skills.abilSilence and skills.abilWolves and skills.abilOvergrowth and skills.abilGawain 
			and skills.abilStrike and skills.abilHeal and skills.abilStorm then
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
--	Emerald Warden specific harass bonuses
--
--  Abilities off cd increase harass util
--
--  Ability use increases harass util for a time
----------------------------------

object.nSilenceUp = 8
object.nWolvesUp = 12
object.nOvergrowthUp = 5
object.nStrikeUp = 10
object.nHealUp = 5
object.nStormUp = 5

object.nSilenceUse = 15
object.nWolvesUse = 10
object.nOvergrowthUse = 5

object.nSilenceThreshold = 30     -- Silence will be used 1st to stop the target from casting
object.nWolvesThreshold = 36      -- Wolves 2nd for slow
object.nOvergrowthThreshold = 50            -- Followed by overgrowth at target location


--Emerald Warden abilities use gives bonus to harass util for a while
function object:oncombateventOverride(EventData)
	self:oncombateventOld(EventData)
	
	local addBonus = 0
	if EventData.Type == "Ability" then
		
		if EventData.InflictorName == "Ability_EmeraldWarden1" then  -- Using Silencing Shot will add bonus points to harass util
			addBonus = addBonus + object.nSilenceUse
		end
		if EventData.InflictorName == "Ability_EmeraldWarden2" then  -- Using Hunter's Command will add bonus points to harass util
			addBonus = addBonus + object.nWolvesUse
		end
		if EventData.InflictorName == "Ability_EmeraldWarden3" then  -- Using Overgrowth will add bonus points to harass util
			addBonus = addBonus + object.nOvergrowthUse
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
	
	if skills.abilSilence:CanActivate() then
		nUtility = nUtility + object.nSilenceUp  -- Silencing Shot off CD will add bonus harass util
	end
	if skills.abilWolves:CanActivate() then
		nUtility = nUtility + object.nWolvesUp   -- Hunter's Command off CD will add bonus harass util
	end
	if skills.abilOvergrowth:CanActivate() then
		nUtility = nUtility + object.nOvergrowthUp       -- Overgrowth off CD will add bonus harass util
	end
	if skills.abilStrike:CanActivate() then
		nUtility = nUtility + object.nStrikeUp    -- Gawain has low CD, and will make EW more aggresive when is off CD
	end
	if skills.abilHeal:CanActivate() then
		nUtility = nUtility + object.nHealUp    -- Gawain has low CD, and will make EW more aggresive when is off CD
	end
	if skills.abilStorm:CanActivate() then
		nUtility = nUtility + object.nStormUp    -- Gawain has low CD, and will make EW more aggresive when is off CD
	end
	return nUtility
end
behaviorLib.CustomHarassUtility = CustomHarassUtilityOverride   


----------------------------------
--	Emerald Warden harass actions
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
		
		-- Since all of Emerald Warden's skills are Magic Dmg, EW will use skill only when his target is NOT MAGIC IMMUNE
		
		-- Item: Symbol Of Rage -> Activates when EW is below 60% hp
		local bHealthLow = unitSelf:GetHealthPercent() < 0.60
		if not bActionTaken  and bHealthLow then
			local itemSymbol = core.GetItem("Item_LifeSteal4")
			if itemSymbol then
				if itemSymbol:CanActivate() then
						bActionTaken = core.OrderItem(botBrain, itemSymbol)
						behaviorLib.lastHarassUtil = behaviorLib.lastHarassUtil + 20   --  Increases aggresion so EW will activate Sybmol and attack not run
				end
			end
		end
		
		-- 1st Skill -> Silencing Shot on channeling target if target is NOT MAGIC IMMUNE
		if unitTarget:IsChanneling() and not bTargetMagicImmune  then
			local abilSilence = skills.abilSilence
			if abilSilence:CanActivate() then
				core.OrderAbilityEntity(botBrain, abilSilence, unitTarget)
			end
		end
		
		-- 2nd Skill -> Hunter's Command
		if not bTargetMagicImmune then
			if not bActionTaken then
				local abilWolves = skills.abilWolves
				if abilWolves:CanActivate() and behaviorLib.lastHarassUtil > object.nWolvesThreshold then
					bActionTaken = core.OrderAbility(botBrain, abilWolves)
				end
			end
		end
		
		-- 1st Skill -> Silencing Shot
		if not bTargetMagicImmune then
			if not bActionTaken then
				local abilSilence = skills.abilSilence
				if abilSilence:CanActivate() and behaviorLib.lastHarassUtil > object.nSilenceThreshold then
					bActionTaken = core.OrderAbilityEntity(botBrain, abilSilence, unitTarget)
				end
			end
		end
		
		-- 3rd Skill -> Overgrowth
		if not bTargetMagicImmune then
			if not bActionTaken then
				local abilOvergrowth = skills.abilOvergrowth
				if abilOvergrowth:CanActivate() and behaviorLib.lastHarassUtil > object.nOvergrowthThreshold then
					bActionTaken = core.OrderAbilityPosition(botBrain, abilOvergrowth, vecTargetPosition)
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
-- Return to well
-----------------------

-- Escape combo for running away

function behaviorLib.CustomRetreatExecute(botBrain)
	bActionTaken = false

	local unitSelf = core.unitSelf
	local unitSelfPosition = unitSelf:GetPosition()
	local unitTarget = behaviorLib.heroTarget
	local bCanSee = unitTarget and core.CanSeeUnit(botBrain, unitTarget)
	if unitTarget == nil or not unitTarget:IsValid() then
		return false --can not execute, move on to the next behavior
	end
	
	
	if bCanSee then
		local abilSilence = skills.abilSilence
		local abilWolves = skills.abilWolves
		local abilOvergrowth = skills.abilOvergrowth
		
		if not bActionTaken and abilSilence:CanActivate() then                                -- Use Silencing Shot if the enemy is visible
			bActionTaken = core.OrderAbilityEntity(botBrain, abilSilence, unitTarget)
		end
		if not bActionTaken and abilWolves:CanActivate() then                                 -- Use Hunter's Command after Silencing Shot
			bActionTaken = core.OrderAbility(botBrain, abilWolves)
		end
		if not bActionTaken and abilOvergrowth:CanActivate() then                             -- Use Overgrowth at Self current position to stop chasing enemies
			bActionTaken = core.OrderAbilityPosition(botBrain, abilOvergrowth, unitSelfPosition)
		end
	end
	return bActionTaken
end

--------------------------------------------
--          PushExecute Override          --
--------------------------------------------

--  Pushing code taken from MyrmidonBot and modified
--  Uses Overgrowth on creeps when pushing if he has more than 60% mana

local function CustomPushExecuteFnOverride(botBrain)
	local bActionTaken = false
	local nMinimumCreeps = 3

	local abilOvergrowth = skills.abilOvergrowth
	
	if abilOvergrowth:CanActivate() and core.unitSelf:GetManaPercent() > 0.60 then
		local tCreeps = core.localUnits["EnemyCreeps"]
		local nNumberCreeps =  core.NumberElements(tCreeps)
		if nNumberCreeps >= nMinimumCreeps then
			local vecTarget = core.GetGroupCenter(tCreeps)
			bActionTaken = core.OrderAbilityPosition(botBrain, abilOvergrowth, vecTarget)
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


BotEcho('finished loading warden_main')

