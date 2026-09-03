--[[
    Unit Test Suite for Slots UI Menu Adapter (SirNukes / X4 UI Integration)
    Tests menu state management, bet controls, credit transactions,
    station closed-loop economy, solvency validation, and Owner Free-Play.
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
    X4Mock.station_money = 2000000 -- 2,000,000 Cr
    self.engine = Slots.new()
    self.menu = SlotsMenu.new(self.engine)
end

function TestSlotsMenu:test_menu_initialization()
    luaunit.assertEquals(self.menu.bet_amount, 5000)
    luaunit.assertEquals(self.menu.is_open, false)
    luaunit.assertEquals(self.menu.demo_mode, false)
    luaunit.assertNil(self.menu.last_round)
    luaunit.assertEquals(self.menu.stats.total_spins, 0)
    luaunit.assertEquals(self.menu.stats.total_wagered, 0)
    luaunit.assertEquals(self.menu.stats.total_won, 0)
    luaunit.assertEquals(self.menu.stats.jackpots_hit, 0)
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
    luaunit.assertEquals(self.menu.stats.total_spins, 1)
    luaunit.assertEquals(self.menu.stats.total_wagered, 10000)
    luaunit.assertEquals(self.menu.stats.total_won, round.payout)
end

function TestSlotsMenu:test_spin_fails_if_insufficient_credits()
    self.menu:open()
    X4Mock.player_money = 2000 -- Player only has 2,000 Cr
    self.menu:set_bet(5000)

    local success, err = self.menu:spin()
    luaunit.assertFalse(success)
    luaunit.assertEquals(err, "INSUFFICIENT_CREDITS")
    luaunit.assertEquals(_G.GetPlayerMoney(), 2000) -- No credits deducted
    luaunit.assertEquals(self.menu.stats.total_spins, 0)
end

function TestSlotsMenu:test_demo_mode_toggle_and_spin()
    self.menu:open()
    self.menu:set_demo_mode(true)
    luaunit.assertTrue(self.menu.demo_mode)

    local start_money = _G.GetPlayerMoney()
    local round = self.menu:spin(42)
    luaunit.assertNotNil(round)
    luaunit.assertTrue(round.demo)
    -- Money must be untouched in demo mode
    luaunit.assertEquals(_G.GetPlayerMoney(), start_money)
    luaunit.assertEquals(self.menu.stats.total_spins, 1)
    -- Stats track wagered/won as 0 for real credits
    luaunit.assertEquals(self.menu.stats.total_wagered, 0)
    luaunit.assertEquals(self.menu.stats.total_won, 0)
end

function TestSlotsMenu:test_station_solvency_check()
    self.menu:set_bet(5000) -- Max jackpot is 5000 * 50 = 250,000 Cr

    -- Sufficient station funds
    local solvent, req = self.menu:check_station_solvency(300000)
    luaunit.assertTrue(solvent)
    luaunit.assertEquals(req, 250000)

    -- Insufficient station funds
    local insolvent, req2 = self.menu:check_station_solvency(100000)
    luaunit.assertFalse(insolvent)
    luaunit.assertEquals(req2, 250000)
end

function TestSlotsMenu:test_station_closed_loop_transfer_on_spin()
    self.menu:open()
    self.menu:set_bet(5000)
    local start_player = 500000
    local start_station = 2000000
    X4Mock.player_money = start_player
    X4Mock.station_money = start_station

    local station_context = {
        is_player_owned = true,
        station_id = "test_station_01",
        ledger = {
            house_gross_revenue = 0,
            house_payouts_total = 0,
            house_net_income = 0
        }
    }

    -- Spin with seed 42
    local round = self.menu:spin(42, station_context)
    luaunit.assertNotNil(round)

    local expected_player = start_player - 5000 + round.payout
    local expected_station = start_station + 5000 - round.payout

    luaunit.assertEquals(_G.GetPlayerMoney(), expected_player)
    luaunit.assertEquals(_G.GetStationMoney(), expected_station)
    luaunit.assertEquals(station_context.ledger.house_gross_revenue, 5000)
    luaunit.assertEquals(station_context.ledger.house_payouts_total, round.payout)
    luaunit.assertEquals(station_context.ledger.house_net_income, 5000 - round.payout)
end

function TestSlotsMenu:test_station_graceful_drain_when_underfunded()
    self.menu:open()
    self.menu:set_bet(5000)
    X4Mock.player_money = 500000
    X4Mock.station_money = 1000 -- Station only has 1,000 Cr after bet!

    local station_context = {
        is_player_owned = true,
        station_id = "underfunded_station",
        ledger = {
            house_gross_revenue = 0,
            house_payouts_total = 0,
            house_net_income = 0
        }
    }

    -- Mock engine to return a major win (20x = 100,000 Cr)
    local mock_engine = {
        play_round = function(_, bet)
            return {
                bet = bet,
                reels = { "nividium", "nividium", "nividium" },
                multiplier = 20,
                win_type = "MAJOR_WIN",
                payout = 100000,
                net_profit = 95000
            }
        end
    }
    local custom_menu = SlotsMenu.new(mock_engine)
    custom_menu:open()
    custom_menu:set_bet(5000)

    local round = custom_menu:spin(nil, station_context)
    luaunit.assertNotNil(round)
    -- Station had 1,000 + 5,000 (bet) = 6,000 Cr available.
    -- Graceful drain: station pays full remaining balance of 6,000 Cr and drains to 0 Cr.
    luaunit.assertEquals(_G.GetStationMoney(), 0)
    luaunit.assertEquals(_G.GetPlayerMoney(), 500000 - 5000 + 6000)
    luaunit.assertTrue(round.drained)
end

function TestSlotsMenu:test_render_table_structure()
    self.menu:open()
    local table_data = self.menu:generate_table_data()
    luaunit.assertNotNil(table_data)
    luaunit.assertNotNil(table_data.title)
    luaunit.assertNotNil(table_data.rows)
    luaunit.assertTrue(#table_data.rows >= 4, "Menu table should contain at least 4 rows")
end

function TestSlotsMenu:test_widget_updates_on_bet_change()
    self.menu:open()
    self.menu:set_bet(25000)
    local updates = self.menu:get_widget_updates()
    luaunit.assertNotNil(updates)
    luaunit.assertNotNil(updates.txt_header)
    luaunit.assertEquals(updates.txt_header.id, "txt_header")
    luaunit.assertTrue(string.find(updates.txt_header.text, "25000 Cr") ~= nil)
    luaunit.assertTrue(string.find(updates.txt_header.text, "500000 Cr") ~= nil)
    luaunit.assertNotNil(updates.txt_banner)
    luaunit.assertEquals(updates.txt_banner.id, "txt_banner")
    luaunit.assertTrue(string.find(updates.txt_banner.text, "25000") ~= nil)
end

function TestSlotsMenu:test_widget_updates_on_demo_toggle()
    self.menu:open()
    self.menu:set_demo_mode(true)
    local updates = self.menu:get_widget_updates()
    luaunit.assertNotNil(updates)
    luaunit.assertNotNil(updates.txt_mode_notice)
    luaunit.assertEquals(updates.txt_mode_notice.id, "txt_mode_notice")
    luaunit.assertTrue(string.find(updates.txt_mode_notice.text, "DEMO MODE") ~= nil)
    luaunit.assertEquals(updates.txt_mode_notice.color, "Color.chatuser_5")
    luaunit.assertNotNil(updates.btn_toggle_demo)
    luaunit.assertEquals(updates.btn_toggle_demo.id, "btn_toggle_demo")
    luaunit.assertEquals(updates.btn_toggle_demo.text.text, "Free-Play Active (Click to Switch to Live Credits)")
    luaunit.assertEquals(updates.btn_toggle_demo.text.halign, "center")

    -- Toggle back off to live credits
    self.menu:set_demo_mode(false)
    local updates2 = self.menu:get_widget_updates()
    luaunit.assertEquals(updates2.txt_mode_notice.text, "")
    luaunit.assertEquals(
        updates2.btn_toggle_demo.text.text,
        "Live Credits Mode (Click for Owner Free-Play / Demo Mode)"
    )
end

function TestSlotsMenu:test_widget_updates_on_spin()
    self.menu:open()
    self.menu:set_bet(10000)
    local round = self.menu:spin(42)
    luaunit.assertNotNil(round)

    local updates = self.menu:get_widget_updates()
    luaunit.assertNotNil(updates)
    luaunit.assertNotNil(updates.box_reel1)
    luaunit.assertEquals(updates.box_reel1.id, "box_reel1")
    luaunit.assertNotEquals(updates.box_reel1.text, "[ --- ]")

    luaunit.assertNotNil(updates.box_reel2)
    luaunit.assertEquals(updates.box_reel2.id, "box_reel2")
    luaunit.assertNotEquals(updates.box_reel2.text, "[ --- ]")

    luaunit.assertNotNil(updates.box_reel3)
    luaunit.assertEquals(updates.box_reel3.id, "box_reel3")
    luaunit.assertNotEquals(updates.box_reel3.text, "[ --- ]")

    luaunit.assertNotNil(updates.txt_banner)
    luaunit.assertEquals(updates.txt_banner.id, "txt_banner")
    luaunit.assertEquals(updates.txt_banner.text, self.menu.status_message)

    -- Header should reflect new player balance after spin
    local current_money = _G.GetPlayerMoney()
    luaunit.assertTrue(string.find(updates.txt_header.text, tostring(current_money)) ~= nil)
end

function TestSlotsMenu:test_widget_contract_id_conformance()
    local expected_ids = {
        "txt_header",
        "txt_mode_notice",
        "btn_toggle_demo",
        "box_reel1",
        "box_reel2",
        "box_reel3",
        "txt_banner"
    }

    local updates = self.menu:get_widget_updates()
    for _, id in ipairs(expected_ids) do
        luaunit.assertNotNil(updates[id], "Missing widget update key: " .. id)
        luaunit.assertEquals(updates[id].id, id, "Widget update id property mismatch for: " .. id)
    end

    -- Verify all contract IDs are defined in md/CasinoStationCues.xml
    local f = io.open("md/CasinoStationCues.xml", "r")
    luaunit.assertNotNil(f, "Could not open md/CasinoStationCues.xml")
    local content = f:read("*all")
    f:close()

    for _, id in ipairs(expected_ids) do
        local needle = "$id%s*=%s*'" .. id .. "'"
        local found = string.find(content, needle) ~= nil
        luaunit.assertTrue(found, "Contract ID not found in XML: " .. id)
    end

    -- Also verify Update_Slots_UI helper cue exists in XML
    luaunit.assertTrue(
        string.find(content, 'cue name="Update_Slots_UI"') ~= nil,
        "Update_Slots_UI cue missing from XML"
    )
end

_G.TestSlotsMenu = TestSlotsMenu

local runner = luaunit.LuaUnit.new()
os.exit(runner:runSuite())

