--[[
* pxtimers - timer bars for Phoenix XI
* Buffs you cast, debuffs you land, your recasts and custom timers, drawn with ImGui.
*
* Built on Thorny's tTimers (MIT): the action tracking and duration calculators come from it, with
* the durations checked against the Phoenix server's scripts. The drawing is new: no GDI+ font DLL
* and no D3DX sprite, the likely cause of tTimers' white screen under Wine/Proton.
*
* Copyright (c) 2024 Thorny (tTimers), 2026 Grimwald (pxtimers). See LICENSE.
--]]

addon.name    = 'pxtimers';
addon.author  = 'Grimwald';
addon.version = '0.1.2';
addon.desc    = 'Buff, debuff, recast and custom timer bars for Phoenix XI.';
addon.link    = 'https://github.com/grimwaldr/pxtimers';

require('common');
require('helpers');
chat     = require('chat');
settings = require('settings');

local jit = require('jit');
jit.off();

-----------------------------------
-- Settings
-----------------------------------
local function panel(t)
    local base = T{
        Enabled            = true,
        Position           = T{ X = 40, Y = 400 },
        Scale              = 1.0,
        Width              = 220,
        BarHeight          = 18,
        Spacing            = 2,
        MaxTimers          = 10,
        GrowUp             = false,
        ShowIcons          = true,
        CountDown          = true,
        ShowTenths         = true,
        SortType           = 'Nominal',
        AnimateCompletion  = true,
        CompletionDuration = 3,
        UseTooltips        = true,
        ShiftCancel        = true,
        CtrlBlock          = true,
        Blend              = true,
        Thresholds         = T{ Low = 10, Mid = 30, High = 60 },
        Colors             = T{ Low = 0xFFE04040, Mid = 0xFFC5A131, High = 0xFF63BA8A },
    };
    for k, v in pairs(t) do
        base[k] = v;
    end
    return base;
end

local defaults = T{
    Font               = 'mono',
    Icons              = true,
    HideWithPrimitives = true,

    -- Buffs grow up and debuffs grow down from the same edge, recasts and custom the same to the right.
    Buff = panel({
        Position        = T{ X = 40, Y = 400 },
        GrowUp          = true,
        SplitByDuration = true,
        TrackMode       = 'Self Cast Only',
        Blocked         = T{},
    }),
    Debuff = panel({
        Position        = T{ X = 40, Y = 404 },
        SplitByDuration = true,
        TrackMode       = 'Self Cast Only',
        ShowMobIndex    = true,
        Colors          = T{ Low = 0xFFE04040, Mid = 0xFFC5A131, High = 0xFF9B7BD4 },
        Blocked         = T{},
    }),
    Recast = panel({
        Position   = T{ X = 420, Y = 400 },
        GrowUp     = true,
        CountDown  = false,
        Colors     = T{ Low = 0xFF63BA8A, Mid = 0xFFC5A131, High = 0xFFD2ABAB },
        Blocked    = T{},
    }),
    Custom = panel({
        Position     = T{ X = 420, Y = 404 },
        CountDown    = false,
        Colors       = T{ Low = 0xFFE04040, Mid = 0xFFC5A131, High = 0xFFFF8D79 },
        UpdateCustom = false,
    }),
};



-----------------------------------
-- Panels and trackers
-----------------------------------
local Panel = require('panel');
local draw  = require('draw');
local config, customTracker, dummyTracker;
local trackers = T{};
local ready = false;

-- Built at load, as tTimers did: the trackers read game memory when they're required.
local function init()
    gSettings = settings.load(defaults:copy(true));
    gPanels = T{
        Buff   = Panel:New('Buff', gSettings.Buff),
        Debuff = Panel:New('Debuff', gSettings.Debuff),
        Recast = Panel:New('Recast', gSettings.Recast),
        Custom = Panel:New('Custom', gSettings.Custom),
    };

    -- Character change: each character keeps its own settings file.
    settings.register('settings', 'pxtimers_settings_update', function (s)
        gSettings = s;
        for name, p in pairs(gPanels) do
            p:UpdateSettings(gSettings[name]);
        end
    end);

    config        = require('config');
    customTracker = require('trackers.custom');
    dummyTracker  = require('trackers.dummy');
    trackers = T{
        { Name = 'Buff',   Tracker = require('trackers.buff') },
        { Name = 'Debuff', Tracker = require('trackers.debuff') },
        { Name = 'Recast', Tracker = require('trackers.recast') },
        { Name = 'Custom', Tracker = customTracker },
    };
    ready = true;
end

ashita.events.register('load', 'pxtimers_load', init);

-----------------------------------
-- Commands
-----------------------------------
gCommands = {};

function gCommands.unlock()
    for _, p in pairs(gPanels) do
        p.AllowDrag = true;
        p.ShowDebugTimers = true;
    end
    draw.say('Panels unlocked: drag them where you want, then /pxt lock.');
end

function gCommands.lock()
    for _, p in pairs(gPanels) do
        p.AllowDrag = false;
        p.ShowDebugTimers = false;
        p.DragActive = false;
    end
    settings.save();
    draw.say('Panels locked.');
end

-- "30" or "30s", "5.5m", "1h", or a clock time "17:13:20" later today.
local function parse_duration(text)
    if (type(text) ~= 'string') then
        return nil;
    end
    local h, m, s = text:match('^(%d+):(%d+):(%d+)$');
    if (h) then
        local t = os.time({ year = os.date('%Y'), month = os.date('%m'), day = os.date('%d'),
            hour = tonumber(h), min = tonumber(m), sec = tonumber(s) });
        local diff = os.difftime(t, os.time());
        return (diff > 0) and diff or nil;
    end
    local number, unit = text:lower():match('^([%d%.]+)([smh]?)$');
    number = tonumber(number);
    if (not number) then
        return nil;
    end
    return number * (({ s = 1, m = 60, h = 3600 })[unit] or 1);
end

local function help()
    draw.say('/pxt - settings');
    draw.say('/pxt move - unlock the panels to drag them (shows sample bars)');
    draw.say('/pxt lock - lock the panels and save where they are');
    draw.say('/pxt custom "Label" 5m [repeat] ["tooltip"] - a timer of your own (30s, 5.5m, 1h, or 17:13:20)');
    draw.say('/pxt stop "Label" - remove a custom timer');
    draw.say('/pxt font [mono|moji|ashita] - the bar font');
end

ashita.events.register('command', 'pxtimers_command', function (e)
    local args = e.command:args();
    if (#args == 0) then
        return;
    end
    local cmd = args[1]:lower();
    if (cmd ~= '/pxt' and cmd ~= '/pxtimers') then
        return;
    end
    e.blocked = true;
    if (not ready) then
        return;
    end

    local sub = (args[2] or ''):lower();
    if (sub == '') then
        config:Show();
    elseif (sub == 'move' or sub == 'unlock' or sub == 'reposition') then
        gCommands.unlock();
    elseif (sub == 'lock') then
        gCommands.lock();
    elseif (sub == 'custom') then
        local duration = parse_duration(args[4]);
        if (not args[3] or not duration) then
            draw.say('Usage: /pxt custom "Label" 5m [repeat] ["tooltip"]');
            return;
        end
        local timer = {
            Creation      = os.clock(),
            Label         = args[3],
            Local         = T{},
            Expiration    = os.clock() + duration,
            TotalDuration = duration,
        };
        if (args[5] and args[5]:lower() == 'repeat') then
            timer.Repeating = true;
            timer.Tooltip = args[6];
        else
            timer.Tooltip = args[5];
        end
        customTracker:AddTimer(timer);
    elseif (sub == 'stop') then
        if (args[3]) then
            customTracker:DeleteTimer(args[3]);
        end
    elseif (sub == 'font') then
        local wanted = (args[3] or ''):lower();
        if (wanted == 'moji') then wanted = 'game'; end
        if (draw.FONT_NAMES[wanted] == nil) then
            -- Alone: step to the next font.
            local current = 1;
            for i, f in ipairs(draw.FONTS) do
                if (f == gSettings.Font) then current = i; end
            end
            wanted = draw.FONTS[(current % #draw.FONTS) + 1];
        end
        gSettings.Font = wanted;
        settings.save();
        draw.say('Font: ' .. draw.FONT_NAMES[wanted]);
    else
        help();
    end
end);

-----------------------------------
-- Frame
-----------------------------------
local function hidden()
    if (gSettings.HideWithPrimitives and not AshitaCore:GetPrimitiveManager():GetVisible()) then
        return true;
    end
    -- Nothing to time while zoning or at the login screen.
    local player = GetPlayerEntity();
    return player == nil;
end

ashita.events.register('d3d_present', 'pxtimers_present', function ()
    if (not ready) then
        return;
    end
    config:Render();

    -- Trackers tick every frame so expiries and blocks are handled even while the bars are hidden.
    local results = {};
    for _, entry in ipairs(trackers) do
        local p = gPanels[entry.Name];
        local ok, timers = pcall(entry.Tracker.Tick, entry.Tracker);
        if (not ok) then
            timers = T{};
        end
        if (p.ShowDebugTimers) then
            timers = dummyTracker:Tick(entry.Name);
        end
        results[entry.Name] = timers;
    end

    if (hidden()) then
        for _, p in pairs(gPanels) do
            p.HitBoxes, p.Bounds = T{}, nil;
        end
        return;
    end

    for _, entry in ipairs(trackers) do
        gPanels[entry.Name]:Render(results[entry.Name]);
    end
    for i = #trackers, 1, -1 do
        gPanels[trackers[i].Name]:RenderTooltip();
    end
end);

ashita.events.register('mouse', 'pxtimers_mouse', function (e)
    if (not ready) then
        return;
    end
    for _, entry in ipairs(trackers) do
        if gPanels[entry.Name]:HandleMouse(e) then
            return;
        end
    end
end);

ashita.events.register('unload', 'pxtimers_unload', function ()
    draw.release();
end);
