RegisterCommand('worldevent', function(source, args, rawCommand)
    -- This assumes you have Ace permissions set up, 
    -- or you can change to true to allow everyone.
    if IsPlayerAceAllowed(source, "command.worldevent") or source == 0 then
        TriggerClientEvent('lively_world:forceEvent', source, args[1])
    else
        print("Permission denied for " .. GetPlayerName(source))
    end
end, false)