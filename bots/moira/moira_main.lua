local _G = getfenv(0)
local object = _G.object

object.myName = object:GetName()

object.bRunLogic	 = true
object.bRunBehaviors	= true
object.bUpdates 		= true
object.bUseShop 		= true

object.bRunCommands 	= true 
object.bMoveCommands	 = true
object.bAttackCommands	 = true
object.bAbilityCommands = true
object.bOtherCommands	 = true

object.bReportBehavior = false
object.bDebugUtility = false

object.logger = {}
object.logger.bWriteLog = false
object.logger.bVerboseLog = false

object.core 		= {}
object.eventsLib	 = {}
object.metadata 	= {}
object.behaviorLib	 = {}
object.skills   	  = {}

runfile "bots/core.lua"
runfile "bots/botbraincore.lua"
runfile "bots/eventsLib.lua"
runfile "bots/metadata.lua"
runfile "bots/behaviorLib.lua"

local core, eventsLib, behaviorLib, metadata, skills = object.core, object.eventsLib, object.behaviorLib, object.metadata, object.skills
local illusionLib = object.illusionLib or {}

local print, ipairs, pairs, string, table, next, type, tinsert, tremove, tsort, format, tostring, tonumber, strfind, strsub
	= _G.print, _G.ipairs, _G.pairs, _G.string, _G.table, _G.next, _G.type, _G.table.insert, _G.table.remove, _G.table.sort, _G.string.format, _G.tostring, _G.tonumber, _G.string.find, _G.string.sub
local ceil, floor, pi, tan, atan, atan2, abs, cos, sin, acos, max, random
	= _G.math.ceil, _G.math.floor, _G.math.pi, _G.math.tan, _G.math.atan, _G.math.atan2, _G.math.abs, _G.math.cos, _G.math.sin, _G.math.acos, _G.math.max, _G.math.random

local BotEcho, VerboseLog, BotLog = core.BotEcho, core.VerboseLog, core.BotLog
local Clamp = core.Clamp

BotEcho(object:GetName() .. " loading moira...")



-- TODO(S)
-- Find out why findMimic() does not exist until first reloadbots
--
--
--
--
--
--
--
--
--











---------------------------------------------------------
--                   CONSTANTS                         --
---------------------------------------------------------

object.heroName = "Hero_Moira"


core.tLanePreferences = {Jungle = 0, Mid = 3, ShortSolo = 3, LongSolo = 2, ShortSupport = 4, LongSupport = 4, ShortCarry = 2, LongCarry = 2}

--just for me to remember it
local cyclone = "Item_Intelligence6"


behaviorLib.StartingItems  = {"Item_RunesOfTheBlight", "Item_DuckBoots", "Item_Scarab"}
behaviorLib.LaneItems  = {"Item_Marchers", "Item_EnhancedMarchers"}
behaviorLib.MidItems  = {cyclone, "Item_Nuke 3", "Item_Morph"}
behaviorLib.LateItems  = {"Item_Nuke 5", "Item_Dawnbringer", "Item_Damage9"}


object.tSkills = {
	0, 1, 0, 2, 0,
	3, 0, 2, 2, 2,
	3, 1, 1, 1, 4,
	3, 4, 4, 4, 4,
	4, 4, 4, 4, 4,
}

-- This is the real deal, core.unitSelf is going to change to run default behaviors for the mimic
object.unitHero = nil



--local tDefaultBehaviors = behaviorLib.tBehaviors

--Check from this list instead when mimic is functional
--local tMimicBehaviors = {}

--tholds & up values
object.nManaburnUpBonus = 10
object.nStunUpBonus = 15

object.nStunThreshold = 40
object.nManaburnThreshold = 50
object.nUltThreshold = 70

object.nDisableTreshold = 45

object.nIlluUseBonus = 20
object.nStunUseBonus = 15
object.nManaburnUseBonus = 15
object.nUltUseBonus = 20

--Illusion of 3rd skill nil if not exist or channeling ended early
object.unitMoiraMimic = nil

------------------
-- Misc Helpers --
------------------

-- Both must be before OnThink or are nil ... dont ask why
function behaviorLib.IsMimic()
	local mimic = object.unitMoiraMimic
	return mimic ~= nil and mimic:IsValid() and core.unitSelf:GetUniqueID() == mimic:GetUniqueID()
end

function object.findMimic()
	if core.tControllableUnits == nil then
		return nil
	end
	if not object.unitHero:IsChanneling() then
		return nil
	end
	for _, illu in pairs(core.tControllableUnits["InventoryUnits"]) do
		if illu:IsValid() and illu:HasState("State_Moira_Ability3_Mimic") then
			if object.unitMoiraMimic == nil then
				core.tFoundItems = {} --revalidate items
				object.unitMoiraMimic = illu
			end
			return illu
		end
	end
	if object.unitMoiraMimic ~= nil then
		object.unitMoiraMimic = nil
		core.tFoundItems = {} --revalidate items
	end
	return nil
end

------------------------------
--	 skills   			--
------------------------------
function object:SkillBuild()
	local unitSelf = self.unitHero
	-- Skill of the real hero
	-- Mimic can not use these. They still can be used to check for cd
	if  skills.abilStun == nil then
		skills.abilStun = unitSelf:GetAbility(0)
		skills.abilManaburn = unitSelf:GetAbility(1)
		skills.abilIllu = unitSelf:GetAbility(2)
		skills.abilBlackHole = unitSelf:GetAbility(3)
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

function object:onthinkOverride(tGameVariables)
	if object.unitHero == nil or not object.unitHero:IsValid() then
		--init
		object.unitHero = self:GetHeroUnit()
	end

	if core.botBrainInitialized then
		-- game is running
		local mimic = object.findMimic()
		if mimic ~= nil then
			core.unitSelf = mimic
		else
			core.unitSelf = self.unitHero
		end
	end
	self:onthinkOld(tGameVariables)
end
object.onthinkOld = object.onthink
object.onthink 	= object.onthinkOverride


function object:oncombateventOverride(EventData)
	self:oncombateventOld(EventData)

	local nAddBonus = 0
	if EventData.Type == "Ability" then
		if EventData.InflictorName == "Ability_Moira1" then
			nAddBonus = nAddBonus + object.nStunUseBonus
		elseif EventData.InflictorName == "Ability_Moira4" then
			nAddBonus = nAddBonus + object.nUltUseBonus
		end
	end

	if nAddBonus > 0 then
		core.DecayBonus(self)
		core.nHarassBonus = core.nHarassBonus + nAddBonus
	end
end
object.oncombateventOld = object.oncombatevent
object.oncombatevent 	= object.oncombateventOverride

function behaviorLib.CustomHarassUtility(hero)
	local nReturnValue = 0
	
	local unitSelf = core.unitSelf
	if skills.abilStun:CanActivate() then
		nReturnValue = nReturnValue + object.nStunUpBonus
	end
	
	if skills.abilManaburn:CanActivate() then
		nReturnValue = nReturnValue + object.nManaburnUpBonus
	end

	-- Less mana less aggerssion
	nReturnValue = nReturnValue + (unitSelf:GetManaPercent() - 1) * 20

	return nReturnValue

end

local function HarassHeroExecuteOverride(botBrain)
	local unitSelf = core.unitSelf
	if unitSelf:IsChanneling() or unitSelf:IsStunned() then
		return true
	end
	local vecMyPosition = unitSelf:GetPosition()

	local unitTarget = behaviorLib.heroTarget
	if unitTarget == nil or not unitTarget:IsValid() then
		return false --Target is invalid, move on to the next behavior
	end

	local vecTargetPosition = unitTarget:GetPosition()
	local nTargetDistanceSq = Vector3.Distance2DSq(vecMyPosition, vecTargetPosition)

	if not core.CanSeeUnit(botBrain, unitTarget) then
		if skills.abilIllu:CanActivate() then
			local vecDesiredPosition = vecTargetPosition + Vector3.Normalize(vecTargetPosition - vecMyPosition) * 400
			return core.OrderAbilityPosition(botBrain, skills.abilIllu, vecDesiredPosition)
		end
		return object.harassExecuteOld(botBrain)
	end

	if not isMimic and nTargetDistanceSq > 1200*1200 and skills.abilIllu:CanActivate() then
		return core.OrderAbilityPosition(botBrain, skills.abilIllu, vecTargetPosition + unitTarget:GetHeading() * unitTarget:GetMoveSpeed())
	end

	local bTargetMagicImmune = unitTarget:isMagicImmune()

	local nLastHarassUtility = behaviorLib.lastHarassUtil

	local bActionTaken = false

	if nLastHarassUtility > object.nStunThreshold and not bTargetMagicImmune then
		local stun = unitSelf:GetAbility(0)
		if stun:CanActivate() then
			local allyTarget = nil
			if nTargetDistanceSq < 550 * 550 then
				allyTarget = unitSelf
			else
				for _, unit in pairs(core.localUnits.AllyHeroes) do
					if Vector3.Distance2DSq(vecTargetPosition, unit:GetPosition()) < 550 * 550 then
						allyTarget = unit
					end
				end
			end
			if allyTarget ~= nil then
				bActionTaken = core.OrderAbilityEntity(botBrain, stun, unitSelf)
			end
		end
	end

	if not bActionTaken then
		if nLastHarassUtility > object.nManaburnThreshold and not bTargetMagicImmune then
			local manaburn = unitSelf:GetAbility(1)
			if manaburn:CanActivate() then
				bActionTaken = core.OrderAbilityEntity(botBrain, manaburn, unitTarget)
			end
		end
	end

	if not bActionTaken and not unitTarget:IsStunned() then
		if object.nDisableTreshold < nLastHarassUtility then
			local itemMorph = core.GetItem("Item_Morph")
			if itemMorph and itemMorph:CanActivate() then
				botBrain:OrderItemEntity(itemMorph.object or itemMorph, unitTarget.object or unitTarget)
				bActionTaken = true
			end
		end
	end

	if not bActionTaken then
		if core.NumberElements(core.localUnits.EnemyHeroes) > 1 then
			local nTargetID = unitTarget:GetUniqueID()
			for _, enemy in pairs(core.localUnits.EnemyHeroes) do
				if enemy:GetUniqueID() ~= nTargetID then
					bActionTaken = core.OrderAbilityPosition(botBrain, unitSelf:GetAbility(3), enemy:GetPosition())
				end
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

----------------------
-- 'gank' with illu --
----------------------
function behaviorLib.IlluGankUtility(botBrain)
	if behaviorLib.IsMimic() then
		return 0
	end

	if not skills.abilIllu:CanActivate() then
		return 0
	end

	if core.NumberElements(core.localUnits.EnemyHeroes) ~= 0 then
		return 0
	end

	local nIlluRange = skills.abilIllu:GetRange()

	local unitSelf = core.unitSelf
	local vecMyPosition = unitSelf:GetPosition()

	--local nSkillsUpBonus = behaviorLib.CustomHarassUtility()
	local nMyMana = unitSelf:GetManaPercent()
	local manaBonus = 20 - (nMyMana ^ 2) * 30

	nUtility = 0
	unitTarget = nil
	for _, enemy in pairs(core.teamBotBrain.tEnemyHeroes) do
		if enemy:IsAlive() and core.CanSeeUnit(botBrain, enemy) then
			local nDistanceSQ = Vector3.Distance2DSq(vecMyPosition, enemy:GetPosition())
			if nDistanceSQ < nIlluRange * nIlluRange and nDistanceSQ > 1200 * 1200 then
				local enemyHealt = enemy:GetHealthPercent()
				newUtility = ((1 - enemyHealt) ^ 2) * 40 + manaBonus
				if newUtility > nUtility then
					nUtility = newUtility
					unitTarget = enemy
				end
			end
		end
	end
	if unitTarget ~= nil then
		behaviorLib.heroTarget = unitTarget
		return nUtility
	else
		return 0
	end
end

behaviorLib.IlluGankBehavior = {}
behaviorLib.IlluGankBehavior["Utility"] = behaviorLib.IlluGankUtility
behaviorLib.IlluGankBehavior["Execute"] = behaviorLib.HarassHeroBehavior["Execute"]
behaviorLib.IlluGankBehavior["Name"] = "Moira gank with illu"
tinsert(behaviorLib.tBehaviors, behaviorLib.IlluGankBehavior)


function object.UseSkillsDefensively(botBrain, ally)
	local unitSelf = core.unitSelf
	local ally = ally or unitSelf
	local bActionTaken = false
	local nUtility = behaviorLib.lastRetreatUtil
	if behaviorLib.nAllyHelpUtility > nUtility then
		nUtility = behaviorLib.nAllyHelpUtility
	end

	for _, enemy in pairs(core.localUnits.EnemyHeroes) do
		if not enemy:IsInvulnerable() or not enemy:IsStunned() and not enemy:isMagicImmune() then
			if nUtility > object.nDisableTreshold then
				local stormspirit = core.GetItem(cyclone)
				if stormspirit ~= nil and stormspirit:CanActivate() then
					botBrain:OrderItemEntity(stormspirit.object or stormspirit, enemy.object or enemy)
					bActionTaken = true
				end

				if not bActionTaken then
					local itemMorph = core.GetItem("Item_Morph")
					if itemMorph ~= nil and itemMorph:CanActivate() then
						botBrain:OrderItemEntity(itemMorph.object or itemMorph, enemy.object or enemy)
						bActionTaken = true
					end
				end
			end

			if not bActionTaken then
				if nUtility > object.nStunThreshold then
					local stun = unitSelf:GetAbility(0)
					if stun:CanActivate() then
						bActionTaken = core.OrderAbilityEntity(botBrain, stun, ally)
					end
				end
			end

			if not bActionTaken then
				if nUtility > object.nUltThreshold then
					local vecEnemyPos = enemy:GetPosition()
					if Vector3.Distance2DSq(ally:GetPosition(), vecEnemyPos) > 90000 then
						bActionTaken = core.OrderAbilityPosition(botBrain, unitSelf:GetAbility(3), vecEnemyPos)
					end
				end
			end

			if bActionTaken then
				break
			end
		end
	end
	return bActionTaken

end

behaviorLib.CustomRetreatExecute = object.UseSkillsDefensively


function behaviorLib.StopChannelUtility(botBrain)
	if not behaviorLib.IsMimic() then
		return 0
	end

	if not object.unitHero:HasState("State_Moira_Ability3_Self") then
		-- atleast channel first 2 secs
		return 0
	end
	if object.findMimic() == nil then
		-- if mimic dies, manualy stop channel
		return 100
	end

	BotEcho("cancel mimic")

	local nearEnemies = 0
	local heroesInRange = HoN.GetUnitsInRadius(object.unitHero:GetPosition(), 1000, core.UNIT_MASK_ALIVE + core.UNIT_MASK_HERO)
	for _, hero in pairs(heroesInRange) do
		if hero:GetTeam() == core.enemyTeam then
			nearEnemies = nearEnemies + 1
		end
	end
	BotEcho("Stop channel utility: EnemyHeroes:" .. tostring(30 * nearEnemies) .. " Recent Damage: " .. tostring(eventsLib.recentDamageSec / object.unitHero:GetMaxHealth() * 100))
	return 30 * nearEnemies + eventsLib.recentDamageSec / object.unitHero:GetMaxHealth() * 1000
end

function behaviorLib.StopChannelExecute(botBrain)
	return core.OrderStop(botBrain, object.unitHero)
end

behaviorLib.StopChannelBehavior = {}
behaviorLib.StopChannelBehavior["Utility"] = behaviorLib.StopChannelUtility
behaviorLib.StopChannelBehavior["Execute"] = behaviorLib.StopChannelExecute
behaviorLib.StopChannelBehavior["Name"] = "Moira stop channel"
tinsert(behaviorLib.tBehaviors, behaviorLib.StopChannelBehavior)


---------------
-- Help ally --
---------------

behaviorLib.unitHelpAlly = nil
behaviorLib.nAllyHelpUtility = 0
function behaviorLib.HelpAllyUtility(botBrain)
	local unitSelf = core.unitSelf

	local nUtility = 0
	local ally = nil
	--local mimicID = object.unitMoiraMimic and object.unitMoiraMimic:GetUniqueID()
	--local isIllu = unitSelf:GetUniqueID() == mimicID
	local vecMyPosition = unitSelf:GetPosition()
	local nLocalEnemies = core.NumberElements(core.localUnits.EnemyHeroes)

	local abilIllu = skills.abilIllu
	local nCastRange = abilIllu:GetRange()
	local bMimicUp = abilIllu:CanActivate()

	for _, unit in pairs(core.teamBotBrain.tAllyHeroes) do
		local nHPPercent = unit:GetHealthPercent()
		local nSelfID = unitSelf:GetUniqueID()
		if unit:IsAlive() and unit:GetUniqueID() ~= nSelfID then
			if nHPPercent < 0.8 then
				local vecUnitPosition = unit:GetPosition()
				local nDistanceSQ = Vector3.Distance2DSq(vecUnitPosition, vecMyPosition)
				if nDistanceSQ < 1200*1200 or (bMimicUp and nLocalEnemies == 0 and nDistanceSQ < nCastRange * nCastRange) then
					local nNewUtility = (1 - nHPPercent) * 30
					local heroesInRange = HoN.GetUnitsInRadius(vecUnitPosition, 1200, core.UNIT_MASK_ALIVE + core.UNIT_MASK_HERO)
					local nEnemyHeroes = 0
					for _, hero in pairs(heroesInRange) do
						if hero:GetTeam() == core.enemyTeam then
							nEnemyHeroes = nEnemyHeroes + 1
						end
					end
					if nEnemyHeroes ~= 0 then
						nNewUtility = nNewUtility + 13 * nEnemyHeroes
						if nNewUtility > nUtility then
							nUtility = nNewUtility
							ally = unit
						end
					end
				end
			end
		end
	end

	behaviorLib.unitHelpAlly = ally
	behaviorLib.nAllyHelpUtility = nUtility
	return nUtility
end

function behaviorLib.HelpAllyExecute(botBrain)
	local unitHero = object.unitHero
	if unitHero:IsChanneling() and core.unitSelf:GetUniqueID() == unitHero:GetUniqueID() then
		return true
	end

	local vecAllyPos = behaviorLib.unitHelpAlly:GetPosition()
	local abilIllu = skills.abilIllu
	if abilIllu:CanActivate() and Vector3.Distance2DSq(vecAllyPos, core.unitSelf:GetPosition()) > 1200*1200 then
		return core.OrderAbilityPosition(botBrain, abilIllu, vecAllyPos)
	end

	local bActionTaken = object.UseSkillsDefensively(botBrain, behaviorLib.unitHelpAlly)

	if not bActionTaken then
		if Vector3.Distance2DSq(core.unitSelf:GetPosition(), vecAllyPos) > 350 * 350 then
			bActionTaken = core.OrderMoveToPos(botBrain, core.unitSelf, vecAllyPos)
		end
	end

	--todo autoattack
	return true
end

behaviorLib.HelpAllyBehavior = {}
behaviorLib.HelpAllyBehavior["Utility"] = behaviorLib.HelpAllyUtility
behaviorLib.HelpAllyBehavior["Execute"] = behaviorLib.HelpAllyExecute
behaviorLib.HelpAllyBehavior["Name"] = "Moira help ally"
tinsert(behaviorLib.tBehaviors, behaviorLib.HelpAllyBehavior)


--------------------
-- Misc Overrides --
--------------------

-- Mimic cant tp
function behaviorLib.ShouldPortOverride(botBrain, vecDesiredPosition)
	local mimicID = object.unitMoiraMimic and object.unitMoiraMimic:GetUniqueID()
	if core.unitSelf:GetUniqueID() == mimicID then
		return false, nil, nil
	end
	return behaviorLib.ShouldPortOld(botBrain, vecDesiredPosition)
end

behaviorLib.ShouldPortOld = behaviorLib.ShouldPort
behaviorLib.ShouldPort = behaviorLib.ShouldPortOverride

-- Mimic doesnt buy, would break the shopping system
function ShopUtilityOverride(botBrain)
	if object.unitMoiraMimic ~= nil and core.unitSelf:GetUniqueID() == object.unitMoiraMimic:GetUniqueID() then
		return 0
	end
	return object.ShopUtilityOld(botBrain)
end

object.ShopUtilityOld = behaviorLib.ShopBehavior["Utility"]
behaviorLib.ShopBehavior["Utility"] = ShopUtilityOverride

-- not to include mimic here nor the real one when mimic is unitSelf
function illusionLib.updateIllusions(botBrain)
	illusionLib.tIllusions = {}
	local tPossibleIllusions = core.tControllableUnits["InventoryUnits"]
	if tPossibleIllusions ~= nil then
		local mimicID = object.unitMoiraMimic and object.unitMoiraMimic:GetUniqueID()
		local moiraID = object.unitHero:GetUniqueID()
		for nUID, unit in pairs(tPossibleIllusions) do
			if unit:IsHero() and nUID ~= mimicID and nUID ~= moiraID then
				tinsert(illusionLib.tIllusions, unit)
			end
		end
	end
end

-- Overriding teambot GetDesiredLane
-- Why isn't it per player in the first place
local teambot = HoN.GetTeamBotBrain()
teambot.GetDesiredLane = function(self, unitAsking)
	if unitAsking then
		local player = unitAsking:GetOwnerPlayerID()
		hero = nil
		for _, unit in pairs(self.tAllyHeroes) do
			if player == unit:GetOwnerPlayerID() then
				hero = unit
			end
		end

		local nUniqueID
		if hero == nil then
			nUniqueID = unitAsking:GetUniqueID()
		else
			nUniqueID = hero:GetUniqueID()
		end
		
		if self.tTopLane[nUniqueID] then
			return metadata.GetTopLane()
		elseif self.tMiddleLane[nUniqueID] then
			return metadata.GetMiddleLane()
		elseif self.tBottomLane[nUniqueID] then
			return metadata.GetBottomLane()
		elseif self.tJungle[nUniqueID] then
			--Jungle doesn't have a lane, but to stop other parts of the code failing, use a dummy lane.
			--With the lane name 'jungle', so we can use core.tMyLane.sLaneName == 'jungle' to know whether we are jungle or not.	
			local jungleLane = core.CopyTable(metadata.GetMiddleLane())
			jungleLane.sLaneName = 'jungle'
			return jungleLane
		end

		BotEcho("Couldn't find a lane for unit: "..tostring(unitAsking)..'  name: '..unitAsking:GetTypeName()..'  id: '..nUniqueID)
		self.teamBotBrainInitialized = false	
	else
		BotEcho("Couldn't find a lane for unit: nil")
	end	
	
	return nil
end
