--[[
	This is shared since not setting a custom physicsobj on the clientside will make the client think there is no physicsobj there
	Altho this does cause funky behavour with moving the entity i think its worth it
	Default limit is 0 for this reason
	
	TODO: try to fix funky behavour
]]

ProperClipping = ProperClipping or {}

local cvar_physics = CreateConVar("proper_clipping_max_physics", "0", FCVAR_ARCHIVE, "Max physical clips a entity can have", 0, 8)

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
			table.insert(n, intersection3D(last, cur, plane, plane_dir))
			
			if b then
				table.insert(n, cur)
			end
		end
		
		last = cur
	end
	
	return n
end

function ProperClipping.MaxPhysicsClips()
	return cvar_physics:GetInt()
end

function ProperClipping.CanAddPhysicsClip(ent, ply)
	if not hook.Run("CanTool", ply, {Entity = ent}, "proper_clipping_physics") then return false end
	
	local physcount = 0
	if ent.ClipData then
		for _, clip in ipairs(ent.ClipData) do
			if clip.physics then
				physcount = physcount + 1
			end
		end
	end
	
	return physcount < cvar_physics:GetInt()
end

function ProperClipping.ClipPhysics(ent, norm, dist)
	local physobj, mdl
	
	if SERVER then
		physobj = ent:GetPhysicsObject()
	else
		mdl = ents.CreateClientProp()
		mdl:SetModel(ent:GetModel())
		mdl:PhysicsInit(SOLID_VPHYSICS)
		mdl:Spawn()
		
		physobj = mdl:GetPhysicsObject()
		mdl:Remove()
	end
	
	if not physobj or not physobj:IsValid() then return end
	
	ent.PhysicsClipped = true
	
	-- Store properties to copy over to the new physobj
	local vol = physobj:GetVolume()
	local mass = physobj:GetMass()
	local motion = physobj:IsMotionEnabled()
	local mat = physobj:GetMaterial()
	
	-- Cull stuff
	local pos = -norm * dist
	
	local new = {}
	for _, convex in ipairs(physobj:GetMeshConvexes()) do
		local vertices = {}
		for _, vertex in ipairs(convex) do
			table.insert(vertices, vertex.pos)
		end
		
		vertices = clipPlane3D(vertices, pos, norm)
		if #vertices > 0 then
			table.insert(new, vertices)
		end
	end
	
	if mdl then
		
	end
	
	-- Make new one
	if not ent:PhysicsInitMultiConvex(new) then return end
	ent:EnableCustomCollisions(true)
	
	if CLIENT then return end
	
	-- Apply stored properties to the new physobj
	local physobj = ent:GetPhysicsObject()
	physobj:SetMass(math.max(1, physobj:GetVolume() / vol * mass))
	physobj:EnableMotion(motion)
	physobj:SetMaterial(mat)
end

function ProperClipping.ResetPhysics(ent)
	if not ent.PhysicsClipped then return end
	
	ent.PhysicsClipped = nil
	
	if SERVER then
		ent:PhysicsInit(SOLID_VPHYSICS)
	else
		ent:PhysicsDestroy()
	end
end
