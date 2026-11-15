--[[
Copyright (c) 2024 Thorny

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.
--]]

--[[
* pxtimers: the sample bars shown in move mode. They're frozen (nothing ticks or expires) so a
* panel's size stays put while you drag it, and they fill the panel to its Max bars so you see the
* full space it can take. Times are spread across the colour marks so every colour shows.
--]]
local tracker = {};
local times = T{ 5, 20, 45, 90, 300, 600, 1200, 1800, 2700, 3600 };

-- Status icons for the samples: a fixed set so they don't change between frames.
local icons = T{ 33, 40, 41, 43, 39, 42, 34, 35, 116, 37, 36, 38, 44, 45, 46, 47, 48, 49, 50, 51 };

local cache = {};
function tracker:Tick(panelName)
    local max = gPanels[panelName].Settings.MaxTimers;
    local state = cache[panelName];
    if (state == nil) or (state.Max ~= max) then
        state = { Max = max, Timers = T{} };
        local name = ({ Buff = 'Buff', Debuff = 'Debuff', Recast = 'Recast', Custom = 'Custom' })[panelName] or panelName;
        for i = 1, max do
            local duration = times[i] or (times[#times] + (i * 60));
            state.Timers:append({
                Creation      = i,
                Duration      = duration,
                TotalDuration = duration * 2,
                Icon          = string.format('STATUS:%u', icons[((i - 1) % #icons) + 1]),
                Label         = string.format('Sample %s %u', name, i),
                Local         = T{},
                Tooltip       = 'Sample bar: drag the panel to move it.',
            });
        end
        cache[panelName] = state;
    end
    -- Nothing in move mode removes a sample, so clear any delete a click may have set.
    for _, timer in ipairs(state.Timers) do
        timer.Local.Delete = nil;
        timer.Local.Block = nil;
    end
    return state.Timers;
end

return tracker;
