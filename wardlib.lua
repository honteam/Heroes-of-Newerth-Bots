----------------------------------------------

--  			 WardLib v0.1  			--
----------------------------------------------
--  		  Created by Sparks1992  		--
----------------------------------------------

local _G = getfenv(0)
local object = _G.object

object.wardlib = object.wardlib or {}
local wardlib, eventsLib, core, behaviorLib = object.wardlib, object.eventsLib, object.core, object.behaviorLib

local print, ipairs, pairs, string, table, next, type, tinsert, tremove, tsort, format, tostring, tonumber, strfind, strsub	= _G.print, _G.ipairs, _G.pairs, _G.string, _G.table, _G.next, _G.type, _G.table.insert, _G.table.remove, _G.table.sort, _G.string.format, _G.tostring, _G.tonumber, _G.string.find, _G.string.sub
local ceil, floor, pi, tan, atan, atan2, abs, cos, sin, acos, max, random = _G.math.ceil, _G.math.floor, _G.math.pi, _G.math.tan, _G.math.atan, _G.math.atan2, _G.math.abs, _G.math.cos, _G.math.sin, _G.math.acos, _G.math.max, _G.math.random

local BotEcho, VerboseLog, BotLog = core.BotEcho, core.VerboseLog, core.BotLog



local nHellbourne = HoN.GetHellbourneTeam() -- 2
local nLegion = HoN.GetLegionTeam() -- 1

local unitSelf = core.unitSelf

local botTeam = HoN.GetTeamBotBrain()

wardlib.tWardSpots = {
-- Legion Team
-- TO ADD THE REAL POSITION FOR WARDS AND PLACE, THESE ARE JUST FOR CODE TESTING
{pos = Vector3.Create(7200, 3600),  description = "Legion Jungle, close to middle lane", vecHeroPlacePos = Vector3.Create(6700, 4000), nSide = nLegion},
{pos = Vector3.Create(7200, 3600),  description = "Legion Jungle, in the middle", vecHeroPlacePos = Vector3.Create(6700, 4000), nSide = nLegion},
{pos = Vector3.Create(7200, 3600),  description = "Runespot Bottom", vecHeroPlacePos = Vector3.Create(6700, 4000), nSide = nLegion},
{pos = Vector3.Create(7200, 3600),  description = "Runespot Top", vecHeroPlacePos = Vector3.Create(6700, 4000), nSide = nLegion},
{pos = Vector3.Create(7200, 3600),  description = "Legion Side, statue, Top lane", vecHeroPlacePos = Vector3.Create(6700, 4000), nSide = nLegion},

-- Hellbourne Team
-- TO ADD THE REAL POSITION FOR WARDS AND PLACE, THESE ARE JUST FOR CODE TESTING
{pos = Vector3.Create(7200, 3600),  description = "Hellbourne Jungle, close to middle lane", vecHeroPlacePos = Vector3.Create(6700, 4000), nSide = nHellbourne},
{pos = Vector3.Create(7200, 3600),  description = "Hellbourne Jungle, top lane cliff", vecHeroPlacePos = Vector3.Create(6700, 4000), nSide = nHellbourne},
{pos = Vector3.Create(7200, 3600),  description = "Runespot Bottom", vecHeroPlacePos = Vector3.Create(6700, 4000), nSide = nHellbourne},
{pos = Vector3.Create(7200, 3600),  description = "Runespot Top", vecHeroPlacePos = Vector3.Create(6700, 4000), nSide = nHellbourne},
{pos = Vector3.Create(7200, 3600),  description = "Hellbourne side, bottom lane Cliff", vecHeroPlacePos = Vector3.Create(6700, 4000), nSide = nHellbourne}
}


-- Find the nearest WardSpot
-- LEFT TO DO -> CHECK IF THERE IS ALREADY A WARD AT THE CLOSEST POSITION

function wardLib.getNearestWardPos(pos, nSide)

	local nClosestSpot = -1
	local nClosestSq = 9999 * 9999
	for i = 1, #wardlib.tWardSpots do
		local tWardSpot = wardlib.tWardSpots[i]
			if nSide == nil or tWardSpots.nSide == nSide then
				local nDistanceSq = Vector3.Distance2DSq(pos, tWardSpots.pos)
				if nDistanceSq < nClosestSq then
					nClosestSq = nDistanceSq
					nClosestSpot = i
				end
			end

	end
	if (nClosestSpot ~= -1) then
		return wardlib.tWardSpots[nClosestSpot].pos, nClosestSpot
	end
	return nil
end
