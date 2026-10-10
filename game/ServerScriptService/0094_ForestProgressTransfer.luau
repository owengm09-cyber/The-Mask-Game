-- Server-only level snapshots. VIP remains verified by MarketplaceService.
local Transfer = {}
local LOBBY_PLACE_ID = 73347091467818
local FOREST_PLACE_ID = 111145439436066
local function integer(value)
	return type(value) == "number" and value == value and value >= 0 and value < math.huge and value == math.floor(value)
end
function Transfer.Read(player)
	local ok, join = pcall(function() return player:GetJoinData() end)
	if not ok or type(join) ~= "table" then return nil end
	local expected = game.PlaceId == FOREST_PLACE_ID and LOBBY_PLACE_ID or FOREST_PLACE_ID
	if join.SourcePlaceId ~= expected then return nil end
	local data = join.TeleportData
	local envelope = type(data) == "table" and data.MaskProgression
	if type(envelope) ~= "table" or envelope.Version ~= 1 or type(envelope.Players) ~= "table" then return nil end
	local record = envelope.Players[tostring(player.UserId)]
	if type(record) ~= "table" or not integer(record.XP) then return nil end
	return record.XP
end
function Transfer.Merge(old, incomingXP)
	local data = table.clone(old or {})
	data.XP = math.max(data.XP or 0, incomingXP)
	data.Wins = data.Wins or 0
	data.Receipts = table.clone(data.Receipts or {})
	return data
end
function Transfer.Build(players, existingData)
	local data = table.clone(existingData or {})
	local records = {}
	for _, player in players do
		local xp = player:GetAttribute("TotalXP")
		if player:GetAttribute("ProgressionLoaded") and not player:GetAttribute("XPSavePending") and integer(xp) then
			records[tostring(player.UserId)] = {XP = xp}
		end
	end
	data.MaskProgression = {Version = 1, Players = records}
	return data
end
return Transfer

