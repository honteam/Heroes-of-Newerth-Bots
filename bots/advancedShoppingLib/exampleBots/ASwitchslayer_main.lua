--WitchSlayerBot v1.0
--[[
Advanced Shopping Library

This S2-Bot implements the advanced shopping system.
The interesting parts are well commented for an easy implementation into your own bot

Tutorial Contents:
-Setup Advanced Shopping Library	-	Line  52 
-Change standard behavior			-	Line 110
-Requesting wards					-	Line 175
-Custom itembuild: Introduction		-	Line 200
-The Item-Handler					
	Call items by name / no need for "FindItems" lines: 379-380; 415-416; 476; 664; 716; 725

There are two types for comments:
1.'--' short explanations
2. '--[.[' and '--].]' for a detailed description

Please jump to line 60.
--]]

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

--[[
Initialize advanced Shopping, so the bot can use all its features of the library.
--]]
--Run the advanced Shopping Library:
runfile "bots/advanedShoppingLib/advancedShoppingLib.lua"
--Please jump to line 80

local core, eventsLib, behaviorLib, metadata, skills = object.core, object.eventsLib, object.behaviorLib, object.metadata, object.skills

local print, ipairs, pairs, string, table, next, type, tinsert, tremove, tsort, format, tostring, tonumber, strfind, strsub
	= _G.print, _G.ipairs, _G.pairs, _G.string, _G.table, _G.next, _G.type, _G.table.insert, _G.table.remove, _G.table.sort, _G.string.format, _G.tostring, _G.tonumber, _G.string.find, _G.string.sub
local ceil, floor, pi, tan, atan, atan2, abs, cos, sin, acos, max, random
	= _G.math.ceil, _G.math.floor, _G.math.pi, _G.math.tan, _G.math.atan, _G.math.atan2, _G.math.abs, _G.math.cos, _G.math.sin, _G.math.acos, _G.math.max, _G.math.random

local BotEcho, VerboseLog, BotLog = core.BotEcho, core.VerboseLog, core.BotLog
local Clamp = core.Clamp

BotEcho('loading witchslayer_main...')

object.heroName = 'Hero_WitchSlayer'

--------------------------------------
-- Advanced Shopping Implementation
--------------------------------------
 
 
 --[[
Set some easy to remeber references to the shopping and item handler.

shopping handler: functions to change the shopping behavior
item handler: functions for an easier usage of items
 --]]
--Set references to handlers
local itemHandler = object.itemHandler
local shopping = object.shoppingHandler
 
 
--[[
Because the itemlists and builds can be a dynamic process, you
have to save them, while the bot is in developement.

If 'developeItemBuildSaver' is off, the bot will loose its decisions
after reloading the bot files midgame.

Turn it off (or delete / comment out, if you are going to submit the bot)
]]--
--Enable ReloadBots compatibility while the bot is in developement
shopping.developeItemBuildSaver = true
 
 
 --[[
 Overview: Standard shopping behavior:
	
	(alternate options in brackets)
	
	- The bot will reserve team items and will not buy items, team-members already have
		Examples of team items: Nomes Wisdom, Mock, Daemonic Breastplate
		bReserveItems = true (false)
	
	- The bot will not wait for his lane before shopping
		Turn it on, if you alter your item builds depending on your lane (mid, safe...)
		bWaitForLaneDecision = false (true)
	
	- The bot will buy Health-Potions, Homecoming Stones and Blight Stones on his own.
		You can turn on/off Health- and Mana-Potions, Homecoming- and Blight Stones 
		or deactivate the automatic purchaise all together
		tConsumableOptions = true ( tItems, false)
		
		tItems = {		
			Item_HomecomingStone	= true, (false)
			Item_HealthPotion		= true, (false)
			Item_RunesOfTheBlight	= true, (false)
			Item_ManaPotion			= true	(false)
			}
		
	-The bot will use the courier, but they will never upgrade or rebuy it.
		If you want to make them care, turn this switch on.
		bCourierCare = false (true)
	
	If you want to change the behavior options, you only have to pass the changes. (see below)
	You can change the behavior setup, whenever you like to do it (transition from support to carry etc.)
	
	
Overview SetupOptions structure:

	default setup options:
		tSetupOptions = {
			bReserveItems 			= true,	
			bWaitForLaneDecision 	= false,
			tConsumableOptions		={		
				Item_HomecomingStone	= true,
				Item_HealthPotion		= true,
				Item_RunesOfTheBlight	= true,
				Item_ManaPotion			= true 
			},
			bCourierCare			= false
		}
	

This bot will support his team, so he should upgrade the courier, buy wards, but he shouldn't buy any Mana Potions
 --]]
--Implement changes to default settings
local tSetupOptions = {
		--upgrade courier
		bCourierCare = true,
		--wait for lane decision before shopping
		bWaitForLaneDecision = true,
		--don't autobuy Mana Potions
		tConsumableOptions = {Item_ManaPotion = false}
		}
--call setup function
shopping.Setup(tSetupOptions)
 
 
 --Requesting Wards of Sight
 --[[
Because Wards are a cheap item, we have to reserve an item-slot for them.
What is more, we have to call the purchaise onto a regular basis. (take a look at the onthink-method line: 320)

 default item slots:
 1: Boots of Choice
 2: Magic Armor
 3: Potal Key
 6: Homecoming Stone
 
 Good spots for custom decisions are slot 4, 5 and 3 (if you don't get a pk).
 
 The following function will reserve item slot 4 for Wards of Sight
 ]]--
--Swap Wards into inventory-slot 4 
shopping.SetItemSlotNumber("Item_FlamingEye", 4)
 
--start buying wards at 2 minutes
object.nextWard = 2*60*1000
 
 
 ----------------------
 --Custom Item Build
 ----------------------
  
--[[
Overview:
	If you want to use custom item build, you have to override the function 'shopping.CheckItemBuild'.
	
	This function is called, whenever the bot runs out of items.
	For a dynamic item build you may want to put only one item into the queue at any time (or just a few)
	
	"shopping.ItemDecisions" is an empty table, which can be used to save your custom item decisions.
	If "shopping.developeItemBuildSaver" is turned on, "shopping.ItemDecisions" will also be saved.
	
	Insert the item-codes into 'shopping.Itembuild'. 
	
This bot:
	This bot will only change his start-items.
		Mid: 		Ring of Teacher, Health Potion, Puzzlebox 3
		Not-Mid:	Guardian Ring, Ptretenders Crown, Minor Totem, HealthPotion and Blight Stones
		
	This function is called 3 times over the bot game:
	At start: Decide start items.
	After finishing start items: Insert all the other items
	After finishing: Will not find any new items and stop item shopping
--]]
--custom item build function
local function WitchSlayerItemBuilder()
		--called everytime your bot runs out of items, should return false if you are done with shopping
		local debugInfo = true

		if debugInfo then BotEcho("Checking Itembuilder of Witch Slayer") end
		
		--no new items
		local bNewItems = false
	   
		--get itembuild decision table 
		local tItemDecisions = shopping.ItemDecisions
		if debugInfo then BotEcho("Found ItemDecisions"..type(tItemDecisions)) end
	   
		--Choose Lane Items
		if not tItemDecisions.Lane then		
	   
				if debugInfo then BotEcho("Choose Startitems") end
			   
				local tLane = core.tMyLane
				if tLane then
						if debugInfo then BotEcho("Found my Lane") end
					   
						local startItems = nil
						 
						if tLane.sLaneName == "middle" then
								if debugInfo then BotEcho("I will take the Mid-Lane.") end
								startItems = {"Item_GuardianRing", "Item_ManaRegen3", "Item_HealthPotion", "Item_Summon 3"}
						else
								if debugInfo then BotEcho("Argh, I am not mid *sob*") end
								startItems = {"Item_GuardianRing", "Item_PretendersCrown", "Item_MinorTotem", "Item_HealthPotion", "Item_RunesOfTheBlight"}
						end
						core.InsertToTable(shopping.Itembuild, startItems)			 
						bNewItems = true
						tItemDecisions.Lane = true
				else
						--still no lane.... no starting items
						if debugInfo then BotEcho("No Lane set. Bot will skip start items now") end
				end
		--rest of itembuild
		elseif not tItemDecisions.Rest then
			   
				if debugInfo then BotEcho("Insert Rest of Items") end
							   
				core.InsertToTable(shopping.Itembuild, behaviorLib.LaneItems)
				core.InsertToTable(shopping.Itembuild, behaviorLib.MidItems)
				core.InsertToTable(shopping.Itembuild, behaviorLib.LateItems)
			   
				bNewItems = true
				tItemDecisions.Rest = true
		end
	   
		if debugInfo then BotEcho("Reached end of Itembuilder Function. Keep Shopping? "..tostring(bNewItems)) end
		return bNewItems
end
object.oldItembuilder = shopping.CheckItemBuild
shopping.CheckItemBuild = WitchSlayerItemBuilder

--------------------------------
-- Skills
--------------------------------
function object:SkillBuild()
	local unitSelf = self.core.unitSelf	
	
	if  skills.abilGraveyard == nil then
		skills.abilGraveyard		= unitSelf:GetAbility(0)
		skills.abilMiniaturization	= unitSelf:GetAbility(1)
		skills.abilPowerDrain		= unitSelf:GetAbility(2)
		skills.abilSilverBullet		= unitSelf:GetAbility(3)
		skills.abilAttributeBoost	= unitSelf:GetAbility(4)
	end
	
	if unitSelf:GetAbilityPointsAvailable() <= 0 then
		return
	end
	
	if skills.abilSilverBullet:CanLevelUp() then
		skills.abilSilverBullet:LevelUp()
	elseif skills.abilGraveyard:CanLevelUp() then
		skills.abilGraveyard:LevelUp()
	elseif skills.abilPowerDrain:GetLevel() < 1 then
		skills.abilPowerDrain:LevelUp()
	elseif skills.abilMiniaturization:CanLevelUp() then
		skills.abilMiniaturization:LevelUp()
	elseif skills.abilPowerDrain:CanLevelUp() then
		skills.abilPowerDrain:LevelUp()
	else
		skills.abilAttributeBoost:LevelUp()
	end
end

---------------------------------------------------
--				   Overrides				   --
---------------------------------------------------
 
function object:onthinkOverride(tGameVariables)
		self:onthinkOld(tGameVariables)
		
		--[[
		The function 'shopping.RequestConsumable(sItemName, nNumber)' allows the bot
		to purchaise frequently used items like dust, regen items, homecoming stones and wards,
		while ignoring your current big item (steamboots, striders etc.).
		
		--]]
		--advShopping requesting wards function
	   
		local nNow = HoN.GetMatchTime()
		--buy new wards every 6 min (start at 2 minute mark)
		if nNow >= object.nextWard then  
				shopping.RequestConsumable ("Item_FlamingEye", 5)
				object.nextWard = nNow + 6*60*1000
		end
end
object.onthinkOld = object.onthink
object.onthink  = object.onthinkOverride


----------------------------------
--	Witch Slayer's specific harass bonuses
--
--  Abilities off cd increase harass util
--  Ability use increases harass util for a time
----------------------------------

object.nGraveyardUp = 12
object.nMiniaturizationUp = 8
object.nSilverBulletUp = 35
object.nSheepstickUp = 12

object.nGraveyardUse = 16
object.nMiniaturizationUse = 15
object.nSilverBulletUse = 55
object.nSheepstickUse = 16

object.nGraveyardThreshold = 45
object.nMiniaturizationThreshold = 40
object.nSilverBulletThreshold = 60
object.nSheepstickThreshold = 30

local function AbilitiesUpUtility(hero)
	local bDebugLines = false
	local bDebugEchos = false
	
	local nUtility = 0
	
	if skills.abilGraveyard:CanActivate() then
		nUtility = nUtility + object.nGraveyardUp
	end
	
	if skills.abilMiniaturization:CanActivate() then
		nUtility = nUtility + object.nMiniaturizationUp
	end
	
	if skills.abilSilverBullet:CanActivate() then
		nUtility = nUtility + object.nSilverBulletUp
	end
	
	local itemSheepstick = itemHandler:GetItem("Item_Morph")
	if itemSheepstick and itemSheepstick:CanActivate() then
		nUtility = nUtility + object.nSheepstickUp
	end
	
	if bDebugEchos then BotEcho(" HARASS - abilitiesUp: "..nUtility) end
	if bDebugLines then
		local lineLen = 150
		local myPos = core.unitSelf:GetPosition()
		local vTowards = Vector3.Normalize(hero:GetPosition() - myPos)
		local vOrtho = Vector3.Create(-vTowards.y, vTowards.x) --quick 90 rotate z
		core.DrawDebugArrow(myPos - vOrtho * lineLen * 1.4, (myPos - vOrtho * lineLen * 1.4 ) + vTowards * nUtility * (lineLen/100), 'cyan')
	end
	
	return nUtility
end

--Witch Slayer ability use gives bonus to harass util for a while
object.nGraveyardUseTime = 0
function object:oncombateventOverride(EventData)
	self:oncombateventOld(EventData)
	
	local bDebugEchos = false
	local nAddBonus = 0
	
	if EventData.Type == "Ability" then
		if bDebugEchos then BotEcho("  ABILILTY EVENT!  InflictorName: "..EventData.InflictorName) end
		if EventData.InflictorName == "Ability_WitchSlayer1" then
			nAddBonus = nAddBonus + object.nGraveyardUse
			object.nGraveyardUseTime = EventData.TimeStamp
		elseif EventData.InflictorName == "Ability_WitchSlayer2" then
			nAddBonus = nAddBonus + object.nMiniaturizationUse
		elseif EventData.InflictorName == "Ability_WitchSlayer4" then
			nAddBonus = nAddBonus + object.nSilverBulletUse
		end
	elseif EventData.Type == "Item" then
		local itemSheepstick = itemHandler:GetItem("Item_Morph")
		if itemSheepstick ~= nil and EventData.SourceUnit == core.unitSelf:GetUniqueID() and EventData.InflictorName == itemSheepstick:GetName() then
			nAddBonus = nAddBonus + self.nSheepstickUse
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

--Util calc override
local function CustomHarassUtilityFnOverride(hero)
	local nUtility = AbilitiesUpUtility(hero)
	
	return nUtility
end
behaviorLib.CustomHarassUtility = CustomHarassUtilityFnOverride   

----------------------------------
--	Witch Slayer harass actions
----------------------------------
object.nGraveyardRangeBuffer = -100 --since our stun isn't instant, subtract some padding

local function HarassHeroExecuteOverride(botBrain)
	local bDebugEchos = false
	
	local unitTarget = behaviorLib.heroTarget
	if unitTarget == nil then
		return false --can not execute, move on to the next behavior
	end
	
	local unitSelf = core.unitSelf
	
	local vecMyPosition = unitSelf:GetPosition()
	local nAttackRangeSq = core.GetAbsoluteAttackRangeToUnit(unitSelf, unitTarget)
	nAttackRangeSq = nAttackRangeSq * nAttackRangeSq
	local nMyExtraRange = core.GetExtraRange(unitSelf)
	
	local vecTargetPosition = unitTarget:GetPosition()
	local nTargetExtraRange = core.GetExtraRange(unitTarget)
	local nTargetDistanceSq = Vector3.Distance2DSq(vecMyPosition, vecTargetPosition)
	local bTargetRooted = unitTarget:IsStunned() or unitTarget:IsImmobilized() or unitTarget:GetMoveSpeed() < 200
	
	local nLastHarassUtility = behaviorLib.lastHarassUtil
	local bCanSee = core.CanSeeUnit(botBrain, unitTarget)	
	
	if bDebugEchos then BotEcho("Witch Slayer HarassHero at "..nLastHarassUtility) end
	local bActionTaken = false

	--since we are using an old pointer, ensure we can still see the target for entity targeting
	if core.CanSeeUnit(botBrain, unitTarget) then
		local bTargetVuln = unitTarget:IsStunned() or unitTarget:IsImmobilized()

		--Sheepstick
		if not bActionTaken and not bTargetVuln then
			local itemSheepstick = itemHandler:GetItem("Item_Morph")
			if itemSheepstick then
				local nRange = itemSheepstick:GetRange()
				if itemSheepstick:CanActivate() and nLastHarassUtility > botBrain.nSheepstickThreshold then
					if nTargetDistanceSq < (nRange * nRange) then
						bActionTaken = core.OrderItemEntityClamp(botBrain, unitSelf, itemSheepstick, unitTarget)
					end
				end
			end
		end
	end
	
	--Graveyard
	if not bActionTaken and not bTargetRooted and nLastHarassUtility > botBrain.nGraveyardThreshold then
		if bDebugEchos then BotEcho("  No action yet, checking graveyard") end
		local abilGraveyard = skills.abilGraveyard
		if abilGraveyard:CanActivate() then
			local nRange = 950 --[[abilGraveyard:GetRange()]] + botBrain.nGraveyardRangeBuffer
			if nTargetDistanceSq < (nRange * nRange) then
				--calculate a target since our range doesn't match the ability effective range
				local vecToward = Vector3.Normalize(vecTargetPosition - vecMyPosition)
				local vecAbilityTarget = vecMyPosition + vecToward * 250
				bActionTaken = core.OrderAbilityPosition(botBrain, abilGraveyard, vecAbilityTarget)
			end
		end
	end
	
	--since we are using an old pointer, ensure we can still see the target for entity targeting	
	if core.CanSeeUnit(botBrain, unitTarget) then		
		--Miniaturization
		if not bActionTaken and nLastHarassUtility > botBrain.nMiniaturizationThreshold then
			--graveyard could take up to 500ms after it is cast to stun, so wait at least that long if we just cast it
			if not bTargetRooted and HoN.GetGameTime() > object.nGraveyardUseTime + 600 then
				if bDebugEchos then BotEcho("  No action yet, checking miniaturization") end
				local abilMiniaturization = skills.abilMiniaturization
				if abilMiniaturization:CanActivate() then
					local nRange = abilMiniaturization:GetRange()
					if nTargetDistanceSq < (nRange * nRange) then
						bActionTaken = core.OrderAbilityEntity(botBrain, abilMiniaturization, unitTarget)
					end
				end
			end
		end
	
		--Silver Bullet
		if not bActionTaken and nLastHarassUtility > botBrain.nSilverBulletThreshold then
			if bDebugEchos then BotEcho("  No action yet, checking silver bullet") end
			local abilSilverBullet = skills.abilSilverBullet
			if abilSilverBullet:CanActivate() --[[and CanKillWithUlt?]] then
				local nRange = abilSilverBullet:GetRange()
				if nTargetDistanceSq < (nRange * nRange) then
					bActionTaken = core.OrderAbilityEntity(botBrain, abilSilverBullet, unitTarget)
				end
			end
		end
	end
	
	--aggressive Power Drain?
	
	if not bActionTaken then
		if bDebugEchos then BotEcho("  No action yet, proceeding with normal harass execute.") end
		return object.harassExecuteOld(botBrain)
	end
end
object.harassExecuteOld = behaviorLib.HarassHeroBehavior["Execute"]
behaviorLib.HarassHeroBehavior["Execute"] = HarassHeroExecuteOverride


--TODO: Power Drain
--[[
----------------------------------
--  FindItems Override
----------------------------------
local function funcFindItemsOverride(botBrain)
	object.FindItemsOld(botBrain)

	if core.itemAstrolabe ~= nil and not core.itemAstrolabe:IsValid() then
		core.itemAstrolabe = nil
	end
	if core.itemSheepstick ~= nil and not core.itemSheepstick:IsValid() then
		core.itemSheepstick = nil
	end

	--only update if we need to
	if core.itemSheepstick and core.itemAstrolabe then
		return
	end

	local inventory = core.unitSelf:GetInventory(true)
	for slot = 1, 12, 1 do
		local curItem = inventory[slot]
		if curItem then
			if core.itemAstrolabe == nil and curItem:GetName() == "Item_Astrolabe" then
				core.itemAstrolabe = core.WrapInTable(curItem)
				core.itemAstrolabe.nHealValue = 200
				core.itemAstrolabe.nRadius = 600
				--Echo("Saving astrolabe")
			elseif core.itemSheepstick == nil and curItem:GetName() == "Item_Morph" then
				core.itemSheepstick = core.WrapInTable(curItem)
			end
		end
	end
end
object.FindItemsOld = core.FindItems
core.FindItems = funcFindItemsOverride
--]]

----------------------------------
--	Witch Slayer's Help behavior
--	
--	Utility: 
--	Execute: Use Astrolabe
----------------------------------
behaviorLib.nHealUtilityMul = 0.8
behaviorLib.nHealHealthUtilityMul = 1.0
behaviorLib.nHealTimeToLiveUtilityMul = 0.5

function behaviorLib.HealHealthUtilityFn(unitHero)
	local nUtility = 0
	
	local nYIntercept = 100
	local nXIntercept = 100
	local nOrder = 2

	nUtility = core.ExpDecay(unitHero:GetHealthPercent() * 100, nYIntercept, nXIntercept, nOrder)
	
	return nUtility
end

function behaviorLib.TimeToLiveUtilityFn(unitHero)
	--Increases as your time to live based on your damage velocity decreases
	local nUtility = 0
	
	local nHealthVelocity = unitHero:GetHealthVelocity()
	local nHealth = unitHero:GetHealth()
	local nTimeToLive = 9999
	if nHealthVelocity < 0 then
		nTimeToLive = nHealth / (-1 * nHealthVelocity)
		
		local nYIntercept = 100
		local nXIntercept = 20
		local nOrder = 2
		nUtility = core.ExpDecay(nTimeToLive, nYIntercept, nXIntercept, nOrder)
	end
	
	nUtility = Clamp(nUtility, 0, 100)
	
	--BotEcho(format("%d timeToLive: %g  healthVelocity: %g", HoN.GetGameTime(), nTimeToLive, nHealthVelocity))
	
	return nUtility, nTimeToLive
end

behaviorLib.nHealCostBonus = 10
behaviorLib.nHealCostBonusCooldownThresholdMul = 4.0
function behaviorLib.AbilityCostBonusFn(unitSelf, ability)
	local bDebugEchos = false
	
	local nCost =		ability:GetManaCost()
	local nCooldownMS =	ability:GetCooldownTime()
	local nRegen =		unitSelf:GetManaRegen()
	
	local nTimeToRegenMS = nCost / nRegen * 1000
	
	if bDebugEchos then BotEcho(format("AbilityCostBonusFn - nCost: %d  nCooldown: %d  nRegen: %g  nTimeToRegen: %d", nCost, nCooldownMS, nRegen, nTimeToRegenMS)) end
	if nTimeToRegenMS < nCooldownMS * behaviorLib.nHealCostBonusCooldownThresholdMul then
		return behaviorLib.nHealCostBonus
	end
	
	return 0
end

behaviorLib.unitHealTarget = nil
behaviorLib.nHealTimeToLive = nil
function behaviorLib.HealUtility(botBrain)
	local bDebugEchos = false
	
	--[[
	if object.myName == "Bot1" then
		bDebugEchos = true
	end
	--]]
	if bDebugEchos then BotEcho("HealUtility") end
	
	local nUtility = 0

	local unitSelf = core.unitSelf
	behaviorLib.unitHealTarget = nil
	
	local itemAstrolabe = itemHandler:GetItem("Item_Astrolabe")
	
	local nHighestUtility = 0
	local unitTarget = nil
	local nTargetTimeToLive = nil
	local sAbilName = ""
	if itemAstrolabe and itemAstrolabe:CanActivate() then
		local tTargets = core.CopyTable(core.localUnits["AllyHeroes"])
		tTargets[unitSelf:GetUniqueID()] = unitSelf --I am also a target
		for key, hero in pairs(tTargets) do
			--Don't heal ourself if we are going to head back to the well anyway, 
			--	as it could cause us to retrace half a walkback
			if hero:GetUniqueID() ~= unitSelf:GetUniqueID() or core.GetCurrentBehaviorName(botBrain) ~= "HealAtWell" then
				local nCurrentUtility = 0
				
				local nHealthUtility = behaviorLib.HealHealthUtilityFn(hero) * behaviorLib.nHealHealthUtilityMul
				local nTimeToLiveUtility = nil
				local nCurrentTimeToLive = nil
				nTimeToLiveUtility, nCurrentTimeToLive = behaviorLib.TimeToLiveUtilityFn(hero)
				nTimeToLiveUtility = nTimeToLiveUtility * behaviorLib.nHealTimeToLiveUtilityMul
				nCurrentUtility = nHealthUtility + nTimeToLiveUtility
				
				if nCurrentUtility > nHighestUtility then
					nHighestUtility = nCurrentUtility
					nTargetTimeToLive = nCurrentTimeToLive
					unitTarget = hero
					if bDebugEchos then BotEcho(format("%s Heal util: %d  health: %d  ttl:%d", hero:GetTypeName(), nCurrentUtility, nHealthUtility, nTimeToLiveUtility)) end
				end
			end
		end

		if unitTarget then
			nUtility = nHighestUtility				
			sAbilName = "Astrolabe"
		
			behaviorLib.unitHealTarget = unitTarget
			behaviorLib.nHealTimeToLive = nTargetTimeToLive
		end		
	end
	
	if bDebugEchos then BotEcho(format("	abil: %s util: %d", sAbilName, nUtility)) end
	
	nUtility = nUtility * behaviorLib.nHealUtilityMul
	
	if botBrain.bDebugUtility == true and nUtility ~= 0 then
		BotEcho(format("  HelpUtility: %g", nUtility))
	end
	
	return nUtility
end

function behaviorLib.HealExecute(botBrain)
	local itemAstrolabe = itemHandler:GetItem("Item_Astrolabe")
	
	local unitHealTarget = behaviorLib.unitHealTarget
	local nHealTimeToLive = behaviorLib.nHealTimeToLive
	
	if unitHealTarget and itemAstrolabe and itemAstrolabe:CanActivate() then 
		local unitSelf = core.unitSelf
		local vecTargetPosition = unitHealTarget:GetPosition()
		local nDistance = Vector3.Distance2D(unitSelf:GetPosition(), vecTargetPosition)
		if nDistance < 600 then
			core.OrderItemClamp(botBrain, unitSelf, itemAstrolabe)
		else
			core.OrderMoveToUnitClamp(botBrain, unitSelf, unitHealTarget)
		end
	else
		return false
	end
	
	return true
end

behaviorLib.HealBehavior = {}
behaviorLib.HealBehavior["Utility"] = behaviorLib.HealUtility
behaviorLib.HealBehavior["Execute"] = behaviorLib.HealExecute
behaviorLib.HealBehavior["Name"] = "Heal"
tinsert(behaviorLib.tBehaviors, behaviorLib.HealBehavior)


----------------------------------
--	Witch Slayer items
----------------------------------
--[[ list code:
	"# Item" is "get # of these"
	"Item #" is "get this level of the item" --]]
behaviorLib.StartingItems = 
	{"Item_GuardianRing", "Item_PretendersCrown", "Item_MinorTotem", "Item_HealthPotion", "Item_RunesOfTheBlight"}
behaviorLib.LaneItems = 
	{"Item_ManaRegen3", "Item_Marchers", "Item_Striders", "Item_GraveLocket"} --ManaRegen3 is Ring of the Teacher
behaviorLib.MidItems = 
	{"Item_SacrificialStone", "Item_NomesWisdom", "Item_Astrolabe", "Item_Intelligence7"} --Intelligence7 is Staff of the Master
behaviorLib.LateItems = 
	{"Item_Morph", "Item_BehemothsHeart", 'Item_Damage9'} --Morph is Sheepstick. Item_Damage9 is Doombringer



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
	invisible
--]]

BotEcho('finished loading witchslayer_main')
