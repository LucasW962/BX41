--!strict

local test = require("@std/test")
local fs = require("@std/fs")

local function read(path: string): string
	return fs.readFileToString(path)
end

local function contains(haystack: string, needle: string): boolean
	return string.find(haystack, needle, 1, true) ~= nil
end

local function count_occurrences(haystack: string, needle: string): number
	local count = 0
	local start = 1
	while true do
		local i = string.find(haystack, needle, start, true)
		if i == nil then
			return count
		end
		count += 1
		start = i + #needle
	end
end

local BX41_PATH = "src/BX41.luau"
local TYPES_PATH = "src/Types.luau"
local LOG_PATH = "src/Log.luau"

test.suite("BX41 Invariants", function(suite)
	suite:case("core module exists", function(asserts)
		asserts.eq(true, fs.exists(BX41_PATH))
	end)

	suite:case("uses Log module and not bare warn/error", function(asserts)
		local source = read(BX41_PATH)
		asserts.eq(true, contains(source, 'const Log: typeof(require("./Log")) = require("./Log")'))
		asserts.eq(false, contains(source, "\n\twarn("))
		asserts.eq(false, contains(source, "\n\terror("))
	end)

	suite:case("descriptor transport stays serializer-first", function(asserts)
		local source = read(BX41_PATH)
		asserts.eq(false, contains(source, 'type(raw_offset) == "number"'))
		asserts.eq(false, contains(source, "FireServer(routed_offset"))
		asserts.eq(false, contains(source, "FireClient(player, routed_offset"))
		asserts.eq(false, contains(source, "FireAllClients(routed_offset"))
		asserts.eq(false, contains(source, "InvokeServer(routed_offset"))
		asserts.eq(false, contains(source, "InvokeClient(player, routed_offset"))
	end)

	suite:case("offset and compact signed i8 serialization remain present", function(asserts)
		local source = read(BX41_PATH)
		asserts.eq(true, contains(source, "const TAG_I8 = 22"))
		asserts.eq(true, contains(source, "if is_integer(n) and n >= -0x80 and n <= 0x7F then"))
		asserts.eq(true, contains(source, "if tag == TAG_I8 then"))
		asserts.eq(true, contains(source, "make_offset_buffer(routed_offset)"))
	end)

	suite:case("integrity mode API and stream separation are present", function(asserts)
		local source = read(BX41_PATH)
		asserts.eq(true, contains(source, "const STREAM_EVENT = 1"))
		asserts.eq(true, contains(source, "const STREAM_FUNCTION = 2"))
		asserts.eq(true, contains(source, "const server_outbound_event_counters"))
		asserts.eq(true, contains(source, "const server_outbound_function_counters"))
		asserts.eq(true, contains(source, "setIntegrity = set_integrity"))
		asserts.eq(true, contains(source, "setIntegrity = router.setIntegrity"))
	end)

	suite:case("types expose setIntegrity", function(asserts)
		local source = read(TYPES_PATH)
		asserts.eq(true, contains(source, "setIntegrity: (secret: string | buffer?, tagBytes: number?) -> ()"))
	end)

	suite:case("logger warn export does not recurse", function(asserts)
		local source = read(LOG_PATH)
		asserts.eq(true, contains(source, "const function emit_warning(message: unknown)"))
		asserts.eq(true, contains(source, "warn(format(message))"))
		asserts.eq(true, contains(source, "warn = emit_warning"))
	end)
end)
