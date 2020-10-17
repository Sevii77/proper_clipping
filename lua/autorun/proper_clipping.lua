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

local class_whitelist = {
	prop_physics = true
}

----------------------------------------

if CLIENT then
	
	hook.Add("Think", "proper_clipping_physics", function()
		for ent in pairs(ProperClipping.ClippedPhysics) do
			local physobj = ent:GetPhysicsObject()
			
			if not IsValid(physobj) then
				ProperClipping.ClippedPhysics[ent] = nil
			else
				physobj:SetPos(ent:GetPos())
				physobj:SetAngles(ent:GetAngles())
			end
		end
	end)
	
	hook.Add("PhysgunPickup", "proper_clipping_physics", function(_, ent)
		if ProperClipping.ClippedPhysics[ent] then return false end
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

function ProperClipping.GetPhysObjData(physobj)
	local constraints, constraint_ents = {}, {}
	
	if SERVER then
		duplicator.GetAllConstrainedEntitiesAndConstraints(physobj:GetEntity(), constraint_ents, constraints)
	end
	
	return {
		vol = physobj:GetVolume(),
		mass = physobj:GetMass(),
		mat = physobj:GetMaterial(),
		contents = physobj:GetContents(),
		motion = physobj:IsMotionEnabled(),
		
		constraints = constraints,
		constraint_ents = constraint_ents
	}
end

function ProperClipping.ApplyPhysObjData(physobj, data)
	physobj:SetMass(math.max(1, physobj:GetVolume() / data.vol * data.mass))
	physobj:SetMaterial(data.mat)
	physobj:SetContents(data.contents)
	
	if SERVER then
		physobj:EnableMotion(data.motion)
		if data.motion then
			physobj:Wake()
		end
		
		timer.Simple(0, function()
			for id, constraint in pairs(data.constraints) do
				duplicator.CreateConstraintFromTable(constraint, data.constraint_ents)
			end
		end)
	else
		physobj:EnableMotion(false)
		physobj:Sleep()
	end
end

function ProperClipping.ClipPhysics(ent, norm, dist)
	if not class_whitelist[ent:GetClass()] and not ent:IsScripted() then return end
	if hook.Run("ProperClippingCanPhysicsClip", ent, ply) == false then return end
	
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
	local data = ProperClipping.GetPhysObjData(physobj)
	
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
	
	-- Make new one
	if not ent:PhysicsInitMultiConvex(new) then return end
	ent:SetMoveType(MOVETYPE_VPHYSICS)
	ent:SetSolid(SOLID_VPHYSICS)
	ent:EnableCustomCollisions(true)
	
	physobj = ent:GetPhysicsObject()
	
	-- Apply stored properties to the new physobj
	ProperClipping.ApplyPhysObjData(physobj, data)
	
	if CLIENT then
		ProperClipping.ClippedPhysics[ent] = physobj
		
		ent:CallOnRemove("proper_clipping", function()
			ProperClipping.ClippedPhysics[ent] = nil
		end)
	end
end

function ProperClipping.ResetPhysics(ent)
	if not ent.PhysicsClipped then return end
	
	ent.PhysicsClipped = nil
	ent.OBBCenterOrg = nil
	
	local physobj = ent:GetPhysicsObject()
	local data = IsValid(physobj) and ProperClipping.GetPhysObjData(physobj)
	
	-- Amazing hack that fixes the physics object, why does this work?
	ent:SetModel(ent:GetModel())
	
	if not ent:PhysicsInit(SOLID_VPHYSICS) then return end
	ent:SetMoveType(MOVETYPE_VPHYSICS)
	ent:EnableCustomCollisions(false)
	
	physobj = ent:GetPhysicsObject()
	
	if data then
		ProperClipping.ApplyPhysObjData(physobj, data)
	end
	
	if CLIENT then
		ProperClipping.ClippedPhysics[ent] = physobj
	end
end
