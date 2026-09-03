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

function TestGameRegistry.test_migrate_casino_data_nil_or_empty()
    local migrated_nil = GameRegistry.migrate_casino_data(nil)
    luaunit.assertNotNil(migrated_nil)
    luaunit.assertEquals(migrated_nil["$CurrentBet"], 5000)
    luaunit.assertEquals(migrated_nil["$Reel1"], "[ PROFIT! ]")
    luaunit.assertEquals(migrated_nil["$Reel2"], "[ PROFIT! ]")
    luaunit.assertEquals(migrated_nil["$Reel3"], "[ PROFIT! ]")
    luaunit.assertEquals(migrated_nil["$ResultBanner"], "Match 3 symbols for profitsss!")
    luaunit.assertEquals(migrated_nil["$TotalSpins"], 0)
    luaunit.assertEquals(migrated_nil["$TotalWagered"], 0)
    luaunit.assertEquals(migrated_nil["$TotalWon"], 0)
    luaunit.assertEquals(migrated_nil["$NetProfit"], 0)
    luaunit.assertEquals(migrated_nil["$JackpotsHit"], 0)
    luaunit.assertEquals(migrated_nil["$DemoMode"], 0)

    local migrated_empty = GameRegistry.migrate_casino_data({})
    luaunit.assertEquals(migrated_empty["$CurrentBet"], 5000)
    luaunit.assertEquals(migrated_empty["$JackpotsHit"], 0)
end

function TestGameRegistry.test_migrate_casino_data_legacy_missing_jackpots_preserves_existing()
    local legacy = {
        ["$CurrentBet"] = 25000,
        ["$TotalSpins"] = 42,
        ["$TotalWagered"] = 1050000,
        ["$TotalWon"] = 800000,
        ["$NetProfit"] = -250000,
    }

    local result = GameRegistry.migrate_casino_data(legacy)
    luaunit.assertEquals(result["$CurrentBet"], 25000, "Existing CurrentBet must be preserved")
    luaunit.assertEquals(result["$TotalSpins"], 42, "Existing TotalSpins must be preserved")
    luaunit.assertEquals(result["$TotalWagered"], 1050000, "Existing TotalWagered must be preserved")
    luaunit.assertEquals(result["$TotalWon"], 800000, "Existing TotalWon must be preserved")
    luaunit.assertEquals(result["$NetProfit"], -250000, "Existing NetProfit must be preserved")
    luaunit.assertEquals(result["$JackpotsHit"], 0, "Missing JackpotsHit must default to 0")
    luaunit.assertEquals(result["$DemoMode"], 0, "Missing DemoMode must default to 0")
    luaunit.assertEquals(result["$Reel1"], "[ PROFIT! ]", "Missing Reel1 must default to [ PROFIT! ]")
    luaunit.assertEquals(result["$ResultBanner"], "Match 3 symbols for profitsss!")
end

function TestGameRegistry.test_migrate_casino_data_preserves_existing_jackpots()
    local existing = {
        ["$JackpotsHit"] = 7,
        ["$TotalSpins"] = 100,
        ["$DemoMode"] = 1,
    }

    local result = GameRegistry.migrate_casino_data(existing)
    luaunit.assertEquals(result["$JackpotsHit"], 7, "Existing JackpotsHit count of 7 must not be overwritten")
    luaunit.assertEquals(result["$DemoMode"], 1, "Existing DemoMode of 1 must not be overwritten")
    luaunit.assertEquals(result["$TotalSpins"], 100, "Existing TotalSpins of 100 must not be overwritten")
    luaunit.assertEquals(result["$TotalWagered"], 0, "Missing TotalWagered must default to 0")
end

function TestGameRegistry.test_xml_contract_savegame_schema_defense_jackpotshit()
    local f = io.open("md/CasinoStationCues.xml", "r")
    luaunit.assertNotNil(f, "md/CasinoStationCues.xml should exist and be readable")
    local content = f:read("*a")
    f:close()

    -- 1. Must check not player.entity.$casino_data.$JackpotsHit?
    luaunit.assertTrue(
        content:find("not player.entity.$casino_data.$JackpotsHit?", 1, true) ~= nil,
        "md/CasinoStationCues.xml must defensively check 'not player.entity.$casino_data.$JackpotsHit?'"
    )

    -- 2. Must guard string construction against missing JackpotsHit in Build_Lobby_Menu
    local has_guard = (content:find("player.entity.$casino_data.$JackpotsHit?", 1, true) ~= nil)
        or (content:find("$data.$JackpotsHit?", 1, true) ~= nil)
    luaunit.assertTrue(
        has_guard,
        "md/CasinoStationCues.xml must guard $JackpotsHit in Build_Lobby_Menu or statistics display"
    )
end

_G.TestGameRegistry = TestGameRegistry

local runner = luaunit.LuaUnit.new()
os.exit(runner:runSuite())
