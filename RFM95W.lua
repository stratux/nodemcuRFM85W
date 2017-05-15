--DIO0 (interrupt) on GPIO5 (1).

waiting_interrupt = 0 --Must receive the interrupt to continue.

current_mode = 0 --0x05=RF95W_MODE_RXCONTINUOUS, 0x03=RF95W_MODE_TX

function handle_dio0_interrupt(level, when)
	local irqFlags = spi_get_register(0x12)
	if current_mode == 0x03 then --Waiting for TX to finish
		if waiting_interrupt == 0 then
			--print("received DIO0 interrupt but was not expecting it.")
			return
		end
		--Don't bother getting IRQ flags, assume that all interrupts are TxDone.
		--print("TxDone.")
		--Set up DIO0 interrupt pin and set DIO0 to interrupt on RxDone.
		spi_set_register(0x40, 0x00)
		--Set RXCONTINUOUS mode.
		spi_set_register(0x01, 0x05)
		current_mode = 0x05
		waiting_interrupt = 0
	elseif current_mode == 0x05 then --RX.
		--print("rx'd, " ..irqFlags)
		if BitAND(irqFlags, 0x80) ~= 0 then --RXTIMEOUT.
			--print("RXTIMEOUT.")
		elseif BitAND(irqFlags, 0x20) ~= 0 then --PAYLOADCRCERROR.
			--print("Payload CRC error.")
		elseif BitAND(irqFlags, 0x40) ~= 0 then --RXDONE.
			local msgLen = spi_get_register(0x13)
			local fifoPtr = spi_get_register(0x10)
			--print("receiving message with length "..msgLen)
			if msgLen < 64 then --Can only handle up to 64 bytes.
				spi_set_register(0x0D, fifoPtr) --Set read start address at the RX FIFO pointer address.
				local recvMsg = spi_bulk_read(0x00, msgLen)
				if recvMsg:byte(1) == 0xF0 then
					--print("Received command message, parsing.")
					parse_commands(recvMsg:sub(2))
				else
					--print("Message received:")
					--print(recvMsg)
				end
			end
		end
	end
	--Clear IRQ flags.
	spi_set_register(0x12, 0xFF)
end

function init_rfm95w()
	--Set SLEEP and LoRa mode.
	spi_set_register(0x01, 0x80) -- LoRa + Sleep.

	tmr.delay(10000) --Wait 10ms.

	--Get mode, check mode.
	local cur_mode = spi_get_register(0x01)
	if cur_mode ~= 0x80 then
		--print("LoRa module init failure.")
	end

	--Set base addresses of the FIFO buffer in both TX and RX cases to zero.
	spi_set_register(0x0E, 0x00)
	spi_set_register(0x0F, 0x00)
	
	--Set STDBY mode.
	spi_set_register(0x01, 0x01)

	--Configuration registers.
	spi_set_register(0x1D, 0x78) -- BW=125 kHz, CR=4/8, ImplicitHeaderModeOn=0.
	spi_set_register(0x1E, 0x74) -- SF=7.
	spi_set_register(0x26, 0x00)

	--Set preamble length to 8.
	spi_set_register(0x20, 0x00)
	spi_set_register(0x21, 0x08)

	--Set frequency to 915 MHz.
	spi_set_register(0x06, 0xE4)
	spi_set_register(0x07, 0xC0)
	spi_set_register(0x08, 0x00)

	--Set TX power to 20 dBm. Enable PA_BOOST.
	spi_set_register(0x09, 0x8F)
	--5.4.3. High Power +20 dBm Operation
	spi_set_register(0x4D, 0x87)

	--Set pin connected to DIO0 to INT (interrupt) mode.
	gpio.mode(1, gpio.INT, gpio.PULLDOWN)
	gpio.trig(1, "up", handle_dio0_interrupt)

	--Set up DIO0 interrupt pin and set DIO0 to interrupt on RxDone.
	spi_set_register(0x40, 0x00)
	--Set RXCONTINUOUS mode.
	spi_set_register(0x01, 0x05)
	current_mode = 0x05
end

function send_message(msg)
	if msg:len() > 255 then
		--Message is too long
		--print("can't send message - too long.")
		return false
	end
	if waiting_interrupt == 1 then
		--print("can't send message - transmit currently in progress.")
		return
	end
	--Set STDBY mode.
	spi_set_register(0x01, 0x01)
	--Set the FIFO address pointer to the start.
	spi_set_register(0x0D, 0x00)
	--Write the message into the FIFO buffer.
	spi_bulk_write(0x00, msg)
	--Set the message payload length register.
	spi_set_register(0x22, msg:len())
	--Set up DIO0 interrupt pin and set DIO0 to interrupt on TxDone.
	spi_set_register(0x40, 0x40)
	--Flag waiting for interrupt.
	waiting_interrupt = 1
	--Begin transmitting.
	spi_set_register(0x01, 0x03)
	current_mode = 0x03
end
