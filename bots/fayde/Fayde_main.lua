-------------------------------------------------
-- ______              _     ______       _    --
-- |  ___|            | |    | ___ \     | |   --
-- | |_ __ _ _   _  __| | ___| |_/ / ___ | |_  --
-- |  _/ _` | | | |/ _` |/ _ \ ___ \/ _ \| __| --
-- | || (_| | |_| | (_| |  __/ |_/ / (_) | |_  --
-- \_| \__,_|\__, |\__,_|\___\____/ \___/ \__| --
--            __/ |                            --
--           |___/     -v1.0 By: DarkFire-     --
-------------------------------------------------

------------------------------------------
--          Bot Initialization          --
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
local ceil, floor, pi, tan, atan, atan2, abs, cos, sin, acos, asin, min, max, random
    = _G.math.ceil, _G.math.floor, _G.math.pi, _G.math.tan, _G.math.atan, _G.math.atan2, _G.math.abs, _G.math.cos, _G.math.sin, _G.math.acos, _G.math.asin, _G.math.min, _G.math.max, _G.math.random

local BotEcho, VerboseLog, BotLog = core.BotEcho, core.VerboseLog, core.BotLog
local Clamp = core.Clamp

BotEcho('loading Fayde_main...')

---------------------------------
--          Constants          --
---------------------------------

-- Wretched Hag
object.heroName = 'Hero_Fade'

-- Item buy order. internal names  
behaviorLib.StartingItems  = {"Item_RunesOfTheBlight", "Item_LoggersHatchet", "Item_IronShield"}
behaviorLib.LaneItems  = {"Item_Marchers", "Item_Bottle", "Item_EnhancedMarchers", "Item_Nuke 1"}
behaviorLib.MidItems  = {"Item_SpellShards 3", "Item_Nuke 5"}
behaviorLib.LateItems  = {"Item_GrimoireOfPower", "Item_Silence", "Item_Morph"}

-- Skillbuild table, 0=q, 1=w, 2=e, 3=r, 4=attri
object.tSkills = {
	1, 0, 1, 0, 1,
	3, 1, 0, 0, 2,
	3, 2, 2, 2, 4,
	3, 4, 4, 4, 4,
	4, 4, 4, 4, 4,
}

-- Bonus agression points if a skill/item is available for use

object.nCullUp = 12
object.nBurningShadowsUp = 15
object.nDeepShadowsUp = 8
object.nReflectionUp = 24
object.nCodexUp = 22
object.nHellflowerUp = 14
object.nSheepstickUp = 18

-- Bonus agression points that are applied to the bot upon successfully using a skill/item

object.nCullUse = 16
object.nBurningShadowsUse = 18
object.nDeepShadowsUse = 10
object.nReflectionUse = 55
object.nCodexUse = 20
object.nHellflowerUse = 17
object.nSheepstickUse = 21

-- Thresholds of aggression the bot must reach to use these abilities

object.nCullThreshold = 22
object.nBurningShadowsThreshold = 23
object.nDeepShadowsThreshold = 21
object.nReflectionThreshold = 28
object.nCodexThreshold = 28
object.nHellflowerThreshold = 25
object.nSheepstickThreshold = 30

-- Other variables

behaviorLib.nCreepPushbackMul = 0.6
behaviorLib.nTargetPositioningMul = 1.2
behaviorLib.nTargetCriticalPositioningMul = 1

------------------------------
--          Skills          --
------------------------------

function object:SkillBuild()
    local unitSelf = self.core.unitSelf
    if  skills.abilCull == nil then
        skills.abilCull = unitSelf:GetAbility(0)
        skills.abilBurningShadows = unitSelf:GetAbility(1)
        skills.abilDeepShadows = unitSelf:GetAbility(2)
        skills.abilReflection = unitSelf:GetAbility(3)
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

------------------------------------------
--          FindItems Override          --
------------------------------------------

local function funcFindItemsOverride(botBrain)
    local bUpdated = object.FindItemsOld(botBrain)
	
	if core.itemBottle ~= nil and not core.itemBottle:IsValid() then
		core.itemBottle = nil
	end
	
	if core.itemCodex ~= nil and not core.itemCodex:IsValid() then
		core.itemCodex = nil
	end
 
	if core.itemHellflower ~= nil and not core.itemHellflower:IsValid() then
		core.itemHellflower = nil
	end
	
    if core.itemSheepstick ~= nil and not core.itemSheepstick:IsValid() then
        core.itemSheepstick = nil
    end
     
    if bUpdated then
        --only update if we need to
        if core.itemSteamboots and  core.itemHellflower and core.itemSheepstick then
            return
        end
         
        local inventory = core.unitSelf:GetInventory(true)
        for slot = 1, 12, 1 do
            local curItem = inventory[slot]
            if curItem then
				if core.itemBottle == nil and curItem:GetName() == "Item_Bottle" then
					core.itemBottle = core.WrapInTable(curItem)
				elseif core.itemCodex == nil and curItem:GetName() == "Item_Nuke" then
					core.itemCodex = core.WrapInTable(curItem)
				elseif core.itemHellflower == nil and curItem:GetName() == "Item_Silence" then
					core.itemHellflower = core.WrapInTable(curItem)
                elseif core.itemSheepstick == nil and curItem:GetName() == "Item_Morph" then
                    core.itemSheepstick = core.WrapInTable(curItem)
                end
            end
        end
    end
end

object.FindItemsOld = core.FindItems
core.FindItems = funcFindItemsOverride

----------------------------------------------
--          OnCombatEvent Override          --
----------------------------------------------

function object:oncombateventOverride(EventData)
	self:oncombateventOld(EventData)

	local nAddBonus = 0
	
	if EventData.Type == "Ability" then
        if EventData.InflictorName == "Ability_Fade1" then
            nAddBonus = nAddBonus + self.nCullUse
		elseif EventData.InflictorName == "Ability_Fade2" then
			nAddBonus = nAddBonus + self.nBurningShadowsUse
        elseif EventData.InflictorName == "Ability_Fade3" then
            nAddBonus = nAddBonus + self.nDeepShadowsUse
        elseif EventData.InflictorName == "Ability_Fade4" then
            nAddBonus = nAddBonus + self.nReflectionUse
        end
    elseif EventData.Type == "Item" then
		if core.itemCodex ~= nil and EventData.SourceUnit == core.unitSelf:GetUniqueID() and EventData.InflictorName == core.itemCodex:GetName() then
			nAddBonus = nAddBonus + self.nCodexUse
		elseif core.itemHellflower ~= nil and EventData.SourceUnit == core.unitSelf:GetUniqueID() and EventData.InflictorName == core.itemHellflower:GetName() then
			nAddBonus = nAddBonus + self.nHellflowerUse
        elseif core.itemSheepstick ~= nil and EventData.SourceUnit == core.unitSelf:GetUniqueID() and EventData.InflictorName == core.itemSheepstick:GetName() then
            nAddBonus = nAddBonus + self.nSheepstickUse
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
--          CustomHarassUtility Override          --
----------------------------------------------------

local function CustomHarassUtilityFnOverride(hero)
	local nUtility = 0

    if skills.abilCull:CanActivate() then
        nUtility = nUtility + object.nCullUp
    end
 
    if skills.abilBurningShadows:CanActivate() then
        nUtility = nUtility + object.nBurningShadowsUp
    end
 
    if skills.abilDeepShadows:CanActivate() then
        nUtility = nUtility + object.nDeepShadowsUp
    end
 
    if skills.abilReflection:CanActivate() then
        nUtility = nUtility + object.nReflectionUp
    end
 
    if object.itemCodex and object.itemCodex:CanActivate() then
        nUtility = nUtility + object.nCodexUp
    end 
 
    if object.itemHellflower and object.itemHellflower:CanActivate() then
        nUtility = nUtility + object.nHellflowerUp
    end
 
    if object.itemSheepstick and object.itemSheepstick:CanActivate() then
        nUtility = nUtility + object.nSheepstickUp
    end

    return nUtility
end

behaviorLib.CustomHarassUtility = CustomHarassUtilityFnOverride   

-------------------------------------------
--          Check Rune Behavior          --
-------------------------------------------

behaviorLib.bCheckRune = false

-- Decides when to check for rune 0 at 3000 units from a rune spot 40 at rune
local function checkRuneUtility(botBrain)
	local nUtility = 0
	local nMatchTime = core.MSToS(HoN.GetMatchTime())

	-- reset the check rune variable 
	if floor(nMatchTime % 120) > 110 then
		behaviorLib.bCheckRune = true
	end
	
	local unitSelf = core.unitSelf
	local vecMyPosition = unitSelf:GetPosition()
	local vecTopRune = Vector3.Create(5820, 9720, -128)
	local vecBotRune = Vector3.Create(11135, 5370, -128)
	local nDistanceTopSq = Vector3.Distance2DSq(vecMyPosition, vecTopRune)
	local nDistanceBotSq = Vector3.Distance2DSq(vecMyPosition, vecBotRune)
	local nDistanceSq = min(nDistanceTopSq, nDistanceBotSq)
	
	-- If the bot is close to the rune then check it
	if behaviorLib.bCheckRune then
		nUtility = Clamp(core.ParabolicDecayFn(nDistanceSq, 40, (3000 * 3000)), 0 , 100)
	else
		nUtility = 0
	end
	
	return nUtility
end

-- Orders hero to move to closest rune spot, and grab/bottle rune if it spawns there
local function checkRuneExecute(botBrain)
	local bActionTaken = false
	local unitSelf = core.unitSelf
	local vecMyPosition = unitSelf:GetPosition()

	local vecTopRune = Vector3.Create(5820, 9720, -128)
	local vecBotRune = Vector3.Create(11135, 5370, -128)
	
	local nDistanceTopSq = Vector3.Distance2DSq(vecMyPosition, vecTopRune)
	local nDistanceBotSq = Vector3.Distance2DSq(vecMyPosition, vecBotRune)
	local nDistanceSq = min(nDistanceTopSq, nDistanceBotSq)
	
	if nDistanceSq > (275 * 275) then
		-- Go to whichever Rune spot is closer
		if nDistanceTopSq < nDistanceBotSq then
			bActionTaken = core.OrderMoveToPosClamp(botBrain, unitSelf, vecTopRune)
		else
			bActionTaken = core.OrderMoveToPosClamp(botBrain, unitSelf, vecBotRune)
		end
	else
		-- We are close enough to the rune spot
		local tRune = HoN.GetUnitsInRadius(vecMyPosition, 400, core.UNIT_MASK_ALIVE + core.UNIT_MASK_POWERUP)
		if core.NumberElements(tRune) > 0 then
			local unitRune = nil
			for _, unit in pairs(tRune) do
				unitRune = unit
			end
			
			core.FindItems()
			local itemBottle = core.itemBottle
			-- If the bot has a bottle then bottle rune, otherwise just grab it
			if itemBottle then
				-- bottle rune if the bottle is empty, otherwise drink until empty
				if getBottleCharges(itemBottle) == 0 then
					bActionTaken = core.OrderItemEntityClamp(botBrain, unitSelf, itemBottle, unitRune)
				else
					if not unitSelf:HasState("State_Bottle") then
						bActionTaken = core.OrderItemClamp(botBrain, unitSelf, itemBottle)
					else
						-- Drink fast if the bot has lots of health/mana
						if unitSelf:GetHealthPercent() > .95 and unitSelf:GetManaPercent() > .95 then
							bActionTaken = core.OrderItemClamp(botBrain, unitSelf, itemBottle)
						else
							bActionTaken = core.OrderAttackPositionClamp(botBrain, unitSelf, vecMyPosition)
						end
					end
				end
			else
				bActionTaken = core.OrderTouch(botBrain, unitSelf, unitRune)
			end
		else
			-- We guessed wrong or we already grabbed the rune, don't check the other rune
			local nMatchTime = core.MSToS(HoN.GetMatchTime())
			if nMatchTime % 120 < 110 then
				behaviorLib.bCheckRune = false
			end
		end
	end

	return bActionTaken
end

behaviorLib.CheckRuneBehavior = {}
behaviorLib.CheckRuneBehavior["Utility"] = checkRuneUtility
behaviorLib.CheckRuneBehavior["Execute"] = checkRuneExecute
behaviorLib.CheckRuneBehavior["Name"] = "CheckRune"
tinsert(behaviorLib.tBehaviors, behaviorLib.CheckRuneBehavior)

--------------------------------------
--          Illusion Logic          --
--------------------------------------

-- Order all illusions to attack the target
local function funcIllusionLogic(botBrain, unitTarget)
	local playerSelf = core.unitSelf:GetOwnerPlayerID()
	local tAllyHeroes = HoN.GetHeroes(core.myTeam)
	local tIllusions = {}
	for nUID, unitHero in pairs(tAllyHeroes) do
		if core.teamBotBrain.tAllyHeroes[nUID] == nil then
			if unitHero:GetOwnerPlayerID() == playerSelf then
				tinsert(tIllusions, unitHero)
			end
		end
	end

	if #tIllusions > 0 then
		for _, unitIllusion in pairs(tIllusions) do
			core.OrderAttack(botBrain, unitIllusion, unitTarget)
		end
	end

	return
end

----------------------------------
--          Cull Logic          --
----------------------------------

-- Find center of a group. modified from St0l3n_ID's funcGroupCenter code
local function funcGroupCenter(tGroup, nMinCount)
    if nMinCount == nil then 
		nMinCount = 1 
	end
     
    if tGroup ~= nil then
        local vGroupCenter = Vector3.Create()
        local nGroupCount = 0 
        for _, unitTarget in pairs(tGroup) do
            vGroupCenter = vGroupCenter + unitTarget:GetPosition()
            nGroupCount = nGroupCount + 1
        end
         
        if nGroupCount < nMinCount then
            return nil
        else
            return vGroupCenter / nGroupCount
        end
    else
        return nil
    end
end

-- Returns the radius of Cull
local function getCullRadius()
	return 300
end

---------------------------------------------
--          Burning Shadows Logic          --
---------------------------------------------

-- Retruns the best direction to cast Burning Shadows at the target from the bots current position
local function getBurningShadowsCastDirection(unitTarget)
	local vecTargetPosition = unitTarget:GetPosition()
	local vecDirection = nil
	
	if unitTarget.bIsMemoryUnit then
		if unitTarget.storedTime + 200 < HoN.GetGameTime() then
			local vecTargetHeading = Vector3.Normalize(unitTarget.storedPosition - vecTargetPosition)
			if vecTargetHeading then
				vecDirection = Vector3.Normalize(vecTargetPosition + vecTargetHeading * 25 - core.unitSelf:GetPosition())
			end
		end
	end
	
	return vecDirection
end

-- Returns the total range of Burning Shadows
local function getBurningShadowsTotalRange()
	return 800
end

------------------------------------------
--          Deep Shadows Logic          --
------------------------------------------

-- Returns the best location to place Deep Shadows when retreating
local function getDeepShadowsRetreatPosition()
	local unitSelf = core.unitSelf
	local vecCurrentPosition = unitSelf:GetPosition()
	local vecDeepShadowsPosition = nil
	
	if unitSelf.bIsMemoryUnit then
		if unitSelf.storedTime + 200 < HoN.GetGameTime() then
			local vecMovementDirection = Vector3.Normalize(vecCurrentPosition - unitSelf.storedPosition)
			if vecMovementDirection then
				vecDeepShadowsPosition = vecCurrentPosition + vecMovementDirection * 320
			end
		end
	else
		vecDeepShadowsPosition = vecCurrentPosition
	end

	return vecDeepShadowsPosition
end

-- Returns the Radius of Deep Shadows
local function getDeepShadowsRadius()
	return 300
end

---------------------------------------
--          Harass Behavior          --
---------------------------------------

local function HarassHeroExecuteOverride(botBrain)
    
    local unitTarget = behaviorLib.heroTarget
    if unitTarget == nil then
        return object.harassExecuteOld(botBrain)
    end
    
    local unitSelf = core.unitSelf
    local vecMyPosition = unitSelf:GetPosition() 
    local nAttackRange = core.GetAbsoluteAttackRangeToUnit(unitSelf, unitTarget)
    local nMyExtraRange = core.GetExtraRange(unitSelf)
    
    local vecTargetPosition = unitTarget:GetPosition()
    local nTargetExtraRange = core.GetExtraRange(unitTarget)
    local nTargetDistanceSq = Vector3.Distance2DSq(vecMyPosition, vecTargetPosition)
    
    local nLastHarassUtility = behaviorLib.lastHarassUtil
    local bCanSee = core.CanSeeUnit(botBrain, unitTarget)    
    local bActionTaken = false
	
	-- Stop the bot from trying to harass heroes while dead
	if not bActionTaken and not unitSelf:IsAlive() then
		bActionTaken = true
	end
	
	-- Illusions
	funcIllusionLogic(botBrain, unitTarget)

	-- Don't cast spells or use items to break stealth from Reflection
	if unitSelf:HasState("State_Fade_Ability4_Stealth") then
        bActionTaken = core.OrderAttackClamp(botBrain, unitSelf, unitTarget)
	end
	
	-- Bottle
	if not bActionTaken then
		core.FindItems()
		local itemBottle = core.itemBottle
		if itemBottle then
			-- Use if the bot has an offensive rune bottled
			if useBottlePowerup(itemBottle, nTargetDistanceSq) then
				bActionTaken = core.OrderItemClamp(botBrain, unitSelf, itemBottle)
			elseif getBottleCharges(itemBottle) > 0 and not unitSelf:HasState("State_Bottle") then
				-- Use if we need mana and it is safe to drink
				local nCurTimeMS = HoN.GetGameTime()
				if unitSelf:GetManaPercent() < .2 and (not (eventsLib.recentDotTime > nCurTimeMS) or not (#eventsLib.incomingProjectiles["all"] > 0)) then
					bActionTaken = core.OrderItemClamp(botBrain, unitSelf, itemBottle)
				end
			end
		end
	end
	
	-- Reflection
	if not bActionTaken then
		local abilReflection = skills.abilReflection
		if abilReflection:CanActivate() and nLastHarassUtility > object.nReflectionThreshold then
			if unitSelf:GetMana() > 390 or unitTarget:GetHealthPercent() < .125 then
				bActionTaken = core.OrderAbility(botBrain, abilReflection)
			end
		end
	end

	-- Hellflower
	if not bActionTaken then
		local bTargetDisabled = unitTarget:IsStunned() or unitTarget:IsSilenced()
		if not bTargetDisabled then
			core.FindItems()
			local itemHellflower = core.itemHellflower
			if itemHellflower then
				if itemHellflower:CanActivate() and nLastHarassUtility > object.nHellflowerThreshold then
					local nRange = itemHellflower:GetRange()
					if nTargetDistanceSq < (nRange * nRange) then
						bActionTaken = core.OrderItemEntityClamp(botBrain, unitSelf, itemHellflower, unitTarget)
					end
				end
			end
		end
	end

	-- Burning Shadows
	if not bActionTaken then
		if not unitTarget:IsStunned() then
			local abilBurningShadows = skills.abilBurningShadows
			if abilBurningShadows:CanActivate() and nLastHarassUtility > object.nBurningShadowsThreshold then
				local nTotalRange = getBurningShadowsTotalRange()
				if nTargetDistanceSq < ((nTotalRange - 40) * (nTotalRange - 40)) then
					local nCastRange = abilBurningShadows:GetRange()
					-- If the target is in range cast on target otherwise cast towards them
					if nTargetDistanceSq < (nCastRange * nCastRange) then
						bActionTaken = core.OrderAbilityEntity(botBrain, abilBurningShadows, unitTarget)
					else
						local vecTargetDirection = getBurningShadowsCastDirection(unitTarget)
						if vecTargetDirection then
							bActionTaken = core.OrderAbilityPosition(botBrain, abilBurningShadows, vecMyPosition + vecTargetDirection * 500)
						end
					end
				end
			end
		end
	end
	
	-- Cull
	if not bActionTaken then
		local abilCull = skills.abilCull
		if abilCull:CanActivate() and nLastHarassUtility > object.nCullThreshold then
			local nRadius = getCullRadius()
			if nTargetDistanceSq < ((nRadius - 20) * (nRadius - 20)) then
				bActionTaken = core.OrderAbility(botBrain, abilCull)
			end
		end
	end
	
	-- Codex
	if not bActionTaken then
		core.FindItems()
		local itemCodex = core.itemCodex
		if itemCodex then
			if itemCodex:CanActivate() and nLastHarassUtility > object.nCodexThreshold then
				if unitTarget:GetHealthPercent() > .075 then
					bActionTaken = core.OrderItemEntityClamp(botBrain, unitSelf, itemCodex, unitTarget)
				end
			end
		end
	end
	
	-- Sheepstick
	if not bActionTaken then
		local bTargetDisabled = unitTarget:IsStunned() or unitTarget:IsSilenced()
		if not bTargetDisabled then
			core.FindItems()
			local itemSheepstick = core.itemSheepstick
			if itemSheepstick then
				if itemSheepstick:CanActivate() and nLastHarassUtility > object.nSheepstickThreshold then
					local nRange = itemSheepstick:GetRange()
					if nTargetDistanceSq < (nRange * nRange) then
						bActionTaken = core.OrderItemEntityClamp(botBrain, unitSelf, itemSheepstick, unitTarget)
					end
				end
			end
		end
	end
	
	-- Deep Shadows
	if not bActionTaken then
		local abilDeepShadows = skills.abilDeepShadows
		if abilDeepShadows:CanActivate() and nLastHarassUtility > object.nDeepShadowsThreshold then
			local nRange = abilDeepShadows:GetRange()
			local nRadius = getDeepShadowsRadius()
			if nTargetDistanceSq < ((nRange + nRadius - 30) * (nRange + nRadius - 30)) then
				local vecTargetDirection = Vector3.Normalize(vecTargetPosition - vecMyPosition)
				if vecTargetDirection then
					-- If the enemy is in range cast behind them, otherwise cast at max range
					if nTargetDistanceSq < ((nRange - 80) * (nRange - 80)) then
						bActionTaken = core.OrderAbilityPosition(botBrain, abilDeepShadows, vecTargetPosition + vecTargetDirection * 80)
					else
						bActionTaken = core.OrderAbilityPosition(botBrain, abilDeepShadows, vecMyPosition + vecTargetDirection * nRange)
					end
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

--------------------------------------------------
--          RetreatFromThreat Override          --
--------------------------------------------------

function funcRetreatFromThreatExecuteOverride(botBrain)
	local bActionTaken = false
	local unitSelf = core.unitSelf

	-- Use Deep Shadows to retreat
	if not bActionTaken then
		if not unitSelf:HasState("State_Fade_Ability4_Stealth") then
			local abilDeepShadows = skills.abilDeepShadows
			if abilDeepShadows:CanActivate() then
				if core.NumberElements(core.localUnits["EnemyHeroes"]) > 0 then
					if unitSelf:GetHealthPercent() < .70 then
						local vecPosition = getDeepShadowsRetreatPosition()
						if vecPosition then
							bActionTaken = core.OrderAbilityPosition(botBrain, abilDeepShadows, vecPosition)
						end
					end
				end
			end
		end
	end
	
	-- Use Reflection to retreat
	if not bActionTaken then
		local abilReflection = skills.abilReflection
		if abilReflection:CanActivate() then
			if core.NumberElements(core.localUnits["EnemyHeroes"]) > 0 then
				if unitSelf:GetHealthPercent() < .55 then
					bActionTaken = core.OrderAbility(botBrain, abilReflection)
				end
			end
		end
	end
	
	if not bActionTaken then
		return object.RetreatFromThreatExecuteOld(botBrain)
	end
end

object.RetreatFromThreatExecuteOld = behaviorLib.RetreatFromThreatExecute
behaviorLib.RetreatFromThreatBehavior["Execute"] = funcRetreatFromThreatExecuteOverride

-------------------------------------------------
--          HealAtWellExecute Overide          --
-------------------------------------------------

local function HealAtWellOveride(botBrain)
    local bActionTaken = false
    local unitSelf = core.unitSelf
    local abilDeepShadows = skills.abilDeepShadows
	
	-- Use Deep Shadows on way to well
	if not bActionTaken then
		if not unitSelf:HasState("State_Fade_Ability4_Stealth") then
			local abilDeepShadows = skills.abilDeepShadows
			if abilDeepShadows:CanActivate() then
				local unitAllyWell = core.allyWell
				if unitAllyWell then
					local nWellDistanceSq = Vector3.Distance2DSq(unitSelf:GetPosition(), unitAllyWell:GetPosition())
					if nWellDistanceSq > (1000 * 1000) then
						local vecPosition = getDeepShadowsRetreatPosition()
						if vecPosition then
							bActionTaken = core.OrderAbilityPosition(botBrain, abilDeepShadows, vecPosition)
						end
					end
				end
			end
		end
	end
 
	-- Use Bottle at well
 	if not bActionTaken then
		core.FindItems()
		local itemBottle = core.itemBottle
		if itemBottle then
			if not unitSelf:HasState("State_Bottle") then
				if getBottleCharges(itemBottle) > 0 then
					local unitAllyWell = core.allyWell
					if unitAllyWell then
						local nWellDistanceSq = Vector3.Distance2DSq(unitSelf:GetPosition(), unitAllyWell:GetPosition())
						if nWellDistanceSq < (400 * 400) then
							bActionTaken = core.OrderItemClamp(botBrain, unitSelf, itemBottle)
						end
					end
				end
			end
		end
	end
 
    if not bActionTaken then
        return object.HealAtWellBehaviorOld(botBrain)
    end
end

object.HealAtWellBehaviorOld = behaviorLib.HealAtWellBehavior["Execute"]
behaviorLib.HealAtWellBehavior["Execute"] = HealAtWellOveride

-------------------------------------------
--          PushExecute Overide          --
-------------------------------------------

-- These are modified from fane_maciuca's Rhapsody Bot
function AbilityPush(botBrain)
	local bActionTaken = false
	local unitSelf = core.unitSelf
	local nMinimumCreeps = 3
	
	-- Stop the bot from trying to farm creeps if the creeps approach the spot where the bot died
	if not unitSelf:IsAlive() then
		return bActionTaken
	end

	-- Use Cull to farm creeps if the bot has enough mana
	local abilCull = skills.abilCull
	if abilCull:CanActivate() and unitSelf:GetManaPercent() > .40 then
		local vecCenter = funcGroupCenter(core.localUnits["EnemyCreeps"], nMinimumCreeps)
		if vecCenter then
			local nDistanceToCenterSq = Vector3.Distance2DSq(unitSelf:GetPosition(), vecCenter)
			-- If the bot is too far away then move closer
			if nDistanceToCenterSq < (20 * 20) then
				bActionTaken = core.OrderAbility(botBrain, abilCull)
			else
				bActionTaken = core.OrderMoveToPosClamp(botBrain, unitSelf, vecCenter)
			end
		end
	end

	return bActionTaken
end

local function PushExecuteOverride(botBrain)
	if not AbilityPush(botBrain) then 
		return object.PushExecuteOld(botBrain)
	end
end

object.PushExecuteOld = behaviorLib.PushBehavior["Execute"]
behaviorLib.PushBehavior["Execute"] = PushExecuteOverride

local function TeamGroupBehaviorOverride(botBrain)
	if not AbilityPush(botBrain) then 
		return object.TeamGroupBehaviorOld(botBrain)
	end
end

object.TeamGroupBehaviorOld = behaviorLib.TeamGroupBehavior["Execute"]
behaviorLib.TeamGroupBehavior["Execute"] = TeamGroupBehaviorOverride

BotEcho(object:GetName()..' finished loading Fayde_main')