TOOL.Category = "Construction"
TOOL.Name = "#Tool.proper_clipping.name"

TOOL.ClientConVar.mode    = "0" -- int
TOOL.ClientConVar.offset  = "0" -- float
TOOL.ClientConVar.physics = "0" -- bool

if CLIENT then
	language.Add("Tool.proper_clipping.name", "Proper Clipping")
	language.Add("Tool.proper_clipping.desc", "Visually or Physically clip entities")
	
	language.Add("Tool.proper_clipping.mode.0", "Hitplane")
	language.Add("Tool.proper_clipping.mode.1", "Point to Point")
	
	language.Add("Tool.proper_clipping.info1", "Hold ALT to invert the plane normal")
	language.Add("Tool.proper_clipping.info2", "Hold SHIFT to enable inside rendering")
	language.Add("Tool.proper_clipping.right", "Clip entity")
	language.Add("Tool.proper_clipping.reload", "Remove all clips")
	
	language.Add("Tool.proper_clipping.left_op0", "Define plane")
	
	language.Add("Tool.proper_clipping.left_op1_stage0", "Define start point")
	language.Add("Tool.proper_clipping.left_op1_stage1", "Define end point")
	
	TOOL.Information = {
		{stage = 0, name = "info1"},
		{stage = 0, name = "info2"},
		{stage = 0, name = "reload"},
		
		{op = 0, name = "left_op0"},
		
		{op = 1, stage = 0, name = "left_op1_stage0"},
		{op = 1, stage = 1, name = "left_op1_stage1"},
		
		{stage = 0, name = "right"}
	}
	
	function TOOL.BuildCPanel(panel)
		local cvar_visual = GetConVar("proper_clipping_max_visual")
		panel:AddControl("Slider", {
			label = "Max Visual Clips",
			command = "proper_clipping_max_visual",
			min = cvar_visual:GetMin(),
			max = cvar_visual:GetMax()
		})
		
		panel:AddControl("ListBox", {
			Label = "Mode",
			Options = {
				["#Tool.proper_clipping.mode.0"] = {proper_clipping_mode = 0},
				["#Tool.proper_clipping.mode.1"] = {proper_clipping_mode = 1}
			}
		})
		
		panel:AddControl("Slider", {
			label = "Offset",
			type = "float",
			command = "proper_clipping_offset",
			min = -50,
			max =  50
		})
		
		panel:AddControl("Checkbox", {
			label = "Physics",
			command = "proper_clipping_physics"
		})
	end
	
end

----------------------------------------

function TOOL:Think()
	local new = math.floor(self:GetClientNumber("mode"))
	
	if new == self:GetOperation() then return end
	
	self:SetOperation(new)
	self:SetStage(0)
end

function TOOL:LeftClick(tr)
	local ent = tr.Entity
	
	local op = self:GetOperation()
	local stage = self:GetStage()
	
	if not (op == 1 and stage == 1 and ent:IsWorld()) then
		if not ent or not ent:IsValid() then return end
		if ent:IsPlayer() or ent:IsWorld() then return end
	end
	
	if op == 0 then
		self.norm = tr.HitNormal
		self.origin = tr.HitPos
	elseif op == 1 then
		if stage == 0 then
			self.origin = tr.HitPos
			self:SetStage(1)
		else
			self.norm = (tr.HitPos - self.origin):GetNormalized()
			self:SetStage(0)
		end
	end
	
	return true
end

function TOOL:RightClick(tr)
	if not self.norm then return end
	if self:GetStage() == 1 then return end
	local ent = tr.Entity
	if not ent or not ent:IsValid() then return end
	if ent:IsPlayer() or ent:IsWorld() then return end
	if CLIENT then return true end
	
	local owner = self:GetOwner()
	local norm = self.norm * (owner:KeyDown(IN_WALK) and -1 or 1)
	local dist = norm:Dot(ent:GetPos() - (self.origin + self.norm * self:GetClientNumber("offset")))
	local norm = ent:WorldToLocalAngles(norm:Angle()):Forward() * -1
	
	local physics = self:GetClientNumber("physics") ~= 0
	
	if physics and not ProperClipping.CanAddPhysicsClip(ent, owner) then
		owner:ChatPrint("Max physics clips per entity reached (max " .. ProperClipping.MaxPhysicsClips() .. ")")
		physics = false
	end
	
	ProperClipping.AddClip(ent, norm, dist, owner:KeyDown(IN_SPEED), physics)
	
	undo.Create("Proper Clip")
	undo.AddFunction(function(_, ent, norm, dist)
		if not ent or not ent:IsValid() then return end
		
		local exists, index = ProperClipping.ClipExists(ent, norm, dist)
		if exists then
			ProperClipping.RemoveClip(ent, index)
		end
	end, ent, norm, dist)
	undo.SetPlayer(owner)
	undo.Finish()
	
	return true
end

function TOOL:Reload(tr)
	if self:GetStage() == 1 then return end
	local ent = tr.Entity
	if not ent or not ent:IsValid() then return end
	if ent:IsPlayer() or ent:IsWorld() then return end
	if CLIENT then return true end
	
	ProperClipping.RemoveClips(ent)
	
	return true
end

----------------------------------------

if CLIENT then
	
	local color_red = Color(255, 80, 100)
	local color_green = Color(30, 255, 120, 190)
	local color_green2 = Color(25, 200, 90, 100)
	
	local model1 = ClientsideModel("models/error.mdl")
	local model2 = ClientsideModel("models/error.mdl")
	model1:SetMaterial("models/debug/debugwhite")
	model2:SetMaterial("models/debug/debugwhite")
	model1:SetNoDraw(true)
	model2:SetNoDraw(true)
	
	local last_ent
	
	hook.Add("PostDrawOpaqueRenderables", "proper_clipping", function(depth, skybox)
		if skybox then return end
		
		if last_ent and last_ent:IsValid() then
			last_ent:SetNoDraw(false)
			last_ent:CreateShadow()
			
			last_ent = nil
		end
		
		if GetConVarString("gmod_toolmode") ~= "proper_clipping" then return end
		local ply = LocalPlayer()
		local wep = ply:GetActiveWeapon()
		if not wep or not wep:IsValid() or wep:GetClass() ~= "gmod_tool" then return end
		local tool = ply:GetTool("proper_clipping")
		if not tool then return end
		
		local origin = tool.origin
		local norm = tool.norm
		if not norm then return end
		
		local tr = ply:GetEyeTrace()
		local ent = tr.Entity
		
		local op = tool:GetOperation()
		local stage = tool:GetStage()
		
		if not (op == 1 and stage == 1 and ent:IsWorld()) then
			if not ent or not ent:IsValid() then return end
			if ent:IsPlayer() or ent:IsWorld() then return end
		end
		
		--------------------
		
		if op == 1 and stage == 1 then
			-- Line mode
			local norm = (tr.HitPos - origin):GetNormalized()
			
			render.SetColorMaterial()
			render.DrawQuadEasy(origin, norm, 16, 16, color_green)
			render.DrawQuadEasy(origin, -norm, 16, 16, color_green2)
			render.DrawLine(origin, origin + norm * 16, color_red)
		else
			-- Preview
			if ent and ent:IsValid() and not ent:IsPlayer() then
				if ent ~= last_ent then
					local mdl = ent:GetModel()
					model1:SetModel(mdl)
					model2:SetModel(mdl)
					
					local pos = ent:GetPos()
					model1:SetPos(pos)
					model2:SetPos(pos)
					
					local ang = ent:GetAngles()
					model1:SetAngles(ang)
					model2:SetAngles(ang)
					
					for _, group in ipairs(ent:GetBodyGroups()) do
						local id = group.id
						local val = ent:GetBodygroup(id)
						model1:SetBodygroup(id, val)
						model2:SetBodygroup(id, val)
					end
				end
				
				ent:SetNoDraw(true)
				
				local i = ply:KeyDown(IN_WALK)
				local offset = tool:GetClientNumber("offset") * (i and -1 or 1)
				
				local prev = render.EnableClipping(true)
				
				render.PushCustomClipPlane(norm * (i and 1 or -1), norm:Dot(origin) * (i and 1 or -1) - offset)
				render.SetColorModulation(0.3, 2, 0.5)
				model1:DrawModel()
				render.PopCustomClipPlane()
				
				render.PushCustomClipPlane(norm * (i and -1 or 1), norm:Dot(origin) * (i and -1 or 1) + offset)
				render.SetColorModulation(2, 0.2, 0.3)
				model2:DrawModel()
				render.PopCustomClipPlane()
				
				render.EnableClipping(prev)
				
				last_ent = ent
			end
		end
	end)
	
end
