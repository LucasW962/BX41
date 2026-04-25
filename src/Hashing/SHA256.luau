--!strict
--!native
--!optimize 2

local K = {
	0x428A2F98,
	0x71374491,
	0xB5C0FBCF,
	0xE9B5DBA5,
	0x3956C25B,
	0x59F111F1,
	0x923F82A4,
	0xAB1C5ED5,
	0xD807AA98,
	0x12835B01,
	0x243185BE,
	0x550C7DC3,
	0x72BE5D74,
	0x80DEB1FE,
	0x9BDC06A7,
	0xC19BF174,
	0xE49B69C1,
	0xEFBE4786,
	0x0FC19DC6,
	0x240CA1CC,
	0x2DE92C6F,
	0x4A7484AA,
	0x5CB0A9DC,
	0x76F988DA,
	0x983E5152,
	0xA831C66D,
	0xB00327C8,
	0xBF597FC7,
	0xC6E00BF3,
	0xD5A79147,
	0x06CA6351,
	0x14292967,
	0x27B70A85,
	0x2E1B2138,
	0x4D2C6DFC,
	0x53380D13,
	0x650A7354,
	0x766A0ABB,
	0x81C2C92E,
	0x92722C85,
	0xA2BFE8A1,
	0xA81A664B,
	0xC24B8B70,
	0xC76C51A3,
	0xD192E819,
	0xD6990624,
	0xF40E3585,
	0x106AA070,
	0x19A4C116,
	0x1E376C08,
	0x2748774C,
	0x34B0BCB5,
	0x391C0CB3,
	0x4ED8AA4A,
	0x5B9CCA4F,
	0x682E6FF3,
	0x748F82EE,
	0x78A5636F,
	0x84C87814,
	0x8CC70208,
	0x90BEFFFA,
	0xA4506CEB,
	0xBEF9A3F7,
	0xC67178F2,
}

local function rotr(x: number, n: number): number
	return bit32.bor(bit32.rshift(x, n), bit32.lshift(x, 32 - n))
end

local function ch(x: number, y: number, z: number): number
	return bit32.bxor(bit32.band(x, y), bit32.band(bit32.bnot(x), z))
end

local function maj(x: number, y: number, z: number): number
	return bit32.bxor(bit32.band(x, y), bit32.band(x, z), bit32.band(y, z))
end

local function big_sigma0(x: number): number
	return bit32.bxor(rotr(x, 2), rotr(x, 13), rotr(x, 22))
end

local function big_sigma1(x: number): number
	return bit32.bxor(rotr(x, 6), rotr(x, 11), rotr(x, 25))
end

local function small_sigma0(x: number): number
	return bit32.bxor(rotr(x, 7), rotr(x, 18), bit32.rshift(x, 3))
end

local function small_sigma1(x: number): number
	return bit32.bxor(rotr(x, 17), rotr(x, 19), bit32.rshift(x, 10))
end

local function concat_buffers(buffers: { buffer }): buffer
	local total = 0
	for _, b in buffers do
		total += buffer.len(b)
	end

	local out = buffer.create(total)
	local cursor = 0
	for _, b in buffers do
		local n = buffer.len(b)
		buffer.copy(out, cursor, b, 0, n)
		cursor += n
	end

	return out
end

local function read_u32_be(bytes: buffer, offset: number): number
	local b0 = buffer.readu8(bytes, offset)
	local b1 = buffer.readu8(bytes, offset + 1)
	local b2 = buffer.readu8(bytes, offset + 2)
	local b3 = buffer.readu8(bytes, offset + 3)
	return bit32.bor(bit32.lshift(b0, 24), bit32.lshift(b1, 16), bit32.lshift(b2, 8), b3)
end

local function write_u32_be(bytes: buffer, offset: number, value: number)
	buffer.writeu8(bytes, offset, bit32.band(bit32.rshift(value, 24), 0xFF))
	buffer.writeu8(bytes, offset + 1, bit32.band(bit32.rshift(value, 16), 0xFF))
	buffer.writeu8(bytes, offset + 2, bit32.band(bit32.rshift(value, 8), 0xFF))
	buffer.writeu8(bytes, offset + 3, bit32.band(value, 0xFF))
end

local function sha256(message: buffer): buffer
	local h0 = 0x6A09E667
	local h1 = 0xBB67AE85
	local h2 = 0x3C6EF372
	local h3 = 0xA54FF53A
	local h4 = 0x510E527F
	local h5 = 0x9B05688C
	local h6 = 0x1F83D9AB
	local h7 = 0x5BE0CD19

	local message_len = buffer.len(message)
	local bit_len = message_len * 8

	local one = buffer.create(1)
	buffer.writeu8(one, 0, 0x80)

	local mod_len = (message_len + 1) % 64
	local zero_pad_len = if mod_len <= 56 then (56 - mod_len) else (56 + 64 - mod_len)
	local zero_pad = buffer.create(zero_pad_len)

	local len_buf = buffer.create(8)
	local hi = math.floor(bit_len / 0x100000000)
	local lo = bit_len % 0x100000000
	write_u32_be(len_buf, 0, hi)
	write_u32_be(len_buf, 4, lo)

	local padded = concat_buffers({ message, one, zero_pad, len_buf })
	local total_len = buffer.len(padded)

	local w = table.create(64, 0)
	for chunk_start = 0, total_len - 1, 64 do
		for i = 0, 15 do
			w[i + 1] = read_u32_be(padded, chunk_start + i * 4)
		end

		for i = 17, 64 do
			local s0 = small_sigma0(w[i - 15])
			local s1 = small_sigma1(w[i - 2])
			w[i] = bit32.band(w[i - 16] + s0 + w[i - 7] + s1, 0xFFFFFFFF)
		end

		local a = h0
		local b = h1
		local c = h2
		local d = h3
		local e = h4
		local f = h5
		local g = h6
		local h = h7

		for i = 1, 64 do
			local t1 = bit32.band(h + big_sigma1(e) + ch(e, f, g) + K[i] + w[i], 0xFFFFFFFF)
			local t2 = bit32.band(big_sigma0(a) + maj(a, b, c), 0xFFFFFFFF)

			h = g
			g = f
			f = e
			e = bit32.band(d + t1, 0xFFFFFFFF)
			d = c
			c = b
			b = a
			a = bit32.band(t1 + t2, 0xFFFFFFFF)
		end

		h0 = bit32.band(h0 + a, 0xFFFFFFFF)
		h1 = bit32.band(h1 + b, 0xFFFFFFFF)
		h2 = bit32.band(h2 + c, 0xFFFFFFFF)
		h3 = bit32.band(h3 + d, 0xFFFFFFFF)
		h4 = bit32.band(h4 + e, 0xFFFFFFFF)
		h5 = bit32.band(h5 + f, 0xFFFFFFFF)
		h6 = bit32.band(h6 + g, 0xFFFFFFFF)
		h7 = bit32.band(h7 + h, 0xFFFFFFFF)
	end

	local out = buffer.create(32)
	write_u32_be(out, 0, h0)
	write_u32_be(out, 4, h1)
	write_u32_be(out, 8, h2)
	write_u32_be(out, 12, h3)
	write_u32_be(out, 16, h4)
	write_u32_be(out, 20, h5)
	write_u32_be(out, 24, h6)
	write_u32_be(out, 28, h7)
	return out
end

return sha256
