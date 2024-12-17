E2Lib.RegisterExtension("proper_clipping", false, "Used to manipuilate visual clips on props and other entities", "This still abides by CanTool, so if the player cant use the tool normally they also wont be able to use the e2 functions")

----------------------------------------
-- Check funcs

local function checkvis(ent, self)
	return ProperClipping.CanAddClip(ent, self.player)
end

local function checkphys(ent, self)
	return ProperClipping.CanAddPhysicsClip(ent, self.player)
end

local function vec(v)
	return Vector(v[1], v[2], v[3])
end

----------------------------------------
-- Methods

-- add clip
local function addclip(self, ent, origin, normal, inside, phys)
	if not checkvis(ent, self) then return 0 end
	if phys and not checkphys(ent, self) then return 0 end
	
	local origin = vec(origin)
	local normal = vec(normal)
	
	return ProperClipping.AddClip(ent, normal, normal:Dot(origin), inside, phys) and 1 or 0
end

__e2setcost(200)
e2function number entity:addClip(vector origin, vector normal, number inside, number phys)
	return addclip(self, this, origin, normal, inside ~= 0, phys ~= 0)
end

__e2setcost(100)
e2function number entity:addClip(vector origin, vector normal, number inside)
	return addclip(self, this, origin, normal, inside ~= 0, false)
end

e2function number entity:addClip(vector origin, vector normal)
	return addclip(self, this, origin, normal, false, false)
end

-- remove all clips
e2function number entity:removeClips()
	local ent = this
	
	if not checkvis(ent, self) then return 0 end
	
	return ProperClipping.RemoveClips(ent) and 1 or 0
end

e2function number entity:removeClip()
	local ent = this
	
	if not checkvis(ent, self) then return 0 end
	
	return ProperClipping.RemoveClips(ent) and 1 or 0
end

-- remove clip by orgin and normal
e2function number entity:removeClip(vector origin, vector normal)
	local ent = this
	
	if not checkvis(ent, self) then return 0 end
	
	local origin = vec(origin)
	local normal = vec(normal)
	
	local exists, index = ProperClipping.ClipExists(ent, normal, normal:Dot(origin))
	if not exists then return 0 end
	
	return ProperClipping.RemoveClip(ent, index) and 1 or 0
end

-- remove clip by index
e2function number entity:removeClipByIndex(number index)
	local ent = this
	
	if not checkvis(ent, self) then return 0 end
	
	return ProperClipping.RemoveClip(ent, index) and 1 or 0
end

e2function number entity:removeClip(number index)
	local ent = this
	
	if not checkvis(ent, self) then return 0 end
	
	return ProperClipping.RemoveClip(ent, index) and 1 or 0
end

-- other shit
__e2setcost(20)
e2function number entity:getClipIndex(vector origin, vector normal)
	local origin = vec(origin)
	local normal = vec(normal)
	
	local exists, index = ProperClipping.ClipExists(this, normal, normal:Dot(origin))
	return exists and index or -1
end

e2function number entity:physicsClipsLeft()
	return ProperClipping.PhysicsClipsLeft(this)
end

e2function table entity:getClipData()
	if not this.ClipData then return E2Lib.newE2Table() end
	local res = E2Lib.newE2Table()

	for key, tbl in ipairs(this.ClipData) do
		nestedTbl = {
			s = {
				d = tbl.d,
				dist = tbl.dist,
				inside = tbl.inside and 1 or 0,
				n = tbl.n,
				new = tbl.new and 1 or 0,
				norm = tbl.norm,
				physics = tbl.physics and 1 or 0
			},
			stypes = {
				d = "s",
				dist = "n",
				inside = "n",
				n = "v",
				new = "n",
				norm = "v",
				physics = "n"
			},
			size = #tbl,
			n = {},
			ntypes = {}
		}
		
		res.n[key] = nestedTbl
		res.ntypes[key] = "t"
	end
	
	res.size = #this.ClipData
	return res
end
