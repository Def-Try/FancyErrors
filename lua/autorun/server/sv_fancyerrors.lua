print("FancyErrors starting")

util.AddNetworkString("FancyErrors")
util.AddNetworkString("FancyErrors_misc")

local function fake_send(entity, ply)
    local message_id = math.random(0, 65535)
    net.Start("FancyErrors")
        net.WriteUInt(0, 2) -- transfer initialise
        net.WriteUInt(message_id, 16)
        if IsValid(entity) then
            net.WriteString(entity:GetModel() or tostring(entity))
        else
            net.WriteString("")
        end
        net.WriteEntity(entity)
    net.Send(ply)
    net.Start("FancyErrors")
        net.WriteUInt(2, 2) -- transfer finished
        net.WriteUInt(message_id, 16)
    net.Send(ply)
    return
end

net.Receive("FancyErrors", function(_, ply)
    local entity = net.ReadEntity()
    if not IsValid(entity) or entity == game.GetWorld() then
        return fake_send(entity, ply)
    end
    local physobj = entity:GetPhysicsObject()
    if not IsValid(physobj) then
        return fake_send(entity, ply)
    end

    local bones = {
        [0]={meshes={physobj:GetMesh()}}
    }
    if entity:GetPhysicsObjectCount() > 1 then
        for i=0,entity:GetPhysicsObjectCount()-1 do
            local bone = entity:GetPhysicsObjectNum(i)
            bones[i] = {meshes={bone:GetMesh()}}
        end
    end

    local message_id = math.random(0, 65535)

    net.Start("FancyErrors")
        net.WriteUInt(0, 2) -- transfer initialise
        net.WriteUInt(message_id, 16)
        net.WriteString(entity:GetModel())
        net.WriteEntity(entity)
    net.Send(ply)

    local current_mesh = 1
    local current_bone = 0
    local current_vert = 1
    local max_message_size = 63.5 * 1024

    local function write_vec(vec)
        net.WriteFloat(vec[1])
        net.WriteFloat(vec[2])
        net.WriteFloat(vec[3])
    end

    local coro = coroutine.create(function()
        for _=0,10000,1 do -- just for safety
            local message_size = 0
            net.Start("FancyErrors")
                net.WriteUInt(1, 2) -- transfer in progress
                net.WriteUInt(message_id, 16)

                net.WriteUInt(current_bone, 16)
                net.WriteUInt(current_mesh, 16)
                net.WriteUInt(current_vert, 16)
                message_size = message_size + 2 * 3 -- message id, current mesh and vert

                local bone = bones[current_bone]

                local mesh = bone.meshes[current_mesh]

                local verticies = util.GetModelMeshes(entity:GetModel())[current_mesh].verticies

                net.WriteUInt(#mesh, 16)

                message_size = message_size + 2 -- vert amount

                for i=current_vert,#mesh,1 do
                    if not verticies[i] then verticies[i] = {} end
                    write_vec(mesh[i].pos)
                    net.WriteFloat(verticies[i].u or math.Round(math.random()))
                    net.WriteFloat(verticies[i].v or math.Round(math.random()))
                    write_vec(verticies[i].normal or Vector(0, 0, -1))
                    write_vec(verticies[i].userdata or Vector())
                    message_size = message_size + 4 * (3*3 + 2)
                    current_vert = i
                    if message_size >= max_message_size then break end
                end
                if current_vert >= #mesh then
                    current_mesh = current_mesh + 1
                    current_vert = 1
                end
            net.Send(ply)

            if current_mesh > #bone+1 then
                current_bone = current_bone + 1
                current_mesh = 1
            end
            if current_bone > #bones then
                break
            end
            coroutine.yield()
        end
        net.Start("FancyErrors")
            net.WriteUInt(2, 2) -- transfer finished
            net.WriteUInt(message_id, 16)
        net.Send(ply)
        if entity:GetPhysicsObjectCount() > 1 then
            local tname = "fancyerrors_ragdoll_bonesync_"..entity:EntIndex().."_ply_"..ply:AccountID()
            timer.Create(tname, 1 / 5, 0, function()
                if not IsValid(entity) then return timer.Remove(tname) end
                net.Start("FancyErrors_misc", true)
                    net.WriteString("ragbones")
                    net.WriteEntity(entity)
                    net.WriteUInt(#bones, 16)
                    for b=0,#bones do
                        net.WriteUInt(entity:TranslatePhysBoneToBone(b), 16)
                        net.WriteMatrix(entity:GetBoneMatrix(entity:TranslatePhysBoneToBone(b)))
                    end
                net.Send(ply)
            end)
        end
    end)

    timer.Create("fancyerrors_message_"..message_id, 0.5, 0, function()
        if not coroutine.status(coro) == "suspended" then
            timer.Remove("fancyerrors_message_"..message_id)
            return
        end
        coroutine.resume(coro)
    end)
    --[[
    net.Start("FancyErrors", true)
        net.WriteString(entity:GetModel())
        net.WriteEntity(entity)
        net.WriteUInt(#meshes, 12)
        for _,mesh in pairs(meshes) do
            net.WriteUInt(#mesh, 12)
            for _,vec in pairs(mesh) do
                net.WriteVector(vec.pos)
            end
        end
    net.Send(ply)
    ]]
end)