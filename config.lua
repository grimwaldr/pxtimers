--[[
* pxtimers - config
* The /pxt settings window. Every change is saved as it's made.
--]]

require('common');
local imgui       = require('imgui');
local draw        = require('draw');
local blockeditor = require('blockeditor');

local HEADER = { 1.00, 0.553, 0.475, 1.0 };  -- ember
local PANELS = T{ 'Buff', 'Debuff', 'Recast', 'Custom' };
local TITLES = { Buff = 'Buffs', Debuff = 'Debuffs', Recast = 'Recasts', Custom = 'Custom' };
local SORTS  = T{ 'Nominal', 'Percentage', 'Alphabetical', 'Creation' };
local SORT_HELP = {
    Nominal      = 'least time left first',
    Percentage   = 'lowest percent left first',
    Alphabetical = 'by name',
    Creation     = 'oldest first',
};
local TRACK  = T{ 'Self Cast Only', 'Party Only', 'Alliance Only', 'All Players' };

-- Phoenix palette for the window itself (shared with pxparse).
local STYLE = {
    { ImGuiCol_WindowBg,         { 0.094, 0.055, 0.055, 0.96 } },
    { ImGuiCol_PopupBg,          { 0.094, 0.055, 0.055, 0.98 } },
    { ImGuiCol_Border,           { 0.824, 0.671, 0.671, 0.20 } },
    { ImGuiCol_TitleBg,          { 0.161, 0.110, 0.110, 1.00 } },
    { ImGuiCol_TitleBgActive,    { 0.196, 0.122, 0.122, 1.00 } },
    { ImGuiCol_FrameBg,          { 0.161, 0.110, 0.110, 1.00 } },
    { ImGuiCol_FrameBgHovered,   { 0.773, 0.318, 0.318, 0.30 } },
    { ImGuiCol_FrameBgActive,    { 0.773, 0.318, 0.318, 0.45 } },
    { ImGuiCol_Button,           { 0.196, 0.122, 0.122, 1.00 } },
    { ImGuiCol_ButtonHovered,    { 0.831, 0.369, 0.369, 0.80 } },
    { ImGuiCol_ButtonActive,     { 0.773, 0.318, 0.318, 1.00 } },
    { ImGuiCol_Header,           { 0.773, 0.318, 0.318, 0.30 } },
    { ImGuiCol_HeaderHovered,    { 0.831, 0.369, 0.369, 0.60 } },
    { ImGuiCol_HeaderActive,     { 0.773, 0.318, 0.318, 0.80 } },
    { ImGuiCol_Tab,              { 0.196, 0.122, 0.122, 1.00 } },
    { ImGuiCol_TabHovered,       { 0.831, 0.369, 0.369, 0.80 } },
    { ImGuiCol_TabSelected or ImGuiCol_TabActive, { 0.773, 0.318, 0.318, 1.00 } },
    { ImGuiCol_CheckMark,        { 1.000, 0.553, 0.475, 1.00 } },
    { ImGuiCol_SliderGrab,       { 0.773, 0.318, 0.318, 1.00 } },
    { ImGuiCol_SliderGrabActive, { 1.000, 0.553, 0.475, 1.00 } },
    { ImGuiCol_Text,             { 1.000, 0.973, 0.973, 1.00 } },
    { ImGuiCol_TextDisabled,     { 0.541, 0.420, 0.420, 1.00 } },
};

local config = { IsOpen = { false } };

local function save()
    settings.save();
end

local function checkbox(label, tbl, key, help)
    local buffer = { tbl[key] == true };
    if (imgui.Checkbox(label, buffer)) then
        tbl[key] = buffer[1];
        save();
    end
    if (help) then
        imgui.ShowHelp(help);
    end
end

local function slider_float(label, tbl, key, lo, hi, fmt)
    local buffer = { tbl[key] };
    if (imgui.SliderFloat(label, buffer, lo, hi, fmt, ImGuiSliderFlags_AlwaysClamp)) then
        tbl[key] = buffer[1];
        save();
    end
end

local function slider_int(label, tbl, key, lo, hi)
    local buffer = { tbl[key] };
    if (imgui.SliderInt(label, buffer, lo, hi, '%d', ImGuiSliderFlags_AlwaysClamp)) then
        tbl[key] = buffer[1];
        save();
    end
end

local function combo(label, tbl, key, options, names)
    local current = tbl[key];
    if (imgui.BeginCombo(label, (names and names[current]) or current, ImGuiComboFlags_None)) then
        for _, option in ipairs(options) do
            if (imgui.Selectable((names and names[option]) or option, option == current)) and (option ~= current) then
                tbl[key] = option;
                save();
            end
        end
        imgui.EndCombo();
    end
end

local function color(label, tbl, key)
    local buffer = draw.argb(tbl[key]);
    if (imgui.ColorEdit4(label, buffer, ImGuiColorEditFlags_AlphaBar or 0)) then
        tbl[key] = draw.to_argb(buffer);
        save();
    end
end

local function panel_tab(name)
    local s  = gSettings[name];
    local id = '##pxt' .. name;
    if (not imgui.BeginTabItem(TITLES[name] .. id .. 'Tab')) then
        return;
    end

    imgui.TextColored(HEADER, 'Panel');
    checkbox('Enabled' .. id .. 'Enabled', s, 'Enabled');
    checkbox('Grow upward' .. id .. 'GrowUp', s, 'GrowUp', 'On: new bars stack up from the anchor. Off: they stack down.');
    checkbox('Show icons' .. id .. 'Icons', s, 'ShowIcons');
    checkbox('Tooltips' .. id .. 'Tips', s, 'UseTooltips', 'Hover a bar to see its details (targets, notes).');
    slider_int('Max bars' .. id .. 'Max', s, 'MaxTimers', 1, 20);
    combo('Sort' .. id .. 'Sort', s, 'SortType', SORTS);
    imgui.ShowHelp(SORT_HELP[s.SortType] or '');

    combo('Bar style' .. id .. 'Style', s, 'BarStyle', { 'gauge', 'fill' }, { gauge = 'Gauge (text on dark, strip below)', fill = 'Filled (deep colours)' });
    imgui.ShowHelp('Gauge keeps the text on a dark row with the timer as a strip underneath, the easiest to read. Filled colours the whole bar in a shade dark enough for the text.');

    imgui.TextColored(HEADER, 'Size');
    slider_float('Scale' .. id .. 'Scale', s, 'Scale', 0.5, 3.0, '%.2f');
    slider_int('Min width' .. id .. 'Width', s, 'Width', 100, 400);
    imgui.ShowHelp('The panel widens past this to fit its longest name, so names are never cut short.');
    slider_int('Bar height' .. id .. 'Height', s, 'BarHeight', 10, 32);
    slider_int('Spacing' .. id .. 'Spacing', s, 'Spacing', 0, 10);

    imgui.TextColored(HEADER, 'Timing');
    checkbox('Count down' .. id .. 'CountDown', s, 'CountDown', 'On: bars start full and empty out. Off: they fill up as the timer ends.');
    checkbox('Show tenths' .. id .. 'Tenths', s, 'ShowTenths', 'Show tenths of a second under a minute.');
    checkbox('Flash when done' .. id .. 'Anim', s, 'AnimateCompletion');
    slider_float('Flash time' .. id .. 'AnimTime', s, 'CompletionDuration', 0.5, 6.0, '%.1fs');

    imgui.TextColored(HEADER, 'Colours');
    imgui.ShowHelp('Bars take the Low colour under the low mark, High above the high mark, and Mid between.');
    color('Low' .. id .. 'Low', s.Colors, 'Low');
    color('Mid' .. id .. 'Mid', s.Colors, 'Mid');
    color('High' .. id .. 'High', s.Colors, 'High');
    checkbox('Blend' .. id .. 'Blend', s, 'Blend', 'Fade smoothly between the colours instead of switching.');
    slider_int('Low mark (s)' .. id .. 'ThLow', s.Thresholds, 'Low', 0, 120);
    slider_int('Mid mark (s)' .. id .. 'ThMid', s.Thresholds, 'Mid', 0, 300);
    slider_int('High mark (s)' .. id .. 'ThHigh', s.Thresholds, 'High', 0, 600);

    imgui.TextColored(HEADER, 'Clicks');
    checkbox('Shift-click removes' .. id .. 'Shift', s, 'ShiftCancel');
    if (s.CtrlBlock ~= nil and name ~= 'Custom') then
        checkbox('Ctrl-click blocks' .. id .. 'Ctrl', s, 'CtrlBlock', 'Removes the bar and stops that action making bars. Undo it on the Blocked tabs.');
    end
    imgui.EndTabItem();
end

local function general_tab()
    if (not imgui.BeginTabItem('General##pxtGeneralTab')) then
        return;
    end
    imgui.TextColored(HEADER, 'Look');
    combo('Font##pxtFont', gSettings, 'Font', draw.FONTS, draw.FONT_NAMES);
    imgui.ShowHelp('DejaVu Mono ships with pxtimers. Moji is FFXI\'s own text font, read from your game files (ROM/119/51.DAT) at scale 1; other scales fall back to DejaVu Mono. Ashita is ImGui\'s font.');
    checkbox('Icons##pxtIcons', gSettings, 'Icons', 'Turns every panel\'s icons off at once.');
    combo('Buff/debuff icons##pxtEffectIcons', gSettings, 'EffectIcons', { 'status', 'menu' }, { status = 'Status icon (from your client)', menu = 'Spell/ability menu icon' });
    imgui.ShowHelp('Status: the effect\'s own icon, the one on your status bar. Menu: the same icon the Recasts panel uses. Applies to new bars.');
    checkbox('Hide with Ashita\'s primitives##pxtPrims', gSettings, 'HideWithPrimitives', 'Hide the bars whenever Ashita hides its on-screen objects (e.g. /primitives hide or screenshots).');
    if (imgui.Button('Move panels##pxtMove')) then
        gCommands.unlock();
    end
    imgui.SameLine();
    if (imgui.Button('Lock panels##pxtLock')) then
        gCommands.lock();
    end

    imgui.TextColored(HEADER, 'Buffs');
    combo('Track##pxtBuffTrack', gSettings.Buff, 'TrackMode', TRACK);
    imgui.ShowHelp('Whose buff casts make bars.');
    checkbox('Split by duration##pxtBuffSplit', gSettings.Buff, 'SplitByDuration', 'One bar per duration when the same buff lasts different times on different people.');

    imgui.TextColored(HEADER, 'Debuffs');
    combo('Track##pxtDebuffTrack', gSettings.Debuff, 'TrackMode', TRACK);
    imgui.ShowHelp('Whose debuff casts make bars.');
    checkbox('Split by duration##pxtDebuffSplit', gSettings.Debuff, 'SplitByDuration');
    checkbox('Mob index in names##pxtMobIndex', gSettings.Debuff, 'ShowMobIndex', 'Adds the mob\'s index so two of the same mob can be told apart. New bars only.');

    imgui.TextColored(HEADER, 'Custom');
    checkbox('Replace same name##pxtUpdateCustom', gSettings.Custom, 'UpdateCustom', 'A new /pxt custom timer replaces one with the same name instead of adding another.');
    imgui.EndTabItem();
end

function config:Render()
    if (not self.IsOpen[1]) then
        return;
    end
    local pushed = 0;
    for _, entry in ipairs(STYLE) do
        if (entry[1] ~= nil) then
            imgui.PushStyleColor(entry[1], entry[2]);
            pushed = pushed + 1;
        end
    end
    imgui.PushStyleVar(ImGuiStyleVar_WindowRounding, 8);
    imgui.PushStyleVar(ImGuiStyleVar_FrameRounding, 4);
    imgui.SetNextWindowSize({ 420, 0 }, ImGuiCond_FirstUseEver);
    if (imgui.Begin(string.format('pxtimers v%s##pxtConfig', addon.version), self.IsOpen, ImGuiWindowFlags_AlwaysAutoResize)) then
        if imgui.BeginTabBar('##pxtConfigTabs', ImGuiTabBarFlags_NoCloseWithMiddleMouseButton) then
            general_tab();
            for _, name in ipairs(PANELS) do
                panel_tab(name);
            end
            blockeditor:DrawTabs();
            imgui.EndTabBar();
        end
    end
    imgui.End();
    imgui.PopStyleVar(2);
    imgui.PopStyleColor(pushed);
end

function config:Show()
    self.IsOpen[1] = true;
end

return config;
