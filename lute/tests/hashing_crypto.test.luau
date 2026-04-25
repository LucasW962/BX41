--!strict

local test = require("@std/test")

local SHA256 = require("../../src/Hashing/SHA256")
local HMAC = require("../../src/Hashing/HMAC")

local function hex_to_nibble(ch: string): number
	local byte = string.byte(ch)
	if byte == nil then
		error("invalid hex input")
	end

	if byte >= string.byte("0") and byte <= string.byte("9") then
		return byte - string.byte("0")
	end

	if byte >= string.byte("a") and byte <= string.byte("f") then
		return byte - string.byte("a") + 10
	end

	if byte >= string.byte("A") and byte <= string.byte("F") then
		return byte - string.byte("A") + 10
	end

	error("invalid hex character")
end

local function hex_to_buffer(hex: string): buffer
	if #hex % 2 ~= 0 then
		error("hex string length must be even")
	end

	local out = buffer.create(#hex // 2)
	local write_index = 0
	for i = 1, #hex, 2 do
		local hi = hex_to_nibble(string.sub(hex, i, i))
		local lo = hex_to_nibble(string.sub(hex, i + 1, i + 1))
		buffer.writeu8(out, write_index, hi * 16 + lo)
		write_index += 1
	end

	return out
end

local HEX_ALPHABET = "0123456789abcdef"
local function buffer_to_hex(bytes: buffer): string
	local chunks = table.create(buffer.len(bytes) * 2)
	for i = 0, buffer.len(bytes) - 1 do
		local value = buffer.readu8(bytes, i)
		local hi = math.floor(value / 16) + 1
		local lo = (value % 16) + 1
		chunks[#chunks + 1] = string.sub(HEX_ALPHABET, hi, hi)
		chunks[#chunks + 1] = string.sub(HEX_ALPHABET, lo, lo)
	end
	return table.concat(chunks)
end

local function repeat_byte(byte_value: number, count: number): buffer
	local out = buffer.create(count)
	for i = 0, count - 1 do
		buffer.writeu8(out, i, byte_value)
	end
	return out
end

local function bitcount_u8(value: number): number
	local count = 0
	for bit = 0, 7 do
		if bit32.band(value, bit32.lshift(1, bit)) ~= 0 then
			count += 1
		end
	end
	return count
end

local function hamming_distance(left: buffer, right: buffer): number
	if buffer.len(left) ~= buffer.len(right) then
		error("hamming distance requires equal lengths")
	end

	local diff = 0
	for i = 0, buffer.len(left) - 1 do
		local x = bit32.bxor(buffer.readu8(left, i), buffer.readu8(right, i))
		diff += bitcount_u8(x)
	end
	return diff
end

test.suite("SHA256", function(suite)
	suite:case("empty string vector", function(asserts)
		local digest = SHA256(buffer.fromstring(""))
		asserts.eq("e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855", buffer_to_hex(digest))
	end)

	suite:case("abc vector", function(asserts)
		local digest = SHA256(buffer.fromstring("abc"))
		asserts.eq("ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad", buffer_to_hex(digest))
	end)

	suite:case("long NIST vector", function(asserts)
		local message = "abcdbcdecdefdefgefghfghighijhijkijkljklmklmnlmnomnopnopq"
		local digest = SHA256(buffer.fromstring(message))
		asserts.eq("248d6a61d20638b8e5c026930c3e6039a33ce45964ff2167f6ecedd419db06c1", buffer_to_hex(digest))
	end)

	suite:case("avalanche sanity", function(asserts)
		local left = SHA256(buffer.fromstring("abc"))
		local right = SHA256(buffer.fromstring("abd"))
		local distance = hamming_distance(left, right)
		asserts.eq(true, distance >= 80)
	end)
end)

test.suite("HMAC-SHA256", function(suite)
	suite:case("rfc4231 test case 1", function(asserts)
		local key = repeat_byte(0x0b, 20)
		local message = buffer.fromstring("Hi There")
		local digest = HMAC.sha256(key, message)
		asserts.eq("b0344c61d8db38535ca8afceaf0bf12b881dc200c9833da726e9376c2e32cff7", buffer_to_hex(digest))
	end)

	suite:case("rfc4231 test case 2", function(asserts)
		local key = buffer.fromstring("Jefe")
		local message = buffer.fromstring("what do ya want for nothing?")
		local digest = HMAC.sha256(key, message)
		asserts.eq("5bdcc146bf60754e6a042426089575c75a003f089d2739839dec58b964ec3843", buffer_to_hex(digest))
	end)

	suite:case("rfc4231 test case 3", function(asserts)
		local key = repeat_byte(0xaa, 20)
		local message = repeat_byte(0xdd, 50)
		local digest = HMAC.sha256(key, message)
		asserts.eq("773ea91e36800e46854db8ebd09181a72959098b3ef8c122d9635514ced565fe", buffer_to_hex(digest))
	end)

	suite:case("key longer than block size", function(asserts)
		local key = repeat_byte(0xaa, 131)
		local message = buffer.fromstring("Test Using Larger Than Block-Size Key - Hash Key First")
		local digest = HMAC.sha256(key, message)
		asserts.eq("60e431591ee0b67f0d8a26aacbf5b77f8e0bc6213728c5140546040f0ee37f54", buffer_to_hex(digest))
	end)

	suite:case("exports are consistent", function(asserts)
		local message = buffer.fromstring("consistency")
		local key = buffer.fromstring("secret")
		local algo, digest = HMAC.HMAC(message, key, 64)
		asserts.eq("HMAC-SHA256", algo)
		asserts.eq(buffer_to_hex(HMAC.sha256(key, message)), buffer_to_hex(digest))
	end)

	suite:case("avalanche sanity", function(asserts)
		local key = buffer.fromstring("secret")
		local left = HMAC.sha256(key, buffer.fromstring("abc"))
		local right = HMAC.sha256(key, buffer.fromstring("abd"))
		local distance = hamming_distance(left, right)
		asserts.eq(true, distance >= 80)
	end)
end)
