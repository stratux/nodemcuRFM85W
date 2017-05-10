--CS on GPIO2 (4).

--The spi.set_mosi() usage in spi_bulk_write requires the 'string write' currently only in the 'dev' branch of NodeMCU.
 
function spi_setup()
	--HSPI
	--FIXME:Is clock divider "10" valid?
	spi.setup(1, spi.MASTER, spi.CPOL_LOW, spi.CPHA_LOW, 8, 20, spi.FULLDUPLEX)
	gpio.mode(4, gpio.OUTPUT)
end

function spi_get_register(reg)
	gpio.write(4, gpio.LOW)
	local x = {spi.send(1, reg, 0x00)}
	gpio.write(4, gpio.HIGH)
	return x[3]
end

function spi_set_register(reg, val)
	gpio.write(4, gpio.LOW)
	local writeReg = BitOR(reg, 0x80)
	local x = {spi.send(1, writeReg, val)}
	gpio.write(4, gpio.HIGH)
	return x[3]
end

function spi_bulk_write(reg, vals)
	gpio.write(4, gpio.LOW)
	local vals = string.char(BitOR(reg, 0x80)) .. vals
	spi.set_mosi(1, vals)
	local bit_len = 8 * vals:len()
	spi.transaction(1, 0, 0, 0, 0, bit_len, 0, -1)
	gpio.write(4, gpio.HIGH)
	return
end
