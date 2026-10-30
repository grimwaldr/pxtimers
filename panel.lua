--[[
* pxtimers - panel
* One stack of timer bars (Buffs, Debuffs, Recasts or Custom). Sorting, the timer cap and the
* finish flash come from tTimers' timer group; drawing is ImGui draw lists in a click-through window.
*
* Clicks never go through ImGui: the addon's mouse event hit-tests the bars itself, so a locked panel
* never takes a click from the game, and shift/ctrl-click and dragging work the same as before.
--]]

require('common');
local ffi   = require('ffi');
local imgui = require('imgui');
local draw  = require('draw');

pcall(ffi.cdef, 'int16_t GetKeyState(int32_t vkey);');
local function key_down(vkey)
    return bit.band(ffi.C.GetKeyState(vkey), 0x8000) ~= 0;
end

local WM_LBUTTONDOWN = 513;
local WM_LBUTTONUP   = 514;

-- Phoenix palette (shared with pxparse): the move-mode frame and the empty part of each bar.
local PALETTE = {
    track  = { 0.094, 0.055, 0.055, 0.80 },  -- #180e0e
    edge   = { 0.824, 0.671, 0.671, 0.22 },  -- #d2abab
    frame  = { 0.773, 0.318, 0.318, 0.90 },  -- #c55151
    tint   = { 0.773, 0.318, 0.318, 0.16 },
    text   = { 1.000, 0.973, 0.973, 1.00 },  -- #fff8f8
    muted  = { 0.918, 0.882, 0.882, 0.85 },
    ember  = { 1.000, 0.553, 0.475, 1.00 },  -- #ff8d79
};

local TITLES = { Buff = 'Buffs', Debuff = 'Debuffs', Recast = 'Recasts', Custom = 'Custom' };

local Panel = {};
Panel.__index = Panel;

function Panel:New(name, settings)
    local o = setmetatable({}, Panel);
    o.Name        = name;
    o.Settings    = settings;
    o.AllowDrag   = false;
    o.ShowDebugTimers = false;
    o.DragActive  = false;
    o.DragFrom    = { 0, 0 };
    o.Mouse       = { X = -1, Y = -1 };
    o.HitBoxes    = T{};
    o.Bounds      = nil;
    return o;
end

function Panel:UpdateSettings(settings)
    self.Settings = settings;
end

-----------------------------------
-- Layout and colour
-----------------------------------
local function time_text(t, tenths)
    if (t >= 3600) then
        return string.format('%d:%02d:%02d', math.floor(t / 3600), math.floor(t % 3600 / 60), math.floor(t % 60));
    elseif (t >= 60) then
        return string.format('%d:%02d', math.floor(t / 60), math.floor(t % 60));
    elseif (tenths) then
        return string.format('%.1f', math.floor(t * 10) / 10);
    end
    return string.format('%d', math.ceil(t));
end

-- Colour by time left: Low below the low mark, High above the high mark, Mid between, blended if set.
function Panel:Color(remaining)
    local s, c = self.Settings, self.Settings.Colors;
    local low, mid, high = draw.argb(c.Low), draw.argb(c.Mid), draw.argb(c.High);
    local th = s.Thresholds;
    if (remaining <= th.Low) then
        return low;
    end
    if (remaining >= th.High) then
        return high;
    end
    if (not s.Blend) then
        return (remaining < th.Mid) and low or mid;
    end
    if (remaining < th.Mid) then
        return draw.lerp(low, mid, (remaining - th.Low) / math.max(th.Mid - th.Low, 0.001));
    end
    return draw.lerp(mid, high, (remaining - th.Mid) / math.max(th.High - th.Mid, 0.001));
end

-- Sizes in screen pixels for this frame.
function Panel:Metrics()
    local s     = self.Settings;
    local scale = s.Scale;
    local font  = gSettings.Font;
    local px    = math.floor(13 * scale + 0.5);
    local line  = draw.line_height(font, px);
    local h     = math.max(math.floor(s.BarHeight * scale + 0.5), line + 2);
    return {
        px      = px,
        font    = font,
        line    = line,
        bar_h   = h,
        width   = math.floor(s.Width * scale + 0.5),
        gap     = math.max(1, math.floor(s.Spacing * scale + 0.5)),
        icon    = s.ShowIcons and gSettings.Icons and h or 0,
        pad     = math.floor(4 * scale + 0.5),
        round   = math.min(3 * scale, h / 2),
    };
end

-----------------------------------
-- Timers in, sorted render rows out
-----------------------------------
local sorters = {
    Creation = function (a, b)
        if (a.Creation == b.Creation) then return a.Label < b.Label; end
        return a.Creation < b.Creation;
    end,
    Alphabetical = function (a, b) return a.Label < b.Label; end,
    Nominal = function (a, b)
        if (a.Duration == b.Duration) then return a.Label < b.Label; end
        return a.Duration < b.Duration;
    end,
    Percentage = function (a, b)
        if (a.Percent == b.Percent) then return a.Label < b.Label; end
        return a.Percent < b.Percent;
    end,
};

function Panel:Rows(timers)
    local s = self.Settings;
    for _, timer in ipairs(timers) do
        if (timer.Duration <= 0) and ((-timer.Duration) > s.CompletionDuration) then
            timer.Local.Delete = true;
        end
    end

    local rows = T{};
    for _, timer in ipairs(timers) do
        if (timer.Local.Delete ~= true) then
            local row = {
                Creation = timer.Creation,
                Duration = timer.Duration,
                Icon     = timer.Icon,
                Label    = tostring(timer.Label or ''),
                Local    = timer.Local,
                Tooltip  = timer.Tooltip,
            };
            if (row.Duration <= 0) then
                row.Complete = s.AnimateCompletion or nil;
                row.Percent  = 0;
            else
                local total = timer.TotalDuration or row.Duration;
                row.Percent = (total > 0) and math.min(row.Duration / total, 1) or 0;
            end
            if (row.Duration > 0) or row.Complete then
                rows:append(row);
            end
        end
    end

    local sorter = sorters[s.SortType];
    if (sorter) then
        table.sort(rows, sorter);
    end
    for i = #rows, s.MaxTimers + 1, -1 do
        rows[i] = nil;
    end
    return rows;
end

-----------------------------------
-- Drawing
-----------------------------------
local WINDOW_FLAGS = bit.bor(ImGuiWindowFlags_NoDecoration, ImGuiWindowFlags_NoBackground, ImGuiWindowFlags_NoInputs,
    ImGuiWindowFlags_NoSavedSettings, ImGuiWindowFlags_NoFocusOnAppearing, ImGuiWindowFlags_NoNav,
    ImGuiWindowFlags_NoBringToFrontOnFocus, ImGuiWindowFlags_NoMove);

function Panel:DrawBar(list, m, x, y, row)
    local s       = self.Settings;
    local bar_x   = x + (m.icon > 0 and (m.icon + m.pad) or 0);
    local bar_w   = m.width - (bar_x - x);
    local x2, y2  = bar_x + bar_w, y + m.bar_h;
    local color   = self:Color(math.max(row.Duration, 0));
    local now     = os.clock();

    -- Icon
    if (m.icon > 0) then
        local tex = draw.icon(row.Icon);
        if (tex) then
            list:AddImage(tex, { x, y }, { x + m.icon, y + m.icon });
        else
            list:AddRectFilled({ x, y }, { x + m.icon, y + m.icon }, draw.u32(PALETTE.track), m.round);
        end
    end

    -- Track
    list:AddRectFilled({ bar_x, y }, { x2, y2 }, draw.u32(PALETTE.track), m.round);

    -- Fill: shrinks as it runs out (count down) or grows toward done (count up).
    local fill = 0;
    if (row.Complete) then
        local on = (math.floor(now * 5) % 2) == 0;
        fill = on and 1 or 0;
        color = draw.argb(s.Colors.Low);
    else
        fill = s.CountDown and row.Percent or (1 - row.Percent);
    end
    if (fill > 0) then
        local fx = bar_x + math.max(bar_w * fill, 1);
        local r  = (fx - bar_x >= m.round * 2) and m.round or 0;
        list:AddRectFilled({ bar_x, y }, { fx, y2 }, draw.u32(draw.alpha(color, 0.92)), r);
        list:AddRectFilled({ bar_x + r, y }, { math.max(fx - r, bar_x + r), y + 1 }, draw.u32({ 1, 1, 1, 0.22 }));
    end
    list:AddRect({ bar_x, y }, { x2, y2 }, draw.u32(PALETTE.edge), m.round, 0, 1.0);

    -- Time on the right, name on the left in what's left over.
    local ty = y + math.floor((m.bar_h - m.line) / 2);
    local right = '';
    if (row.Complete) then
        right = (self.Name == 'Recast') and 'Ready' or '';
    elseif (row.Duration > 0) then
        right = time_text(row.Duration, s.ShowTenths);
    end
    local right_w = 0;
    if (right ~= '') then
        right_w = draw.text_width(m.font, m.px, right);
        draw.text(list, m.font, m.px, x2 - m.pad - right_w, ty, PALETTE.text, right);
    end
    -- Fitting the name is a loop, so it's kept on the timer until the name, room or font changes.
    local room  = math.floor(bar_w - (m.pad * 3) - right_w);
    local fit   = row.Local.Fit;
    if (fit == nil or fit.text ~= row.Label or fit.room ~= room or fit.font ~= m.font or fit.px ~= m.px) then
        fit = { text = row.Label, room = room, font = m.font, px = m.px, out = draw.fit(m.font, m.px, row.Label, room) };
        row.Local.Fit = fit;
    end
    local label = fit.out;
    if (label ~= '') then
        draw.text(list, m.font, m.px, bar_x + m.pad, ty, PALETTE.text, label);
    end

    self.HitBoxes:append({ MinX = x, MinY = y, MaxX = x2, MaxY = y2, Row = row });
end

function Panel:Render(timers)
    local s = self.Settings;
    self.HitBoxes = T{};
    self.Bounds = nil;
    if (s.Enabled == false and not self.AllowDrag) then
        return;
    end

    local rows = self:Rows(timers);
    if (#rows == 0 and not self.AllowDrag) then
        return;
    end

    local m      = self:Metrics();
    local count  = math.max(#rows, self.AllowDrag and 1 or 0);
    local height = (count * m.bar_h) + (math.max(count - 1, 0) * m.gap);
    local ax, ay = s.Position.X, s.Position.Y;
    local top    = s.GrowUp and (ay - height) or ay;

    -- Room for the move-mode label and frame around the bars.
    local margin = 24;
    imgui.SetNextWindowPos({ ax - margin, top - margin }, ImGuiCond_Always);
    imgui.SetNextWindowSize({ m.width + margin * 2, height + margin * 2 }, ImGuiCond_Always);
    imgui.PushStyleVar(ImGuiStyleVar_WindowPadding, { 0, 0 });
    imgui.PushStyleVar(ImGuiStyleVar_WindowBorderSize, 0);
    if (imgui.Begin('##pxtimers_' .. self.Name, true, WINDOW_FLAGS)) then
        local list = imgui.GetWindowDrawList();
        local font_pushed = draw.push(m.px);
        self.Bounds = { MinX = ax, MinY = top, MaxX = ax + m.width, MaxY = top + height };
        if (self.AllowDrag) then
            -- Tint goes under the bars so they stay readable while moving.
            local b = self.Bounds;
            list:AddRectFilled({ b.MinX - 3, b.MinY - 3 }, { b.MaxX + 3, b.MaxY + 3 }, draw.u32(PALETTE.tint), 4);
        end
        for i, row in ipairs(rows) do
            local y;
            if (s.GrowUp) then
                y = ay - (i * m.bar_h) - ((i - 1) * m.gap);
            else
                y = ay + ((i - 1) * (m.bar_h + m.gap));
            end
            self:DrawBar(list, m, ax, y, row);
        end

        if (self.AllowDrag) then
            self:DrawMoveFrame(list, m);
        end
        if (font_pushed) then
            imgui.PopFont();
        end
    end
    imgui.End();
    imgui.PopStyleVar(2);
end

-- Move mode: a frame round the panel and its name on a tab at the far edge (away from the anchor,
-- so it never sits on top of the panel that grows the other way from the same spot).
function Panel:DrawMoveFrame(list, m)
    local b = self.Bounds;
    local hot = self.DragActive or self:Contains(b, self.Mouse.X, self.Mouse.Y);
    list:AddRect({ b.MinX - 3, b.MinY - 3 }, { b.MaxX + 3, b.MaxY + 3 }, draw.u32(hot and PALETTE.ember or PALETTE.frame), 4, 0, hot and 2 or 1);

    local title = TITLES[self.Name] or self.Name;
    local px    = 13;
    local w     = draw.text_width(m.font, px, title) + 10;
    local lh    = draw.line_height(m.font, px);
    local ty    = self.Settings.GrowUp and (b.MinY - lh - 6) or (b.MaxY + 4);
    list:AddRectFilled({ b.MinX - 3, ty - 1 }, { b.MinX - 3 + w, ty + lh + 2 }, draw.u32(PALETTE.frame), 3);
    draw.text(list, m.font, px, b.MinX + 2, ty, PALETTE.text, title);
    self.TabBox = { MinX = b.MinX - 3, MinY = ty - 1, MaxX = b.MinX - 3 + w, MaxY = ty + lh + 2 };
end

function Panel:RenderTooltip()
    if (not self.Settings.UseTooltips) or self.DragActive then
        return;
    end
    local row = self:HitTest(self.Mouse.X, self.Mouse.Y);
    if (row and type(row.Tooltip) == 'string' and row.Tooltip ~= '') then
        imgui.BeginTooltip();
        for line in (row.Tooltip .. '\n'):gmatch('(.-)\n') do
            imgui.TextColored(PALETTE.text, line);
        end
        imgui.EndTooltip();
    end
end

-----------------------------------
-- Mouse
-----------------------------------
function Panel:Contains(b, x, y)
    return b ~= nil and x >= b.MinX and x <= b.MaxX and y >= b.MinY and y <= b.MaxY;
end

function Panel:HitTest(x, y)
    for _, box in ipairs(self.HitBoxes) do
        if self:Contains(box, x, y) then
            return box.Row;
        end
    end
end

-- Returns true when the click belonged to this panel (so the game shouldn't see it).
function Panel:HandleMouse(e)
    self.Mouse.X, self.Mouse.Y = e.x, e.y;
    local s = self.Settings;

    if (self.DragActive) then
        s.Position.X = s.Position.X + (e.x - self.DragFrom[1]);
        s.Position.Y = s.Position.Y + (e.y - self.DragFrom[2]);
        self.DragFrom[1], self.DragFrom[2] = e.x, e.y;
        if (e.message == WM_LBUTTONUP) or (not self.AllowDrag) then
            self.DragActive = false;
            settings.save();
        end
        e.blocked = true;
        return true;
    end

    if (e.message == WM_LBUTTONDOWN) and self.AllowDrag then
        if self:Contains(self.Bounds, e.x, e.y) or self:Contains(self.TabBox, e.x, e.y) then
            self.DragActive = true;
            self.DragFrom[1], self.DragFrom[2] = e.x, e.y;
            self.Swallow = true;
            e.blocked = true;
            return true;
        end
    end

    if (e.message == WM_LBUTTONDOWN) and (not self.AllowDrag) then
        local ctrl, shift = key_down(0x11), key_down(0x10);
        if (ctrl and s.CtrlBlock) or (shift and s.ShiftCancel) then
            local row = self:HitTest(e.x, e.y);
            if (row) then
                row.Local.Delete = true;
                if (ctrl and s.CtrlBlock) then
                    row.Local.Block = true;
                end
                self.Swallow = true;
                e.blocked = true;
                return true;
            end
        end
    end

    if (e.message == WM_LBUTTONUP) and self.Swallow then
        self.Swallow = nil;
        e.blocked = true;
        return true;
    end
    return false;
end

return Panel;
