--[[
Name: Advanced Shopping Library
Current Version: 1.0
Creator: Schnarchnase

Overview:
	This library will advance the bots shopping system.

Features:
	ItemHandler:
		-no need for find-items
		-call items by name and unit
		-easier inventory tests
		
	ShoppingHandler:
		-Bots can use the courier
		-Bots can take care of the courier (upgrade it, rebuy if it dies)
		-Bots can reserve items (don't go for team items, if the team has one already or another bot reserved it)
		-Bots can buy consumables periodically or on demand
		-dynamic item builds supported
		-desired item slots supported (e.g.: if bot has boots, put them in slot 1)

Tip: 
	Take a look at the WitchSlayer-Bot to setting your shopping experience!

Usage:
	Underneath the other runfiles:
		runfile "bots/advancedShopping.lua"
		
	Set references:
		local itemHandler = object.itemHandler
		local shopping = object.shoppingHandler
	
	Use of ItemHandler:
		itemHandler:GetItem(sItemName, unit)
		itemHandler:GetItem("Item_Astrolabe")
		itemHandler:GetItem("Item_LoggersHatchet", unitBooboo)
		
	Set up your preferences:
		default setup options:
			tSetupOptions = {
				bReserveItems 			= true,	-- true or false
				bWaitForLaneDecision 	= false,-- true or false
				tConsumableOptions		={		
					Item_HomecomingStone	= true,-- true or false
					Item_HealthPotion		= true,-- true or false
					Item_RunesOfTheBlight	= true,-- true or false
					Item_ManaPotion			= true -- true or false
				},								--{}, true or false
				bCourierCare			= false	-- true or false
			}
		
		you only need to insert differences to default (same object structure)
		shopping.setup (tSetupOptions)
		
		Example:		
			This bot will support his team, so he should upgrade the courier, 
			buy wards, but he shouldn't buy any Mana Potions
		
			--Implement changes to default settings
			local tSetupOptions = {
					bCourierCare = true, --upgrade courier
					bWaitForLaneDecision = true, --wait for lane decision before shopping
					tConsumableOptions = {Item_ManaPotion = false} --don't autobuy Mana Potions
					}
			--call setup function
			shopping.Setup(tSetupOptions)
		----------------------------------------------------------------
	
	ReloadBots compatibility: (Set to true while testing)
		shopping.bDevelopeItemBuildSaver = false
		
	Set desired item slots:
		shopping.SetItemSlotNumber(sItemName, nSlotNumber)
		shopping.SetItemSlotNumber("Item_FlamingEye", 4)
	
	Request Consumables:
		shopping.RequestConsumable (sItemName, nNumber)
		shopping.RequestConsumable ("Item_FlamingEye", 5)
	
	Dynamic item builds (Take a look at WitchSlayer):
		Override 
			shopping.CheckItemBuild()
	
	Manually upgrade courier:
		shopping.DoCourierUpgrade(courier, currentGold)
		
	Misc.:
		shopping.nSellBonusValue = 2000 --Add to sell cost to prevent selling of desired items
		shopping.nMaxHealthTreshold = 1000 --max Health for buying potions
		shopping.nMaxManaTreshold = 350 -- max Mana for buying potions
	
--]]

local _G = getfenv(0)
local object = _G.object

-- Shopping and itemHandler Position 
object.itemHandler = object.itemHandler or {}
object.itemHandler.tItems = object.itemHandler.tItems or {}
object.shoppingHandler = object.shoppingHandler or {}

local core, eventsLib, behaviorLib, metadata, itemHandler, shopping = object.core, object.eventsLib, object.behaviorLib, object.metadata, object.itemHandler, object.shoppingHandler

local print, ipairs, pairs, string, table, next, type, tinsert, tremove, tsort, format, tostring, tonumber, strfind, strsub
		= _G.print, _G.ipairs, _G.pairs, _G.string, _G.table, _G.next, _G.type, _G.table.insert, _G.table.remove, _G.table.sort, _G.string.format, _G.tostring, _G.tonumber, _G.string.find, _G.string.sub
local ceil, floor, pi, tan, atan, atan2, abs, cos, sin, acos, max, random
		= _G.math.ceil, _G.math.floor, _G.math.pi, _G.math.tan, _G.math.atan, _G.math.atan2, _G.math.abs, _G.math.cos, _G.math.sin, _G.math.acos, _G.math.max, _G.math.random
 
local BotEcho, VerboseLog, BotLog = core.BotEcho, core.VerboseLog, core.BotLog


--debugInfo
shopping.bDebugInfoGeneralInformation = false
shopping.bDebugInfoItemHandler = false
shopping.bDebugInfoShoppingFunctions = false
shopping.bDebugInfoShoppingBehavior = false
shopping.bDebugInfoCourierRelated = false

--if shopping.bDebugInfoShoppingFunctions then BotEcho("") end

----------------------------------------------------
--important advanced Shopping variables
----------------------------------------------------

--Lists
--Itembuild: list, position and decision
shopping.tItembuild = shopping.tItembuild or {} --itemcodes
shopping.tItembuildPosition = shopping.tItembuildPosition or 1 --position
shopping.tItemDecisions = shopping.tItemDecisions or {} --table of custom reminders 
--Shoppinglist
shopping.tShoppingList = shopping.tShoppingList or {}

--Courier
shopping.bCourierMissionControl = false
shopping.nNextFindCourierTime = HoN.GetGameTime()

--other variables
shopping.nNextItemBuildCheck = 600*1000
shopping.nCheckItemBuildInterval = 10*1000

shopping.nNextBuyTime = HoN.GetGameTime()
shopping.nBuyInterval = 250 -- One Shopping Round per Behavior utility call 

--Shopping Utility Values
shopping.nShoppingUtilityValue = 30
shopping.nShoppingPreGameUtilityValue = 100

--item is not avaible for shopping, retry it at a later time (mainly puzzlebox)
shopping.tDelayedItems = {}

--developement only - set this to true in your botfiles, while in pre submission phase
shopping.bDevelopeItemBuildSaver = false 

--names of some items
shopping.sNameHomecomingStone = "Item_HomecomingStone"
shopping.sNamePostHaste = "Item_PostHaste"
shopping.sNameHealthPostion = "Item_HealthPotion"
shopping.sNameBlightRunes = "Item_RunesOfTheBlight"
shopping.sNameManaPotions = "Item_ManaPotion"

--purchasable consumables 
shopping.tConsumables = {
	Item_HomecomingStone	= true,
	Item_HealthPotion		= true,
	Item_RunesOfTheBlight	= true,
	Item_ManaPotion			= true,
	Item_FlamingEye			= true, --Ward of Sight
	Item_ManaEye			= true, --Ward of Revelation
	Item_DustOfRevelation	= true  --Dust
	}

--List of desired item slots 
shopping.tDesiredItems = {
	Item_PostHaste 			= 1,
	Item_EnhancedMarchers	= 1,
	Item_PlatedGreaves 		= 1,
	Item_Steamboots 		= 1,
	Item_Striders 			= 1,
	Item_Marchers 			= 1,
	Item_Immunity 			= 2,
	Item_BarrierIdol 		= 2,
	Item_MagicArmor2 		= 2,
	Item_MysticVestments 	= 2,
	Item_PortalKey			= 3,
	Item_GroundFamiliar		= 6,
	Item_HomecomingStone	= 6
	}

--items in their desired item slot receive a bonus value
shopping.nSellBonusValue = 2000

--check function on a periodic basis
shopping.nNextCourierControl = HoN.GetGameTime()
shopping.nCourierControlIntervall = 250

--Courierstates: 0: Bugged; 1: Fill Courier; 2: Delivery; 3: Fill Stash
shopping.nCourierState = 0

--used item slots by our bot
shopping.tCourierSlots = {}

--courier delivery ring
shopping.nCourierDeliveryDistanceSq = 500 * 500

--only cast delivery one time (prevents courier lagging)
shopping.bDelivery = false

--Courier Bug Time-Outs
shopping.nCourierDeliveryTimeOut = 1000 
shopping.nCourierPositionTimeOut = shopping.nCourierDeliveryTimeOut + 500

--courier repair variables
shopping.nCourierBuggedTimer = 0
shopping.vecCourierLastPosition = nil

--stop shopping if we are done
shopping.bDoShopping = true
--stop shopping if we experience issues like stash is full
shopping.bPauseShopping = false

--table of requested items
shopping.tRequestQueue = {}

--Regen Tresholds
shopping.nMaxHealthTreshold = 1000
shopping.nMaxManaTreshold = 350

-----------------------------------------------
-----------------------------------------------
-- WIP-Functions
-----------------------------------------------
-----------------------------------------------

--function SyncWithDatabse
--[[
description:	Saves your itembuild progress to ensure compatibility with ReloadBots
--]]
local function SyncWithDatabse()
	
	local entry = object.myName
	
	--load values
	if not shopping.bDatabaseLoaded then
		if shopping.bDebugInfoGeneralInformation then BotEcho("Loading Database") end
		shopping.bDatabaseLoaded = true
		local result = GetDBEntry(entry, entry, false, HoN.GetRemainingPreMatchTime() > 0)
		if result then
			if shopping.bDebugInfoGeneralInformation then BotEcho("Found entries in database") end
			valTable = result.value
			if valTable then
				if shopping.bDebugInfoGeneralInformation then BotEcho("Reloading bot decisions") end
				--have entries -- unpack them
					shopping.tItembuild = valTable[1]
					shopping.tItembuildPosition = valTable[2]
					shopping.tItemDecisions = valTable[3]
					shopping.tDelayedItems = valTable[4]
					shopping.tCourierSlots = valTable[5]
					itemHandler:UpdateDatabase()
			end
		end
	end
	
	--save values
	local tableSaver = {value = {}}
	local dataToSave = tableSaver.value
	tinsert (dataToSave, shopping.tItembuild)
	tinsert (dataToSave, shopping.tItembuildPosition)
	tinsert (dataToSave, shopping.tItemDecisions)
	tinsert (dataToSave, shopping.tDelayedItems)
	tinsert (dataToSave, shopping.tCourierSlots)
	
	--GetDBEntry(entry, value, saveToDB, restoreDefault, setDefault)
	GetDBEntry(entry, tableSaver, true)
end

----------------------------------------------------
----------------------------------------------------
--			Item - Handler 
----------------------------------------------------
----------------------------------------------------

--function GetItem
--[[
description: 	Returns the chosen item
parameters: 	sItemName : Name of the item (e.g. "Item_HomecomingStone"); 
				unit : in which inventory is the item? (if nil then core.unitSelf)
				bIncludeStash: Check if your unit owns an item, don't try to use it with this option.

returns:		the item or nil if not found
--]]
function itemHandler:GetItem(sItemName, unit, bIncludeStash)
	   
	   --no item name, no item
		if not sItemName then 
			return 
		end
		--default unit: hero-unit
		if not unit then 
			unit = core.unitSelf 
		end
	   
	   --get the item
		local unitID = unit:GetUniqueID()
		local itemEntry = unitID and itemHandler.tItems[unitID..sItemName]
		
		--test if there is an item and if its still usable
		if itemEntry and itemEntry:IsValid() then 
			local nSlot = itemEntry:GetSlot()
			--access = in the inventory of this unit
			local access = unit:CanAccess(itemEntry.object)
			--in stash, therefore not accessable
			local bInUnitsInventory = nSlot <= 6
			
			if shopping.bDebugInfoItemHandler then BotEcho("Access to item "..sItemName.." in slot "..tostring(nSlot).." granted: "..tostring(access)) end
			
			--don't delete if its acessable or in stash
			if bInUnitsInventory and not access then
				--outdated entry
				itemHandler.tItems[unitID..sItemName] = nil
			elseif access or bIncludeStash then
				if shopping.bDebugInfoItemHandler then BotEcho("Return Item: "..sItemName) end
				
				--return the item
				return itemEntry
			end
		else
			--item is not usable --> delete it
			itemHandler.tItems[unitID..sItemName] = nil
		end
end
 
--function AddItem
--[[ 
description: 	Add an item to the itemHandler (Mainly used by next function UpdateDatabase)
parameters: 	curItem : item to add; unit : in which inventory is the item? (if nil then core.unitSelf)

returns:		true if the item was added
--]]
function itemHandler:AddItem(curItem, unit)
	   
	--no item, nothing to add
	if not curItem then 
		return 
	end
	
	--default unit:  hero-unit
	if not unit then unit = core.unitSelf end
	
	--itemName
	local sItemName = curItem:GetName()
	
	--be sure that there is no item in database
	if not itemHandler:GetItem(sItemName, unit, true) then
		
		local unitID = unit:GetUniqueID()
		
		if shopping.bDebugInfoItemHandler then BotEcho("Add Item: "..sItemName) end
		
		--add item
		itemHandler.tItems[unitID..sItemName] = core.WrapInTable(curItem)
				
		--return success
		return true
	end
	
	if shopping.bDebugInfoItemHandler then BotEcho("Item already in itemHandler: "..sItemName) end
	--return failure
	return false
end
 
--function Update Database
--[[
description:	Updates the itemHandler Database. Including all units with an inventory (courier, Booboo, 2nd Courier etc.)
parameters: 	bClear : Remove old entries?

--]]
function itemHandler:UpdateDatabase(bClear)
	   
	local unitSelf = core.unitSelf
	
	--remove invalid entries
	if bClear then
		if shopping.bDebugInfoItemHandler then BotEcho("Clear list") end
		for slot, item in pairs(itemHandler.tItems) do
			if item and not item:IsValid() then
				--item is not valid remove it
				 itemHandler.tItems[slot] = nil
			end
		end
	end
	
	--hero Inventory
	local inventory = unitSelf:GetInventory(true)
	
	--insert all items of his inventory
	for slot = 1, 12, 1 do
		local curItem = inventory[slot]
		itemHandler:AddItem(curItem, unitSelf)
	end
	   
	--all other inventory units (Couriers, Booboo)
	local inventoryUnits = core.tControllableUnits and core.tControllableUnits["InventoryUnits"]
	
	if inventoryUnits then	
		--do the same as above (insert all items)
		for _, unit in ipairs(inventoryUnits) do
			if unit:IsValid() then
				local unitInventory = unit:GetInventory()
				for slot = 1, 6, 1 do
					local curItem = unitInventory[slot]
					itemHandler:AddItem(curItem, unit)
				end
			end
		end	
	end
end

-----------------
-- end of 
-- Item Handler
-----------------

----------------------------------------------------
----------------------------------------------------
--			Shopping - Handler 
----------------------------------------------------
----------------------------------------------------

--tChanges
--[[
(first option is default)
tChanges.Item_HomecomingStone: true or false
tChanges.Item_HealthPotion: true or false
tChanges.Item_RunesOfTheBlight: true or false
tChanges.Item_ManaPotion: true or false
--]]

--tSetupOptions
--[[ 
(first option is default)
tSetupOptions.bReserveItems: true or false
	Check, if a team-item is already in the inventory of allies
	
tSetupOptions.bWaitForLaneDecision: false or true
	Wait for the bots lane before start shopping (lane item builds)
	
tSetupOptions.tConsumableOptions: true, false/nil, tChanges
	Shall the bot buy certain consumables periodically? 
	
tSetupOptions.bCourierCare: false or true
	Shall the bot upgrade and rebuy the courier?
--]]

--function Setup
--[[
description:	Select the features of this file (can be called multiple times)
parameters: 	tSetupOptions:		Table with option changes				
--]]
function shopping.Setup (tSetupOptions)

	local tSetupOptions = tSetupOptions or {}
	
	--initialize shopping
	shopping.BuyItems = shopping.BuyItems  or true
	shopping.bSetupDone = true
	
	--Check, if item is already reserved by a bot or a player (basic) and update function for teambot
	shopping.CheckItemReservation = tSetupOptions.bReserveItems or shopping.CheckItemReservation or true
	
	--Wait for lane decision before shopping?
	shopping.bWaitForLaneDecision = tSetupOptions.bWaitForLaneDecision or shopping.bWaitForLaneDecision or false
	
	--Consumables options
	local tConsumableOptions = tSetupOptions.tConsumableOptions
	if tConsumableOptions == false then
		shopping.BuyConsumables = false
	else
		shopping.BuyConsumables = true
		shopping.bBuyRegen = true
		if type(tConsumableOptions) == "table" then
			--found a table with changes, check each option
			for itemDef, value in pairs (tConsumableOptions) do
				if shopping.tConsumables[itemDef] ~= nil then
					shopping.tConsumables[itemDef] = value
				else
					if shopping.bDebugInfoGeneralInformation then BotEcho("Itemdefinition was not found in the default table: "..tostring(itemDef)) end
				end
			end
		end
	end
	
	--Courier options
	shopping.bCourierCare = tSetupOptions.bCourierCare or shopping.bCourierCare or false
	
end

--function GetCourier
--[[
description:	Returns the main courier
parameters:		bForceUpdate:	Force a courier-search operation

returns: 		the courier unit, if found
--]]
function shopping.GetCourier(bForceUpdate)
	
	--get saved courier
	local unitCourier = shopping.courier
	--if it is still alive return it
	if unitCourier and unitCourier:IsValid() then 
		return unitCourier 
	end
	
	--only search periodically
	local nNow = HoN.GetGameTime()
	if not bForceUpdate and shopping.nNextFindCourierTime > nNow then
		return		
	end	
	
	shopping.nNextFindCourierTime = nNow + 1000
	
	if shopping.bDebugInfoShoppingFunctions then BotEcho("Courier was not found. Checking inventory units") end
	
	--Search for a courier
	local controlUnits = core.tControllableUnits and core.tControllableUnits["InventoryUnits"] or {}
	for key, unit in pairs(controlUnits) do
		if unit then 
			local sUnitName = unit:GetTypeName()
			--Courier Check
			if sUnitName == "Pet_GroundFamiliar" or sUnitName == "Pet_FlyngCourier" then
				if shopping.bDebugInfoShoppingFunctions then BotEcho("Found Courier!") end
				
				--my courier? share to team
				if unit:GetOwnerPlayer() == core.unitSelf:GetOwnerPlayer() then
					unit:TeamShare()
				end
				
				--set references and return the courier
				shopping.courier = unit
				return unit
			end
		end
	end
end

--function CareAboutCourier
--[[
description:	check if the courier, needs further attention
--]]
function shopping.CareAboutCourier()
	
	--Before the game starts, don't care about the courier
	if HoN.GetMatchTime() <= 0 then return end 
	
	--get courier
	local courier = shopping.GetCourier()
	
	--do we have a courier
	if courier then 
		--got a ground courier? Send Upgrade-Order
		if courier:GetTypeName() == "Pet_GroundFamiliar" then
			if shopping.bDebugInfoShoppingFunctions then BotEcho("Courier needs an upgrade - Will do it soon") end
			shopping.courierDoUpgrade = true
		end
	else		
		--no courier - buy one
		if shopping.bDebugInfoShoppingFunctions then BotEcho("No Courier found, may buy a new one.") end
		shopping.bBuyNewCourier = true
	end		
	
end

--function DoCourierUpgrade(courier, gold)
--[[
description:	Upgrade the courier, if the bot has enough gold
parameters: 	courier: courier unit 
				gold: current gold

returns the remaining gold
--]]
function shopping.DoCourierUpgrade(courier, gold)
	
	local unitCourier = courier or shopping.GetCourier()
	local nMyGold = gold or object:GetGold()
	
	if unitCourier and nMyGold >= 200 then
		shopping.courierDoUpgrade = false
		if unitCourier:GetTypeName() == "Pet_GroundFamiliar" then
			local courierUpgrade = unitCourier:GetAbility(0)
			core.OrderAbility(object, courierUpgrade)
			nMyGold = nMyGold - 200
		end
	end
	
	return nMyGold
end

--function RequestConsumable
--[[
description:	Request Consumables to be bought soon
parameters: 	name: itemname, you want to purchase (regen, stones, wards and dust)
				count: number you want to purchase (doubles dust)
--]]
function shopping.RequestConsumable (name, count)

	--check if the requested item is a consumable
	local sEntry = name and shopping.tConsumables[name] ~= nil
	
	if sEntry then
		--item is a consumable
		local nCount = count or 1
		for i = 1, nCount do
			--purchase the requested number
			tinsert(shopping.tRequestQueue, name)
		end
	end			
end

--function Autobuy
--[[
description:	Checks for automatic consumable purchases

returns:		Keep buying items periodically		
--]]
function  shopping.Autobuy()

	local bKeepBuyingConsumables = false
	
	local tConsumables = shopping.tConsumables
	
	--get info about ourself 
	local unitSelf = core.unitSelf
	local courier = shopping.GetCourier()
	local nMyGold = object:GetGold()
	
	--Regen
	if shopping.bBuyRegen then
		
		local bBuyRegen = false
		
		--info about Health and Mana
		local nMaxHealth = unitSelf:GetMaxHealth()
		local nMaxMana = unitSelf:GetMaxMana()
		local nHealthPercent = unitSelf:GetHealthPercent()
		local nManaPercent = unitSelf:GetManaPercent()
		
		--only buy Health-Regen as long we can use it 
		if nMaxHealth <= shopping.nMaxHealthTreshold then
			if tConsumables[shopping.sNameBlightRunes] then
				bBuyRegen = true
				--only buy Runes if we don't have some
				local BlightRunes = itemHandler:GetItem(shopping.sNameBlightRunes, nil, true) or itemHandler:GetItem(shopping.sNameBlightRunes, courier)
				if not BlightRunes and nHealthPercent < 0.8 and nHealthPercent >= 0.6 then
					local itemDef = HoN.GetItemDefinition(shopping.sNameBlightRunes)
					local cost = itemDef:GetCost()
					
					--check if we can afford them
					if nMyGold >= cost then
						shopping.RequestConsumable (shopping.sNameBlightRunes, 1)
						nMyGold = nMyGold - cost
					end
				end
			end
			if tConsumables[shopping.sNameHealthPostion] then
				bBuyRegen = true
				--only buy potions if we don't have some
				local HealthPotion = itemHandler:GetItem(shopping.sNameHealthPostion, nil, true) or itemHandler:GetItem(shopping.sNameHealthPostion, courier)
				if not HealthPotion and nHealthPercent < 0.6 and nManaPercent > 0.4 then
					local itemDef = HoN.GetItemDefinition(shopping.sNameHealthPostion)
					local cost = itemDef:GetCost()
					
					--check if we can afford them
					if nMyGold >= cost then
						shopping.RequestConsumable (shopping.sNameHealthPostion, 1)
						nMyGold = nMyGold - cost
					end
				end
			end
		end
		
		--only buy Mana-Regen as long we can use it 
		if nMaxMana < shopping.nMaxManaTreshold then
			if tConsumables[shopping.sNameManaPotions] then
				bBuyRegen = true
				--only buy mana, if we don't have some
				local ManaPotion = itemHandler:GetItem(shopping.sNameManaPotions, nil, true) or itemHandler:GetItem(shopping.sNameManaPotions, courier)
				if not ManaPotion and nManaPercent < 0.4 and nHealthPercent > 0.5 then
					local itemDef = HoN.GetItemDefinition(shopping.sNameManaPotions)
					local cost = itemDef:GetCost()
					
					if nMyGold >= cost then
						shopping.RequestConsumable (shopping.sNameManaPotions, 1)
						nMyGold = nMyGold - cost
					end
				end
			end
		end
		
		shopping.bBuyRegen = bBuyRegen
		bKeepBuyingConsumables = bBuyRegen
	end	
	
	
	--homeomcing stones
	if tConsumables[shopping.sNameHomecomingStone] then
		--only buy stones if we have not Post Haste
		local itemPostHaste = itemHandler:GetItem(shopping.sNamePostHaste, nil, true) or itemHandler:GetItem(shopping.sNamePostHaste, courier)
		if itemPostHaste then 
			tConsumables[shopping.sNameHomecomingStone] = false
		else
			bKeepBuyingConsumables = true
			--only buy stones if we don't have some
			local stone = itemHandler:GetItem(shopping.sNameHomecomingStone, nil, true) or itemHandler:GetItem(shopping.sNameHomecomingStone, courier)
			if not stone then
				local itemDef = HoN.GetItemDefinition(shopping.sNameHomecomingStone)
				local cost = itemDef:GetCost()
				local count = 0
				
				local nNow = HoN.GetMatchTime()
				
				--10 min into the game buy them in pairs, if you can
				if nMyGold >= 2*cost and nNow > 600000 then
					count = 2
				elseif nMyGold >= cost and unitSelf:GetLevel() > 2 then
					count = 1
				end
				
				if count > 0 then
					shopping.RequestConsumable (shopping.sNameHomecomingStone, count)
					nMyGold = nMyGold - count * cost
				end
			end
		end
	end

	return bKeepBuyingConsumables
end

--function GetConsumables
--[[
description:	Insert the requested items into the shopping list.
--]]
function shopping.GetConsumables()
	
	--automaticly purchase
	if shopping.BuyConsumables and #shopping.tRequestQueue == 0 then
		if shopping.bDebugInfoShoppingFunctions then BotEcho("Checking for Consumables") end
		shopping.BuyConsumables = shopping.Autobuy()
	end
	
	--insert requested items into shopping list
	local tRequestQueue = shopping.tRequestQueue
	
	local bCheckEntries = true
	while bCheckEntries do
		local sQueueEntry = tRequestQueue[1]
		if sQueueEntry then
			--found first entry, check definition
			local itemDef = HoN.GetItemDefinition(sQueueEntry)
			if itemDef then
				--put item definition into shopping list
				tinsert(shopping.tShoppingList, 1, itemDef)
			else
				--could not get the item definition, skipping entry
				if shopping.bDebugInfoShoppingFunctions then BotEcho("Item definition was not found: "..sQueueEntry) end
			end
			--remove entry
			tremove(tRequestQueue, 1)
		else
			--no entries left
			bCheckEntries = false
		end
	end
end

--function CheckItemBuild	-->>This file should be overriden<<--
--[[
description:	Check your itembuild for some new items

returns:		true if you should keep buying items
--]]
function shopping.CheckItemBuild()

	if shopping.bDebugInfoGeneralInformation then BotEcho("You may want to override this function: shopping.CheckItemBuild()") end
	
	--just convert the standard lists into the new shopping list
	if shopping.tItembuild then
		if #shopping.tItembuild == 0 then
			core.InsertToTable(shopping.tItembuild, behaviorLib.StartingItems)
			core.InsertToTable(shopping.tItembuild, behaviorLib.LaneItems)
			core.InsertToTable(shopping.tItembuild, behaviorLib.MidItems)
			core.InsertToTable(shopping.tItembuild, behaviorLib.LateItems)
		else
			--we reached the end of our itemlist. Done with shopping
			return false
		end
	end
	return true
end

--function GetAllComponents
--[[
description:	Get all components of an item definition - including any sub-components 
parameters: 	itemDef: the item definition

returns:		a list of all components of an item (including sub-components)
--]]
function shopping.GetAllComponents(itemDef)
	
	--result table
	local result = {}
		
	if itemDef then
		--info about this item definition
		local bRecipe = not itemDef:GetAutoAssemble()
		local components = itemDef:GetComponents()
		
		if components then
			if #components>1 then
				--item is no basic omponent 
				
				if bRecipe then
					--because we insert the recipe at the end we have to remove it in its componentlist
					tremove(components, #components)
				end
				
				--get all sub-components of the components
				for _, val in ipairs (components) do
					local comp = shopping.GetAllComponents(val)
					--insert all sub-components in our list
					for _, val2 in ipairs (comp) do
						tinsert(result, val2)
					end
				end
				
				--insert itemDef at the end of all other components
				tinsert(result, itemDef)
			else
				--this item is a basis component
				tinsert(result, itemDef)
			end
		else
			BotEcho("Error: GetComponents returns no value. purchase may bug out")
		end
	else
		BotEcho("Error: No itemDef found")
	end
	
	if shopping.bDebugInfoShoppingFunctions then
		BotEcho("Result info")
		for pos,val in ipairs (result) do
			BotEcho("Position: "..tostring(pos).." ItemName: "..tostring((val and val:GetName()) or "Error val not found"))
		end
		BotEcho("End of Result Info")
	end
	
	return result
end

--function RemoveFirstByValue 
--[[ 
description:	Remove the first encounter of a specific value in a table
parameters: 	t: table to look at
				valueToRemove: value which should be removed (first encounter)

returns: 		true if a value is successfully removed
--]]
function shopping.RemoveFirstByValue(t, valueToRemove)

	--no table, nothing to remove
	if not t then
		return false
	end

	local bSuccess = false
	--loop through table
	for i, value in ipairs(t) do
		--found matching value
		if value == valueToRemove then
			if shopping.bDebugInfoShoppingFunctions then BotEcho("Removing itemdef "..tostring(value)) end
			--remove entry
			tremove(t, i)
			bSuccess = true
			break
		end
	end
	
	return bSuccess
end

--function CheckItemsInventory 
--[[
description:	Check items in your inventory and removes any components you already own
parameters: 	tComponents: List of itemDef (usually result of shopping.GetAllComponents)

returns: 		the remaining components to buy
--]]
function shopping.CheckItemsInventory (tComponents)
	if shopping.bDebugInfoShoppingFunctions then BotEcho("Checking Inventory Stuff") end
	
	if not tComponents then 
		return 
	end
	
	--result table
	local tResult = core.CopyTable(tComponents)
	
	--info about ourself
	local unit = core.unitSelf 
	local inventory = unit:GetInventory(true)
	
	--courier items 
	local courier = shopping.GetCourier()
	if courier then
		local courierInventory = courier:GetInventory(false)
		for index, slot in ipairs (shopping.tCourierSlots) do
			if slot then
				tinsert(inventory, courierInventory[slot])
			end
		end
	end
	
	--Get all components we own
	if #tResult > 0 then
		
		local tPartOfItem = {}
		
		--Search inventory if we have any (sub-)components
		for invSlot, invItem in pairs(inventory) do
			if invItem then
				local itemDef = invItem:GetItemDefinition()
				
				--Search list for any matches
				for compSlot, compDef in ipairs(tResult) do
					if compDef == itemDef then
						if shopping.bDebugInfoShoppingFunctions then BotEcho("Found component. Name"..compDef:GetName()) end
						
						--found a component, add it to the list
						tinsert(tPartOfItem, invItem)
						break
					end
				end
			end
		end
		
		--Delete (sub-)components of items we own
		for _, item in ipairs (tPartOfItem) do			
			local itemDef = item:GetItemDefinition()
			if shopping.bDebugInfoShoppingFunctions then BotEcho("Removing elements itemName"..itemDef:GetName()) end
			
			--fount an item
			if item then
				if shopping.bDebugInfoShoppingFunctions then BotEcho("Found item") end
				
				local bRecipe = item:IsRecipe() 
				local level = not bRecipe and item:GetLevel() or 0
				
				if bRecipe then
					--item is a recipe remove the first encounter
					if shopping.bDebugInfoShoppingFunctions then BotEcho("this is a recipe") end
					shopping.RemoveFirstByValue(tResult, itemDef)
				else
					--item is no recipe, take further testing
					if shopping.bDebugInfoShoppingFunctions then BotEcho("not a recipe") end
					
					--remove level-1 recipes
					while level > 1 do
						shopping.RemoveFirstByValue(tResult, itemDef)
						level = level -1
					end
					
					--get sub-components
					local components = shopping.GetAllComponents(itemDef)
					
					--remove all sub-components and itself
					for _,val in pairs (components) do
						if shopping.bDebugInfoShoppingFunctions then BotEcho("Removing Component. "..val:GetName()) end
						shopping.RemoveFirstByValue(tResult, val)
					end
				end
			end
		end
	end
	
	return tResult
end

--function GetNextItem
--[[
description:	Get the next item in the itembuild-list and put its components in the shopping-list	

returns:		true if you should keep shopping
--]]
local function GetNextItem()

	local bKeepShopping = true
	
	--references to our itembuild list
	local itemList = shopping.tItembuild
	local listPos = shopping.tItembuildPosition
	
	--check if there are no more items to buy
	if  listPos > #itemList then
		--get new items
		if shopping.bDebugInfoShoppingFunctions then BotEcho("shopping.tItembuild: Index Out of Bounds. Check for new stuff") end
		 bKeepShopping = shopping.CheckItemBuild()
	end
	
	--Get next item and put it into Shopping List
	if bKeepShopping then
		--go to next position
		shopping.tItembuildPosition = listPos + 1
		
		if shopping.bDebugInfoShoppingFunctions then BotEcho("Next Listposition:"..tostring(listPos)) end
		
		--get item definition
		local nextItemCode = itemList[listPos]
		local name, num, level = behaviorLib.ProcessItemCode(nextItemCode)
				
		--care about ItemReservations?
		if shopping.CheckItemReservation then
			local teamBot = HoN.GetTeamBotBrain()
			if teamBot and not teamBot.ReserveItem(name) then 
				--item reservation failed,because it is already reserved
				return GetNextItem()
			end
		end
		
		local itemDef = HoN.GetItemDefinition(name)
		
		if shopping.bDebugInfoShoppingFunctions then BotEcho("Name "..name.." Anzahl "..num.." Level"..level) end
				
		
		--get all components
		local itemComponents = shopping.GetAllComponents(itemDef)
		
		--Add Level Recipes
		local levelRecipe = level
		while levelRecipe > 1 do
			--BotEcho("Level Up")
			tinsert (itemComponents, itemDef)
			levelRecipe = levelRecipe -1
		end
		
		--only do extra work if we need to
		if num > 1 then 
			--Add number of items
			local temp = core.CopyTable(itemComponents)
			while num > 1 do
				--BotEcho("Anzahl +1")
				core.InsertToTable(temp, itemComponents)
				num = num - 1
			end
			
			itemComponents = core.CopyTable(temp)
		end
				
		--returns table of remaining components
		local tReaminingItems = shopping.CheckItemsInventory(itemComponents)

		--insert remaining items in shopping list
		if #tReaminingItems > 0 then
			if shopping.bDebugInfoShoppingFunctions then BotEcho("Remaining Components:") end
			for compSlot, compDef in ipairs (tReaminingItems) do
				if compDef then
					local defName = compDef:GetName()
					if shopping.bDebugInfoShoppingFunctions then BotEcho("Component "..defName) end
					--only insert component if it not an autocombined element
					if  defName ~= name or not compDef:GetAutoAssemble() then
						tinsert(shopping.tShoppingList, compDef)
					end
				end
			end
		else
			if shopping.bDebugInfoShoppingFunctions then BotEcho("No remaining components. Skip this item (If you want more items of this type increase number)") end
			return GetNextItem()
		end
		
	end
	
	if shopping.bDebugInfoShoppingFunctions then BotEcho("bKeepShopping? "..tostring(bKeepShopping)) end
	
	return bKeepShopping
end

--function Print All
--[[
description:	Print Your itembuild-list, your current itembuild-list position and your shopping-list

--]]
function shopping.printAll()
	
	--references to the lists
	local itemBuild = shopping.tItembuild 
	local shoppingList = shopping.tShoppingList
	local position = shopping.tItembuildPosition 
	
	BotEcho("My itembuild:")
	--go through whole list and print each component
	for slot, item in ipairs(itemBuild) do
		if item then
			if slot == position then BotEcho("Future items:") end
			local name = behaviorLib.ProcessItemCode(item)  or "Error, no item name found!"
			BotEcho("Slot "..tostring(slot).." Itemname "..name)
		end
	end
	
	BotEcho("My current shopping List")
	--go through whole list and print each component
	for compSlot, compDef in ipairs(shoppingList) do
		if compDef then
			BotEcho("Component Type check: "..tostring(compDef:GetTypeID()).." is "..tostring(compDef:GetName()))
		else
			BotEcho( "No desc")
		end
	end
end

--function UpdateItemList 
--[[
description:	Updates your itembuild-list and your shopping-list on a periodically basis. Update can be forced
parameters: 	bForceUpdate: Force a list update (usually called if your shopping-list is empty)

--]]
function shopping.UpdateItemList(bForceUpdate)
	
	--get current time
	local nNow =  HoN.GetGameTime()
	
	--default setup if it is not overridden by the implementing bot
	if not shopping.bSetupDone then
		--function shopping.Setup (bReserveItems, bSkipLaneWaiting, bCourierCare, bBuyConsumables, tConsumableOptions)
		shopping.Setup()
	end

	
	--Check itembuild every now and then or force an update
	if shopping.nNextItemBuildCheck <= nNow or bForceUpdate then
		if shopping.bDebugInfoShoppingFunctions then BotEcho(tostring(shopping.nNextItemBuildCheck).." Now "..tostring(nNow).." Force Update? "..tostring(bForceUpdate)) end
		
		if shopping.bDevelopeItemBuildSaver and bForceUpdate then 
			SyncWithDatabse() 
		end
		
		if shopping.tShoppingList then
			--Is your Shopping list empty? get new item-components to buy
			if #shopping.tShoppingList == 0 and shopping.BuyItems then
				if shopping.bDebugInfoShoppingFunctions then BotEcho("Checking for next item") end
				shopping.BuyItems = GetNextItem()
			end
			
			--check for consumables
			if core.unitSelf:IsAlive() then
				shopping.GetConsumables()
			end
			
			--Are we in charge to buy and upgrade courier?
			if shopping.bCourierCare then
				if shopping.bDebugInfoShoppingFunctions then BotEcho("Care about Courier") end
				shopping.CareAboutCourier()
			end
			
			--check for delayed items (Mainly puzzlebox re-purchase)
			local tDelayedItems = shopping.tDelayedItems
			if #tDelayedItems > 0 then
				if shopping.bDebugInfoShoppingFunctions then BotEcho("Found delayed items") end
				local success = false
				--check if there are any items off cooldown
				for i, listEntry in ipairs(tDelayedItems) do
					local nTime, itemDef = listEntry[1], listEntry[2]
					if nTime <= nNow then
						--try to re-purchase this item
						if shopping.bDebugInfoShoppingFunctions then BotEcho("Insert Entry in shopping list") end
						tinsert(shopping.tShoppingList,1, itemDef)
						success = i
						break;
					end
				end
				if success then
					tremove (shopping.tDelayedItems, success)
				end				
			end							
		end
		
		--reset cooldown
		shopping.nNextItemBuildCheck = nNow + shopping.nCheckItemBuildInterval
		if shopping.bDebugInfoShoppingFunctions then shopping.printAll() end
	end
end


-----------------------------------------------
--Sort items
-----------------------------------------------

--function SetItemSlotNumber
--[[ 
description:	Sets the slot for an itemName
parameters: 	itemName: Name of the item
				slot: Desired slot of this item (leave it to delete an entry)

returns: 		true if successfully set
--]]
function shopping.SetItemSlotNumber(itemName, slot)
	
	if not itemName then 
		return false 
	end
	
	--insert slot number or delete entry if slot is nil
	shopping.tDesiredItems[itemName] = slot
	
	return true
end

--function GetItemSlotNumber
--[[ 
description:	Get the desired Slot of an item
parameters: 	itemName: Name of the item

returns: 		the number of the desired Slot
--]]
function shopping.GetItemSlotNumber(itemName)
	local desiredItems = shopping.tDesiredItems
	return desiredItems and desiredItems[itemName] or 0
end


--function pair(a, b) -->	helper-function for sorting tables
--[[
description:	Checks if a table element is smaller than another one
parameters:		a: first table element
				b: second table element
				
returns:		true if a is smaller than b
--]]
local function pair(a, b) 
	return a[1] < b[1] 
end

--function SortItems 
--[[
description:	Sort the items in the units inventory 
parameters: 	unit: The unit which should sort its items

returns 		true if the inventory was changed
--]]
function shopping.SortItems (unit)
	local bChanged = false
	
	if shopping.bDebugInfoShoppingFunctions then BotEcho("Sorting items probably") end
	
	--default unit hero-unit
	if not unit then 
		unit = core.unitSelf 
	end
	
	--get inventory
	local inventory = unit:GetInventory(true)
	
	--item slot list	
	local tSlots = 		{false, false, false, false, false, false}
	
	--list of cost and slot pairs
	local tValueList = {}
	
	--index all items
	for slot, item in pairs (inventory) do
		if shopping.bDebugInfoShoppingFunctions then BotEcho("Current Slot"..tostring(slot)) end
		
		--only add non recipe items
		if not item:IsRecipe() then 
			
			--get item info
			local itemName = item:GetName()			
			local itemTotalCost = item:GetTotalCost()
			if shopping.bDebugInfoShoppingFunctions then BotEcho("Item "..itemName) end
			
			--get desiredSlot
			local desiredSlot = shopping.GetItemSlotNumber(itemName)
			
			if desiredSlot > 0 then
				--go a recommended slot
				--check for already existing entry
				local savedItemSlot = tSlots[desiredSlot]
				if savedItemSlot then
					--got existing entry
					--compare this old entry with the current one
					local itemToCompare = inventory[savedItemSlot]
					local itemCompareCost = itemToCompare:GetTotalCost()
					if itemTotalCost > itemCompareCost then
						--new item has a greater value, but old entry in value-list
						tinsert(tValueList, {itemTotalCost,savedItemSlot})
						tSlots[desiredSlot] = slot
					else
						--old item is better, insert new item in value-list
						tinsert(tValueList, {itemTotalCost,slot})
					end
				else
					--got a desiredSlot but don't have an item in it yet.
					--Just put it in
					tSlots[desiredSlot] = slot
				end
			else
				--We don' have a recommended slot, just put it in the value list
				--add itemcost and position to the value list
				tinsert(tValueList, {itemTotalCost,slot})
			end
		end				
	end
	
	--sort our table (itemcost Down -> Top)
	table.sort(tValueList, pair)
	
	--insert missing entries with items from our value list (Top-down)
	for key, slot in ipairs (tSlots) do
		if not slot then
			local tEntry = tValueList[#tValueList] 
			if tEntry then
				tSlots[key] = tEntry[2]
				tremove (tValueList)
			end
		end
	end
	
	--we have to take care for item swaps, because the slots will alter after a swap.
	local nLengthSlots = #tSlots 
	for key, slot in ipairs (tSlots) do
		--Replace any slot after this one
		for start=key+1, nLengthSlots, 1 do
			if tSlots[start] == key then
				tSlots[start] = slot
			end
		end
	end
	
	--swap Items
	for slot=1, 6, 1 do
		local thisItemSlot = tSlots[slot]
		if thisItemSlot then
			--valid swap?
			if thisItemSlot ~= slot then
				if shopping.bDebugInfoShoppingFunctions then BotEcho("Swapping Slot "..tostring(thisItemSlot).." with "..tostring(slot)) end
				
				--swap items
				unit:SwapItems(thisItemSlot, slot)
				
				bChanged = true
			end
		end
	end
	
	if shopping.bDebugInfoShoppingFunctions then 
		BotEcho("Sorting Result: "..tostring(bChanged)) 
		for position, fromSlot in pairs (tSlots) do
			BotEcho("Item in Slot "..tostring(position).." was swapped from "..tostring(fromSlot))
		end
	end
	
	return bChanged
end

--function SellItems 
--[[
description:	Sell a number of items from the unit's inventory (inc.stash)
parameters: 	number: Number of items to sell; 
				unit: Unit which should sell its items
				itemdef: sell restirction for item definiton

returns:		true if the items were succcessfully sold
--]]
function shopping.SellItems (number, unit)
	local bChanged = false
	
	--default unit: hero-unit
	if not unit then 
		unit = core.unitSelf 
	end
	
	--default number: 1; return if there is a negative value
	if not number then 
		number = 1
	elseif number < 1 then 
		return bChanged 
	end
	
	--get inventory
	local tInventory = unit:GetInventory(true)
	
	--list of cost and slot pairs
	local tValueList = {}
	
	--index all items
	for slot, item in pairs (tInventory) do
		--insert only non recipe items
		if not item:IsRecipe() then 
			local itemTotalCost = item:GetTotalCost()
			local itemName = item:GetName()
			--give the important items a bonus in gold (Boots, Mystic Vestments etc.)
			if slot == shopping.GetItemSlotNumber(itemName) then
				itemTotalCost = itemTotalCost + shopping.nSellBonusValue
			end
			--insert item in the list
			tinsert(tValueList, {itemTotalCost, slot})
			if shopping.bDebugInfoShoppingFunctions then BotEcho("Insert Slotnumber: "..tostring(slot).." Item "..itemName.." Price "..tostring(itemTotalCost)) end
		end				
	end
	
	--sort list (itemcost Down->Top)
	table.sort(tValueList, pair)	
	
	local bStashOnly = true
	
	--sell Items
	while number > 0 do
		local valueEntry = tValueList[#tValueList]
		local sellingSlot = valueEntry and valueEntry[2]
		if sellingSlot then
			if shopping.bDebugInfoShoppingFunctions then BotEcho("I am selling slotnumber"..tostring(slot)) end
			--Sell item by lowest TotalCost
			unit:SellBySlot(sellingSlot)
			
			if sellingSlot <= 6 then
				bStashOnly = false
			end
			
			--remove from list
			tremove (tValueList)
			bChanged = true			
		else
			--no item to sell
			break
		end
		number = number -1
	end
	
	return bChanged, bStashOnly
end

--function NumberSlotsOpenStash
--[[
description:	Counts the number of open sots in the stash
parameters: inventory: inventory of a unit

returns the number of free stash slots
--]]
function shopping.NumberSlotsOpenStash(inventory)
	local numOpen = 0
	--count only stash
	for slot = 7, 12, 1 do
		curItem = inventory[slot]
		if curItem == nil then
			--no item is a free slot - count it
			numOpen = numOpen + 1
		end
	end
	return numOpen
end

-------------------
-- end of 
-- Shopping Handler
-------------------

----------------------------------------------------
----------------------------------------------------
--			Shopping - Behavior 
----------------------------------------------------
----------------------------------------------------
function shopping.ShopUtility(botBrain)

	local utility = 0
	
	--don't shop till we know where to go
	if shopping.bWaitForLaneDecision then
		if HoN.GetRemainingPreMatchTime() >= core.teamBotBrain.nInitialBotMove then 
			return utility 
		else
			shopping.bWaitForLaneDecision = false
		end
	end
	
	local nShoppingUtilityValue = HoN.GetMatchTime() > 0 and shopping.nShoppingUtilityValue or shopping.nShoppingPreGameUtilityValue
	
	local myGold = botBrain:GetGold()
	
	local unitSelf = core.unitSelf
	local bCanAccessStash = unitSelf:CanAccessStash()
	
	--courier care
	if shopping.bCourierCare then 
		local courier = shopping.GetCourier()
		
		--check we have to buy a new courier
		if shopping.bBuyNewCourier then
			if courier then					
				--there is a courier, no need to buy one
				shopping.bBuyNewCourier = false
				shopping.bPauseShopping = false
			else
				shopping.bPauseShopping = true
				if myGold >= 200 and bCanAccessStash then 
					--recheck courier to be safe
					if not shopping.GetCourier(true) then 
						--buy it
						tinsert(shopping.tShoppingList, 1, HoN.GetItemDefinition("Item_GroundFamiliar"))
					end
					shopping.bBuyNewCourier = false
					shopping.bPauseShopping = false
				end
			end
		end
		
		--check if we have to upgrade courier
		if shopping.courierDoUpgrade and myGold >= 200 then
			myGold = shopping.DoCourierUpgrade(courier, myGold)
		end
	end
	
	--still items to buy?
	if shopping.bDoShopping and not shopping.bPauseShopping then 
		
		if not behaviorLib.finishedBuying then
			utility = nShoppingUtilityValue
		end
		
		--if shopping.bDebugInfoShoppingBehavior then BotEcho("Check next item") end
		local nextItemDef = shopping.tShoppingList and shopping.tShoppingList[1]
		
		if not nextItemDef then
			if shopping.bDebugInfoShoppingBehavior then BotEcho("No item definition in Shopping List. Start List update") end
			shopping.UpdateItemList(true)
			nextItemDef = shopping.tShoppingList[1]
		end
		
		
		if nextItemDef then 
		
			if myGold > nextItemDef:GetCost() then
				if shopping.bDebugInfoShoppingBehavior then BotEcho("Enough gold to buy the item: "..nextItemDef:GetName()..". Current gold: "..tostring(myGold)) end	
				utility = nShoppingUtilityValue
				behaviorLib.finishedBuying = false
				if bCanAccessStash then
					if shopping.bDebugInfoShoppingBehavior then BotEcho("Hero can access shop") end
					utility = nShoppingUtilityValue * 3						
				end				
			end
		else
			BotEcho("Error no next item...Stopping any shopping")
			shopping.bDoShopping = false
		end
		
	end
	
	return utility
end

function shopping.ShopExecute(botBrain)
	
	local nNow = HoN.GetGameTime()
	
	--Space out your buys (one purchase per behavior-utility cycle)
	if shopping.nNextBuyTime > nNow then
		return false
	end

	if shopping.bDebugInfoShoppingBehavior then BotEcho("Shopping Execute:") end
	
	shopping.nNextBuyTime = nNow + shopping.nBuyInterval
		
	local unitSelf = core.unitSelf

	local bChanged = false
	local inventory = unitSelf:GetInventory(true)
	local nextItemDef = shopping.tShoppingList[1]
		
	if nextItemDef then
		if shopping.bDebugInfoShoppingBehavior then BotEcho("Found item. Buying "..nextItemDef:GetName()) end
		
		local goldAmtBefore = botBrain:GetGold()
		local nItemCost = nextItemDef:GetCost()
		
		--enough gold to buy the item?
		if goldAmtBefore >= nItemCost then 
			
			--check number of stash items
			local openSlots = shopping.NumberSlotsOpenStash(inventory)
			
			--enough space?
			if openSlots < 1 then
			
				local bSuccess, bStashOnly = shopping.SellItems (1)
				--stop shopping, if we can't purchase items anymore, fix it with next stash access
				shopping.bPauseShopping = not bSuccess or not bStashOnly
				
			else
				unitSelf:PurchaseRemaining(nextItemDef)
		
				local goldAmtAfter = botBrain:GetGold()
				local bGoldReduced = (goldAmtAfter < goldAmtBefore)
				
				--check purchase success
				if bGoldReduced then 
					if shopping.bDebugInfoShoppingBehavior then BotEcho("item Purchased. removing it from shopping list") end
					tremove(shopping.tShoppingList,1)
					if shopping.bDevelopeItemBuildSaver then SyncWithDatabse() end
				else
					local maxStock = nextItemDef:GetMaxStock()
					if maxStock > 0 then
						-- item may not be purchaseble, due to cooldown, so skip it
						if shopping.bDebugInfoShoppingBehavior then BotEcho("Item not purchaseable due to cooldown. Item will be skipped") end
						tremove(shopping.tShoppingList,1)
						--re-enter bigger items after cooldown delay 
						if nItemCost > 250 then
							if shopping.bDebugInfoShoppingBehavior then BotEcho("Item is valuble, will try to repurchase it after some delay") end
							local nItemRestockedTime = nNow + 120000
							tinsert (shopping.tDelayedItems, {nItemRestockedTime, nextItemDef})
						end
					else
						if shopping.bDebugInfoShoppingBehavior then BotEcho("No Purchase of "..nextItemDef:GetName()..". Unknown exception waiting for stash access to fix it.") end
						shopping.bPauseShopping = true
					end						
				end	
				bChanged = bChanged or bGoldReduced
			end
		end
	end
	
	--finished buying
	if bChanged == false then
		if shopping.bDebugInfoShoppingBehavior then BotEcho("Finished Buying!") end
		behaviorLib.finishedBuying = true
		shopping.bStashFunctionActivation = true
		itemHandler:UpdateDatabase()
		local bCanAccessStash = unitSelf:CanAccessStash()
		if not bCanAccessStash then 
			if shopping.bDebugInfoShoppingBehavior then  BotEcho("CourierStart") end
			shopping.bCourierMissionControl = true
		end
	end
end
behaviorLib.ShopBehavior["Utility"] = shopping.ShopUtility
behaviorLib.ShopBehavior["Execute"] = shopping.ShopExecute

----------------------------------------------------------
--Stash-Functions
--Sort your inventory, if in base
----------------------------------------------------------
function shopping.StashUtility(botBrain)
	local utility = 0
	
	local unitSelf = core.unitSelf
	local bCanAccessStash = unitSelf:CanAccessStash()
	
	if bCanAccessStash then
		--increase util when porting greatly
		if core.unitSelf:IsChanneling() then
			utility = 125
		elseif shopping.bStashFunctionActivation then
			utility = 30
		end
	else
		shopping.bStashFunctionActivation = true
	end
	
	if shopping.bDebugInfoShoppingBehavior and utility > 0 then BotEcho("Stash utility: "..tostring(utility)) end

	return utility
end
 
function shopping.StashExecute(botBrain)
	
	local bSuccess = false
	
	local unitSelf = core.unitSelf
	local bCanAccessStash = unitSelf:CanAccessStash()
	
	if shopping.bDebugInfoShoppingBehavior then BotEcho("Can access stash "..tostring(bCanAccessStash)) end
	
	--we can access the stash so just sort the items
	if bCanAccessStash then
		if shopping.bDebugInfoShoppingBehavior then BotEcho("Sorting items soon") end
		
		bSuccess = shopping.SortItems (unitSelf) 
		
		if shopping.bDebugInfoShoppingBehavior then BotEcho("Sorted items"..tostring(bSuccess)) end
		
		--don't sort items again in this stash-meeting (besides if we are using a tp)
		shopping.bStashFunctionActivation = false
		
		--all Stashproblems should be fixed now
		shopping.bPauseShopping = false
		
		itemHandler:UpdateDatabase(bSuccess)
	end
	
	--if we have a courier use it
	local itemCourier = itemHandler:GetItem("Item_GroundFamiliar") 
	if itemCourier then 
		core.OrderItemClamp(botBrain, unitSelf, itemCourier)
		
		--now we should have a new free slot, so we can resort the stash
		shopping.bStashFunctionActivation = true
	end
	
	
	return bSuccess
end
 
behaviorLib.StashBehavior = {}
behaviorLib.StashBehavior["Utility"] = shopping.StashUtility
behaviorLib.StashBehavior["Execute"] = shopping.StashExecute
behaviorLib.StashBehavior["Name"] = "Stash"
tinsert(behaviorLib.tBehaviors, behaviorLib.StashBehavior) 

---------------------------------------------------
-- Find Items
---------------------------------------------------

--function FindItems
--[[
description:	compatibility to older bots, check for item references
parameters: 	botBrain: 			botBrain

--]]
function shopping.FindItems(botBrain)	
	
	core.itemHatchet = itemHandler:GetItem("Item_LoggersHatchet") 
	if core.itemHatchet and not core.itemHatchet.val then
		core.itemHatchet.val = true
		if core.unitSelf:GetAttackType() == "melee" then
			core.itemHatchet.creepDamageMul = 1.32
		else
			core.itemHatchet.creepDamageMul = 1.12
		end
	end
	
	core.itemRoT = itemHandler:GetItem("Item_ManaRegen3") or itemHandler:GetItem("Item_LifeSteal5") or itemHandler:GetItem("Item_NomesWisdom")
	if core.itemRoT and not core.itemRoT.val then
		core.itemRoT.val = true
		local modifierKey = core.itemRoT:GetActiveModifierKey()
		core.itemRoT.bHeroesOnly = (modifierKey == "ringoftheteacher_heroes" or modifierKey == "abyssalskull_heroes" or modifierKey == "nomeswisdom_heroes") 
		core.itemRoT.nNextUpdateTime = 0
		core.itemRoT.Update = function() 
		local nCurrentTime = HoN.GetGameTime()
			if nCurrentTime > core.itemRoT.nNextUpdateTime then
				local modifierKey = core.itemRoT:GetActiveModifierKey()
				core.itemRoT.bHeroesOnly = (modifierKey == "ringoftheteacher_heroes" or modifierKey == "abyssalskull_heroes" or modifierKey == "nomeswisdom_heroes")
				core.itemRoT.nNextUpdateTime = nCurrentTime + 800
			end
		end
	end
	
	core.itemGhostMarchers = itemHandler:GetItem("Item_EnhancedMarchers")
	if core.itemGhostMarchers and not core.itemGhostMarchers.val then
		core.itemGhostMarchers.val = true
		core.itemGhostMarchers.expireTime = 0
		core.itemGhostMarchers.duration = 6000
		core.itemGhostMarchers.msMult = 0.12
	end	
	
	
	--compatible
	return true
end
shopping.FindItemsOld = core.FindItems
core.FindItems = shopping.FindItems

---------------------------------------------------
--Further Courier Functions
---------------------------------------------------

--fill courier with stash items and remeber the transfered slot
function shopping.FillCourier(courier)
	local success = false
	
	if not courier then return success end
	
	if shopping.bDebugInfoCourierRelated then BotEcho("Fill COurier") end
	
	--get info about inventory
	local inventory = courier:GetInventory()
	local stash = core.unitSelf:GetInventory (true)
	
	local tSlotsOpen = {}
	
	--check open courier slots
	for  slot = 1, 6, 1 do
		local item = inventory[slot]
		if not item then 
			if shopping.bDebugInfoCourierRelated then BotEcho("Slot "..tostring(slot).." is free") end
			tinsert(tSlotsOpen, slot)
		end
	end
	--transfer items to courier
	local openSlot = 1
	for slot=12, 7, -1 do 
		local curItem = stash[slot]
		local freeSlot = tSlotsOpen[openSlot]
		if curItem and freeSlot then
			if shopping.bDebugInfoCourierRelated then BotEcho("Swap "..tostring(slot).." with "..tostring(freeSlot)) end
			courier:SwapItems(slot, freeSlot)
			tinsert(shopping.tCourierSlots, freeSlot)
			openSlot = openSlot + 1
			success = true
		end
	end
	
	if success then
		itemHandler:UpdateDatabase()
	end
	
	return success 
end

--fill stash with the items from courier
function shopping.FillStash(courier)
	local success = false
	
	if not courier then 
		return success 
	end
	
	--get inventory information
	local inventory = courier:GetInventory()
	local stash = core.unitSelf:GetInventory (true)
	
	--any items to return to stash?
	local tCourierSlots = shopping.tCourierSlots
	if not tCourierSlots then 
		return success 
	end
	
	if shopping.bDebugInfoCourierRelated then BotEcho("Fill Stash") end
	
	-- return items to stash
	local nLastItemSlot = #tCourierSlots
	for slot=7, 12, 1 do 
		local itemInStashSlot = stash[slot]
		local nItemSlot = tCourierSlots[nLastItemSlot]
		local itemInSlot = nItemSlot and inventory[nItemSlot]
		if not itemInSlot then
			if shopping.bDebugInfoCourierRelated then BotEcho("No item in Slot "..tostring(nItemSlot)) end
			tremove(shopping.tCourierSlots)
			nLastItemSlot = nLastItemSlot - 1
		else
			if not itemInStashSlot then
				if shopping.bDebugInfoCourierRelated then BotEcho("Swap "..tostring(nItemSlot).." with "..tostring(slot)) end
				courier:SwapItems(nItemSlot, slot)
				tremove(shopping.tCourierSlots)
				nLastItemSlot = nLastItemSlot - 1
				success = true
			end
		end
	end
	
	local courierSlotsUsed = #shopping.tCourierSlots
	if courierSlotsUsed > 0 then
		if shopping.bDebugInfoCourierRelated then BotEcho("Still items remaining. Selling number of items: "..tostring(courierSlotsUsed)) end
		shopping.SellItems (courierSlotsUsed, courier)
		return shopping.FillStash(courier)
	end
	
	return success 
end

--courier control function
local function CourierMission(botBrain, courier)
	
	local currentState = shopping.nCourierState
	local bOnMission = true
	
	--check current state; 0: setting up courier (after reload); 1: fill courier; 2 deliver; 3 home
	if currentState < 2 then
		if currentState < 1 then
			--we have sth to deliver
			if #shopping.tCourierSlots > 0 then
				shopping.nCourierState = 2
			else
				shopping.nCourierState = 1
			end
		else
			--filling courier phase
			if courier:CanAccessStash() then
				if shopping.bDebugInfoCourierRelated then BotEcho("Stash Access") end
				--fill courier
				local success = shopping.FillCourier(courier)
				if success then
					--Item transfer successfull. Switch to delivery phase
					shopping.nCourierState = 2
				else 
					--no items transfered (no space or no items)
					if currentState == 1.9 then
						--3rd transfer attempt didn't solve the issue, stopping mission
						if shopping.bDebugInfoCourierRelated then BotEcho("Something destroyed courier usage. Courier-Inventory is full or unit has no stash items") end
						bOnMission = false
					else
						--waiting some time before trying again
						if shopping.bDebugInfoCourierRelated then BotEcho("Can not transfer any items. Taking a time-out") end
						local nNow = HoN.GetGameTime()
						shopping.nNextCourierControl = nNow + 5000
						shopping.nCourierState = shopping.nCourierState +0.3
					end
				end
			end
		end
	else
		if currentState < 3 then
			--delivery
			
			--unit is dead? abort delivery
			if not core.unitSelf:IsAlive() then
				if shopping.bDebugInfoCourierRelated then BotEcho("Hero is dead - returning Home") end
				--abort mission and fill stash
				shopping.nCourierState = 3
				
				--home
				local courierHome = courier:GetAbility(3)
				if courierHome then
					core.OrderAbility(botBrain, courierHome, nil, true)
					return bOnMission
				end
			end
			
			-- only cast delivery ability once (else it will lag the courier movement
			if not shopping.bDelivery then
				if shopping.bDebugInfoCourierRelated then BotEcho("Courier uses Delivery!") end
				--deliver
				local courierSend = courier:GetAbility(2)
				if courierSend then
					core.OrderAbility(botBrain, courierSend, nil, true)
					shopping.bDelivery = true
					return bOnMission
				end
			end
			
			--activate speedburst
			local courierSpeed = courier:GetAbility(1) and courier:GetAbility(0)
			if courierSpeed and courierSpeed:CanActivate() then
				core.OrderAbility(botBrain, courierSpeed)
				return bOnMission
			end
			
			--check if courier is near hero to queue home-skill
			local distanceCourierToHeroSq = Vector3.Distance2DSq(courier:GetPosition(), core.unitSelf:GetPosition()) 
			if shopping.bDebugInfoCourierRelated then BotEcho("Distance between courier and hero"..tostring(distanceCourierToHeroSq)) end
			
			if distanceCourierToHeroSq <= shopping.nCourierDeliveryDistanceSq then
				if shopping.bDebugInfoCourierRelated then BotEcho("Courier is in inner circle") end
				
				if not shopping.bUpdateDatabaseAfterDelivery then
					shopping.bUpdateDatabaseAfterDelivery = true
					
					if shopping.bDebugInfoCourierRelated then BotEcho("Activate Home Skill !") end
					--home
					local courierHome = courier:GetAbility(3)
					if courierHome then
						core.OrderAbility(botBrain, courierHome, nil, true)
						return bOnMission
					end
				end
			else
				if shopping.bDebugInfoCourierRelated then BotEcho("Courier is out of range") end
				if shopping.bUpdateDatabaseAfterDelivery then
				
					if shopping.bDebugInfoCourierRelated then BotEcho("Delivery done") end
					shopping.bUpdateDatabaseAfterDelivery = false
					itemHandler:UpdateDatabase()
					
					--remove item entries successfully delivered (item transfer bug protection)
					local inventory = courier:GetInventory(false)
					local index = 1
					while index <= #shopping.tCourierSlots do
						local slot = shopping.tCourierSlots[index]
						local item = slot and inventory[slot]
						if item then
							index = index + 1
						else
							tremove(shopping.tCourierSlots, index)
						end
					end
					if shopping.bDevelopeItemBuildSaver then SyncWithDatabse() end
					shopping.nCourierState = 3
					shopping.bDelivery = false
				end
			end
		else
		
			--unit just respawned after failed mission - try to deliver again
			if core.unitSelf:IsAlive() and shopping.bDelivery then
				if shopping.bDebugInfoCourierRelated then BotEcho("Hero has respawned") end
				--abort mission and fill stash
				shopping.nCourierState = 2
				shopping.bDelivery = false
			end
			
			--Waiting for courier to be usable
			if courier:CanAccessStash() then
				if shopping.bDebugInfoCourierRelated then BotEcho("Courier can access stash. Ending mission") end
				
				shopping.FillStash(courier)
				shopping.nCourierState = 1
				
				bOnMission = false
				if shopping.bDevelopeItemBuildSaver then SyncWithDatabse() end
			end
		end
	end

	return bOnMission
end

--courier repair function
local function CheckCourierBugged(botBrain, courier)
	--Courier is a multi user controlled unit, so it may bugged out
	
	--end of courier mission; don't track courier
	if not shopping.bCourierMissionControl and core.IsTableEmpty(shopping.tCourierSlots) then
		shopping.vecCourierLastPosition = nil
		return
	end
	
	local nNow = HoN.GetGameTime()
	local vecCourierPosition = courier:GetPosition()
	
	--no position set or courier is moving update position and time
	if not shopping.vecCourierLastPosition or Vector3.Distance2DSq(vecCourierPosition, shopping.vecCourierLastPosition) > 100 then
		shopping.vecCourierLastPosition = vecCourierPosition
		shopping.nCourierBuggedTimer	= nNow
		return
	end
		
	--current tracking
	--check for bugs
	if shopping.nCourierState == 2 then
		--want to deliver 
		if shopping.nCourierBuggedTimer + shopping.nCourierDeliveryTimeOut <= nNow then
			--unit is not moving for 1.5s and we want to deliver... request a new delivery order
			--deliver
			local courierSend = courier:GetAbility(2)
			if courierSend then
				core.OrderAbility(botBrain, courierSend, nil, true)
				shopping.bDelivery = true
			end
			shopping.nCourierBuggedTimer = nNow
		end
	else
		--otherwise
		if shopping.nCourierBuggedTimer + shopping.nCourierPositionTimeOut <= nNow then
			--home
			local courierHome = courier:GetAbility(3)
			if courierHome then
				core.OrderAbility(botBrain, courierHome, nil, true)
			end
			shopping.nCourierBuggedTimer = nNow
		end
	end	
	
	if core.unitSelf:IsAlive() then
		shopping.bCourierMissionControl = true
	end
	
end

---------------------------------------------------
-- On think: TeambotBrain  and Courier Control
---------------------------------------------------
function shopping:onThinkShopping(tGameVariables)

	--old onThink
	self:onthinkPreShopOld(tGameVariables)
	
	--Courier Control
	local nNow = HoN.GetGameTime()
	if shopping.nNextCourierControl <= nNow then
	
		shopping.nNextCourierControl = nNow + shopping.nCourierControlIntervall
		
		local courier = shopping.GetCourier()
	
		--no courier? no action
		if courier then
			if shopping.bCourierMissionControl then
				shopping.bCourierMissionControl = CourierMission (self, courier)
			end
			
			--repair courier usage (multi control problems)
			CheckCourierBugged(self, courier)
			
			--activate shield if needed
			local courierShield =  courier:GetAbility(1)
			local nCourierHealthPercent = courier:GetHealthPercent()
			if courierShield and courierShield:CanActivate() and nCourierHealthPercent < 1 then
				if shopping.bDebugInfoCourierRelated then BotEcho("Activate Shield") end
				core.OrderAbility(self, courierShield)
				return 
			end		
		end
	end
	
	--Update itemLists
	shopping.UpdateItemList()
end
object.onthinkPreShopOld = object.onthink
object.onthink 	= shopping.onThinkShopping