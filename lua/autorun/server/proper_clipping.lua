ProperClipping = ProperClipping or {}
ProperClipping.ClippedEntities = {}

util.AddNetworkString("proper_clipping")

----------------------------------------

function ProperClipping.AddClip(ent, norm, dist, inside, physics)
	if not ProperClipping.ClippedEntities[ent] then
		ProperClipping.ClippedEntities[ent] = ent
		ent:CallOnRemove("proper_clipping", function()
			ProperClipping.ClippedEntities[ent] = nil
		end)
	end
	
	ent.Clipped = true
	ent.ClipData = ent.ClipData or {}
	
	table.insert(ent.ClipData, {
		norm = norm,
		n = norm:Angle(),
		d = dist,
		inside = inside,
		physics = physics, -- this is used to network and call on client automaticly
		new = true -- whats this used for? no clue but lets add it anyways
	})
	
	if physics then
		ProperClipping.ClipPhysics(ent, norm, dist)
	end
	
	ProperClipping.StoreClips(ent)
	ProperClipping.NetworkClips(ent)
end

function ProperClipping.RemoveClips(ent)
	if not ent.ClipData then return end
	
	ProperClipping.ClippedEntities[ent] = nil
	ent:RemoveCallOnRemove("proper_clipping")
	
	ent.Clipped = nil
	ent.ClipData = nil
	
	duplicator.ClearEntityModifier(ent, "proper_clipping")
	
	ProperClipping.ResetPhysics(ent)
	ProperClipping.NetworkClips(ent)
end

function ProperClipping.RemoveClip(ent, index)
	if not ent.ClipData then return end
	if not ent.ClipData[index] then return end
	
	local clip = ent.ClipData[index]
	
	table.remove(ent.ClipData, index)
	
	if #ent.ClipData == 0 then
		ProperClipping.RemoveVisualClips(ent)
		
		return
	end
	
	if clip.physics then
		ProperClipping.ResetPhysics(ent)
		
		for _, clip in ipairs(ent.ClipData) do
			ProperClipping.ClipPhysics(ent, clip.norm, clip.dist)
		end
	end
	
	ProperClipping.StoreClips(ent)
	ProperClipping.NetworkClips(ent)
end

function ProperClipping.StoreClips(ent)
	local clips = {}
	for i, clip in ipairs(ent.ClipData) do
		clips[i] = {
			clip.norm,
			clip.d,
			clip.inside,
			clip.physics
		}
	end
	
	duplicator.StoreEntityModifier(ent, "proper_clipping", clips)
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
			for i, clip in ipairs(ent.ClipData) do
				net.WriteFloat(clip.norm.x)
				net.WriteFloat(clip.norm.y)
				net.WriteFloat(clip.norm.z)
				net.WriteFloat(clip.d)
				net.WriteBool(clip.inside)
				net.WriteBool(clip.physics)
			end
		end
		
		net.Send(ply or player.GetHumans())
	end)
end

----------------------------------------

hook.Add("PlayerInitialSpawn", "proper_clipping", function(ply)
	local id = "proper_clipping_" .. ply:EntIndex()
	hook.Add("CreateMove", id, function(ply2, _, cmd)
		if not ply:IsValid() then
			hook.Remove("CreateMove", id)
			
			return
		end
		
		if ply ~= ply2 then return end
		if cmd:IsForced() then return end
		
		local ent_count, clip_count = 0, 0
		for ent, _ in pairs(ProperClipping.ClippedEntities) do
			ProperClipping.NetworkClips(ent, ply)
			ent_count = ent_count + 1
			clip_count = clip_count + #ent.ClipData
		end
		
		print("Sending " .. clip_count .. " clips from " .. ent_count .. " entities to " .. ply:GetName())
		
		hook.Remove("CreateMove", id)
	end)
end)


----------------------------------------

duplicator.RegisterEntityModifier("proper_clipping", function(ply, ent, data)
	if not ent or not ent:IsValid() then return end
	
	if not hook.Run("CanTool", ply, {Entity = ent}, "proper_clipping") then
		ply:ChatPrint("Not allowed to create visual clips, " .. tostring(ent) .. " will be spawned without any.")
		
		return
	end
	
	local physcount = 0
	local physmax = ProperClipping.MaxPhysicsClips()
	
	if not hook.Run("CanTool", ply, {Entity = ent}, "proper_clipping_physics") then
		ply:ChatPrint("Not allowed to create physics clips, " .. tostring(ent) .. " will be spawned without any.")
		
		physcount = math.huge
	end
	
	for _, clip in ipairs(data) do
		local norm, dist, inside, physics = unpack(clip)
		
		if physics then
			if physcount >= physmax then
				physics = false
			end
			
			physcount = physcount + 1
		end
		
		ProperClipping.AddClip(ent, norm, dist, inside, physics)
	end
	
	if physcount > physmax and physcount ~= math.huge then
		ply:ChatPrint("Max physics clips per entity reached (max " .. physmax .. "), " .. tostring(ent) .. " will only have " .. physmax .. " instead of " .. physcount .. ".")
	end
end)

-- Function to convert from OBBCenter translated to world > GetPos cuz obbcenter fucks up visclip with physclip
local function convert(ent, norm, dist)
	return norm, norm:Dot(norm * dist + ent:OBBCenter())
end

-- clips from https://steamcommunity.com/sharedfiles/filedetails/?id=106753151
duplicator.RegisterEntityModifier("clips", function(ply, ent, data)
	if not ent or not ent:IsValid() then return end
	
	if not hook.Run("CanTool", ply, {Entity = ent}, "proper_clipping") then
		ply:ChatPrint("Not allowed to create visual clips, " .. tostring(ent) .. " will be spawned without any.")
		
		return
	end
	
	timer.Simple(0.5, function()
		duplicator.ClearEntityModifier(ent, "clips")
		
		for _, clip in ipairs(data) do
			local norm, dist = convert(ent, clip.n:Forward(), clip.d)
			
			ProperClipping.AddClip(ent, norm, dist, clip.inside)
		end
	end)
end)

-- clips from https://steamcommunity.com/sharedfiles/filedetails/?id=238138995
local insides = {}

duplicator.RegisterEntityModifier("clipping_all_prop_clips", function(ply, ent, data)
	if not ent or not ent:IsValid() then return end
	
	if not hook.Run("CanTool", ply, {Entity = ent}, "proper_clipping") then
		ply:ChatPrint("Not allowed to create visual clips, " .. tostring(ent) .. " will be spawned without any.")
		
		return
	end
	
	timer.Simple(0.5, function()
		duplicator.ClearEntityModifier(ent, "clipping_all_prop_clips")
		
		for _, clip in ipairs(data) do
			local norm, dist = convert(ent, clip[1]:Forward(), clip[2])
			
			ProperClipping.AddClip(ent, norm, dist, insides[ent])
		end
		
		insides[ent] = nil
	end)
end)

duplicator.RegisterEntityModifier("clipping_render_inside", function(ply, ent, data)
	if not ent or not ent:IsValid() then return end
	
	local inside = data[1]
	insides[ent] = inside
	
	if ent.ClipData then
		local changed = false
		for _, clip in ipairs(ent.ClipData) do
			if clip.inside ~= inside then
				clip.inside = inside
				changed = true
			end
		end
		
		if changed then
			ProperClipping.NetworkClips(ent)
		end
	end
	
	timer.Simple(1, function()
		duplicator.ClearEntityModifier(ent, "clipping_render_inside")
		
		insides[ent] = nil
	end)
end)
