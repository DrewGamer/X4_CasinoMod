--[[
    Unit Test Suite for 3-Reel Slots Engine (Teladi Profit Spinner)
    Tests pure Lua 5.1 game rules, paytables, PRNG determinism, and betting math.
--]]

-- Add package paths for local modules and test runner
package.path = "lua/?.lua;lua/?/init.lua;tests/lua/?.lua;" .. package.path

local luaunit = require("luaunit")
local Slots = require("casino_core.slots")

local TestSlots = {}

function TestSlots:setUp()
    self.slots = Slots.new()
end

function TestSlots:test_symbols_definition()
    local symbols = self.slots:get_symbols()
    luaunit.assertNotNil(symbols)
    luaunit.assertEquals(#symbols, 5)
    luaunit.assertEquals(symbols[1], "teladi_profit")
    luaunit.assertEquals(symbols[2], "nividium")
    luaunit.assertEquals(symbols[3], "silicon")
    luaunit.assertEquals(symbols[4], "ore")
    luaunit.assertEquals(symbols[5], "energy_cells")
end

function TestSlots:test_reel_strips_initialization()
    local reels = self.slots:get_reels()
    luaunit.assertEquals(#reels, 3)
    for i = 1, 3 do
        luaunit.assertTrue(#reels[i] >= 10, "Each reel strip should have at least 10 stops")
    end
end

function TestSlots:test_deterministic_spin_with_seed()
    local outcome1 = self.slots:spin(42)
    local outcome2 = self.slots:spin(42)

    luaunit.assertEquals(#outcome1, 3)
    luaunit.assertEquals(#outcome2, 3)
    luaunit.assertEquals(outcome1[1], outcome2[1])
    luaunit.assertEquals(outcome1[2], outcome2[2])
    luaunit.assertEquals(outcome1[3], outcome2[3])
end

function TestSlots:test_paytable_jackpot_three_teladi_profit()
    local outcome = { "teladi_profit", "teladi_profit", "teladi_profit" }
    local multiplier, win_type = self.slots:evaluate_outcome(outcome)
    luaunit.assertEquals(multiplier, 50)
    luaunit.assertEquals(win_type, "JACKPOT")
end

function TestSlots:test_paytable_major_win_three_nividium()
    local outcome = { "nividium", "nividium", "nividium" }
    local multiplier, win_type = self.slots:evaluate_outcome(outcome)
    luaunit.assertEquals(multiplier, 20)
    luaunit.assertEquals(win_type, "MAJOR_WIN")
end

function TestSlots:test_paytable_medium_win_three_silicon()
    local outcome = { "silicon", "silicon", "silicon" }
    local multiplier, win_type = self.slots:evaluate_outcome(outcome)
    luaunit.assertEquals(multiplier, 10)
    luaunit.assertEquals(win_type, "MEDIUM_WIN")
end

function TestSlots:test_paytable_medium_win_three_ore()
    local outcome = { "ore", "ore", "ore" }
    local multiplier, win_type = self.slots:evaluate_outcome(outcome)
    luaunit.assertEquals(multiplier, 10)
    luaunit.assertEquals(win_type, "MEDIUM_WIN")
end

function TestSlots:test_paytable_minor_win_three_energy_cells()
    local outcome = { "energy_cells", "energy_cells", "energy_cells" }
    local multiplier, win_type = self.slots:evaluate_outcome(outcome)
    luaunit.assertEquals(multiplier, 5)
    luaunit.assertEquals(win_type, "ENERGY_BOOST")
end

function TestSlots:test_paytable_two_matching_symbols()
    -- 2x matching on left
    local mult1, type1 = self.slots:evaluate_outcome({ "teladi_profit", "teladi_profit", "ore" })
    luaunit.assertEquals(mult1, 2)
    luaunit.assertEquals(type1, "PAIR_MATCH")

    -- 2x matching on right
    local mult2, type2 = self.slots:evaluate_outcome({ "energy_cells", "nividium", "nividium" })
    luaunit.assertEquals(mult2, 2)
    luaunit.assertEquals(type2, "PAIR_MATCH")

    -- 2x matching split
    local mult3, type3 = self.slots:evaluate_outcome({ "silicon", "ore", "silicon" })
    luaunit.assertEquals(mult3, 2)
    luaunit.assertEquals(type3, "PAIR_MATCH")
end

function TestSlots:test_paytable_loss_no_matching_symbols()
    local outcome = { "teladi_profit", "nividium", "ore" }
    local multiplier, win_type = self.slots:evaluate_outcome(outcome)
    luaunit.assertEquals(multiplier, 0)
    luaunit.assertEquals(win_type, "LOSS")
end

function TestSlots:test_place_bet_calculation()
    local bet_amount = 5000
    local result = self.slots:play_round(bet_amount, 12345)
    luaunit.assertNotNil(result)
    luaunit.assertEquals(result.bet, bet_amount)
    luaunit.assertEquals(#result.reels, 3)
    luaunit.assertNotNil(result.multiplier)
    luaunit.assertEquals(result.payout, bet_amount * result.multiplier)
    luaunit.assertEquals(result.net_profit, result.payout - bet_amount)
end

function TestSlots:test_invalid_bet_amount_rejection()
    luaunit.assertError(function() self.slots:play_round(0) end)
    luaunit.assertError(function() self.slots:play_round(-100) end)
    luaunit.assertError(function() self.slots:play_round("invalid") end)
end

_G.TestSlots = TestSlots

local runner = luaunit.LuaUnit.new()
os.exit(runner:runSuite())
