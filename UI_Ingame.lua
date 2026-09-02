-- ============================================================
--               RYZEN ULTIMATE MOD v4.5 (Anti-Ban)
-- ============================================================
-- Автосоздание конфига ryzen.cfg, если его нет
-- ============================================================

local OFFSETS = {
    uworld = 0x7381A2C0,
    entlist = 0x7381AA48,
    mesh = 0x310,
    bone = 0x4C0,
    cam = 0x1B0,
    health = 0x12C8,
    team = 0x12CC
}

local CONFIG_PATH = "/sdcard/Android/data/com.tencent.ig/files/UE4Game/ShadowTrackerExtra/ShadowTrackerExtra/Saved/Paks/puffer_temp/ryzen.cfg"

local function createDefaultConfig()
    local default = [[esp = true
aim = true
aim_key = 2
box_color = 00FF00
line_color = FF0000
dist_color = FFFFFF
max_dist = 200
smooth = 5
fov = 30
bone = 13
]]
    local f = io.open(CONFIG_PATH, "w")
    if f then
        f:write(default)
        f:close()
        return true
    end
    return false
end

local function loadConfig()
    local cfg = { esp=true, aim=true, aim_key=2, box_color="00FF00", line_color="FF0000", dist_color="FFFFFF", max_dist=200, smooth=5, fov=30, bone=13 }
    local f = io.open(CONFIG_PATH, "r")
    if not f then
        if createDefaultConfig() then
            f = io.open(CONFIG_PATH, "r")
        else
            return cfg
        end
    end
    if f then
        for line in f:lines() do
            local key, val = line:match("^%s*(%w+)%s*=%s*(%S+)")
            if key and val then
                if val == "true" then val = true
                elseif val == "false" then val = false
                else val = tonumber(val) or val end
                cfg[key] = val
            end
        end
        f:close()
    end
    return cfg
end

local cfg = loadConfig()

-- ===== БЕЗОПАСНОЕ ЧТЕНИЕ ПАМЯТИ =====
local function readInt(addr)
    local success, val = pcall(UE4.UKismetSystemLibrary.ReadInt, addr)
    return success and val or 0
end

local function readFloat(addr)
    local success, val = pcall(UE4.UKismetSystemLibrary.ReadFloat, addr)
    return success and val or 0.0
end

local function readVec3(addr)
    return {x=readFloat(addr), y=readFloat(addr+4), z=readFloat(addr+8)}
end

local function getBonePos(mesh, boneIndex)
    local boneArray = readInt(mesh + OFFSETS.bone)
    if boneArray == 0 then return nil end
    return readVec3(boneArray + boneIndex * 0x30 + 0x10)
end

local function worldToScreen(worldPos)
    local matrixAddr = readInt(OFFSETS.uworld) + OFFSETS.cam
    local m = {}
    for i = 0, 15 do m[i] = readFloat(matrixAddr + i*4) end
    local w = m[3]*worldPos.x + m[7]*worldPos.y + m[11]*worldPos.z + m[15]
    if w < 0.001 then return nil end
    local x = (m[0]*worldPos.x + m[4]*worldPos.y + m[8]*worldPos.z + m[12]) / w
    local y = (m[1]*worldPos.x + m[5]*worldPos.y + m[9]*worldPos.z + m[13]) / w
    local sw = UE4.UKismetSystemLibrary.GetScreenSize().X
    local sh = UE4.UKismetSystemLibrary.GetScreenSize().Y
    return { x = (x*0.5+0.5)*sw, y = (1 - (y*0.5+0.5))*sh, z = w }
end

local function isVisible(startPos, endPos)
    local hit = UE4.UKismetSystemLibrary.LineTraceSingle(
        UE4.UKismetSystemLibrary.GetGameWorld(),
        startPos, endPos, 0, false, {}
    )
    return not hit.bBlockingHit
end

local lastUpdate = 0
local lastConfigRead = 0

local function RyzenTick(deltaTime)
    local now = UE4.UKismetSystemLibrary.GetGameTimeInSeconds()
    if now - lastUpdate < (0.15 + math.random()*0.15) then return end
    lastUpdate = now

    if now - lastConfigRead > 5 then
        cfg = loadConfig()
        lastConfigRead = now
    end

    if not cfg.esp and not cfg.aim then return end

    local world = UE4.UKismetSystemLibrary.GetGameWorld()
    if not world then return end
    local pc = UE4.UGameplayStatics.GetPlayerController(world, 0)
    if not pc then return end
    local myPawn = pc.Pawn
    if not myPawn then return end
    local myPos = myPawn:GetActorLocation()
    local myTeam = myPawn.TeamID or 0

    local actors = UE4.UGameplayStatics.GetAllActorsOfClass(world, UE4.ASTExtraPlayerCharacter)
    for _, pawn in ipairs(actors) do
        if pawn and pawn ~= myPawn then
            local health = pawn.Health
            if health and health > 0 and health <= 100 then
                local team = pawn.TeamID or 0
                if team ~= myTeam then
                    local mesh = pawn.Mesh
                    if mesh then
                        local headPos = getBonePos(mesh, 13)
                        local rootPos = getBonePos(mesh, 0)
                        if headPos and rootPos then
                            local dist = math.sqrt((headPos.x-myPos.x)^2 + (headPos.y-myPos.y)^2 + (headPos.z-myPos.z)^2) / 100
                            if dist < (cfg.max_dist or 200) then
                                if isVisible(myPos, headPos) then
                                    local headScreen = worldToScreen(headPos)
                                    local rootScreen = worldToScreen(rootPos)
                                    if headScreen and rootScreen and headScreen.z > 0.1 then
                                        if cfg.esp then
                                            local height = rootScreen.y - headScreen.y
                                            local width = height * 0.45
                                            UE4.UKismetSystemLibrary.DrawBox(
                                                headScreen.x - width/2, headScreen.y,
                                                width, height, cfg.box_color or "00FF00"
                                            )
                                            UE4.UKismetSystemLibrary.DrawLine(
                                                headScreen.x, headScreen.y, rootScreen.x, rootScreen.y,
                                                cfg.line_color or "FF0000"
                                            )
                                            UE4.UKismetSystemLibrary.DrawText(
                                                headScreen.x, headScreen.y - 20,
                                                string.format("%.1fm", dist),
                                                cfg.dist_color or "FFFFFF"
                                            )
                                        end
                                        if cfg.aim then
                                            if UE4.UKismetSystemLibrary.IsKeyDown(cfg.aim_key or 2) then
                                                local centerX = UE4.UKismetSystemLibrary.GetScreenSize().X / 2
                                                local centerY = UE4.UKismetSystemLibrary.GetScreenSize().Y / 2
                                                local dx = headScreen.x - centerX
                                                local dy = headScreen.y - centerY
                                                if math.abs(dx) < (cfg.fov or 30) and math.abs(dy) < (cfg.fov or 30) then
                                                    local smooth = cfg.smooth or 5
                                                    local jitterX = (math.random() - 0.5) * 0.5
                                                    local jitterY = (math.random() - 0.5) * 0.5
                                                    UE4.UKismetSystemLibrary.AddMouseDelta(dx / smooth + jitterX, dy / smooth + jitterY)
                                                end
                                            end
                                        end
                                    end
                                end
                            end
                        end
                    end
                end
            end
        end
    end
end

local function hook()
    if not _G.RyzenHooked then
        _G.RyzenHooked = true
        UE4.UKismetSystemLibrary.RegisterTickEvent(RyzenTick)
    end
end
hook()
