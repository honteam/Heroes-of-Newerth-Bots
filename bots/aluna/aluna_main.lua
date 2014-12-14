--AlunaBot v1

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

BotEcho('loading aluna_main...')

--------------------------------
-- Lanes
--------------------------------
core.tLanePreferences = {Jungle = 0, Mid = 3, ShortSolo = 4, LongSolo = 3, ShortSupport = 5, LongSupport = 4, ShortCarry = 3, LongCarry = 2}

object.heroName = 'Hero_Aluna'

----------------------------------
--	Aluna items
----------------------------------
--[[ list code:
	"# Item" is "get # of these"
	"Item #" is "get this level of the item" --]]
behaviorLib.StartingItems = {"Item_Scarab", "2 Item_RunesOfTheBlight", "Item_ManaPotion"}
behaviorLib.LaneItems = {"Item_Scarab", "Item_Steamboots", "Item_Silence"} --Item_Silence is hell flower
behaviorLib.MidItems = {"Item_Lightning2", "Item_Dawnbringer", "Item_Weapon3" } --Item_Lightning2 is charged hammer, Item_Weapon3 is savage mace, Item_Critical1 is riftshards
behaviorLib.LateItems = {"Item_Critical1 4", "Item_HarkonsBlade", "Item_Sasuke", "Item_Evasion"} --Item_Freeze is frostwolf, Item_Sasuke is Genjuro, Item_Evasion is wingbow

--------------------------------
-- Skills
--------------------------------
object.tSkills = {
    1, 0, 1, 2, 1, 3,	-- 1-6
	1, 0, 0, 0, 3, 		-- 7-11
	2, 2, 2, 4, 3,		-- 12-16
	4, 4, 4, 4, 4, 4, 4, 4, 4,	--17-25
}
function object:SkillBuild()

	local unitSelf = self.core.unitSelf

	if skills.abilEmeraldLightning == nil then
		skills.abilEmeraldLightning = unitSelf:GetAbility(0)
		skills.abilPowerThrow = unitSelf:GetAbility(1)
		skills.abilDejaVu = unitSelf:GetAbility(2)
		skills.abilEmeraldRed = unitSelf:GetAbility(3)
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
--	Aluna specific harass bonuses
--
--  Abilities off cd increase harass util
--  Ability use increases harass util for a time
----------------------------------

object.nEmeraldLightningUp = 8
object.nPowerThrowUp = 12
object.nDejaVuUp = 4
object.nEmeraldRedUp = 4

object.nEmeraldLightningUse = 15
object.nPowerThrowUse = 5
object.nDejaVuUse = 10
object.nEmeraldRedUse = 20

object.nEmeraldLightningThreshold = 40
object.nPowerThrowThreshold = 35
object.nDejaVuThreshold = 90
object.nEmeraldRedThreshold = 80
object.nDejaVuRetreatThreshold = 50

-- Variables for sniping --
object.nTimeSniped = 0
object.bStillThrowing = false

object.vecEstimatedSnipePosition = nil
object.unitSnipeTarget = nil
object.unitSnipeEstimatedTime = nil

--Aluna abilities use gives bonus to harass util for a while
function object:oncombateventOverride(EventData)
	self:oncombateventOld(EventData)
	
	local addBonus = 0
	if EventData.Type == "Ability" then
		--BotEcho("  ABILILTY EVENT!  InflictorName: "..EventData.InflictorName)
		if EventData.InflictorName == "Ability_Aluna1" then
			addBonus = addBonus + object.nEmeraldLightningUse
		end
		if EventData.InflictorName == "Ability_Aluna2" then
			addBonus = addBonus + object.nPowerThrowUse
		end
		if EventData.InflictorName == "Ability_Aluna3" then
			addBonus = addBonus + object.nDejaVuUse
		end
		if EventData.InflictorName == "Ability_Aluna4" then
			addBonus = addBonus + object.nEmeraldRedUse
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
	
	if skills.abilEmeraldLightning:CanActivate() then
		nUtility = nUtility + object.nEmeraldLightningUp
	end
	if skills.abilPowerThrow:CanActivate() then
		nUtility = nUtility + object.nPowerThrowUp
	end
	if skills.abilDejaVu:CanActivate() then
		nUtility = nUtility + object.nDejaVuUp
	end
	if skills.abilEmeraldRed:CanActivate() then
		nUtility = nUtility + object.nEmeraldRedUp
	end
	return nUtility
end
behaviorLib.CustomHarassUtility = CustomHarassUtilityOverride   


----------------------------------
--	Aluna harass actions
----------------------------------
local function HarassHeroExecuteOverride(botBrain)
	local bDebugEchos = false
		
	local unitSelf = core.unitSelf
	local unitTarget = behaviorLib.heroTarget 
	
	local bActionTaken = false
	--since we are using an old pointer, ensure we can still see the target for entity targeting
	if unitTarget ~= nil then 
		local nDistSq = Vector3.Distance2DSq(unitSelf:GetPosition(), unitTarget:GetPosition())
		
		--EmeraldLightning
		if core.CanSeeUnit(botBrain, unitTarget) then
			local abilEmeraldLightning = skills.abilEmeraldLightning
			if abilEmeraldLightning:CanActivate() and behaviorLib.lastHarassUtil > object.nEmeraldLightningThreshold then
				bActionTaken = core.OrderAbilityEntity(botBrain, abilEmeraldLightning, unitTarget)
			end
		end
		
		--PowerThrow
		if not bActionTaken then
			local abilPowerThrow = skills.abilPowerThrow
			if abilPowerThrow:CanActivate() and behaviorLib.lastHarassUtil > object.nPowerThrowThreshold then
				bActionTaken = core.OrderAbilityPosition(botBrain, abilPowerThrow, unitTarget:GetPosition())
			end
		end
		
		--DejaVu
		if not bActionTaken then
			local abilDejaVu = skills.abilDejaVu
			if abilDejaVu:CanActivate() and behaviorLib.lastHarassUtil > object.nDejaVuThreshold then
				bActionTaken = core.OrderAbility(botBrain, abilDejaVu)
			end
		end
		
		--EmeraldRed
		if not bActionTaken then
			local abilEmeraldRed = skills.abilEmeraldRed
			if abilEmeraldRed:CanActivate() and behaviorLib.lastHarassUtil > object.nEmeraldRedThreshold and unitSelf:GetMana() > 200 then
				bActionTaken = core.OrderAbility(botBrain, abilEmeraldRed)
			end
		end
		
	end
	
	if not bActionTaken then
		return object.harassExecuteOld(botBrain)
	end
end
object.harassExecuteOld = behaviorLib.HarassHeroBehavior["Execute"]
behaviorLib.HarassHeroBehavior["Execute"] = HarassHeroExecuteOverride

------------------------------------------------------------------
--Retreat execute
------------------------------------------------------------------
--  this is a great function to override with using retreating skills, such as blinks, travels, stuns or slows.
function behaviorLib.CustomRetreatExecute(botBrain)
	bActionTaken = false
	--Activate DejaVu if we can
	local abilDejaVu = skills.abilDejaVu
	if abilDejaVu and abilDejaVu:CanActivate() and behaviorLib.lastRetreatUtil >= object.nDejaVuRetreatThreshold then
		bActionTaken = core.OrderAbility(botBrain, abilDejaVu)
	end

	return bActionTaken
end

----------------------------------------
--		  	  Snipe Behaviour	  	  --
----------------------------------------
-- This is where things get interesting.
local function snipeUtility(botBrain)
	if (object.bStillThrowing) then
		return 90
	end

	local abilPowerThrow = skills.abilPowerThrow
	
	if not abilPowerThrow:CanActivate() then
		return 0
	end

	local unitSelf = core.unitSelf
	local vecSelfPos = unitSelf:GetPosition()
	local abilEmeraldRed = skills.abilEmeraldRed

	local nDamage = 70 + abilPowerThrow:GetLevel() * 70
	
	for nUID,unitEnemy in pairs(HoN.GetHeroes(core.enemyTeam)) do
		if (unitEnemy) then
			if core.CanSeeUnit(botBrain, unitEnemy) and unitEnemy:GetHealth() > 0 then
				tEnemyHero = core.teamBotBrain:CreateMemoryUnit(unitEnemy)
			else
				--we can't see them any more, perfect time to strike!
				tEnemyHero = core.teamBotBrain:GetMemoryUnit(unitEnemy)
				if (tEnemyHero) then
					local nHealth = tEnemyHero.storedHealth
					local vecPosition = tEnemyHero.lastStoredPosition
					--if we can kill them, and if they are close or (we can use our combo
					if (nHealth + 40 < nDamage and vecPosition and (Vector3.Distance2DSq(vecSelfPos, vecPosition) < 1500 * 1500 or 
						unitSelf:HasState("State_Aluna_Ability4") or (abilEmeraldRed:CanActivate() and unitSelf:GetMana() > 200))) then
						local nSpeed = tEnemyHero:GetMoveSpeed()
						local nTimePassed = HoN:GetGameTime() - tEnemyHero.lastStoredTime
						object.vecEstimatedSnipePosition, object.unitSnipeEstimatedTime = core.GetSnipeLocation(vecPosition, core.enemyWell:GetPosition(), nSpeed, nTimePassed + 800, vecSelfPos, 3000)
						object.unitSnipeTarget = unitEnemy
						return 90
					end
				end
			end
		end
	end	
	return 0
end

local function snipeExecute(botBrain)
	local abilPowerThrow = skills.abilPowerThrow
	if (not abilPowerThrow:CanActivate()) then
		return false
	end
	local bActionTaken = false
	local unitSelf = core.unitSelf
	if (object.vecEstimatedSnipePosition) then --position exists
		local abilEmeraldRed = skills.abilEmeraldRed
		
		if abilEmeraldRed:GetCharges() > 0 and unitSelf:GetMana() > 200 and not unitSelf:HasState("State_Aluna_Ability4") then
			bActionTaken = core.OrderAbility(botBrain, abilEmeraldRed, true)
			if (bActionTaken) then
				object.bStillThrowing = true
			end
		else
			bActionTaken = core.OrderAbilityPosition(botBrain, abilPowerThrow, object.vecEstimatedSnipePosition, true)
			if (bActionTaken) then
				object.bStillThrowing = false
			end
		end
	else
		object.bStillThrowing = false
	end
	return bActionTaken
end
behaviorLib.snipeBehavior = {}
behaviorLib.snipeBehavior["Utility"] = snipeUtility
behaviorLib.snipeBehavior["Execute"] = snipeExecute
behaviorLib.snipeBehavior["Name"] = "snipe"
tinsert(behaviorLib.tBehaviors, behaviorLib.snipeBehavior)

local function ProcessKillChatOverride(unitTarget, sTargetPlayerName)
	local nTimeOffset = abs((object.unitSnipeEstimatedTime or 0) - HoN:GetGameTime())
	--BotEcho(nTimeOffset)
	if unitTarget == object.unitSnipeTarget and nTimeOffset < 10000 then
		local sTargetName = sTargetPlayerName or unitTarget:GetDisplayName()
		if sTargetName == nil or sTargetName == "" then
			sTargetName = unitTarget:GetTypeName()
		end
		-- The super taunt. 1/100 chance to say: BOOM HEADSHOT
		if random(100) == 1 then
			core.AllChatLocalizedMessage("^900B^990O^090O^099O^009O^909M^900! ^990H^090E^099A^009D^909S^900H^990O^090T^099!", {target=sTargetName}, 0)
		end
	else
		object.funcProcessKillChatOld(unitTarget, sTargetPlayerName)
	end
end
object.funcProcessKillChatOld = core.ProcessKillChat
core.ProcessKillChat = ProcessKillChatOverride

BotEcho('finished loading aluna_main')

