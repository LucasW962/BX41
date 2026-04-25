--!strict
--!native
--!optimize 2

const SHA256 = require("./SHA256")

const BLOCK_SIZE = 64

local function xor_with_byte(input: buffer, value: number): buffer
	local out = buffer.create(buffer.len(input))
	for i = 0, buffer.len(input) - 1 do
		buffer.writeu8(out, i, bit32.bxor(buffer.readu8(input, i), value))
	end
	return out
end

local function concat_buffers(left: buffer, right: buffer): buffer
	local out = buffer.create(buffer.len(left) + buffer.len(right))
	buffer.copy(out, 0, left, 0, buffer.len(left))
	buffer.copy(out, buffer.len(left), right, 0, buffer.len(right))
	return out
end

local function normalize_key(key: buffer): buffer
	local normalized = key
	if buffer.len(normalized) > BLOCK_SIZE then
		normalized = SHA256(normalized)
	end

	if buffer.len(normalized) == BLOCK_SIZE then
		return normalized
	end

	local padded = buffer.create(BLOCK_SIZE)
	buffer.copy(padded, 0, normalized, 0, buffer.len(normalized))
	return padded
end

local function sha256(key: buffer, message: buffer): buffer
	local block_key = normalize_key(key)
	local i_key_pad = xor_with_byte(block_key, 0x36)
	local o_key_pad = xor_with_byte(block_key, 0x5C)

	local inner = SHA256(concat_buffers(i_key_pad, message))
	return SHA256(concat_buffers(o_key_pad, inner))
end

return table.freeze({
	sha256 = sha256,
	HMAC = function(
		message: buffer,
		key: buffer,
		_blockSizeBytes: number, -- this was gonna be for smth, ignored
		_bigEndian: boolean? -- this was gonna be for smth, ignored
	): (string, buffer)
		return "HMAC-SHA256", sha256(key, message)
	end,
})
