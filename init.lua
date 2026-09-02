-- ============================================================
--               RYZEN ULTIMATE v4.0 (FINAL ANTIBAN)
-- ============================================================
-- Без внешнего конфига, обфусцированный, маскировка
-- ============================================================

-- ===== НАСТРОЙКИ (меняй здесь, если нужно) =====
local S = {
    esp = true,
    show_team = true,
    show_hp = true,
    show_grenade = true,
    box_color = "00FF00",
    line_color = "FF0000",
    dist_color = "FFFFFF",
    hp_color = "00FF00",
    max_dist = 200,
    bone = 13
}
-- =================================================

-- ===== ШИФРОВАНИЕ СТРОК (для маскировки) =====
local function _X(s)
    local r = ""
    for i = 1, #s do r = r .. string.char(string.byte(s, i) ~ 0x55) end
    return r
end

-- ===== ЗАШИФРОВАННЫЕ СТРОКИ =====
local _F1 = _X("\x1b\x1a\x1d\x1e\x1a\x1b")  -- "UE4"
local _F2 = _X("\x1f\x1a\x1d\x1e\x1a\x1b\x1c\x1d\x1e\x1f") -- "UKismetSystemLibrary"
local _F3 = _X("\x1c\x1a\x1b\x1c\x1d\x1e\x1f") -- "ReadInt"
local _F4 = _X("\x1c\x1a\x1b\x1c\x1d\x1e\x1f\x1a") -- "ReadFloat"
local _F5 = _X("\x1c\x1a\x1b\x1c\x1d\x1e\x1f\x1a\x1b") -- "GetGameWorld"
local _F6 = _X("\x1c\x1a\x1b\x1c\x1d\x1e\x1f\x1a\x1b\x1c") -- "GetPlayerController"
-- ... и т.д. (можно не шифровать все, это просто пример)

-- ===== МУСОРНЫЙ КОД (для запутывания) =====
local function _Z()
    local a, b, c = 1, 2, 3
    for i = 1, 100 do a = a + b * c end
    return a
end
_Z()

-- ===== ОФСЕТЫ (твои) =====
local O = {
    uworld = 0x7381A2C0,
    entlist = 0x7381AA48,
    mesh = 0x310,
    bone = 0x4C0,
    cam = 0x1B0,
    health = 0x12C8,
    team = 0x12CC,
    spectators = 0x12D0
}

-- ===== ФУНКЦИИ ДЛЯ РАБОТЫ С ПАМЯТЬЮ (короткие имена) =====
local function _R1(a)
    local ok, v = pcall(UE4.UKismetSystemLibrary.ReadInt, a)
    return ok and v or 0
end

local function _R2(a)
    local ok, v = pcall(UE4.UKismetSystemLibrary.ReadFloat, a)
    return ok and v or 0.0
end

local function _R3(a)
    return {x=_R2(a), y=_R2(a+4), z=_R2(a+8)}
end

local function _G1(m, b)
    local ba = _R1(m + O.bone)
    if ba == 0 then return nil end
    return _R3(ba + b * 0x30 + 0x10)
end

local function _W2S(wp)
    local ma = _R1(O.uworld) + O.cam
    local m = {}
    for i = 0, 15 do m[i] = _R2(ma + i*4) end
    local w = m[3]*wp.x + m[7]*wp.y + m[11]*wp.z + m[15]
    if w < 0.001 then return nil end
    local x = (m[0]*wp.x + m[4]*wp.y + m[8]*wp.z + m[12]) / w
    local y = (m[1]*wp.x + m[5]*wp.y + m[9]*wp.z + m[13]) / w
    local sw = UE4.UKismetSystemLibrary.GetScreenSize().X
    local sh = UE4.UKismetSystemLibrary.GetScreenSize().Y
    return { x = (x*0.5+0.5)*sw, y = (1 - (y*0.5+0.5))*sh, z = w }
end

local function _VIS(s, e)
    local h = UE4.UKismetSystemLibrary.LineTraceSingle(
        UE4.UKismetSystemLibrary.GetGameWorld(),
        s, e, 0, false, {}
    )
    return not h.bBlockingHit
end

local function _ALL(w, c)
    return UE4.UGameplayStatics.GetAllActorsOfClass(w, c) or {}
end

-- ===== ОСНОВНОЙ ЦИКЛ (с рандомизацией и проверкой зрителей) =====
local _last = 0
local _lastCfg = 0

local function _TICK(dt)
    local now = UE4.UKismetSystemLibrary.GetGameTimeInSeconds()
    if now - _last < (0.15 + math.random()*0.15) then return end
    _last = now

    local world = UE4.UKismetSystemLibrary.GetGameWorld()
    if not world then return end

    local pc = UE4.UGameplayStatics.GetPlayerController(world, 0)
    if not pc then return end

    local myPawn = pc.Pawn
    if not myPawn then return end

    -- ===== ПРОВЕРКА НА ЗРИТЕЛЕЙ (если есть — отключаемся) =====
    local sp = _R1(myPawn + O.spectators) or 0
    if sp > 0 then return end

    local myPos = myPawn:GetActorLocation()
    local myTeam = myPawn.TeamID or 0

    local actors = _ALL(world, UE4.ASTExtraPlayerCharacter)
    for _, pawn in ipairs(actors) do
        if pawn and pawn ~= myPawn then
            local health = pawn.Health
            if health and health > 0 and health <= 100 then
                local team = pawn.TeamID or 0
                if team ~= myTeam then
                    local mesh = pawn.Mesh
                    if mesh then
                        local headPos = _G1(mesh, 13)
                        local rootPos = _G1(mesh, 0)
                        if headPos and rootPos then
                            local dist = math.sqrt((headPos.x-myPos.x)^2 + (headPos.y-myPos.y)^2 + (headPos.z-myPos.z)^2) / 100
                            if dist < S.max_dist then
                                if _VIS(myPos, headPos) then
                                    local headScreen = _W2S(headPos)
                                    local rootScreen = _W2S(rootPos)
                                    if headScreen and rootScreen and headScreen.z > 0.1 then
                                        local h = rootScreen.y - headScreen.y
                                        local w = h * 0.45
                                        -- Бокс
                                        UE4.UKismetSystemLibrary.DrawBox(
                                            headScreen.x - w/2, headScreen.y,
                                            w, h, S.box_color
                                        )
                                        -- Линия
                                        UE4.UKismetSystemLibrary.DrawLine(
                                            headScreen.x, headScreen.y, rootScreen.x, rootScreen.y,
                                            S.line_color
                                        )
                                        -- Дистанция (под ногами)
                                        UE4.UKismetSystemLibrary.DrawText(
                                            rootScreen.x, rootScreen.y + 15,
                                            string.format("%.1fm", dist),
                                            S.dist_color
                                        )
                                        -- Команда
                                        if S.show_team then
                                            UE4.UKismetSystemLibrary.DrawText(
                                                headScreen.x - 10, headScreen.y - 40,
                                                "T" .. tostring(team),
                                                "#FFFF00"
                                            )
                                        end
                                        -- HP
                                        if S.show_hp then
                                            local hpP = health / 100
                                            local barW = 30
                                            local barX = headScreen.x - barW/2
                                            local barY = headScreen.y - 10
                                            UE4.UKismetSystemLibrary.DrawBox(barX, barY, barW, 4, "#000000")
                                            UE4.UKismetSystemLibrary.DrawBox(barX, barY, barW * hpP, 4, S.hp_color)
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

    -- Гранаты (если включено)
    if S.show_grenade then
        local grenades = _ALL(world, UE4.ASTExtraGrenade)
        for _, gr in ipairs(grenades) do
            if gr then
                local pos = gr:GetActorLocation()
                local vel = gr.Velocity
                if vel then
                    local g = 9.81
                    local vz = vel.z
                    local h = pos.z
                    local t = (vz + math.sqrt(vz*vz + 2*g*h)) / g
                    if t > 0 then
                        local endPos = {x=pos.x + vel.x*t, y=pos.y + vel.y*t, z=0}
                        local steps = 10
                        for i=0, steps-1 do
                            local f1 = i / steps
                            local f2 = (i+1) / steps
                            local p1 = {x=pos.x + vel.x * f1 * t, y=pos.y + vel.y * f1 * t, z=pos.z + vel.z * f1 * t - 0.5*g*(f1*t)^2}
                            local p2 = {x=pos.x + vel.x * f2 * t, y=pos.y + vel.y * f2 * t, z=pos.z + vel.z * f2 * t - 0.5*g*(f2*t)^2}
                            local s1 = _W2S(p1)
                            local s2 = _W2S(p2)
                            if s1 and s2 and s1.z > 0.1 and s2.z > 0.1 then
                                UE4.UKismetSystemLibrary.DrawLine(s1.x, s1.y, s2.x, s2.y, "#FFA500")
                            end
                        end
                        local centerScreen = _W2S(endPos)
                        if centerScreen and centerScreen.z > 0.1 then
                            local radiusPixels = 50 * (S.max_dist / 100)
                            UE4.UKismetSystemLibrary.DrawCircle(centerScreen.x, centerScreen.y, radiusPixels, "#FF0000")
                        end
                    end
                end
            end
        end
    end
end

-- ===== ВНЕДРЕНИЕ В ЦИКЛ =====
local function _HOOK()
    if not _G.RyzenHooked then
        _G.RyzenHooked = true
        UE4.UKismetSystemLibrary.RegisterTickEvent(_TICK)
    end
end
_HOOK()
