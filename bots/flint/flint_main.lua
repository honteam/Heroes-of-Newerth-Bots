--FlintBot v1.0


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

BotEcho('loading flint_main...')

--------------------------------
-- Lanes
--------------------------------
core.tLanePreferences = {Jungle = 0, Mid = 4, ShortSolo = 4, LongSolo = 2, ShortSupport = 2, LongSupport = 1, ShortCarry = 5, LongCarry = 5}

object.heroName = 'Hero_FlintBeastwood'

--------------------------------
-- Skills
--------------------------------
local bSkillsValid = false
function object:SkillBuild()	
	local unitSelf = self.core.unitSelf

	if not bSkillsValid then
		skills.flare		= unitSelf:GetAbility(0)
		skills.hollowpoint	= unitSelf:GetAbility(1)
		skills.deadeye		= unitSelf:GetAbility(2)
		skills.moneyshot	= unitSelf:GetAbility(3)
		skills.attributeBoost = unitSelf:GetAbility(4)
		
		if skills.flare and skills.hollowpoint and skills.deadeye and skills.moneyshot and skills.attributeBoost then
			bSkillsValid = true
		else
			return
		end
	end	
	
	if unitSelf:GetAbilityPointsAvailable() <= 0 then
		return
	end
	
	--speicific level 1 skill
	if skills.hollowpoint:GetLevel() < 1 then
		skills.hollowpoint:LevelUp()
	--max in this order {ult, flare, deadeye, hollowpoint, stats}
	elseif skills.moneyshot:CanLevelUp() then
		skills.moneyshot:LevelUp()
	elseif skills.flare:CanLevelUp() then
		skills.flare:LevelUp()
	elseif skills.deadeye:CanLevelUp() then
		skills.deadeye:LevelUp()
	elseif skills.hollowpoint:CanLevelUp() then
		skills.hollowpoint:LevelUp()
	else
		skills.attributeBoost:LevelUp()
	end	
end


---------------------------------------------------
--                   Overrides                   --
---------------------------------------------------

--[[for testing
function object:onthinkOverride(tGameVariables)
	self:onthinkOld(tGameVariables)
	
	core.unitSelf:TeamShare()
	
	-- Insert code here
end
object.onthinkOld = object.onthink
object.onthink 	= object.onthinkOverride
--]]


----------------------------------
--	Flint specific harass bonuses
--
--  Abilities off cd increase harass util
--  Ability use increases harass util for a time
----------------------------------

object.flareUpBonus = 10
object.ultUpBonus = 50

object.flareUseBonus = 15

local function AbilitiesUpUtilityFn()
	local val = 0
	
	if skills.flare:CanActivate() then
		val = val + object.flareUpBonus
	end
	
	if skills.moneyshot:CanActivate() then
		val = val + object.ultUpBonus
	end
	
	return val
end

--Flint ability use gives bonus to harass util for a while
function object:oncombateventOverride(EventData)
	self:oncombateventOld(EventData)
	
	local addBonus = 0
	
	if EventData.Type == "Ability" then
		--BotEcho("ABILILTY EVENT!  InflictorName: "..EventData.InflictorName)		
		if EventData.InflictorName == "Ability_FlintBeastwood1" then
			addBonus = addBonus + object.flareUseBonus
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

--Util calc override
local function CustomHarassUtilityOverride(hero)
	local nUtility = AbilitiesUpUtilityFn()
	
	return nUtility
end
behaviorLib.CustomHarassUtility = CustomHarassUtilityOverride  

--HarassHeroUtility override
local function HarassHeroUtilityOverride(botBrain)
	--Flint's ult has a larger range than the default "local units" target gathering range of 1250 (or 
	--	whatever core.localCreepRange is). This means we have to temporarally override that table so 
	--	we consider all units that are in his (extended) range
	
	local oldHeroes = core.localUnits["EnemyHeroes"]
		
	local abilMoneyShot = skills.moneyshot
	local nRange = abilMoneyShot:GetRange()
	
	if nRange > core.localCreepRange and abilMoneyShot:CanActivate() then
		local vecMyPosition = core.unitSelf:GetPosition()		
		local tAllHeroes = HoN.GetUnitsInRadius(vecMyPosition, nRange, core.UNIT_MASK_ALIVE + core.UNIT_MASK_HERO)
		local tEnemyHeroes = {}
		local nEnemyTeam = core.enemyTeam
		for key, hero in pairs(tAllHeroes) do
			if hero:GetTeam() == nEnemyTeam then
				tinsert(tEnemyHeroes, hero)
			end
		end
		
		core.teamBotBrain:AddMemoryUnitsToTable(tEnemyHeroes, nEnemyTeam, vecMyPosition, nRange)
		core.localUnits["EnemyHeroes"] = tEnemyHeroes
	end
	
	local nUtility = object.HarassHeroUtilityOld(botBrain)	
	
	core.localUnits["EnemyHeroes"] = oldHeroes
	return nUtility
end
object.HarassHeroUtilityOld = behaviorLib.HarassHeroBehavior["Utility"] 
behaviorLib.HarassHeroBehavior["Utility"]  = HarassHeroUtilityOverride 

----------------------------------
--	Flint specific building attack
----------------------------------

local function HitBuildingExecuteOverride(botBrain)
	--BotEcho('Derp')
	local bDebugLines = false
	local lineLen = 150
	
	local bActionTaken = false
	
	local abilFlare = skills.flare
	local nFlareLevel = abilFlare:GetLevel()
	
	local nFlareBuildingDamage = 25
	if nFlareLevel == 2 then
		nFlareBuildingDamage = 50
	elseif nFlareLevel == 3 then
		nFlareBuildingDamage = 75
	elseif nFlareLevel == 4 then
		nFlareBuildingDamage = 100
	end
	
	local bShouldFlare = false	
	local unitTarget = nil
	
	if abilFlare:CanActivate() then
		local tEnemyBuildings = core.localUnits.EnemyBuildings
		for key, building in pairs(tEnemyBuildings) do
			if botBrain:CanSeeUnit(building) then
				if not building:IsInvulnerable() and building:GetHealth() < nFlareBuildingDamage then
					unitTarget = building
					bShouldFlare = true
					break
				end
			end
		end
	end
	
	if bShouldFlare then
		local unitSelf = core.unitSelf
		local nFlareRange = abilFlare:GetRange() + core.GetExtraRange(unitSelf) + core.GetExtraRange(unitTarget)
		
		local vecTargetPosition = unitTarget:GetPosition()
		local vecMyPosition = unitSelf:GetPosition()
		
		if Vector3.Distance2DSq(vecTargetPosition, vecMyPosition) > (nFlareRange * nFlareRange) then
			--BotEcho("Move in to flare!")
			core.OrderMoveToPosClamp(botBrain, unitSelf, vecTargetPosition, false)
			bActionTaken = true
		else
			--BotEcho("Flarin!")
			bActionTaken = core.OrderAbilityPosition(botBrain, abilFlare, vecTargetPosition)
		end		
	end
	
	if not bActionTaken then
		object.HitBuildingExecuteOld(botBrain)
	end
end
object.HitBuildingExecuteOld = behaviorLib.HitBuildingBehavior["Execute"]
behaviorLib.HitBuildingBehavior["Execute"] = HitBuildingExecuteOverride

----------------------------------
--	Flint harass actions
----------------------------------
local function HarassHeroExecuteOverride(botBrain)
	local unitTarget = behaviorLib.heroTarget
	if unitTarget == nil or not unitTarget:IsValid() then
		return false -- we can't procede, reassess behaviors
	end
	
	local vecTargetPos = unitTarget:GetPosition()
	
	local unitSelf = core.unitSelf
	local bCanSee = core.CanSeeUnit(botBrain, unitTarget)
	
	local bActionTaken = false
	
	local nDistanceSq = Vector3.Distance2DSq(unitSelf:GetPosition(), vecTargetPos)
	
	--money shot
	if not bActionTaken and bCanSee then
		--ult only if it will kill our enemy
		local abilMoneyShot = skills.moneyshot
		local nRange = abilMoneyShot:GetRange() + core.GetExtraRange(unitSelf) + core.GetExtraRange(unitTarget)

		if abilMoneyShot:CanActivate() and nDistanceSq < (nRange * nRange) then
			local nLevel = abilMoneyShot:GetLevel()
			local nDamage = 355
			if nLevel == 2 then
				nDamage = 505
			elseif nLevel == 3 then
				nDamage = 655
			end
			
			local nHealth = unitTarget:GetHealth()
			local nDamageMultiplier = 1 - unitTarget:GetMagicResistance()
			local nTrueDamage = nDamage * nDamageMultiplier
			local bUseMoneyShot = ((core.nDifficulty ~= core.nEASY_DIFFCULTY) 
								or (unitTarget:IsBotControlled() and nTrueDamage > nHealth) 
								or (not unitTarget:IsBotControlled() and nHealth - nTrueDamage >= nMaxHealth * 0.12))
			
			--BotEcho(format("ultDamage: %d  damageMul: %g  trueDmg: %g  health: %d", nDamage, nDamageMultiplier, nTrueDamage, nHealth))
			if bUseMoneyShot then
				bActionTaken = core.OrderAbilityEntity(botBrain, abilMoneyShot, unitTarget)
			end
		end
	end
	
	--flare
	if not bActionTaken then
		--TODO: consider updating with thresholds on flare
		local abilFlare = skills.flare
		local nRange = abilFlare:GetRange() + core.GetExtraRange(unitSelf) + core.GetExtraRange(unitTarget)		
		local nFlareCost = abilFlare:GetManaCost()
		
		local bShouldFlare = false 
		local bFlareUsable = abilFlare:CanActivate() and nDistanceSq < (nRange * nRange)
				
		if bFlareUsable then
			local abilMoneyShot = skills.moneyshot
			if abilMoneyShot:CanActivate() then
				--don't flare if it means we can't ult
				local nMoneyShotCost = abilMoneyShot:GetManaCost()
				if unitSelf:GetMana() - nMoneyShotCost > nFlareCost then
					bShouldFlare = true
				end
			else
				bShouldFlare = true
			end				
		end
		
		if bShouldFlare then
			bActionTaken = core.OrderAbilityPosition(botBrain, abilFlare, vecTargetPos)
		end
	end
	
	if not bActionTaken then
		return object.harassExecuteOld(botBrain)
	end
end
object.harassExecuteOld = behaviorLib.HarassHeroBehavior["Execute"]
behaviorLib.HarassHeroBehavior["Execute"] = HarassHeroExecuteOverride


----------------------------------
--	Flint items
----------------------------------
--[[ list code:
	"# Item" is "get # of these"
	"Item #" is "get this level of the item" --]]
behaviorLib.StartingItems = {"2 Item_DuckBoots", "2 Item_MinorTotem", "Item_HealthPotion", "Item_RunesOfTheBlight"}
behaviorLib.LaneItems = {"Item_Marchers", "Item_IronShield", "Item_Steamboots"}
behaviorLib.MidItems = {"Item_Stealth", "Item_Immunity", "Item_Pierce 3"} --Pierce is Shieldbreaker, Immunity is Shrunken Head
behaviorLib.LateItems = {"Item_Weapon3", "Item_Warpcleft", "Item_Lightning2", "Item_BehemothsHeart", 'Item_Damage9'} --Weapon3 is Savage Mace. Lightning2 is Charged Hammer. Item_Damage9 is Doombringer



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

BotEcho('finished loading flint_main')
