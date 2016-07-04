--Pandamonium Bot v0.1
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

BotEcho('loading panda_main...')

--------------------------------
-- Lanes
--------------------------------
core.tLanePreferences = {Jungle = 0, Mid = 5, ShortSolo = 3, LongSolo = 2, ShortSupport = 1, LongSupport = 1, ShortCarry = 5, LongCarry = 3}
-- Jungle 0 -> Cannot jungle
-- Mid 5 -> Panda is a srong hero in 1v1 situations
-- ShortSolo 3 -> Can solo a lane because of the Cannon Ball escape
-- LongSolo 2 -> Can solo long lane because of the Warp ability (1st skill point goes in escape), but is not recommended since he is carry
-- ShortSupport 1 -> Can support with his disable skills, but is not recommended since he is carry
-- LongSupport 3 -> Can support with his disable skills, but is not recommended since he is carry
-- ShortCarry 5 -> Highly recommended to go short lane to farm
-- LongCarry 3 -> Can go carry on the long lane with a support because of the Cannon Ball escape

object.heroName = 'Hero_Panda'

----------------------------------
--	Panda items
----------------------------------
--[[ list code:
	"# Item" is "get # of these"
	"Item #" is "get this level of the item" --]]
behaviorLib.StartingItems = {"Item_Scarab", "2 Item_RunesOfTheBlight", "Item_ManaPotion"}  -- Items: Scarab, 2x Runes Of The Blight, Mana Potion
behaviorLib.LaneItems = {"Item_Marchers", "Item_Insanitarius", "Item_EnhancedMarchers"}    -- Items: Marchers, Insanitarius, Upg. Ghost Marchers
behaviorLib.MidItems = {"Item_PortalKey", "Item_Pierce 3"} 								   -- Items: Portal Key, Shield Breaker Lvl 3
behaviorLib.LateItems = {"Item_Protect", "Item_DaemonicBreastplate"} 					   -- Items: Null Stone, Daemonic Breastplate

--------------------------------
-- Skills
--------------------------------
local bSkillsValid = false
object.tSkills = {
    2, 1, 0, 1, 1, 3,	-- Levels 1-6 -> start with escape ability, max Flick for - armor resulting in higher dmg with Ultimate and 1 point in Flurry and 1 point in Ultimate
	1, 0, 0, 0, 3,     -- Levels 7-11 -> finish maxing Flick, max out Flurry, then 2nd lvl Ultimate
	2, 2, 2, 4, 3,     -- Levels 12-16 -> finish maxing Cannon Ball, then 3rd lvl Ultimate
	4, 4, 4, 4, 4, 4, 4, 4, 4,	-- Levels 17-25 -> Attribute Points
}
function object:SkillBuild()

	local unitSelf = self.core.unitSelf

	if not bSkillsValid then
		skills.abilFlurry = unitSelf:GetAbility(0)   -- 1st Skill -> Flurry
		skills.abilFlick = unitSelf:GetAbility(1)  -- 2nd Skill -> Flick
		skills.abilCannonBall = unitSelf:GetAbility(2)  -- 3rd Skill -> Cannon Ball
		skills.abilFaceSmash = unitSelf:GetAbility(3)  -- Ultimate -> Face Smash
		
		if skills.abilFlurry and skills.abilFlick and skills.abilCannonBall and skills.abilFaceSmash then
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
--	Panda specific harass bonuses
--
--  Abilities off cd increase harass util
--
--  Ability use increases harass util for a time
----------------------------------

object.nFlurryUp = 8
object.nFlickUp = 12
object.nCannonBallUp = 5
object.nFaceSmashUp = 10

object.nFlurryUse = 15
object.nFlickUse = 5
object.nCannonBallUse = 10
object.nFaceSmashUse = 10



--Panda abilities use gives bonus to harass util for a while

function object:oncombateventOverride(EventData)
	self:oncombateventOld(EventData)
	
	local addBonus = 0
	if EventData.Type == "Ability" then
		
		if EventData.InflictorName == "Ability_Panda1" then  -- Using Flurry will add bonus points to harass util
			addBonus = addBonus + object.nFlurryUse
		end
		if EventData.InflictorName == "Ability_Panda2" then  -- Using Flick will add bonus points to harass util
			addBonus = addBonus + object.nFlickUse
		end
		if EventData.InflictorName == "Ability_Panda3" then  -- Using Cannon Ball will add bonus points to harass util
			addBonus = addBonus + object.nCannonBallUse
		end
		if EventData.InflictorName == "Ability_Panda4" then  -- Using Face Smash will add bonus points to harass util
			addBonus = addBonus + object.nFaceSmashUse
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
	
	if skills.abilFlurry:CanActivate() then
		nUtility = nUtility + object.nFlurryUp         -- Flurry off CD will add bonus harass util
	end
	if skills.abilFlick:CanActivate() then
		nUtility = nUtility + object.nFlickUp          -- Flick off CD will add bonus harass util
	end
	if skills.abilCannonBall:CanActivate() then
		nUtility = nUtility + object.nCannonBallUp     -- Cannon Ball off CD will add bonus harass util
	end
	if skills.abilFaceSmash:CanActivate() then
		nUtility = nUtility + object.nFaceSmashUp      -- Face Smash off CD will add bonus harass util
	end
	return nUtility
end
behaviorLib.CustomHarassUtility = CustomHarassUtilityOverride   


----------------------------------
--	Panda harass actions
----------------------------------
local function HarassHeroExecuteOverride(botBrain)
	local bDebugEchos = false
		
	local unitSelf = core.unitSelf
	local unitTarget = behaviorLib.heroTarget 
	
	local bActionTaken = false
	
	local nDistSq = Vector3.Distance2DSq(unitSelf:GetPosition(), unitTarget:GetPosition())
	local vecTargetPosition = unitTarget:GetPosition()
	local nLastHarassUtility = behaviorLib.lastHarassUtil
	local bCanSee = core.CanSeeUnit(botBrain, unitTarget)
	local itemPortalKey = core.GetItem("Item_PortalKey")
	local nMyExtraRange = core.GetExtraRange(unitSelf)
	
	
	--since we are using an old pointer, ensure we can still see the target for entity targeting
	if unitTarget ~= nil then 
		
		-- Portal Key -- Used only if Ultimate isn't channeling
		if bCanSee and itemPortalKey and itemPortalKey:CanActivate() and not unitTarget:HasState("State_Panda_Ability4") and not unitSelf:HasState("State_Panda_Ability4") then   
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

		
		

	
		--	1st Skill -> Flurry -- Used only if Ultimate isn't channeling
		if not bActionTaken and not unitTarget:HasState("State_Panda_Ability4") and not unitSelf:HasState("State_Panda_Ability4")  then   -- Don't use skill while ult is channeling
				local abilFlurry = skills.abilFlurry
				if abilFlurry:CanActivate() and nDistSq < 190 * 190 then
					core.OrderMoveToUnitClamp(botBrain, unitSelf, unitTarget)              -- Go towards the enemy hero to face him
					bActionTaken = core.OrderAbility(botBrain, abilFlurry)				   -- Then use Flurry
				end
		end
		
		-- 2nd Skill -> Flick -- Used only if Ultimate isn't channeling
		if not bActionTaken and not unitTarget:HasState("State_Panda_Ability4") and not unitSelf:HasState("State_Panda_Ability4") then    -- Don't use skill while ult is channeling
			local abilFlick = skills.abilFlick
			if abilFlick:CanActivate() and nDistSq < 350 * 350 then
				bActionTaken = core.OrderAbilityEntity(botBrain, abilFlick, unitTarget)
			end
		end
		
		-- 3rd Skill -> Cannon Ball -- Used only if Ultimate isn't channeling
		if not bActionTaken and not unitTarget:HasState("State_Panda_Ability4") and not unitSelf:HasState("State_Panda_Ability4") then    -- Don't use skill while ult is channeling
			local abilCannonBall = skills.abilCannonBall
			if abilCannonBall:CanActivate() and nDistSq < 600 * 600 then
				bActionTaken = core.OrderAbilityPosition(botBrain, abilCannonBall, unitTarget:GetPosition())
			end
		end

		-- Ultimate -> Face Smash
		if not bActionTaken then
			local abilFaceSmash = skills.abilFaceSmash
			local itemInsanitarius = core.GetItem("Item_Insanitarius")
			if abilFaceSmash:CanActivate() then
				bActionTaken = core.OrderAbilityEntity(botBrain, abilFaceSmash, unitTarget)
				if itemInsanitarius and itemInsanitarius:CanActivate() and unitTarget:HasState("State_Panda_Ability4") and unitSelf:HasState("State_Panda_Ability4") then  -- Activate Insanitarius while ult is channeling
					bActionTaken = core.OrderItem(botBrain, itemInsanitarius)
				end
			end
		end
		
		if itemInsanitarius and itemInsanitarius:CanActivate() and not unitTarget:HasState("State_Panda_Ability4") and not unitSelf:HasState("State_Panda_Ability4") then  -- Deactivate Insanitarius if ult is not channeling
			bActionTaken = core.OrderItem(botBrain, itemInsanitarius)
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
--this is a great function to override with using retreating skills, such as blinks, travels, stuns or slows.

-- Blink code taken from ChronosBot - Works really well with Cannon Ball

function behaviorLib.CustomReturnToWellExecute(botBrain)
	local itemPortalKey = core.GetItem("Item_PortalKey")
	local abilCannonBall = skills.abilCannonBall
	if itemPortalKey ~= nil and itemPortalKey:CanActivate() then
			return core.OrderBlinkItemToEscape(botBrain, unitSelf, itemPortalKey)
		else if abilCannonBall:CanActivate() then
			return core.OrderBlinkAbilityToEscape(botBrain, skills.abilCannonBall, true)
		     end
	end
end

--------------------------------------------
--          PushExecute Override          --
--------------------------------------------

--  Pushing code taken from MyrmidonBot and modified
--  Uses Flurry on creeps when pushing if he has more than 60% mana -- Cannon Ball is not using for pushing to keep it for escape

local function CustomPushExecuteFnOverride(botBrain)
	local bActionTaken = false
	local nMinimumCreeps = 3
	local unitSelf = core.unitSelf
	local abilFlurry = skills.abilFlurry
	
	if abilFlurry:CanActivate() and core.unitSelf:GetManaPercent() > 0.60 then
		local tCreeps = core.localUnits["EnemyCreeps"]
		local nNumberCreeps =  core.NumberElements(tCreeps)
		if nNumberCreeps >= nMinimumCreeps then
			local vecTarget = core.GetGroupCenter(tCreeps)
			core.OrderMoveToUnitClamp(botBrain, unitSelf, vecTarget)				-- Go towards the creeps
			bActionTaken = core.OrderAbility(botBrain, abilFlurry)					-- Then Use Flurry
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


BotEcho('finished loading Panda_main')
