--***************************************--
--******** \KrakenBot v0.000003/ ********--
--************** \Created/ **************--
--************* \Geramie A/ *************--
--********** \[RC2W]optx_2000/ **********--
--***************************************--
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

BotEcho('loading kraken_main...')

object.heroName = 'Hero_Kraken'

--------------------------------
-- Kraken Skills
--------------------------------
function object:SkillBuild()
	local unitSelf = self.core.unitSelf

	if skills.abilTorrent == nil then
		skills.abilTorrent = unitSelf:GetAbility(0)
		skills.abilTsunamiCharge = unitSelf:GetAbility(1)
		skills.abilSplash = unitSelf:GetAbility(2)
		skills.abilKraken = unitSelf:GetAbility(3)
		skills.abilAttributeBoost = unitSelf:GetAbility(4)
	end
	
	if unitSelf:GetAbilityPointsAvailable() <= 0 then
		return
	end
	
	--speicific level ordering first {torrent, tsunamiCharge, splash, splash, splash}
	if not (skills.abilTorrent:GetLevel() >= 1) then
		skills.abilTorrent:LevelUp()
	elseif not (skills.abilTsunamiCharge:GetLevel() >= 1) then
		skills.abilTsunamiCharge:LevelUp()
	elseif not (skills.abilSplash:GetLevel() >= 3) then
		skills.abilSplash:LevelUp()
	--max in this order {ult, splash, torrent, tsunamiCharge, stats}
	elseif skills.abilKraken:CanLevelUp() then
		skills.abilKraken:LevelUp()
	elseif skills.abilSplash:CanLevelUp() then
		skills.abilSplash:LevelUp()
	elseif skills.abilTorrent:CanLevelUp() then
		skills.abilTorrent:LevelUp()
	elseif skills.abilTsunamiCharge:CanLevelUp() then
		skills.abilTsunamiCharge:LevelUp()
	else
		skills.abilAttributeBoost:LevelUp()
	end	
end

-------------------------------------------------------
--	Kraken specific harass bonuses
--
--  Abilities off cd increase harass util
--  Ability use increases harass util for a time
-------------------------------------------------------

object.abilTorrentUpBonus = 5
object.abilTsunamiChargeUpBonus = 10
object.abilSplashUpBonus = 5
object.abilKrakenUpBonus = 40

object.abilTorrentUseBonus = 25
object.abilTsunamiChargeUseBonus = 40
object.abilSplashUseBonus = 20
object.abilKrakenUseBonus = 50

object.abilTorrentUtilThreshold = 40
object.abilTsunamiChargeUtilThreshold = 45
object.abilKrakenUtilThreshold = 50

local function AbilitiesUpUtilityFn(hero)
	
	local val = 0
	
	if hero:GetLevel() > 2 then
		if skills.abilTorrent:CanActivate() then
			val = val + object.abilTorrentUpBonus
		end
		
		if skills.abilTsunamiCharge:CanActivate() then
			val = val + object.abilTsunamiChargeUpBonus
		end
		
		if skills.abilSplash:CanActivate() then
			val = val + object.abilSplashUpBonus
		end
		
		if skills.abilKraken:CanActivate() then
			val = val + object.abilKrakenUpBonus
		end
	end
	
	return val
end
---------------------------------
--Items up harras bonus
---------------------------------
local function ItemsUpUtilityFn(hero)
	local addBonus = 0
	
	--checking for shamans headdress in inventory
	core.FindItems()
	local itemMagicArmor2 = core.itemMagicArmor2
	if itemMagicArmor2 then
		BotEcho("##########ADDING FOR SHAMANS HEADDRESS")
		addBonus = addBonus + 8
	end
	
	--checking for helm of the black legion in inventory
	core.FindItems()
	local itemShield2 = core.itemShield2
	if itemShield2 then
		BotEcho("##########ADDING FOR HELM")
		addBonus = addBonus + 8
	end
	
	return addBonus
end
-----------------------------------------------------------------
-- Kraken ability use gives bonus to harass util for a while
-----------------------------------------------------------------
function object:oncombateventOverride(EventData)
	self:oncombateventOld(EventData)
	
	local addBonus = 0
	
	if EventData.Type == "Ability" then
		--BotEcho("ABILILTY EVENT!  InflictorName: "..EventData.InflictorName)		
		if EventData.InflictorName == "Ability_Kraken1" then
			addBonus = addBonus + object.abilTorrentUseBonus
		elseif EventData.InflictorName == "Ability_Kraken2" then
			addBonus = addBonus + object.abilTsunamiChargeUseBonus
		elseif EventData.InflictorName == "Ability_Kraken3" then
			addBonus = addBonus + object.abilSplashUseBonus
		elseif EventData.InflictorName == "Ability_Kraken4" then
			addBonus = addBonus + object.abilKrakenUseBonus
		end
	end
	
	if addBonus > 0 then
		--decay before we add
		core.DecayBonus(self)
	
		core.nHarassBonus = core.nHarassBonus + addBonus
	end
end

object.oncombateventOld = object.oncombatevent
object.oncombatevent 	= object.oncombateventOverride

-----------------------------------
-- Util calc override
-----------------------------------
local function CustomHarassUtilityOverride(hero)
	local nUtility = AbilitiesUpUtilityFn(hero)
	local nItems = ItemsUpUtilityFn(hero)
	local nTotal = nUtility + nItems
	return nTotal
end
behaviorLib.CustomHarassUtility = CustomHarassUtilityOverride

----------------------------------
--	Kraken ability radius
----------------------------------
function object.GetKrakenRadius()
	return 300
end

-----------------------------------------------------------
-- AngToTarget: Function to return the angle (deg) from self to target
-- @ param unitSelf: IUnitEntity of self
-- @ param unitTarget: IUnitEntity of target
--
-- @ return angle from self to target in degrees
function AngToTarget(unitSelf, unitTarget)
    local deltaY = unitTarget:GetPosition().y - unitSelf:GetPosition().y
    local deltaX = unitTarget:GetPosition().y - unitSelf:GetPosition().x
 
    nAng = atan2(deltaY, deltaX)*57.2957795131
    return floor(nAng)
end
-- core.AngleBetween(unitPos, targetPos)
 
-----------------------------------------------------------
-- ClearToTarget: Function determines angle from self to target
--   followed by angle to all nearby creeps to determine if any are
--   between self and target
--@ param unitSelf:  IUnitEntity of self
--@ param unitTarget: IUnitEntity of target
--@ param tcreeps: table of nearby creeps (IUnitEntity)
--
--@ return: Bool as to whether path is clear to target or not
function ClearToTarget(unitSelf, unitTarget, tBuildingsTrees)
    local nhyster_theta = 2
    local nTargetDistanceSq = Vector3.Distance2DSq(unitSelf:GetPosition(), unitTarget:GetPosition())
	local ntheta_target = AngToTarget(unitSelf, unitTarget)
    for index, buildingsTrees in pairs(tBuildingsTrees) do
        if Vector3.Distance2DSq(unitSelf:GetPosition(), buildingsTrees:GetPosition()) < nTargetDistanceSq then 
            if abs(ntheta_target - AngToTarget(unitSelf, buildingsTrees)) < nhyster_theta then
                return false -- 
            end
        end
    end
    VerboseLog("Can hit hero!!!!")
    return true
end

----------------------------------
--  FindItems Override
----------------------------------
local function funcFindItemsOverride(botBrain)
	local bUpdated = object.FindItemsOld(botBrain)
	
	if core.itemBloodChalice ~= nil and not core.itemBloodChalice:IsValid() then
		core.itemBloodChalice = nil
	end
	if core.itemMagicArmor2 ~= nil and not core.itemMagicArmor2:IsValid() then
		core.itemMagicArmor2 = nil
	end
	if core.itemShield2 ~= nil and not core.itemShield2:IsValid() then
		core.itemShield2 = nil
	end
	
	if bUpdated then
		--only update if we need to
		if core.itemBloodChalice then
			return
		elseif core.itemMagicArmor2 then
			return
		elseif core.itemShield2 then
			return
		end

		local inventory = core.unitSelf:GetInventory(true)
		for slot = 1, 12, 1 do
			local curItem = inventory[slot]
			if curItem then
				if core.itemBloodChalice == nil and curItem:GetName() == "Item_BloodChalice" then
					core.itemBloodChalice = core.WrapInTable(curItem)
				elseif core.itemMagicArmor2 == nil and curItem:GetName() == "Item_MagicArmor2" then
					core.itemMagicArmor2 = core.WrapInTable(curItem)
				elseif core.itemShield2 == nil and curItem:GetName() == "Item_Shield2" then
					core.itemShield2 = core.WrapInTable(curItem)
				end
			end
		end
	end
end
object.FindItemsOld = core.FindItems
core.FindItems = funcFindItemsOverride

--------------------------------------------------
--Function: 	Mana Prediction
--Objective: 	Check to see if you have enough mana
--				to use in a specific time
--Arguements:	Number - Units Current Mana
--				Number - Units Mana Regeneration
--				Number - Time
--				Number - Ability Mana Cost
--Return:		Boolean
--------------------------------------------------
local function ManaPredictionFn(nUnitCurrentMana, nUnitManaRegen, nTime, nAbilManaCost)
	if (nUnitCurrentMana + (nUnitManaRegen * nTime)) > nAbilManaCost then
		return true
	else
		return false
	end
end

--------------------------------------------------
--Function: 	Units in Radius
--Objective: 	Check to see if specified unit is
--				in radius
--Arguements:	String - Unit Type
--Return:		Boolean
--------------------------------------------------
local function UnitsInRadiusFn(botBrain, sUnitType)
	local tUnits = core.localUnits[sUnitType]
	
	for id, unit in pairs(tUnits) do
		if core.CanSeeUnit(botBrain, unit) then
			return true
		end
	end
	
	return false
end

local function TargetInAbilityRangeFn(uSelf, uTarget, aAbility)
	local nDistance = Vector3.Distance2D(uSelf:GetPosition(), uTarget:GetPosition())
	local nRange = aAbility and aAbility:GetRange() + core.GetExtraRange(uSelf) + core.GetExtraRange(uTarget)
	
	if nDistance < nRange then
		return true
	end
	
	return false
end

-- A fixed list seems to be better then to check on each cycle if its  exist
-- so we create it here
local tRelativeMovements = {}
local function createRelativeMovementTable(key)
	--BotEcho('Created a relative movement table for: '..key)
	tRelativeMovements[key] = {
		vLastPos = Vector3.Create(),
		vRelMov = Vector3.Create(),
		timestamp = 0
	}
--	BotEcho('Created a relative movement table for: '..tRelativeMovements[key].timestamp)
end
createRelativeMovementTable("Target")

-- tracks movement for targets based on a list, so its reusable
-- key is the identifier for different uses (fe. RaMeteor for his path of destruction)
-- vTargetPos should be passed the targets position of the moment
-- to use this for prediction add the vector to a units position and multiply it
-- the function checks for 100ms cycles so one second should be multiplied by 20
local function relativeMovement(sKey, vTargetPos)
	local debugEchoes = false
	
	local gameTime = HoN.GetGameTime()
	local key = sKey
	local vLastPos = tRelativeMovements[key].vLastPos
	local nTS = tRelativeMovements[key].timestamp
	local timeDiff = gameTime - nTS 
	
	if debugEchoes then
		BotEcho('Updating relative movement for key: '..key)
		BotEcho('Relative Movement position: '..vTargetPos.x..' | '..vTargetPos.y..' at timestamp: '..nTS)
		BotEcho('Relative lastPosition is this: '..vLastPos.x)
	end
	
	if timeDiff >= 90 and timeDiff <= 140 then -- 100 should be enough (every second cycle)
		local relativeMov = vTargetPos-vLastPos
		
		if vTargetPos.LengthSq > vLastPos.LengthSq
		then relativeMov =  relativeMov*-1 end
		
		tRelativeMovements[key].vRelMov = relativeMov
		tRelativeMovements[key].vLastPos = vTargetPos
		tRelativeMovements[key].timestamp = gameTime
		
		
		if debugEchoes then
			BotEcho('Relative movement -- x: '..relativeMov.x..' y: '..relativeMov.y)
			BotEcho('^r---------------Return new-'..tRelativeMovements[key].vRelMov.x)
		end
		
		return relativeMov
	elseif timeDiff >= 150 then
		tRelativeMovements[key].vRelMov =  Vector3.Create(0,0)
		tRelativeMovements[key].vLastPos = vTargetPos
		tRelativeMovements[key].timestamp = gameTime
	end
	
	if debugEchoes then BotEcho('^g---------------Return old-'..tRelativeMovements[key].vRelMov.x) end
	return tRelativeMovements[key].vRelMov
end

----------------------------------
--	Kraken harass actions
----------------------------------
local function HarassHeroExecuteOverride(botBrain)
	local unitSelf = core.unitSelf	--Self
	local bActionTaken = false		--Has an action been taken boolean
	local unitTarget = behaviorLib.heroTarget	--Unit Target
	local bWaitAbilKraken = false

	--Check to see if unitTarget exists
	if unitTarget == nil then
		return false
	end

	--Checking for blood chalice in inventory
	core.FindItems()
	local itemBloodChalice = core.itemBloodChalice	--Blood Chalice Item

	--Checking to see if chalice is active
	if itemBloodChalice and itemBloodChalice:CanActivate() then
		--Checking if current hp is above 75% and mana is below 25%
		if unitSelf:GetHealthPercent() >= 0.75 and unitSelf:GetManaPercent() <= 0.25 then
			--Using Blood Chalice
			bActionTaken = core.OrderItemClamp(botBrain, unitSelf, itemBloodChalice)
		end
	end

	--Check to see if unit is in view
	if core.CanSeeUnit(botBrain, unitTarget) then
		local nLastHarassUtility = behaviorLib.lastHarassUtil
		local bTargetRooted = unitTarget:IsStunned() or unitTarget:IsImmobilized() or unitTarget:GetMoveSpeed() < 300
		--Ability variables
		local abilTorrent = skills.abilTorrent
		local abilTsunamiCharge = skills.abilTsunamiCharge
		local abilSplash = skills.abilSplash
		local abilKraken = skills.abilKraken
		
		--Check to see if I'm not doing something
		if not bActionTaken then
			--Check if ability is off cooldown
			if abilKraken:GetActualRemainingCooldownTime() == 0 and abilKraken:GetLevel() > 0 then
				--Check if my mana is less than my ability
				if unitSelf:GetMana() < abilKraken:GetManaCost() then
					--Check if I should wait for more mana to use abilKraken
					bWaitAbilKraken = ManaPredictionFn(unitSelf:GetMana(), unitSelf:GetManaRegen(), 5, abilKraken:GetManaCost())
				--Check if I have don't have enough mana to combo abilKraken and abilTorrent
				elseif unitSelf:GetMana() < (abilTorrent:GetManaCost() + abilKraken:GetManaCost()) then
					--Check if I should wait for more mana to use abilKraken and abilTorrent
					bWaitAbilKraken = ManaPredictionFn(unitSelf:GetMana(), unitSelf:GetManaRegen(), 5, (abilKraken:GetManaCost() + abilTorrent:GetManaCost()))
				--Check if I have don't have enough mana to combo abilKraken and abilTsunamiCharge
				elseif unitSelf:GetMana() < (abilTsunamiCharge:GetManaCost() + abilKraken:GetManaCost()) then
					--Check if I should wait for more mana to use abilKraken and abilTsunamiCharge
					bWaitAbilKraken = ManaPredictionFn(unitSelf:GetMana(), unitSelf:GetManaRegen(), 5, (abilKraken:GetManaCost() + abilTsunamicharge:GetManaCost()))
				else
					--Don't wait for abilKraken and use other abilities
					bWaitAbilKraken = false
				end

			--Check if abilKraken will be up soon
			elseif abilKraken:GetActualRemainingCooldownTime() < 5 and abilKraken:GetLevel() > 0 then
				bWaitAbilKraken = true
			elseif abilKraken:GetLevel() > 0 then
				--Don't wait for abilKraken and use other abilities
				bWaitAbilKraken = false
			end
		end
		
		--Check to see if I don't have to wait for abilKraken
		if not bWaitAbilKraken then
			--Check to see if I can activate abilKraken
			if abilKraken:CanActivate() then
				--Check to see if target is in range of ability and is rooted
				if TargetInAbilityRangeFn(unitSelf, unitTarget, abilKraken) and bTargetRooted then
					--Check if allies in radius
					if UnitsInRadiusFn(botBrain, "AllyUnits") then
						if nLastHarassUtility > botBrain.abilKrakenUtilThreshold then
							-- this needs to be called every cycle to ensure up to date values for relative movement
							local nPredictMeteor = 10
							local relativeMov = relativeMovement("Target", unitTarget:GetPosition()) * nPredictMeteor
							
							BotEcho("***Releasing The Kraken***")
							bActionTaken = core.OrderAbilityPosition(botBrain, abilKraken, (unitTarget:GetPosition()+relativeMov))
						end
					end
				end
			end
			
			--Check to see if I can activate abilTsunamiCharge
			if abilTsunamiCharge:CanActivate() then
				--Check to see if target is in range of ability and is not rooted
				if TargetInAbilityRangeFn (unitSelf, unitTarget, abilTsunamiCharge) and not bTargetRooted then
					--putting all buildings and trees in radius into a table
					local abilTsunamiChargeRange = abilTsunamiCharge:GetRange()
					local tBuildingsTrees = {}
					local tTreesInRadius = HoN.GetTreesInRadius(unitSelf:GetPosition(), abilTsunamiChargeRange)
					local tBuildingsInRadius = HoN.GetUnitsInRadius(Vector3.Create(), 99999, core.UNIT_MASK_ALIVE + core.UNIT_MASK_BUILDING)

					tBuildingsTrees = core.CopyTable(tTreesInRadius)
					tBuildingsTrees = core.CopyTable(tBuildingsInRadius)
					
					--using table of buildings and trees to see if anything is in path of ability
					if tBuildingsTrees ~= nil then
						--Check to see if anything is between unit and target
						if ClearToTarget(unitSelf, unitTarget, tBuildingsTrees) then
							if nLastHarassUtility > botBrain.abilTsunamiChargeUtilThreshold then
								-- this needs to be called every cycle to ensure up to date values for relative movement
								local nPredictMeteor = 10
								local relativeMov = relativeMovement("Target", unitTarget:GetPosition()) * nPredictMeteor
								
								bActionTaken = core.OrderAbilityPosition(botBrain, abilTsunamiCharge, (unitTarget:GetPosition()+relativeMov))
							end
						end
					else
						if nLastHarassUtility > botBrain.abilTsunamiChargeUtilThreshold then
							-- this needs to be called every cycle to ensure up to date values for relative movement
							local nPredictMeteor = 10
							local relativeMov = relativeMovement("Target", unitTarget:GetPosition()) * nPredictMeteor
							
							bActionTaken = core.OrderAbilityPosition(botBrain, abilTsunamiCharge, (unitTarget:GetPosition()+relativeMov))
						end
					end
				end
			end
			
			--Check to see if I can activate abilTorrent
			if abilTorrent:CanActivate() then
				--Check to see if target is in range of ability and is not rooted
				if TargetInAbilityRangeFn (unitSelf, unitTarget, abilTorrent) and not bTargetRooted then					
					if nLastHarassUtility > botBrain.abilTorrentUtilThreshold then
						bActionTaken = core.OrderAbilityEntity(botBrain, abilTorrent, unitTarget)
					end
				end
			end
		end
	end
end  
object.harassExecuteOld = behaviorLib.HarassHeroBehavior["Execute"]
behaviorLib.HarassHeroBehavior["Execute"] = HarassHeroExecuteOverride

----------------------------------
--	Kraken items
----------------------------------
behaviorLib.StartingItems = {"Item_LoggersHatchet", "Item_IronBuckler", "Item_RunesOfTheBlight"}
behaviorLib.LaneItems = {"Item_Scarab", "Item_MarkOfTheNovice", "Item_CrushingClaws", "Item_Steamboots", "Item_MysticVestments",  "Item_HelmOfTheVictim"}
behaviorLib.MidItems = {"Item_TrinketOfRestoration", "Item_TrinketOfRestoration", "Item_Lifetube", "Item_Beastheart"}
behaviorLib.LateItems = {"Item_Freeze", "Item_DaemonicBreastplate", "Item_Critical1 4"}

BotEcho('finished loading kraken_main')