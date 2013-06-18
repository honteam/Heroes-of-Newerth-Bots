--[[
Name: Advanced Shopping Library
Current Version: 0.4
Creator: Schnarchnase

Overview:
	This library will advance the bots shopping system.

Features:
	-Use of Courier
	-Upgrade and Rebuy of courier
	-easier itemHandler (Call item by Name, no findItems needed)
	-dynamic Itembuilds supported
	-periodic item purchases (consumables) supported
	-reservation handling supported (don't go for nomes wisdom if another character got one)

Tip: 
	Take a look at the WitchSlayer-Bot to setting your shopping experience!
	
Installation:
Unpack the files in your HoN/game/bots folder

How to use adv.Shopping:

1. Activate the library:
	
	Just run this file for default behavior.
	[LUA]
	runfile "bots/advancedShopping.lua"
	[/LUA]

2. Set the references (if you want to use them:

	[LUA]	
	local itemHandler = object.itemHandler
	local shopping = object.shoppingHandler
	[/LUA]
	
2. Set your preferences:

	Call the setup function

	[LUA]	
	--function 		Setup
	--description:	Select the features of this file
	--parameters: 	bReserveItems:		Shall the bot tell the other bot, that he will go for certain items?
	--				bSkipLaneWaiting:	Shall the bot immediently start shopping?
	--				bCourierCare:		Shall the bot upgrade the courier and rebuy it?
	--				bBuyConsumables:	Shall the bot buy consumables like homecoming stone and potions?
	--				tConsumableOptions:	Consumables, which should be bought
	
	shopping.Setup (bReserveItems, bSkipLaneWaiting, bCourierCare, bBuyConsumables, tConsumableOptions)
	[/LUA]
	
	default consumable options:
	
	[LUA]
	shopping.tConsumables = {
	Item_HealthPotion		= true,
	Item_RunesOfTheBlight	= true,
	--Item_ManaPotion		= true,
	--Item_FlamingEye		= true, --Ward of Sight
	--Item_ManaEye			= true, --Ward of Revelation
	--Item_DustOfRevelation	= true, --Dust
	Item_HomecomingStone	= true
	}
	[/LUA]
	
	Example 1:
	[LUA]
	--standard setup behavior: reserve team items, start shopping immediently, don't care about courier upgrades and buy standard consumables
	--shopping.Setup (bReserveItems, bSkipLaneWaiting, bCourierCare, bBuyConsumables, tConsumableOptions)
	
	shopping.Setup(true, true, false, true) -- Consumable options are not needed, because we don't change them
	[/LUA]
	
	Example 2:
	[LUA]
	--this bot will wait for the lanes to be set, upgrade the courier and will buy homecoming-stones and mana potions.
	--shopping.Setup (bReserveItems, bSkipLaneWaiting, bCourierCare, bBuyConsumables, tConsumableOptions)
	
	local tConsumableOptions =  { Item_HomecomingStone = true, Item_ManaPotion = true}
	shopping.Setup (false, false, true, true, tConsumableOptions)
	[/LUA]
	
	Example 3:
	[LUA]
	--this bot will only buy non reserved team items (such as Nomes Wisdom), start shopping immediently and will buy standard regen and dust on request (see below)
	--shopping.Setup (bReserveItems, bSkipLaneWaiting, bCourierCare, bBuyConsumables, tConsumableOptions)
	
	local tConsumableOptions =  { Item_HomecomingStone = true, Item_HealthPotion = true, Item_RunesOfTheBlight = true, Item_DustOfRevelation = true}
	shopping.Setup (true, true, false, true, tConsumableOptions)
	[/LUA]

3. Request Wards and Dust:
	
	If you have enabled the purchase of wards or dust in the consumable options,
	you will have access to the RequestConsumable function:
	
	[LUA]
	--function 		RequestConsumable
	--description:	Request Ward of Sight, Rev-Wards or Dust
	--parameters: 	name: itemname, you want to purchaise (Wards and dust)
	--				count: number you want to purchase (doubles dust)
	
	function shopping.RequestConsumable (name, count)
	[/LUA]
	
	Example:
	[LUA]
	--Request 3 wards of sight. (if they are out of stock, the bot will skip the purchase)
	--shopping.RequestConsumable (name, count)
	shopping.RequestConsumable ("Item_FlamingEye", 3)
	[/LUA]
	
4. Change the desired item slots (e.g. Your bot should save a slot for wards, if it has some)
	
	default slot reservations:
	
	[LUA]
	--List of desired Items and its Slot
	shopping.DesiredItems = {
		Item_PostHaste 			= 1,
		Item_EnhancedMarchers 	= 1,
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
	[/LUA]
	
	As you can see, boots will always be placed in the first slot. 
	
	Change the desired Slot of an item by the SetItemSlotNumber-function:
	
	[LUA]
	--function 		SetItemSlotNumber
	--description:	Sets the slot for an itemName
	--parameters: 	itemName: Name of the item
	--				slot: Desired slot of this item (leave it to delete an entry)
	
	--returns: 		true if successfully set
	
	shopping.SetItemSlotNumber(itemName, slot)
	[/LUA]
	
	Example:
	[LUA]
	--Save the fifth slot for wards of sight
	--shopping.SetItemSlotNumber(itemName, slot)
	shopping.SetItemSlotNumber("Item_FlamingEye", 5)
	[/LUA]
	
5. How to use the itemHandler

	Just call for the item you want to use per GetItem:
	
	[LUA]
	--function 		GetItem
	--description: 	Returns the chosen item
	--parameters: 	sItemName : Name of the item (e.g. "Item_HomecomingStone"); 
	--				unit : in which inventory is the item? (if nil then core.unitSelf)
	
	--returns:		 the item or nil if not found
	
	itemHandler:GetItem(sItemName, unit)
	[/LUA]
	
	Example:
	[LUA]
	--Call for Astrolabe on unitself 
	local itemAstrolabe = itemHandler:GetItem("Item_Astrolabe")
	
	--call Loggers Hatchet on Booboo
	local itemHandler:GetItem("Item_LoggersHatchet", booboo) 
	[/LUA]

6. How to implement dynamic itembuilds?

	Override the CheckItemBuild function
	
	[LUA]
	--function 		CheckItemBuild	-->>This file should probably be overriden<<--
	--description:	Check your itembuild for some new items
	
	--returns:		true if you should keep buying items
	shopping.CheckItemBuild()
	[/LUA]
	
	This function is called everytime your bot reaches the end of the itembuild-list.
	
	Save your decisions in shopping.ItemDecisions and put your itemcodes in the shopping.Itembuild - list.
	
	Return true, if you have added one or more new items.
	
	Examples:
	[LUA]
	-test itembuild override
	local function WitchSlayerItemBuilder()
		local debugInfo = true
		
		if debugInfo then BotEcho("Checking Itembuilder of Witch Slayer") end
		
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
	[/LUA]
	
7. How to change consumable behavior?

	You are not satisfied with the way consumables are bought? 
	
	Then override the GetConsumables - function to implement it the way you want it to be
	
	[LUA]
	--function 		GetConsumables	-->>This file should probably be overriden<<--
	--description:	Check if the bot needs some new consumables
	
	--returns:		true if you should keep searching for consumables
	function shopping.GetConsumables()
	[/LUA]
	
	This function is called every ten seconds. If you want to change the intervall use this variable
	
	[LUA]
	shopping.checkItemBuildInterval = 10*1000
	[/LUA]
	
	Everytime you think you should buy a ceratin consumable put its item definition (!!) in the following list
	
	[LUA]
	shopping.ShoppingList
	[/LUA]
	
	It is highly recommanded to take a look at the funcion yourself.
	
8. Is it possible to buy steamboots or shamand headress with other components?
	
	Yes it is, if you write a wrapper around the GetAllComponents-function
	
	[LUA]
	--function 		GetAllComponents
	--description:	Get all components of an item definition - including any sub-components 
	--parameters: 	itemDef: the item definition
	
	--returns:		a list of all components (item definitions) of an item (including sub-components)
	shopping.GetAllComponents(itemDef)
	[/LUA]
	
	Just go through the list you receive and replace the definitions you don't want.
	
	Another possibility is to fix the Dawnbringer-Bug (If you have Frostburn, he will buy all three swords)
	Just insert the item definitions of Frostburn, Searing Light and Frozen Light.

9. Save your itembuild progress while developing your bot
	
	While you are programming your bot, you may enounter the problem that your bot looses all decisions (etc.).
	
	This can be prevented by setting the following variable to true
	
	[LUA]
	--developement only - set this to true in your botfiles, while in pre submission phase
	shopping.developeItemBuildSaver = true 
	[/LUA]
	
	Remove this variable, if you are going to the submission phase, because you don't want to save useless stuff on the server
	

10. Random stuff:
	You may want to change the bonus-sell-value for items that are in your desired-slot
	
	[LUA]
	shopping.SellBonusValue = 2000
	[/LUA]
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
local debugInfoGeneralInformation = false
local debugInfoItemHandler = false
local debugInfoShoppingFunctions = false
local debugInfoShoppingBehavior = false
local debugInfoCourierRelated = false

--if debugInfoGeneralInformation then BotEcho("") end

----------------------------------------------------
--important advanced Shopping variables
----------------------------------------------------

--Lists
--Itembuild: list, position and decision
shopping.Itembuild = shopping.Itembuild or {}
shopping.ItembuildPosition = shopping.ItembuildPosition or 1
shopping.ItemDecisions = shopping.ItemDecisions or {}
--Shoppinglist
shopping.ShoppingList = shopping.ShoppingList or {}

--Courier
shopping.bCourierMissionControl = false
shopping.nextFindCourierTime = HoN.GetGameTime()

--other variables
shopping.nextItemBuildCheck = 600*1000
shopping.checkItemBuildInterval = 10*1000

shopping.nextBuyTime = HoN.GetGameTime()
shopping.buyInterval = 250 -- One Shopping Round per Behavior utility call 
shopping.finishedBuying = true

--item is not avaible for shopping, retry it at a later time
shopping.delayedItems = {}

--Give the bot extratime for shopping 
shopping.PreGameDelay = 1000 -- 1 second

--developement only - set this to true in your botfiles, while in pre submission phase
shopping.developeItemBuildSaver = false 

--last time a consumable was purchaised 
shopping.LastConsumablePurchaiseTime = 0

--names of some items
local nameHomecomingStone = "Item_HomecomingStone"
local namePostHaste = "Item_PostHaste"
local nameHealthPostion = "Item_HealthPotion"
local nameBlightRunes = "Item_RunesOfTheBlight"
local nameManaPotions = "Item_ManaPotion"
local nameSightWard = "Item_FlamingEye"
local nameRevealWard = "Item_ManaEye"
local nameDust = "Item_DustOfRevelation"

shopping.tConsumables = {
	Item_HealthPotion		= true,
	Item_RunesOfTheBlight	= true,
	--Item_ManaPotion			= true,
	--Item_FlamingEye			= true, --Ward of Sight
	--Item_ManaEye			= true, --Ward of Revelation
	--Item_DustOfRevelation	= true,  --Dust
	Item_HomecomingStone	= true
	}

--List of desired Items and its Slot
shopping.DesiredItems = {
	Item_PostHaste 			= 1,
	Item_EnhancedMarchers 	= 1,
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


shopping.SellBonusValue = 2000

--check function on a periodic basis
shopping.nextCourierControl = HoN.GetGameTime()
shopping.CourierControlIntervall = 250

--Courierstates: 0: Waiting for Control; 1: Fill Courier; 2: Deliver; 3: Fill Stash
shopping.CourierState = 0

--used item slots by our bot
shopping.courierSlots = {}

--courier delivery ring
shopping.nCourierDeliveryDistanceSq = 500 * 500

--only cast delivery one time (prevents courier lagging)
shopping.bDelivery = false

--Courier Bug Time-Outs
shopping.nCourierDeliveryTimeOut = 1000 
shopping.nCourierPositionTimeOut = shopping.nCourierDeliveryTimeOut + 500

--courier repair variables
shopping.CourierBuggedTimer = 0
shopping.CourierLastPosition = nil

--stop shopping if we are done
shopping.DoShopping = true
--stop shopping if we experience issues like stash is full
shopping.PauseShopping = false


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

returns:		 the item or nil if not found
--]]
function itemHandler:GetItem(sItemName, unit)
       
	   --no item name, no item
        if not sItemName then return end
		--default unit: hero-unit
        if not unit then unit = core.unitSelf end
       
	   --get the item
        local unitID = unit:GetUniqueID()
        local itemEntry = unitID and itemHandler.tItems[unitID..sItemName]
		
		--test if there is an item and if its still usable
        if itemEntry then 
			if itemEntry:IsValid() then
		
				if debugInfoItemHandler then BotEcho("Return Item: "..sItemName) end
			
				--return the item
				return itemEntry
			else
				--item is not usable --> delete it
				itemHandler.tItems[unitID..sItemName] = nil
			end
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
	if not curItem then return end
	--default unit:  hero-unit
	if not unit then unit = core.unitSelf end
	
	--get info about unit and item
	local unitID = unit:GetUniqueID()
	local sItemName = curItem:GetName()
	
	--be sure that there is no item in database
	if not itemHandler:GetItem(unitID..sItemName) then
		
		--add item
		 itemHandler.tItems[unitID..sItemName] = core.WrapInTable(curItem)
		
		if debugInfoItemHandler then BotEcho("Add Item: "..sItemName) end
		
		--return success
		return true
	end
	
	if debugInfoItemHandler then BotEcho("Item already in itemHandler: "..sItemName) end
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
		if debugInfoItemHandler then BotEcho("Clear list") end
		for slot, item in pairs(itemHandler.tItems) do
			if item and not item:IsValid() then
				--item is not valid remove it
				 itemHandler.tItems[slot] = nil
			end
		end
	end
	
    --hero Inventory
    local inventory = unitSelf:GetInventory()
	
	--insert all items of his inventory
    for slot = 1, 6, 1 do
        local curItem = inventory[slot]
        itemHandler:AddItem(curItem, unitSelf)
    end
       
    --all other inventory units (Couriers, Booboo)
    local inventoryUnits = core.tControllableUnits["InventoryUnits"]
	
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


--debug function
local function developeDatabaseSync()
	
	local entry = object.myName
	
	--BotEcho("my name is "..entry)
	
	--load values
	if not shopping.bDatabaseLoaded then
		if debugInfoGeneralInformation then BotEcho("Loading Database") end
		shopping.bDatabaseLoaded = true
		local result = GetDBEntry(entry, entry, false, HoN.GetRemainingPreMatchTime() > 0)
		if result then
			if debugInfoGeneralInformation then BotEcho("Found entries in database") end
			valTable = result.value
			if valTable then
				if debugInfoGeneralInformation then BotEcho("Reloading bot decisions") end
				--have entries -- unpack them
					shopping.Itembuild = valTable[1]
					shopping.ItembuildPosition = valTable[2]
					shopping.ItemDecisions = valTable[3]
					shopping.delayedItems = valTable[4]
			end
		end
	end
	
	--save values
	local tableSaver = {value = {}}
	local dataToSave = tableSaver.value
	tinsert (dataToSave, shopping.Itembuild)
	tinsert (dataToSave, shopping.ItembuildPosition)
	tinsert (dataToSave, shopping.ItemDecisions)
	tinsert (dataToSave, shopping.delayedItems)
	
	--GetDBEntry(entry, value, saveToDB, restoreDefault, setDefault)
	GetDBEntry(entry, tableSaver, true)
end

----------------------------------------------------
----------------------------------------------------
--			Shopping - Handler 
----------------------------------------------------
----------------------------------------------------

--function Setup
--[[
description:	Select the features of this file
parameters: 	bReserveItems:		Shall the bot tell the other bot, that he will go for certain items?
				bSkipLaneWaiting:	Shall the bot immediently start shopping?
				bCourierCare:		Shall the bot upgrade the courier and rebuy it?
				bBuyConsumables:	Shall the bot buy consumables like homecoming stone and potions?
				tConsumableOptions:	Consumables, which should be bought
				
--]]
function shopping.Setup (bReserveItems, bSkipLaneWaiting, bCourierCare, bBuyConsumables, tConsumableOptions)

	--initialize shopping
	shopping.BuyItems = true
	shopping.bSetupDone = true
	
	--Check, if item is already reserved by a bot or a player (basic) and update function for teambot
	shopping.CheckItemReservation = bReserveItems
	
	--Wait for lane decision before shopping?
	shopping.PreGameWaiting = not bSkipLaneWaiting
	
	--Consumables options
	shopping.BuyConsumables = bBuyConsumables
	if bBuyConsumables and type(tConsumableOptions) == "table" then
		shopping.tConsumables = tConsumableOptions
	end
	
	--Courier options
	shopping.bCourierCare = bCourierCare
	
end

--function GetCourier
--[[
description:	Returns the main courier

returns: the courier unit, if found
--]]
function shopping.GetCourier()
	
	--get saved courier
	local unitCourier = shopping.courier
	--if it is still alive return it
	if unitCourier and unitCourier:IsValid() then return unitCourier end
	
	local nNow = HoN.GetGameTime()
	if shopping.nextFindCourierTime > nNow then
		return		
	end	
	
	shopping.nextFindCourierTime = nNow + 1000
	
	if debugInfoShoppingFunctions then BotEcho("Courier was not found. Checking inventory units") end
	
	--Search for a courier
	local controlUnits = core.tControllableUnits["InventoryUnits"]
	for key, unit in pairs(controlUnits) do
		if unit then 
			local sUnitName = unit:GetTypeName()
			--Courier Check
			if sUnitName == "Pet_GroundFamiliar" or sUnitName == "Pet_FlyngCourier" then
				if debugInfoShoppingFunctions then BotEcho("Found Courier!") end
				
				if unit:GetOwnerPlayer() == core.unitSelf:GetOwnerPlayer() then
					unit:TeamShare()
				end
				
				--set references an return the courier
				shopping.courier = unit
				return unit
			end
		end
	end
end

--check if courier, needs further attention
function shopping.CareAboutCourier(botBrain)
	--Courier Stuff
	--------------------------------------------------
	if HoN.GetMatchTime() <= 0 then return end 
	
	--get courier
	local courier = shopping.GetCourier()
	--do we have a courier
	if courier then 
		--got a ground courier? Send Upgrade-Order
		if courier:GetTypeName() == "Pet_GroundFamiliar" then
			if debugInfoShoppingFunctions then BotEcho("Courier needs an upgrade - Will do it soon") end
			shopping.courierDoUpgrade = true
		end
	else		
		--no courier - buy one
		if debugInfoShoppingFunctions then BotEcho("No Courier found, may buy a new one.") end
		shopping.BuyNewCourier = HoN.GetItemDefinition("Item_GroundFamiliar")
	end		
	
end

--function RequestConsumable
--[[
description:	Request Ward of Sight, Rev-Wards or Dust
parameters: 	name: itemname, you want to purchaise (Wards and dust)
				count: number you want to purchase (doubles dust)
--]]
function shopping.RequestConsumable (name, count)
	local entry = tConsumables[name]
	if entry ~= nil and type(count) == "number" then
		if type(entry) == "number" then
			tConsumables[name] = entry + count
		else
			tConsumables[name] = count
		end
	end			
end

--function GetConsumables	-->>This file should probably be overriden<<--
--[[
description:	Check if the bot needs some new consumables

returns:		true if you should keep searching for consumables
--]]
function shopping.GetConsumables()
	
	if debugInfoGeneralInformation then BotEcho("You may want to override this function: shopping.GetConsumables()") end
	
	--actual time
	local nNow = HoN.GetMatchTime()
	
	
	local tConsumables = shopping.tConsumables
	
	
	--purchaise bugged out reset it
	if shopping.LastConsumablePurchaiseTime + 300000 <= nNow then
		for name, value in pairs (tConsumables) do
			shopping.tConsumables[name] = true
		end
	end
	
	local bKeepBuyingConsumables = false
	
	--get info about ourSelf 
	local unitSelf = core.unitSelf
	local courier = shopping.courier
	local level = unitSelf:GetLevel()
	local gold = object:GetGold()
	
	--regen stuff
	--------------------------------------------------
	
	if level < 10 then 
		local healthP = unitSelf:GetHealthPercent()
		local manaP = unitSelf:GetManaPercent()
		
		if tConsumables[nameBlightRunes] ~= nil and gold >= 90 then
			
			--only buy runes if we don't have one already
			local gotRunes = itemHandler:GetItem(nameBlightRunes)
			if gotRunes then
				tConsumables[nameBlightRunes] = true
			else
				if tConsumables[nameBlightRunes] and healthP < 0.8 and healthP >= 0.6 then
					
					--buy one set of Blight  Stones
					local itemDef = HoN.GetItemDefinition(nameBlightRunes)
					tinsert(shopping.ShoppingList, 1, itemDef)
					gold = gold - 90
					
					tConsumables[nameBlightRunes] = false
					shopping.LastConsumablePurchaiseTime = nNow
				else
					-- we don't have them, but we already have one instance in queue (or not needed)
				end
			end
		end
		
		if tConsumables[nameHealthPostion] ~= nil then 
			--only buy healthpot if we don't have one already
			local gotHealthPot = itemHandler:GetItem(nameHealthPostion)
			if gotHealthPot then
				tConsumables[nameHealthPostion] = true
			else
				if tConsumables[nameHealthPostion] and healthP < 0.6 and gold >= 100 then
					
					--buy one Potion
					local itemDef = HoN.GetItemDefinition(nameHealthPostion)
					tinsert(shopping.ShoppingList, 1, itemDef)
					gold = gold - 100
					
					tConsumables[nameHealthPostion] = false
					shopping.LastConsumablePurchaiseTime = nNow
				else
					-- we don't have a potion, but we already have one in queue (or not needed)
				end
			end
		end
		
		if tConsumables[nameManaPotions] ~= nil then
			--only buy manapot if we don't have one already
			local gotManaPot = itemHandler:GetItem(nameManaPotions)
			if gotManaPot then
				tConsumables[nameManaPotions] = true
			else
				if tConsumables[nameManaPotions] and manaP < 0.3 and gold >= 50 then
					
					--buy one Mana Potion
					local itemDef = HoN.GetItemDefinition(nameManaPotions)
					tinsert(shopping.ShoppingList, 1, itemDef)
					gold = gold - 50
					
					tConsumables[nameManaPotions] = false
					shopping.LastConsumablePurchaiseTime = nNow
				else
					-- we don't have a potion, but we already have one in queue (or not needed)
				end
			end
		end
		bKeepBuyingConsumables = true
	end

	--homecoming stone
	--------------------------------------------------
	
	if tConsumables[nameHomecomingStone] ~= nil then
		--only buy stones if we have not Post Haste
		local itemPostHaste = itemHandler:GetItem(namePostHaste)
		if not itemPostHaste then 
		
			--only buy stones if we don't have one already and we are at least level 3
			local stone = itemHandler:GetItem(nameHomecomingStone)
			if stone then
				tConsumables[nameHomecomingStone] = true
			else
				if tConsumables[nameHomecomingStone] and level > 2 and gold >= 135 then
					
					--buy homecoming stone
					local itemDef = HoN.GetItemDefinition(nameHomecomingStone)
					tinsert(shopping.ShoppingList, 1, itemDef)
					gold = gold - 135
					if gold >= 135 and HoN.GetMatchTime() > 600000 then --10 minutes
						tinsert(shopping.ShoppingList, 1, itemDef)
						gold = gold - 135
					end
					tConsumables[nameHomecomingStone] = false
					shopping.LastConsumablePurchaiseTime = nNow
				else
					-- we don't have a stone, but we already have one in queue (or under level 3)
				end
			end
			if debugInfoShoppingFunctions then BotEcho("Homecoming Stone Status: tConsumables[stone]: "..tostring(tConsumables[nameHomecomingStone]).." and have stone: "..tostring(stone)) end
			bKeepBuyingConsumables = true
		end
	end
	
	--Wards
	local wardEntry = tConsumables[nameSightWard]
	if type(wardEntry) == "number" then
		local nWardsNumber = wardEntry
		local itemDef = wardEntry > 0 and HoN.GetItemDefinition(nameSightWard)
		while nWardsNumber > 0 and gold >= 100 do
			tinsert(shopping.ShoppingList, 1, itemDef)
			gold = gold - 100
			nWardsNumber = nWardsNumber - 1
			shopping.LastConsumablePurchaiseTime = nNow
		end
		tConsumables[nameSightWard] = nWardsNumber
		bKeepBuyingConsumables = true
	end
	
	--RevWards
	wardEntry = tConsumables[nameRevealWard]
	if type(wardEntry) == "number" then
		local nWardsNumber = wardEntry
		local itemDef = wardEntry > 0 and HoN.GetItemDefinition(nameRevealWard)
		while nWardsNumber > 0 and gold >= 100 do
			tinsert(shopping.ShoppingList, 1, itemDef)
			gold = gold - 100
			nWardsNumber = nWardsNumber - 1
			shopping.LastConsumablePurchaiseTime = nNow
		end
		tConsumables[nameRevealWard] = nWardsNumber
		bKeepBuyingConsumables = true
	end
	
	--Dust
	wardEntry = tConsumables[nameDust]
	if type(wardEntry) == "number" then
		local nWardsNumber = wardEntry
		local itemDef = wardEntry > 0 and HoN.GetItemDefinition(nameDust)
		while nWardsNumber > 0 and gold >= 180 do
			tinsert(shopping.ShoppingList, 1, itemDef)
			gold = gold - 100
			nWardsNumber = nWardsNumber - 1
			shopping.LastConsumablePurchaiseTime = nNow
		end
		tConsumables[nameDust] = nWardsNumber
		bKeepBuyingConsumables = true
	end
	return bKeepBuyingConsumables
end

--function CheckItemBuild	-->>This file should probably be overriden<<--
--[[
description:	Check your itembuild for some new items

returns:		true if you should keep buying items
--]]
function shopping.CheckItemBuild()

	if debugInfoGeneralInformation then BotEcho("You may want to override this function: shopping.CheckItemBuild()") end
	
	--just convert the standard lists into the new shopping list
	if shopping.Itembuild then
		if #shopping.Itembuild == 0 then
			core.InsertToTable(shopping.Itembuild, behaviorLib.StartingItems)
			core.InsertToTable(shopping.Itembuild, behaviorLib.LaneItems)
			core.InsertToTable(shopping.Itembuild, behaviorLib.MidItems)
			core.InsertToTable(shopping.Itembuild, behaviorLib.LateItems)
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
			BotEcho("Error: GetComponents returns no value. Purchaise may bug out")
		end
	else
		BotEcho("Error: No itemDef found")
	end
	
	if debugInfoShoppingFunctions then
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
			if debugInfoShoppingFunctions then BotEcho("Removing itemdef "..tostring(value)) end
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
	if debugInfoShoppingFunctions then BotEcho("Checking Inventory Stuff") end
	
	if not tComponents then return end
	
	--result table
	local tResult = core.CopyTable(tComponents)
	
	--info about ourself
	local unit = core.unitSelf 
	local inventory = unit:GetInventory(true)
	
	--courier items 
	local courier = shopping.GetCourier()
	if courier then
		local courierInventory = courier:GetInventory(false)
		for index, slot in ipairs (shopping.courierSlots) do
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
						if debugInfoShoppingFunctions then BotEcho("Found component. Name"..compDef:GetName()) end
						
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
			if debugInfoShoppingFunctions then BotEcho("Removing elements itemName"..itemDef:GetName()) end
			
			--fount an item
			if item then
				if debugInfoShoppingFunctions then BotEcho("Found item") end
				
				local bRecipe = item:IsRecipe() 
				local level = not bRecipe and item:GetLevel() or 0
				
				if bRecipe then
					--item is a recipe remove the first encounter
					if debugInfoShoppingFunctions then BotEcho("this is a recipe") end
					shopping.RemoveFirstByValue(tResult, itemDef)
				else
					--item is no recipe, take further testing
					if debugInfoShoppingFunctions then BotEcho("not a recipe") end
					
					--remove level-1 recipes
					while level > 1 do
						shopping.RemoveFirstByValue(tResult, itemDef)
						level = level -1
					end
					
					--get sub-components
					local components = shopping.GetAllComponents(itemDef)
					
					--remove all sub-components and itself
					for _,val in pairs (components) do
						if debugInfoShoppingFunctions then BotEcho("Removing Component. "..val:GetName()) end
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
	local itemList = shopping.Itembuild
	local listPos = shopping.ItembuildPosition
	
	--check if there are no more items to buy
	if  listPos > #itemList then
		--get new items
		if debugInfoShoppingFunctions then BotEcho("Shopping.Itembuild: Index Out of Bounds. Check for new stuff") end
		 bKeepShopping = shopping.CheckItemBuild()
	end
	
	--Get next item and put it into Shopping List
	if bKeepShopping then
		--go to next position
		shopping.ItembuildPosition = listPos + 1
		
		if debugInfoShoppingFunctions then BotEcho("Next Listposition:"..tostring(listPos)) end
		
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
		
		if debugInfoShoppingFunctions then BotEcho("Name "..name.." Anzahl "..num.." Level"..level) end
				
		
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
			if debugInfoShoppingFunctions then BotEcho("Remaining Components:") end
			for compSlot, compDef in ipairs (tReaminingItems) do
				if compDef then
					local defName = compDef:GetName()
					if debugInfoShoppingFunctions then BotEcho("Component "..defName) end
					--only insert component if it not an autocombined element
					if  defName ~= name or not compDef:GetAutoAssemble() then
						tinsert(shopping.ShoppingList, compDef)
					end
				end
			end
		else
			if debugInfoShoppingFunctions then BotEcho("No remaining components. Skip this item (If you want more items of this type increase number)") end
			return GetNextItem()
		end
		
	end
	
	if debugInfoShoppingFunctions then BotEcho("bKeepShopping? "..tostring(bKeepShopping)) end
	
	return bKeepShopping
end

--function Print All
--[[
description:	Print Your itembuild-list, your current itembuild-list position and your shopping-list

--]]
function shopping.printAll()
	
	--references to the lists
	local itemBuild = shopping.Itembuild 
	local shoppingList = shopping.ShoppingList
	local position = shopping.ItembuildPosition 
	
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
description:	Updates your itembuild-list and your shopping-list on a periodicly basis. Update can be forced
parameters: 	botBrain: botBrain 
				bForceUpdate: Force a list update (usually called if your shopping-list is empty)

--]]
function shopping.UpdateItemList(botBrain, bForceUpdate)
	
	--get current time
	local nNow =  HoN.GetGameTime()
	
	--default setup if it is not overridden by the implementing bot
	if not shopping.bSetupDone then
		--function shopping.Setup (bReserveItems, bSkipLaneWaiting, bCourierCare, bBuyConsumables, tConsumableOptions)
		shopping.Setup(true, true, false, true)
	end

	
	--Check itembuild every now and then or force an update
	if shopping.nextItemBuildCheck <= nNow or bForceUpdate then
		if debugInfoShoppingFunctions then BotEcho(tostring(shopping.nextItemBuildCheck).." Now "..tostring(nNow).." Force Update? "..tostring(bForceUpdate)) end
		
		if shopping.developeItemBuildSaver and bForceUpdate then developeDatabaseSync() end
		if shopping.ShoppingList then
			--Is your Shopping list empty? get new item-components to buy
			if #shopping.ShoppingList == 0 and shopping.BuyItems then
				if debugInfoShoppingFunctions then BotEcho("Checking for next item") end
				shopping.BuyItems = GetNextItem()
			end
			--check for consumables
			if shopping.BuyConsumables then
				if debugInfoShoppingFunctions then BotEcho("Checking for Consumables") end
				shopping.BuyConsumables = shopping.GetConsumables()
			end		
			--Are we in charge to buy and upgrade courier?
			if shopping.bCourierCare then
				if debugInfoShoppingFunctions then BotEcho("Care about Courier") end
				shopping.CareAboutCourier(botBrain)
			end
			
			--check for delayed items
			local tDelayedItems = shopping.delayedItems
			if #tDelayedItems > 0 then
				if debugInfoShoppingFunctions then BotEcho("Found delayed items") end
				local success = false
				--check if there are any items off cooldown
				for i, listEntry in ipairs(tDelayedItems) do
					local nTime, itemDef = listEntry[1], listEntry[2]
					if nTime <= nNow then
						--try to re-purchase this item
						if debugInfoShoppingFunctions then BotEcho("Insert Entry in shopping list") end
						tinsert(shopping.ShoppingList,1, itemDef)
						success = i
						break;
					end
				end
				if success then
					tremove (shopping.delayedItems, success)
				end				
			end							
		end
		--reset cooldown
		shopping.nextItemBuildCheck = nNow + shopping.checkItemBuildInterval
		if debugInfoShoppingFunctions then shopping.printAll() end
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
	
	if not itemName then return false end
	
	--insert slot number or delete entry if slot is nil
	shopping.DesiredItems[itemName] = slot
	
	return true
end

--function GetItemSlotNumber
--[[ 
description:	Get the desired Slot of an item
parameters: 	itemName: Name of the item

returns: 		the number of the desired Slot
--]]
function shopping.GetItemSlotNumber(itemName)
	local desiredItems = shopping.DesiredItems
	return desiredItems and desiredItems[itemName] or 0
end


--function pair(a, b) -->	helper-function for sorting tables
--[[
description:	Checks if a table element is smaller than another one
parameters:		a: first table element
				b: second table element
				
returns:		true if a is smaller than b
--]]
local function pair(a, b) return a[1] < b[1] end

--function SortItems 
--[[
description:	Sort the items in the units inventory 
parameters: 	unit: The unit which should sort its items

returns 		true if the inventory was changed
--]]
function shopping.SortItems (unit)
	local bChanged = false
	
	if debugInfoShoppingFunctions then BotEcho("Sorting items probably") end
	
	--default unit hero-unit
	if not unit then unit = core.unitSelf end
	
	--get inventory
	local inventory = unit:GetInventory(true)
	
	--item slot list	
	local tSlots = 		{false, false, false, false, false, false}
	
	--list of cost and slot pairs
	local tValueList = {}
	
	--index all items
	for slot, item in pairs (inventory) do
		if debugInfoShoppingFunctions then BotEcho("Current Slot"..tostring(slot)) end
		
		--only add non recipe items
		if not item:IsRecipe() then 
			
			--get item info
			local itemName = item:GetName()			
			local itemTotalCost = item:GetTotalCost()
			if debugInfoShoppingFunctions then BotEcho("Item "..itemName) end
			
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
				if debugInfoShoppingFunctions then BotEcho("Swapping Slot "..tostring(thisItemSlot).." with "..tostring(slot)) end
				
				--swap items
				unit:SwapItems(thisItemSlot, slot)
				
				bChanged = true
			end
		end
	end
	
	if debugInfoShoppingFunctions then 
		BotEcho("Sorting Result: "..tostring(bChanged)) 
		for position, fromSlot in pairs (tSlots) do
			BotEcho("Item in Slot "..tostring(position).." was swapped from "..tostring(fromSlot))
		end
	end
	
	return bChanged
end

--function SellItems 
--[[
description:	Sell a number off items from the unit's inventory (inc.stash)
parameters: 	number: Number of items to sell; 
				unit: Unit which should sell its items
				itemdef: sell restirction for item definiton

returns:		true if the items were succcessfully sold
--]]
function shopping.SellItems (number, unit)
	local bChanged = false
	
	--default unit: hero-unit
	if not unit then unit = core.unitSelf end
	
	--default number: 1; return if there is a negative value
	if not number then number = 1
	elseif number < 1 then return bChanged 
	end
	
	--get inventory
	local inventory = unit:GetInventory(true)
	
	--list of cost and slot pairs
	local tValueList = {}
	
	--index all items
	for slot, item in pairs (inventory) do
		--insert only non recipe items
		if not item:IsRecipe() then 
			local itemTotalCost = item:GetTotalCost()
			local itemName = item:GetName()
			--give the important items a bonus in gold (Boots, Mystic Vestments etc.)
			if slot == shopping.GetItemSlotNumber(itemName) then
				itemTotalCost = itemTotalCost + shopping.SellBonusValue
			end
			--insert item in the list
			tinsert(tValueList, {itemTotalCost, slot})
			if debugInfoShoppingFunctions then BotEcho("Insert Slotnumber: "..tostring(slot).." Item "..itemName.." Price "..tostring(itemTotalCost)) end
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
			if debugInfoShoppingFunctions then BotEcho("I am selling slotnumber"..tostring(slot)) end
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

-------- Behavior Fns --------
--Util
function shopping.ShopUtility(botBrain)

	local utility = 0
	
	--don't shop till we know where to go
	if shopping.PreGameWaiting then
		if HoN.GetRemainingPreMatchTime() >= core.teamBotBrain.nInitialBotMove then 
			return utility 
		else
			shopping.PreGameWaiting = false
		end
	end
	
	local myGold = botBrain:GetGold()
	
	local unitSelf = core.unitSelf
	local bCanAccessStash = unitSelf:CanAccessStash()
	
	--courier care
	if shopping.bCourierCare then 
		local courier = shopping.GetCourier()
		if shopping.BuyNewCourier then
			if courier then					
				--there is a courier, noone needs to buy one
				shopping.BuyNewCourier = nil
				shopping.PauseShopping = false
			else
				shopping.PauseShopping = true
				if myGold >= 200 and bCanAccessStash then 
					tinsert(shopping.ShoppingList, 1, shopping.BuyNewCourier)
					shopping.BuyNewCourier = nil
					shopping.PauseShopping = false
				end
			end
		end
		if shopping.courierDoUpgrade and myGold >= 200 then
			if courier then
				shopping.courierDoUpgrade = false
				if courier:GetTypeName() == "Pet_GroundFamiliar" then
					local courierUpgrade = courier:GetAbility(0)
					core.OrderAbility(botBrain, courierUpgrade)
					myGold = myGold - 200
				end
			end
		end
	end
	
	--still items to buy?
	if shopping.DoShopping and not shopping.PauseShopping then 
		
		if not behaviorLib.finishedBuying then
			utility = 30
		end
		
		--if debugInfoShoppingBehavior then BotEcho("Check next item") end
		local nextItemDef = shopping.ShoppingList and shopping.ShoppingList[1]
		
		if not nextItemDef then
			if debugInfoShoppingBehavior then BotEcho("No item definition in Shopping List. Start List update") end
			shopping.UpdateItemList(botBrain, true)
			nextItemDef = shopping.ShoppingList[1]
		end
		
		
		if nextItemDef then 
			--if debugInfoShoppingBehavior then BotEcho("Found item! Name"..nextItemDef:GetName()) end
		
			if myGold > nextItemDef:GetCost() then
				if debugInfoShoppingBehavior then BotEcho("Enough gold to buy the item. Current gold: "..tostring(myGold)) end	
				utility = 30
				behaviorLib.finishedBuying = false
				if bCanAccessStash then
					if debugInfoShoppingBehavior then BotEcho("Hero can access shop") end
					utility = 99						
				end				
			end
		else
			BotEcho("Error no next item...Stopping any shopping")
			shopping.DoShopping = false
		end
		
	end
	--if debugInfoShoppingBehavior then BotEcho("Returning Shop utility: "..tostring(utility)) end
	return utility
end

function shopping.ShopExecute(botBrain)

	if debugInfoShoppingBehavior then BotEcho("Shopping Execute:") end
	
	local nNow = HoN.GetGameTime()
	
	--Space out your buys (one purchase per behavior-utility cycle)
	if shopping.nextBuyTime > nNow then
		--if debugInfoShoppingBehavior then BotEcho("Shop closed") end
		return false
	end

	shopping.nextBuyTime = nNow + shopping.buyInterval
		
	local unitSelf = core.unitSelf

	local bChanged = false
	local inventory = unitSelf:GetInventory(true)
	local nextItemDef = shopping.ShoppingList[1]
		
	if nextItemDef then
		if debugInfoShoppingBehavior then BotEcho("Found item. Buying "..nextItemDef:GetName()) end
		
		local goldAmtBefore = botBrain:GetGold()
		local nItemCost = nextItemDef:GetCost()
		
		--enough gold to buy the item?
		if goldAmtBefore >= nItemCost then 
			
			--check number of stash items
			local openSlots = shopping.NumberSlotsOpenStash(inventory)
			--enough space?
			if openSlots < 1 then
				local bSuccess, bStashOnly = shopping.SellItems (1)
				shopping.PauseShopping = not bSuccess or not bStashOnly
			else
				core.teamBotBrain.bPurchasedThisFrame = true
				unitSelf:PurchaseRemaining(nextItemDef)
		
				local goldAmtAfter = botBrain:GetGold()
				local bGoldReduced = (goldAmtAfter < goldAmtBefore)
				--check purchase success
				if bGoldReduced then 
					if debugInfoShoppingBehavior then BotEcho("item Purchased. removing it from shopping list") end
					tremove(shopping.ShoppingList,1)
					if shopping.developeItemBuildSaver then developeDatabaseSync() end
				else
					local maxStock = nextItemDef:GetMaxStock()
                    if maxStock > 0 then
						-- item may not be purchaseble, due to cooldown, so skip it
						if debugInfoShoppingBehavior then BotEcho("Item not purchaseable due to cooldown. Item will be skipped") end
						tremove(shopping.ShoppingList,1)
						--re-enter bigger items after cooldown delay 
						if nItemCost > 250 then
							if debugInfoShoppingBehavior then BotEcho("Item is valuble, will try to repurchaise it after some delay") end
							local nItemRestockedTime = nNow + 120000
							tinsert (shopping.delayedItems, {nItemRestockedTime, nextItemDef})
						end
					else
						if debugInfoShoppingBehavior then BotEcho("No Purchase of "..nextItemDef:GetName()..". Unknown exception waiting for stash access to fix it.") end
						shopping.PauseShopping = true
					end						
				end	
				bChanged = bChanged or bGoldReduced
			end
		end
		
		
		
		
	end
	
	--finished buying
	if bChanged == false then
		if debugInfoShoppingBehavior then BotEcho("Finished Buying!") end
		behaviorLib.finishedBuying = true
		shopping.bStashFunctionActivation = true
		local bCanAccessStash = unitSelf:CanAccessStash()
		if not bCanAccessStash then 
			if debugInfoShoppingBehavior then  BotEcho("CourierStart") end
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
	
	if debugInfoShoppingBehavior and utility > 0 then BotEcho("Stash utility: "..tostring(utility)) end

	return utility
end
 
function shopping.StashExecute(botBrain)
	
	local bSuccess = false
	
	local unitSelf = core.unitSelf
	local bCanAccessStash = unitSelf:CanAccessStash()
	
	if debugInfoShoppingBehavior then BotEcho("CanAccessStash (true is right) "..tostring(bCanAccessStash)) end
	
	--we can access the stash so just sort the items
	if bCanAccessStash then
		if debugInfoShoppingBehavior then BotEcho("Sorting items soon") end
		
		bSuccess = shopping.SortItems (unitSelf) 
		
		if debugInfoShoppingBehavior then BotEcho("Sorted items"..tostring(bSuccess)) end
		
		--don't sort items again in this stash-meeting (besides if we are using a tp)
		shopping.bStashFunctionActivation = false
		
		--all Stashproblems should be fixed now
		shopping.PauseShopping = false
		
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
	
	if debugInfoItemHandler then BotEcho("Ok, it is time to update the Find-Item references") end
	
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
-- Downscale PreGameUtility (Better Shopping Experience)
---------------------------------------------------
function shopping.PreGameUtility(botBrain)
	if HoN:GetMatchTime() <= 0 then
		return 29
	end
	return 0
end
behaviorLib.PreGameBehavior["Utility"] = shopping.PreGameUtility

function shopping.PreGameExecute(botBrain)
	if HoN.GetRemainingPreMatchTime() > core.teamBotBrain.nInitialBotMove - shopping.PreGameDelay then        
		core.OrderHoldClamp(botBrain, core.unitSelf)
	else
		local vecTargetPos = behaviorLib.PositionSelfTraverseLane(botBrain)
		core.OrderMoveToPosClamp(botBrain, core.unitSelf, vecTargetPos, false)
	end
end
behaviorLib.PreGameBehavior["Execute"] = shopping.PreGameExecute

---------------------------------------------------
--Further Courier Functions
---------------------------------------------------

--fill courier with stash items and remeber the transfered slot
function shopping.FillCourier(courier)
	local success = false
	
	if not courier then return success end
	
	if debugInfoCourierRelated then BotEcho("Fill COurier") end
	
	--get info about inventory
	local inventory = courier:GetInventory()
	local stash = core.unitSelf:GetInventory (true)
	
	local tSlotsOpen = {}
	
	--check open courier slots
	for  slot = 1, 6, 1 do
		local item = inventory[slot]
		if not item then 
			if debugInfoCourierRelated then BotEcho("Slot "..tostring(slot).." is free") end
			tinsert(tSlotsOpen, slot)
		end
	end
	--transfer items to courier
	local openSlot = 1
	for slot=12, 7, -1 do 
		local curItem = stash[slot]
		local freeSlot = tSlotsOpen[openSlot]
		if curItem and freeSlot then
			if debugInfoCourierRelated then BotEcho("Swap "..tostring(slot).." with "..tostring(freeSlot)) end
			courier:SwapItems(slot, freeSlot)
			tinsert(shopping.courierSlots, freeSlot)
			openSlot = openSlot + 1
			success = true
		end
	end
	
	return success 
end

--fill stash with the items from courier
function shopping.FillStash(courier)
	local success = false
	
	if not courier then return success end
	
	--get inventory information
	local inventory = courier:GetInventory()
	local stash = core.unitSelf:GetInventory (true)
	
	--any items to return to stash?
	local tCourierSlots = shopping.courierSlots
	if not tCourierSlots then return success end
	
	if debugInfoCourierRelated then BotEcho("Fill Stash") end
	
	-- retrun items
	local nLastItemSlot = #tCourierSlots
	for slot=7, 12, 1 do 
		local itemInStashSlot = stash[slot]
		local nItemSlot = tCourierSlots[nLastItemSlot]
		local itemInSlot = nItemSlot and inventory[nItemSlot]
		if not itemInSlot then
			if debugInfoCourierRelated then BotEcho("No item in Slot "..tostring(nItemSlot)) end
			tremove(shopping.courierSlots)
			nLastItemSlot = nLastItemSlot - 1
		else
			if not itemInStashSlot then
				if debugInfoCourierRelated then BotEcho("Swap "..tostring(nItemSlot).." with "..tostring(slot)) end
				courier:SwapItems(nItemSlot, slot)
				tremove(shopping.courierSlots)
				nLastItemSlot = nLastItemSlot - 1
				success = true
			end
		end
	end
	
	return success 
end

--courier control function
local function CourierMission(botBrain, courier)
	
	local currentState = shopping.CourierState
	local bOnMission = true
	
	--check current state; 0: waiting for courier; 1: fill courier; 2 deliver; 3 home
	if currentState < 2 then
		if currentState < 1 then
			--Waiting for courier to be usable
			if courier:CanAccessStash() then
				if debugInfoCourierRelated then BotEcho("Courier can access stash") end
				--activate second phase: fill courier
				shopping.CourierState = 1
			end
		else
			--filling courier phase
			if courier:CanAccessStash() then
				if debugInfoCourierRelated then BotEcho("Stash Access") end
				--fill courier
				local success = shopping.FillCourier(courier)
				if success then
					--Item transfer successfull. Switch to delivery phase
					shopping.CourierState = 2
				else 
					--no items transfered (no space or no items)
					if currentState == 1.9 then
						--3rd transfer attempt didn't solve the issue, stopping mission
						if debugInfoCourierRelated then BotEcho("Something destroyed courier usage. Courier-Inventory is full or unit has no stash items") end
						bOnMission = false
					else
						--waiting some time before trying again
						if debugInfoCourierRelated then BotEcho("Can not transfer any items. Taking a time-out") end
						local nNow = HoN.GetGameTime()
						shopping.nextCourierControl = nNow + 5000
						shopping.CourierState = shopping.CourierState +0.3
					end
				end
			end
		end
	else
		if currentState < 3 then
			--delivery
			
			--unit is dead? abort delivery
			if not core.unitSelf:IsAlive() then
				if debugInfoCourierRelated then BotEcho("Hero is dead - returning Home") end
				--abort mission and fill stash
				shopping.CourierState = 3
				
				--home
				local courierHome = courier:GetAbility(3)
				if courierHome then
					core.OrderAbility(botBrain, courierHome, nil, true)
					return bOnMission
				end
			end
			
			-- only cast delivery ability once (else it will lag the courier movement
			if not shopping.bDelivery then
				if debugInfoCourierRelated then BotEcho("Courier uses Delivery!") end
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
			if debugInfoCourierRelated then BotEcho("Distance between courier and hero"..tostring(distanceCourierToHeroSq)) end
			if distanceCourierToHeroSq <= shopping.nCourierDeliveryDistanceSq then
				if debugInfoCourierRelated then BotEcho("Courier is in inner circle") end
				if not shopping.bUpdateDatabaseAfterDelivery then
					shopping.bUpdateDatabaseAfterDelivery = true
					if debugInfoCourierRelated then BotEcho("Activate Home Skill !") end
					--home
					local courierHome = courier:GetAbility(3)
					if courierHome then
						core.OrderAbility(botBrain, courierHome, nil, true)
						return bOnMission
					end
				end
			else
				if debugInfoCourierRelated then BotEcho("Courier is out of range") end
				if shopping.bUpdateDatabaseAfterDelivery then
					if debugInfoCourierRelated then BotEcho("Delivery done") end
					shopping.bUpdateDatabaseAfterDelivery = false
					itemHandler:UpdateDatabase()
					
					--remove item entries successfully delivered (item transfer bug protection)
					local inventory = courier:GetInventory(false)
					local index = 1
					while index <= #shopping.courierSlots do
						local slot = shopping.courierSlots[index]
						local item = slot and inventory[slot]
						if item then
							index = index + 1
						else
							tremove(shopping.courierSlots, index)
						end
					end
					
					shopping.CourierState = 3
				end
			end
		else
			--Waiting for courier to be usable
			if courier:CanAccessStash() then
				if debugInfoCourierRelated then BotEcho("Courier can access stash. Ending mission") end
				
				shopping.FillStash(courier)
				shopping.CourierState = 0
				shopping.bDelivery = false
				bOnMission = false
			end
		end
	end

	return bOnMission
end

--courier repair function
local function CheckCourierBugged(botBrain, courier)
	--Courier is a multi user controlled unit, so it may bugged out
	
	--end of courier mission; don't track courier
	if not shopping.bCourierMissionControl then
		shopping.CourierLastPosition = nil
		return
	end
	
	local nNow = HoN.GetGameTime()
	local vecCourierPosition = courier:GetPosition()
	
	--no position set or courier is moving update position and time
	if not shopping.CourierLastPosition or Vector3.Distance2DSq(vecCourierPosition, shopping.CourierLastPosition) > 100 then
		shopping.CourierLastPosition = vecCourierPosition
		shopping.CourierBuggedTimer	= nNow
		return
	end
		
	--current tracking
	--check for bugs
	if shopping.CourierState == 2 then
		--want to deliver 
		if shopping.CourierBuggedTimer + shopping.nCourierDeliveryTimeOut <= nNow then
			--unit is not moving for 1.5s and we want to deliver... request a new delivery order
			--deliver
			local courierSend = courier:GetAbility(2)
			if courierSend then
				core.OrderAbility(botBrain, courierSend, nil, true)
				shopping.bDelivery = true
			end
			shopping.CourierBuggedTimer = nNow
		end
	else
		--otherwise
		if shopping.CourierBuggedTimer + shopping.nCourierPositionTimeOut <= nNow then
			--home
			local courierHome = courier:GetAbility(3)
			if courierHome then
				core.OrderAbility(botBrain, courierHome, nil, true)
			end
			shopping.CourierBuggedTimer = nNow
		end
	end	
	
end



---------------------------------------------------
-- TeamBotBrain Functions
---------------------------------------------------

--generate new Reservation table in the teambot
local function SetupReservation()
	
	local debugTeamBotBrain = true
	local teamBot = HoN.GetTeamBotBrain()
	
	teamBot.bReservation = true
	
	--restricted items:
	local tReservations = {
			--AbyssalSkull
			Item_LifeSteal5 = false,
			--Nomes Wisdom
			Item_NomesWisdom = false,
			--Sols Bulwark
			Item_SolsBulwark = false,
			--Daemonic Breastplate
			Item_DaemonicBreastplate = false,
			--Barrier Idol
			Item_BarrierIdol = false,
			--Astrolabe
			Item_Astrolabe = false,
			--Mock of Brilliance
			Item_Damage10 = false
	}
	teamBot.tReservatedItems = tReservations
	
	if debugTeamBotBrain then BotEcho("Teambotbrain reservation Initialized") end
end

--reserve an item, if possible
local function ReserveItem (itemName)
	
	local debugTeamBotBrain = true
	
	if not itemName then return false end
	
	local teamBot = HoN.GetTeamBotBrain()
	
	if not teamBot.bReservation then 
		teamBot.SetupReservation()
	end
	
	--check if reserved
	local tReservationTable = teamBot.tReservatedItems
	
	local bReserved = tReservationTable[itemName]
	
	if debugTeamBotBrain then BotEcho(itemName.." was found in reservation table: "..tostring(bReserved)) end
	
	--if item is not reserved or not tracked, you can buy it 
	if  bReserved ~= false then
		return not bReserved
	end
	
	--item is not reserved... need further checks
	local bFoundItem = false
	
	--check if an instance of the item is in the inventory of not supported heroes (without this lib or human players)
	local tAllyHeroes= HoN.GetHeroes(core.myTeam)
	for index, hero in pairs(tAllyHeroes) do
		--we can only check the inventory... :(
		local inventory = hero:GetInventory (false)
		bFoundItem = core.InventoryContains(inventory, itemName, false, false)
		if #bFoundItem > 0 then
			if debugTeamBotBrain then BotEcho(itemName.." was found in an allies inventory: ") end
			bFoundItem = true
			break
		else
			bFoundItem = false
		end
	end
	
	--Reserve item 
	tReservationTable[itemName] = true
	
	--if item was not found, we can buy it
	return not bFoundItem
end

---------------------------------------------------
-- On think: TeambotBrain  and Courier Control
---------------------------------------------------
function shopping:onThinkShopping(tGameVariables)
	
	--Pre old onThink, because we have to add the teambot functions before entering the behaviors
	if shopping.CheckItemReservation then
		local teamBot = HoN.GetTeamBotBrain()
		if not teamBot.SetupReservation then
			if debugInfoGeneralInformation then BotEcho("Setting up teambotBrain") end
			teamBot.SetupReservation = SetupReservation
			teamBot.ReserveItem = ReserveItem
		end
	end
	
	--old onThink
	self:onthinkPreShopOld(tGameVariables)
	
	--Courier Control
	local nNow = HoN.GetGameTime()
	if shopping.nextCourierControl <= nNow then
	
		shopping.nextCourierControl = nNow + shopping.CourierControlIntervall
		
		local courier = shopping.GetCourier()
	
		--no courier? no action
		if courier then
			if shopping.bCourierMissionControl then
				shopping.bCourierMissionControl = CourierMission (self, courier)
				
				--repair courier usage (multi control problems)
				CheckCourierBugged(self, courier)
			end
			
			--activate shield if needed
			local courierShield =  courier:GetAbility(1)
			local nCourierHP = courier:GetHealthPercent()
			if courierShield and courierShield:CanActivate() and nCourierHP < 1 then
				if debugInfoCourierRelated then BotEcho("Activate Shield") end
				core.OrderAbility(self, courierShield)
				return 
			end		
		end
	end
	
	
	--Update itemLists
	shopping.UpdateItemList(botBrain)
end
object.onthinkPreShopOld = object.onthink
object.onthink 	= shopping.onThinkShopping