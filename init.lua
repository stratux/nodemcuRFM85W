dofile("bitops.lua")
dofile("spi.lua")
dofile("RFM95W.lua")
dofile("uart.lua")

spi_setup()
init_rfm95w()

--Comment this out for dev.
--TODO: Detect if the peripheral board is connected.

tmr.alarm(2, 10000, tmr.ALARM_SINGLE, function()
	setup_gps_uart()
end)
