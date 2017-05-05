waiting_interrupt = 0

function handle_dio0_interrupt(level, when)
	if waiting_interrupt == 0 then
		print("received DIO0 interrupt but was not expecting it.")
		return
	end
	--Don't bother getting IRQ flags, assume that all interrupts are TxDone.
	print("TxDone.")
	--Clear IRQ flags.
	spi_set_register(0x12, 0xFF)
	waiting_interrupt = 0
end

function init_rfm95w()
	--Set SLEEP and LoRa mode.
	spi_set_register(0x01, 0x80) -- LoRa + Sleep.

	tmr.delay(10000) --Wait 10ms.

	--Get mode, check mode.
	local cur_mode = spi_get_register(0x01)
	if cur_mode ~= 0x80 then
		print("LoRa module init failure.")
	end

	--Set base addresses of the FIFO buffer in both TX and RX cases to zero.
	spi_set_register(0x0E, 0x00)
	spi_set_register(0x0F, 0x00)
	
	--Set STDBY mode.
	spi_set_register(0x01, 0x01)

	--Configuration registers.
	spi_set_register(0x1D, 0x42) -- BW=31.25 kHz, CR=4/5, ImplicitHeaderModeOn=0.
	spi_set_register(0x1E, 0xB0) -- SF=11.
	spi_set_register(0x26, 0x04)

	--Set frequency to 915 MHz.
	spi_set_register(0x06, 0xE4)
	spi_set_register(0x07, 0xC0)
	spi_set_register(0x08, 0x00)

	--Set TX power to 20 dBm. Enable PA_BOOST.
	spi_set_register(0x09, 0x8F)
	--5.4.3. High Power +20 dBm Operation
	spi_set_register(0x4D, 0x87)
end

function send_message(msg)
	if msg:len() > 255 then
		--Message is too long
		print("can't send message - too long.")
		return false
	end
	if waiting_interrupt == 1 then
		print("can't send message - transmit currently in progress.")
		return
	end
	--Set pin connected to DIO0 to INT (interrupt) mode.
	gpio.mode(12, gpio.INT, gpio.PULLDOWN)
	gpio.trig(12, "up", handle_dio0_interrupt)
	--Set up DIO0 interrupt pin and set DIO0 to interrupt on TxDone.
	spi_set_register(0x40, 0x40)
	--Set STDBY mode.
	spi_set_register(0x01, 0x01)
	--Set the FIFO address pointer to the start.
	spi_set_register(0x0D, 0x00)
	--Write the message into the FIFO buffer.
	spi_bulk_write(0x00, msg)
	--Set the message payload length register.
	spi_set_register(0x22, msg:len())
	--Flag waiting for interrupt.
	waiting_interrupt = 1
	--Begin transmitting.
	spi_set_register(0x01, 0x03)
end
