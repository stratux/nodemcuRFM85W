--FIXME. This configuration makes the serial port unusable while the GPS is connected.

function stringstarts(String, Start)
    return string.sub(String,1,string.len(Start))==Start
end

function stringends(String, End)
    return End=='' or string.sub(String,-string.len(End))==End
end

-- Sets up the standard UART for normal communications.
function reenable_standard_uart()
    uart.on("data") -- unregister callback function
    uart.alt(0)
    uart.setup(0, 115200, 8, uart.PARITY_NONE, uart.STOPBITS_1, 1)
end

-- Sets up the primary UART to receive the GPS data.
function setup_gps_uart()
    uart.alt(0)
    uart.setup(0, 9600, 8, uart.PARITY_NONE, uart.STOPBITS_1, 1)

    uart.on("data", "\n", receive_uart, 0)
end

-- Receives data from the GPS UART.
function receive_uart(data)
    if stringstarts(data, "$GP") then
        if parse_gps_string(data) then
            --GPS position has been obtained.
            --TODO: Send position.
            s = "pos:"..last_lat..","..last_lng
            send_message(s)
        end
    end
end

-- Modified from http://stackoverflow.com/a/7615129.
function mySplit(inputstr, sep)
    if sep == nil then
        sep = "%s"
    end
    local t={} ; i=1
    for str in string.gmatch(inputstr, "([^"..sep.."]*)("..sep.."?)") do
        t[i] = str
        i = i + 1
    end
    return t
end


--http://stackoverflow.com/a/25594410
local function bxor(a,b)--Bitwise xor
    local p,c=1,0
    while a>0 and b>0 do
        local ra,rb=a%2,b%2
        if ra~=rb then c=c+p end
        a,b,p=(a-ra)/2,(b-rb)/2,p*2
    end
    if a<b then a=b end
    while a>0 do
        local ra=a%2
        if ra>0 then c=c+p end
        a,p=(a-ra)/2,p*2
    end
    return c
end

function gps_crc(data)
    local n = 0
    for i = 1, #data do
        local b = data:byte(i)
        if b == 42 then
            -- Reached "*", end the CRC calc.
            return n
        end
        if b ~= 36 then
            -- Skip "$" characters, if any.
            n = bxor(n, b)
        end
    end
    return n
end

last_gprmc = ""
last_lat = 0.00
last_lng = 0.00

function parse_gps_string(data)
    if data:sub(1, 1) ~= "$" then
        --Invalid format
        return false
    end

    x = mySplit(data, ",")
    if #x < 2 then
        --Invalid format.
        return false
    end

    crc_x = mySplit(data, "*")

    if #crc_x < 2 then
        --No CRC or invalid format.
        return false
    end


    --CRC value is a hex value, convert to dec and compare.
    crc = tonumber(crc_x[#crc_x-1], 16)

    calculated_crc = gps_crc(data)

    if crc ~= calculated_crc then
        --CRC doesn't match.
        return false
    end

    --Parse the GPRMC line.
    if x[1] == "$GPRMC" then
        last_gprmc = data

		-- Parse the lat.
		local lat_raw = x[4]
		if lat_raw:len() < 10 then --String is too short.
			return false
		end
		local lat_hrs = tonumber(lat_raw:sub(1, 2), 10)
		local lat_min_f = tonumber(lat_raw:sub(3), 10)
		last_lat = lat_hrs + (lat_min_f/60.0)
		if x[5] == "S" then
			last_lat = -last_lat
		end
		
		--Parse the lng.
		local lng_raw = x[6]
		if lng_raw:len() < 11 then -- String is too short.
			return false
		end
		local lng_hrs = tonumber(lng_raw:sub(1, 3), 10)
		local lng_min_f = tonumber(lng_raw:sub(4), 10)
		last_lng = lng_hrs + (lng_min_f/60.0)
		if x[7] == "W" then
			last_lng = -last_lng
		end
        return true
    end

    return false
end
