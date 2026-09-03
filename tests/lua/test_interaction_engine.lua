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

function InteractionEngine.handle_conversation_started(actor, station, player_entity, event_context)
    local action_type = InteractionEngine.classify_npc_interaction(actor, station)

    if action_type == "dealer_bypass" then
        player_entity.casino_pending_open = "lobby"
        return {
            close_conversation = true,
            dialogue_choices = {},
            pending_open = "lobby"
        }
    elseif action_type == "bartender_dialogue" then
        local is_default_section = true
        if event_context then
            if event_context.section and event_context.section ~= "default" then
                is_default_section = false
            elseif event_context.conversation and event_context.conversation ~= "default" then
                is_default_section = false
            end
        end

        local choices = {}
        if is_default_section then
            table.insert(choices, {
                text = "[Casino] Station Game Lobby",
                section = "x4_casino_open_lobby"
            })
        end

        return {
            close_conversation = false,
            dialogue_choices = choices,
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
        local registered_dealers = {}

        if has_dealer_slots then
            for _, slot in ipairs(room.dealer_slots) do
                local dealer = nil
                if slot.component and slot.component.slotactor and slot.component.slotactor[slot] then
                    dealer = slot.component.slotactor[slot]
                elseif slot.slotactor then
                    dealer = slot.slotactor
                end

                if dealer then
                    dealer.busy = false
                    dealer.customhandler = true
                    table.insert(registered_dealers, dealer)
                end
            end
            if #registered_dealers > 0 then
                return registered_dealers
            end
        end

        if not has_dealer_slots and (not room.casino_host or not room.casino_host.is_alive) then
            local host = {
                knownname = "Casino Croupier",
                name = "Casino Croupier",
                race = (station.owner and station.owner.primaryrace) or "teladi",
                role = "service",
                customhandler = true,
                busy = false,
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

function InteractionEngine.migrate_savegame_state(casino_data)
    if not casino_data then
        casino_data = {}
    end

    if casino_data.CurrentBet == nil then
        casino_data.CurrentBet = 5000
    end
    if casino_data.Reel1 == nil then
        casino_data.Reel1 = "[ PROFIT! ]"
    end
    if casino_data.Reel2 == nil then
        casino_data.Reel2 = "[ PROFIT! ]"
    end
    if casino_data.Reel3 == nil then
        casino_data.Reel3 = "[ PROFIT! ]"
    end
    if casino_data.ResultBanner == nil then
        casino_data.ResultBanner = "Match 3 symbols for profitsss!"
    end
    if casino_data.TotalSpins == nil then
        casino_data.TotalSpins = 0
    end
    if casino_data.TotalWagered == nil then
        casino_data.TotalWagered = 0
    end
    if casino_data.TotalWon == nil then
        casino_data.TotalWon = 0
    end
    if casino_data.NetProfit == nil then
        casino_data.NetProfit = 0
    end
    if casino_data.JackpotsHit == nil then
        casino_data.JackpotsHit = 0
    end
    if casino_data.DemoMode == nil then
        casino_data.DemoMode = 0
    end

    return casino_data
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
    luaunit.assertNil(result.dialogue_choices[1].position, "Position must be nil to enable dynamic auto-positioning")

    -- Selecting option
    local nav_result = InteractionEngine.handle_next_section("x4_casino_open_lobby", self.player_entity)
    luaunit.assertTrue(nav_result.close_conversation)
    luaunit.assertEquals(self.player_entity.casino_pending_open, "lobby")

    local opened_cue = InteractionEngine.handle_conversation_finished(self.player_entity)
    luaunit.assertEquals(opened_cue, "Open_Lobby_Direct")
end

function TestInteractionEngine:test_bartender_dialogue_guard_prevents_submenu_injection()
    local bartender = {
        name = "Station Bartender",
        entity_type = "bartender",
        entity_role = "bartender"
    }

    -- Submenu or non-default section navigation
    local submenu_context = { section = "directions" }
    local result = InteractionEngine.handle_conversation_started(
        bartender, self.station, self.player_entity, submenu_context
    )
    luaunit.assertFalse(result.close_conversation)
    luaunit.assertEquals(#result.dialogue_choices, 0,
        "No casino choices should be injected into bartender submenus (section ~= 'default')")
end

function TestInteractionEngine.test_bartender_xml_cue_contract()
    local f = io.open("md/CasinoStationCues.xml", "r")
    luaunit.assertNotNil(f, "md/CasinoStationCues.xml should exist and be readable")
    local content = f:read("*a")
    f:close()

    -- Extract On_Bartender_Conversation_Started cue block
    local cue_start = content:find('<cue name="On_Bartender_Conversation_Started"')
    luaunit.assertNotNil(cue_start, "On_Bartender_Conversation_Started cue must exist")
    local cue_end = content:find('</cue>', cue_start)
    local cue_block = content:sub(cue_start, cue_end)

    -- Verify default section guards
    luaunit.assertTrue(
        cue_block:find('<event_conversation_started conversation="default"/>', 1, true) ~= nil,
        "Guard must check event_conversation_started conversation='default'"
    )
    luaunit.assertTrue(
        cue_block:find('<event_conversation_returned_to_section section="default"/>', 1, true) ~= nil,
        "Guard must check event_conversation_returned_to_section section='default'"
    )
    luaunit.assertTrue(
        cue_block:find('<event_conversation_next_section section="default"/>', 1, true) ~= nil,
        "Guard must check event_conversation_next_section section='default'"
    )

    -- Verify dynamic auto-positioning (no position attribute)
    luaunit.assertTrue(
        cue_block:find("text=\"'[Casino] Station Game Lobby'\"", 1, true) ~= nil,
        "Choice text must be '[Casino] Station Game Lobby'"
    )
    luaunit.assertTrue(
        cue_block:find("section=\"'x4_casino_open_lobby'\"", 1, true) ~= nil,
        "Choice section must be 'x4_casino_open_lobby'"
    )
    luaunit.assertFalse(
        cue_block:find('position=', 1, true) ~= nil,
        "position attribute must be omitted for dynamic auto-positioning"
    )

    -- Extract On_Bartender_Next_Section cue block
    local next_start = content:find('<cue name="On_Bartender_Next_Section"')
    luaunit.assertNotNil(next_start, "On_Bartender_Next_Section cue must exist")
    local next_end = content:find('</cue>', next_start)
    local next_block = content:sub(next_start, next_end)

    luaunit.assertTrue(
        next_block:find('<event_conversation_next_section section="\'x4_casino_open_lobby\'"/>', 1, true) ~= nil,
        "On_Bartender_Next_Section must trigger on section 'x4_casino_open_lobby'"
    )
    luaunit.assertTrue(
        next_block:find('<close_conversation/>', 1, true) ~= nil,
        "On_Bartender_Next_Section must execute close_conversation"
    )
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

function TestInteractionEngine:test_slot_actor_retrieval_and_unsuppression()
    local dealer_actor = {
        name = "Table Dealer",
        entity_role = "service",
        busy = true,
        customhandler = false,
        has_roulette_dealer_slot = true
    }
    local slot = {
        id = "slot_roulette_dealer_01",
        tag = "tag.roulette_dealer"
    }
    slot.component = {
        slotactor = {
            [slot] = dealer_actor
        }
    }
    local room = {
        dealer_slots = { slot },
        tags = { casino = true }
    }

    local result = InteractionEngine.handle_room_entry(room, self.station)
    luaunit.assertNotNil(result, "Room entry should return or register slot dealers")
    luaunit.assertEquals(dealer_actor.busy, false, "Roulette table dealer busy flag must be cleared (false)")
    luaunit.assertTrue(dealer_actor.customhandler, "Roulette table dealer customhandler trait must be true")
    luaunit.assertNil(room.casino_host, "Fallback croupier must not spawn when dealer slots exist")
end

function TestInteractionEngine:test_wandering_service_crew_not_registered_as_dealer()
    local wandering_service_npc = {
        name = "Service Crew Member",
        entity_type = "service",
        entity_role = "service",
        busy = false,
        customhandler = false
    }

    -- Verify wandering crew is classified strictly as vanilla_only
    local classification = InteractionEngine.classify_npc_interaction(wandering_service_npc, self.station)
    luaunit.assertEquals(classification, "vanilla_only", "Generic service crew must NOT be classified as dealer_bypass")
    luaunit.assertFalse(wandering_service_npc.customhandler, "Generic service crew must retain customhandler = false")
end

function TestInteractionEngine.test_dealer_xml_cue_contract_slotactor_and_busy_false()
    local f = io.open("md/CasinoStationCues.xml", "r")
    luaunit.assertNotNil(f, "md/CasinoStationCues.xml should exist and be readable")
    local content = f:read("*a")
    f:close()

    -- 1. Must query $slot.component.slotactor.{$slot}
    luaunit.assertTrue(
        content:find("$slot.component.slotactor.{$slot}", 1, true) ~= nil,
        "md/CasinoStationCues.xml must retrieve dealer entity via $slot.component.slotactor.{$slot}"
    )

    -- 2. Must set busy='false' and customhandler='true' on dealer
    luaunit.assertTrue(
        content:find('busy="false"', 1, true) ~= nil,
        "md/CasinoStationCues.xml must suppress busy flag using busy=\"false\""
    )

    -- 3. Must NOT scan generic entityrole.service to hook dealers
    luaunit.assertFalse(
        content:find("$npc.role == entityrole.service", 1, true) ~= nil,
        "md/CasinoStationCues.xml must NOT treat generic entityrole.service as dealers"
    )
end

function TestInteractionEngine.test_ascii_typography_sanitization()
    local files_to_check = {
        "md/CasinoStationCues.xml",
        "lua/ui_adapters/slots_menu.lua",
        "t/0001.xml",
        "t/0001-l044.xml",
        "scripts/play_slots.lua"
    }
    local non_ascii_count = 0
    local failure_details = {}

    for _, filepath in ipairs(files_to_check) do
        local f = io.open(filepath, "rb")
        luaunit.assertNotNil(f, "File must exist: " .. filepath)
        local content = f:read("*a")
        f:close()

        local file_non_ascii = 0
        for i = 1, #content do
            local byte = content:byte(i)
            if byte > 127 then
                non_ascii_count = non_ascii_count + 1
                file_non_ascii = file_non_ascii + 1
            end
        end
        if file_non_ascii > 0 then
            table.insert(failure_details, string.format("%s (%d non-ASCII bytes)", filepath, file_non_ascii))
        end
    end

    luaunit.assertEquals(
        non_ascii_count,
        0,
        "Non-ASCII characters detected (causes '?' glyph corruption): " .. table.concat(failure_details, ", ")
    )
end

function TestInteractionEngine.test_transient_croupier_xml_cue_contract()
    local f = io.open("md/CasinoStationCues.xml", "r")
    luaunit.assertNotNil(f, "md/CasinoStationCues.xml should exist and be readable")
    local content = f:read("*a")
    f:close()

    -- 1. Must check $DealerSlots.count == 0 before spawning fallback croupier
    luaunit.assertTrue(
        content:find("$DealerSlots.count == 0", 1, true) ~= nil,
        "Fallback croupier must only spawn when $DealerSlots.count == 0"
    )

    -- 2. Must select station owner primary race
    luaunit.assertTrue(
        content:find('select race="player.station.owner.primaryrace"', 1, true) ~= nil,
        "Fallback croupier must match station owner primary race"
    )

    -- 3. Must flag host as casino croupier
    luaunit.assertTrue(
        content:find("$host.$is_casino_croupier", 1, true) ~= nil,
        "Fallback croupier must set $host.$is_casino_croupier"
    )

    -- 4. Clean despawn in On_Player_Left_Room
    local exit_cue_start = content:find('<cue name="On_Player_Left_Room"')
    luaunit.assertNotNil(exit_cue_start, "On_Player_Left_Room cue must exist")
    local exit_cue_end = content:find('</cue>', exit_cue_start)
    local exit_block = content:sub(exit_cue_start, exit_cue_end)

    luaunit.assertTrue(
        exit_block:find('<destroy_object object="event.param.$casino_host"/>', 1, true) ~= nil,
        "On_Player_Left_Room must destroy $casino_host"
    )
    luaunit.assertTrue(
        exit_block:find('<remove_value name="event.param.$casino_host"/>', 1, true) ~= nil,
        "On_Player_Left_Room must remove $casino_host blackboard reference"
    )
end

function TestInteractionEngine.test_standalone_ui_live_widget_update_pipeline()
    local f = io.open("md/CasinoStationCues.xml", "r")
    luaunit.assertNotNil(f, "md/CasinoStationCues.xml should exist and be readable")
    local content = f:read("*a")
    f:close()

    -- 1. Verify Update_Slots_UI cue exists
    local update_cue_start = content:find('<cue name="Update_Slots_UI"')
    luaunit.assertNotNil(update_cue_start, "Update_Slots_UI helper cue must exist in md/CasinoStationCues.xml")
    local update_cue_end = content:find('</cue>', update_cue_start)
    local update_block = content:sub(update_cue_start, update_cue_end)

    -- 2. Verify all 7 required widgets are targeted via md.Simple_Menu_API.Update_Widget
    local required_widget_ids = {
        "txt_header",
        "txt_mode_notice",
        "btn_toggle_demo",
        "box_reel1",
        "box_reel2",
        "box_reel3",
        "txt_banner"
    }
    for _, widget_id in ipairs(required_widget_ids) do
        local target = "$id%s*=%s*'" .. widget_id .. "'"
        luaunit.assertTrue(
            update_block:find(target) ~= nil,
            "Update_Slots_UI must update widget: " .. widget_id
        )
    end

    -- 3. Verify actions signal Update_Slots_UI
    luaunit.assertTrue(
        content:find('signal_cue_instantly cue="Update_Slots_UI"', 1, true) ~= nil,
        "Actions in md/CasinoStationCues.xml must signal Update_Slots_UI"
    )
end

function TestInteractionEngine.test_savegame_schema_defense_and_null_migration()
    -- Emulate legacy savegame state missing new schema keys
    local legacy_data = {
        CurrentBet = 5000,
        TotalSpins = 12,
        TotalWagered = 60000,
        TotalWon = 25000,
        NetProfit = -35000
        -- JackpotsHit is missing (nil)
        -- DemoMode is missing (nil)
        -- Reel1, Reel2, Reel3 missing
        -- ResultBanner missing
    }

    -- Step 1: Run migration through InteractionEngine emulator
    local migrated = InteractionEngine.migrate_savegame_state(legacy_data)
    luaunit.assertNotNil(migrated, "Migration function must return migrated table")
    luaunit.assertEquals(migrated.JackpotsHit, 0, "Missing JackpotsHit must migrate to 0")
    luaunit.assertEquals(migrated.DemoMode, 0, "Missing DemoMode must migrate to 0")
    luaunit.assertEquals(migrated.Reel1, "[ PROFIT! ]", "Missing Reel1 must default to '[ PROFIT! ]'")
    luaunit.assertEquals(migrated.Reel2, "[ PROFIT! ]", "Missing Reel2 must default to '[ PROFIT! ]'")
    luaunit.assertEquals(migrated.Reel3, "[ PROFIT! ]", "Missing Reel3 must default to '[ PROFIT! ]'")
    luaunit.assertEquals(migrated.ResultBanner, "Match 3 symbols for profitsss!", "Missing ResultBanner must default")
    luaunit.assertEquals(migrated.TotalSpins, 12, "Existing TotalSpins must be preserved")
    luaunit.assertEquals(migrated.CurrentBet, 5000, "Existing CurrentBet must be preserved")

    -- Step 2: Validate XML contract across Init_Casino_State, Open_Lobby_Direct, Build_Lobby_Menu
    local f = io.open("md/CasinoStationCues.xml", "r")
    luaunit.assertNotNil(f, "md/CasinoStationCues.xml should exist and be readable")
    local content = f:read("*a")
    f:close()

    luaunit.assertTrue(
        content:find("not player.entity.$casino_data.$JackpotsHit?", 1, true) ~= nil,
        "Init_Casino_State or menu builds must guard against missing $JackpotsHit"
    )
    luaunit.assertTrue(
        content:find("not player.entity.$casino_data.$DemoMode?", 1, true) ~= nil,
        "Init_Casino_State or menu builds must guard against missing $DemoMode"
    )
end

_G.TestInteractionEngine = TestInteractionEngine

local runner = luaunit.LuaUnit.new()
os.exit(runner:runSuite())

