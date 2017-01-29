--PrisonerBot v0.1
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

local tBottle = {}

BotEcho('loading prisoner_main...')

--------------------------------
-- Lanes
--------------------------------
core.tLanePreferences = {Jungle = 0, Mid = 3, ShortSolo = 1, LongSolo = 0, ShortSupport = 3, LongSupport = 3, ShortCarry = 2, LongCarry = 1}

object.heroName = 'Hero_Prisoner'

----------------------------------
--	Prisoner items
----------------------------------
--[[ list code:
	"# Item" is "get # of these"
	"Item #" is "get this level of the item" --]]
behaviorLib.StartingItems = {"Item_LoggersHatchet", "Item_IronBuckler", "Item_RunesOfTheBlight"} -- Items: Logger's Hatchet, Iron Buckler, Runes of Blight
behaviorLib.LaneItems = {"Item_Bottle", "Item_Marchers", "Item_Steamboots", "Item_ElderParasite"} -- Items: Marchers, Steamboots, Elder Parasite
behaviorLib.MidItems = {"Item_Insanitarius", "Item_Immunity" } -- Items: Insanitarius, Shrunken Head
behaviorLib.LateItems = {"Item_SolsBulwark", "Item_DaemonicBreastplate", "Item_BehemothsHeart"} -- Items: Sol's Bulwark, Daemonic Breastplate, Behemoth's Heart

--------------------------------
-- Skills
--------------------------------
local bSkillsValid = false
object.tSkills = {
    0, 1, 0, 1, 	-- Levels 1-4 -> Max Hook and Shackle
	0, 3, 0, 1,     -- Levels 5-8 -> Then lvl Ultimate at lvl 6
	1, 2, 3, 2,     -- Levels 9-12 -> then level the passive Riot skill
	2, 2, 4, 		-- Levels 13-15 -> 
	3, 4, 4, 4, 4, 4, 4, 4, 4, 4,	-- Levels 17-25 -> Attribute Points
}
function object:SkillBuild()

	local unitSelf = self.core.unitSelf

	if not bSkillsValid then
		skills.abilHook = unitSelf:GetAbility(0)   -- 1st Skill -> The Ol' Ball and Chain -> Hook
		skills.abilShackle = unitSelf:GetAbility(1)  -- 2nd Skill -> Shackle
		skills.abilPrisonBreak = unitSelf:GetAbility(3)  -- Ultimate -> Prison Break
		
		if skills.abilHook and skills.abilShackle and skills.abilRiot and skills.abilPrisonBreak then
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
--	Prisoner specific harass bonuses
--
--  Abilities off cd increase harass util
--
--  Ability use increases harass util for a time
----------------------------------

object.nHookUp = 15
object.nShackleUp = 10
object.nPrisonBreakUp = 25

object.nHookUse = 15
object.nShackleUse = 5
object.nPrisonBreakUse = 10



--Prisoner abilities use gives bonus to harass util for a while
function object:oncombateventOverride(EventData)
	self:oncombateventOld(EventData)
	
	local addBonus = 0
	if EventData.Type == "Ability" then
		
		if EventData.InflictorName == "Ability_Prisoner1" then  -- Using Hook will add bonus points to harass util
			addBonus = addBonus + object.nHookUse
		end
		if EventData.InflictorName == "Ability_Prisoner2" then  -- Using Shackle will add bonus points to harass util
			addBonus = addBonus + object.nShackleUse
		end
		if EventData.InflictorName == "Ability_Prisoner4" then  -- Using Prison Break will add bonus points to harass util
			addBonus = addBonus + object.nPrisonBreakUse
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
	
	if skills.abilHook:CanActivate() then
		nUtility = nUtility + object.nHookUp  -- Hook off CD will add bonus harass util
	end
	if skills.abilShackle:CanActivate() then
		nUtility = nUtility + object.nShackleUp   -- Shackle off CD will add bonus harass util
	end
	if skills.abilPrisonBreak:CanActivate() then
		nUtility = nUtility + object.nPrisonBreakUp    -- Prison Break off CD will add bonus harass util
	end
	return nUtility
end
behaviorLib.CustomHarassUtility = CustomHarassUtilityOverride   

---HOOK LOGIC
local tRelativeMovements = {}
local function createRelativeMovementTable(sKey)
	--BotEcho('Created a relative movement table for: '..key)
	tRelativeMovements[sKey] = {
		vecLastPos = Vector3.Create(),
		vecRelMov = Vector3.Create(),
		nTimestamp = 0
	}
--	BotEcho('Created a relative movement table for: '..tRelativeMovements[sKey].nTimestamp)
end

createRelativeMovementTable("HookField") -- for landing Hook

-- tracks movement for targets based on a list, so its reusable
-- sKey is the identifier for different uses (fe. RaMeteor for his path of destruction)
-- vecTargetPos should be passed the targets position of the moment
-- to use this for prediction add the vector to a units position and multiply it
-- the function checks for 100ms cycles so one second should be multiplied by 20
local function relativeMovement(sKey, vecTargetPos)
	local bDebugEchoes = false

	local nGameTime = HoN.GetGameTime()
	local vecLastPos = tRelativeMovements[sKey].vecLastPos
	local nTS = tRelativeMovements[sKey].nTimestamp
	local nTimeDiff = nGameTime - nTS

	if bDebugEchoes then
		BotEcho('Updating relative movement for key: '..sKey)
		BotEcho('Relative Movement position: '..vecTargetPos.x..' | '..vecTargetPos.y..' at timestamp: '..nTS)
		BotEcho('Relative lastPosition is this: '..vecLastPos.x)
	end

	if nTimeDiff >= 90 and nTimeDiff <= 140 then -- 100 should be enough (every second cycle)
		local vecRelativeMov = vecTargetPos-vecLastPos

		if vecTargetPos.LengthSq > vecLastPos.LengthSq	then
			vecRelativeMov =  vecRelativeMov*-1
		end

		tRelativeMovements[sKey].vecRelMov = vecRelativeMov
		tRelativeMovements[sKey].vecLastPos = vecTargetPos
		tRelativeMovements[sKey].nTimestamp = nGameTime


		if bDebugEchoes then
			BotEcho('Relative movement -- x: '..vecRelativeMov.x..' y: '..vecRelativeMov.y)
			BotEcho('^r---------------Return new-'..tRelativeMovements[sKey].vecRelMov.x)
		end

		return vecRelativeMov
	elseif nTimeDiff >= 150 then
		tRelativeMovements[sKey].vecRelMov =  Vector3.Create(0,0)
		tRelativeMovements[sKey].vecLastPos = vecTargetPos
		tRelativeMovements[sKey].nTimestamp = nGameTime
	end

	if bDebugEchoes then BotEcho('^g---------------Return old-'..tRelativeMovements[sKey].vecRelMov.x) end
	return tRelativeMovements[sKey].vecRelMov
end
----------------------------------
--	Prisoner harass actions
----------------------------------
local function HarassHeroExecuteOverride(botBrain)
	local bDebugEchos = false
		
	local unitSelf = core.unitSelf
	local unitTarget = behaviorLib.heroTarget 
	if unitTarget == nil then
		return object.harassExecuteOld(botBrain)
	end
	local vecMyPosition = unitSelf:GetPosition()
	local bActionTaken = false
	local vecTargetPosition = unitTarget:GetPosition()
	local nTargetDistanceSq = Vector3.Distance2DSq(vecMyPosition, vecTargetPosition)
	local nLastHarassUtility = behaviorLib.lastHarassUtil
	local bCanSeeTarget = core.CanSeeUnit(botBrain, unitTarget)
	local nMyExtraRange = core.GetExtraRange(unitSelf)
	local vecRelativeMov = relativeMovement("HookField", vecTargetPosition) * 5 --updating every 100ms
	--damage stealth illusion movespeed regen
	local runeInBottle = tBottle.getRune()
	if runeInBottle == "damage" or runeInBottle == "illusion" or runeInBottle == "movespeed" then
		botBrain:OrderItem(core.GetItem("Item_Bottle"))
	end
	
	--since we are using an old pointer, ensure we can still see the target for entity targeting
	if unitTarget ~= nil then 
		
		
		
		
		-- 1st Skill -> Hook
		local abilHook = skills.abilHook
		local bDebugEchoes = false
		if abilHook:CanActivate() then
			local nRange = abilHook:GetRange()
			local vecTargetPredictPosition = vecTargetPosition + vecRelativeMov
			if Vector3.Distance2DSq(vecMyPosition, vecTargetPredictPosition) < nRange * nRange then
				bActionTaken = core.OrderAbilityPosition(botBrain, abilHook, vecTargetPredictPosition)
				if bDebugEchoes then
						BotEcho("Casting HOOK!")
				end
			end
		end

		if bDebugEchoes then
			local nRange = abilHook:GetRange()
			core.DrawXPosition(vecTargetPosition + vecRelativeMov, 'red', 100) --vecTargetPredictPosition
			core.DrawDebugArrow(vecTargetPosition, vecTargetPosition + vecRelativeMov, 'red') --predicted target movement path
			core.DrawDebugArrow(vecMyPosition, vecMyPosition + (Vector3.Normalize((vecTargetPosition + vecRelativeMov) - vecMyPosition)) * nRange, 'green') --weed field range aimed at predicted position
		end


		
		-- 2nd Skill -> Shackle
		if not bActionTaken then
			local abilShackle = skills.abilShackle
			if abilShackle:CanActivate() then
				local nRange = abilShackle:GetRange()
				if nTargetDistanceSq < (nRange * nRange) then
					bActionTaken = core.OrderAbilityEntity(botBrain, abilShackle, unitTarget)
				end
			end
		end
		
		-- Ultimate -> Prison Break
		if not bActionTaken then
			local abilPrisonBreak = skills.abilPrisonBreak
			if abilPrisonBreak:CanActivate() then
				if nTargetDistanceSq < (550 * 550) then
					bActionTaken = core.OrderAbility(botBrain, abilPrisonBreak)
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


--------------------------------------------
--          PushExecute Override          --
--------------------------------------------

--  Pushing code taken from MyrmidonBot and modified
--  Uses Hook on creeps when pushing if he has more than 60% mana

local function CustomPushExecuteFnOverride(botBrain)
	local bActionTaken = false
	local nMinimumCreeps = 3

	local abilHook = skills.abilHook
	if abilHook:CanActivate() and core.unitSelf:GetManaPercent() > 0.60 then
		local tCreeps = core.localUnits["EnemyCreeps"]
		local nNumberCreeps =  core.NumberElements(tCreeps)
		if nNumberCreeps >= nMinimumCreeps then
			local vecTarget = core.GetGroupCenter(tCreeps)
			bActionTaken = core.OrderAbilityPosition(botBrain, abilHook, vecTarget)
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

-- Change default behaviors if we have rune
function behaviorLib.newUseBottleBehaviorUtility(botBrain)
	if core.unitSelf:HasState("State_PowerupRegen") or core.unitSelf:HasState("State_PowerupStealth") then
		return 0
	end

	nUtility = behaviorLib.oldUseBottleBehaviorUtility(botBrain)
	if tBottle.getRune() == "regen" then
		nUtility = nUtility * 0.8
	end
	return nUtility
end

behaviorLib.oldUseBottleBehaviorUtility = behaviorLib.tItemBehaviors["Item_Bottle"]["Utility"]
behaviorLib.tItemBehaviors["Item_Bottle"]["Utility"] = behaviorLib.newUseBottleBehaviorUtility

function behaviorLib.newAttackCreepsUtility(botBrain)
	if  core.unitSelf:HasState("State_PowerupStealth") then
		return 0
	end

	return behaviorLib.oldAttackCreepsUtility(botBrain)
end
behaviorLib.oldAttackCreepsUtility = behaviorLib.AttackCreepsBehavior["Utility"]
behaviorLib.AttackCreepsBehavior["Utility"] = behaviorLib.newAttackCreepsUtility

function behaviorLib.newattackEnemyMinionsUtility(botBrain)
	if  core.unitSelf:HasState("State_PowerupStealth") then
		return 0
	end

	return behaviorLib.oldattackEnemyMinionsUtility(botBrain)
end
behaviorLib.oldattackEnemyMinionsUtility = behaviorLib.attackEnemyMinionsBehavior["Utility"]
behaviorLib.attackEnemyMinionsBehavior["Utility"] = behaviorLib.newattackEnemyMinionsUtility

---------------------------
-- Override rune picking --
---------------------------
function behaviorLib.newPickRuneUtility(botBrain)
	local rune = core.teamBotBrain.GetNearestRune(core.unitSelf:GetPosition())
	if rune == nil then
		return 0
	end

	behaviorLib.runeToPick = rune

	local nUtility = 25

	if rune.unit then
		nUtility = nUtility + 10
	end

	if core.GetItem("Item_Bottle") ~= nil then
		nUtility = nUtility + 20 - tBottle.getCharges() * 5
	end

	return nUtility - Vector3.Distance2DSq(rune.vecLocation, core.unitSelf:GetPosition())/(2000*2000)
end
behaviorLib.PickRuneBehavior["Utility"] = behaviorLib.newPickRuneUtility

function behaviorLib.newPickRuneExecute(botBrain)
	bActionTaken = false
	if tBottle.getCharges() > 0 and behaviorLib.newUseBottleBehaviorUtility(botBrain) > 0 then
		botBrain:OrderItem(core.GetItem("Item_Bottle").object)
	end

	if not bActionTaken then
		itemPortalKey = core.GetItem("Item_PortalKey")
		if itemPortalKey ~= nil and itemPortalKey:CanActivate() then
			botBrain:OrderItemPosition(itemPortalKey.object, behaviorLib.GetSafeBlinkPosition(behaviorLib.runeToPick.vecLocation, 1200))
			bActionTaken = true
		end
	end

	if not bActionTaken then
		bActionTaken = behaviorLib.pickRune(botBrain, behaviorLib.runeToPick)
	end
	return bActionTaken
end

behaviorLib.PickRuneBehavior["Execute"] = behaviorLib.newPickRuneExecute

----------------
--    Misc    --
----------------

------------------------
-- helpers for bottle --
------------------------

function tBottle.getCharges()
	local itemBottle = core.GetItem("Item_Bottle")
	if itemBottle == nil then
		return 0
	end

	local nCharges = nil
	local modifier = itemBottle:GetActiveModifierKey()
	if modifier == "bottle_empty" then
		nCharges = 0
	elseif modifier == "bottle_1" then
		nCharges = 1
	elseif modifier == "bottle_2" then
		nCharges = 2
	elseif modifier == "bottle_3" then
		nCharges = 3
	else
		nCharges = 4 --rune
	end
	return nCharges
end

--damage stealth illusion movespeed regen
function tBottle.getRune()
	local itemBottle = core.GetItem("Item_Bottle")
	if itemBottle == nil then
		return ""
	end
	local modifier = itemBottle:GetActiveModifierKey()
	local sKey = string.gmatch(modifier, "bottle_%w")
	if sKey == "1" or sKey == "2" or sKey == "3" or sKey =="empty" then
		return ""
	else
		return sKey
	end
end


BotEcho('finished loading prisoner_main')
