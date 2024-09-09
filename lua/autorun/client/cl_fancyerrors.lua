print("FancyErrors starting")

-- CreateConVar("fancyerrors_use_vismesh", "0", FCVAR_USERINFO + FCVAR_ARCHIVE)
-- TODO: figure how to use vismesh

_G.fancyerrors_meshes = _G.fancyerrors_meshes or {}
_G.fancyerrors_models = {}

local throwawayrt_texture = GetRenderTarget("fancyerrors_throwawayrt", 512, 512)

concommand.Add("fancyerrors_force_unknown", function()
	local entity = LocalPlayer():GetEyeTrace().Entity
	if not IsValid(entity) or entity == game.GetWorld() then return end
	net.Start("FancyErrors")
		net.WriteEntity(entity)
	net.SendToServer()
end)

local validated = {}
local queue = {}
local downloading = {}
local messages = {}
local mesh_mat = Material("fancy_errors/tex.vmt")

local function fix_model(entity, model)
	local bones = _G.fancyerrors_models[model]
	entity.fancyerrors_meshes = {}
	for bonen,bone in pairs(bones) do
		local meshes = bone.meshes
		for _,mesh_ in pairs(meshes) do
			local obj = Mesh(mesh_mat)
			local bone_ = 0
			if bonen ~= 0 then
				bone_ = entity:TranslatePhysBoneToBone(bonen)
			end
			
			mesh.Begin(obj, MATERIAL_TRIANGLES, math.floor(#mesh_ / 3))
			for v=1, #mesh_, 3 do
				local v1, v2, v3 = mesh_[v].pos, mesh_[v+1].pos, mesh_[v+2].pos
				local n = (v1-v3):Cross(v1-v2)
				for _,vt in pairs({v1, v2, v3}) do
					mesh.Position(vt)
					mesh.Normal(n)
					mesh.AdvanceVertex()
				end
			end 
			mesh.End()

			_G.fancyerrors_meshes[#_G.fancyerrors_meshes+1] = obj
			entity.fancyerrors_meshes[#entity.fancyerrors_meshes+1] = {obj, bone_, bonen}
		end
	end

	local function render_()
		for _,mesh in pairs(entity.fancyerrors_meshes) do
			if not IsValid(mesh[1]) then continue end
			local mat = nil
			if mesh[2] == 0 then
				if entity.bonematrixes then
					mat = entity.bonematrixes[mesh[3]]
				else
					mat = entity:GetWorldTransformMatrix()
				end
			else
				if entity.bonematrixes then
					mat = entity.bonematrixes[mesh[3]]
				else
					mat = entity:GetBoneMatrix(mesh[2])
				end
			end
			local rmat = Matrix(mat)
			local wmat = entity:GetWorldTransformMatrix()
			local rwmat = entity:GetWorldTransformMatrix()
			if entity.bonematrixes then
				wmat = entity.bonematrixes[1]
				if mat == entity.bonematrixes[0] then
					wmat = entity.bonematrixes[0]
				end
				if mat == entity:GetWorldTransformMatrix() then
					wmat = entity:GetWorldTransformMatrix()
				end
			end
			rmat:SetTranslation(wmat:GetTranslation() + (rmat:GetTranslation() - wmat:GetTranslation()))
			cam.PushModelMatrix(rmat)
			mesh[1]:Draw()
			cam.PopModelMatrix()
		end
	end

	entity.fancyerrors_csentity = ClientsideModel("models/hunter/plates/plate.mdl")

	entity:SetRenderMode(RENDERMODE_TRANSCOLOR)
	function entity:RenderOverride()
		if not entity.fancyerrors_meshes then return end
		--render.ResetModelLighting(1, 1, 1)
		--render.ModelMaterialOverride(Material("fancy_errors/invis.vmt"))
		render.PushRenderTarget(throwawayrt_texture)
		render.Model({model="models/hunter/plates/plate.mdl", pos=entity:GetPos(), angle=entity:GetAngles()}, entity.fancyerrors_csentity)
		render.PopRenderTarget()
		--render.ModelMaterialOverride(nil)
		render.SetMaterial(mesh_mat)
		render_()
		render.RenderFlashlights(function() render_() end)
	end
end
local function do_download(ent)
	if downloading[ent:GetModel() or tostring(ent)] then return end
	validated[ent] = true

	if _G.fancyerrors_models[ent:GetModel() or tostring(ent)] then
		fix_model(ent, ent:GetModel() or tostring(ent))
		return
	end

	downloading[ent:GetModel() or tostring(ent)] = true
	queue[#queue + 1] = ent:GetModel() or tostring(ent)
	net.Start("FancyErrors")
		net.WriteEntity(ent)
	net.SendToServer()

	if #queue > 5 then
		return true
	end
	return false
end
local function fixer() timer.Create("fancyerrors_checker", 1, 0, function()
	local queue_ = table.Copy(queue)
	for k,v in pairs(queue_) do
		if _G.fancyerrors_models[v] then
			queue[k] = nil
			downloading[v] = nil
		end
	end
	if #queue > 5 then return end
	for _,ent in ents.Iterator() do
		if ({
			["class C_BaseFlex"]=true,
			["viewmodel"]=true,
			["worldspawn"]=true
		})[ent:GetClass()] then continue end
		if not ent:GetModel() then
			continue
		end
		if ent:GetModel():StartsWith("*") then
			continue
		end
		if validated[ent] or file.Exists(ent:GetModel(), "GAME") then
			continue
		end
		
		if do_download(ent) then break end
	end
end) end
if not IsValid(LocalPlayer()) then
	hook.Add("InitPostEntity", "fancyerrors_start", function()
		fixer()
	end)
else
	fixer()
end

net.Receive("FancyErrors_misc", function()
	local type = net.ReadString()
	if type == "ragbones" then
		local ent = net.ReadEntity()
		ent.bonematrixes = ent.bonematrixes or {}
		for b=0,net.ReadUInt(16) do
			net.ReadUInt(16)
			local m = net.ReadMatrix()
			ent.bonematrixes[b] = m
		end
		--ent.bonematrixes[0] = Matrix(ent:GetWorldTransformMatrix())
	end
end)

net.Receive("FancyErrors", function()
	local type = net.ReadUInt(2)
	local message_id = net.ReadUInt(16)

	if not messages[message_id] and type ~= 0 then return end

	if type == 0 then
		messages[message_id] = {
			model=net.ReadString(),
			ent=net.ReadEntity(),
			bones={}
		}
		print("Got model "..messages[message_id].model.." for entity "..tostring(messages[message_id].ent))
		notification.AddProgress("fancyerrors_"..message_id, "["..message_id.."] Downloading model "..
			messages[message_id].model.."... 0 bones 0 meshes (0 vertices)")
	end
	if type == 2 then
		local msg = messages[message_id]
		messages[message_id] = nil
		_G.fancyerrors_models[msg.model] = msg.bones
		fix_model(msg.ent, msg.model)
		notification.Kill("fancyerrors_"..message_id)
	end
	if type == 1 then
		local current_bone = net.ReadUInt(16)
		local current_mesh = net.ReadUInt(16)
		local current_vert = net.ReadUInt(16)
		local vertex_count = net.ReadUInt(16)
		local msg = messages[message_id]
		local bone = msg.bones[current_bone]
		if not bone then
			bone = {meshes={}}
			msg.bones[current_bone] = bone
		end
		local mesh = bone.meshes[current_mesh]
		if not mesh then
			mesh = {}
			bone.meshes[current_mesh] = mesh
		end
		for i=current_vert,vertex_count,1 do
			mesh[i] = {
				pos=Vector(net.ReadFloat(), net.ReadFloat(), net.ReadFloat()),
				u=net.ReadFloat(), v=net.ReadFloat(),
				normal=Vector(net.ReadFloat(), net.ReadFloat(), net.ReadFloat()),
				userdata=Vector(net.ReadFloat(), net.ReadFloat(), net.ReadFloat()),
			}
			if net.BytesLeft() <= 0 then
				break
			end
		end
		local msh, vrt, bns = 0, 0, 0
		for _,v in pairs(msg.bones) do
			bns = bns + 1
			msh = msh + #v.meshes
			for __,vv in pairs(v.meshes) do
				vrt = vrt + #vv
			end
		end
		notification.AddProgress("fancyerrors_"..message_id, "["..message_id.."] Downloading model "..
			messages[message_id].model.."... "..bns.." bones "..msh.." meshes ("..vrt.." vertices)")
	end
end)

hook.Add("ShutDown", "fancyerrors_freemeshes", function()
	for _,mesh in pairs(_G.fancyerrors_meshes) do
		mesh:Destroy()
	end
end)