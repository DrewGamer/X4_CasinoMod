--[[
    Unit Test Suite for Slots UI Menu Adapter (SirNukes / X4 UI Integration)
    Tests menu state management, bet controls, credit transactions, and UI table rendering.
--]]

package.path = "lua/?.lua;lua/?/init.lua;tests/lua/?.lua;tests/mocks/?.lua;" .. package.path

local luaunit = require("luaunit")
local X4Mock = require("x4_engine_mock")
local Slots = require("casino_core.slots")
local SlotsMenu = require("ui_adapters.slots_menu")

local TestSlotsMenu = {}

function TestSlotsMenu:setUp()
    X4Mock.reset()
    X4Mock.player_money = 500000 -- 500,000 Cr
    self.engine = Slots.new()
    self.menu = SlotsMenu.new(self.engine)
end

function TestSlotsMenu:test_menu_initialization()
    luaunit.assertEquals(self.menu.bet_amount, 5000)
    luaunit.assertEquals(self.menu.is_open, false)
    luaunit.assertNil(self.menu.last_round)
end

function TestSlotsMenu:test_menu_open_and_close()
    self.menu:open()
    luaunit.assertEquals(self.menu.is_open, true)
    self.menu:close()
    luaunit.assertEquals(self.menu.is_open, false)
end

function TestSlotsMenu:test_set_bet_amount()
    self.menu:set_bet(25000)
    luaunit.assertEquals(self.menu.bet_amount, 25000)

    self.menu:set_bet(1000)
    luaunit.assertEquals(self.menu.bet_amount, 1000)
end

function TestSlotsMenu:test_spin_deducts_bet_and_credits_payout()
    self.menu:open()
    self.menu:set_bet(10000)
    local start_money = _G.GetPlayerMoney()
    luaunit.assertEquals(start_money, 500000)

    -- Deterministic spin with seed 42
    local round = self.menu:spin(42)
    luaunit.assertNotNil(round)
    luaunit.assertEquals(round.bet, 10000)
    local expected_money = start_money - 10000 + round.payout
    luaunit.assertEquals(_G.GetPlayerMoney(), expected_money)
    luaunit.assertEquals(self.menu.last_round, round)
end

function TestSlotsMenu:test_spin_fails_if_insufficient_credits()
    self.menu:open()
    X4Mock.player_money = 2000 -- Player only has 2,000 Cr
    self.menu:set_bet(5000)

    local success, err = self.menu:spin()
    luaunit.assertFalse(success)
    luaunit.assertEquals(err, "INSUFFICIENT_CREDITS")
    luaunit.assertEquals(_G.GetPlayerMoney(), 2000) -- No credits deducted
end

function TestSlotsMenu:test_render_table_structure()
    self.menu:open()
    local table_data = self.menu:generate_table_data()
    luaunit.assertNotNil(table_data)
    luaunit.assertNotNil(table_data.title)
    luaunit.assertNotNil(table_data.rows)
    luaunit.assertTrue(#table_data.rows >= 4, "Menu table should contain at least 4 rows")
end

_G.TestSlotsMenu = TestSlotsMenu

local runner = luaunit.LuaUnit.new()
os.exit(runner:runSuite())
