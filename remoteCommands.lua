--0xF0
--Start configuring.
--0x99 [reg] [val]
--Set a single value in register
--0xF1
--Commit-confirm. Reset in 1 minute if "confirm" is not received.
--0xF2
--Confirm changes.

pending_changes = {}

--Called from handle_dio0_interrupt() when a message is received.
function parse_commands(cmds)
	local i = 1
	while i <= cmds:len() do
		local b = cmds:byte(i)
		print(i .. ":" .. b)
		if b == 0xF2 then
			--Confirm changes. Commits then sets up a confirm timer.
			commit_changes()
			--Set up the timeout function, in case "commit confirm" isn't received.
			tmr.alarm(3, 30000, tmr.ALARM_SINGLE, function()
				commit_timeout()
			end)
		elseif b == 0xF1 then
			--Commit confirm.
			tmr.stop(3)
		elseif b == 0x99 then
			if i < cmds:len()-1 then --Need two bytes after 0x99.
				local l = table.getn(pending_changes)+1
				pending_changes[l] = {}
				pending_changes[l][1] = cmds:byte(i+1) --Register.
				pending_changes[l][2] = cmds:byte(i+2) --Value
				i = i + 2
			end
		end
		i = i + 1
	end
end

--Called when "confirm" is received.
function commit_changes()
	for i = 1, table.getn(pending_changes), 1 do
		--print("command: " .. pending_changes[i][1] .. "." .. pending_changes[i][2])
		spi_set_register(pending_changes[i][1], pending_changes[i][2])
	end
	pending_changes = {}
end

--Called when the "confirm" is not received in time.
function commit_timeout()
	node.restart()
end
