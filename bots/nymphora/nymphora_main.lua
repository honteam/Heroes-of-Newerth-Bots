
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

local sqrtTwo = math.sqrt(2)

BotEcho('loading nymphora_main...')

---------------
--  Globals  --
---------------
-- Constants --
---------------
--   items   --
---------------
core.tLanePreferences = {Jungle = 0, Mid = 1, ShortSolo = 1, LongSolo = 1, ShortSupport = 5, LongSupport = 5, ShortCarry = 1, LongCarry = 1}

behaviorLib.StartingItems = 
	{"Item_TrinketOfRestoration", "Item_MinorTotem", "Item_ManaPotion", "Item_CrushingClaws"}
behaviorLib.LaneItems = 
	{"Item_Marchers", "Item_MysticPotpourri", "Item_EnhancedMarchers"}
behaviorLib.MidItems = 
	{"Item_Astrolabe", "Item_Morph", "Item_FrostfieldPlate"}
behaviorLib.LateItems = 
	{"Item_Intelligence7", "Item_Summon"} --Intelligence7 is Staff of the Master


----------------
-- Thresholds --
----------------
object.stunThreshold = 35





--------------------
-- For skillbuild --
--------------------
object.manaNeeded = 0
object.healNeeded = 0

--------------
-- For heal --
--------------
object.healPos = nil
object.healLastCastTime = -20000

function object:SkillBuild()
	local unitSelf = self.core.unitSelf

	if skills.heal == nil then
		skills.heal		= unitSelf:GetAbility(0)
		skills.mana		= unitSelf:GetAbility(1)
		skills.stun		= unitSelf:GetAbility(2)
		skills.teleport	= unitSelf:GetAbility(3)
		skills.recall	= unitSelf:GetAbility(5)
	end

	if unitSelf:GetAbilityPointsAvailable() <= 0 then
		return
	end

	for i = 0, unitSelf:GetAbilityPointsAvailable(), 1 do
		bAbilityLeveled = false
		core.AllChat(self.healNeeded .. " " .. self.manaNeeded)
		if skills.teleport:CanLevelUp() then
			skills.teleport:LevelUp()
		else
			if (self.healNeeded > 1 and skills.heal:CanLevelUp()) or (self.manaNeeded > 1 and skills.mana:CanLevelUp()) or
				(not skills.stun:CanLevelUp() and (skills.heal:CanLevelUp() or skills.mana:CanLevelUp())) then
				if self.healNeeded > self.manaNeeded and skills.heal:CanLevelUp() then
					skills.heal:LevelUp()
					bAbilityLeveled = true
					self.healNeeded = self.healNeeded - 1
				else
					skills.mana:LevelUp()
					bAbilityLeveled = true
					self.manaNeeded = self.manaNeeded - 1
				end
			elseif skills.stun:CanLevelUp() then
				skills.stun:LevelUp()
				bAbilityLeveled = true
			end
		end
		if not bAbilityLeveled then
			unitSelf:GetAbility(4):LevelUp()
		end
	end
end


function useHeal(botBrain, pos)
	object.healLastCastTime = HoN.GetGameTime()
	object.healPos = pos
	return core.OrderAbilityPosition(botBrain, skills.heal, pos)
end



behaviorLib.SupportBehavior = {}

-- Base 10
-- 0.5 for every missing % of hp or mana
-- Max 60 at 0% of hp or mana
function behaviorLib.SupportUtility(botBrain)
	local unitSelf = core.unitSelf

	local localUnits = core.localUnits
	local allyHeroes = core.CopyTable(localUnits.AllyHeroes)
	allyHeroes[unitSelf:GetUniqueID()] = unitSelf

	local sType = ""
	local nUtility = 0
	local unitTarget = {}

	local canGiveMana = skills.mana:CanActivate()
	local canHeal = skills.heal:CanActivate()

	for _, hero in pairs(allyHeroes) do
		local mana = hero:GetManaPercent()
		object.manaNeeded = object.manaNeeded + (1 - mana) / 200
		local newUtility = 10 + (1 - mana) * 100 / 2
		if canGiveMana and newUtility > nUtility then
			nUtility = newUtility
			sType = "mana"
			unitTarget = hero
		end

		local hp = hero:GetHealthPercent()
		object.healNeeded = object.healNeeded + (1 - hp) / 200
		local newUtility = 10 + (1 - hp) * 100 / 2
		if canHeal and newUtility > nUtility then
			nUtility = newUtility
			sType = "heal"
			unitTarget = hero
		end
	end
	behaviorLib.SupportBehavior.sType = sType
	behaviorLib.SupportBehavior.target = unitTarget
	return nUtility

end

function behaviorLib.SupportExecute(botBrain)
	if behaviorLib.SupportBehavior.sType == "mana" then
		return core.OrderAbilityEntity(botBrain, skills.mana, behaviorLib.SupportBehavior.target)
	end
	if behaviorLib.SupportBehavior.sType == "heal" then
		local unitTarget = behaviorLib.SupportBehavior.target
		local vecTargetPos = unitTarget:GetPosition() + unitTarget:GetHeading() * unitTarget:GetMoveSpeed() * 3 / 4
		return useHeal(botBrain, behaviorLib.SupportBehavior.target:GetPosition())
	end

	return false
end

behaviorLib.SupportBehavior["Utility"] = behaviorLib.SupportUtility
behaviorLib.SupportBehavior["Execute"] = behaviorLib.SupportExecute
behaviorLib.SupportBehavior["Name"] = "Nymphora supprot"
tinsert(behaviorLib.tBehaviors, behaviorLib.SupportBehavior)

-----------
-- Fight --
-----------
function HarassHeroExecuteOverride(botBrain)
	local unitTarget = behaviorLib.heroTarget
	if unitTarget == nil or not unitTarget:IsValid() then
		return false --can not execute, move on to the next behavior
	end
	
	local unitSelf = core.unitSelf
	local vecMyPosition = unitSelf:GetPosition()
	local nMyExtraRange = core.GetExtraRange(unitSelf)
	
	local vecTargetPosition = unitTarget:GetPosition()
	local nTargetExtraRange = core.GetExtraRange(unitTarget)
	local nTargetDistanceSq = Vector3.Distance2DSq(vecMyPosition, vecTargetPosition)
	local bTargetRooted = unitTarget:IsStunned() or unitTarget:IsImmobilized() or unitTarget:GetMoveSpeed() < 200
	
	local nLastHarassUtil = behaviorLib.lastHarassUtil
	local bCanSee = core.CanSeeUnit(botBrain, unitTarget)

	local vecPosInHalfSec = vecTargetPosition
	if bCanSee then
		local vecPosInHalfSec = vecTargetPosition + unitTarget:GetHeading() * unitTarget:GetMoveSpeed() / 2
	end

	local bActionTaken = false

	if nLastHarassUtil > object.stunThreshold and skills.stun:CanActivate() then
		bActionTaken = core.OrderAbilityPosition(botBrain, skills.stun, vecPosInHalfSec)
	end
	if not bActionTaken then
		if skills.heal:CanActivate() then
			bActionTaken = useHeal(botBrain, vecPosInHalfSec)
		end
	end

	if not bActionTaken then
		return object.harassExecuteOld(botBrain)
	end
end
object.harassExecuteOld = behaviorLib.HarassHeroBehavior["Execute"]
behaviorLib.HarassHeroBehavior["Execute"] = HarassHeroExecuteOverride

------------
-- Escape --
------------
function behaviorLib.CustomRetreatExecute(botBrain)
	local unitSelf = core.unitSelf
	local myPos = unitSelf:GetPosition()

	local bActionTaken = false

	if behaviorLib.lastRetreatUtil > object.stunThreshold and skills.stun:CanActivate() then
		if core.NumberElements(core.localUnits.EnemyHeroes) > 0 then
			local unitTarget = nil
			local closestDistance = 999999999
			for _, unit in pairs(core.localUnits.EnemyHeroes) do
				local Distance2DSq = Vector3.Distance2DSq(myPos, unit:GetPosition())
				if Distance2DSq < closestDistance then
					unitTarget = unit
					closestDistance = Distance2DSq
				end
			end

			bActionTaken = core.OrderAbilityPosition(botBrain, skills.stun, unitTarget:GetPosition())
		end
	end

	return bActionTaken
end

function behaviorLib.customPushExecute(botBrain)
	local unitSelf = core.unitSelf
	
	bActionTaken = false

	if unitSelf:GetManaPercent() > 0.7 then
		local centerOfCreeps = core.AoETargeting(unitSelf, skills.heal:GetRange(), 300, true, nil, nil, nil)
		if skills.heal:CanActivate() then
			bActionTaken = useHeal(botBrain, centerOfCreeps)
		end
		if not bActionTaken then
			if skills.stun:CanActivate() then
				bActionTaken = core.OrderAbilityPosition(botBrain, skills.stun, centerOfCreeps)
			end
		end
	end

	return bActionTaken
end

-- Walk to own heal
function behaviorLib.getHealedUtility(botBrain)
	local time = HoN.GetGameTime()
	if time - 1100 < object.healLastCastTime then
		local unitSelf = core.unitSelf
		if unitSelf:GetHealthPercent() < 0.95 then
			local distance = Vector3.Distance2D(unitSelf:GetPosition(), object.healPos) - 300
			if distance < unitSelf:GetMoveSpeed() * (time - object.healLastCastTime) / 1000 then
				return 40
			end
		end
	end
	return 0
end

function behaviorLib.getHealedExecute(botBrain)
	return core.OrderMoveToPos(botBrain, core.unitSelf, object.healPos)
end

behaviorLib.getHealedBehavior["Utility"] = behaviorLib.getHealedUtility
behaviorLib.getHealedBehavior["Execute"] = behaviorLib.getHealedExecute
behaviorLib.getHealedBehavior["Name"] = "Nymphora get healed"
tinsert(behaviorLib.tBehaviors, behaviorLib.getHealedBehavior)
