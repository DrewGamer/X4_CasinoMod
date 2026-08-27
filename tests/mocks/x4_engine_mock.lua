--[[
    X4 Foundations Engine Mock for Headless Lua 5.1 Testing
    Mocks X4 Lua API functions, Helper tables, and game state.
--]]

local X4Mock = {
    player_money = 1000000, -- Default 1,000,000 Cr
    station_money = 5000000, -- Default 5,000,000 Cr
    registered_events = {},
    menu_rows = {},
    active_menu = nil,
    ui_triggers = {},
    debug_logs = {}
}

-- Reset all mock state
function X4Mock.reset()
    X4Mock.player_money = 1000000
    X4Mock.station_money = 5000000
    X4Mock.registered_events = {}
    X4Mock.menu_rows = {}
    X4Mock.active_menu = nil
    X4Mock.ui_triggers = {}
    X4Mock.debug_logs = {}
end

-- Global X4 Functions
_G.GetPlayerMoney = function()
    return X4Mock.player_money
end

_G.AddPlayerMoney = function(amount)
    X4Mock.player_money = X4Mock.player_money + amount
    return X4Mock.player_money
end

_G.GetStationMoney = function()
    return X4Mock.station_money
end

_G.AddStationMoney = function(amount)
    X4Mock.station_money = X4Mock.station_money + amount
    return X4Mock.station_money
end

_G.DebugError = function(msg)
    table.insert(X4Mock.debug_logs, { level = "ERROR", msg = tostring(msg) })
end

_G.AddUITrigger = function(screen, control, action, param)
    table.insert(X4Mock.ui_triggers, {
        screen = screen,
        control = control,
        action = action,
        param = param
    })
end

_G.RegisterEvent = function(event_name, callback)
    X4Mock.registered_events[event_name] = callback
end

-- Mock Helper library
_G.Helper = {
    createTable = function(descriptor)
        return { descriptor = descriptor, rows = {} }
    end,
    ffiToString = function(c_str)
        return tostring(c_str)
    end
}

-- Mock C / FFI table
_G.C = {}
_G.ffi = {
    string = function(s) return tostring(s) end
}

-- Mock Menu table
_G.Menus = _G.Menus or {}

return X4Mock
