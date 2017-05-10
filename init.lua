dofile("bitops.lua")
dofile("spi.lua")
dofile("RFM95W.lua")
dofile("uart.lua")

spi_setup()
init_rfm95w()

--Comment this out for dev.
--TODO: Detect if the peripheral board is connected.
setup_gps_uart()

