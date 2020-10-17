ProperClipping = ProperClipping or {}
ProperClipping.ClippedEntities = {}

util.AddNetworkString("proper_clipping")

local cvar_visuals = CreateConVar("proper_clipping_max_visual_server", "6", FCVAR_ARCHIVE, "Max visual clips a entity can have, client can still adjust how many will be visible for them, this is just for networking and serverside", 0, 6)

----------------------------------------

function ProperClipping.CanAddClip(ent, ply)
	return hook.Run("CanTool", ply, {Entity = ent}, "proper_clipping") and true or false
end

function ProperClipping.AddClip(ent, norm, dist, inside, physics)
	if not ProperClipping.ClippedEntities[ent] then
		ProperClipping.ClippedEntities[ent] = ent
		ent:CallOnRemove("proper_clipping", function()
			ProperClipping.ClippedEntities[ent] = nil
		end)
	end
	
	ent.Clipped = true
	ent.ClipData = ent.ClipData or {}
	
	if #ent.ClipData >= cvar_visuals:GetInt() then return false end
	
	if type(dist) ~= "table" then
		norm = {norm}
		dist = {dist}
		inside = {inside}
		physics = {physics}
	end
	
	local norms, dists = {}, {}
	local physcount = 1
	for i = 1, #norm do
		local norm = norm[i]
		local dist = dist[i]
		local inside = inside[i]
		local physics = physics[i]
		
		table.insert(ent.ClipData, {
			norm = norm,
			n = norm:Angle(),
			dist = dist,
			d = norm:Dot(norm * dist - (ent.OBBCenterOrg or ent:OBBCenter())),
			inside = inside,
			physics = physics, -- this is used to network and call on client automaticly
			new = true -- whats this used for? no clue but lets add it anyways
		})
		
		hook.Run("ProperClippingClipAdded", ent, norm, dist, inside, physics)
		
		if physics then
			norms[i] = norm
			dists[i] = dist
			physcount = physcount + 1
		end
	end
	
	if physcount ~= 1 then
		ProperClipping.ClipPhysics(ent, norms, dists)
	end
	
	ProperClipping.StoreClips(ent)
	ProperClipping.NetworkClips(ent)
	
	return true
end

function ProperClipping.RemoveClips(ent)
	if not ent.ClipData then return false end
	
	ProperClipping.ClippedEntities[ent] = nil
	ent:RemoveCallOnRemove("proper_clipping")
	
	ent.Clipped = nil
	ent.ClipData = nil
	
	duplicator.ClearEntityModifier(ent, "proper_clipping")
	duplicator.ClearEntityModifier(ent, "clips")
	
	ProperClipping.ResetPhysics(ent)
	ProperClipping.NetworkClips(ent)
	
	hook.Run("ProperClippingClipsRemoved", ent)
	
	return true
end

function ProperClipping.RemoveClip(ent, index)
	if not ent.ClipData then return false end
	if not ent.ClipData[index] then return false end
	
	local clip = ent.ClipData[index]
	
	table.remove(ent.ClipData, index)
	
	if not next(ent.ClipData) then
		ProperClipping.RemoveClips(ent)
		
		hook.Run("ProperClippingClipRemoved", ent, index)
		
		return true
	end
	
	if clip.physics then
		ProperClipping.ResetPhysics(ent)
		
		for _, clip in ipairs(ent.ClipData) do
			ProperClipping.ClipPhysics(ent, clip.norm, clip.dist)
		end
	end
	
	ProperClipping.StoreClips(ent)
	ProperClipping.NetworkClips(ent)
	
	hook.Run("ProperClippingClipRemoved", ent, index)
	
	return true
end

function ProperClipping.StoreClips(ent)
	-- Clips for self
	local clips = {}
	for i, clip in ipairs(ent.ClipData) do
		clips[i] = {
			clip.norm,
			clip.dist,
			clip.inside,
			clip.physics
		}
	end
	
	duplicator.StoreEntityModifier(ent, "proper_clipping", clips)
	
	-- Clips for https://steamcommunity.com/sharedfiles/filedetails/?id=106753151
	local clips = {}
	for i, clip in ipairs(ent.ClipData) do
		clips[i] = {
			n = clip.n,
			d = clip.d,
			inside = clip.inside,
			new = true
		}
	end
	
	duplicator.StoreEntityModifier(ent, "clips", clips)
	
	-- Not gonna do the other tool since that can load in clips from the one above anyways
	-- This could lead to issue by using all 3 tools in a specific order on the same ent
	-- saving it across different servers and w/e but thats not my issue
end

function ProperClipping.NetworkClips(ent, ply)
	-- Use a timer so that when a ent is spawned it will send all of the clips at once
	timer.Create(tostring(ent) .. "_proper_clipping", 0.1, 1, function()
		net.Start("proper_clipping")
		net.WriteUInt(ent:EntIndex(), 14)
		
		if not ent.ClipData then
			net.WriteBool(false)
		else
			net.WriteBool(true)
			net.WriteUInt(#ent.ClipData, 4)
			for _, clip in ipairs(ent.ClipData) do
				net.WriteFloat(clip.norm.x)
				net.WriteFloat(clip.norm.y)
				net.WriteFloat(clip.norm.z)
				net.WriteFloat(clip.dist)
				net.WriteBool(clip.inside)
				net.WriteBool(clip.physics)
			end
		end
		
		net.Send(ply or player.GetHumans())
		
		hook.Run("ProperClippingClipsNetworked", ent, ply)
	end)
end

function ProperClipping.ClipExists(ent, norm, dist)
	if not ent.ClipData then return false end
	
	local x = math.Round(norm.x, 4)
	local y = math.Round(norm.y, 4)
	local z = math.Round(norm.z, 4)
	local d = math.Round(dist, 2)
	
	for i, clip in ipairs(ent.ClipData) do
		if math.Round(clip.norm.x, 4) ~= x then continue end
		if math.Round(clip.norm.y, 4) ~= y then continue end
		if math.Round(clip.norm.z, 4) ~= z then continue end
		if math.Round(clip.dist, 2) ~= d then continue end
		
		return true, i
	end
	
	return false
end

----------------------------------------

hook.Add("PlayerInitialSpawn", "proper_clipping", function(ply)
	local id = "proper_clipping_" .. ply:EntIndex()
	hook.Add("SetupMove", id, function(ply2, _, cmd)
		if not ply:IsValid() then
			hook.Remove("SetupMove", id)
			
			return
		end
		
		if ply ~= ply2 then return end
		if cmd:IsForced() then return end
		
		local ent_count, clip_count = 0, 0
		for ent in pairs(ProperClipping.ClippedEntities) do
			ProperClipping.NetworkClips(ent, ply)
			ent_count = ent_count + 1
			clip_count = clip_count + #ent.ClipData
		end
		
		print("Sending " .. clip_count .. " clips from " .. ent_count .. " entities to " .. ply:GetName())
		
		hook.Remove("SetupMove", id)
	end)
end)

----------------------------------------

-- Used to convert from OBBCenter translated to world > GetPos cuz obbcenter fucks up visclip with physclip
local function convert(ent, norm, dist)
	return norm, norm:Dot(norm * dist + (ent.OBBCenterOrg or ent:OBBCenter()))
end

-- Used to check if clips is different from proper_clipping and if so only use the later one
local function modified(ent)
	local a, b = ent.EntityMods.proper_clipping, ent.EntityMods.clips
	if #a ~= #b then return true end
	
	for i = 1, #a do
		local anorm, adist = a[i][1], a[i][2]
		local bnorm, bdist = convert(ent, b[i].n:Forward(), b[i].d)
		
		if not anorm:IsEqualTol(bnorm, 4) or math.Round(adist, 2) ~= math.Round(bdist, 2) then return true end
	end
	
	return false
end

-- Clips from self
duplicator.RegisterEntityModifier("proper_clipping", function(ply, ent, data)
	if not IsValid(ent) then return end
	
	-- Entity was last clipped with this tool so only handle it with that entmod
	if ent.EntityMods.clipping_all_prop_clips then return end
	if modified(ent) then return end
	
	if not hook.Run("CanTool", ply, {Entity = ent}, "proper_clipping") then
		ply:ChatPrint("Not allowed to create visual clips, " .. tostring(ent) .. " will be spawned without any.")
		
		return
	end
	
	timer.Simple(0, function()
		local physcount = 0
		local physmax = ProperClipping.MaxPhysicsClips()
		
		for _, clip in ipairs(data) do
			if clip.physics then
				if not hook.Run("CanTool", ply, {Entity = ent}, "proper_clipping_physics") then
					ply:ChatPrint("Not allowed to create physics clips, " .. tostring(ent) .. " will be spawned without any.")
					
					physcount = math.huge
				end
				
				break
			end
		end
		
		local norms, dists, insides, physicss = {}, {}, {}, {}
		for i, clip in ipairs(data) do
			local norm, dist, inside, physics = unpack(clip)
			
			if physics then
				physcount = physcount + 1
				
				if physcount > physmax then
					physics = false
				end
			end
			
			norms[i] = norm
			dists[i] = dist
			insides[i] = inside
			physicss[i] = physics
		end
		
		ProperClipping.AddClip(ent, norms, dists, insides, physicss)
		
		if physcount > physmax and physcount ~= math.huge then
			ply:ChatPrint("Max physics clips per entity reached (max " .. physmax .. "), " .. tostring(ent) .. " will only have " .. physmax .. " instead of " .. physcount .. ".")
		end
	end)
end)

-- Clips from https://steamcommunity.com/sharedfiles/filedetails/?id=106753151
duplicator.RegisterEntityModifier("clips", function(ply, ent, data)
	if not IsValid(ent) then return end
	if ent.EntityMods.clipping_all_prop_clips then return end
	if ent.EntityMods.proper_clipping and not modified(ent) then return end
	
	if not hook.Run("CanTool", ply, {Entity = ent}, "proper_clipping") then
		ply:ChatPrint("Not allowed to create visual clips, " .. tostring(ent) .. " will be spawned without any.")
		
		return
	end
	
	timer.Simple(0, function()
		for _, clip in ipairs(data) do
			local norm, dist = convert(ent, clip.n:Forward(), clip.d)
			
			if not ProperClipping.ClipExists(ent, norm, dist) then
				ProperClipping.AddClip(ent, norm, dist, clip.inside)
			end
		end
	end)
end)

-- Clips from https://steamcommunity.com/sharedfiles/filedetails/?id=238138995
duplicator.RegisterEntityModifier("clipping_all_prop_clips", function(ply, ent, data)
	if not IsValid(ent) then return end
	
	if not hook.Run("CanTool", ply, {Entity = ent}, "proper_clipping") then
		ply:ChatPrint("Not allowed to create visual clips, " .. tostring(ent) .. " will be spawned without any.")
		
		return
	end
	
	local inside = ent.EntityMods.clipping_render_inside
	inside = inside and inside[1]
	
	duplicator.ClearEntityModifier(ent, "clipping_all_prop_clips")
	duplicator.ClearEntityModifier(ent, "clipping_render_inside")
	
	timer.Simple(0, function()
		for _, clip in ipairs(data) do
			local norm, dist = convert(ent, clip[1]:Forward(), clip[2])
			
			if not ProperClipping.ClipExists(ent, norm, dist) then
				ProperClipping.AddClip(ent, norm, dist, inside)
			end
		end
	end)
end)
