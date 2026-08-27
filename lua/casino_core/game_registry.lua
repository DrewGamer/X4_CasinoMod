--[[
    Casino Game Registry & Dispatcher
    Pure Lua 5.1 catalog and dispatcher for X4 Casino Mod mini-games.
    Supports registering, querying, and filtering active/upcoming games.
--]]

local GameRegistry = {}
GameRegistry.__index = GameRegistry

local VALID_STATUSES = {
    active = true,
    maintenance = true,
    coming_soon = true
}

local DEFAULT_GAMES = {
    {
        id = "slots_teladi_profit_spinner",
        name = "Teladi Profit Spinner",
        category = "slots",
        tagline = "3-Reel Classic Fruit/Ore Slot Machine",
        min_bet = 1000,
        max_bet = 100000,
        default_bet = 5000,
        status = "active",
        ui_menu_id = "x4_casino_slots_menu",
        open_cue = "md.CasinoStationCues.Open_Slots_Direct"
    },
    {
        id = "blackjack_21",
        name = "Space 21 Blackjack",
        category = "cards",
        tagline = "Single-Deck Dealer Blackjack (Pays 3:2)",
        min_bet = 5000,
        max_bet = 500000,
        default_bet = 10000,
        status = "coming_soon",
        ui_menu_id = "x4_casino_blackjack_menu",
        open_cue = "md.CasinoStationCues.Open_Blackjack_Direct"
    },
    {
        id = "roulette_orbital",
        name = "Orbital Roulette",
        category = "roulette",
        tagline = "European Single-Zero High-Roller Wheel",
        min_bet = 2500,
        max_bet = 1000000,
        default_bet = 25000,
        status = "coming_soon",
        ui_menu_id = "x4_casino_roulette_menu",
        open_cue = "md.CasinoStationCues.Open_Roulette_Direct"
    }
}

--- Create a new GameRegistry instance
-- @param initial_games Optional list of game definition tables
-- @return GameRegistry object
function GameRegistry.new(initial_games)
    local self = setmetatable({}, GameRegistry)
    self.games = {}
    self.order = {}

    local games_to_load = initial_games or DEFAULT_GAMES
    for _, game_def in ipairs(games_to_load) do
        self:register_game(game_def)
    end

    return self
end

--- Validate and register a game definition
-- @param game_def Table containing game metadata
-- @return boolean true on success
function GameRegistry:register_game(game_def)
    if type(game_def) ~= "table" then
        error("Game definition must be a table")
    end
    if type(game_def.id) ~= "string" or game_def.id == "" then
        error("Game id is required and must be a non-empty string")
    end
    if type(game_def.name) ~= "string" or game_def.name == "" then
        error("Game name is required and must be a non-empty string")
    end
    if type(game_def.category) ~= "string" or game_def.category == "" then
        error("Game category is required and must be a non-empty string")
    end

    local min_bet = game_def.min_bet or 1000
    local max_bet = game_def.max_bet or 100000
    local default_bet = game_def.default_bet or min_bet

    if type(min_bet) ~= "number" or min_bet <= 0 then
        error("min_bet must be a positive number")
    end
    if type(max_bet) ~= "number" or max_bet < min_bet then
        error("max_bet must be greater than or equal to min_bet")
    end
    if type(default_bet) ~= "number" or default_bet < min_bet or default_bet > max_bet then
        error("default_bet must be between min_bet and max_bet")
    end

    local status = game_def.status or "active"
    if not VALID_STATUSES[status] then
        error("Invalid game status: " .. tostring(status))
    end

    local entry = {
        id = game_def.id,
        name = game_def.name,
        category = game_def.category,
        tagline = game_def.tagline or "",
        min_bet = min_bet,
        max_bet = max_bet,
        default_bet = default_bet,
        status = status,
        ui_menu_id = game_def.ui_menu_id or "",
        open_cue = game_def.open_cue or ""
    }

    if not self.games[entry.id] then
        table.insert(self.order, entry.id)
    end
    self.games[entry.id] = entry

    return true
end

--- Unregister a game by id
-- @param game_id String identifier of game
-- @return boolean true if found and removed, false otherwise
function GameRegistry:unregister_game(game_id)
    if not self.games[game_id] then
        return false
    end

    self.games[game_id] = nil
    for i, id in ipairs(self.order) do
        if id == game_id then
            table.remove(self.order, i)
            break
        end
    end

    return true
end

--- Retrieve a game by id
-- @param game_id String identifier
-- @return Game definition table or nil
function GameRegistry:get_game(game_id)
    return self.games[game_id]
end

--- Retrieve all registered games in order
-- @return Array of game definition tables
function GameRegistry:get_all_games()
    local result = {}
    for _, id in ipairs(self.order) do
        if self.games[id] then
            table.insert(result, self.games[id])
        end
    end
    return result
end

--- Retrieve all active games
-- @return Array of game definition tables
function GameRegistry:get_active_games()
    local result = {}
    for _, id in ipairs(self.order) do
        local game = self.games[id]
        if game and game.status == "active" then
            table.insert(result, game)
        end
    end
    return result
end

--- Retrieve games by category
-- @param category String category name
-- @return Array of game definition tables
function GameRegistry:get_games_by_category(category)
    local result = {}
    for _, id in ipairs(self.order) do
        local game = self.games[id]
        if game and game.category == category then
            table.insert(result, game)
        end
    end
    return result
end

--- Update game status
-- @param game_id String identifier
-- @param status String status ("active", "maintenance", "coming_soon")
-- @return boolean true if updated, false if not found
function GameRegistry:set_game_status(game_id, status)
    if not VALID_STATUSES[status] then
        error("Invalid game status: " .. tostring(status))
    end
    local game = self.games[game_id]
    if not game then
        return false
    end
    game.status = status
    return true
end

--- Get total game count
-- @return integer
function GameRegistry:get_game_count()
    return #self.order
end

--- Get all unique categories
-- @return Array of category strings
function GameRegistry:get_categories()
    local cat_map = {}
    local result = {}
    for _, id in ipairs(self.order) do
        local game = self.games[id]
        if game and not cat_map[game.category] then
            cat_map[game.category] = true
            table.insert(result, game.category)
        end
    end
    return result
end

return GameRegistry
