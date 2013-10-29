local object = _G.object
local core, eventsLib, behaviorLib, metadata = object.core, object.eventsLib, object.behaviorLib, object.metadata
local print, ipairs, pairs, string, table, next, type, tinsert, tremove, tsort, format, tostring, tonumber, strfind, strsub
	= _G.print, _G.ipairs, _G.pairs, _G.string, _G.table, _G.next, _G.type, _G.table.insert, _G.table.remove, _G.table.sort, _G.string.format, _G.tostring, _G.tonumber, _G.string.find, _G.string.sub
local ceil, floor, pi, tan, atan, atan2, abs, cos, sin, acos, max, random
	= _G.math.ceil, _G.math.floor, _G.math.pi, _G.math.tan, _G.math.atan, _G.math.atan2, _G.math.abs, _G.math.cos, _G.math.sin, _G.math.acos, _G.math.max, _G.math.random
local BotEcho, VerboseLog, BotLog = core.BotEcho, core.VerboseLog, core.BotLog
local Clamp = core.Clamp

--this is so that developers can tell this code to ignore certain items they have written bot-specific code for.
behaviorLib.tDontUseDefaultItemBehavior = {}

function behaviorLib.addCurrentItemBehaviors()  --run on initialization, too add current item behaviors.
	local inventory = core.unitSelf:GetInventory(false)
	for slot = 1, 6 do
		local curItem = inventory[slot]
		if curItem then
			behaviorLib.addItemBehavior(curItem:GetName(), false)
		end
	end
end

	
function behaviorLib.addItemBehavior(itemName, remove)
	local bDebugEchos = false
	
	-- Ignore items on our ignore list
	if core.tableContains(behaviorLib.tDontUseDefaultItemBehavior, itemName) > 0 then
		if bDebugEchos then BotEcho("^rDisabled "..itemName) end
		return
	end
	
	remove = (remove == nil and false) or remove
	behaviorLib.behaviorToModify = nil
	
	if itemName == "Item_Replenish" then
		behaviorLib.behaviorToModify = behaviorLib.RingOfSorceryBehavior
	elseif itemName == "Item_ManaPotion" then
		behaviorLib.behaviorToModify = behaviorLib.UseManaPotBehavior
	elseif itemName == "Item_Bottle" then
		behaviorLib.behaviorToModify = behaviorLib.UseBottleBehavior
	elseif itemName == "Item_HealthPotion" then
		behaviorLib.behaviorToModify = behaviorLib.UseHealthPotBehavior
	elseif itemName == "Item_RunesOfTheBlight" then
		behaviorLib.behaviorToModify = behaviorLib.UseRunesOfTheBlightBehavior
	elseif (itemName == "Item_ManaBattery" or itemName == "Item_PowerSupply") then
		behaviorLib.behaviorToModify = behaviorLib.UseBatterySupplyBehavior
	elseif itemName == "Item_Astrolabe" then
		behaviorLib.behaviorToModify = behaviorLib.AstrolabeBehavior
	elseif itemName == "Item_SacrificialStone" then
		behaviorLib.behaviorToModify = behaviorLib.SacrificialStoneBehavior
	elseif itemName == "Item_BloodChalice" then
		behaviorLib.behaviorToModify = behaviorLib.BloodChaliceBehavior
	elseif itemName == "Item_Lightning2" then
		behaviorLib.behaviorToModify = behaviorLib.ChargedHammerBehavior
	elseif itemName == "Item_ElderParasite" then
		behaviorLib.behaviorToModify = behaviorLib.ElderParasiteBehavior
	elseif itemName == "Item_Stealth" then
		behaviorLib.behaviorToModify = behaviorLib.AssassinsShroudBehavior
	elseif itemName == "Item_Immunity" then
		behaviorLib.behaviorToModify = behaviorLib.ShrunkenHeadBehavior
	elseif itemName == "Item_ManaBurn2" then
		behaviorLib.behaviorToModify = behaviorLib.GeomancersBehavior
	end
	
	
	if behaviorLib.behaviorToModify ~= nil then
		if remove then
			if core.RemoveByValue(behaviorLib.tBehaviors, behaviorLib.behaviorToModify) then
				if bDebugEchos then BotEcho("^rRemoved "..itemName) end
			else
				BotEcho("^rFailed to remove "..itemName.." from behaviours!?") --this is an error we should know about.
			end
		elseif core.tableContains(behaviorLib.tBehaviors, behaviorLib.behaviorToModify) == 0 then
			tinsert(behaviorLib.tBehaviors, behaviorLib.behaviorToModify)
			if bDebugEchos then BotEcho("^gadded "..itemName) end
		else
			--BotEcho("^rBehavior exists.. ")
		end
	end
end


----------------------------------
--  Behaviors start below!
----------------------------------


----------------------------------
--  Ring of Sorcery behavior by Kairus101
--  
--  Utility: 
--  Execute: Use Ring of Sorcery
----------------------------------
--each drained mana pool is worth 25 utility
function behaviorLib.RingOfSorceryUtility(botBrain)
	local unitSelf = core.unitSelf
	local vecMyPosition = unitSelf:GetPosition()
	behaviorLib.itemRingOfSorcery = core.GetItem("Item_Replenish")
	local nUtility = 0
	
	if behaviorLib.itemRingOfSorcery and behaviorLib.itemRingOfSorcery:CanActivate() then
		nUtility = (1 - unitSelf:GetManaPercent()) * 25 --this bots mana pool
		local tTargets = core.localUnits["AllyHeroes"]  -- Get allies close to the bot
		for key, hero in pairs(tTargets) do
			local nRoSRange = 700
			if (Vector3.Distance2DSq(vecMyPosition, hero:GetPosition()) < nRoSRange * nRoSRange) then
				nUtility = nUtility + (1 - hero:GetManaPercent()) * 25 --another bots mana pool
			end
		end		
		return nUtility
	end
	return 0
end

function behaviorLib.RingOfSorceryExecute(botBrain)
	local unitSelf = core.unitSelf
	return core.OrderItemClamp(botBrain, unitSelf, behaviorLib.itemRingOfSorcery) -- Use Ring of Sorcery
end

behaviorLib.RingOfSorceryBehavior = {}
behaviorLib.RingOfSorceryBehavior["Utility"] = behaviorLib.RingOfSorceryUtility
behaviorLib.RingOfSorceryBehavior["Execute"] = behaviorLib.RingOfSorceryExecute
behaviorLib.RingOfSorceryBehavior["Name"] = "RingOfSorcery"


--------------------------------------
--  			UseRegen   		 --
--------------------------------------
-------- Global Constants & Variables --------
behaviorLib.bUseBatterySupplyForHealth = true
behaviorLib.bUseBatterySupplyForMana = true
behaviorLib.bUseBottleForHealth = true
behaviorLib.bUseBottleForMana = true
behaviorLib.safeTreeAngle = 120
-------- Helper Functions --------
function behaviorLib.GetSafeDrinkDirection()
	-- Returns vector to a safe direciton to retreat to drink if the bot is threatened
	-- Returns nil if safe
	local vecSafeDirection = nil
	local unitSelf = core.unitSelf
	local vecSelfPos = unitSelf:GetPosition()
	local nMyID = unitSelf:GetUniqueID()
	local tThreateningUnits = {}
	local tUnitThreatenedRadius = {}
	
	for _, unitEnemy in pairs(core.localUnits["EnemyUnits"]) do
		-- Ignore creeps that are already attacking something
		local unitEnemyTarget = unitEnemy:GetAttackTarget()
		if not (core.IsLaneCreep(unitEnemy) and unitEnemyTarget and unitEnemyTarget:GetUniqueID() ~= nMyID) then
			local nAbsRange = core.GetAbsoluteAttackRangeToUnit(unitEnemy, unitSelf) + 325
			local nAbsRangeSq = nAbsRange * nAbsRange
			local nDistSq = Vector3.Distance2DSq(vecSelfPos, unitEnemy:GetPosition())
			if nDistSq < nAbsRangeSq then
				tinsert(tThreateningUnits, unitEnemy)
				tinsert(tUnitThreatenedRadius, nAbsRange)
			end
		end
	end

	local curTimeMS = HoN.GetGameTime()
	local nThreateningUnits = core.NumberElements(tThreateningUnits)
	if nThreateningUnits > 0 or eventsLib.recentDotTime > curTimeMS or #eventsLib.incomingProjectiles["all"] > 0 then
		-- Determine best "away from threat" vector
		local vecAway = Vector3.Create()
		for nIndex, unitEnemy in pairs(tThreateningUnits) do
			local vecAwayFromTarget = Vector3.Normalize(vecSelfPos - unitEnemy:GetPosition())
			vecAway = vecAway + vecAwayFromTarget * tUnitThreatenedRadius[nIndex]
		end
		
		-- Average vecAway with "retreat" vector
		local vecRetreat = Vector3.Normalize(behaviorLib.PositionSelfBackUp() - vecSelfPos)
		local vecSafeDirection = Vector3.Normalize(vecAway + vecRetreat)
	end

	return vecSafeDirection
end

------------------------------------
--  		Mana Potion 		  --
------------------------------------
function behaviorLib.UseManaPotUtility(botBrain)
	-- Roughly 20 + when we are missing 100 mana
	-- Function which crosses 20 at x = 100 and 30 at x = 200, convex down
	
	local unitSelf = core.unitSelf
	behaviorLib.itemManaPot = core.GetItem("Item_ManaPotion")
	
	if behaviorLib.itemManaPot and not unitSelf:HasState("State_ManaPotion") then	
		local nManaMissing = unitSelf:GetMaxMana() - unitSelf:GetMana()
		local nManaRegen = unitSelf:GetManaRegen()
		local nManaRegenAmount = 100
		local nManaBuffer = nManaRegen * 20
		local nUtilityThreshold = 20
		
		local vecPoint = Vector3.Create(nManaRegenAmount, nUtilityThreshold)
		local vecOrigin = Vector3.Create(-100, -45)
		
		return core.ATanFn(nManaMissing, vecPoint, vecOrigin, 100)
	elseif not behaviorLib.itemManaPot then
		behaviorLib.addItemBehavior("Item_ManaPotion", true)
	end
	
	return 0
end

function behaviorLib.UseManaPotExecute(botBrain)
	local bActionTaken = false
	local unitSelf = core.unitSelf
	local vecSelfPos = unitSelf:GetPosition()
	
	if behaviorLib.itemManaPot then
		local vecRetreatDirection = behaviorLib.GetSafeDrinkDirection()
		-- Check if it is safe to drink
		if vecRetreatDirection then
			bActionTaken = core.OrderMoveToPosClamp(botBrain, unitSelf, vecSelfPos + vecRetreatDirection * core.moveVecMultiplier, false)
		else
			bActionTaken = core.OrderItemEntityClamp(botBrain, unitSelf, behaviorLib.itemManaPot, unitSelf)
		end
	end
		
	return bActionTaken
end

behaviorLib.UseManaPotBehavior = {}
behaviorLib.UseManaPotBehavior["Utility"] = behaviorLib.UseManaPotUtility
behaviorLib.UseManaPotBehavior["Execute"] = behaviorLib.UseManaPotExecute
behaviorLib.UseManaPotBehavior["Name"] = "UseManaPot"

------------------------------------

--  		   Bottle   		  --
------------------------------------
function behaviorLib.BottleHealthUtilFn(nHealthMissing, nHealthRegen)
	-- Roughly 20 + when we are missing 135 hp
	-- Function which crosses 20 at x = 135 and 30 at x = 220, convex down
	if (not behaviorLib.bUseBottleForHealth) then
		return 0
	end
	
	local nHealAmount = 135
	local nHealBuffer = nHealthRegen * 3
	local nUtilityThreshold = 20

	local vecPoint = Vector3.Create(nHealAmount + nHealBuffer, nUtilityThreshold)
	local vecOrigin = Vector3.Create(-100, -30)
	
	return core.ATanFn(nHealthMissing, vecPoint, vecOrigin, 100)
end

function behaviorLib.BottleManaUtilFn(nManaMissing, nManaRegen)
	-- Roughly 20 + when we are missing 70 mana
	-- Function which crosses 20 at x = 70 and 30 at x = 140, convex down
	if (not behaviorLib.bUseBottleForMana) then
		return 0
	end
	
	local nManaRegenAmount = 70
	local nManaBuffer = nManaRegen * 3
	local nUtilityThreshold = 20
	
	local vecPoint = Vector3.Create(nManaRegenAmount + nManaBuffer, nUtilityThreshold)
	local vecOrigin = Vector3.Create(-125, -30)
	
	return core.ATanFn(nManaMissing, vecPoint, vecOrigin, 100)
end

function behaviorLib.UseBottleUtility(botBrain)
	local unitSelf = core.unitSelf
	local nHealthMissing = unitSelf:GetMaxHealth() - unitSelf:GetHealth()
	local nManaMissing = unitSelf:GetMaxMana() - unitSelf:GetMana()
	local nHealthRegen = unitSelf:GetHealthRegen()
	local nManaRegen = unitSelf:GetManaRegen()
	behaviorLib.itemBottle = core.GetItem("Item_Bottle")
	
	if behaviorLib.itemBottle and not unitSelf:HasState("State_Bottle") and behaviorLib.itemBottle:GetActiveModifierKey() ~= "bottle_empty" then
		local nBottleHealthFn = behaviorLib.BottleHealthUtilFn(nHealthMissing, nHealthRegen)
		local nBottleManaFn = behaviorLib.BottleManaUtilFn(nManaMissing, nManaRegen)
		
		return max(
			nBottleHealthFn * .8 + nBottleManaFn * .2, --health
			nBottleManaFn * .8 + nBottleHealthFn * .2  --mana
			)
	end
	
	return 0
end

function behaviorLib.UseBottleExecute(botBrain)
	local bActionTaken = false
	local unitSelf = core.unitSelf

	if not core.IsTableEmpty(tItemBottle) then
		local vecRetreatDirection = behaviorLib.GetSafeDrinkDirection()
		-- Check if it is safe to drink
		if vecRetreatDirection then
			bActionTaken = core.OrderMoveToPosClamp(botBrain, unitSelf, vecSelfPos + vecRetreatDirection * core.moveVecMultiplier, false)
		else
			bActionTaken = core.OrderItemClamp(botBrain, unitSelf, behaviorLib.itemBottle)
		end
	end
	
	return bActionTaken
end

behaviorLib.UseBottleBehavior = {}
behaviorLib.UseBottleBehavior["Utility"] = behaviorLib.UseBottleUtility
behaviorLib.UseBottleBehavior["Execute"] = behaviorLib.UseBottleExecute
behaviorLib.UseBottleBehavior["Name"] = "UseBottle"

------------------------------------
--  		Health Potion   	  --
------------------------------------
function behaviorLib.UseHealthPotUtility(botBrain)
	-- Roughly 20 + when we are missing 400 hp
	-- Function which crosses 20 at x = 400 and 40 at x = 650, convex down

	local unitSelf = core.unitSelf
	behaviorLib.itemHealthPot = core.GetItem("Item_HealthPotion")
	
	if behaviorLib.itemHealthPot and not unitSelf:HasState("State_HealthPotion") then	
		local nHealthMissing = unitSelf:GetMaxHealth() - unitSelf:GetHealth()
		local nHealthRegen = unitSelf:GetHealthRegen()
		local nHealAmount = 400
		local nHealBuffer = nHealthRegen * 10
		local nUtilityThreshold = 20
		
		local vecPoint = Vector3.Create(nHealAmount, nUtilityThreshold)
		local vecOrigin = Vector3.Create(200, -40)
		return core.ATanFn(nHealthMissing, vecPoint, vecOrigin, 100)
	elseif not behaviorLib.itemHealthPot then
		behaviorLib.addItemBehavior("Item_HealthPotion", true)
	end
	return 0
end

function behaviorLib.UseHealthPotExecute(botBrain)
	local bActionTaken = false
	local unitSelf = core.unitSelf
	local vecSelfPos = unitSelf:GetPosition()
	
	if behaviorLib.itemHealthPot then
		local vecRetreatDirection = behaviorLib.GetSafeDrinkDirection()
		-- Check if it is safe to drink
		if vecRetreatDirection then
			bActionTaken = core.OrderMoveToPosClamp(botBrain, unitSelf, vecSelfPos + vecRetreatDirection * core.moveVecMultiplier, false)
		else
			bActionTaken = core.OrderItemEntityClamp(botBrain, unitSelf, behaviorLib.itemHealthPot, unitSelf)
		end
	end
	return bActionTaken
end

behaviorLib.UseHealthPotBehavior = {}
behaviorLib.UseHealthPotBehavior["Utility"] = behaviorLib.UseHealthPotUtility
behaviorLib.UseHealthPotBehavior["Execute"] = behaviorLib.UseHealthPotExecute
behaviorLib.UseHealthPotBehavior["Name"] = "UseHealthPot"


------------------------------------
--  	 Runes OfThe Blight 	  --
------------------------------------
function behaviorLib.UseRunesOfTheBlightUtility(botBrain)
	-- Roughly 20 + when we are missing 115 hp
	-- Function which crosses 20 at x = 115 and is 30 at roughly x = 600, convex down

	local unitSelf = core.unitSelf
	local tInventory = unitSelf:GetInventory()
	behaviorLib.itemBlights = core.GetItem("Item_RunesOfTheBlight")
	
	if behaviorLib.itemBlights and not unitSelf:HasState("State_RunesOfTheBlight") then
		local unitSelf = core.unitSelf
		local nHealthMissing = unitSelf:GetMaxHealth() - unitSelf:GetHealth()
		local nHealthRegen = unitSelf:GetHealthRegen()
		local nHealAmount = 115
		local nHealBuffer = nHealthRegen * 16
		local nUtilityThreshold = 20
			
		local vecPoint = Vector3.Create(nHealAmount + nHealBuffer, nUtilityThreshold)
		local vecOrigin = Vector3.Create(-1000, -20)
		
		return core.ATanFn(nHealthMissing, vecPoint, vecOrigin, 100)
	elseif not behaviorLib.itemBlights then
		behaviorLib.addItemBehavior("Item_RunesOfTheBlight", true)
	end
	
	return 0
end

function behaviorLib.UseRunesOfTheBlightExecute(botBrain)
	local unitSelf = core.unitSelf
	local vecSelfPos = unitSelf:GetPosition()
	local bActionTaken = false
	local unitClosestTree = nil
	local nClosestTreeDistSq = 9999 * 9999
	local vecLaneForward = object.vecLaneForward
	local vecLaneForwardNeg = -vecLaneForward
	local funcRadToDeg = core.RadToDeg
	local funcAngleBetween = core.AngleBetween
	local nHalfSafeTreeAngle = behaviorLib.safeTreeAngle / 2

	core.UpdateLocalTrees()
	local tTrees = core.localTrees
	for _, unitTree in pairs(tTrees) do
		vecTreePosition = unitTree:GetPosition()
		-- "Safe" trees are backwards
		if not vecLaneForward or abs(funcRadToDeg(funcAngleBetween(vecTreePosition - vecSelfPos, vecLaneForwardNeg)) ) < nHalfSafeTreeAngle then
			local nDistSq = Vector3.Distance2DSq(vecTreePosition, vecSelfPos)
			if nDistSq < nClosestTreeDistSq then
				unitClosestTree = unitTree
				nClosestTreeDistSq = nDistSq
				if bDebugLines then
					core.DrawXPosition(vecTreePosition, 'yellow')
				end
			end
		end
	end
	if unitClosestTree ~= nil then
		bActionTaken = core.OrderItemEntityClamp(botBrain, unitSelf,  behaviorLib.itemBlights, unitClosestTree)
	end
		
	return bActionTaken
end
behaviorLib.UseRunesOfTheBlightBehavior = {}
behaviorLib.UseRunesOfTheBlightBehavior["Utility"] = behaviorLib.UseRunesOfTheBlightUtility
behaviorLib.UseRunesOfTheBlightBehavior["Execute"] = behaviorLib.UseRunesOfTheBlightExecute
behaviorLib.UseRunesOfTheBlightBehavior["Name"] = "UseRunesOfTheBlight"

------------------------------------
--   Mana Battery/PowerSupply     --
------------------------------------

function behaviorLib.GetBatterySupplyFromInventory()
	-- Returns Mana Battery or Power Supply if they are in the bot's inventory
	-- else returns nil
	
	local unitSelf = core.unitSelf
	local tInventory = unitSelf:GetInventory()
	local tManaBattery = core.InventoryContains(tInventory, "Item_ManaBattery")
	local tPowerSupply = core.InventoryContains(tInventory, "Item_PowerSupply")
	
	if not core.IsTableEmpty(tManaBattery) then
		return tManaBattery[1]
	elseif not core.IsTableEmpty(tPowerSupply) then
		return tPowerSupply[1]
	end
	
	return nil
end

function behaviorLib.BatterySupplyHealthUtilFn(nHealthMissing, nCharges)
	-- With 1 Charge:
	-- Roughly 20 + when we are missing 30 health
	-- Function which crosses 20 at x = 30 and 30 at x = 140, convex down
	-- With 15 Charges:
	-- Roughly 20 + when we are missing 170 health
	-- Function which crosses 20 at x = 170 and 30 at x = 330, convex down
	if (not behaviorLib.bUseBatterySupplyForHealth) then
		return 0
	end
	
	local nHealAmount = 10 * nCharges
	local nHealBuffer = 20
	local nUtilityThreshold = 20
	
	local vecPoint = Vector3.Create(nHealAmount + nHealBuffer, nUtilityThreshold)
	local vecOrigin = Vector3.Create(-250, -30)
	
	return core.ATanFn(nHealthMissing, vecPoint, vecOrigin, 100)
end

function behaviorLib.BatterySupplyManaUtilFn(nManaMissing, nCharges)
	-- With 1 Charge:
	-- Roughly 20 + when we are missing 40 mana
	-- Function which crosses 20 at x = 40 and 30 at x = 100, convex down
	-- With 15 Charges:
	-- Roughly 20 + when we are missing 280 mana
	-- Function which crosses 20 at x = 280 and 30 at x = 470, convex down
	if (not behaviorLib.bUseBatterySupplyForMana) then
		return 0
	end
	
	local nManaRegenAmount = 15 * nCharges
	local nManaBuffer = 25
	local nUtilityThreshold = 20
	
	local vecPoint = Vector3.Create(nManaRegenAmount + nManaBuffer, nUtilityThreshold)
	local vecOrigin = Vector3.Create(-60, -50)
	
	return core.ATanFn(nManaMissing, vecPoint, vecOrigin, 100)
end

function behaviorLib.UseBatterySupplyUtility(botBrain)
	local unitSelf = core.unitSelf
	local nHealthMissing = unitSelf:GetMaxHealth() - unitSelf:GetHealth()
	local nManaMissing = unitSelf:GetMaxMana() - unitSelf:GetMana()
	local itemBatterySupply = behaviorLib.GetBatterySupplyFromInventory()
	
	if itemBatterySupply ~= nil and itemBatterySupply:CanActivate() then
		local nCharges = itemBatterySupply:GetCharges()
		local nBatterySupplyHealthUtility = behaviorLib.BatterySupplyHealthUtilFn(nHealthMissing, nCharges)
		local nBatterySupplyManaUtility = behaviorLib.BatterySupplyManaUtilFn(nManaMissing, nCharges)
		
		return max(
			nBatterySupplyHealthUtility * .8 + nBatterySupplyManaUtility * .2, --health
			nBatterySupplyManaUtility * .8 + nBatterySupplyHealthUtility * .2  --mana
			)
	end
	
	return 0
end

function behaviorLib.UseBatterySupplyExecute(botBrain)
	local unitSelf = core.unitSelf
	local tInventory = unitSelf:GetInventory()
	local bActionTaken = false
	
	-- Use Mana Battery/Power Supply to heal
	local itemBatterySupply = behaviorLib.GetBatterySupplyFromInventory(tInventory)
	if itemBatterySupply:GetCharges() > 0 then
		bActionTaken = core.OrderItemClamp(botBrain, unitSelf, itemBatterySupply)
	end
	
	return bActionTaken
end
behaviorLib.UseBatterySupplyBehavior = {}
behaviorLib.UseBatterySupplyBehavior["Utility"] = behaviorLib.UseBatterySupplyUtility
behaviorLib.UseBatterySupplyBehavior["Execute"] = behaviorLib.UseBatterySupplyExecute
behaviorLib.UseBatterySupplyBehavior["Name"] = "UseBatterySupply"


------------------------------------
--   		  Astrolabe 		  --
------------------------------------

behaviorLib.unitHealTarget = nil
behaviorLib.nHealTimeToLive = nil
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
	return nUtility, nTimeToLive
end

function behaviorLib.AstrolabeUtility(botBrain)
	local bDebugEchos = false
	local nUtility = 0

	local unitSelf = core.unitSelf
	behaviorLib.unitHealTarget = nil
	
	behaviorLib.itemAstrolabe = core.GetItem("Item_Astrolabe")
	
	local nHighestUtility = 0
	local unitTarget = nil
	local nTargetTimeToLive = nil
	local sAbilName = ""
	if behaviorLib.itemAstrolabe and behaviorLib.itemAstrolabe:CanActivate() then
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
			behaviorLib.unitHealTarget = unitTarget
			behaviorLib.nHealTimeToLive = nTargetTimeToLive
		end
	end
	
	nUtility = nUtility * behaviorLib.nHealUtilityMul
	if botBrain.bDebugUtility == true and nUtility ~= 0 then
		BotEcho(format("  HelpUtility: %g", nUtility))
	end
	return nUtility
end

function behaviorLib.AstrolabeExecute(botBrain)
	local unitHealTarget = behaviorLib.unitHealTarget
	local nHealTimeToLive = behaviorLib.nHealTimeToLive
	
	if unitHealTarget then 
		local unitSelf = core.unitSelf
		local vecTargetPosition = unitHealTarget:GetPosition()
		local nDistance = Vector3.Distance2DSq(unitSelf:GetPosition(), vecTargetPosition)
		if nDistance < 500 * 500 then
			core.OrderItemClamp(botBrain, unitSelf, behaviorLib.itemAstrolabe)
		else
			core.OrderMoveToUnitClamp(botBrain, unitSelf, unitHealTarget)
		end
	else
		return false
	end
	
	return true
end

behaviorLib.AstrolabeBehavior = {}
behaviorLib.AstrolabeBehavior["Utility"] = behaviorLib.AstrolabeUtility
behaviorLib.AstrolabeBehavior["Execute"] = behaviorLib.AstrolabeExecute
behaviorLib.AstrolabeBehavior["Name"] = "UseAstrolabe"


------------------------------------
--   	Sacrificial Stone 		  --
------------------------------------

function behaviorLib.SacrificialStoneUtility(botBrain)
	local unitSelf = core.unitSelf
	behaviorLib.itemSacrificialStone = core.GetItem("Item_SacrificialStone")
	if (behaviorLib.itemSacrificialStone and behaviorLib.itemSacrificialStone:CanActivate()) then
		return 100
	else
		return 0
	end
end

function behaviorLib.SacrificialStoneExecute(botBrain)
	local unitSelf = core.unitSelf
	return core.OrderItemClamp(botBrain, unitSelf, behaviorLib.itemSacrificialStone)
end
behaviorLib.SacrificialStoneBehavior = {}
behaviorLib.SacrificialStoneBehavior["Utility"] = behaviorLib.SacrificialStoneUtility
behaviorLib.SacrificialStoneBehavior["Execute"] = behaviorLib.SacrificialStoneExecute
behaviorLib.SacrificialStoneBehavior["Name"] = "UseSacrificialStone"


------------------------------------
--  		Blood Chalice 		  --
------------------------------------
function behaviorLib.BloodChaliceUtility(botBrain)
	local unitSelf = core.unitSelf
	behaviorLib.itemBloodChalice = core.GetItem("Item_BloodChalice")
	if (behaviorLib.itemBloodChalice and behaviorLib.itemBloodChalice:CanActivate()) then
		
		local unitTarget = behaviorLib.heroTarget
		if unitTarget and unitTarget:GetHealthPercent() <= .2 and Vector3.Distance2DSq(unitSelf:GetPosition(), unitTarget:GetPosition()) < (700 * 700) then
			--about to get a kill! Yay! Congrats! Use chalice and reap the benefits of being an AI who has 1200 APM.
			return 100
		end
		if unitSelf:GetManaPercent() < 0.3 and unitSelf:GetHealthPercent() > 0.7 then
			return 100
		end
	end
	return 0
end

function behaviorLib.BloodChaliceExecute(botBrain)
	local unitSelf = core.unitSelf
	return core.OrderItemClamp(botBrain, unitSelf, behaviorLib.itemBloodChalice)
end
behaviorLib.BloodChaliceBehavior = {}
behaviorLib.BloodChaliceBehavior["Utility"] = behaviorLib.BloodChaliceUtility
behaviorLib.BloodChaliceBehavior["Execute"] = behaviorLib.BloodChaliceExecute
behaviorLib.BloodChaliceBehavior["Name"] = "UseBloodChalice"

------------------------------------
--  		Charged Hammer 		  --
------------------------------------
behaviorLib.unitChargedHammerTarget = nil
function behaviorLib.ChargedHammerUtility(botBrain)
	local unitSelf = core.unitSelf
	behaviorLib.itemChargedHammer = core.GetItem("Item_Lightning2")
	if behaviorLib.itemChargedHammer and behaviorLib.itemChargedHammer:CanActivate() and behaviorLib.heroTarget then --only when we have a target
		local tAllyHeroes = HoN.GetHeroes(core.myTeam)
		behaviorLib.unitChargedHammerTarget = unitSelf
		local nRange = behaviorLib.itemChargedHammer:GetRange()
		for i, hero in pairs(tAllyHeroes) do
			--core.DrawDebugArrow(unitSelf:GetPosition(), hero:GetPosition(), 'white')
			local nDistanceSq = Vector3.Distance2DSq(unitSelf:GetPosition(), hero:GetPosition())
			if hero:IsValid() and hero:IsAlive() and not hero:HasState("State_Item5C") and behaviorLib.unitChargedHammerTarget:GetHealthPercent() > hero:GetHealthPercent() and nDistanceSq < nRange * nRange then
				behaviorLib.unitChargedHammerTarget = hero
			end
		end
		if behaviorLib.unitChargedHammerTarget ~= nil then
			--core.DrawDebugArrow(unitSelf:GetPosition(), behaviorLib.unitChargedHammerTarget:GetPosition(), 'green')
			return Clamp(80 - behaviorLib.unitChargedHammerTarget:GetHealthPercent() * 100, 0, 100)
		end
	end
	return 0
end

function behaviorLib.ChargedHammerExecute(botBrain)
	local unitSelf = core.unitSelf
	return core.OrderItemEntityClamp(botBrain, unitSelf, behaviorLib.itemChargedHammer, behaviorLib.unitChargedHammerTarget, false)
end
behaviorLib.ChargedHammerBehavior = {}
behaviorLib.ChargedHammerBehavior["Utility"] = behaviorLib.ChargedHammerUtility
behaviorLib.ChargedHammerBehavior["Execute"] = behaviorLib.ChargedHammerExecute
behaviorLib.ChargedHammerBehavior["Name"] = "UseChargedHammer"

------------------------------------
--  		Elder Parasite		  --
------------------------------------
behaviorLib.nElderParasiteThreshhold = 30
behaviorLib.nElderParasiteRetreatThreshold = 50
function behaviorLib.ElderParasiteUtility(botBrain)
	local unitSelf = core.unitSelf
	behaviorLib.itemElderParasite = core.GetItem("Item_ElderParasite")
	if behaviorLib.itemElderParasite and behaviorLib.itemElderParasite:CanActivate() and not unitSelf:IsImmobilized() and not unitSelf:IsStunned() then
		--offensive
		if (behaviorLib.lastHarassUtil > behaviorLib.nElderParasiteThreshhold) and behaviorLib.heroTarget then	--only when we have a target
			return 100
		end
		--defensive
		if behaviorLib.lastRetreatUtil >= behaviorLib.nElderParasiteRetreatThreshold and (core.GetLastBehaviorName(botBrain) == "RetreatFromThreat" or core.GetLastBehaviorName(botBrain) == "HealAtWell") then --we are RUNNING FOR OUR LIVES!
			return 100
		end
	end
	return 0
end

function behaviorLib.ElderParasiteExecute(botBrain)
	local unitSelf = core.unitSelf
	return core.OrderItemClamp(botBrain, unitSelf, behaviorLib.itemElderParasite)
end
behaviorLib.ElderParasiteBehavior = {}
behaviorLib.ElderParasiteBehavior["Utility"] = behaviorLib.ElderParasiteUtility
behaviorLib.ElderParasiteBehavior["Execute"] = behaviorLib.ElderParasiteExecute
behaviorLib.ElderParasiteBehavior["Name"] = "UseElderParasite"

------------------------------------
--  	  Assassins Shroud		  --
------------------------------------
behaviorLib.nAssassinsShroudThreshhold = 50
behaviorLib.nAssassinsShroudRetreatThreshhold = 50
function behaviorLib.AssassinsShroudUtility(botBrain)
	local unitSelf = core.unitSelf
	behaviorLib.itemAssassinsShroud = core.GetItem("Item_Stealth")
	if behaviorLib.itemAssassinsShroud and behaviorLib.itemAssassinsShroud:CanActivate() then
		--offensive
		if (behaviorLib.lastHarassUtil > behaviorLib.nAssassinsShroudThreshhold) and behaviorLib.heroTarget then	--only when we have a target
			return 100
		end
		--defensive
		if behaviorLib.lastRetreatUtil >= behaviorLib.nAssassinsShroudRetreatThreshhold and (core.GetLastBehaviorName(botBrain) == "RetreatFromThreat" or core.GetLastBehaviorName(botBrain) == "HealAtWell") then --we are RUNNING FOR OUR LIVES!
			return 100
		end
	end
	return 0
end

function behaviorLib.AssassinsShroudExecute(botBrain)
	local unitSelf = core.unitSelf
	return core.OrderItemClamp(botBrain, unitSelf, behaviorLib.itemAssassinsShroud)
end
behaviorLib.AssassinsShroudBehavior = {}
behaviorLib.AssassinsShroudBehavior["Utility"] = behaviorLib.AssassinsShroudUtility
behaviorLib.AssassinsShroudBehavior["Execute"] = behaviorLib.AssassinsShroudExecute
behaviorLib.AssassinsShroudBehavior["Name"] = "UseAssassinsShroud"

------------------------------------
--  	   Shrunken Head		  --
------------------------------------
behaviorLib.nShrunkenHeadThreshhold = 70
function behaviorLib.ShrunkenHeadUtility(botBrain)
	local unitSelf = core.unitSelf
	behaviorLib.itemShrunkenHead = core.GetItem("Item_Immunity")
	if behaviorLib.itemShrunkenHead and behaviorLib.itemShrunkenHead:CanActivate() then
		--offensive
		if (behaviorLib.lastHarassUtil > behaviorLib.nShrunkenHeadThreshhold) and behaviorLib.heroTarget then	--only when we have a target
			return 100
		end
		--defensive
		--possibility to have it cast on retreat, however due to game mechanics, I would consider this a bad move.
	end
	return 0
end

function behaviorLib.ShrunkenHeadExecute(botBrain)
	local unitSelf = core.unitSelf
	return core.OrderItemClamp(botBrain, unitSelf, behaviorLib.itemShrunkenHead)
end
behaviorLib.ShrunkenHeadBehavior = {}
behaviorLib.ShrunkenHeadBehavior["Utility"] = behaviorLib.ShrunkenHeadUtility
behaviorLib.ShrunkenHeadBehavior["Execute"] = behaviorLib.ShrunkenHeadExecute
behaviorLib.ShrunkenHeadBehavior["Name"] = "UseShrunkenHead"

------------------------------------
--  	   Geomancers Bane		  --
------------------------------------
behaviorLib.nGeomancersThreshhold = 40
behaviorLib.nGeomancersRetreatThreshhold = 50
function behaviorLib.GeomancersUtility(botBrain)
	local unitSelf = core.unitSelf
	behaviorLib.itemGeomancers = core.GetItem("Item_ManaBurn2")
	if behaviorLib.itemGeomancers and behaviorLib.itemGeomancers:CanActivate() then
		--offensive
		if (behaviorLib.lastHarassUtil > behaviorLib.nGeomancersThreshhold) and behaviorLib.heroTarget then	--only when we have a target
			return 100
		end
		--defensive
		if behaviorLib.lastRetreatUtil >= behaviorLib.nGeomancersRetreatThreshhold and (core.GetLastBehaviorName(botBrain) == "RetreatFromThreat" or core.GetLastBehaviorName(botBrain) == "HealAtWell") then --we are RUNNING FOR OUR LIVES!
			return 100
		end
	end
	return 0
end

function behaviorLib.GeomancersExecute(botBrain)
	local unitSelf = core.unitSelf
	return core.OrderItemClamp(botBrain, unitSelf, behaviorLib.itemGeomancers)
end
behaviorLib.GeomancersBehavior = {}
behaviorLib.GeomancersBehavior["Utility"] = behaviorLib.GeomancersUtility
behaviorLib.GeomancersBehavior["Execute"] = behaviorLib.GeomancersExecute
behaviorLib.GeomancersBehavior["Name"] = "UseGeomancers"
