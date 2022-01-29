---@diagnostic disable: undefined-global, redefined-local, undefined-field
require("Collision")

-- MENU
local version = 1.0
local menuIcon = "https://static.wikia.nocookie.net/leagueoflegends/images/0/05/Vex_OriginalCircle.png"

local Menu = MenuElement({
    id = "Champ",
    name = myHero.charName,
    type = MENU,
    leftIcon = menuIcon
})
Menu:MenuElement({
    id = "Key",
    name = "Key Settings",
    type = MENU
})
Menu.Key:MenuElement({
    id = "Combo",
    name = "Combo",
    key = string.byte(" ")
})
Menu:MenuElement({
    id = "Combo",
    name = "Combo",
    type = MENU
})
Menu.Key:MenuElement({
    id = "Harass",
    name = "Harass",
    key = string.byte(" ")
})
Menu:MenuElement({
    id = "Harass",
    name = "Harass",
    type = MENU
})
Menu:MenuElement({
    id = "Draw",
    name = "Drawings",
    type = MENU
})

---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------

local function GetMode()
    if Menu.Key.Combo:Value() then
        return "Combo"
    elseif Menu.Key.Harass:Value() then
        return "Harass"
    end
    return ""
end

local function GetDistanceSqr(pos1, pos2)
    local pos2 = pos2 or myHero.pos
    local dx = pos1.x - pos2.x
    local dz = (pos1.z or pos1.y) - (pos2.z or pos2.y)
    return dx * dx + dz * dz
end

local function GetDistance(pos1, pos2)
    return math.sqrt(GetDistanceSqr(pos1, pos2))
end

local _AllyHeroes
function GetAllyHeroes()
    if _AllyHeroes then
        return _AllyHeroes
    end
    _AllyHeroes = {}
    for i = 1, Game.HeroCount() do
        local unit = Game.Hero(i)
        if unit.isAlly then
            table.insert(_AllyHeroes, unit)
        end
    end
    return _AllyHeroes
end

local _EnemyHeroes
function GetEnemyHeroes()
    if _EnemyHeroes then
        return _EnemyHeroes
    end
    for i = 1, Game.HeroCount() do
        local unit = Game.Hero(i)
        if unit.isEnemy then
            if _EnemyHeroes == nil then
                _EnemyHeroes = {}
            end
            table.insert(_EnemyHeroes, unit)
        end
    end
    return {}
end

function IsImmobile(unit)
    for i = 0, unit.buffCount do
        local buff = unit:GetBuff(i)
        if buff and (buff.type == 5 or buff.type == 12 or buff.type == 30 or buff.type == 25 or buff.name == "recall") and
            buff.count > 0 then
            return true
        end
    end
    return false
end

local _OnVision = {}
function OnVision(unit)
    if _OnVision[unit.networkID] == nil then
        _OnVision[unit.networkID] = {
            state = unit.visible,
            tick = GetTickCount(),
            pos = unit.pos
        }
    end
    if _OnVision[unit.networkID].state == true and not unit.visible then
        _OnVision[unit.networkID].state = false
        _OnVision[unit.networkID].tick = GetTickCount()
    end
    if _OnVision[unit.networkID].state == false and unit.visible then
        _OnVision[unit.networkID].state = true
        _OnVision[unit.networkID].tick = GetTickCount()
    end
    return _OnVision[unit.networkID]
end
Callback.Add("Tick", function()
    OnVisionF()
end)
local visionTick = GetTickCount()
function OnVisionF()
    if GetTickCount() - visionTick > 100 then
        for i, v in pairs(GetEnemyHeroes()) do
            OnVision(v)
        end
    end
end

local _OnWaypoint = {}
function OnWaypoint(unit)
    if _OnWaypoint[unit.networkID] == nil then
        _OnWaypoint[unit.networkID] = {
            pos = unit.posTo,
            speed = unit.ms,
            time = Game.Timer()
        }
    end
    if _OnWaypoint[unit.networkID].pos ~= unit.posTo then
        -- print("OnWayPoint:"..unit.charName.." | "..math.floor(Game.Timer()))
        _OnWaypoint[unit.networkID] = {
            startPos = unit.pos,
            pos = unit.posTo,
            speed = unit.ms,
            time = Game.Timer()
        }
        DelayAction(function()
            local time = (Game.Timer() - _OnWaypoint[unit.networkID].time)
            local speed = GetDistance(_OnWaypoint[unit.networkID].startPos, unit.pos) /
                              (Game.Timer() - _OnWaypoint[unit.networkID].time)
            if speed > 1250 and time > 0 and unit.posTo == _OnWaypoint[unit.networkID].pos and
                GetDistance(unit.pos, _OnWaypoint[unit.networkID].pos) > 200 then
                _OnWaypoint[unit.networkID].speed = GetDistance(_OnWaypoint[unit.networkID].startPos, unit.pos) /
                                                        (Game.Timer() - _OnWaypoint[unit.networkID].time)
                -- print("OnDash: "..unit.charName)
            end
        end, 0.05)
    end
    return _OnWaypoint[unit.networkID]
end

local function GetPred(unit, speed, delay)
    local speed = speed or math.huge
    local delay = delay or 0.25
    local unitSpeed = unit.ms
    if OnWaypoint(unit).speed > unitSpeed then
        unitSpeed = OnWaypoint(unit).speed
    end
    if OnVision(unit).state == false then
        local unitPos = unit.pos + Vector(unit.pos, unit.posTo):Normalized() *
                            ((GetTickCount() - OnVision(unit).tick) / 1000 * unitSpeed)
        local predPos = unitPos + Vector(unit.pos, unit.posTo):Normalized() *
                            (unitSpeed * (delay + (GetDistance(myHero.pos, unitPos) / speed)))
        if GetDistance(unit.pos, predPos) > GetDistance(unit.pos, unit.posTo) then
            predPos = unit.posTo
        end
        return predPos
    else
        if unitSpeed > unit.ms then
            local predPos = unit.pos + Vector(OnWaypoint(unit).startPos, unit.posTo):Normalized() *
                                (unitSpeed * (delay + (GetDistance(myHero.pos, unit.pos) / speed)))
            if GetDistance(unit.pos, predPos) > GetDistance(unit.pos, unit.posTo) then
                predPos = unit.posTo
            end
            return predPos
        elseif IsImmobile(unit) then
            return unit.pos
        else
            return unit:GetPrediction(speed, delay)
        end
    end
end

function GetPercentHP(unit)
    if type(unit) ~= "userdata" then
        error("{GetPercentHP}: bad argument #1 (userdata expected, got " .. type(unit) .. ")")
    end
    return 100 * unit.health / unit.maxHealth
end

function GetPercentMP(unit)
    if type(unit) ~= "userdata" then
        error("{GetPercentMP}: bad argument #1 (userdata expected, got " .. type(unit) .. ")")
    end
    return 100 * unit.mana / unit.maxMana
end

local function GetBuffs(unit)
    local t = {}
    for i = 0, unit.buffCount do
        local buff = unit:GetBuff(i)
        if buff.count > 0 then
            table.insert(t, buff)
        end
    end
    return t
end

function HasBuff(unit, buffname)
    if type(unit) ~= "userdata" then
        error("{HasBuff}: bad argument #1 (userdata expected, got " .. type(unit) .. ")")
    end
    if type(buffname) ~= "string" then
        error("{HasBuff}: bad argument #2 (string expected, got " .. type(buffname) .. ")")
    end
    for i, buff in pairs(GetBuffs(unit)) do
        if buff.name == buffname then
            return true
        end
    end
    return false
end

function GetBuffCount(unit, buffname)
    for i = 0, unit.buffCount do
        local buff = unit:GetBuff(i)
        if buff.name == buffname and buff.count > 0 then
            return buff.count
        end
    end
    return 0
end

function GetItemSlot(unit, id)
    for i = ITEM_1, ITEM_7 do
        if unit:GetItemData(i).itemID == id then
            return i
        end
    end
    return 0
end

function GetBuffData(unit, buffname)
    for i = 0, unit.buffCount do
        local buff = unit:GetBuff(i)
        if buff.name == buffname and buff.count > 0 then
            return buff
        end
    end
    return {
        type = 0,
        name = "",
        startTime = 0,
        expireTime = 0,
        duration = 0,
        stacks = 0,
        count = 0
    }
end

function IsImmune(unit)
    if type(unit) ~= "userdata" then
        error("{IsImmune}: bad argument #1 (userdata expected, got " .. type(unit) .. ")")
    end
    for i, buff in pairs(GetBuffs(unit)) do
        if (buff.name == "KindredRNoDeathBuff" or buff.name == "UndyingRage") and GetPercentHP(unit) <= 10 then
            return true
        end
        if buff.name == "VladimirSanguinePool" or buff.name == "JudicatorIntervention" then
            return true
        end
    end
    return false
end

function IsValidTarget(unit, range, checkTeam, from)
    local range = range == nil and math.huge or range
    if type(range) ~= "number" then
        error("{IsValidTarget}: bad argument #2 (number expected, got " .. type(range) .. ")")
    end
    if type(checkTeam) ~= "nil" and type(checkTeam) ~= "boolean" then
        error("{IsValidTarget}: bad argument #3 (boolean or nil expected, got " .. type(checkTeam) .. ")")
    end
    if type(from) ~= "nil" and type(from) ~= "userdata" then
        error("{IsValidTarget}: bad argument #4 (vector or nil expected, got " .. type(from) .. ")")
    end
    if unit == nil or not unit.valid or not unit.visible or unit.dead or not unit.isTargetable or IsImmune(unit) or
        (checkTeam and unit.isAlly) then
        return false
    end
    return unit.pos:DistanceTo(from.pos and from.pos or myHero.pos) < range
end

function CountAlliesInRange(point, range)
    if type(point) ~= "userdata" then
        error("{CountAlliesInRange}: bad argument #1 (vector expected, got " .. type(point) .. ")")
    end
    local range = range == nil and math.huge or range
    if type(range) ~= "number" then
        error("{CountAlliesInRange}: bad argument #2 (number expected, got " .. type(range) .. ")")
    end
    local n = 0
    for i = 1, Game.HeroCount() do
        local unit = Game.Hero(i)
        if unit.isAlly and not unit.isMe and IsValidTarget(unit, range, false, point) then
            n = n + 1
        end
    end
    return n
end

local function CountEnemiesInRange(point, range)
    if type(point) ~= "userdata" then
        error("{CountEnemiesInRange}: bad argument #1 (vector expected, got " .. type(point) .. ")")
    end
    local range = range == nil and math.huge or range
    if type(range) ~= "number" then
        error("{CountEnemiesInRange}: bad argument #2 (number expected, got " .. type(range) .. ")")
    end
    local n = 0
    for i = 1, Game.HeroCount() do
        local unit = Game.Hero(i)
        if IsValidTarget(unit, range, true, point) then
            n = n + 1
        end
    end
    return n
end

local DamageReductionTable = {
    ["Braum"] = {
        buff = "BraumShieldRaise",
        amount = function(target)
            return 1 - ({0.3, 0.325, 0.35, 0.375, 0.4})[target:GetSpellData(_E).level]
        end
    },
    ["Urgot"] = {
        buff = "urgotswapdef",
        amount = function(target)
            return 1 - ({0.3, 0.4, 0.5})[target:GetSpellData(_R).level]
        end
    },
    ["Alistar"] = {
        buff = "Ferocious Howl",
        amount = function(target)
            return ({0.5, 0.4, 0.3})[target:GetSpellData(_R).level]
        end
    },
    ["Galio"] = {
        buff = "GalioIdolOfDurand",
        amount = function(target)
            return 0.5
        end
    },
    ["Garen"] = {
        buff = "GarenW",
        amount = function(target)
            return 0.7
        end
    },
    ["Gragas"] = {
        buff = "GragasWSelf",
        amount = function(target)
            return ({0.1, 0.12, 0.14, 0.16, 0.18})[target:GetSpellData(_W).level]
        end
    },
    ["Annie"] = {
        buff = "MoltenShield",
        amount = function(target)
            return 1 - ({0.16, 0.22, 0.28, 0.34, 0.4})[target:GetSpellData(_E).level]
        end
    },
    ["Malzahar"] = {
        buff = "malzaharpassiveshield",
        amount = function(target)
            return 0.1
        end
    }
}

function CalcPhysicalDamage(source, target, amount)
    local ArmorPenPercent = source.armorPenPercent
    local ArmorPenFlat = (0.4 + target.levelData.lvl / 30) * source.armorPen
    local BonusArmorPen = source.bonusArmorPenPercent

    if source.type == Obj_AI_Minion then
        ArmorPenPercent = 1
        ArmorPenFlat = 0
        BonusArmorPen = 1
    elseif source.type == Obj_AI_Turret then
        ArmorPenFlat = 0
        BonusArmorPen = 1
        if source.charName:find("3") or source.charName:find("4") then
            ArmorPenPercent = 0.25
        else
            ArmorPenPercent = 0.7
        end
    end

    if source.type == Obj_AI_Turret then
        if target.type == Obj_AI_Minion then
            amount = amount * 1.25
            if string.ends(target.charName, "MinionSiege") then
                amount = amount * 0.7
            end
            return amount
        end
    end

    local armor = target.armor
    local bonusArmor = target.bonusArmor
    local value = 100 / (100 + (armor * ArmorPenPercent) - (bonusArmor * (1 - BonusArmorPen)) - ArmorPenFlat)

    if armor < 0 then
        value = 2 - 100 / (100 - armor)
    elseif (armor * ArmorPenPercent) - (bonusArmor * (1 - BonusArmorPen)) - ArmorPenFlat < 0 then
        value = 1
    end
    return math.max(0, math.floor(
        DamageReductionMod(source, target, PassivePercentMod(source, target, value) * amount, 1)))
end

function CalcMagicalDamage(source, target, amount)
    local mr = target.magicResist
    local value = 100 / (100 + (mr * source.magicPenPercent) - source.magicPen)

    if mr < 0 then
        value = 2 - 100 / (100 - mr)
    elseif (mr * source.magicPenPercent) - source.magicPen < 0 then
        value = 1
    end
    return math.max(0, math.floor(
        DamageReductionMod(source, target, PassivePercentMod(source, target, value) * amount, 2)))
end

function DamageReductionMod(source, target, amount, DamageType)
    if source.type == Obj_AI_Hero then
        if GetBuffCount(source, "Exhaust") > 0 then
            amount = amount * 0.6
        end
    end

    if target.type == Obj_AI_Hero then

        for i = 0, target.buffCount do
            if target:GetBuff(i).count > 0 then
                local buff = target:GetBuff(i)
                if buff.name == "MasteryWardenOfTheDawn" then
                    amount = amount * (1 - (0.06 * buff.count))
                end

                if DamageReductionTable[target.charName] then
                    if buff.name == DamageReductionTable[target.charName].buff and
                        (not DamageReductionTable[target.charName].damagetype or
                            DamageReductionTable[target.charName].damagetype == DamageType) then
                        amount = amount * DamageReductionTable[target.charName].amount(target)
                    end
                end

                if target.charName == "Maokai" and source.type ~= Obj_AI_Turret then
                    if buff.name == "MaokaiDrainDefense" then
                        amount = amount * 0.8
                    end
                end

                if target.charName == "MasterYi" then
                    if buff.name == "Meditate" then
                        amount = amount - amount * ({0.5, 0.55, 0.6, 0.65, 0.7})[target:GetSpellData(_W).level] /
                                     (source.type == Obj_AI_Turret and 2 or 1)
                    end
                end
            end
        end

        if GetItemSlot(target, 1054) > 0 then
            amount = amount - 8
        end

        if target.charName == "Kassadin" and DamageType == 2 then
            amount = amount * 0.85
        end
    end

    return amount
end

function PassivePercentMod(source, target, amount, damageType)
    local SiegeMinionList = {"Red_Minion_MechCannon", "Blue_Minion_MechCannon"}
    local NormalMinionList = {"Red_Minion_Wizard", "Blue_Minion_Wizard", "Red_Minion_Basic", "Blue_Minion_Basic"}

    if source.type == Obj_AI_Turret then
        if table.contains(SiegeMinionList, target.charName) then
            amount = amount * 0.7
        elseif table.contains(NormalMinionList, target.charName) then
            amount = amount * 1.14285714285714
        end
    end
    if source.type == Obj_AI_Hero then
        if target.type == Obj_AI_Hero then
            if (GetItemSlot(source, 3036) > 0 or GetItemSlot(source, 3034) > 0) and source.maxHealth < target.maxHealth and
                damageType == 1 then
                amount = amount *
                             (1 + math.min(target.maxHealth - source.maxHealth, 500) / 50 *
                                 (GetItemSlot(source, 3036) > 0 and 0.015 or 0.01))
            end
        end
    end
    return amount
end

local function Priority(charName)
    local p1 = {"Alistar", "Amumu", "Blitzcrank", "Braum", "Cho'Gath", "Dr. Mundo", "Garen", "Gnar", "Maokai",
                "Hecarim", "Jarvan IV", "Leona", "Lulu", "Malphite", "Nasus", "Nautilus", "Nunu", "Olaf", "Ornn",
                "Poppy", "Rammus", "Rell", "Renekton", "Sejuani", "Shen", "Shyvana", "Singed", "Sion", "Skarner",
                "Taric", "TahmKench", "Thresh", "Volibear", "Warwick", "MonkeyKing", "Yorick", "Zac"}
    local p2 = {"Aatrox", "Bard", "Camille", "Darius", "Elise", "Evelynn", "Galio", "Gragas", "Illaoi", "Irelia",
                "Ivern", "Janna", "Jax", "Lee Sin", "Morgana", "Nami", "Neeko", "Nocturne", "Pantheon", "Pyke", "Rakan",
                "RekSai", "Rengar", "Rumble", "Senna", "Seraphine", "Sett", "Sona", "Swain", "Trundle", "Tryndamere",
                "Udyr", "Urgot", "Vi", "Viego", "XinZhao", "Yuumi", "Zoe"}
    local p3 = {"Akali", "Diana", "Ekko", "FiddleSticks", "Fiora", "Gangplank", "Gwen", "Fizz", "Heimerdinger", "Jayce",
                "Kassadin", "Kayle", "Kled", "Kha'Zix", "Lillia", "Lissandra", "Mordekaiser", "Nidalee", "Riven",
                "Ryze", "Shaco", "Sylas", "Vladimir", "Yasuo", "Zilean", "Zyra"}
    local p4 = {"Ahri", "Akshan", "Anivia", "Annie", "Aphelios", "Ashe", "AurelionSol", "Azir", "Brand", "Caitlyn",
                "Cassiopeia", "Corki", "Draven", "Ezreal", "Graves", "Jhin", "Jinx", "KaiSa", "Kalista", "Karma",
                "Karthus", "Katarina", "Kayn", "Kennen", "KogMaw", "Kindred", "Leblanc", "Lucian", "Lux", "Malzahar",
                "MasterYi", "MissFortune", "Orianna", "Qiyana", "Quinn", "Samira", "Sivir", "Soraka", "Syndra", "Talon",
                "Taliyah", "Teemo", "Tristana", "TwistedFate", "Twitch", "Varus", "Vayne", "Veigar", "Velkoz", "Vex",
                "Viktor", "Xayah", "Xerath", "Yone", "Zed", "Ziggs", "Zeri"}
    if table.contains(p1, charName) then
        return 1
    end
    if table.contains(p2, charName) then
        return 1.25
    end
    if table.contains(p3, charName) then
        return 1.75
    end
    return table.contains(p4, charName) and 2.25 or 1
end

local function GetTarget(range, t, pos)
    local t = t or "AD"
    local pos = pos or myHero.pos
    local target = {}
    for i = 1, Game.HeroCount() do
        local hero = Game.Hero(i)
        if hero.isEnemy and not hero.dead then
            OnVision(hero)
        end
        if hero.isEnemy and hero.valid and not hero.dead and
            (OnVision(hero).state == true or
                (OnVision(hero).state == false and GetTickCount() - OnVision(hero).tick < 650)) and hero.isTargetable then
            local heroPos = hero.pos
            if OnVision(hero).state == false then
                heroPos = hero.pos + Vector(hero.pos, hero.posTo):Normalized() *
                              ((GetTickCount() - OnVision(hero).tick) / 1000 * hero.ms)
            end
            if GetDistance(pos, heroPos) <= range then
                if t == "AD" then
                    target[(CalcPhysicalDamage(myHero, hero, 100) / hero.health) * Priority(hero.charName)] = hero
                elseif t == "AP" then
                    target[(CalcMagicalDamage(myHero, hero, 100) / hero.health) * Priority(hero.charName)] = hero
                elseif t == "HYB" then
                    target[((CalcMagicalDamage(myHero, hero, 50) + CalcPhysicalDamage(myHero, hero, 50)) / hero.health) *
                        Priority(hero.charName)] = hero
                end
            end
        end
    end
    local bT = 0
    for d, v in pairs(target) do
        if d > bT then
            bT = d
        end
    end
    if bT ~= 0 then
        return target[bT]
    end
end

local castSpell = {
    state = 0,
    tick = GetTickCount(),
    casting = GetTickCount() - 1000,
    mouse = mousePos
}
local function CastSpell(spell, pos, range, delay)
    local range = range or math.huge
    local delay = delay or 250
    local ticker = GetTickCount()

    if castSpell.state == 0 and GetDistance(myHero.pos, pos) < range and ticker - castSpell.casting > delay +
        Game.Latency() and pos:ToScreen().onScreen then
        castSpell.state = 1
        castSpell.mouse = mousePos
        castSpell.tick = ticker
    end
    if castSpell.state == 1 then
        if ticker - castSpell.tick < Game.Latency() then
            Control.SetCursorPos(pos)
            Control.KeyDown(spell)
            Control.KeyUp(spell)
            castSpell.casting = ticker + delay
            DelayAction(function()
                if castSpell.state == 1 then
                    Control.SetCursorPos(castSpell.mouse)
                    castSpell.state = 0
                end
            end, Game.Latency() / 1000)
        end
        if ticker - castSpell.casting > Game.Latency() then
            Control.SetCursorPos(castSpell.mouse)
            castSpell.state = 0
        end
    end
end

local aa = {
    state = 1,
    tick = GetTickCount(),
    tick2 = GetTickCount(),
    downTime = GetTickCount(),
    target = myHero
}
local lastTick = 0
local lastMove = 0
local AaTicker = Callback.Add("Tick", function()
    AaTick()
end)
function AaTick()
    if aa.state == 1 and myHero.attackData.state == 2 then
        lastTick = GetTickCount()
        aa.state = 2
        aa.target = myHero.attackData.target
    end
    if aa.state == 2 then
        if myHero.attackData.state == 1 then
            aa.state = 1
        end
        if Game.Timer() + Game.Latency() / 2000 - myHero.attackData.castFrame / 200 > myHero.attackData.endTime -
            myHero.attackData.windDownTime and aa.state == 2 then
            -- print("OnAttackComp WindUP:"..myHero.attackData.endTime)
            aa.state = 3
            aa.tick2 = GetTickCount()
            aa.downTime = myHero.attackData.windDownTime * 1000 - (myHero.attackData.windUpTime * 1000)
        end
    end
    if aa.state == 3 then
        if GetTickCount() - aa.tick2 - Game.Latency() - myHero.attackData.castFrame > myHero.attackData.windDownTime *
            1000 - (myHero.attackData.windUpTime * 1000) / 2 then
            aa.state = 1
        end
        if myHero.attackData.state == 1 then
            aa.state = 1
        end
        if GetTickCount() - aa.tick2 > aa.downTime then
            aa.state = 1
        end
    end
end

--------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
--------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------

------------------------------------------------------------------------------------------------------------------------------------------------
-- VEX --
------------------------------------------------------------------------------------------------------------------------------------------------

class "Vex"

function Vex:__init()

    print(">>>> Vex loaded! <<<<")

    self.spellIcons = {
        Q = "https://static.wikia.nocookie.net/leagueoflegends/images/1/1b/Vex_Mistral_Bolt.png",
        W = "https://static.wikia.nocookie.net/leagueoflegends/images/a/ae/Vex_Personal_Space.png",
        E = "https://static.wikia.nocookie.net/leagueoflegends/images/b/bd/Vex_Looming_Darkness.png",
        R = "https://static.wikia.nocookie.net/leagueoflegends/images/3/36/Vex_Shadow_Surge.png",
        Mana = "https://static.wikia.nocookie.net/leagueoflegends/images/0/0f/Tear_of_the_Goddess_item_old.png"
    }

    self.AA = {
        delay = 0.25,
        speed = 2000,
        width = 0,
        range = 550
    }
    self.Q = {
        delay = 0.25,
        speedMin = 600,
        speedMax = 3200,
        width1 = 360,
        width2 = 160,
        range1 = 500,
        range2 = 1200
    }
    self.W = {
        delay = 0.25,
        speed = math.huge,
        range = 475
    }
    self.E = {
        delay = 0.25,
        speed = 1250,
        width = 300,
        range = 800
    }
    self.R = {
        delay = 0.25,
        speed = 1750,
        width = 260,
        range = 2000
    }
    self.range = 550

    self:Menu()

    function OnTick()
        self:Tick()
    end
    function OnDraw()
        self:Draw()
    end
end

function Vex:Menu()
    Menu.Combo:MenuElement({
        id = "useQ",
        name = "Use Q",
        value = true,
        leftIcon = self.spellIcons.Q
    })
    Menu.Combo:MenuElement({
        id = "useQmana",
        name = "If mana % > x",
        value = 0,
        min = 0,
        max = 100,
        step = 1,
        leftIcon = self.spellIcons.Mana
    })
    Menu.Combo:MenuElement({
        id = "useW",
        name = "Use W",
        value = true,
        leftIcon = self.spellIcons.W
    })
    Menu.Combo:MenuElement({
        id = "useWmana",
        name = "If mana % > x",
        value = 0,
        min = 0,
        max = 100,
        step = 1,
        leftIcon = self.spellIcons.Mana
    })
    Menu.Combo:MenuElement({
        id = "useE",
        name = "Use E",
        value = true,
        leftIcon = self.spellIcons.E
    })
    Menu.Combo:MenuElement({
        id = "useEmana",
        name = "If mana % > x",
        value = 0,
        min = 0,
        max = 100,
        step = 1,
        leftIcon = self.spellIcons.Mana
    })
    Menu.Combo:MenuElement({
        id = "useR",
        name = "Use R",
        value = true,
        leftIcon = self.spellIcons.R
    })
    Menu.Combo:MenuElement({
        id = "useRmana",
        name = "If mana % > x",
        value = 0,
        min = 0,
        max = 100,
        step = 1,
        leftIcon = self.spellIcons.Mana
    })

    ---------------------------------------------

    Menu.Harass:MenuElement({
        id = "useQ",
        name = "Use Q",
        value = true,
        leftIcon = self.spellIcons.Q
    })
    Menu.Harass:MenuElement({
        id = "useQmana",
        name = "If mana % > x",
        value = 0,
        min = 0,
        max = 100,
        step = 1,
        leftIcon = self.spellIcons.Mana
    })
    Menu.Harass:MenuElement({
        id = "useW",
        name = "Use W",
        value = true,
        leftIcon = self.spellIcons.W
    })
    Menu.Harass:MenuElement({
        id = "useWmana",
        name = "If mana % > x",
        value = 0,
        min = 0,
        max = 100,
        step = 1,
        leftIcon = self.spellIcons.Mana
    })
    Menu.Harass:MenuElement({
        id = "useE",
        name = "Use E",
        value = true,
        leftIcon = self.spellIcons.E
    })
    Menu.Harass:MenuElement({
        id = "useEmana",
        name = "If mana % > x",
        value = 0,
        min = 0,
        max = 100,
        step = 1,
        leftIcon = self.spellIcons.Mana
    })

    ---------------------------------------------

    Menu.Draw:MenuElement({
        id = "drawQ",
        name = "Draw Q",
        value = true,
        leftIcon = self.spellIcons.Q
    })
    Menu.Draw:MenuElement({
        id = "drawW",
        name = "Draw W",
        value = true,
        leftIcon = self.spellIcons.W
    })
    Menu.Draw:MenuElement({
        id = "drawE",
        name = "Draw E",
        value = true,
        leftIcon = self.spellIcons.E
    })
    Menu.Draw:MenuElement({
        id = "drawR",
        name = "Draw R",
        value = true,
        leftIcon = self.spellIcons.R
    })

end

function Vex:Tick()
    if Game.IsChatOpen() then
        return
    end
    if myHero.dead then
        return
    end

    self.R.range = ({1000, 2000, 3000})[myHero:GetSpellData(_R).level] or 1000

    if GetMode() == "Combo" then
        if aa.state ~= 2 then
            self:Combo()
        end
    elseif GetMode() == "Harass" then
        if aa.state ~= 2 then
            self:Harass()
        end
    end
end

function Vex:Draw()

    if myHero.dead then return end

    if Menu.Draw.drawQ:Value() then
        Draw.Circle(myHero.pos, self.Q.range2)
    end
    if Menu.Draw.drawW:Value() then
        Draw.Circle(myHero.pos, self.W.range)
    end
    if Menu.Draw.drawE:Value() then
        Draw.Circle(myHero.pos, self.E.range)
    end
    if Menu.Draw.drawR:Value() then
        Draw.Circle(myHero.pos, self.R.range)
    end
end

function Vex:Combo()

    local mana = GetPercentMP(myHero)
    if Menu.Combo.useQ:Value() and mana > Menu.Combo.useQmana:Value() then
        self:UseQ()
    end
    if Menu.Combo.useW:Value() and mana > Menu.Combo.useWmana:Value() then
        self:UseW()
    end
    if Menu.Combo.useE:Value() and mana > Menu.Combo.useEmana:Value() then
        self:UseE()
    end
    if Menu.Combo.useR:Value() and mana > Menu.Combo.useRmana:Value() then
        self:UseR()
    end
end

function Vex:Harass()

    local mana = GetPercentMP(myHero)
    if Menu.Harass.useQ:Value() and mana > Menu.Harass.useQmana:Value() then
        self:UseQ()
    end
    if Menu.Harass.useW:Value() and mana > Menu.Harass.useWmana:Value() then
        self:UseW()
    end
    if Menu.Harass.useE:Value() and mana > Menu.Harass.useEmana:Value() then
        self:UseE()
    end
end

------------ Q START ------------

function Vex:UseQ()

    local qSpeed = (self.Q.speedMax + self.Q.speedMin) / 2

    for i, target in pairs(GetEnemyHeroes()) do
        if IsValidTarget(target, self.Q.range2, true, myHero.pos) then
            local qPred = GetPred(target, qSpeed, self.Q.delay)
            local hp = target.health + target.shieldAP + target.shieldAD
            local dmg = CalcMagicalDamage(myHero, target, 15 + 45 * myHero:GetSpellData(_Q).level + (0.6 * myHero.ap))

            if qPred and GetDistance(myHero.pos, qPred) < self.Q.range2 then
                self:UseQclose(target, qPred)
                if hp < dmg then
                    self:CastQ(qPred)
                end
            end
        end
    end

    local comboTarget = GetTarget(self.Q.range2, "AP")
    if comboTarget then
        local qPred = GetPred(comboTarget, qSpeed, self.Q.delay)
        if qPred and GetDistance(myHero.pos, qPred) < self.Q.range2 then
            self:UseQhighHitchance(comboTarget, qPred)
        end
    end
end

function Vex:UseQhighHitchance(target, qPred)

    -- immobile
    if IsImmobile(target) then
        self:CastQ(target.pos)
    end

    -- slowed
    if target.ms < 340 then
        self:CastQ(qPred)
    end

    -- onWayPoint
    if Game.Timer() - OnWaypoint(target).time > 0.05 and GetDistance(myHero.pos, qPred) < self.Q.range2 then
        self:CastQ(qPred)
    end

    -- dash
    if OnWaypoint(target).speed > target.ms then
        if GetDistance(myHero.pos, qPred) < self.Q.range2 then
            self:CastQ(qPred)
        end
    end
end

function Vex:UseQclose(target, qPred)
    if GetDistance(myHero.pos, qPred) < self.Q.range1 then
        self:CastQ(qPred)
    end
end

function Vex:CastQ(tPos)
    if Game.CanUseSpell(_Q) == 0 and castSpell.state == 0 then
        CastSpell(HK_Q, tPos, 5000)
    end
end

------------ Q END ------------

------------ W START ------------

function Vex:UseW()

    if Game.CanUseSpell(_W) == 0 and castSpell.state == 0 then
        for i, target in pairs(GetEnemyHeroes()) do
            if IsValidTarget(target, self.W.range, true, myHero.pos) then
                local wPred = GetPred(target, self.W.speed, self.W.delay)
                if wPred and GetDistance(myHero.pos, wPred) < self.W.range then
                    Control.CastSpell(HK_W)
                end
            end
        end
    end
end

------------ W END ------------

------------ W START ------------

function Vex:UseE()

    for i, target in pairs(GetEnemyHeroes()) do
        if IsValidTarget(target, self.E.range, true, myHero.pos) then
            local ePred = GetPred(target, self.E.delay, self.E.delay)
            local hp = target.health + target.shieldAP + target.shieldAD
            local dmg = CalcMagicalDamage(myHero, target, 30 + 20 * myHero:GetSpellData(_E).level +
                (0.35 + 0.05 * myHero:GetSpellData(_E).level) * myHero.ap)

            if ePred and GetDistance(myHero.pos, ePred) < self.E.range then
                self:UseEclose(target, ePred)
                if hp < dmg then
                    self:CastE(ePred)
                end
            end
        end
    end

    local comboTarget = GetTarget(self.E.range, "AP")
    if comboTarget then
        local ePred = GetPred(comboTarget, self.E.delay, self.E.delay)
        if ePred and GetDistance(myHero.pos, ePred) < self.E.range then
            self:UseEhighHitchance(comboTarget, ePred)
        end
    end
end

function Vex:UseEhighHitchance(target, ePred)

    -- immobile
    if IsImmobile(target) then
        self:CastE(target.pos)
    end

    -- slowed
    if target.ms < 340 then
        self:CastE(ePred)
    end

    -- onWayPoint
    if Game.Timer() - OnWaypoint(target).time > 0.05 and Game.Timer() - OnWaypoint(target).time < 0.06 and
        GetDistance(myHero.pos, ePred) < self.E.range then
        self:CastE(ePred)
    end

    -- dash
    if OnWaypoint(target).speed > target.ms then
        if GetDistance(myHero.pos, ePred) < self.E.range then
            self:CastE(ePred)
        end
    end
end

function Vex:UseEclose(target, ePred)
    if GetDistance(myHero.pos, ePred) < self.E.range then
        self:CastE(ePred)
    end
end

function Vex:CastE(tPos)
    if Game.CanUseSpell(_E) == 0 and castSpell.state == 0 then
        CastSpell(HK_E, tPos, 5000)
    end
end

------------ E END ------------

------------ R START ------------

function Vex:UseR()

    for i, target in pairs(GetEnemyHeroes()) do
        if IsValidTarget(target, self.R.range, true, myHero.pos) then
            local rPred = GetPred(target, self.R.speed, self.R.delay)
            local hp = target.health + target.shieldAP + target.shieldAD
            local rMissileDmg = CalcMagicalDamage(myHero, target,
                25 + 50 * myHero:GetSpellData(_R).level + (0.2 * myHero.ap))
            local rImpactDmg = CalcMagicalDamage(myHero, target,
                50 + 100 * myHero:GetSpellData(_R).level + (0.5 * myHero.ap))

            if myHero:GetSpellData(_R).name == "VexR" then
                if rPred and GetDistance(myHero.pos, rPred) < self.R.range then

                    local rSetCol = Collision:SetSpell(self.R.range, self.R.speed, self.R.delay, self.R.width)
                    local rCol = rSetCol:__GetHeroCollision(myHero, mousePos, 3, target)

                    if Game.CanUseSpell(_R) == 0 and castSpell.state == 0 and not rCol then
                        if CountEnemiesInRange(rPred, 2000) == 1 then
                            if hp < rMissileDmg + rImpactDmg then
                                self:UseRhighHitchance(target, rPred)
                                -- Control.CastSpell(HK_R, rPred)
                            end
                        elseif hp < rMissileDmg and not rCol then
                            self:UseRhighHitchance(target, rPred)
                            -- Control.CastSpell(HK_R, rPred)
                        end
                    end
                end
            elseif HasBuff(target, "VexRTarget") and hp < rImpactDmg then
                if CountEnemiesInRange(target, 2000) == 1 then
                    Control.CastSpell(HK_R)
                end
            end
        end
    end
end

function Vex:UseRhighHitchance(target, rPred)

    -- immobile
    if IsImmobile(target) then
        self:CastR1(target.pos)
    end

    -- slowed
    if target.ms < 340 then
        self:CastR1(rPred)
    end

    -- onWayPoint
    if Game.Timer() - OnWaypoint(target).time > 0.05 and GetDistance(myHero.pos, rPred) < self.R.range then
        self:CastR1(rPred)
    end

    -- dash
    if OnWaypoint(target).speed > target.ms then
        if GetDistance(myHero.pos, rPred) < self.R.range then
            self:CastR1(rPred)
        end
    end
end

function Vex:CastR1(tPos)
    CastSpell(HK_R, myHero.pos:Extended(tPos, 200), 4000)
end

------------ R END ------------

function OnLoad()
    if myHero.charName == "Vex" then
        Vex()
    else
        print("Wrong champ, please use Vex.")
        return
    end
end