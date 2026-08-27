--[[
    Unit Test Suite for Game Registry & Dispatcher
    Tests pure Lua 5.1 game registry, catalog retrieval, filtering, and validation.
--]]

-- Add package paths for local modules and test runner
package.path = "lua/?.lua;lua/?/init.lua;tests/lua/?.lua;" .. package.path

local luaunit = require("luaunit")
local GameRegistry = require("casino_core.game_registry")

local TestGameRegistry = {}

function TestGameRegistry:setUp()
    self.registry = GameRegistry.new()
end

function TestGameRegistry:test_default_catalog_initialization()
    local all_games = self.registry:get_all_games()
    luaunit.assertTrue(#all_games >= 3, "Default catalog should have at least 3 games")

    local slots = self.registry:get_game("slots_teladi_profit_spinner")
    luaunit.assertNotNil(slots)
    luaunit.assertEquals(slots.name, "Teladi Profit Spinner")
    luaunit.assertEquals(slots.category, "slots")
    luaunit.assertEquals(slots.status, "active")
    luaunit.assertEquals(slots.min_bet, 1000)
    luaunit.assertEquals(slots.max_bet, 100000)
    luaunit.assertEquals(slots.default_bet, 5000)
    luaunit.assertEquals(slots.ui_menu_id, "x4_casino_slots_menu")
    luaunit.assertEquals(slots.open_cue, "md.CasinoStationCues.Open_Slots_Direct")

    local blackjack = self.registry:get_game("blackjack_21")
    luaunit.assertNotNil(blackjack)
    luaunit.assertEquals(blackjack.category, "cards")
    luaunit.assertEquals(blackjack.status, "coming_soon")

    local roulette = self.registry:get_game("roulette_orbital")
    luaunit.assertNotNil(roulette)
    luaunit.assertEquals(roulette.category, "roulette")
    luaunit.assertEquals(roulette.status, "coming_soon")
end

function TestGameRegistry:test_get_game_missing()
    local game = self.registry:get_game("non_existent_game")
    luaunit.assertNil(game)
end

function TestGameRegistry:test_register_custom_game()
    local custom_game = {
        id = "dice_craps_nebula",
        name = "Nebula Craps",
        category = "dice",
        tagline = "Classic Station Craps & Dice Table",
        min_bet = 500,
        max_bet = 50000,
        default_bet = 2500,
        status = "active",
        ui_menu_id = "x4_casino_craps_menu",
        open_cue = "md.CasinoStationCues.Open_Craps_Direct"
    }

    local success = self.registry:register_game(custom_game)
    luaunit.assertTrue(success)

    local retrieved = self.registry:get_game("dice_craps_nebula")
    luaunit.assertNotNil(retrieved)
    luaunit.assertEquals(retrieved.name, "Nebula Craps")
    luaunit.assertEquals(retrieved.category, "dice")
end

function TestGameRegistry:test_register_invalid_game_errors()
    -- Missing ID
    luaunit.assertError(function()
        self.registry:register_game({ name = "No ID Game", category = "slots", min_bet = 100, max_bet = 1000 })
    end)

    -- Missing Name
    luaunit.assertError(function()
        self.registry:register_game({ id = "no_name", category = "slots", min_bet = 100, max_bet = 1000 })
    end)

    -- Missing Category
    luaunit.assertError(function()
        self.registry:register_game({ id = "no_cat", name = "No Category", min_bet = 100, max_bet = 1000 })
    end)

    -- Invalid Bet Ranges (min_bet > max_bet)
    luaunit.assertError(function()
        self.registry:register_game({
            id = "bad_bets",
            name = "Bad Bets Game",
            category = "slots",
            min_bet = 5000,
            max_bet = 1000,
            default_bet = 2000
        })
    end)

    -- Negative Bet
    luaunit.assertError(function()
        self.registry:register_game({
            id = "negative_bet",
            name = "Negative Bet Game",
            category = "slots",
            min_bet = -100,
            max_bet = 1000
        })
    end)
end

function TestGameRegistry:test_unregister_game()
    local unreg_success = self.registry:unregister_game("roulette_orbital")
    luaunit.assertTrue(unreg_success)
    luaunit.assertNil(self.registry:get_game("roulette_orbital"))

    -- Unregistering again returns false
    local unreg_again = self.registry:unregister_game("roulette_orbital")
    luaunit.assertFalse(unreg_again)
end

function TestGameRegistry:test_get_active_games()
    local active = self.registry:get_active_games()
    luaunit.assertTrue(#active >= 1)
    for _, game in ipairs(active) do
        luaunit.assertEquals(game.status, "active")
    end
end

function TestGameRegistry:test_get_games_by_category()
    local slots_games = self.registry:get_games_by_category("slots")
    luaunit.assertEquals(#slots_games, 1)
    luaunit.assertEquals(slots_games[1].id, "slots_teladi_profit_spinner")

    local cards_games = self.registry:get_games_by_category("cards")
    luaunit.assertEquals(#cards_games, 1)
    luaunit.assertEquals(cards_games[1].id, "blackjack_21")

    local empty_games = self.registry:get_games_by_category("unknown_category")
    luaunit.assertEquals(#empty_games, 0)
end

function TestGameRegistry:test_set_game_status()
    local game = self.registry:get_game("blackjack_21")
    luaunit.assertEquals(game.status, "coming_soon")

    local updated = self.registry:set_game_status("blackjack_21", "active")
    luaunit.assertTrue(updated)
    luaunit.assertEquals(self.registry:get_game("blackjack_21").status, "active")

    local active = self.registry:get_active_games()
    local found = false
    for _, g in ipairs(active) do
        if g.id == "blackjack_21" then
            found = true
            break
        end
    end
    luaunit.assertTrue(found, "blackjack_21 should now appear in active games")

    -- Invalid status
    luaunit.assertError(function()
        self.registry:set_game_status("blackjack_21", "invalid_status")
    end)

    -- Non-existent game
    local false_update = self.registry:set_game_status("non_existent", "active")
    luaunit.assertFalse(false_update)
end

function TestGameRegistry:test_get_categories()
    local categories = self.registry:get_categories()
    luaunit.assertNotNil(categories)
    luaunit.assertTrue(#categories >= 3)

    local set = {}
    for _, cat in ipairs(categories) do
        set[cat] = true
    end
    luaunit.assertTrue(set["slots"])
    luaunit.assertTrue(set["cards"])
    luaunit.assertTrue(set["roulette"])
end

_G.TestGameRegistry = TestGameRegistry

local runner = luaunit.LuaUnit.new()
os.exit(runner:runSuite())
