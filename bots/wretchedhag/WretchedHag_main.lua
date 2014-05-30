-----------------------------------------
--  _   _	    ______       _    --
-- | | | |	   | ___ \     | |   --
-- | |_| | __ _  __ _| |_/ / ___ | |_  --
-- |  _  |/ _` |/ _` | ___ \/ _ \| __| --
-- | | | | (_| | (_| | |_/ / (_) | |_  --
-- \_| |_/\__,_|\__, \____/ \___/ \__| --
--	       __/ |		 --
--	      |___/  -By: DarkFire   --
-----------------------------------------
 
------------------------------------------
--	  Bot Initialization	  --
------------------------------------------
 
local _G = getfenv(0)
local object = _G.object
 
object.myName = object:GetName()
 
object.bRunLogic = true
object.bRunBehaviors = true
object.bUpdates = true
object.bUseShop = true
 
object.bRunCommands = true
object.bMoveCommands = true
object.bAttackCommands = true
object.bAbilityCommands = true
object.bOtherCommands = true
 
object.bReportBehavior = false
object.bDebugUtility = false
 
object.logger = {}
object.logger.bWriteLog = false
object.logger.bVerboseLog = false
 
object.core = {}
object.eventsLib = {}
object.metadata = {}
object.behaviorLib = {}
object.skills = {}
 
runfile "bots/core.lua"
runfile "bots/botbraincore.lua"
runfile "bots/eventsLib.lua"
runfile "bots/metadata.lua"
runfile "bots/behaviorLib.lua"
 
local core, eventsLib, behaviorLib, metadata, skills = object.core, object.eventsLib, object.behaviorLib, object.metadata, object.skills
 
local print, ipairs, pairs, string, table, next, type, tinsert, tremove, tsort, format, tostring, tonumber, strfind, strsub
	= _G.print, _G.ipairs, _G.pairs, _G.string, _G.table, _G.next, _G.type, _G.table.insert, _G.table.remove, _G.table.sort, _G.string.format, _G.tostring, _G.tonumber, _G.string.find, _G.string.sub
local ceil, floor, pi, tan, atan, atan2, abs, cos, sin, acos, asin, max, random
	= _G.math.ceil, _G.math.floor, _G.math.pi, _G.math.tan, _G.math.atan, _G.math.atan2, _G.math.abs, _G.math.cos, _G.math.sin, _G.math.acos, _G.math.asin, _G.math.max, _G.math.random
 
local BotEcho, VerboseLog, BotLog = core.BotEcho, core.VerboseLog, core.BotLog
local Clamp = core.Clamp
 
BotEcho('loading WretchedHag_main...')

--------------------------------
-- Lanes
--------------------------------
core.tLanePreferences = {Jungle = 0, Mid = 5, ShortSolo = 4, LongSolo = 5, ShortSupport = 2, LongSupport = 2, ShortCarry = 4, LongCarry = 5}
 
---------------------------------
--  	Constants   	   --
---------------------------------
 
-- Wretched Hag
object.heroName = 'Hero_BabaYaga'
 
-- Item buy order. internal names
behaviorLib.StartingItems  = {"Item_PretendersCrown", "Item_MarkOfTheNovice", "Item_RunesOfTheBlight", "Item_HealthPotion"}
behaviorLib.LaneItems  = {"Item_Marchers", "Item_GraveLocket", "Item_Steamboots", "2 Item_Scarab", "Item_Silence"}
behaviorLib.MidItems  = {"Item_Protect", "Item_GrimoireOfPower"}
behaviorLib.LateItems  = {"Item_Intelligence7", "Item_Morph"}
 
-- Skillbuild table, 0 = q, 1 = w, 2 = e, 3 = r, 4 = attri
object.tSkills = {
	1, 2, 2, 0, 2,
	3, 2, 0, 0, 0,
	3, 1, 1, 1, 4,
	3, 4, 4, 4, 4,
	4, 4, 4, 4, 4
}
 
-- Bonus agression points if a skill/item is available for use
 
object.nHauntUp = 8
object.nScreamUp = 12
object.nBlastUp = 26
object.nHellflowerUp = 12
object.nSheepstickUp = 15
 
-- Bonus agression points that are applied to the bot upon successfully using a skill/item
 
object.nHauntUse = 10
object.nBlinkUse = 8
object.nScreamUse = 16
object.nBlastUse = 24
object.nHellflowerUse = 15
object.nSheepstickUse = 18
 
-- Thresholds of aggression the bot must reach to use these abilities
 
object.nHauntThreshold = 23
object.nBlinkThreshold = 31
object.nScreamThreshold = 26
object.nBlastThreshold = 36
object.nHellflowerThreshold = 23
object.nSheepstickThreshold = 29
 
-- Other variables
 
behaviorLib.nCreepPushbackMul = 0.55
behaviorLib.nPositionHeroInfluenceMul = 3.75
 
------------------------------
--  	Skills  	--
------------------------------
 
function object:SkillBuild()
	local unitSelf = self.core.unitSelf
	if  skills.abilHaunt == nil then
		skills.abilHaunt = unitSelf:GetAbility(0)
		skills.abilBlink = unitSelf:GetAbility(1)
		skills.abilScream = unitSelf:GetAbility(2)
		skills.abilBlast = unitSelf:GetAbility(3)
		skills.abilAttributeBoost = unitSelf:GetAbility(4)
	end
 
	local nPoints = unitSelf:GetAbilityPointsAvailable()
	if nPoints <= 0 then
		return
	end
 
	local nLevel = unitSelf:GetLevel()
	for i = nLevel, (nLevel + nPoints) do
		unitSelf:GetAbility( self.tSkills[i] ):LevelUp()
	end
end
 
 
----------------------------------------
--	  OnThink Override	  --
----------------------------------------
 
function object:onthinkOverride(tGameVariables)
	self:onthinkOld(tGameVariables)
 
	-- Toggle Steamboots for more Health/Mana
	local itemSteamboots = core.GetItem("Item_Steamboots")
	if itemSteamboots and itemSteamboots:CanActivate() then
		local unitSelf = core.unitSelf
		local sKey = itemSteamboots:GetActiveModifierKey()
		if sKey == "str" then
			-- Toggle away from STR if health is high enough
			if unitSelf:GetHealthPercent() > .65 then
				self:OrderItem(itemSteamboots.object, false)
			end
		elseif sKey == "agi" then
			-- Always toggle past AGI
			self:OrderItem(itemSteamboots.object, false)
		elseif sKey == "int" then
			-- Toggle away from INT if health gets too low
			if unitSelf:GetHealthPercent() < .45 then
				self:OrderItem(itemSteamboots.object, false)
			end
		end
	end
end
 
object.onthinkOld = object.onthink
object.onthink = object.onthinkOverride
 
----------------------------------------------
--	  OnCombatEvent Override	  --
----------------------------------------------
 
function object:oncombateventOverride(EventData)
	self:oncombateventOld(EventData)
 
	local nAddBonus = 0
 
	if EventData.Type == "Ability" then
		if EventData.InflictorName == "Ability_BabaYaga1" then
			nAddBonus = nAddBonus + self.nHauntUse
		elseif EventData.InflictorName == "Ability_BabaYaga2" then
			local sCurrentBehavior = core.GetCurrentBehaviorName(self)
			if sCurrentBehavior ~= "RetreatFromThreat" and sCurrentBehavior ~= "HealAtWell" then
				nAddBonus = nAddBonus + self.nBlinkUse
			end
		elseif EventData.InflictorName == "Ability_BabaYaga3" then
			nAddBonus = nAddBonus + self.nScreamUse
		elseif EventData.InflictorName == "Ability_BabaYaga4" then
			nAddBonus = nAddBonus + self.nBlastUse
		end
	elseif EventData.Type == "Item" then
		if EventData.SourceUnit == core.unitSelf:GetUniqueID() then
			local sInflictorName = EventData.InflictorName
			local itemHellflower = core.GetItem("Item_Silence")
			local itemSheepstick = core.GetItem("Item_Morph")
			if itemHellflower ~= nil and sInflictorName == itemHellflower:GetName() then
				nAddBonus = nAddBonus + self.nHellflowerUse
			elseif itemSheepstick ~= nil and sInflictorName == itemSheepstick:GetName() then
				nAddBonus = nAddBonus + self.nSheepstickUse
			end
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
--	  CustomHarassUtility Override	  --
----------------------------------------------------
 
local function CustomHarassUtilityFnOverride(hero)
	local nUtility = 0
 
	if skills.abilHaunt:CanActivate() then
		nUtility = nUtility + object.nHauntUp
	end
 
	if skills.abilScream:CanActivate() then
		nUtility = nUtility + object.nScreamUp
	end
 
	if skills.abilBlast:CanActivate() then
		nUtility = nUtility + object.nBlastUp
	end
	
	local itemHellflower = core.GetItem("Item_Silence")
	if itemHellflower and itemHellflower:CanActivate() then
		nUtility = nUtility + object.nHellflowerUp
	end
 
	local itemSheepstick = core.GetItem("Item_Morph")
	if itemSheepstick and itemSheepstick:CanActivate() then
		nUtility = nUtility + object.nSheepstickUp		
	end
 
	return nUtility
end
 
behaviorLib.CustomHarassUtility = CustomHarassUtilityFnOverride 
 
-----------------------------------
--	  Haunt Logic	  --
-----------------------------------
 
-- Returns the magic damage Haunt will do
local function hauntDamage()
	local nHauntLevel = skills.abilHaunt:GetLevel()
	   
	if nHauntLevel == 1 then
		return 100
	elseif nHauntLevel == 2 then
		return 170
	elseif nHauntLevel == 3 then
		return 270
	elseif nHauntLevel == 4 then
		return 350
	end
 
	return nil
end
 
------------------------------------
--	  Scream Logic	  --
------------------------------------
 
-- Returns the radius of Scream
local function screamRadius()
	local nSkillLevel = skills.abilScream:GetLevel()
	   
	if nSkillLevel == 1 then
		return 425
	elseif nSkillLevel == 2 then
		return 450
	elseif nSkillLevel == 3 then
		return 475
	elseif nSkillLevel == 4 then
		return 500
	end
 
	return nil
end
 
-----------------------------------
--	  Blast Logic	  --
-----------------------------------
 
-- Filters a group to be within a given range. Modified from St0l3n_ID's Chronos bot
local function filterGroupRange(tGroup, vecCenter, nRange)
	if tGroup and vecCenter and nRange then
		local tResult = {}
		local nRangeSq = nRange * nRange
		for _, unitTarget in pairs(tGroup) do
			if Vector3.Distance2DSq(unitTarget:GetPosition(), vecCenter) <= nRangeSq then
				tinsert(tResult, unitTarget)
			end
		end   
	   
		if #tResult > 0 then
			return tResult
		end
	end
	   
	return nil
end
 
-- Find the angle in degrees between two targets. Modified from St0l3n_ID's AngToTarget code
local function getAngToTarget(vecSelf, vecTarget)
	local nDeltaY = vecTarget.y - vecSelf.y
	local nDeltaX = vecTarget.x - vecSelf.x
 
	return floor(core.RadToDeg(atan2(nDeltaY, nDeltaX)))
end
 
-- Returns the best direction to use a cone based spell
local function getConeTarget(tLocalTargets, nRange, nDegrees, nMinCount)
	if nMinCount == nil then
		nMinCount = 1
	end
 
	if tLocalTargets and core.NumberElements(tLocalTargets) >= nMinCount then
		local unitSelf = core.unitSelf
		local vecMyPosition = unitSelf:GetPosition()
		local tHeroesInRange = filterGroupRange(tLocalTargets, vecMyPosition, nRange)
		if tHeroesInRange and #tHeroesInRange >= nMinCount then
			-- Create a list of the directions to each hero in range
			local tAngleOfHeroesInRange = {}
			for _, unitEnemyHero in pairs(tHeroesInRange) do
				local vecEnemyPosition = unitEnemyHero:GetPosition()
				local vecDirection = Vector3.Normalize(vecEnemyPosition - vecMyPosition)
				vecDirection = core.RotateVec2DRad(vecDirection, pi / 2)
			   
				local nHighAngle = getAngToTarget(vecMyPosition, vecEnemyPosition + vecDirection * 100)
				local nMidAngle = getAngToTarget(vecMyPosition, vecEnemyPosition)
				local nLowAngle = getAngToTarget(vecMyPosition, vecEnemyPosition - vecDirection * 100)
				   
				tinsert(tAngleOfHeroesInRange, {nHighAngle, nMidAngle, nLowAngle})
			end
 
			local tBestGroup = {}
			local tCurrentGroup = {}
			for _, tStartAngles in pairs(tAngleOfHeroesInRange) do
				local nStartAngle = tStartAngles[1]
				if nStartAngle <= -90 then
					-- Avoid doing calculations near the break in numbers
					nStartAngle = nStartAngle + 360
				end
				   
				local nEndAngle = nStartAngle + nDegrees
				for _, tAngles in pairs(tAngleOfHeroesInRange) do
					local nHighAngle = tAngles[1]
					local nMidAngle = tAngles[2]
					local nLowAngle = tAngles[3]
					if nStartAngle > 90 and nStartAngle <= 270 then
						-- Avoid doing calculations near the break in numbers
						if nHighAngle < 0 then
							nHighAngle = nHighAngle + 360
						end
						   
						if nMidAngle < 0 then
							nMidAngle = nMidAngle + 360
						end
						   
						if nLowAngle < 0 then
							nLowAngle = nLowAngle + 360
						end
					end
				   
					if (nStartAngle <= nMidAngle and nMidAngle <= nEndAngle) or (nHighAngle >= nStartAngle and nLowAngle <= nStartAngle) or (nHighAngle >= nEndAngle and nLowAngle <= nEndAngle) then
						tinsert(tCurrentGroup, nMidAngle)
					end
				end
 
				if #tCurrentGroup > #tBestGroup then
					tBestGroup = tCurrentGroup
				end
 
				tCurrentGroup = {}
			end
 
			local nBestGroupSize = #tBestGroup
			   
			if nBestGroupSize >= nMinCount then
				tsort(tBestGroup)
			   
				local nAvgAngle = core.DegToRad((tBestGroup[1] + tBestGroup[nBestGroupSize]) / 2)
 
				return Vector3.Create(cos(nAvgAngle), sin(nAvgAngle)) * 500
			end
		end
	end
 
	return nil
end
 
-- Returns the magic damage that Hag Ult will do
local function blastDamage()
	local nBlastLevel = skills.abilBlast:GetLevel()
	if nBlastLevel < 1 then 
		return nil
	end
	
	local nHauntLevel = skills.abilHaunt:GetLevel()
	local tHauntDamageValues = {50, 100, 200, 250}
	local nBlastDamage = tHauntDamageValues[nHauntLevel] or 0
	
	if core.GetItem("Item_Intelligence7") then
		local tBlastDamageValues = {340, 530, 725}
		nBlastDamage = nBlastDamage + tBlastDamageValues[nBlastLevel]
	else
		local tBlastDamageValues = {290, 420, 550}
		nBlastDamage = nBlastDamage + tBlastDamageValues[nBlastLevel]
	end
 
	return nBlastDamage
end
 
---------------------------------------
--	  Harass Behavior	  --
---------------------------------------
 
local function HarassHeroExecuteOverride(botBrain)
 
	local unitTarget = behaviorLib.heroTarget
	if unitTarget == nil then
		return object.harassExecuteOld(botBrain)
	end
 
	local nLastHarassUtility = behaviorLib.lastHarassUtil
	local bActionTaken = false
	   
	local unitSelf = core.unitSelf
	local vecMyPosition = unitSelf:GetPosition()
	local nMyMana = unitSelf:GetMana()
	local vecTargetPosition = unitTarget:GetPosition()
	local nTargetDistanceSq = Vector3.Distance2DSq(vecMyPosition, vecTargetPosition)
	local bTargetDisabled = unitTarget:IsStunned() or unitTarget:IsSilenced()
	local bCanSeeTarget = core.CanSeeUnit(botBrain, unitTarget)
	local nTargetMagicEHP = nil
	   
	if bCanSeeTarget then
		nTargetMagicEHP = unitTarget:GetHealth() / (1 - unitTarget:GetMagicResistance())
	end
	   
	-- Hellflower
	local itemHellflower = core.GetItem("Item_Silence")
	if itemHellflower and itemHellflower:CanActivate() and (nMyMana - itemHellflower:GetManaCost()) >= 60 and not bTargetDisabled and bCanSeeTarget and nLastHarassUtility > object.nHellflowerThreshold then
		local nRange = itemHellflower:GetRange()
		if nTargetDistanceSq < (nRange * nRange) then
			bActionTaken = core.OrderItemEntityClamp(botBrain, unitSelf, itemHellflower, unitTarget)
		end
	end
 
	-- Blast
	if not bActionTaken then
		local abilBlast = skills.abilBlast
		if abilBlast:CanActivate() and (nMyMana - abilBlast:GetManaCost()) >= 60 and nLastHarassUtility > object.nBlastThreshold then
			-- Hag Ult hits 700 Range at 33 degrees
			local nRange = abilBlast:GetRange()
			local vecDirection = getConeTarget(core.localUnits["EnemyHeroes"], nRange + 200, 20, 2)
			if vecDirection then
				-- Cast towards group center (only if there are 2 or more heroes)
				bActionTaken = core.OrderAbilityPosition(botBrain, abilBlast, vecMyPosition + vecDirection)
			elseif nTargetMagicEHP and (nTargetMagicEHP * .85) > blastDamage() then
				-- Otherwise cast on target
				nRange = nRange - 75
				if nTargetDistanceSq < (nRange * nRange) and nTargetDistanceSq > (200 * 200) then
					bActionTaken = core.OrderAbilityEntity(botBrain, abilBlast, unitTarget)
				end
			end
		end   
	end
	   
	-- Haunt
	if not bActionTaken then
		local abilHaunt = skills.abilHaunt
		if abilHaunt:CanActivate() and (nMyMana - abilHaunt:GetManaCost()) >= 60  and bCanSeeTarget and nTargetMagicEHP and (nTargetMagicEHP * .65) > hauntDamage() and nLastHarassUtility > object.nHauntThreshold then
			local nRange = abilHaunt:GetRange()
			if nTargetDistanceSq < (nRange * nRange) then
				bActionTaken = core.OrderAbilityEntity(botBrain, abilHaunt, unitTarget)
			end
		end
	end
	   
	-- Sheepstick
	if not bActionTaken then
		local itemSheepstick = core.GetItem("Item_Morph")
		if itemSheepstick and itemSheepstick:CanActivate() and (nMyMana - itemSheepstick:GetManaCost()) >= 60  and not bTargetDisabled and bCanSeeTarget and nLastHarassUtility > object.nSheepstickThreshold then
			local nRange = itemSheepstick:GetRange()
			if nTargetDistanceSq < (nRange * nRange) then
				bActionTaken = core.OrderItemEntityClamp(botBrain, unitSelf, itemSheepstick, unitTarget)
			end
		end
	end
	 
	-- Blink
	if not bActionTaken then
		local abilBlink = skills.abilBlink
		if abilBlink:CanActivate() and unitSelf:GetLevel() > 1 and (nMyMana - abilBlink:GetManaCost()) >= 60 and nLastHarassUtility > object.nBlinkThreshold and (nMyMana > 200 or unitTarget:GetHealthPercent() < .15) then
			local nRange = abilBlink:GetRange() + 50
			if nTargetDistanceSq < (nRange * nRange) and nTargetDistanceSq > (415 * 415) then
				local unitEnemyWell = core.enemyWell
				if unitEnemyWell then
					-- If possible blink behind the enemy (where behind is defined as the direction from the target to the enemy well)
					local vecTargetPointToWell = Vector3.Normalize(unitEnemyWell:GetPosition() - vecTargetPosition)
					if vecTargetPointToWell then
						bActionTaken = core.OrderAbilityPosition(botBrain, abilBlink, vecTargetPosition + (vecTargetPointToWell * 150))
					end
				end
			end
		end
	end
	   
	-- Scream
	if not bActionTaken then
		local abilScream = skills.abilScream
		if abilScream:CanActivate() and (nMyMana - abilScream:GetManaCost()) >= 60  and nLastHarassUtility > object.nScreamThreshold then
			local nRadius = screamRadius() - 10
			if nTargetDistanceSq < (nRadius * nRadius) then
				bActionTaken = core.OrderAbility(botBrain, abilScream)
			end
		end
	end
 
	if not bActionTaken then
		return object.harassExecuteOld(botBrain)
	end
	   
	return bActionTaken
end
 
object.harassExecuteOld = behaviorLib.HarassHeroBehavior["Execute"]
behaviorLib.HarassHeroBehavior["Execute"] = HarassHeroExecuteOverride

--------------------------------------------------
--	  RetreatFromThreat Override	  --
--------------------------------------------------

local function funcRetreatFromThreatExecuteOverride(botBrain)
	local bActionTaken = false
       
	-- Use blink to retreat if possible
	if not bActionTaken then
		local abilBlink = skills.abilBlink
		if abilBlink:CanActivate() and core.unitSelf:GetHealthPercent() < .425 then
			bActionTaken = core.OrderBlinkAbilityToEscape(botBrain, abilBlink)
			if not bActionTaken then
				bActionTaken = core.OrderAbilityPosition(botBrain, abilBlink, core.allyWell:GetPosition())
			end
		end
	end
       
	return bActionTaken
end
behaviorLib.CustomRetreatExecute = funcRetreatFromThreatExecuteOverride
 
-------------------------------------------------
--	  HealAtWellExecute Overide	  --
-------------------------------------------------

function behaviorLib.CustomReturnToWellExecute(botBrain)
	return core.OrderBlinkAbilityToEscape(botBrain, abilBlink)
end
 
-------------------------------------------
--	  	 Pushing				 --
-------------------------------------------
 
-- These are modified from fane_maciuca's Rhapsody Bot
function behaviorLib.customPushExecute(botBrain)
	local bSuccess = false
	local abilScream = skills.abilScream
	local unitSelf = core.unitSelf
	local nMinimumCreeps = 3
       
	-- Stop the bot from trying to farm creeps if the creeps approach the spot where the bot died
	if not unitSelf:IsAlive() then
		return bSuccess
	end
       
	--Don't use Scream if it would put mana too low
	if abilScream:CanActivate() and unitSelf:GetManaPercent() > .32 then
		local tLocalEnemyCreeps = core.localUnits["EnemyCreeps"]
		if core.NumberElements(tLocalEnemyCreeps) > nMinimumCreeps then
			local vecCenter = core.GetGroupCenter(tLocalEnemyCreeps)
			if vecCenter then
				local vecCenterDistanceSq = Vector3.Distance2DSq(unitSelf:GetPosition(), vecCenter)
				if vecCenterDistanceSq then
					if vecCenterDistanceSq < (90 * 90) then
						bSuccess = core.OrderAbility(botBrain, abilScream)
					else
						bSuccess = core.OrderMoveToPos(botBrain, unitSelf, vecCenter)
					end
				end
			end
		end
	end
       
	return bSuccess
end
BotEcho(object:GetName()..' finished loading WretchedHag_main')
