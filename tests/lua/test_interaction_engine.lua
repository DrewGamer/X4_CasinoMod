--[[
    Unit Test Suite for Station Interior Physical Interaction & NPC Filtering Engine
    Validates dynamic room classification, dealer bypass, bartender dialogue hooks,
    wandering NPC filtering, and transient croupier lifecycle contracts.
--]]

package.path = "lua/?.lua;lua/?/init.lua;tests/lua/?.lua;tests/mocks/?.lua;" .. package.path

local luaunit = require("luaunit")
local X4Mock = require("x4_engine_mock")

-- Pure Lua Interaction Engine Contract Emulator matching CasinoStationCues.xml
local InteractionEngine = {}

function InteractionEngine.is_casino_room(room, station)
    if not room or not station then
        return false
    end

    -- 1. Tag Match
    if room.tags and (room.tags["casino"] or room.tags["gambling"]) then
        return true
    end

    -- 2. Dealer Slot Match
    if room.dealer_slots and #room.dealer_slots > 0 then
        return true
    end

    -- 3. Bar Room with Welfare Modules Match
    if room.roomtype == "bar" and station.welfare_modules and #station.welfare_modules > 0 then
        return true
    end

    -- 4. Macro List Fallback Match
    local valid_macros = {
        ["room_gen_casino_01_macro"] = true,
        ["room_gen_bar_01_macro"] = true,
        ["room_gen_gamblingden_01_macro"] = true
    }
    if room.macro and valid_macros[room.macro] then
        return true
    end

    return false
end

function InteractionEngine.classify_npc_interaction(actor, station)
    if not actor or not station then
        return "none"
    end

    -- Tier 1 & Tier 3: Direct Bypass Target
    if actor.has_roulette_dealer_slot or
       actor.is_casino_croupier or
       actor.name == "{20208,20801}" or
       actor.name == "{20208,20802}" or
       actor.name == "Casino Croupier" then
        return "dealer_bypass"
    end

    -- Tier 2: Bartender Dialogue Target
    if actor.entity_type == "bartender" or actor.entity_role == "bartender" then
        return "bartender_dialogue"
    end

    -- Filtered: Wandering crew, pilots, managers, visitors retain 100% vanilla dialogue
    return "vanilla_only"
end

function InteractionEngine.handle_conversation_started(actor, station, player_entity)
    local action_type = InteractionEngine.classify_npc_interaction(actor, station)

    if action_type == "dealer_bypass" then
        player_entity.casino_pending_open = "lobby"
        return {
            close_conversation = true,
            dialogue_choices = {},
            pending_open = "lobby"
        }
    elseif action_type == "bartender_dialogue" then
        return {
            close_conversation = false,
            dialogue_choices = {
                { text = "[Casino] Station Game Lobby", section = "x4_casino_open_lobby", position = "bottom_right" }
            },
            pending_open = nil
        }
    else
        -- Vanilla NPC: 0 casino choices injected
        return {
            close_conversation = false,
            dialogue_choices = {},
            pending_open = nil
        }
    end
end

function InteractionEngine.handle_next_section(section, player_entity)
    if section == "x4_casino_open_lobby" then
        player_entity.casino_pending_open = "lobby"
        return { close_conversation = true, pending_open = "lobby" }
    end
    return { close_conversation = false, pending_open = nil }
end

function InteractionEngine.handle_conversation_finished(player_entity)
    if player_entity.casino_pending_open then
        local target = player_entity.casino_pending_open
        player_entity.casino_pending_open = nil
        if target == "slots" then
            return "Open_Slots_Direct"
        elseif target == "lobby" then
            return "Open_Lobby_Direct"
        end
    end
    return nil
end

function InteractionEngine.handle_room_entry(room, station)
    local is_casino = InteractionEngine.is_casino_room(room, station)
    if is_casino then
        local has_dealer_slots = (room.dealer_slots and #room.dealer_slots > 0)
        if not has_dealer_slots and (not room.casino_host or not room.casino_host.is_alive) then
            local host = {
                knownname = "Casino Croupier",
                name = "Casino Croupier",
                race = (station.owner and station.owner.primaryrace) or "teladi",
                role = "service",
                customhandler = true,
                is_casino_croupier = true,
                is_alive = true
            }
            room.casino_host = host
            return host
        end
    end
    return nil
end

function InteractionEngine.handle_room_exit(old_room)
    if old_room and old_room.casino_host then
        if old_room.casino_host.is_alive then
            old_room.casino_host.is_alive = false
        end
        old_room.casino_host = nil
        return true
    end
    return false
end

-- =========================================================================
-- Unit Tests
-- =========================================================================

local TestInteractionEngine = {}

function TestInteractionEngine:setUp()
    X4Mock.reset()
    self.station = {
        name = "Grand Exchange Casino Complex",
        owner = { primaryrace = "teladi" },
        welfare_modules = { "module_tel_hab_01" }
    }
    self.player_entity = {}
end

function TestInteractionEngine:test_room_discovery_by_tags()
    local casino_tagged_room = { tags = { casino = true } }
    local gambling_tagged_room = { tags = { gambling = true } }
    local generic_room = { tags = { engineering = true } }

    luaunit.assertTrue(InteractionEngine.is_casino_room(casino_tagged_room, self.station))
    luaunit.assertTrue(InteractionEngine.is_casino_room(gambling_tagged_room, self.station))
    luaunit.assertFalse(InteractionEngine.is_casino_room(generic_room, self.station))
end

function TestInteractionEngine.test_room_discovery_by_dealer_slots()
    local slotted_room = {
        dealer_slots = { { id = "slot_roulette_01", tag = "tag.roulette_dealer" } }
    }
    local empty_slot_room = { dealer_slots = {} }

    local station = { owner = { primaryrace = "teladi" } }
    luaunit.assertTrue(InteractionEngine.is_casino_room(slotted_room, station))
    luaunit.assertFalse(InteractionEngine.is_casino_room(empty_slot_room, station))
end

function TestInteractionEngine.test_room_discovery_by_bar_and_welfare()
    local bar_room = { roomtype = "bar" }
    local station_with_welfare = { welfare_modules = { "welfare_01" } }
    local station_without_welfare = { welfare_modules = {} }

    luaunit.assertTrue(InteractionEngine.is_casino_room(bar_room, station_with_welfare))
    luaunit.assertFalse(InteractionEngine.is_casino_room(bar_room, station_without_welfare))
end

function TestInteractionEngine.test_room_discovery_by_fallback_macro()
    local macro_casino = { macro = "room_gen_casino_01_macro" }
    local macro_bar = { macro = "room_gen_bar_01_macro" }
    local macro_den = { macro = "room_gen_gamblingden_01_macro" }
    local macro_dock = { macro = "room_gen_dock_01_macro" }

    local empty_station = { welfare_modules = {} }
    luaunit.assertTrue(InteractionEngine.is_casino_room(macro_casino, empty_station))
    luaunit.assertTrue(InteractionEngine.is_casino_room(macro_bar, empty_station))
    luaunit.assertTrue(InteractionEngine.is_casino_room(macro_den, empty_station))
    luaunit.assertFalse(InteractionEngine.is_casino_room(macro_dock, empty_station))
end

function TestInteractionEngine:test_dealer_direct_bypass_frame_zero()
    local static_dealer = {
        name = "Table Dealer",
        has_roulette_dealer_slot = true,
        entity_role = "service"
    }

    local result = InteractionEngine.handle_conversation_started(static_dealer, self.station, self.player_entity)
    luaunit.assertTrue(result.close_conversation, "Dealer conversation must close immediately on Frame 0")
    luaunit.assertEquals(#result.dialogue_choices, 0, "No dialogue options should show on dealer bypass")
    luaunit.assertEquals(self.player_entity.casino_pending_open, "lobby")

    -- Modal dispatch on conversation finished
    local opened_cue = InteractionEngine.handle_conversation_finished(self.player_entity)
    luaunit.assertEquals(opened_cue, "Open_Lobby_Direct")
    luaunit.assertNil(self.player_entity.casino_pending_open)
end

function TestInteractionEngine:test_named_dealers_and_titles_bypass()
    local dealer_20801 = { name = "{20208,20801}" }
    local dealer_20802 = { name = "{20208,20802}" }
    local croupier_actor = { name = "Casino Croupier", is_casino_croupier = true }

    luaunit.assertEquals(InteractionEngine.classify_npc_interaction(dealer_20801, self.station), "dealer_bypass")
    luaunit.assertEquals(InteractionEngine.classify_npc_interaction(dealer_20802, self.station), "dealer_bypass")
    luaunit.assertEquals(InteractionEngine.classify_npc_interaction(croupier_actor, self.station), "dealer_bypass")
end

function TestInteractionEngine:test_bartender_dialogue_hook()
    local bartender = {
        name = "Station Bartender",
        entity_type = "bartender",
        entity_role = "bartender"
    }

    local result = InteractionEngine.handle_conversation_started(bartender, self.station, self.player_entity)
    luaunit.assertFalse(result.close_conversation, "Bartender comms should stay open for dialogue selection")
    luaunit.assertEquals(#result.dialogue_choices, 1)
    luaunit.assertEquals(result.dialogue_choices[1].text, "[Casino] Station Game Lobby")
    luaunit.assertEquals(result.dialogue_choices[1].section, "x4_casino_open_lobby")
    luaunit.assertEquals(result.dialogue_choices[1].position, "bottom_right")

    -- Selecting option
    local nav_result = InteractionEngine.handle_next_section("x4_casino_open_lobby", self.player_entity)
    luaunit.assertTrue(nav_result.close_conversation)
    luaunit.assertEquals(self.player_entity.casino_pending_open, "lobby")

    local opened_cue = InteractionEngine.handle_conversation_finished(self.player_entity)
    luaunit.assertEquals(opened_cue, "Open_Lobby_Direct")
end

function TestInteractionEngine:test_wandering_npc_filtered_cleanly()
    local captain = { name = "Ship Captain", entity_type = "commander", entity_role = "captain" }
    local pilot = { name = "Fighter Pilot", entity_type = "pilot", entity_role = "pilot" }
    local crew = { name = "Service Crew", entity_type = "service", entity_role = "service" }
    local visitor = { name = "Station Visitor", entity_type = "visitor", entity_role = "visitor" }

    local npcs = { captain, pilot, crew, visitor }
    for _, npc in ipairs(npcs) do
        local classification = InteractionEngine.classify_npc_interaction(npc, self.station)
        luaunit.assertEquals(classification, "vanilla_only",
            "Wandering NPC " .. npc.name .. " must be vanilla_only")

        local result = InteractionEngine.handle_conversation_started(npc, self.station, self.player_entity)
        luaunit.assertFalse(result.close_conversation)
        luaunit.assertEquals(#result.dialogue_choices, 0,
            "No casino choices injected into wandering NPC " .. npc.name)
        luaunit.assertNil(self.player_entity.casino_pending_open)
    end
end

function TestInteractionEngine:test_transient_croupier_spawner_and_despawn()
    local casino_room_no_slots = { tags = { casino = true }, dealer_slots = {} }

    -- 1. Entry spawns fallback host
    local host = InteractionEngine.handle_room_entry(casino_room_no_slots, self.station)
    luaunit.assertNotNil(host)
    luaunit.assertEquals(host.name, "Casino Croupier")
    luaunit.assertEquals(host.race, "teladi")
    luaunit.assertTrue(host.is_casino_croupier)
    luaunit.assertTrue(host.is_alive)
    luaunit.assertEquals(casino_room_no_slots.casino_host, host)

    -- 2. Entry again does not duplicate host
    local duplicate = InteractionEngine.handle_room_entry(casino_room_no_slots, self.station)
    luaunit.assertNil(duplicate)

    -- 3. Exit despawns host cleanly
    local cleaned = InteractionEngine.handle_room_exit(casino_room_no_slots)
    luaunit.assertTrue(cleaned)
    luaunit.assertFalse(host.is_alive)
    luaunit.assertNil(casino_room_no_slots.casino_host)
end

function TestInteractionEngine.test_transient_croupier_race_matching()
    local boron_station = { owner = { primaryrace = "boron" } }
    local boron_room = { tags = { casino = true }, dealer_slots = {} }

    local host = InteractionEngine.handle_room_entry(boron_room, boron_station)
    luaunit.assertNotNil(host)
    luaunit.assertEquals(host.race, "boron", "Croupier should match station owner primary race")
end

_G.TestInteractionEngine = TestInteractionEngine

local runner = luaunit.LuaUnit.new()
os.exit(runner:runSuite())
