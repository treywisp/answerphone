--[[

This is free and unencumbered software released into the public domain.

Anyone is free to copy, modify, publish, use, compile, sell, or
distribute this software, either in source code form or as a compiled
binary, for any purpose, commercial or non-commercial, and by any
means.

In jurisdictions that recognize copyright laws, the author or authors
of this software dedicate any and all copyright interest in the
software to the public domain. We make this dedication for the benefit
of the public at large and to the detriment of our heirs and
successors. We intend this dedication to be an overt act of
relinquishment in perpetuity of all present and future rights to this
software under copyright law.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND,
EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF
MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT.
IN NO EVENT SHALL THE AUTHORS BE LIABLE FOR ANY CLAIM, DAMAGES OR
OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE,
ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR
OTHER DEALINGS IN THE SOFTWARE.

For more information, please refer to <https://unlicense.org>

]]

script_author("treywisp")
script_name("answerphone")

local sampev = require("samp.events")
local inicfg = require("inicfg")

local settings_source = "answerphone.ini"
local settings = inicfg.load({
    variables = {
        active = true,
        dnd = false, -- do not distrub 
    }
}, settings_source)

local answers = {
    afk = "[Aвтоответчик] Я в AFK без ESC более 10 мин. Напиши позже",
    combat = "[Aвтоответчик] Я сейчас в бою. Отвечу тебе позже",
    dnd = "[Aвтоответчик] Я сейчас занят. Пожалуйста, напиши позже"
}

local ped_states = {
    afk = false,
    combat = false,
    last_afk = 0,
    last_combat = 0,
}

local peds = {}

local function notify(text)
    sampAddChatMessage("[answerphone] {FFFFFF}"..text, 0xF4A460)
end

local function answer(nick, id)
    local now = os.time() * 1000

    if peds[nick] and now - peds[nick] < 180000 then return end
    peds[nick] = nil

    lua_thread.create(function() wait(666)
        local response = settings.variables.dnd and answers.dnd
                         or ped_states.combat and answers.combat
                         or ped_states.afk and answers.afk
        if response then sampSendChat("/sms " .. id .. " " .. response) end

        peds[nick] = os.time() * 1000
    end)
end

function main()
    if not isSampAvailable or not isSampfuncsLoaded() then return end
    while not isSampAvailable() do wait (100) end

    notify("Загружено. Автоответчик (/ap) -" .. (settings.variables.active and "{A7FC00} включен{FFFFFF}." or "{FF0000} выключен{FFFFFF}.") .. " Режим \"не беспокоить\" (/ap_dnd) -" .. (settings.variables.dnd and "{A7FC00} включен{FFFFFF}" or "{FF0000} выключен{FFFFFF}"))

    sampRegisterChatCommand("ap", function()
        settings.variables.active = not settings.variables.active
        inicfg.save(settings, settings_source)
        notify("Автоответчик теперь " .. (settings.variables.active and "работает" or "выключен"))
    end)

    sampRegisterChatCommand("ap_dnd", function()
        settings.variables.dnd = not settings.variables.dnd
        inicfg.save(settings, settings_source)
        notify("Режим \"не беспокоить\" теперь " .. (settings.variables.dnd and "работает" or "выключен"))
    end)

    while true do wait(0)
        if settings.variables.active then
            local now = os.time() * 1000

            for i = 0, 255 do
                if (isKeyJustPressed(i)) then
                    ped_states.last_afk = now
                    if (ped_states.afk) then ped_states.afk = not ped_states.afk end
                end
            end

            if (ped_states.combat) and (now - ped_states.last_combat > 10000) then
                ped_states.last_combat = false
            end

            if (now - ped_states.last_afk > 600000) then
                ped_states.afk = true
            end
        end
    end
end

function sampev.onSendTakeDamage(id, damage, weapon, bodypart)
    if (id ~= 65535) and (damage > 3) and (settings.variables.active) then
        ped_states.last_combat = os.time() * 1000
        ped_states.combat = true
    end
end

function sampev.onServerMessage(color, text)
    if (color == -65281) and (text:find("^ SMS%: .*%. Отправитель%: .*%[%d+%]")) and (settings.variables.active) then
        local nick, id = string.match(text, "^ SMS%: .*%. Отправитель%: (.*)%[(%d+)%]")
        if ped_states.afk or ped_states.combat or settings.variables.dnd then
            answer(nick, id)
        end
    end
end