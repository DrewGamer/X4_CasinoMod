--[[
    Slots UI Menu Adapter (SirNukes Simple Menu / X4 UI Integration)
    Connects the pure Lua 3-Reel Slots engine to X4 in-game menus, player credits,
    station closed-loop economy, solvency validation, and Owner Free-Play.
--]]

local Slots = require("casino_core.slots")

local SlotsMenu = {}
SlotsMenu.__index = SlotsMenu

-- Default bet tiers in Credits
local BET_TIERS = { 1000, 5000, 25000, 100000 }
local MAX_JACKPOT_MULTIPLIER = 50

local SYMBOL_NAMES = {
    teladi_profit = "Teladi Profit",
    nividium      = "Nividium",
    silicon       = "Silicon",
    ore           = "Ore",
    energy_cells  = "Energy Cells"
}

local SYMBOL_BOX_NAMES = {
    teladi_profit = "[ PROFIT! ]",
    nividium      = "[ NIVIDIUM]",
    silicon       = "[ SILICON ]",
    ore           = "[   ORE   ]",
    energy_cells  = "[ E-CELLS ]"
}

--- Create a new SlotsMenu adapter
-- @param engine Optional Slots domain engine instance
-- @return SlotsMenu object
function SlotsMenu.new(engine)
    local self = setmetatable({}, SlotsMenu)
    self.engine = engine or Slots.new()
    self.bet_amount = 5000
    self.is_open = false
    self.demo_mode = false
    self.last_round = nil
    self.status_message = "Select your bet and press SPIN to play!"
    self.stats = {
        total_spins = 0,
        total_wagered = 0,
        total_won = 0,
        jackpots_hit = 0
    }
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

--- Toggle Owner Free-Play / Demo Mode
-- @param enabled Boolean flag
function SlotsMenu:set_demo_mode(enabled)
    self.demo_mode = not not enabled
    if self.demo_mode then
        self.status_message = "[DEMO MODE ENABLED] Free spins active. No credits deducted or awarded."
    else
        self.status_message = "Demo mode disabled. Playing with live Credits."
    end
end

--- Check if the station treasury can back the maximum jackpot for the current bet
-- @param station_money Integer station credits
-- @return boolean solvent, integer required_reserve
function SlotsMenu:check_station_solvency(station_money)
    local required_reserve = self.bet_amount * MAX_JACKPOT_MULTIPLIER
    local current_station = station_money or 0
    return (current_station >= required_reserve), required_reserve
end

--- Execute a spin
-- @param seed Optional seed for deterministic execution
-- @param station_context Optional table describing host station { is_player_owned, station_id, ledger }
-- @return round table on success, or (false, error_reason) on failure
function SlotsMenu:spin(seed, station_context)
    if self.demo_mode then
        local round = self.engine:play_round(self.bet_amount, seed)
        round.demo = true
        self.last_round = round
        self.stats.total_spins = self.stats.total_spins + 1

        if round.multiplier >= 50 then
            self.status_message = string.format("[DEMO] *** JACKPOT! Simulated win: %d Cr! (50x) ***", round.payout)
        elseif round.multiplier > 0 then
            self.status_message = string.format(
                "[DEMO] Win! Simulated win: %d Cr! (%dx)", round.payout, round.multiplier)
        else
            self.status_message = "[DEMO] No match. Teladi keeps profitsss!"
        end
        return round
    end

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

    -- Closed-loop transfer to station treasury if player-owned station
    if station_context and station_context.is_player_owned and _G.AddStationMoney then
        _G.AddStationMoney(self.bet_amount)
    end

    -- Update station ledger gross revenue
    if station_context and station_context.ledger then
        local ledger = station_context.ledger
        ledger.house_gross_revenue = (ledger.house_gross_revenue or 0) + self.bet_amount
    end

    -- Run domain spin
    local round = self.engine:play_round(self.bet_amount, seed)
    self.last_round = round
    self.stats.total_spins = self.stats.total_spins + 1
    self.stats.total_wagered = self.stats.total_wagered + self.bet_amount

    -- Calculate payout and handle station solvency / graceful drain
    local actual_payout = round.payout
    local is_drained = false

    if round.payout > 0 then
        if station_context and station_context.is_player_owned and _G.GetStationMoney then
            local station_bal = _G.GetStationMoney()
            if station_bal < round.payout then
                actual_payout = station_bal
                is_drained = true
                if _G.AddStationMoney then
                    _G.AddStationMoney(-actual_payout)
                end
            else
                if _G.AddStationMoney then
                    _G.AddStationMoney(-round.payout)
                end
            end
        end

        if _G.AddPlayerMoney then
            _G.AddPlayerMoney(actual_payout)
        end

        self.stats.total_won = self.stats.total_won + actual_payout
        if round.win_type == "JACKPOT" then
            self.stats.jackpots_hit = self.stats.jackpots_hit + 1
        end

        if station_context and station_context.ledger then
            local ledger = station_context.ledger
            ledger.house_payouts_total = (ledger.house_payouts_total or 0) + actual_payout
            ledger.house_net_income = ledger.house_gross_revenue - ledger.house_payouts_total
        end
    else
        if station_context and station_context.ledger then
            local ledger = station_context.ledger
            ledger.house_net_income = ledger.house_gross_revenue - (ledger.house_payouts_total or 0)
        end
    end

    round.actual_payout = actual_payout
    round.drained = is_drained

    -- Update UI status message
    if is_drained then
        self.status_message = string.format(
            "*** JACKPOT! Station treasury drained: Received %d Cr! (Station at 0 Cr) ***",
            actual_payout
        )
    elseif round.win_type == "JACKPOT" then
        self.status_message = string.format("*** JACKPOT! Won %d Cr! (50x) ***", actual_payout)
    elseif round.win_type == "MAJOR_WIN" then
        self.status_message = string.format("=== MAJOR WIN! Won %d Cr! (20x) ===", actual_payout)
    elseif round.win_type == "MEDIUM_WIN" then
        self.status_message = string.format("[+] Medium Win! Won %d Cr! (10x) [+]", actual_payout)
    elseif round.win_type == "ENERGY_BOOST" then
        self.status_message = string.format("[+] Energy Boost! Won %d Cr! (5x) [+]", actual_payout)
    elseif round.win_type == "PAIR_MATCH" then
        self.status_message = string.format("[+] Pair Match! Won %d Cr! (2x)", actual_payout)
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
        { type = "header", title = "TELADI PROFIT SPINNER", balance = current_money, demo = self.demo_mode },
        -- Row 2: 3-Reel Display
        { type = "reels", reel1 = r1, reel2 = r2, reel3 = r3 },
        -- Row 3: Status / Result Banner
        { type = "status", text = self.status_message },
        -- Row 4: Bet Selection
        { type = "bet_selection", current_bet = self.bet_amount, options = BET_TIERS },
        -- Row 5: Action Controls
        { type = "actions", can_spin = self.demo_mode or (current_money >= self.bet_amount) }
    }

    return {
        id = "x4_casino_slots_menu",
        title = "Teladi Profit Spinner",
        rows = rows
    }
end

--- Generate live widget update payload for SirNukes Simple Menu API (Update_Widget)
-- @param state Optional table overriding or providing state
-- @return Map of widget update tables keyed by widget id
function SlotsMenu:get_widget_updates(state)
    state = state or {}
    local current_money = state.player_money
    if current_money == nil and _G.GetPlayerMoney then
        current_money = _G.GetPlayerMoney()
    end
    current_money = current_money or 0

    local bet = state.bet_amount or self.bet_amount
    local is_demo = state.demo_mode
    if is_demo == nil then
        is_demo = self.demo_mode
    end

    local status_msg = state.status_message or self.status_message
    local round = state.last_round or self.last_round

    -- 1. txt_header
    local header_text = string.format(
        "TELADI PROFIT SPINNER  |  Balance: %d Cr  |  Bet: %d Cr",
        current_money,
        bet
    )

    -- 2. txt_mode_notice
    local mode_text = ""
    local mode_color = "Color.text_normal"
    if is_demo then
        mode_text = "*** DEMO MODE / OWNER FREE-PLAY ACTIVE - No Credits Exchanged ***"
        mode_color = "Color.chatuser_5"
    elseif state.is_player_owned then
        local station_money = state.station_money
        if station_money == nil and _G.GetStationMoney then
            station_money = _G.GetStationMoney()
        end
        station_money = station_money or 0
        local req_reserve = bet * MAX_JACKPOT_MULTIPLIER
        if station_money < req_reserve then
            mode_text = string.format(
                "Station Treasury Low: %d Cr (Requires %d Cr reserve for max jackpot)",
                station_money,
                req_reserve
            )
            mode_color = "Color.text_inactive"
        end
    end

    -- 3. btn_toggle_demo
    local demo_btn_text = "Live Credits Mode (Click for Owner Free-Play / Demo Mode)"
    if is_demo then
        demo_btn_text = "Free-Play Active (Click to Switch to Live Credits)"
    end

    -- 4. box_reel1, box_reel2, box_reel3
    local r1 = state.reel1
    local r2 = state.reel2
    local r3 = state.reel3
    if not r1 then
        if round and round.reels and round.reels[1] then
            r1 = SYMBOL_BOX_NAMES[round.reels[1]] or SYMBOL_NAMES[round.reels[1]] or tostring(round.reels[1])
        else
            r1 = "[ --- ]"
        end
    end
    if not r2 then
        if round and round.reels and round.reels[2] then
            r2 = SYMBOL_BOX_NAMES[round.reels[2]] or SYMBOL_NAMES[round.reels[2]] or tostring(round.reels[2])
        else
            r2 = "[ --- ]"
        end
    end
    if not r3 then
        if round and round.reels and round.reels[3] then
            r3 = SYMBOL_BOX_NAMES[round.reels[3]] or SYMBOL_NAMES[round.reels[3]] or tostring(round.reels[3])
        else
            r3 = "[ --- ]"
        end
    end

    return {
        txt_header = {
            id = "txt_header",
            text = header_text,
        },
        txt_mode_notice = {
            id = "txt_mode_notice",
            text = mode_text,
            color = mode_color,
        },
        btn_toggle_demo = {
            id = "btn_toggle_demo",
            text = {
                text = demo_btn_text,
                halign = "center",
            },
        },
        box_reel1 = {
            id = "box_reel1",
            text = r1,
        },
        box_reel2 = {
            id = "box_reel2",
            text = r2,
        },
        box_reel3 = {
            id = "box_reel3",
            text = r3,
        },
        txt_banner = {
            id = "txt_banner",
            text = status_msg,
        },
    }
end

return SlotsMenu
