--[[
    Interactive CLI Terminal Game: Teladi Profit Spinner
    Allows testing pure Lua casino logic directly in the terminal before launching X4.
--]]

package.path = "lua/?.lua;lua/?/init.lua;" .. package.path

local Slots = require("casino_core.slots")

-- Symbol formatting with visual icons/labels
local SYMBOL_DISPLAY = {
    teladi_profit = "[ PROFIT! ]",
    nividium      = "[ NIVIDIUM]",
    silicon       = "[ SILICON ]",
    ore           = "[   ORE   ]",
    energy_cells  = "[ E-CELLS ]"
}

local WIN_TITLES = {
    JACKPOT      = "*** TELADI JACKPOT! (50x) ***",
    MAJOR_WIN    = "=== MAJOR WIN! (20x) ===",
    MEDIUM_WIN   = "[+] MEDIUM WIN! (10x) [+]",
    ENERGY_BOOST = "[+] ENERGY BOOST! (5x) [+]",
    PAIR_MATCH   = "[+] PAIR MATCH (2x)",
    LOSS         = "[-] No match. Teladi keeps profitsss."
}

local function format_credits(n)
    local s = tostring(math.floor(n))
    local pos = string.len(s) % 3
    if pos == 0 then pos = 3 end
    return string.sub(s, 1, pos) .. string.gsub(string.sub(s, pos + 1), "(%d%d%d)", ",%1")
end

local function print_banner(balance)
    print("\n========================================================")
    print("        TELADI PROFIT SPINNER (3-Reel Slots CLI)        ")
    print("========================================================")
    print(string.format("  Player Balance: %s Cr", format_credits(balance)))
    print("--------------------------------------------------------")
end

local function render_reels(reels)
    local d1 = SYMBOL_DISPLAY[reels[1]] or reels[1]
    local d2 = SYMBOL_DISPLAY[reels[2]] or reels[2]
    local d3 = SYMBOL_DISPLAY[reels[3]] or reels[3]

    print("\n  +-------------+-------------+-------------+")
    print(string.format("  |  %s  |  %s  |  %s  |", d1, d2, d3))
    print("  +-------------+-------------+-------------+\n")
end

local function main()
    local game = Slots.new()
    local balance = 100000 -- Starting balance: 100,000 Cr
    local current_bet = 5000

    print_banner(balance)
    print("Controls:")
    print("  [Enter]         - Spin with current bet (" .. format_credits(current_bet) .. " Cr)")
    print("  [1/2/3/4]       - Change bet (1: 1k, 2: 5k, 3: 25k, 4: 100k)")
    print("  [s <count>]     - Fast simulation (e.g. 's 1000' spins)")
    print("  [q]             - Quit CLI")

    while balance > 0 do
        io.write(string.format("\n[Balance: %s Cr | Bet: %s Cr] > ", format_credits(balance), format_credits(current_bet)))
        io.flush()
        local input = io.read()
        if not input or input:lower() == "q" then
            print("\nLeaving casino lounge. Final Balance: " .. format_credits(balance) .. " Cr. Profitsss to you!")
            break
        end

        input = input:match("^%s*(.-)%s*$") -- trim

        if input == "1" then
            current_bet = 1000
            print("Bet changed to 1,000 Cr")
        elseif input == "2" then
            current_bet = 5000
            print("Bet changed to 5,000 Cr")
        elseif input == "3" then
            current_bet = 25000
            print("Bet changed to 25,000 Cr")
        elseif input == "4" then
            current_bet = 100000
            print("Bet changed to 100,000 Cr")
        elseif input:match("^s%s*(%d+)$") then
            -- Simulation mode
            local spins = tonumber(input:match("^s%s*(%d+)$"))
            if spins and spins > 0 then
                print(string.format("\n--- Simulating %d spins at %s Cr/spin ---", spins, format_credits(current_bet)))
                local total_wagered = 0
                local total_won = 0
                local wins_count = 0
                local stats = {}

                for _ = 1, spins do
                    if balance < current_bet then
                        print("[!] Bankroll depleted during simulation!")
                        break
                    end
                    balance = balance - current_bet
                    total_wagered = total_wagered + current_bet

                    local round = game:play_round(current_bet)
                    balance = balance + round.payout
                    total_won = total_won + round.payout

                    if round.multiplier > 0 then
                        wins_count = wins_count + 1
                    end
                    stats[round.win_type] = (stats[round.win_type] or 0) + 1
                end

                print(string.format("Spins Completed: %d", spins))
                print(string.format("Total Wagered:   %s Cr", format_credits(total_wagered)))
                print(string.format("Total Payout:    %s Cr", format_credits(total_won)))
                print(string.format("Net Profit/Loss: %+s Cr", format_credits(total_won - total_wagered)))
                print(string.format("Actual RTP:      %.2f%%", (total_won / total_wagered) * 100))
                print(string.format("Hit Rate:        %.2f%%", (wins_count / spins) * 100))
                print("Outcome Breakdown:")
                for k, v in pairs(stats) do
                    print(string.format("  - %-15s: %d (%0.1f%%)", k, v, (v / spins) * 100))
                end
                print(string.format("Current Balance: %s Cr", format_credits(balance)))
            end
        else
            -- Single Spin
            if balance < current_bet then
                print("[!] Insufficient balance for bet of " .. format_credits(current_bet) .. " Cr!")
            else
                balance = balance - current_bet
                local round = game:play_round(current_bet)
                balance = balance + round.payout

                render_reels(round.reels)
                local title = WIN_TITLES[round.win_type] or round.win_type
                print(string.format("  %s", title))
                if round.payout > 0 then
                    print(string.format("  Payout: +%s Cr  (Multiplier: %dx)", format_credits(round.payout), round.multiplier))
                else
                    print("  Lost:   -" .. format_credits(current_bet) .. " Cr")
                end
                print(string.format("  New Balance: %s Cr", format_credits(balance)))
            end
        end
    end
end

main()
