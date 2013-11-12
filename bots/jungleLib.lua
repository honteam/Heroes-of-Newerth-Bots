----------------------------------------------

--  			 JungleLib v1.1  			--
----------------------------------------------
--  		  Created by Kairus101  		--
----------------------------------------------

local _G = getfenv(0)
local object = _G.object

object.jungleLib = object.jungleLib or {}
local jungleLib, eventsLib, core, behaviorLib = object.jungleLib, object.eventsLib, object.core, object.behaviorLib

local print, ipairs, pairs, string, table, next, type, tinsert, tremove, tsort, format, tostring, tonumber, strfind, strsub	= _G.print, _G.ipairs, _G.pairs, _G.string, _G.table, _G.next, _G.type, _G.table.insert, _G.table.remove, _G.table.sort, _G.string.format, _G.tostring, _G.tonumber, _G.string.find, _G.string.sub
local ceil, floor, pi, tan, atan, atan2, abs, cos, sin, acos, max, random = _G.math.ceil, _G.math.floor, _G.math.pi, _G.math.tan, _G.math.atan, _G.math.atan2, _G.math.abs, _G.math.cos, _G.math.sin, _G.math.acos, _G.math.max, _G.math.random

local BotEcho, VerboseLog, BotLog = core.BotEcho, core.VerboseLog, core.BotLog


local Hellbourne = HoN.GetHellbourneTeam() -- 2
local legion = HoN.GetLegionTeam() -- 1

jungleLib.tJungleSpots = {
--Legion
{pos = Vector3.Create(7200, 3600),  description = "L closest to well"      , nDifficulty = 100, nStacks = 0, tCreepDifficulty = {}, vecOutsidePos = Vector3.Create(6700, 4000)	, bCorpseBlocking = false, nSide = legion },
{pos = Vector3.Create(7800, 4500),  description = "L easy camp" 		   , nDifficulty = 30 , nStacks = 0, tCreepDifficulty = {}, vecOutsidePos = Vector3.Create(7800, 5200)	, bCorpseBlocking = false, nSide = legion },
{pos = Vector3.Create(9800, 4200),  description = "L mid-jungle hard camp" , nDifficulty = 100, nStacks = 0, tCreepDifficulty = {}, vecOutsidePos = Vector3.Create(9800, 3500)	, bCorpseBlocking = false, nSide = legion },
{pos = Vector3.Create(11100, 3250), description = "L pullable camp" 	   , nDifficulty = 55 , nStacks = 0, tCreepDifficulty = {}, vecOutsidePos = Vector3.Create(11100, 2700), bCorpseBlocking = false, nSide = legion },
{pos = Vector3.Create(11300, 4400), description = "L camp above pull camp" , nDifficulty = 55 , nStacks = 0, tCreepDifficulty = {}, vecOutsidePos = Vector3.Create(11300, 3800), bCorpseBlocking = false, nSide = legion },
{pos = Vector3.Create(4900, 8100),  description = "L ancients"  		   , nDifficulty = 250, nStacks = 0, tCreepDifficulty = {}, vecOutsidePos = Vector3.Create(5500, 7800)	, bCorpseBlocking = false, nSide = legion },
--Hellbourne
{pos = Vector3.Create(9400, 11200), description = "H closest to well"      , nDifficulty = 100, nStacks = 0, tCreepDifficulty = {}, vecOutsidePos = Vector3.Create(8800, 11300), bCorpseBlocking = false, nSide = Hellbourne },
{pos = Vector3.Create(7800, 11600), description = "H easy camp" 		   , nDifficulty = 30 , nStacks = 0, tCreepDifficulty = {}, vecOutsidePos = Vector3.Create(7400, 12200), bCorpseBlocking = false, nSide = Hellbourne },
{pos = Vector3.Create(6500, 10400), description = "H below easy camp"      , nDifficulty = 55 , nStacks = 0, tCreepDifficulty = {}, vecOutsidePos = Vector3.Create(6700, 11000), bCorpseBlocking = false, nSide = Hellbourne },
{pos = Vector3.Create(5100, 12450), description = "H pullable camp" 	   , nDifficulty = 55 , nStacks = 0, tCreepDifficulty = {}, vecOutsidePos = Vector3.Create(5100, 13100), bCorpseBlocking = false, nSide = Hellbourne },
{pos = Vector3.Create(4000, 11500), description = "H far hard camp" 	   , nDifficulty = 100, nStacks = 0, tCreepDifficulty = {}, vecOutsidePos = Vector3.Create(4400, 11700), bCorpseBlocking = false, nSide = Hellbourne },
{pos = Vector3.Create(12300, 5600), description = "H ancients"  		   , nDifficulty = 250, nStacks = 0, tCreepDifficulty = {}, vecOutsidePos = Vector3.Create(12300, 6400), bCorpseBlocking = false, nSide = Hellbourne }
}
jungleLib.nMinutesPassed = -1
jungleLib.nStacking = 0

local tCreepPreferences = {} -- This will hold the creep preferences for certain strings. e.g. "Alchemist's bones" or "Legionnaire"

local nCheckFrequency = 500 --check 2 times a second
jungleLib.nLastCheck = 0
function jungleLib.assess(botBrain)
	if (core.NumberElements(tCreepPreferences) == 0) then
		return
	end

	--NEUTRAL SPAWNING
	local time = HoN.GetMatchTime()
	if (time <= jungleLib.nLastCheck + nCheckFrequency) then --framskip
		return
	end
	jungleLib.nLastCheck = time
	
	local mins = -1
	if time then
		mins, secs = jungleLib.getTime()
		if (mins == 0 and secs == 30) or (mins ~= jungleLib.nMinutesPassed and mins ~= 0) then --SPAWNING
			for _, jungleSpot in pairs(jungleLib.tJungleSpots) do
				if (not jungleSpot.bCorpseBlocking) then --it won't spawn with corpse in way.
					jungleSpot.nStacks = 1 --assume something spawned. If not, it will be removed later if not.
				end
				jungleSpot.bCorpseBlocking = false
			end
			if (jungleLib.nStacking ~= 0) then --add stack if stacking.
				jungleLib.tJungleSpots[jungleLib.nStacking].nStacks = jungleLib.tJungleSpots[jungleLib.nStacking].nStacks + 1
			end
			jungleLib.nStacking = 0
		end
	end
	jungleLib.nMinutesPassed = mins

	--CHECK NEUTRAL SPAWN CAMPS
	local debug = false
	
	for i, jungleSpot in pairs(jungleLib.tJungleSpots) do
		if (debug) then
			if (jungleSpot.nStacks == 0) then
				core.DrawXPosition(jungleSpot.pos, 'green')
			else
				core.DrawXPosition(jungleSpot.pos, 'red')
			end
		end
	
		if (HoN.CanSeePosition(jungleSpot.pos))then
			--reset creep difficulties
			jungleSpot.tCreepDifficulty = {}
			local nUnitsNearCamp = 0
			local uUnits = HoN.GetUnitsInRadius(jungleSpot.pos, 800, core.UNIT_MASK_ALIVE + core.UNIT_MASK_UNIT)
			for key, unit in pairs(uUnits) do
				if unit:GetTeam() ~= core.myTeam and unit:GetTeam() ~= core.enemyTeam then
					nUnitsNearCamp = nUnitsNearCamp + 1
					if (debug) then core.DrawXPosition(unit:GetPosition(), 'red') end
					
					-- For each unit, for each preference table, add the appropriate value.
					for sString, tCreepPrefs in pairs(tCreepPreferences) do
						local nAddedDifficulty = tCreepPrefs[unit:GetTypeName()]
						if nAddedDifficulty and nAddedDifficulty ~= 0 then
							jungleSpot.tCreepDifficulty[sString] = (jungleSpot.tCreepDifficulty[sString] ~= nil and jungleSpot.tCreepDifficulty[sString] or 0) + nAddedDifficulty
						end
					end
					
				end
			end
			
			if jungleSpot.nStacks ~= 0 and nUnitsNearCamp == 0 then --we can see the camp, nothing is there.
				if (debug) then BotEcho("Camp " .. jungleSpot.description .. " is empty. Are they all dead. "..jungleLib.tJungleSpots[i].nStacks) end
				if secs > 37 then --This is a corpse check. Units killed > 37 seconds block the camp.
					jungleSpot.bCorpseBlocking = true
				end
				jungleSpot.nStacks = 0
			end
			if (nUnitsNearCamp ~= 0 and jungleSpot.nStacks == 0 ) then --this shouldn't be true. New units should be made on the minute.
				if (debug) then BotEcho("Camp "..jungleSpot.description.." isn't empty, but I thought it was... Maybe I pulled it too far O.o") end
				jungleSpot.nStacks = 1
			end
		end
	end
end

-- This key function will add a bots checking prefs to the table - this opens up many doors, including separate alch bones and jungle checks on a single bot
-- and it allows multiple bot's needs to be checked at once.
function jungleLib.AddPreference(sPreferenceName, tPrefs)
	--BotEcho("^y################################################################################## "..sPreferenceName)
	tCreepPreferences[sPreferenceName] = tPrefs
end
--[[
AddPreference("default", { -- this has been left out for submission - I figure it is a (slight) waste of system resources.
	Neutral_Catman_leader = 40,
	Neutral_Catman = 20,
	Neutral_VagabondLeader = 30,
	Neutral_Minotaur = 15,
	Neutral_Ebula = 3,
	Neutral_HunterWarrior = 3,
	Neutral_snotterlarge = 0,
	Neutral_snottling = -1,
	Neutral_SkeletonBoss = -5,
	Neutral_AntloreHealer = 2,
	Neutral_WolfCommander = 5,
})
--]]

-- Add the ability to remove preferences if they are no longer needed/not in use.
function jungleLib.RemovePreference(sPreferenceName)
	tCreepPreferences[sPreferenceName] = nil
end

function jungleLib.getNearestCampPos(pos, sPreference, minimumnDifficulty, maximumnDifficulty, nSide, bIgnoreAncients)
	sPreference = sPreference or "default"
	minimumnDifficulty = minimumnDifficulty or 0
	maximumnDifficulty = maximumnDifficulty or 999
	bIgnoreAncients = bIgnoreAncients or false
	
	local nClosestCamp = -1
	local nClosestSq = 9999 * 9999
	for i = 1, #jungleLib.tJungleSpots do
		if not (bIgnoreAncients and (i == 6 or i == 12)) then
			local jungleSpot = jungleLib.tJungleSpots[i]
			if nSide == nil or jungleSpot.nSide == nSide then
				local nDist = Vector3.Distance2DSq(pos, jungleSpot.pos)
				local nDifficulty = jungleSpot.nDifficulty
				if (jungleSpot.tCreepDifficulty[sPreference] ~= nil) then -- added creep difficulty
					nDifficulty = nDifficulty + jungleSpot.tCreepDifficulty[sPreference]
				end
				if nDist < nClosestSq and jungleSpot.nStacks ~= 0 and nDifficulty > minimumnDifficulty and nDifficulty < maximumnDifficulty then
					nClosestSq = nDist
					nClosestCamp = i
				end
			end
		end
	end
	if (nClosestCamp ~= -1 and jungleLib.tJungleSpots[nClosestCamp].nStacks > 0) then
		return jungleLib.tJungleSpots[nClosestCamp].pos, nClosestCamp
	end
	return nil
end

function jungleLib.getTime()
	local time = HoN.GetMatchTime()
	if time then
		mins = floor(time / 60000)
		secs = floor((time - 60000 * mins) / 1000)
	end
	return mins or -1, secs or -1
end