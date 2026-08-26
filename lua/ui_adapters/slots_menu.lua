--[[
    Slots UI Menu Adapter (SirNukes Simple Menu / X4 UI Integration)
    Connects the pure Lua 3-Reel Slots engine to X4 in-game menus, player credits, and button handlers.
--]]

local Slots = require("casino_core.slots")

local SlotsMenu = {}
SlotsMenu.__index = SlotsMenu

-- Default bet tiers in Credits
local BET_TIERS = { 1000, 5000, 25000, 100000 }

local SYMBOL_NAMES = {
    teladi_profit = "Teladi Profit",
    nividium      = "Nividium",
    silicon       = "Silicon",
    ore           = "Ore",
    energy_cells  = "Energy Cells"
}

--- Create a new SlotsMenu adapter
-- @param engine Optional Slots domain engine instance
-- @return SlotsMenu object
function SlotsMenu.new(engine)
    local self = setmetatable({}, SlotsMenu)
    self.engine = engine or Slots.new()
    self.bet_amount = 5000
    self.is_open = false
    self.last_round = nil
    self.status_message = "Select your bet and press SPIN to play!"
    return self
end

--- Open the slot machine menu
function SlotsMenu:open()
    self.is_open = true
    self.status_message = "Ready to spin! Match 3 symbols for profitsss."
end

--- Close the slot machine menu
function SlotsMenu:close()
    self.is_open = false
end

--- Set current bet amount
-- @param amount Number of credits
function SlotsMenu:set_bet(amount)
    if type(amount) == "number" and amount > 0 then
        self.bet_amount = amount
        self.status_message = string.format("Bet set to %d Cr.", amount)
    end
end

--- Execute a spin
-- @param seed Optional seed for deterministic execution
-- @return round table on success, or (false, error_reason) on failure
function SlotsMenu:spin(seed)
    local current_money = 0
    if _G.GetPlayerMoney then
        current_money = _G.GetPlayerMoney()
    end

    if current_money < self.bet_amount then
        self.status_message = "Insufficient credits for this bet!"
        return false, "INSUFFICIENT_CREDITS"
    end

    -- Deduct bet from player
    if _G.AddPlayerMoney then
        _G.AddPlayerMoney(-self.bet_amount)
    end

    -- Run domain spin
    local round = self.engine:play_round(self.bet_amount, seed)
    self.last_round = round

    -- Award payout if won
    if round.payout > 0 and _G.AddPlayerMoney then
        _G.AddPlayerMoney(round.payout)
    end

    -- Update UI status message
    if round.win_type == "JACKPOT" then
        self.status_message = string.format("★ JACKPOT! Won %d Cr! (50x) ★", round.payout)
    elseif round.win_type == "MAJOR_WIN" then
        self.status_message = string.format("♦ MAJOR WIN! Won %d Cr! (20x) ♦", round.payout)
    elseif round.win_type == "MEDIUM_WIN" then
        self.status_message = string.format("▲ Medium Win! Won %d Cr! (10x) ▲", round.payout)
    elseif round.win_type == "ENERGY_BOOST" then
        self.status_message = string.format("⚡ Energy Boost! Won %d Cr! (5x) ⚡", round.payout)
    elseif round.win_type == "PAIR_MATCH" then
        self.status_message = string.format("✓ Pair Match! Won %d Cr! (2x)", round.payout)
    else
        self.status_message = "No match. Teladi keeps profitsss!"
    end

    return round
end

--- Generate standard UI table descriptor data for SirNukes Simple Menu API
-- @return table descriptor data
function SlotsMenu:generate_table_data()
    local current_money = 0
    if _G.GetPlayerMoney then
        current_money = _G.GetPlayerMoney()
    end

    local r1 = self.last_round and (SYMBOL_NAMES[self.last_round.reels[1]] or self.last_round.reels[1]) or "---"
    local r2 = self.last_round and (SYMBOL_NAMES[self.last_round.reels[2]] or self.last_round.reels[2]) or "---"
    local r3 = self.last_round and (SYMBOL_NAMES[self.last_round.reels[3]] or self.last_round.reels[3]) or "---"

    local rows = {
        -- Row 1: Header / Balance
        { type = "header", title = "TELADI PROFIT SPINNER", balance = current_money },
        -- Row 2: 3-Reel Display
        { type = "reels", reel1 = r1, reel2 = r2, reel3 = r3 },
        -- Row 3: Status / Result Banner
        { type = "status", text = self.status_message },
        -- Row 4: Bet Selection
        { type = "bet_selection", current_bet = self.bet_amount, options = BET_TIERS },
        -- Row 5: Action Controls
        { type = "actions", can_spin = (current_money >= self.bet_amount) }
    }

    return {
        id = "x4_casino_slots_menu",
        title = "Teladi Profit Spinner",
        rows = rows
    }
end

return SlotsMenu
