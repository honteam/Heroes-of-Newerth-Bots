local _G = getfenv(0)
local object = _G.object

local core, eventsLib, behaviorLib, metadata, skills = object.core, object.eventsLib, object.behaviorLib, object.metadata, object.skills

local print, ipairs, pairs, string, table, next, type, tinsert, tremove, tsort, format, tostring, tonumber, strfind, strsub
	= _G.print, _G.ipairs, _G.pairs, _G.string, _G.table, _G.next, _G.type, _G.table.insert, _G.table.remove, _G.table.sort, _G.string.format, _G.tostring, _G.tonumber, _G.string.find, _G.string.sub
local ceil, floor, pi, tan, atan, atan2, abs, cos, sin, acos, max, random
	= _G.math.ceil, _G.math.floor, _G.math.pi, _G.math.tan, _G.math.atan, _G.math.atan2, _G.math.abs, _G.math.cos, _G.math.sin, _G.math.acos, _G.math.max, _G.math.random

local BotEcho, VerboseLog, BotLog = core.BotEcho, core.VerboseLog, core.BotLog
local Clamp = core.Clamp

object.runelib = {}
local runelib = object.runelib

local RUNE_UNIT_MASK = core.UNIT_MASK_POWERUP + core.UNIT_MASK_ALIVE

local teambot = nil

local runeNames = {"Powerup_Damage", "Powerup_Illusion", "Powerup_Stealth", "Powerup_Refresh", "Powerup_Regen", "Powerup_MoveSpeed", "Powerup_Super"}

function core.NewRuneCoreInitialize(controller)
teambot = HoN.GetTeamBotBrain()
	if teambot then
		if teambot.runes == nil then

			teambot.nextSpawnCheck = 120000 --2min mark
			teambot.nextCheck = 120000
			teambot.checkInterval = 1000

			--todo add types expect "greatter" and "lesser" rune so bot can go for better rune if it have vision
			teambot.runes = {
				{location = Vector3.Create(5824, 9728), unit=nil, picked = true, better=true},
				{location = Vector3.Create(11136, 5376), unit=nil, picked = true, better=true}
			}

			function teambot:runeLibOnthinkOverride(tGameVariables)
				self:runeLibOnthinkOld(tGameVariables)-- old think

				time = HoN.GetMatchTime()
				if time and time > teambot.nextSpawnCheck then
					teambot.nextSpawnCheck = teambot.nextSpawnCheck + 120000
					for _,rune in pairs(teambot.runes) do
						--something spawned
						rune.picked = false
						rune.unit = nil
						rune.better = true
					end
					runelib.checkRunes()
				end
				if time and time > teambot.nextCheck then
					teambot.nextCheck = teambot.nextCheck + teambot.checkInterval
					runelib.checkRunes()
				end
			end
			teambot.runeLibOnthinkOld = teambot.onthink
			teambot.onthink = teambot.runeLibOnthinkOverride
		end
	end
	core.OldRuneCoreInitialize(controller)
end --of editting teambot
core.OldRuneCoreInitialize = core.CoreInitialize
core.CoreInitialize = core.NewRuneCoreInitialize

function runelib.checkRunes()
	for _,rune in pairs(teambot.runes) do
		if HoN.CanSeePosition(rune.location) then
			units = HoN.GetUnitsInRadius(rune.location, 50, RUNE_UNIT_MASK)
			local runeFound = false
			for _,unit in pairs(units) do
				local typeName = unit:GetTypeName()
				if core.tableContains(runeNames, typeName) then
					runeFound = true
					rune.unit = unit
					if typeName == "Powerup_Refresh" then
						rune.better = false
					end
					break
				end
			end
			if not runeFound then
				rune.unit = nil
				rune.picked = true
			end
		end
	end
end

function runelib.GetNearestRune(pos, certain, prioritizeBetter)
	--we want to be sure there is rune
	certain = certain or false
	prioritizeBetter = prioritizeBetter or true

	local mypos = core.unitSelf:GetPosition()

	local nearestRune = nil
	local shortestDistanceSQ = 99999999
	for _,rune in pairs(teambot.runes) do
		if not certain or rune.unit ~= nil then
			local distance = Vector3.Distance2DSq(rune.location, mypos)
			if rune.better and prioritizeBetter then
				distance = distance - 1000*1000
			end
			if not rune.picked and distance < shortestDistanceSQ then
				nearestRune = rune
				shortestDistanceSQ = distance
			end
		end
	end
	return nearestRune
end

function runelib.pickRune(botBrain, rune)

	if rune == nil or rune.location == nil or rune.picked then
		return false
	end
	if not HoN.CanSeePosition(rune.location) or rune.unit == nil then
		return behaviorLib.MoveExecute(botBrain, rune.location)
	else
		--core.OrderTouch(botBrain, core.unitSelf, rune.unit)

		botBrain:OrderEntity(core.unitSelf.object, "Touch", rune.unit)
		return true
	end
end

function table.contains(table, element)
	for _, value in pairs(table) do
		if value == element then
			return true
		end
	end
	return false
end