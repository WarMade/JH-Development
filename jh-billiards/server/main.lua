local QBCore = exports['qb-core']:GetCoreObject()
local Config = { Fee = 50 }

QBCore.Functions.CreateCallback('jh-billiards:server:canPlay', function(source, cb)
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)
    
    if not Player then 
        print("^1Error: Player data not found for source " .. tostring(src) .. "^7")
        return cb(false) 
    end

    local money = Player.PlayerData.money['cash'] or 0
    local hasCue = Player.Functions.GetItemByName("weapon_poolcue") ~= nil

    cb(hasCue and money >= 50)
end)

local activeGames = {}
local tablePots = {}

local function UpdateLeaderboard(citizenid, name, isWin)
    local query = ""
    if isWin then
        query = "INSERT INTO billiards_leaderboard (citizenid, name, wins) VALUES (?, ?, 1) ON DUPLICATE KEY UPDATE wins = wins + 1, name = ?"
    else
        query = "INSERT INTO billiards_leaderboard (citizenid, name, losses) VALUES (?, ?, 1) ON DUPLICATE KEY UPDATE losses = losses + 1, name = ?"
    end
    MySQL.Async.execute(query, {citizenid, name, name})
end

QBCore.Commands.Add("poolstats", "Check the Top Pool Hustlers", {}, false, function(source)
    MySQL.Async.fetchAll('SELECT * FROM billiards_leaderboard ORDER BY wins DESC LIMIT 5', {}, function(result)
        local menu = {
            {
                header = "🏆 Top Pool Hustlers",
                isMenuHeader = true
            }
        }
        for i, data in ipairs(result) do
            table.insert(menu, {
                header = i .. ". " .. data.name,
                text = "Wins: " .. data.wins .. " | Losses: " .. data.losses,
                isMenuHeader = true
            })
        end
        TriggerClientEvent('qb-menu:client:openMenu', source, menu)
    end)
end)

RegisterNetEvent('jh-billiards:server:joinTable', function(tableId, betAmount, tableCoords)
    local src = source
    local bet = tonumber(betAmount) or Config.Fee
    local Player = QBCore.Functions.GetPlayer(src)
    if not Player then return end

    if Player.PlayerData.money['cash'] < bet then
        TriggerClientEvent('QBCore:Notify', src, "Not enough cash!", "error")
        return
    end

    Player.Functions.RemoveMoney('cash', bet, "billiards-bet")

    if not tablePots[tableId] then
        tablePots[tableId] = bet
    else
        tablePots[tableId] = tablePots[tableId] + bet
    end

    local game = activeGames[tableId]
    if not game then
        activeGames[tableId] = {
            players = {src},
            currentTurn = src,
            ballsPotted = 0,
            betAmount = bet
        }
        TriggerClientEvent('jh-billiards:client:setupTurn', src, true) -- You are the striker
        TriggerClientEvent('QBCore:Notify', src, "Waiting for an opponent to join your $" .. bet .. " match.", "primary")
        return
    end

    if #game.players >= 2 then
        Player.Functions.AddMoney('cash', bet, "billiards-refund")
        tablePots[tableId] = tablePots[tableId] - bet
        TriggerClientEvent('QBCore:Notify', src, "This table is full!", "error")
        return
    end

    if game.betAmount ~= bet then
        Player.Functions.AddMoney('cash', bet, "billiards-refund")
        tablePots[tableId] = tablePots[tableId] - bet
        TriggerClientEvent('QBCore:Notify', src, "Bet amount must match the table wager.", "error")
        return
    end

    table.insert(game.players, src)
    game.currentTurn = game.players[1]
    game.potAmount = tablePots[tableId]

    local startCoords = tableCoords or vector3(0.0, 0.0, 0.0)

    for _, playerId in ipairs(game.players) do
        TriggerClientEvent('jh-billiards:client:beginMatch', playerId, tableId, startCoords)
        local isMyTurn = (playerId == game.currentTurn)
        TriggerClientEvent('jh-billiards:client:setupTurn', playerId, isMyTurn)
    end

    TriggerClientEvent('QBCore:Notify', game.players[1], "Match started! Pot: $" .. game.potAmount .. ".", "success")
    TriggerClientEvent('QBCore:Notify', src, "Match started! Pot: $" .. game.potAmount .. ".", "success")
end)

RegisterNetEvent('jh-billiards:server:endShot', function(tableId, ballsPottedThisTurn)
    local game = activeGames[tableId]
    if not game then return end

    if ballsPottedThisTurn > 0 then
        TriggerClientEvent('QBCore:Notify', game.currentTurn, "Nice shot! Still your turn.", "primary")
    else
        for _, playerId in ipairs(game.players) do
            if playerId ~= game.currentTurn then
                game.currentTurn = playerId
                break
            end
        end
    end

    for _, playerId in ipairs(game.players) do
        local isMyTurn = (playerId == game.currentTurn)
        TriggerClientEvent('jh-billiards:client:setupTurn', playerId, isMyTurn)
    end
end)

RegisterNetEvent('jh-billiards:server:processPot', function(tableId, isEightBall, remainingBalls)
    local src = source
    local game = activeGames[tableId]
    if not game then return end

    if isEightBall then
        if remainingBalls > 1 then
            EndBilliardsGame(tableId, "loss", src)
        else
            EndBilliardsGame(tableId, "win", src)
        end
    else
        game.ballsPotted = game.ballsPotted + 1
    end
end)

RegisterNetEvent('jh-billiards:server:leaveTable', function(tableId)
    local src = source
    local game = activeGames[tableId]
    if not game then return end

    local remainingPlayers = {}
    for _, playerId in ipairs(game.players) do
        if playerId ~= src then
            table.insert(remainingPlayers, playerId)
        end
    end

    activeGames[tableId] = nil
    tablePots[tableId] = nil
    if #remainingPlayers == 1 then
        TriggerClientEvent('QBCore:Notify', remainingPlayers[1], "Your opponent left the game. You win!", "success")
    end

    TriggerClientEvent('QBCore:Notify', src, "You left the billiards game.", "error")
    for _, playerId in ipairs(game.players) do
        TriggerClientEvent('jh-billiards:client:exitGame', playerId, tableId)
    end
end)

function EndBilliardsGame(tableId, result, playerSrc)
    local game = activeGames[tableId]
    local winner = nil
    local loser = nil

    if result == "win" then
        winner = playerSrc
        for _, p in ipairs(game.players) do if p ~= winner then loser = p end end
    else
        loser = playerSrc
        for _, p in ipairs(game.players) do if p ~= loser then winner = p end end
    end

    if winner then
        local winnerPlayer = QBCore.Functions.GetPlayer(winner)
        if winnerPlayer and game.potAmount then
            winnerPlayer.Functions.AddMoney('cash', game.potAmount, "billiards-win")
            UpdateLeaderboard(winnerPlayer.PlayerData.citizenid, winnerPlayer.PlayerData.charinfo.firstname, true)
            TriggerClientEvent('QBCore:Notify', winner, "YOU WON $" .. game.potAmount .. "!", "success")
        else
            TriggerClientEvent('QBCore:Notify', winner, "YOU WON!", "success")
        end
    end
    if loser then
        local loserPlayer = QBCore.Functions.GetPlayer(loser)
        if loserPlayer then
            UpdateLeaderboard(loserPlayer.PlayerData.citizenid, loserPlayer.PlayerData.charinfo.firstname, false)
        end
        TriggerClientEvent('QBCore:Notify', loser, "YOU LOST!", "error")
    end

    activeGames[tableId] = nil
    tablePots[tableId] = nil
    for _, playerId in ipairs(game.players) do
        TriggerClientEvent('jh-billiards:client:exitGame', playerId, tableId)
    end
end