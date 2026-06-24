---ShortModule in UtilitesModule
--[[
	Shortening module,
	
	Module.en(number) to shorten a number to a suffix
	Module.time(seconds) to get a string in the D/H/M/S format
]]

local Module = {}

Module.Prefixes = {"K","M","B","T","Qd","Qn","Sx","Sp","Oc","No",
	"De","UDe","DDe","TDe","QtDe","QnDe","SxDe","SpDe","OcDe","NoDe",
	"Vg","UVg","DVg","TVg","QdVg","QnVg","SxVg","SpVg","OcVg","NoVg",
	"Tg","UTg","DTg","TTg","QdTg","QnTg","SxTg","SpTg","OcTg","NoTg",
	"qg","Uqg","Dqg","Tqg","Qdqg","Qnqg","Sxqg","Spqg","Ocqg","Noqg",
	"Qg","UQg","DQg","TQg","QdQg","QnQg","SxQg","SpQg","OcQg","NoQg",
	"sg","Usg","Dsg","Tsg","Qdsg","Qnsg","Sxsg","Spsg","Ocsg","Nosg",
	"Sg","USg","DSg","TSg","QdSg","QnSg","SxSg","SpSg","OcSg","NoSg",
	"Og","UOg","DOg","TOg","QdOg","QnOg","SxOg","SpOg","OcOg","NoOg",
	"Ng","UNg","DNg","TNg","QdNg","QnNg","SxNg","SpNg","OcNg","NoNg",
	"Ce", "UCe"}


function Module.CutDigits(x)
	if x - math.floor(x) == 0 then return x end
	return string.format("%.2f", x)
end


function Module.en(number, digits)
	if number == 0 then return number end
	if number < 1 then return Module.CutDigits(number) end
	
	number = (number < 0 and math.abs(number)) or number
	digits = digits or 2
	
	local suffix = math.floor(math.log10(number)/3)
	
	return Module.CutDigits(number / 1000^(suffix)) .. ( Module.Prefixes[math.floor(suffix)] or "")
end

Module.time = function(val)
	if not tonumber(val) then return val end

	local days = math.floor(val / 86400)
	val = val - days * 86400

	local hours = math.floor(val / 3600)
	val = val - hours * 3600

	local mins = math.floor(val / 60)
	val = val - mins * 60

	val = val > 0 and " " .. math.floor(val) .. "s" or ""
	return (days > 0 and days .. "d" or "") .. (hours > 0 and " " .. hours .. "h" or "") .. (mins > 0 and " " .. mins .. "m" or "") .. val
end

Module.date = function(val)
	if not tonumber(val) then return val end
	
	local DateTable = os.date("!*t", val)
	local Months = {"Jan","Feb","Mar","Apr","May","Jun","Jul","Aug","Sep","Oct","Nov","Dec"}
	
	return DateTable.day.." "..Months[DateTable.month].." "..DateTable.year
end

Module.comma = function(value)
	value = tostring(value)
	return value:reverse():gsub("%d%d%d", "%1,"):reverse():gsub("^,", "")
end

return Module
