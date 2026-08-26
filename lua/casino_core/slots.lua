--[[
    3-Reel Slots Core Engine (Teladi Profit Spinner)
    Pure Lua 5.1 domain logic for X4 Foundations Casino Mod.
    Zero engine dependencies for 100% headless testability.
--]]

local Slots = {}
Slots.__index = Slots

-- Standard casino symbols
local SYMBOLS = {
    "teladi_profit",
    "nividium",
    "silicon",
    "ore",
    "energy_cells"
}

-- Default 3-Reel strips with calibrated stops for realistic odds
local DEFAULT_REEL_STRIPS = {
    -- Reel 1
    {
        "energy_cells", "ore", "energy_cells", "silicon", "energy_cells",
        "ore", "nividium", "energy_cells", "silicon", "teladi_profit",
        "energy_cells", "ore"
    },
    -- Reel 2
    {
        "energy_cells", "silicon", "energy_cells", "ore", "energy_cells",
        "nividium", "energy_cells", "silicon", "ore", "teladi_profit",
        "energy_cells", "silicon"
    },
    -- Reel 3
    {
        "energy_cells", "ore", "energy_cells", "silicon", "energy_cells",
        "ore", "nividium", "energy_cells", "teladi_profit", "energy_cells",
        "silicon", "ore"
    }
}

--- Create a new Slots game instance
-- @param custom_reels Optional custom reel strips table
-- @return Slots object
function Slots.new(custom_reels)
    local self = setmetatable({}, Slots)
    self.reels = custom_reels or DEFAULT_REEL_STRIPS
    self.symbols = SYMBOLS
    return self
end

--- Get all available symbols
-- @return Array of symbol strings
function Slots:get_symbols()
    return self.symbols
end

--- Get all reel strips
-- @return Array of 3 reel strip arrays
function Slots:get_reels()
    return self.reels
end

--- Spin the 3 reels and return the resulting symbol combination
-- @param seed Optional integer seed for deterministic testing
-- @return Array of 3 symbol strings { sym1, sym2, sym3 }
function Slots:spin(seed)
    if seed then
        math.randomseed(seed)
    end

    local outcome = {}
    for i = 1, 3 do
        local strip = self.reels[i]
        local stop_idx = math.random(1, #strip)
        outcome[i] = strip[stop_idx]
    end

    return outcome
end

--- Evaluate a 3-reel outcome against the paytable
-- @param outcome Array of 3 symbol strings { sym1, sym2, sym3 }
-- @return multiplier (number), win_type (string)
function Slots:evaluate_outcome(outcome)
    local _ = self
    local s1, s2, s3 = outcome[1], outcome[2], outcome[3]

    -- 3-of-a-kind (Jackpot / Major / Medium / Energy Boost)
    if s1 == s2 and s2 == s3 then
        if s1 == "teladi_profit" then
            return 50, "JACKPOT"
        elseif s1 == "nividium" then
            return 20, "MAJOR_WIN"
        elseif s1 == "silicon" or s1 == "ore" then
            return 10, "MEDIUM_WIN"
        elseif s1 == "energy_cells" then
            return 5, "ENERGY_BOOST"
        end
    end

    -- 2-of-a-kind (Pair match)
    if s1 == s2 or s2 == s3 or s1 == s3 then
        return 2, "PAIR_MATCH"
    end

    -- No match
    return 0, "LOSS"
end

--- Play a full betting round
-- @param bet_amount Integer bet in Credits (must be > 0)
-- @param seed Optional seed for deterministic execution
-- @return Round result table
function Slots:play_round(bet_amount, seed)
    if type(bet_amount) ~= "number" or bet_amount <= 0 then
        error("Invalid bet amount: must be a positive number")
    end

    local outcome = self:spin(seed)
    local multiplier, win_type = self:evaluate_outcome(outcome)
    local payout = math.floor(bet_amount * multiplier)
    local net_profit = payout - bet_amount

    return {
        bet = bet_amount,
        reels = outcome,
        multiplier = multiplier,
        win_type = win_type,
        payout = payout,
        net_profit = net_profit
    }
end

return Slots
