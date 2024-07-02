--[[
	[x] This is shared since not setting a custom physicsobj on the clientside will make the client think there is no physicsobj there
	[x] Altho this does cause funky behavour with moving the entity i think its worth it
	[x] Also clearing the physclips from a entity makes it behave like there is nothing there on the client untill its duped and spawned,
	        could make it create it the same was sv does but again, funky behavour. Guess its okey like this? again gotta find a way to
	        somehow fix. Maby take a look at how prop resize addons do it.
	
	This has been somewhat fixed? Requires some more testing to be sure.
	
	Default limit is 0 for this reason (not anymore, lets hope shit dont break)
	
	[x] TODO: try to fix funky behavour (done?)
]]

ProperClipping = ProperClipping or {
	ClippedPhysics = {}
}

local cvar_physics = CreateConVar("proper_clipping_max_physics", "2", FCVAR_ARCHIVE, "Max physical clips a entity can have", 0, 8)
local dConstraints = duplicator.ConstraintType
local clippedPhysics = ProperClipping.ClippedPhysics
local class_whitelist = {
	prop_physics = true
}

----------------------------------------

if CLIENT then
	
	local function addHook()
		hook.Add("Think", "proper_clipping_physics", function()
			for ent in pairs(clippedPhysics) do
				if not IsValid(ent) then
					clippedPhysics[ent] = nil
				else
					local physobj = ent:GetPhysicsObject()
					if not IsValid(physobj) then
						clippedPhysics[ent] = nil
					else
						physobj:SetPos(ent:GetPos())
						physobj:SetAngles(ent:GetAngles())
					end
				end
			end
		end)
	end

	hook.Add("PhysgunPickup", "proper_clipping_physics", function(_, ent)
		if not clippedPhysics[ent] then return end
		addHook()
		return false
	end)

	hook.Add("PhysgunDrop", "proper_clipping_physics", function(_, ent)
		if not clippedPhysics[ent] then return end
		hook.Remove("Think", "proper_clipping_physics" )
	end)

	hook.Add("NetworkEntityCreated", "proper_clipping_physics", function(ent)
		if ent.PhysicsClipped then
			for _, clip in ipairs(ent.ClipData) do
				if clip.physics then
					ProperClipping.ClipPhysics(ent, clip.norm, clip.dist)
				end
			end
		end
	end)
end

----------------------------------------

local function abovePlane(point, plane, plane_dir)
	return plane_dir:Dot(point - plane) > 0
end

local function intersection3D(line_start, line_end, plane, plane_dir)
	local line = line_end - line_start
	local dot = plane_dir:Dot(line)
	
	if math.abs(dot) < 1e-6 then return end
	
	return line_start + line * (-plane_dir:Dot(line_start - plane) / dot)
end

local function clipPlane3D(poly, plane, plane_dir)
	local n = {}
	
	local last = poly[#poly]
	for _, cur in ipairs(poly) do
		local a = abovePlane(last, plane, plane_dir)
		local b = abovePlane(cur, plane, plane_dir)
		
		if a and b then
			table.insert(n, cur)
		elseif a or b then
			local point = intersection3D(last, cur, plane, plane_dir)
			-- Check since if the point lies on the plane it will return nil
			if point then
				table.insert(n, point)
			end
			
			if b then
				table.insert(n, cur)
			end
		end
		
		last = cur
	end
	
	return n
end

----------------------------------------

function ProperClipping.MaxPhysicsClips()
	return cvar_physics:GetInt()
end

function ProperClipping.PhysicsClipsLeft(ent)
	local physcount = 0
	if ent.ClipData then
		for _, clip in ipairs(ent.ClipData) do
			if clip.physics then
				physcount = physcount + 1
			end
		end
	end
	
	local max = cvar_physics:GetInt()
	return physcount < max, max - physcount
end

function ProperClipping.CanAddPhysicsClip(ent, ply)
	if not class_whitelist[ent:GetClass()] and not ent:IsScripted() then return false, -1 end
	if hook.Run("ProperClippingCanPhysicsClip", ent, ply) == false then return false, -1 end
	if not hook.Run("CanTool", ply, {Entity = ent}, "proper_clipping_physics") then return false, 0 end
	
	return ProperClipping.PhysicsClipsLeft(ent)
end

function ProperClipping.GetPhysObjData(ent, physobj)
	local constraints = SERVER and constraint.GetTable(ent) or nil
	if SERVER then
		constraint.RemoveAll(ent)
	end
	
	return {
		damping = {physobj:GetDamping()},
		vol = physobj:GetVolume(),
		mass = physobj:GetMass(),
		mat = physobj:GetMaterial(),
		contents = physobj:GetContents(),
		motion = physobj:IsMotionEnabled(),
		constraints = constraints
	}
end

local constraint_timers = {}
function ProperClipping.ApplyPhysObjData(physobj, physdata, keepmass)
	physobj:SetDamping(unpack(physdata.damping))
	physobj:SetMaterial(physdata.mat)
	physobj:SetContents(physdata.contents)
	
	if SERVER then
		physobj:SetMass(keepmass and physdata.mass or math.max(1, physobj:GetVolume() / physdata.vol * physdata.mass))
		physobj:EnableMotion(physdata.motion)
		if physdata.motion then
			physobj:Wake()
		end
		
		for _, data in ipairs(physdata.constraints) do
			if data.Type == "" then continue end
			local con = dConstraints[data.Type]
			local args = {}
			local id = ""
			for i, arg in ipairs(con.Args) do
				args[i] = data[arg]
				id = id .. tostring(data[arg]) .. "\0"
			end
			
			if not constraint_timers[id] then
				constraint_timers[id] = true
				
				timer.Simple(0, function()
					con.Func(unpack(args))
					constraint_timers[id] = nil
				end)
			end
		end
	else
		physobj:EnableMotion(false)
		physobj:Sleep()
	end
end

function ProperClipping.ClipPhysics(ent, norm, dist, keepmass)
	if not class_whitelist[ent:GetClass()] and not ent:IsScripted() then return end
	if hook.Run("ProperClippingCanPhysicsClip", ent) == false then return end
	
	local physobj = ent:GetPhysicsObject()
	
	if CLIENT and not IsValid(physobj) then
		ent:PhysicsInit(SOLID_VPHYSICS)
		
		physobj = ent:GetPhysicsObject()
	end
	
	if not IsValid(physobj) then return end
	
	local meshes = physobj:GetMeshConvexes()
	if not meshes then return end
	
	ent.PhysicsClipped = true
	ent.OBBCenterOrg = ent.OBBCenterOrg or ent:OBBCenter()
	
	-- Store properties to copy over to the new physobj
	local data = ProperClipping.GetPhysObjData(ent, physobj)
	
	-- Cull stuff
	if type(dist) ~= "table" then
		norm = {norm}
		dist = {dist}
	end
	
	local new = {}
	for _, convex in ipairs(meshes) do
		local vertices = {}
		for _, vertex in ipairs(convex) do
			vertices[#vertices + 1] = vertex.pos
		end
		
		new[#new + 1] = vertices
	end
	
	for i = 1, #norm do
		local norm = norm[i]
		local pos = norm * dist[i]
		
		local new2 = {}
		for _, vertices in ipairs(new) do
			vertices = clipPlane3D(vertices, pos, norm)
			if next(vertices) then
				new2[#new2 + 1] = vertices
			end
		end
		
		new = new2
	end
	
	-- Can crash without this
	-- https://github.com/Facepunch/garrysmod/blob/master/garrysmod/lua/entities/sent_ball.lua#L75
	ent.ConstraintSystem = nil
	
	-- Make new one
	if not ent:PhysicsInitMultiConvex(new) then return end
	ent:SetMoveType(MOVETYPE_VPHYSICS)
	ent:SetSolid(SOLID_VPHYSICS)
	ent:EnableCustomCollisions(true)
	
	physobj = ent:GetPhysicsObject()
	
	-- Apply stored properties to the new physobj
	ProperClipping.ApplyPhysObjData(physobj, data, keepmass)
	
	if CLIENT then
		clippedPhysics[ent] = physobj
		
		ent:CallOnRemove("proper_clipping", function()
			clippedPhysics[ent] = nil
		end)
	end
	
	hook.Run("ProperClippingPhysicsClipped", ent, norm, dist)
end

function ProperClipping.ResetPhysics(ent, keepmass)
	if not ent.PhysicsClipped then return end
	
	ent.PhysicsClipped = nil
	ent.OBBCenterOrg = nil
	
	local physobj = ent:GetPhysicsObject()
	local data = IsValid(physobj) and ProperClipping.GetPhysObjData(ent, physobj)
	
	-- Amazing hack that fixes the physics object, why does this work?
	ent:SetModel(ent:GetModel())
	
	if not ent:PhysicsInit(SOLID_VPHYSICS) then return end
	ent:SetMoveType(MOVETYPE_VPHYSICS)
	ent:EnableCustomCollisions(false)
	
	physobj = ent:GetPhysicsObject()
	
	if data then
		ProperClipping.ApplyPhysObjData(physobj, data, keepmass)
	end
	
	if CLIENT then
		clippedPhysics[ent] = physobj
	end
	
	hook.Run("ProperClippingPhysicsReset", ent)
end
