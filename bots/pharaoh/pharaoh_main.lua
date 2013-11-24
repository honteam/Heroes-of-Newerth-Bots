--PharaohBot v1

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

BotEcho('loading pharaoh_main...')

--------------------------------
-- Lanes
--------------------------------
core.tLanePreferences = {Jungle = 0, Mid = 1, ShortSolo = 2, LongSolo = 1, ShortSupport = 1, LongSupport = 1, ShortCarry = 4, LongCarry = 3}

object.heroName = 'Hero_Mumra'

--------------------------------
-- Skills
--------------------------------
function object:SkillBuild()

	local unitSelf = self.core.unitSelf

	if skills.abilLeap == nil then
		skills.abilHellFire = unitSelf:GetAbility(0)
		skills.abilWallOfMummies = unitSelf:GetAbility(1)
		skills.abilTormentedSoul = unitSelf:GetAbility(2)
		skills.abilWrathOfThePharaoh = unitSelf:GetAbility(3)
		skills.attributeBoost = unitSelf:GetAbility(4)
	end
	
	if unitSelf:GetAbilityPointsAvailable() <= 0 then
		return
	end
	
	--get a level in walls, then max Tormented Soul, ult, then hellfire, and lastly walls
	if skills.abilWallOfMummies:GetLevel() < 1 then
		skills.abilWallOfMummies:LevelUp()
	elseif skills.abilTormentedSoul:CanLevelUp() then
		skills.abilTormentedSoul:LevelUp()		
	elseif skills.abilWrathOfThePharaoh:CanLevelUp() then
		skills.abilWrathOfThePharaoh:LevelUp()
	elseif skills.abilHellFire:CanLevelUp() then
		skills.abilHellFire:LevelUp()	
	elseif skills.abilWallOfMummies:CanLevelUp() then
		skills.abilWallOfMummies:LevelUp()
	else
		skills.attributeBoost:LevelUp()
	end	
end

behaviorLib.nCreepPushbackMul = 0.5
behaviorLib.nTargetPositioningMul = 0.6

----------------------------------
--	Pharaoh specific harass bonuses
--
--  Abilities off cd increase harass util
--  Ability use increases harass util for a time
----------------------------------

object.nHellFireUp = 8
object.nWallOfMummiesUp = 8
object.nTormentedSoulUp = 10
object.nWrathOfThePharaohUp = 15

object.nHellFireUse = 20
object.nWallOfMummiesUse = 20
object.nTormentedSoulUse = 8 -- low because it doesn't put us in a compromising position
object.nWrathOfThePharaohUse = 20

object.nHellFireThreshold = 35
object.nWallOfMummiesThreshold = 40
object.nTormentedSoulThreshold = 45
object.nWrathOfThePharaohThreshold = 50

--Pharaoh abilities use gives bonus to harass util for a while
function object:oncombateventOverride(EventData)
	self:oncombateventOld(EventData)
	
	local addBonus = 0
	if EventData.Type == "Ability" then
		--BotEcho("  ABILILTY EVENT!  InflictorName: "..EventData.InflictorName)
		if EventData.InflictorName == "Ability_Mumra1" then
			addBonus = addBonus + object.nHellFireUse
		end
		if EventData.InflictorName == "Ability_Mumra2" then
			addBonus = addBonus + object.nWallOfMummiesUse
		end
		if EventData.InflictorName == "Ability_Mumra3" then
			addBonus = addBonus + object.nTormentedSoulUse
		end
		if EventData.InflictorName == "Ability_Mumra4" then
			addBonus = addBonus + object.nWrathOfThePharaohUse
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
	
	if skills.abilHellFire:CanActivate() then
		nUtility = nUtility + object.nHellFireUp
	end
	if skills.abilWallOfMummies:CanActivate() then
		nUtility = nUtility + object.nWallOfMummiesUp
	end
	if skills.abilTormentedSoul:CanActivate() then
		nUtility = nUtility + object.nTormentedSoulUp
	end
	if skills.abilWrathOfThePharaoh:CanActivate() then
		nUtility = nUtility + object.nWrathOfThePharaohUp
	end
	return nUtility
end
behaviorLib.CustomHarassUtility = CustomHarassUtilityOverride   


----------------------------------
--	Pharaoh harass actions
----------------------------------
local function HarassHeroExecuteOverride(botBrain)
	local bDebugEchos = false
		
	local unitSelf = core.unitSelf
	local target = behaviorLib.heroTarget 
	
	local bActionTaken = false
	--since we are using an old pointer, ensure we can still see the target for entity targeting
	if target ~= nil and core.CanSeeUnit(botBrain, target) then 
		local nDistSq = Vector3.Distance2DSq(unitSelf:GetPosition(), target:GetPosition())
		
		--HellFire
		local abilHellFire = skills.abilHellFire
		local nHellFireRadius = 300
		if not bActionTaken then
			if abilHellFire:CanActivate() and nDistSq < nHellFireRadius * nHellFireRadius and behaviorLib.lastHarassUtil > object.nHellFireThreshold then
				bActionTaken = core.OrderAbility(botBrain, abilHellFire)
			end
		end
		
		--WallOfMummies
		local abilWallOfMummies = skills.abilWallOfMummies
		local nWallOfMummiesRadius = 189.5
		if not bActionTaken then
			if abilWallOfMummies:CanActivate() and nDistSq < nWallOfMummiesRadius * nWallOfMummiesRadius and behaviorLib.lastHarassUtil > object.nWallOfMummiesThreshold then
				bActionTaken = core.OrderAbility(botBrain, abilWallOfMummies)
			end
		end
		
		--TormentedSoul
		local abilTormentedSoul = skills.abilTormentedSoul
		--local nTormentedSoulRadius = 600
		if not bActionTaken then
			if abilTormentedSoul:CanActivate() and behaviorLib.lastHarassUtil > object.nTormentedSoulThreshold then
				bActionTaken = core.OrderAbilityPosition(botBrain, abilTormentedSoul, target:GetPosition())
			end
		end
		
		--WrathOfThePharaoh
		--TODO Make this smarter by checking for enemies in the way
		local abilWrathOfThePharaoh = skills.abilWrathOfThePharaoh
		if not bActionTaken then
			if abilWrathOfThePharaoh:CanActivate() and behaviorLib.lastHarassUtil > object.nWrathOfThePharaohThreshold then
				bActionTaken = core.OrderAbilityPosition(botBrain, abilWrathOfThePharaoh, target:GetPosition())
			end
		end
		
	end
	
	if not bActionTaken then
		return object.harassExecuteOld(botBrain)
	end
end
object.harassExecuteOld = behaviorLib.HarassHeroBehavior["Execute"]
behaviorLib.HarassHeroBehavior["Execute"] = HarassHeroExecuteOverride

----------------------------------------
--		  Snipe Losers Behaviour	  --
----------------------------------------

object.vecEstimatedSnipePosition = nil
object.unitSnipeTarget = nil
object.unitSnipeEstimatedTime = nil
local function snipeUtility(botBrain)
	local unitSelf = core.unitSelf
	local vecSelfPos = unitSelf:GetPosition()
	local abilTormentedSoul = skills.abilTormentedSoul
	
	if not abilTormentedSoul:CanActivate() then
		return 0
	end
	
	local nDamage = 40 + abilTormentedSoul:GetLevel() * 40
	
	for nUID,unitEnemy in pairs(HoN.GetHeroes(core.enemyTeam)) do
		if (unitEnemy) then
			if core.CanSeeUnit(botBrain, unitEnemy) and unitEnemy:GetHealth() > 0 then
				tEnemyHero = core.teamBotBrain:CreateMemoryUnit(unitEnemy)
			else
				--we can't see them any more, perfect time to strike!
				tEnemyHero = core.teamBotBrain:GetMemoryUnit(unitEnemy)
				if (tEnemyHero) then
					local nHealth = tEnemyHero.storedHealth
					if (nHealth + 40 < nDamage) then --this needs more logic
						local nSpeed = tEnemyHero:GetMoveSpeed()
						local vecPosition = tEnemyHero.lastStoredPosition
						local nTimePassed = HoN:GetGameTime() - tEnemyHero.lastStoredTime
						object.vecEstimatedSnipePosition, object.unitSnipeEstimatedTime = core.GetSnipeLocation(vecPosition, core.enemyWell:GetPosition(), nSpeed, nTimePassed, vecSelfPos, 1200)
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
	if (object.vecEstimatedSnipePosition) then --position exists
		return core.OrderAbilityPosition(botBrain, skills.abilTormentedSoul, object.vecEstimatedSnipePosition, true)
	end
	return false
end
behaviorLib.snipeBehavior = {}
behaviorLib.snipeBehavior["Utility"] = snipeUtility
behaviorLib.snipeBehavior["Execute"] = snipeExecute
behaviorLib.snipeBehavior["Name"] = "snipeSuckers"
tinsert(behaviorLib.tBehaviors, behaviorLib.snipeBehavior)

local function ProcessKillChatOverride(unitTarget, sTargetPlayerName)
	local nTimeOffset = abs((object.unitSnipeEstimatedTime or 0) - HoN:GetGameTime())
	--BotEcho(nTimeOffset)
	if unitTarget == object.unitSnipeTarget and nTimeOffset < 10000 then
		local sTargetName = sTargetPlayerName or unitTarget:GetDisplayName()
		if sTargetName == nil or sTargetName == "" then
			sTargetName = unitTarget:GetTypeName()
		end
		core.AllChatLocalizedMessage("^900B^990O^090O^099O^009O^909M^900! ^990H^090E^099A^009D^909S^900H^990O^090T^099!", {target=sTargetName}, 0)
	else
		object.funcProcessKillChatOld(unitTarget, sTargetPlayerName)
	end
end
object.funcProcessKillChatOld = core.ProcessKillChat
core.ProcessKillChat = ProcessKillChatOverride

----------------------------------
--	Pharaoh items
----------------------------------
--[[ list code:
	"# Item" is "get # of these"
	"Item #" is "get this level of the item" --]]
behaviorLib.StartingItems = {"Item_IronBuckler", "2 Item_RunesOfTheBlight", "Item_CrushingClaws"}
behaviorLib.LaneItems = {"Item_BloodChalice", "Item_Marchers", "Item_Lifetube"} --Item_Strength6 is Frostbrand
behaviorLib.MidItems = {"Item_Shield2", "Item_MagicArmor2", "Item_SolsBulwark", "Item_EnhancedMarchers" } --Item_Shield2 is HOTBL, Item_MagicArmor2 is shamans headdress, Item_EnhancedMarchers is ghost marchers
behaviorLib.LateItems = {"Item_DaemonicBreastplate", "Item_BehemothsHeart", "Item_Excruciator", "Item_BarrierIdol"} --Item_Excruciator is barbed armor

BotEcho('finished loading pharaoh_main')

