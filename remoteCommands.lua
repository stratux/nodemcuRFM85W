--0xF0
--Start configuring.
--0x99 [reg] [val]
--Set a single value in register
--0xF1
--Commit-confirm. Reset in 1 minute if "confirm" is not received.
--0xF2
--Confirm changes.

local pending_changes = {}

--Called from handle_dio0_interrupt() when a message is received.
function parse_commands(cmds)
end

--Called when "confirm" is received.
function commit_changes()
	for i = 1, pending_changes:len() + 1, 1 do
		spi_set_register(pending_changes[i][1], pending_changes[i][2])
	end
	pending_changes = {}
end

--Called when the "confirm" is not received in time.
function commit_timeout()
	node.restart()
end
