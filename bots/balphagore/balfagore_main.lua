----------------------------------------------
-- _____       
--|_   _|
--  | |   _ __   __ _  _ __    __ _   __ _   ___   _ __   ___
--  | |  | '__| / _` || '_ \  / _` | / _` | / _ \ | '__| / _ \
--  | |  | |   | (_| || |_) || (_| || (_| || (_) || |   |  __/
--  \_/  |_|    \__,_|| .__/  \__,_| \__, | \___/ |_|    \___|
--                    | |             __/ |
--                    |_|            |___/     version 1.0.0
--
------------------------------------------
--      Created by: kairus101	--
------------------------------------------
 
------------------------------------------
--  	Bot Initialization  	--
------------------------------------------
local _G = getfenv(0)
local object = _G.object
object.myName = object:GetName()
object.bRunLogic, object.bRunBehaviors, object.bUpdates, object.bUseShop, object.bRunCommands, object.bMoveCommands, object.bAttackCommands, object.bAbilityCommands, object.bOtherCommands = true
object.logger = {}
object.bReportBehavior, object.bDebugUtility, object.logger.bWriteLog, object.logger.bVerboseLog = false
object.core 		= {}
object.eventsLib	= {}
object.metadata 	= {}
object.behaviorLib  = {}
object.skills   	= {}
runfile "bots/core.lua"
runfile "bots/botbraincore.lua"
runfile "bots/eventslib.lua"
runfile "bots/metadata.lua"
runfile "bots/behaviorlib.lua"
local core, eventsLib, behaviorLib, metadata, skills = object.core, object.eventsLib, object.behaviorLib, object.metadata, object.skills
local print, ipairs, pairs, string, table, next, type, tinsert, tremove, tsort, format, tostring, tonumber, strfind, strsub 	= _G.print, _G.ipairs, _G.pairs, _G.string, _G.table, _G.next, _G.type, _G.table.insert, _G.table.remove, _G.table.sort, _G.string.format, _G.tostring, _G.tonumber, _G.string.find, _G.string.sub
local ceil, floor, pi, tan, atan, atan2, abs, cos, sin, acos, max, random, sqrt = _G.math.ceil, _G.math.floor, _G.math.pi, _G.math.tan, _G.math.atan, _G.math.atan2, _G.math.abs, _G.math.cos, _G.math.sin, _G.math.acos, _G.math.max, _G.math.random, _G.math.sqrt
local BotEcho, VerboseLog, BotLog = core.BotEcho, core.VerboseLog, core.BotLog
local Clamp = core.Clamp
BotEcho('loading balfagore_main...')

--------------------------------
-- Lanes
--------------------------------
core.tLanePreferences = {Jungle = 0, Mid = 4, ShortSolo = 4, LongSolo = 3, ShortSupport = 1, LongSupport = 1, ShortCarry = 5, LongCarry = 5}
 
---------------------------------
--  	Constants   	   --
---------------------------------
--Balphagore
object.heroName = 'Hero_Bephelgor'
 
-- Item buy order. internal names
behaviorLib.StartingItems = {"Item_LoggersHatchet", "Item_GuardianRing", "2 Item_RunesOfTheBlight"}
behaviorLib.LaneItems = {"Item_ManaRegen3", "Item_Marchers", "Item_MysticVestments", "Item_EnhancedMarchers"}
behaviorLib.MidItems = {"Item_Energizer", "Item_Pierce 3", "Item_SolsBulwark", "Item_DaemonicBreastplate"}
behaviorLib.LateItems = {"Item_BehemothsHeart", 'Item_Damage9'}
 
-- Skillbuild. 0 is Regurgitate, 1 is Demonic Pathogen, 2 is Corpse Conversion, 3 is Hell on Newerth, 4 is Attributes
object.tSkills = {
	2, 0, 2, 0, 2, 0,   -- 1-6
	2, 0, 3, 4, 3,  	-- 7-11
	4, 4, 4, 4, 3,  	-- 12-16
	4, 4, 4, 4, 4, 1, 1, 1, 1,  	--17-25
}
 
-- Bonus agression points if a skill / item is available for use
object.nHellUp = 5
object.nRegurgitateUp = 10
object.nMinionsCloseUp = 8
object.nTrappingUp = 10
object.nEnergizerUp = 8
object.nCanAttackUp = 10
 
-- Bonus agression points that are applied to the bot upon successfully using a skill / item
object.nRegurgitateUse = 10
object.nHellUse = 8
object.nEnergizerUse = 8
 
-- Thresholds of aggression the bot must reach to use these abilities
object.nRegurgitateThreshold = 26
object.tHellOnNewerthThreshold = {70, 60, 50} --depending on charges
object.nEnergizerThreshold = 30
 
--time variables
object.nTimeBarfed = 0 		--used to get corpses at well
object.nTimeEnergizered = 0	--used for minions to remember when to trap again
 
--table variables (need to keep track on minions and corpses)
object.tMinions = {} 		--hold minions
object.tCorpseTable = {}	--position, time
object.tOldLocalCreeps = {}	--for checking if units are dead for corpses.
 
--item variables
core.itemEnergizer = nil	--energizer
core.itemBulwark = nil 		--sol's bulwark
 
--other variables
core.distSqTolerance = 5 * 5
behaviorLib.nCreepPushbackMul = 0.4
behaviorLib.nTargetPositioningMul = 0.4
behaviorLib.nTargetCriticalPositioningMul = 1
object.nMinionDistance = 0	--average distance minions are from target.
object.nMinionsClose = 0	--this is for use with energizer
object.bUnitStill = false	--this adds extra harass utility if hero is trapped
object.bTrapping = true		--controls whether trapagore traps.
object.nMinionSkip = 5		--control minions every object.nMinionSkip frames.
object.nCurSkip = 0			--current frame. This is for frame skip.
object.nLastRunTime = 0		--Last time minions were run.
 
--difficulty variables
--[[
core.nEASY_DIFFICULTY   = 1
core.nMEDIUM_DIFFICULTY = 2
core.nHARD_DIFFICULTY   = 3
]]
object.trapEffectiveness = {95 * 95, 75 * 75, 55 * 55} --Lower is better.
object.trapCycleSkip = {7*50, 4*50, 1*50} --Lower is better.
object.trapCircleRadius = {550, 450, 350}
 
------------------------------
--  	Skills  	--
------------------------------
function object:SkillBuild()
	local unitSelf = self.core.unitSelf
	if  skills.abilRegurgitate == nil then
		skills.abilRegurgitate = unitSelf:GetAbility(0)		--Barf
		skills.abilDemonicPathogen = unitSelf:GetAbility(1)	--Silence
		skills.abilSpawnMinions = unitSelf:GetAbility(2)	--Corpse pickup / Minions
		skills.abilHellOnNewerth = unitSelf:GetAbility(3)	--Ultimate
		skills.abilAttributeBoost = unitSelf:GetAbility(4)	--Stats
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
 
------------------------------------------
--  	FindItems Override  	--
------------------------------------------
local function FindItemsOverride(botBrain)
	local bUpdated = object.FindItemsOld(botBrain)
 
	if core.itemEnergizer ~= nil and not core.itemEnergizer:IsValid() then
		core.itemEnergizer = nil
	end
	if core.itemGhostMarchers ~= nil and not core.itemGhostMarchers:IsValid() then
		core.itemGhostMarchers = nil
	end
 
	if bUpdated then
		if core.itemEnergizer and core.itemGhostMarchers then
			return
		end
 
		local inventory = core.unitSelf:GetInventory(false)
		for slot = 1, 6 do
			local curItem = inventory[slot]
			if curItem and not curItem:IsRecipe() then
				if core.itemEnergizer == nil and curItem:GetName() == "Item_Energizer" then
					core.itemEnergizer = core.WrapInTable(curItem)
				elseif core.itemGhostMarchers == nil and curItem:GetName() == "Item_EnhancedMarchers" then
					core.itemGhostMarchers = core.WrapInTable(curItem)
				elseif core.itemBulwark == nil and curItem:GetName() == "Item_SolsBulwark" then
					core.itemBulwark = core.WrapInTable(curItem)
					core.OrderItemClamp(botBrain, unitSelf, core.itemBulwark) --turn to negative bols
				end
			end
		end
	end
end
object.FindItemsOld = core.FindItems
core.FindItems = FindItemsOverride
 
----------------------------------------------------
--  	  Minion Trapping Helper Functions  	  --
----------------------------------------------------
local function GetHeroByID(botBrain, ID) --refreshes the targetted unit.
	for id, unitHero in pairs(HoN.GetHeroes(core.enemyTeam)) do
		if unitHero ~= nil then
			if core.CanSeeUnit(botBrain, unitHero) then
				if unitHero:GetUniqueID() == ID then
					return unitHero
				end
			end
		end
	end
	return nil
end
local function positionOffset(pos, angle, distance) --this is used by minions to form a ring around people.
	tmp = Vector3.Create(cos(angle) * distance, sin(angle) * distance)
	return tmp + pos
end
 
----------------------------------------
--  	OnThink Override	  --
----------------------------------------
function object:onthinkOverride(tGameVariables) --This is run, even while dead. Every frame.
	self:onthinkOld(tGameVariables)--don't distrupt old think, run it.
 
	local unitSelf = core.unitSelf
	local vecSelfPos = unitSelf:GetPosition()
	local nNumMinions = table.getn(object.tMinions)
	local bDebugLines = false
	   
	---------------------------------
	--  	Register Minions	   --
	---------------------------------
	if (nNumMinions == 0 and unitSelf:IsAlive() and core.localUnits ~= nil) then
		object.tMinions = {}
		i = 1 --keep track of array index
		for key, unit in pairs(core.localUnits["AllyUnits"]) do
			if (unit:GetTypeName() == "Pet_Bephelgor_Ability2" and unit:GetOwnerPlayerID() == unitSelf:GetOwnerPlayerID()) then
				object.tMinions[i] = unit
				if (bDebugLines) then core.DrawDebugArrow(object.tMinions[i]:GetPosition(), vecSelfPos, 'white') end
				i = i + 1
			end
		end
	end
	   
	-----------------------------------------------------------------------------------
	---------------------------------
	--  	 Control Minions	   --
	---------------------------------
	-- This part is the most complicated part of the program. The minions:
	-- 1. Find a hero or building.
	-- 2. if target is a building, attack it.
	-- 3. If it's a hero:
	--   a. If target / minion is unit walking, just attack them.
	--   b. If target is not trapped yet and we have > 3 minions, surround it, 
	--  	  and close in until they are trapped.
	--   c. Attack trapped target.
	-- 4. If there is no target, attack-move along with the creep wave.
	-----------------------------------------------------------------------------------
	   
	--this is a frame-skip. We don't need to run minions code every single frame.
	object.nCurSkip = HoN:GetGameTime() - object.nLastRunTime
	if (object.nCurSkip >= object.nMinionSkip and table.getn(object.tMinions) > 0) then--don't skip
		object.nLastRunTime = HoN:GetGameTime()
		local botBrain = self
		local bDebugLines = false
		local vecWellPos = (core.enemyWell and core.enemyWell:GetPosition()) or Vector3.Create()
		   
		---------------------------------
		--    1.Minions Get Target     --
		---------------------------------   	   
		local target = nil --this is what minions will use
		local heroTarget = behaviorLib.heroTarget
		local buildingTarget = behaviorLib.hitBuildingTarget
		if (buildingTarget and buildingTarget:IsValid() and buildingTarget:IsAlive() and core.CanSeeUnit(botBrain, buildingTarget) and Vector3.Distance2DSq(buildingTarget:GetPosition(), vecSelfPos) < 2000 * 2000) then
			--If we have a building in mind
			target = buildingTarget
		elseif (heroTarget and heroTarget:IsValid() and heroTarget:IsAlive() and heroTarget:GetHealth() > 0 and core.CanSeeUnit(botBrain, heroTarget) and Vector3.Distance2DSq(heroTarget:GetPosition(), vecSelfPos) < 2000 * 2000) then
			--If we have a hero in mind
			target = GetHeroByID(botBrain, heroTarget:GetUniqueID())
		end
		object.nMinionDistance = nil
		object.nMinionsClose = 0
		   
		if (target and bDebugLines) then core.DrawDebugArrow(core.unitSelf:GetPosition(), target:GetPosition(), 'white') end
		   
		---------------------------------
		--  2.Minions Building Attack  --
		---------------------------------
		if (target and target:IsBuilding()) then --kill buildings trapagore attacks, first and foremost.
			for i = 1, nNumMinions do
				if (object.tMinions[i] and object.tMinions[i]:IsValid() and object.tMinions[i]:IsAlive()) then
					core.OrderAttack(botBrain, object.tMinions[i], target, false)
				end
			end
			object.nMinionSkip = 500 --500ms till next cycle
			   
		---------------------------------
		--    3.Minions Hero Attack    --
		---------------------------------
		elseif (target and nNumMinions > 2)then
			local target = target
			local vecTargetPos = target:GetPosition()-- + vTargetVel * 0.5
			local angleToWell = atan2(vecWellPos.y - vecTargetPos.y, vecWellPos.x - vecTargetPos.x)
			   
			if (nNumMinions > 3 and object.bTrapping) then
				object.nMinionSkip = object.trapCycleSkip[core.nDifficulty]
				   
				local totalDistance = 0
				for i = 1, nNumMinions do
					if (object.tMinions[i] and object.tMinions[i]:IsValid() and object.tMinions[i]:IsAlive() and object.tMinions[i]:GetPosition() and target and vecTargetPos) then
						vecMinionPos = object.tMinions[i]:GetPosition()
						totalDistance = totalDistance + Vector3.Distance2D(vecMinionPos, vecTargetPos)
					end
				end
				--local nAvgDistance = 1.1 * sqrt(tTotalDisplacement[1] * tTotalDisplacement[1] + tTotalDisplacement[2] * tTotalDisplacement[2]) / nNumMinions
				local nAvgDistance = totalDistance / nNumMinions
				   
				object.nMinionDistance = nAvgDistance
				distance = nAvgDistance - 30
				if (distance > object.trapCircleRadius[core.nDifficulty]) then
					distance = object.trapCircleRadius[core.nDifficulty]
				end --There is a cap on the distance.
				   
				--TRAP IF POSSIBLE
				i = 1
				while (i <= nNumMinions) do
					if (object.tMinions[i] and object.tMinions[i]:IsValid() and object.tMinions[i]:IsAlive() and object.tMinions[i]:GetPosition()) then
						vecTrappingPosition = positionOffset(vecTargetPos, angleToWell + 2 * pi * i / nNumMinions, distance)
						nDistFromTargetSq = Vector3.Distance2DSq(object.tMinions[i]:GetPosition(), vecTargetPos)
					
						local bJustEnergized = (HoN:GetGameTime() - object.nTimeEnergizered) < (6000 - 800)
						local bUnplannedUnitwalking = object.tMinions[i]:GetUnitwalking() and (HoN:GetGameTime() - object.nTimeEnergizered) > 6000
						local bLowTargetHealth = target:GetHealthPercent() < 0.05
						local bInPosition = (Vector3.Distance2DSq(object.tMinions[i]:GetPosition(), vecTrappingPosition) < object.trapEffectiveness[core.nDifficulty])
						local bCloseEnough = nDistFromTargetSq < object.trapEffectiveness[core.nDifficulty]
	
						if (target:GetUnitwalking() or bJustEnergized or bUnplannedUnitwalking or bLowTargetHealth or (bInPosition and bCloseEnough)) then
							---------------------------------
							--  	 a.Attack Target	   --
							---------------------------------
							if (nDistFromTargetSq > 128 * 128) then
								--ATTACK, You are / can't trap them.
								if (core.GetAttackSequenceProgress(object.tMinions[i]) ~= "windup") then--this is needed, don't cancel attacks param doesn't work for some reason.
									core.OrderMoveToPos(botBrain, object.tMinions[i], vecTargetPos, false)
								end
								if (bDebugLines) then core.DrawXPosition(vecTargetPos, 'yellow') end
							else
								core.OrderAttack(botBrain, object.tMinions[i], target, false)
								if (bDebugLines) then core.DrawXPosition(vecTargetPos, 'red') end
							end
						else --TRAP, they are trappable.
							---------------------------------
							--  	b.Surround Target      --
							---------------------------------
							botBrain:OrderPosition(object.tMinions[i].object or object.tMinions[i], "Move", vecTrappingPosition, nil, nil, false)
							if (bDebugLines)then core.DrawDebugArrow(object.tMinions[i]:GetPosition(), vecTrappingPosition, 'green') end--draw where hero is going
						end
						i = i + 1
					else
						tremove(object.tMinions, i)
						nNumMinions = table.getn(object.tMinions)
					end
				end
			else
				---------------------------------
				--  	 c.Attack  Target      --
				---------------------------------
				--we don't have enough minions to trap, just attack.
				object.nMinionSkip = 250 --250ms till next cycle
				for i = 1, nNumMinions do
					if (object.tMinions[i] and object.tMinions[i]:IsValid() and object.tMinions[i]:IsAlive()) then
						core.OrderAttack(botBrain, object.tMinions[i], target)
					end --kill em'
				end
			end
			   
		---------------------------------
		--  	4.Pushing   	   --
		---------------------------------
		else --no target, push forwards.
			object.nMinionSkip = 250--250ms till next cycle
			destPos = core.GetFurthestCreepWavePos(core.tMyLane, true)
			for i = 1, nNumMinions do
				if (object.tMinions[i])then
					if (object.tMinions[i] and object.tMinions[i]:IsValid() and object.tMinions[i]:IsAlive()) then
						core.OrderAttackPosition(botBrain, object.tMinions[i], destPos, false, false)--attackmove
					else
						tremove(object.tMinions, i) 
						i = i - 1 
						nNumMinions = table.getn(object.tMinions)
					end
				end
			end
		end
		nNumMinions = table.getn(object.tMinions)
		   
	end
end
object.onthinkOld = object.onthink
object.onthink  = object.onthinkOverride
 
 
----------------------------------------------
--  	BotBrainInitialize Override  	--
----------------------------------------------
function BotBrainInitializeOverride(tGameVariables)
	object.BotBrainInitializeOverrideOld(tGameVariables)
	
	if (core.nDifficulty == core.nEASY_DIFFICULTY) then
		object.bTrapping = false
	end
end
object.BotBrainInitializeOverrideOld = core.BotBrainCoreInitialize
core.BotBrainCoreInitialize = BotBrainInitializeOverride
 
 
 
----------------------------------------------
--  	OnCombatEvent Override  	--
----------------------------------------------
function object:oncombateventOverride(EventData)
	self:oncombateventOld(EventData)
 
	local nAddBonus = 0
 
	if EventData.Type == "Ability" then
		if EventData.InflictorName == "Ability_Bephelgor1" then
			nAddBonus = nAddBonus + object.nRegurgitateUse
		elseif EventData.InflictorName == "Ability_Bephelgor4" then
			nAddBonus = nAddBonus + object.nHellUse
		end
	elseif EventData.Type == "Item" then
		if core.itemEnergizer ~= nil and EventData.SourceUnit == core.unitSelf:GetUniqueID() and EventData.InflictorName == core.itemEnergizer:GetName() then
			nAddBonus = nAddBonus + self.nEnergizerUse
		end
	end
 
	if nAddBonus > 0 then
		core.DecayBonus(self)
		core.nHarassBonus = core.nHarassBonus + nAddBonus
	end
end
object.oncombateventOld = object.oncombatevent
object.oncombatevent = object.oncombateventOverride
 
----------------------------------------------------
--  	CustomHarassUtility Override	  --
----------------------------------------------------
local function CustomHarassUtilityOverride(unit) --this is part of harass hero utility.
	unitSelf = core.unitSelf
	local val = 0
	local heroTarget = unit
	--can attack enemy
	if (Vector3.Distance2DSq(unitSelf:GetPosition(), heroTarget:GetPosition()) < 128 * 128 and unitSelf:IsAttackReady()) then
		val = val + object.nCanAttackUp
	end
	--can use ultimate.
	if skills.abilHellOnNewerth:CanActivate() then
		val = val + object.nHellUp
	end
	--can use barf
	if skills.abilRegurgitate:CanActivate() then
		val = val + object.nRegurgitateUp
	end
	local nNumMinions = #object.tMinions
	--Minions are close to enemy
	if (nNumMinions > 3 and object.nMinionDistance and object.nMinionDistance < 300) then
		val = val + object.nMinionsCloseUp
	end
	--Minions are trapping enemy
	if (nNumMinions > 3 and object.bUnitStill and object.nMinionDistance and object.nMinionDistance < 80)then
		val = val + object.nTrappingUp
	end
	--can use energizer
	if (core.itemEnergizer and object.nMinionsClose > 3 and core.itemEnergizer:CanActivate()) then
		val = val + object.nEnergizerUp
	end 
	return val
end
behaviorLib.CustomHarassUtility = CustomHarassUtilityOverride
 
----------------------------------------------------
--  	   Heal At Well Override		  --
----------------------------------------------------
--When returning to well, use skills and items.

local function HealAtWellUtilityOverride(botBrain)
	local vecBackupPos = core.allyWell and core.allyWell:GetPosition() or behaviorLib.PositionSelfBackUp()
	local nOldHealingMultiplier = 1.75
	local nGoldSpendingDesire = 8 / 2000
	local nManaRefillingDesire = 8 --0 if full, this if empty
	if (Vector3.Distance2DSq(core.unitSelf:GetPosition(), vecBackupPos) < 400 * 400 and core.unitSelf:GetManaPercent() * 100 < 95) then
		return 80
	end
	return object.HealAtWellUtilityOld(botBrain) * nOldHealingMultiplier + (botBrain:GetGold() * nGoldSpendingDesire) + 1-(core.unitSelf:GetManaPercent()) * nManaRefillingDesire --courageously flee back to base.
end

function behaviorLib.CustomReturnToWellExecute(botBrain)
	local vecWellPos = (core.allyWell and core.allyWell:GetPosition()) or behaviorLib.PositionSelfBackUp()
	if (Vector3.Distance2DSq(core.unitSelf:GetPosition(), vecWellPos) > 600 * 600) then
		if (core.itemEnergizer and core.itemEnergizer:CanActivate() and not unitSelf:HasState("State_Energizer_Buff"))then --when heading to base, use energizer
			botBrain:OrderItem(core.itemEnergizer.object or core.itemEnergizer, false)
			object.nTimeEnergizered = HoN:GetGameTime()
		end

		if (skills.abilRegurgitate:CanActivate()) then --BARF
			core.OrderAbility(botBrain, skills.abilRegurgitate)
		end
	end
	return false
end
object.HealAtWellUtilityOld = behaviorLib.HealAtWellBehavior["Utility"]
behaviorLib.HealAtWellBehavior["Utility"] = HealAtWellUtilityOverride
 
----------------------------------------
--  	Harass Behaviour	  --
----------------------------------------
local function HarassHeroExecuteOverride(botBrain)
	local unitSelf = core.unitSelf
	local nHarassUtility = behaviorLib.lastHarassUtil
	local unitTarget = behaviorLib.heroTarget
	   
	local nTargetDistanceSq = Vector3.Distance2DSq(unitSelf:GetPosition(), unitTarget:GetPosition())
	local nNumMinions = table.getn(object.tMinions)
	local vecWellPos = core.allyWell and core.allyWell:GetPosition() or behaviorLib.PositionSelfBackUp()
	local distToWellSq = Vector3.Distance2DSq(unitSelf:GetPosition(), vecWellPos)
	local bActionTaken = false
	   
	--Spawn Minions
	if skills.abilSpawnMinions:CanActivate() and distToWellSq > 500 * 500 and unitSelf:GetLevel() >= 5 and skills.abilSpawnMinions:GetCharges() == skills.abilSpawnMinions:GetLevel() * 3 and nNumMinions < 3 and --can activate
		(core.teamBotBrain.nPushState == 2 or behaviorLib.heroTarget) then
		bActionTaken = core.OrderAbility(botBrain, skills.abilSpawnMinions)
	end
	   
	--Regurgitate
	if not bActionTaken and nHarassUtility > object.nRegurgitateThreshold and nTargetDistanceSq < 300 * 300 and skills.abilRegurgitate:CanActivate() then
		object.nTimeBarfed = HoN:GetGameTime()
		bActionTaken = core.OrderAbility(botBrain, skills.abilRegurgitate, false, false)
	end
	   
	-- Ultimate
	local ultThreshholdValue = floor(skills.abilHellOnNewerth:GetCharges() / 40) + 1
	if not bActionTaken and skills.abilHellOnNewerth:CanActivate() and nHarassUtility > object.tHellOnNewerthThreshold[ultThreshholdValue] and nTargetDistanceSq < 550 * 550 then
		bActionTaken = core.OrderAbility(botBrain, skills.abilHellOnNewerth)
	end
	   
	-- Energizer
	if not bActionTaken and core.itemEnergizer and core.itemEnergizer:CanActivate() and nHarassUtility > object.nEnergizerThreshold then
		botBrain:OrderItem(core.itemEnergizer.object or core.itemEnergizer, false)
		object.nTimeEnergizered = HoN:GetGameTime()
	end
	   
	--default
	if not bActionTaken then
		return object.harassHeroExecuteOld(botBrain)
	end
	return bActionTaken
end
object.harassHeroExecuteOld = behaviorLib.HarassHeroBehavior["Execute"]
behaviorLib.HarassHeroBehavior["Execute"] = HarassHeroExecuteOverride
 
----------------------------------------
--  	Retreat Behaviour   	  --
----------------------------------------
local function retreatFromThreatExecuteOverride(botBrain)
	--note that these actions do not requite a frame to complete, therefore bActionTaken is not necessary.
	--use energizer when retreating
	if itemEnergizer and itemEnergizer:CanActivate() and behaviorLib.lastRetreatUtil >= object.nEnergizerThreshold then
		botBrain:OrderItem(core.itemEnergizer.object or core.itemEnergizer, false)
		object.nTimeEnergizered = HoN:GetGameTime()
	end
	--use regurgitate when retreating
	if (skills.abilRegurgitate:CanActivate() and behaviorLib.lastRetreatUtil >= object.nRegurgitateThreshold) then
		core.OrderAbility(botBrain, skills.abilRegurgitate, false, true)
	end
	--use ghost marchers when retreating
	if (core.itemGhostMarchers and core.itemGhostMarchers:CanActivate())then --when heading to base, use boots
		botBrain:OrderItem(core.itemGhostMarchers.object or core.itemGhostMarchers, false)
	end
	   
	return object.RetreatFromThreatExecuteOld(botBrain)
end
object.RetreatFromThreatExecuteOld = behaviorLib.RetreatFromThreatBehavior["Execute"]
behaviorLib.RetreatFromThreatBehavior["Execute"] = retreatFromThreatExecuteOverride
 
----------------------------------------
--  	Advanced Think Behaviour	  --
----------------------------------------
local function advancedThinkUtility(botBrain)
	return 95; --always ridiculously important. Though, this rarly returns true.
end
 
local function advancedThinkExecute(botBrain)
	local unitSelf = core.unitSelf
	local vecSelfPos = unitSelf:GetPosition()
	local nNumMinions = table.getn(object.tMinions)
	local vecWellPos = core.allyWell and core.allyWell:GetPosition() or behaviorLib.PositionSelfBackUp()
	local distToWellSq = Vector3.Distance2DSq(vecSelfPos, vecWellPos)
	local bActionTaken = false
	   
	--make and eat corpses at base
	if ( distToWellSq < 500 * 500 and not unitSelf:IsChanneling() and
	unitSelf:GetLevel() > 1 and (skills.abilSpawnMinions:GetCharges() < skills.abilSpawnMinions:GetLevel() * 3 or object.nTimeBarfed + 4800 > HoN:GetGameTime())) then
		if (skills.abilRegurgitate:CanActivate() and not unitSelf:IsChanneling() and distToWellSq < 100 * 100) then --turn and spew
			bActionTaken = core.OrderMoveToPos(botBrain, unitSelf, positionOffset(vecSelfPos, 0, 10))
			object.nTimeBarfed = HoN:GetGameTime()
			bActionTaken = core.OrderAbility(botBrain, skills.abilRegurgitate, false, true)
		elseif (object.nTimeBarfed + 3300 > HoN:GetGameTime()) then --wait while barfing.
			bActionTaken = core.OrderHoldClamp(botBrain, unitSelf, false)
		elseif (object.nTimeBarfed + 4200 > HoN:GetGameTime()) then --collect corpses
			bActionTaken = core.OrderMoveToPos(botBrain, unitSelf, positionOffset(vecSelfPos, 0, 300))
		else --move back into the center of the well
			bActionTaken = core.OrderMoveToPos(botBrain, unitSelf, vecWellPos)
		end
	end
	   
	return bActionTaken
end
behaviorLib.advancedThink = {}
behaviorLib.advancedThink["Utility"] = advancedThinkUtility
behaviorLib.advancedThink["Execute"] = advancedThinkExecute
behaviorLib.advancedThink["Name"] = "advancedThink"
tinsert(behaviorLib.tBehaviors, behaviorLib.advancedThink)
 
----------------------------------------
--     Collect Corpses Behaviour	  --
----------------------------------------
local corpsePosition = nil
local function getCorpsesUtility(botBrain)
	local unitSelf = core.unitSelf
	local vecSelfPos = unitSelf:GetPosition()
	   
	-- Find Corpses
	if (unitSelf:IsAlive() and core.localUnits ~= nil)then
		local localCreeps = {}
		--Get all creeps nearby and put them into a single table.
		for k, v in pairs(core.localUnits['EnemyCreeps']) do
			localCreeps[k] = v
		end
		for k, v in pairs(core.localUnits['AllyCreeps']) do
			localCreeps[k] = v
		end
		for k, v in pairs(localCreeps) do
			object.tOldLocalCreeps[k] = nil
		end
		for key, unit in pairs(object.tOldLocalCreeps) do
			id = key
			if (unit and unit:IsValid() and unit:GetHealth() and unit:GetHealth() <= 0 and core.IsLaneCreep(unit)) then --these cause awful amounts of 'corpses' constantly.
				if (unit:GetAttackRange() ~= 690) then--catapults don't have corpses..
					tinsert(object.tCorpseTable, {position = unit:GetPosition(), time = HoN:GetGameTime()})--create corpse record
				end
			end
		end
		object.tOldLocalCreeps = localCreeps
		for key, event in pairs(object.tCorpseTable) do --remove old / obtained corpses
			if (HoN.GetGameTime() > event['time'] + 14000 or Vector3.Distance2DSq(vecSelfPos, event['position']) <= 105 * 105) then
				tremove(object.tCorpseTable, key)
			end
		end
	end
 
	--assess corpses
	local bDebugLines = false
	if (unitSelf:GetLevel() < 2 or (skills.abilSpawnMinions:GetCharges() == skills.abilSpawnMinions:GetLevel() * 3 and unitSelf:GetHealthPercent() * 1000 == 1000))then
		return 0
	end
	local closestCorpse = nil
	local nClosestCorpseDistSq = 9999 * 9999
	for key, v in pairs(object.tCorpseTable) do
		vecCorpsePosition = v['position']
		--"safe" corpses aren't toward the opponents.
		if not object.vecLaneForward or abs(core.RadToDeg(core.AngleBetween(vecCorpsePosition - unitSelf:GetPosition(), -object.vecLaneForward)) ) < 130 then
			local nDistSq = Vector3.Distance2DSq(vecCorpsePosition, unitSelf:GetPosition())
			if (bDebugLines)then core.DrawXPosition(vecCorpsePosition, 'aqua') end
			if nDistSq < nClosestCorpseDistSq then
				closestCorpse = v
				nClosestCorpseDistSq = nDistSq
			end
		elseif (bDebugLines)then core.DrawXPosition(vecCorpsePosition, 'black') end
	end
	if (closestCorpse) then
		corpsePosition = closestCorpse['position']
		return 30 * ((500-sqrt(nClosestCorpseDistSq)) / 500) -- basically, the closer you are to the corpse, the more you want it. 30 utility over 500 units.
	else
		corpsePosition = nil
		return 0
	end
end
local function getCorpsesExecute(botBrain)
	if (corpsePosition) then --corpse exists
		return core.OrderMoveToPosClamp(botBrain, core.unitSelf, corpsePosition)--get the corpse.
	end
	return false
end
behaviorLib.getCorpses = {}
behaviorLib.getCorpses["Utility"] = getCorpsesUtility
behaviorLib.getCorpses["Execute"] = getCorpsesExecute
behaviorLib.getCorpses["Name"] = "getCorpses"
tinsert(behaviorLib.tBehaviors, behaviorLib.getCorpses)
 
 --@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@ PERSONALITY
core.tKillChatKeys = {
	"kairus101_balphagore_kill1",
	"kairus101_balphagore_kill2",
	"kairus101_balphagore_kill3",
	"kairus101_balphagore_kill4",
	"kairus101_balphagore_kill5"
}
core.tDeathChatKeys = {
	"kairus101_balphagore_death1",
	"kairus101_balphagore_death2",
	"kairus101_balphagore_death3",
	"kairus101_balphagore_death4",
	"kairus101_balphagore_death5",
	"kairus101_balphagore_death6",
	"kairus101_balphagore_death7"
}
 
 --@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@ SIGN OFF
BotEcho('finished loading balfagore_main')
