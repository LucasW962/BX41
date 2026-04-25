--!strict
--!native
--!optimize 2

const ReplicatedStorage = game:GetService("ReplicatedStorage")
const RunService = game:GetService("RunService")
const Players = game:GetService("Players")

const Types = require("./Types")
const Log = require("./Log")
const HMAC = require("./Hashing/HMAC")

type Channel = Types.Channel
type Disconnectable = Types.Disconnectable
type Serializable = Types.Serializable
type SerializableDescriptor = Types.SerializableDescriptor
type BX41 = Types.BX41
type BX41Module = Types.BX41Module

type PackedUnknownTuple = { [number]: unknown, n: number }
type PackedSerializableTuple = { [number]: Serializable, n: number }

type EventServerHandler = (player: Player, ...Serializable) -> ()
type EventClientHandler = (...Serializable) -> ()
type FunctionServerHandler = (player: Player, ...Serializable) -> ...Serializable
type FunctionClientHandler = (...Serializable) -> ...Serializable

const DEFAULT_REMOTE_EVENT_NAME = "BX41_RE"
const DEFAULT_REMOTE_FUNCTION_NAME = "BX41_RF"

const CHANNEL_SERVER = "Server"
const CHANNEL_CLIENT = "Client"
const CHANNEL_BOTH = "Both"

const DEFAULT_INTEGRITY_TAG_BYTES = 4
const MIN_INTEGRITY_TAG_BYTES = 2
const MAX_INTEGRITY_TAG_BYTES = 16
const U16_MODULUS = 0x10000
const STREAM_EVENT = 1
const STREAM_FUNCTION = 2

const VALID_SERIALIZABLE_DESCRIPTORS = table.freeze({
	["nil"] = true,
	boolean = true,
	buffer = true,
	number = true,
	string = true,
	table = true,
	Instance = true,
	Vector3 = true,
	Vector2 = true,
	CFrame = true,
	Color3 = true,
	BrickColor = true,
	Region3 = true,
	EnumItem = true,
	UDim = true,
	UDim2 = true,
	TweenInfo = true,
})

const function normalize_channel(channel: unknown): Channel
	if channel == CHANNEL_SERVER then
		return CHANNEL_SERVER
	end

	if channel == CHANNEL_CLIENT then
		return CHANNEL_CLIENT
	end

	if channel == CHANNEL_BOTH or channel == nil then
		return CHANNEL_BOTH
	end

	Log.panic(`invalid channel '{tostring(channel)}', expected 'Server', 'Client', or 'Both'`, 3)
	return CHANNEL_BOTH
end

const function describe(value: unknown): string
	if value == nil then
		return "nil"
	end

	const valueType = typeof(value)
	if valueType == "buffer" then
		return `buffer({buffer.len(value :: buffer)} bytes)`
	end

	return valueType
end

const function _to_u8(offset: number): number
	if offset ~= math.floor(offset) then
		Log.panic(`offset must be an integer in [0, 255], got {offset}`, 3)
	end

	if offset < 0 or offset > 255 then
		Log.panic(`offset must be in [0, 255], got {offset}`, 3)
	end

	return bit32.band(offset, 0xFF)
end

const function make_offset_buffer(offset: number): buffer
	const out = buffer.create(1)
	buffer.writeu8(out, 0, _to_u8(offset))
	return out
end

const function parse_offset(value: unknown): number?
	if typeof(value) == "buffer" then
		const bytes = value :: buffer
		if buffer.len(bytes) ~= 1 then
			return nil
		end

		return buffer.readu8(bytes, 0)
	end

	if type(value) == "number" then
		if value ~= math.floor(value) then
			return nil
		end
		if value < 0 or value > 255 then
			return nil
		end
		return bit32.band(value, 0xFF)
	end

	return nil
end

const function normalize_descriptor_token(token: unknown): SerializableDescriptor?
	if type(token) == "string" then
		if (VALID_SERIALIZABLE_DESCRIPTORS :: any)[token] then
			return token :: SerializableDescriptor
		end
		return nil
	end

	if type(token) ~= "table" then
		return nil
	end

	const descriptor = (token :: any)._descriptor
	if type(descriptor) ~= "string" then
		return nil
	end

	if not (VALID_SERIALIZABLE_DESCRIPTORS :: any)[descriptor] then
		return nil
	end

	return descriptor :: SerializableDescriptor
end

const function parse_descriptors(kind: string, descriptor_tokens: PackedUnknownTuple): { SerializableDescriptor }?
	if descriptor_tokens.n == 0 then
		return nil
	end

	local descriptors = table.create(descriptor_tokens.n) :: { SerializableDescriptor }
	for i = 1, descriptor_tokens.n do
		const descriptor = normalize_descriptor_token(descriptor_tokens[i])
		if descriptor == nil then
			Log.panic(`{kind} descriptor #{i} is invalid`, 3)
		end

		descriptors[i] = descriptor
	end

	return descriptors
end

const DESCRIPTOR_MATCHERS = table.freeze({
	["nil"] = function(value: unknown): boolean
		return value == nil
	end,
	boolean = function(value: unknown): boolean
		return type(value) == "boolean"
	end,
	number = function(value: unknown): boolean
		return type(value) == "number"
	end,
	string = function(value: unknown): boolean
		return type(value) == "string"
	end,
	table = function(value: unknown): boolean
		return type(value) == "table"
	end,
	buffer = function(value: unknown): boolean
		return typeof(value) == "buffer"
	end,
	Instance = function(value: unknown): boolean
		return typeof(value) == "Instance"
	end,
	Vector3 = function(value: unknown): boolean
		return typeof(value) == "Vector3"
	end,
	Vector2 = function(value: unknown): boolean
		return typeof(value) == "Vector2"
	end,
	CFrame = function(value: unknown): boolean
		return typeof(value) == "CFrame"
	end,
	Color3 = function(value: unknown): boolean
		return typeof(value) == "Color3"
	end,
	BrickColor = function(value: unknown): boolean
		return typeof(value) == "BrickColor"
	end,
	Region3 = function(value: unknown): boolean
		return typeof(value) == "Region3"
	end,
	EnumItem = function(value: unknown): boolean
		return typeof(value) == "EnumItem"
	end,
	UDim = function(value: unknown): boolean
		return typeof(value) == "UDim"
	end,
	UDim2 = function(value: unknown): boolean
		return typeof(value) == "UDim2"
	end,
	TweenInfo = function(value: unknown): boolean
		return typeof(value) == "TweenInfo"
	end,
})

const function value_matches_descriptor(value: unknown, descriptor: SerializableDescriptor): boolean
	const matcher = (DESCRIPTOR_MATCHERS :: any)[descriptor] :: ((unknown) -> boolean)?
	if matcher == nil then
		return false
	end

	return matcher(value)
end

const function assert_descriptor_values(
	values: PackedSerializableTuple,
	descriptors: { SerializableDescriptor },
	context: string
)
	if values.n ~= #descriptors then
		Log.panic(`{context} expected {#descriptors} arguments, got {values.n}`, 3)
	end

	for i = 1, values.n do
		const descriptor = descriptors[i]
		const value = values[i]
		if not value_matches_descriptor(value, descriptor) then
			Log.panic(`{context} argument #{i} expected {descriptor}, got {describe(value)}`, 3)
		end
	end
end

const TAG_NIL = 0
const TAG_FALSE = 1
const TAG_TRUE = 2
const TAG_U8 = 3
const TAG_I8 = 22
const TAG_I16 = 4
const TAG_I32 = 5
const TAG_F64 = 6
const TAG_STRING = 7
const TAG_BUFFER = 8
const TAG_ARRAY = 9
const TAG_MAP = 10
const TAG_VECTOR2 = 11
const TAG_VECTOR3 = 12
const TAG_CFRAME = 13
const TAG_COLOR3 = 14
const TAG_UDIM = 15
const TAG_UDIM2 = 16
const TAG_REGION3 = 17
const TAG_INSTANCE = 18
const TAG_ENUM_ITEM = 19
const TAG_BRICK_COLOR = 20
const TAG_TWEEN_INFO = 21

const function concat_buffers(parts: { buffer }): buffer
	local total = 0
	for _, part in parts do
		total += buffer.len(part)
	end

	const out = buffer.create(total)
	local cursor = 0
	for _, part in parts do
		const part_len = buffer.len(part)
		buffer.copy(out, cursor, part, 0, part_len)
		cursor += part_len
	end

	return out
end

const function make_u8(value: number): buffer
	const out = buffer.create(1)
	buffer.writeu8(out, 0, value)
	return out
end

const function make_i8(value: number): buffer
	const out = buffer.create(1)
	buffer.writeu8(out, 0, bit32.band(value, 0xFF))
	return out
end

const function make_u32(value: number): buffer
	const out = buffer.create(4)
	buffer.writeu32(out, 0, value)
	return out
end

const function make_i16(value: number): buffer
	const out = buffer.create(2)
	buffer.writeu16(out, 0, bit32.band(value, 0xFFFF))
	return out
end

const function make_i32(value: number): buffer
	const out = buffer.create(4)
	buffer.writeu32(out, 0, bit32.band(value, 0xFFFFFFFF))
	return out
end

const function make_f64(value: number): buffer
	const out = buffer.create(8)
	buffer.writef64(out, 0, value)
	return out
end

const function make_f32(value: number): buffer
	const out = buffer.create(4)
	buffer.writef32(out, 0, value)
	return out
end

const function read_i16(packet: buffer, offset: number): number
	const raw = buffer.readu16(packet, offset)
	if raw >= 0x8000 then
		return raw - 0x10000
	end
	return raw
end

const function read_i32(packet: buffer, offset: number): number
	const raw = buffer.readu32(packet, offset)
	if raw >= 0x80000000 then
		return raw - 0x100000000
	end
	return raw
end

const function read_i8(packet: buffer, offset: number): number
	const raw = buffer.readu8(packet, offset)
	if raw >= 0x80 then
		return raw - 0x100
	end
	return raw
end

const function is_integer(value: number): boolean
	return value == math.floor(value)
end

const function require_room(packet: buffer, cursor: number, amount: number): boolean
	return cursor + amount <= buffer.len(packet)
end

const function make_i32_from_signed(value: number): buffer
	const out = buffer.create(4)
	buffer.writei32(out, 0, value)
	return out
end

const function make_u16(value: number): buffer
	const out = buffer.create(2)
	buffer.writeu16(out, 0, value)
	return out
end

const function normalize_integrity_key(secret: unknown): buffer?
	if secret == nil then
		return nil
	end

	if typeof(secret) == "buffer" then
		const key = secret :: buffer
		if buffer.len(key) == 0 then
			Log.panic("setIntegrity key buffer must not be empty", 3)
		end
		return key
	end

	if type(secret) == "string" then
		if #secret == 0 then
			Log.panic("setIntegrity key string must not be empty", 3)
		end
		return buffer.fromstring(secret)
	end

	Log.panic("setIntegrity key must be string, buffer, or nil", 3)
	return nil
end

const function next_u16(counter: number): number
	local next_counter = counter + 1
	if next_counter >= U16_MODULUS then
		next_counter = 0
	end
	return next_counter
end

const function copy_buffer_range(source: buffer, start: number, length: number): buffer
	const out = buffer.create(length)
	if length > 0 then
		buffer.copy(out, 0, source, start, length)
	end
	return out
end

const function buffers_equal(left: buffer, right: buffer): boolean
	const left_len = buffer.len(left)
	if left_len ~= buffer.len(right) then
		return false
	end

	local diff = 0
	for i = 0, left_len - 1 do
		diff = bit32.bor(diff, bit32.bxor(buffer.readu8(left, i), buffer.readu8(right, i)))
	end

	return diff == 0
end

const function compute_integrity_tag(
	offset: number,
	counter: number,
	payload: buffer,
	key: buffer,
	tag_bytes: number
): buffer
	const mac_input = concat_buffers({ make_u8(_to_u8(offset)), make_u16(counter), payload })
	const digest = HMAC.sha256(key, mac_input)
	return copy_buffer_range(digest, 0, tag_bytes)
end

const function wrap_integrity_payload(
	offset: number,
	payload: buffer,
	key: buffer,
	counter: number,
	tag_bytes: number
): buffer
	const counter_buf = make_u16(counter)
	const tag = compute_integrity_tag(offset, counter, payload, key, tag_bytes)
	return concat_buffers({ counter_buf, payload, tag })
end

const function unwrap_integrity_payload(
	offset: number,
	framed: buffer,
	key: buffer,
	tag_bytes: number
): (buffer?, number?)
	const framed_len = buffer.len(framed)
	if framed_len < 2 + tag_bytes then
		return nil, nil
	end

	const counter = buffer.readu16(framed, 0)
	const payload_len = framed_len - 2 - tag_bytes
	const payload = copy_buffer_range(framed, 2, payload_len)
	const incoming_tag = copy_buffer_range(framed, 2 + payload_len, tag_bytes)
	const expected_tag = compute_integrity_tag(offset, counter, payload, key, tag_bytes)
	if not buffers_equal(incoming_tag, expected_tag) then
		return nil, nil
	end

	return payload, counter
end

const function parse_enum_item(path: string): EnumItem?
	local first_dot = string.find(path, ".", 1, true)
	if first_dot == nil then
		return nil
	end

	local second_dot = string.find(path, ".", first_dot + 1, true)
	if second_dot == nil then
		return nil
	end

	const enum_name = string.sub(path, first_dot + 1, second_dot - 1)
	const item_name = string.sub(path, second_dot + 1)
	const enum_table = (Enum :: any)[enum_name]
	if enum_table == nil then
		return nil
	end

	const item = enum_table[item_name]
	if typeof(item) ~= "EnumItem" then
		return nil
	end

	return item :: EnumItem
end

const function write_value(
	parts: { buffer },
	value: unknown,
	seen: { [any]: true },
	instances: { Instance },
	context: string
)
	if value == nil then
		table.insert(parts, make_u8(TAG_NIL))
		return
	end

	const kind = typeof(value)
	if kind == "boolean" then
		table.insert(parts, make_u8(if value :: boolean then TAG_TRUE else TAG_FALSE))
		return
	end

	if kind == "number" then
		const n = value :: number
		if is_integer(n) and n >= 0 and n <= 0xFF then
			table.insert(parts, make_u8(TAG_U8))
			table.insert(parts, make_u8(n))
			return
		end

		if is_integer(n) and n >= -0x80 and n <= 0x7F then
			table.insert(parts, make_u8(TAG_I8))
			table.insert(parts, make_i8(n))
			return
		end

		if is_integer(n) and n >= -0x8000 and n <= 0x7FFF then
			table.insert(parts, make_u8(TAG_I16))
			table.insert(parts, make_i16(n))
			return
		end

		if is_integer(n) and n >= -0x80000000 and n <= 0x7FFFFFFF then
			table.insert(parts, make_u8(TAG_I32))
			table.insert(parts, make_i32(n))
			return
		end

		table.insert(parts, make_u8(TAG_F64))
		table.insert(parts, make_f64(n))
		return
	end

	if kind == "string" then
		const string_buf = buffer.fromstring(value :: string)
		table.insert(parts, make_u8(TAG_STRING))
		table.insert(parts, make_u32(buffer.len(string_buf)))
		table.insert(parts, string_buf)
		return
	end

	if kind == "buffer" then
		const bytes = value :: buffer
		table.insert(parts, make_u8(TAG_BUFFER))
		table.insert(parts, make_u32(buffer.len(bytes)))
		table.insert(parts, bytes)
		return
	end

	if kind == "Vector2" then
		const v = value :: Vector2
		table.insert(parts, make_u8(TAG_VECTOR2))
		table.insert(parts, make_f32(v.X))
		table.insert(parts, make_f32(v.Y))
		return
	end

	if kind == "Vector3" then
		const v = value :: Vector3
		table.insert(parts, make_u8(TAG_VECTOR3))
		table.insert(parts, make_f32(v.X))
		table.insert(parts, make_f32(v.Y))
		table.insert(parts, make_f32(v.Z))
		return
	end

	if kind == "CFrame" then
		const cf = value :: CFrame
		const x, y, z, r00, r01, r02, r10, r11, r12, r20, r21, r22 = cf:GetComponents()
		table.insert(parts, make_u8(TAG_CFRAME))
		table.insert(parts, make_f32(x))
		table.insert(parts, make_f32(y))
		table.insert(parts, make_f32(z))
		table.insert(parts, make_f32(r00))
		table.insert(parts, make_f32(r01))
		table.insert(parts, make_f32(r02))
		table.insert(parts, make_f32(r10))
		table.insert(parts, make_f32(r11))
		table.insert(parts, make_f32(r12))
		table.insert(parts, make_f32(r20))
		table.insert(parts, make_f32(r21))
		table.insert(parts, make_f32(r22))
		return
	end

	if kind == "Color3" then
		const c = value :: Color3
		table.insert(parts, make_u8(TAG_COLOR3))
		table.insert(parts, make_f32(c.R))
		table.insert(parts, make_f32(c.G))
		table.insert(parts, make_f32(c.B))
		return
	end

	if kind == "UDim" then
		const u = value :: UDim
		table.insert(parts, make_u8(TAG_UDIM))
		table.insert(parts, make_f32(u.Scale))
		table.insert(parts, make_i32_from_signed(u.Offset))
		return
	end

	if kind == "UDim2" then
		const u = value :: UDim2
		table.insert(parts, make_u8(TAG_UDIM2))
		table.insert(parts, make_f32(u.X.Scale))
		table.insert(parts, make_i32_from_signed(u.X.Offset))
		table.insert(parts, make_f32(u.Y.Scale))
		table.insert(parts, make_i32_from_signed(u.Y.Offset))
		return
	end

	if kind == "Region3" then
		const r = value :: Region3
		const min = r.CFrame.Position - (r.Size / 2)
		const max = r.CFrame.Position + (r.Size / 2)
		table.insert(parts, make_u8(TAG_REGION3))
		table.insert(parts, make_f32(min.X))
		table.insert(parts, make_f32(min.Y))
		table.insert(parts, make_f32(min.Z))
		table.insert(parts, make_f32(max.X))
		table.insert(parts, make_f32(max.Y))
		table.insert(parts, make_f32(max.Z))
		return
	end

	if kind == "Instance" then
		table.insert(parts, make_u8(TAG_INSTANCE))
		table.insert(instances, value :: Instance)
		table.insert(parts, make_u32(#instances))
		return
	end

	if kind == "EnumItem" then
		const enum_path = tostring(value)
		const encoded = buffer.fromstring(enum_path)
		table.insert(parts, make_u8(TAG_ENUM_ITEM))
		table.insert(parts, make_u32(buffer.len(encoded)))
		table.insert(parts, encoded)
		return
	end

	if kind == "BrickColor" then
		table.insert(parts, make_u8(TAG_BRICK_COLOR))
		table.insert(parts, make_u16((value :: BrickColor).Number))
		return
	end

	if kind == "TweenInfo" then
		const tween = value :: TweenInfo
		const style = buffer.fromstring(tostring(tween.EasingStyle))
		const direction = buffer.fromstring(tostring(tween.EasingDirection))

		table.insert(parts, make_u8(TAG_TWEEN_INFO))
		table.insert(parts, make_f64(tween.Time))
		table.insert(parts, make_u32(buffer.len(style)))
		table.insert(parts, style)
		table.insert(parts, make_u32(buffer.len(direction)))
		table.insert(parts, direction)
		table.insert(parts, make_i32_from_signed(tween.RepeatCount))
		table.insert(parts, make_u8(if tween.Reverses then 1 else 0))
		table.insert(parts, make_f64(tween.DelayTime))
		return
	end

	if kind ~= "table" then
		Log.panic(`{context} unsupported payload type {describe(value)}`, 3)
	end

	const source = value :: { [unknown]: unknown }
	if seen[source] then
		Log.panic(`{context} cyclic table payloads are not supported`, 3)
	end
	seen[source] = true

	local array_len = 0
	local is_array = true
	for key in source do
		if type(key) ~= "number" or key ~= math.floor(key) or key < 1 then
			is_array = false
			break
		end
		if key > array_len then
			array_len = key
		end
	end

	if is_array then
		for i = 1, array_len do
			if source[i] == nil then
				is_array = false
				break
			end
		end
	end

	if is_array then
		table.insert(parts, make_u8(TAG_ARRAY))
		table.insert(parts, make_u32(array_len))
		for i = 1, array_len do
			write_value(parts, source[i], seen, instances, context)
		end
		seen[source] = nil
		return
	end

	local pair_count = 0
	for _ in source do
		pair_count += 1
	end

	table.insert(parts, make_u8(TAG_MAP))
	table.insert(parts, make_u32(pair_count))
	for key, item in source do
		write_value(parts, key, seen, instances, context)
		write_value(parts, item, seen, instances, context)
	end

	seen[source] = nil
end

const function read_value(
	packet: buffer,
	cursor_ref: { index: number },
	instances: { Instance }
): (boolean, Serializable?)
	local cursor = cursor_ref.index
	if not require_room(packet, cursor, 1) then
		return false, nil
	end

	const tag = buffer.readu8(packet, cursor)
	cursor += 1

	if tag == TAG_NIL then
		cursor_ref.index = cursor
		return true, nil
	end

	if tag == TAG_FALSE then
		cursor_ref.index = cursor
		return true, false
	end

	if tag == TAG_TRUE then
		cursor_ref.index = cursor
		return true, true
	end

	if tag == TAG_U8 then
		if not require_room(packet, cursor, 1) then
			return false, nil
		end
		const value = buffer.readu8(packet, cursor)
		cursor_ref.index = cursor + 1
		return true, value
	end

	if tag == TAG_I8 then
		if not require_room(packet, cursor, 1) then
			return false, nil
		end
		const value = read_i8(packet, cursor)
		cursor_ref.index = cursor + 1
		return true, value
	end

	if tag == TAG_I16 then
		if not require_room(packet, cursor, 2) then
			return false, nil
		end
		const value = read_i16(packet, cursor)
		cursor_ref.index = cursor + 2
		return true, value
	end

	if tag == TAG_I32 then
		if not require_room(packet, cursor, 4) then
			return false, nil
		end
		const value = read_i32(packet, cursor)
		cursor_ref.index = cursor + 4
		return true, value
	end

	if tag == TAG_F64 then
		if not require_room(packet, cursor, 8) then
			return false, nil
		end
		const value = buffer.readf64(packet, cursor)
		cursor_ref.index = cursor + 8
		return true, value
	end

	if tag == TAG_STRING or tag == TAG_BUFFER then
		if not require_room(packet, cursor, 4) then
			return false, nil
		end
		const len = buffer.readu32(packet, cursor)
		cursor += 4
		if not require_room(packet, cursor, len) then
			return false, nil
		end

		const bytes = buffer.create(len)
		if len > 0 then
			buffer.copy(bytes, 0, packet, cursor, len)
		end
		cursor += len
		cursor_ref.index = cursor

		if tag == TAG_STRING then
			return true, buffer.tostring(bytes)
		end
		return true, bytes
	end

	if tag == TAG_VECTOR2 then
		if not require_room(packet, cursor, 8) then
			return false, nil
		end
		const x = buffer.readf32(packet, cursor)
		const y = buffer.readf32(packet, cursor + 4)
		cursor_ref.index = cursor + 8
		return true, Vector2.new(x, y)
	end

	if tag == TAG_VECTOR3 then
		if not require_room(packet, cursor, 12) then
			return false, nil
		end
		const x = buffer.readf32(packet, cursor)
		const y = buffer.readf32(packet, cursor + 4)
		const z = buffer.readf32(packet, cursor + 8)
		cursor_ref.index = cursor + 12
		return true, Vector3.new(x, y, z)
	end

	if tag == TAG_CFRAME then
		if not require_room(packet, cursor, 48) then
			return false, nil
		end

		const x = buffer.readf32(packet, cursor)
		const y = buffer.readf32(packet, cursor + 4)
		const z = buffer.readf32(packet, cursor + 8)
		const r00 = buffer.readf32(packet, cursor + 12)
		const r01 = buffer.readf32(packet, cursor + 16)
		const r02 = buffer.readf32(packet, cursor + 20)
		const r10 = buffer.readf32(packet, cursor + 24)
		const r11 = buffer.readf32(packet, cursor + 28)
		const r12 = buffer.readf32(packet, cursor + 32)
		const r20 = buffer.readf32(packet, cursor + 36)
		const r21 = buffer.readf32(packet, cursor + 40)
		const r22 = buffer.readf32(packet, cursor + 44)

		cursor_ref.index = cursor + 48
		return true, CFrame.new(x, y, z, r00, r01, r02, r10, r11, r12, r20, r21, r22)
	end

	if tag == TAG_COLOR3 then
		if not require_room(packet, cursor, 12) then
			return false, nil
		end
		const r = buffer.readf32(packet, cursor)
		const g = buffer.readf32(packet, cursor + 4)
		const b = buffer.readf32(packet, cursor + 8)
		cursor_ref.index = cursor + 12
		return true, Color3.new(r, g, b)
	end

	if tag == TAG_UDIM then
		if not require_room(packet, cursor, 8) then
			return false, nil
		end
		const scale = buffer.readf32(packet, cursor)
		const offset = buffer.readi32(packet, cursor + 4)
		cursor_ref.index = cursor + 8
		return true, UDim.new(scale, offset)
	end

	if tag == TAG_UDIM2 then
		if not require_room(packet, cursor, 16) then
			return false, nil
		end
		const xs = buffer.readf32(packet, cursor)
		const xo = buffer.readi32(packet, cursor + 4)
		const ys = buffer.readf32(packet, cursor + 8)
		const yo = buffer.readi32(packet, cursor + 12)
		cursor_ref.index = cursor + 16
		return true, UDim2.new(xs, xo, ys, yo)
	end

	if tag == TAG_REGION3 then
		if not require_room(packet, cursor, 24) then
			return false, nil
		end
		const min = Vector3.new(
			buffer.readf32(packet, cursor),
			buffer.readf32(packet, cursor + 4),
			buffer.readf32(packet, cursor + 8)
		)
		const max = Vector3.new(
			buffer.readf32(packet, cursor + 12),
			buffer.readf32(packet, cursor + 16),
			buffer.readf32(packet, cursor + 20)
		)
		cursor_ref.index = cursor + 24
		return true, Region3.new(min, max)
	end

	if tag == TAG_INSTANCE then
		if not require_room(packet, cursor, 4) then
			return false, nil
		end
		const instance_index = buffer.readu32(packet, cursor)
		cursor_ref.index = cursor + 4
		const instance = instances[instance_index]
		if instance == nil then
			return false, nil
		end
		return true, instance
	end

	if tag == TAG_ENUM_ITEM then
		if not require_room(packet, cursor, 4) then
			return false, nil
		end
		const len = buffer.readu32(packet, cursor)
		cursor += 4
		if not require_room(packet, cursor, len) then
			return false, nil
		end
		const enum_path = buffer.readstring(packet, cursor, len)
		cursor_ref.index = cursor + len
		const item = parse_enum_item(enum_path)
		if item == nil then
			return false, nil
		end
		return true, item
	end

	if tag == TAG_BRICK_COLOR then
		if not require_room(packet, cursor, 2) then
			return false, nil
		end
		const number = buffer.readu16(packet, cursor)
		cursor_ref.index = cursor + 2
		return true, BrickColor.new(number)
	end

	if tag == TAG_TWEEN_INFO then
		if not require_room(packet, cursor, 8 + 4) then
			return false, nil
		end

		const time = buffer.readf64(packet, cursor)
		cursor += 8
		const style_len = buffer.readu32(packet, cursor)
		cursor += 4
		if not require_room(packet, cursor, style_len + 4) then
			return false, nil
		end
		const style_path = buffer.readstring(packet, cursor, style_len)
		cursor += style_len

		const dir_len = buffer.readu32(packet, cursor)
		cursor += 4
		if not require_room(packet, cursor, dir_len + 4 + 1 + 8) then
			return false, nil
		end
		const dir_path = buffer.readstring(packet, cursor, dir_len)
		cursor += dir_len

		const repeat_count = buffer.readi32(packet, cursor)
		cursor += 4
		const reverses = buffer.readu8(packet, cursor) == 1
		cursor += 1
		const delay_time = buffer.readf64(packet, cursor)
		cursor += 8
		cursor_ref.index = cursor

		const style_item = parse_enum_item(style_path)
		const dir_item = parse_enum_item(dir_path)
		if style_item == nil or dir_item == nil then
			return false, nil
		end

		if style_item.EnumType ~= Enum.EasingStyle or dir_item.EnumType ~= Enum.EasingDirection then
			return false, nil
		end

		return true, TweenInfo.new(
			time,
			style_item :: Enum.EasingStyle,
			dir_item :: Enum.EasingDirection,
			repeat_count,
			reverses,
			delay_time
		)
	end

	if tag == TAG_ARRAY then
		if not require_room(packet, cursor, 4) then
			return false, nil
		end
		const len = buffer.readu32(packet, cursor)
		cursor += 4

		const out = table.create(len) :: { Serializable }
		const nested_cursor = { index = cursor }
		for i = 1, len do
			const ok, value = read_value(packet, nested_cursor, instances)
			if not ok then
				return false, nil
			end
			out[i] = value :: Serializable
		end

		cursor_ref.index = nested_cursor.index
		return true, out
	end

	if tag == TAG_MAP then
		if not require_room(packet, cursor, 4) then
			return false, nil
		end
		const len = buffer.readu32(packet, cursor)
		cursor += 4

		const out = {} :: { [Serializable]: Serializable }
		const nested_cursor = { index = cursor }
		for _ = 1, len do
			const ok_key, key = read_value(packet, nested_cursor, instances)
			if not ok_key then
				return false, nil
			end

			const ok_value, item = read_value(packet, nested_cursor, instances)
			if not ok_value then
				return false, nil
			end

			if key == nil then
				return false, nil
			end

			out[key :: Serializable] = item :: Serializable
		end

		cursor_ref.index = nested_cursor.index
		return true, out
	end

	return false, nil
end

const function serialize_tuple(values: PackedSerializableTuple, context: string): (buffer, { Instance }?)
	if values.n > 255 then
		Log.panic(`{context} supports at most 255 tuple values, got {values.n}`, 3)
	end

	const parts = table.create(1 + values.n * 2) :: { buffer }
	table.insert(parts, make_u8(values.n))

	const seen = {} :: { [any]: true }
	const instances = {} :: { Instance }
	for i = 1, values.n do
		write_value(parts, values[i], seen, instances, `{context} tuple index {i}`)
	end

	const packet = concat_buffers(parts)
	if #instances == 0 then
		return packet, nil
	end

	return packet, instances
end

const function deserialize_tuple(raw_payload: unknown, raw_instances: unknown): PackedSerializableTuple?
	if typeof(raw_payload) ~= "buffer" then
		return nil
	end

	const packet = raw_payload :: buffer
	if buffer.len(packet) < 1 then
		return nil
	end

	local instances = {} :: { Instance }
	if raw_instances ~= nil then
		if type(raw_instances) ~= "table" then
			return nil
		end

		const incoming = raw_instances :: { unknown }
		local parsed = {} :: { Instance }
		for i = 1, #incoming do
			const instance = incoming[i]
			if typeof(instance) ~= "Instance" then
				return nil
			end
			parsed[i] = instance :: Instance
		end

		instances = parsed
	end

	const count = buffer.readu8(packet, 0)
	const cursor = { index = 1 }
	const out = table.create(count) :: PackedSerializableTuple
	out.n = count

	for i = 1, count do
		const ok, value = read_value(packet, cursor, instances)
		if not ok then
			return nil
		end
		out[i] = value :: Serializable
	end

	if cursor.index ~= buffer.len(packet) then
		return nil
	end

	return out
end

const function get_or_create_remote_event(name: string): RemoteEvent
	const existing = ReplicatedStorage:FindFirstChild(name)
	if existing ~= nil then
		if not existing:IsA("RemoteEvent") then
			Log.panic(`{name} already exists and is not a RemoteEvent`, 2)
		end
		return existing :: RemoteEvent
	end

	if RunService:IsServer() then
		const remote = Instance.new("RemoteEvent")
		remote.Name = name
		remote.Parent = ReplicatedStorage
		return remote
	end

	return ReplicatedStorage:WaitForChild(name) :: RemoteEvent
end

const function get_or_create_remote_function(name: string): RemoteFunction
	const existing = ReplicatedStorage:FindFirstChild(name)
	if existing ~= nil then
		if not existing:IsA("RemoteFunction") then
			Log.panic(`{name} already exists and is not a RemoteFunction`, 2)
		end
		return existing :: RemoteFunction
	end

	if RunService:IsServer() then
		const remote = Instance.new("RemoteFunction")
		remote.Name = name
		remote.Parent = ReplicatedStorage
		return remote
	end

	return ReplicatedStorage:WaitForChild(name) :: RemoteFunction
end

const function make_disconnectable(disconnect_impl: () -> ()): Disconnectable
	local disconnect_once: (() -> ())? = disconnect_impl
	return {
		Disconnect = function(_: any)
			const callback = disconnect_once
			if callback == nil then
				return
			end

			disconnect_once = nil
			callback()
		end,
	}
end

const function create_router(): BX41
	const remote_event = get_or_create_remote_event(DEFAULT_REMOTE_EVENT_NAME)
	const remote_function = get_or_create_remote_function(DEFAULT_REMOTE_FUNCTION_NAME)

	const event_server_handlers = {} :: { [number]: { EventServerHandler } }
	const event_client_handlers = {} :: { [number]: { EventClientHandler } }
	const function_server_handlers = {} :: { [number]: FunctionServerHandler }
	const function_client_handlers = {} :: { [number]: FunctionClientHandler }

	local next_event_offset = 1
	local next_function_offset = 1
	local integrity_key: buffer? = nil
	local integrity_tag_bytes = DEFAULT_INTEGRITY_TAG_BYTES
	local client_outbound_event_counter = 0
	local client_outbound_function_counter = 0
	local server_inbound_event_counter: number? = nil
	local server_inbound_function_counter: number? = nil
	const server_outbound_event_counters = {} :: { [Player]: number }
	const server_outbound_function_counters = {} :: { [Player]: number }
	const client_inbound_event_counters = {} :: { [Player]: number }
	const client_inbound_function_counters = {} :: { [Player]: number }

	const function clear_counter_maps()
		for player in server_outbound_event_counters do
			server_outbound_event_counters[player] = nil
		end

		for player in server_outbound_function_counters do
			server_outbound_function_counters[player] = nil
		end

		for player in client_inbound_event_counters do
			client_inbound_event_counters[player] = nil
		end

		for player in client_inbound_function_counters do
			client_inbound_function_counters[player] = nil
		end
	end

	const function reset_integrity_counters()
		client_outbound_event_counter = 0
		client_outbound_function_counter = 0
		server_inbound_event_counter = nil
		server_inbound_function_counter = nil
		clear_counter_maps()
	end

	const function set_integrity(secret: unknown, tag_bytes: number?)
		const key = normalize_integrity_key(secret)
		if key == nil then
			integrity_key = nil
			reset_integrity_counters()
			return
		end

		local resolved_tag_bytes = DEFAULT_INTEGRITY_TAG_BYTES
		if tag_bytes ~= nil then
			if type(tag_bytes) ~= "number" or tag_bytes ~= math.floor(tag_bytes) then
				Log.panic("setIntegrity tagBytes must be an integer", 2)
			end
			if tag_bytes < MIN_INTEGRITY_TAG_BYTES or tag_bytes > MAX_INTEGRITY_TAG_BYTES then
				Log.panic(
					`setIntegrity tagBytes must be in [{MIN_INTEGRITY_TAG_BYTES}, {MAX_INTEGRITY_TAG_BYTES}]`,
					2
				)
			end
			resolved_tag_bytes = tag_bytes
		end

		integrity_key = key
		integrity_tag_bytes = resolved_tag_bytes
		reset_integrity_counters()
	end

	const function seal_payload(offset: number, payload: buffer, target_player: Player?, stream: number): buffer
		const key = integrity_key
		if key == nil then
			return payload
		end

		local counter = 0
		if RunService:IsServer() then
			if target_player == nil then
				Log.panic("internal integrity state error: missing target player", 3)
			end

			const target = target_player :: Player
			if stream == STREAM_EVENT then
				counter = server_outbound_event_counters[target] or 0
				server_outbound_event_counters[target] = next_u16(counter)
			elseif stream == STREAM_FUNCTION then
				counter = server_outbound_function_counters[target] or 0
				server_outbound_function_counters[target] = next_u16(counter)
			else
				Log.panic("internal integrity state error: invalid stream", 3)
			end
		else
			if stream == STREAM_EVENT then
				counter = client_outbound_event_counter
				client_outbound_event_counter = next_u16(counter)
			elseif stream == STREAM_FUNCTION then
				counter = client_outbound_function_counter
				client_outbound_function_counter = next_u16(counter)
			else
				Log.panic("internal integrity state error: invalid stream", 3)
			end
		end

		return wrap_integrity_payload(offset, payload, key, counter, integrity_tag_bytes)
	end

	const function open_payload(
		offset: number,
		raw_payload: unknown,
		source_player: Player?,
		context: string,
		stream: number
	): buffer?
		if typeof(raw_payload) ~= "buffer" then
			return nil
		end

		const payload = raw_payload :: buffer
		const key = integrity_key
		if key == nil then
			return payload
		end

		const unwrapped, counter = unwrap_integrity_payload(offset, payload, key, integrity_tag_bytes)
		if unwrapped == nil or counter == nil then
			Log.warn(`{context} failed integrity validation`)
			return nil
		end

		if RunService:IsServer() then
			if source_player == nil then
				Log.warn(`{context} missing source player for integrity validation`)
				return nil
			end

			local expected: number?
			if stream == STREAM_EVENT then
				expected = client_inbound_event_counters[source_player]
			elseif stream == STREAM_FUNCTION then
				expected = client_inbound_function_counters[source_player]
			else
				Log.warn(`{context} invalid integrity stream`)
				return nil
			end

			if expected ~= nil and counter ~= expected then
				Log.warn(
					`{context} rejected counter for {source_player.Name}: expected {expected}, got {counter}`
				)
				return nil
			end

			if stream == STREAM_EVENT then
				client_inbound_event_counters[source_player] = next_u16(counter)
			else
				client_inbound_function_counters[source_player] = next_u16(counter)
			end
		else
			local expected: number?
			if stream == STREAM_EVENT then
				expected = server_inbound_event_counter
			elseif stream == STREAM_FUNCTION then
				expected = server_inbound_function_counter
			else
				Log.warn(`{context} invalid integrity stream`)
				return nil
			end

			if expected ~= nil and counter ~= expected then
				Log.warn(`{context} rejected counter: expected {expected}, got {counter}`)
				return nil
			end

			if stream == STREAM_EVENT then
				server_inbound_event_counter = next_u16(counter)
			elseif stream == STREAM_FUNCTION then
				server_inbound_function_counter = next_u16(counter)
			else
				Log.warn(`{context} invalid integrity stream`)
				return nil
			end
		end

		return unwrapped
	end

	if RunService:IsServer() then
		Players.PlayerRemoving:Connect(function(player: Player)
			server_outbound_event_counters[player] = nil
			server_outbound_function_counters[player] = nil
			client_inbound_event_counters[player] = nil
			client_inbound_function_counters[player] = nil
		end)
	end

	const function add_server_event_handler(offset: number, handler: EventServerHandler): Disconnectable
		const bucket = event_server_handlers[offset] or {}
		event_server_handlers[offset] = bucket
		table.insert(bucket, handler)

		return make_disconnectable(function()
			for i = #bucket, 1, -1 do
				if bucket[i] == handler then
					table.remove(bucket, i)
					break
				end
			end

			if #bucket == 0 then
				event_server_handlers[offset] = nil
			end
		end)
	end

	const function add_client_event_handler(offset: number, handler: EventClientHandler): Disconnectable
		const bucket = event_client_handlers[offset] or {}
		event_client_handlers[offset] = bucket
		table.insert(bucket, handler)

		return make_disconnectable(function()
			for i = #bucket, 1, -1 do
				if bucket[i] == handler then
					table.remove(bucket, i)
					break
				end
			end

			if #bucket == 0 then
				event_client_handlers[offset] = nil
			end
		end)
	end

	if RunService:IsServer() then
		remote_event.OnServerEvent:Connect(function(player: Player, raw_offset: unknown, ...: unknown)
			const offset = parse_offset(raw_offset)
			if offset == nil then
				return
			end

			const handlers = event_server_handlers[offset]
			if handlers == nil then
				return
			end

			const legacy = table.pack(...) :: PackedUnknownTuple
			const opened = open_payload(offset, legacy[1], player, `OnServerEvent offset={offset}`, STREAM_EVENT)
			if opened == nil then
				return
			end

			const payloads = deserialize_tuple(opened, legacy[2])
			if payloads == nil then
				return
			end

			for _, handler in handlers do
				handler(player, unpack(payloads, 1, payloads.n))
			end
		end)

		remote_function.OnServerInvoke = function(
			player: Player,
			raw_offset: unknown,
			...: unknown
		): ...unknown
			const offset = parse_offset(raw_offset)
			if offset == nil then
				return nil
			end
			const handler = function_server_handlers[offset]
			if handler == nil then
				return nil
			end

			const legacy = table.pack(...) :: PackedUnknownTuple
			const opened = open_payload(offset, legacy[1], player, `OnServerInvoke offset={offset}`, STREAM_FUNCTION)
			if opened == nil then
				return nil
			end

			const request_payloads = deserialize_tuple(opened, legacy[2])
			if request_payloads == nil then
				return nil
			end

			const protected = table.pack(pcall(handler, player, unpack(request_payloads, 1, request_payloads.n)))
			if not protected[1] then
				Log.warn(`OnServerInvoke offset={offset} failed: {tostring(protected[2])}`)
				return nil
			end

			local response_raw = table.create(protected.n - 1) :: PackedSerializableTuple
			response_raw.n = protected.n - 1
			for i = 2, protected.n do
				response_raw[i - 1] = protected[i] :: Serializable
			end

			const response_buffer, response_instances = serialize_tuple(response_raw, `OnServerInvoke response offset={offset}`)
			const sealed = seal_payload(offset, response_buffer, player, STREAM_FUNCTION)
			if response_instances == nil then
				return sealed
			end

			return sealed, response_instances
		end
	end

	if RunService:IsClient() then
		remote_event.OnClientEvent:Connect(function(raw_offset: unknown, ...: unknown)
			const offset = parse_offset(raw_offset)
			if offset == nil then
				return
			end
			const handlers = event_client_handlers[offset]
			if handlers == nil then
				return
			end

			const legacy = table.pack(...) :: PackedUnknownTuple
			const opened = open_payload(offset, legacy[1], nil, `OnClientEvent offset={offset}`, STREAM_EVENT)
			if opened == nil then
				return
			end

			const payloads = deserialize_tuple(opened, legacy[2])
			if payloads == nil then
				return
			end

			for _, handler in handlers do
				handler(unpack(payloads, 1, payloads.n))
			end
		end)

		remote_function.OnClientInvoke = function(raw_offset: unknown, ...: unknown): ...unknown
			const offset = parse_offset(raw_offset)
			if offset == nil then
				return nil
			end
			const handler = function_client_handlers[offset]
			if handler == nil then
				return nil
			end

			const legacy = table.pack(...) :: PackedUnknownTuple
			const opened = open_payload(offset, legacy[1], nil, `OnClientInvoke offset={offset}`, STREAM_FUNCTION)
			if opened == nil then
				return nil
			end

			const request_payloads = deserialize_tuple(opened, legacy[2])
			if request_payloads == nil then
				return nil
			end

			const protected = table.pack(pcall(handler, unpack(request_payloads, 1, request_payloads.n)))
			if not protected[1] then
				Log.warn(`OnClientInvoke offset={offset} failed: {tostring(protected[2])}`)
				return nil
			end

			local response_raw = table.create(protected.n - 1) :: PackedSerializableTuple
			response_raw.n = protected.n - 1
			for i = 2, protected.n do
				response_raw[i - 1] = protected[i] :: Serializable
			end

			const response_buffer, response_instances = serialize_tuple(response_raw, `OnClientInvoke response offset={offset}`)
			const sealed = seal_payload(offset, response_buffer, nil, STREAM_FUNCTION)
			if response_instances == nil then
				return sealed
			end

			return sealed, response_instances
		end
	end

	const function allocate_offset(kind: string, current: number): number
		if current > 255 then
			Log.panic(`exhausted {kind} offset space (u8)`, 3)
		end
		return current
	end

	const function define_event(channel_mode: unknown, ...: unknown): any
		const routed_offset = allocate_offset("event", next_event_offset)
		next_event_offset += 1
		const mode = normalize_channel(channel_mode)
		const descriptors = parse_descriptors("defineEvent", table.pack(...) :: PackedUnknownTuple)

		const api = {
			offset = routed_offset,

			fireServer = function(...: Serializable)
				if mode == CHANNEL_SERVER then
					Log.panic("fireServer is disabled for Server channel routes", 2)
				end
				if not RunService:IsClient() then
					Log.panic("fireServer can only be called on the client", 2)
				end

				const payload_values = table.pack(...) :: PackedSerializableTuple
				if descriptors ~= nil then
					assert_descriptor_values(payload_values, descriptors :: { SerializableDescriptor }, `fireServer offset={routed_offset}`)
				end

				const payload_buffer, payload_instances = serialize_tuple(payload_values, `fireServer offset={routed_offset}`)
				const sealed = seal_payload(routed_offset, payload_buffer, nil, STREAM_EVENT)
				if payload_instances == nil then
					remote_event:FireServer(make_offset_buffer(routed_offset), sealed)
					return
				end

				remote_event:FireServer(make_offset_buffer(routed_offset), sealed, payload_instances)
			end,

			fireClient = function(player: Player, ...: Serializable)
				if mode == CHANNEL_CLIENT then
					Log.panic("fireClient is disabled for Client channel routes", 2)
				end
				if not RunService:IsServer() then
					Log.panic("fireClient can only be called on the server", 2)
				end

				const payload_values = table.pack(...) :: PackedSerializableTuple
				if descriptors ~= nil then
					assert_descriptor_values(payload_values, descriptors :: { SerializableDescriptor }, `fireClient offset={routed_offset}`)
				end

				const payload_buffer, payload_instances = serialize_tuple(payload_values, `fireClient offset={routed_offset}`)
				const sealed = seal_payload(routed_offset, payload_buffer, player, STREAM_EVENT)
				if payload_instances == nil then
					remote_event:FireClient(player, make_offset_buffer(routed_offset), sealed)
					return
				end

				remote_event:FireClient(player, make_offset_buffer(routed_offset), sealed, payload_instances)
			end,

			fireAllClients = function(...: Serializable)
				if mode == CHANNEL_CLIENT then
					Log.panic("fireAllClients is disabled for Client channel routes", 2)
				end
				if not RunService:IsServer() then
					Log.panic("fireAllClients can only be called on the server", 2)
				end

				const payload_values = table.pack(...) :: PackedSerializableTuple
				if descriptors ~= nil then
					assert_descriptor_values(payload_values, descriptors :: { SerializableDescriptor }, `fireAllClients offset={routed_offset}`)
				end

				const payload_buffer, payload_instances = serialize_tuple(payload_values, `fireAllClients offset={routed_offset}`)
				if integrity_key ~= nil then
					for _, player in Players:GetPlayers() do
						const sealed = seal_payload(routed_offset, payload_buffer, player, STREAM_EVENT)
						if payload_instances == nil then
							remote_event:FireClient(player, make_offset_buffer(routed_offset), sealed)
						else
							remote_event:FireClient(player, make_offset_buffer(routed_offset), sealed, payload_instances)
						end
					end
					return
				end

				if payload_instances == nil then
					remote_event:FireAllClients(make_offset_buffer(routed_offset), payload_buffer)
					return
				end

				remote_event:FireAllClients(make_offset_buffer(routed_offset), payload_buffer, payload_instances)
			end,

			onServer = function(handler: (player: Player, ...Serializable) -> ()): Disconnectable
				if mode == CHANNEL_SERVER then
					Log.panic("onServer is disabled for Server channel routes", 2)
				end
				return add_server_event_handler(routed_offset, handler :: EventServerHandler)
			end,

			onClient = function(handler: (...Serializable) -> ()): Disconnectable
				if mode == CHANNEL_CLIENT then
					Log.panic("onClient is disabled for Client channel routes", 2)
				end
				return add_client_event_handler(routed_offset, handler :: EventClientHandler)
			end,
		}

		return table.freeze(api)
	end

	const function define_function(channel_mode: unknown, ...: unknown): any
		const routed_offset = allocate_offset("function", next_function_offset)
		next_function_offset += 1
		const mode = normalize_channel(channel_mode)
		const descriptors = parse_descriptors("defineFunction", table.pack(...) :: PackedUnknownTuple)

		const api = {
			offset = routed_offset,

			invokeServer = function(...: Serializable): ...any
				if mode == CHANNEL_SERVER then
					Log.panic("invokeServer is disabled for Server channel routes", 2)
				end
				if not RunService:IsClient() then
					Log.panic("invokeServer can only be called on the client", 2)
				end

				const request_values = table.pack(...) :: PackedSerializableTuple
				if descriptors ~= nil then
					assert_descriptor_values(request_values, descriptors :: { SerializableDescriptor }, `invokeServer offset={routed_offset}`)
				end

				const request_buffer, request_instances = serialize_tuple(request_values, `invokeServer offset={routed_offset}`)
				const sealed_request = seal_payload(routed_offset, request_buffer, nil, STREAM_FUNCTION)
				local raw_response: PackedUnknownTuple
				if request_instances == nil then
					raw_response = table.pack(remote_function:InvokeServer(make_offset_buffer(routed_offset), sealed_request))
				else
					raw_response = table.pack(remote_function:InvokeServer(
						make_offset_buffer(routed_offset),
						sealed_request,
						request_instances
					))
				end

				const opened_response = open_payload(
					routed_offset,
					raw_response[1],
					nil,
					`invokeServer offset={routed_offset} response`,
					STREAM_FUNCTION
				)
				if opened_response == nil then
					Log.panic(`invokeServer offset={routed_offset} failed response integrity validation`, 2)
					return nil
				end

				const response_payloads = deserialize_tuple(opened_response, raw_response[2])
				if response_payloads == nil then
					Log.panic(`invokeServer offset={routed_offset} received malformed response`, 2)
					return nil
				end

				return unpack(response_payloads, 1, response_payloads.n)
			end,

			invokeClient = function(player: Player, ...: Serializable): ...any
				if mode == CHANNEL_CLIENT then
					Log.panic("invokeClient is disabled for Client channel routes", 2)
				end
				if not RunService:IsServer() then
					Log.panic("invokeClient can only be called on the server", 2)
				end

				const request_values = table.pack(...) :: PackedSerializableTuple
				if descriptors ~= nil then
					assert_descriptor_values(request_values, descriptors :: { SerializableDescriptor }, `invokeClient offset={routed_offset}`)
				end

				const request_buffer, request_instances = serialize_tuple(request_values, `invokeClient offset={routed_offset}`)
				const sealed_request = seal_payload(routed_offset, request_buffer, player, STREAM_FUNCTION)
				local raw_response: PackedUnknownTuple
				if request_instances == nil then
					raw_response = table.pack(remote_function:InvokeClient(player, make_offset_buffer(routed_offset), sealed_request))
				else
					raw_response = table.pack(remote_function:InvokeClient(
						player,
						make_offset_buffer(routed_offset),
						sealed_request,
						request_instances
					))
				end

				const opened_response = open_payload(
					routed_offset,
					raw_response[1],
					player,
					`invokeClient offset={routed_offset} response`,
					STREAM_FUNCTION
				)
				if opened_response == nil then
					Log.panic(`invokeClient offset={routed_offset} failed response integrity validation`, 2)
					return nil
				end

				const response_payloads = deserialize_tuple(opened_response, raw_response[2])
				if response_payloads == nil then
					Log.panic(`invokeClient offset={routed_offset} received malformed response`, 2)
					return nil
				end

				return unpack(response_payloads, 1, response_payloads.n)
			end,

			onServer = function(handler: (player: Player, ...Serializable) -> ...any)
				if mode == CHANNEL_SERVER then
					Log.panic("onServer is disabled for Server channel routes", 2)
				end
				function_server_handlers[routed_offset] = handler :: FunctionServerHandler
			end,

			onClient = function(handler: (...Serializable) -> ...any)
				if mode == CHANNEL_CLIENT then
					Log.panic("onClient is disabled for Client channel routes", 2)
				end
				function_client_handlers[routed_offset] = handler :: FunctionClientHandler
			end,
		}

		return table.freeze(api)
	end

	return (table.freeze({
		defineEvent = define_event,
		defineFunction = define_function,
		setIntegrity = set_integrity,
	}) :: any) :: BX41
end

const router = create_router() 

const function descriptor_token(descriptor: SerializableDescriptor)
	return table.freeze({
		_descriptor = descriptor,
		_value = nil,
	})
end

return (table.freeze({
	defineEvent = router.defineEvent,
	defineFunction = router.defineFunction,
	setIntegrity = router.setIntegrity,
	Channel = table.freeze({
		Server = "Server" :: "Server",
		Client = "Client" :: "Client",
		Both = "Both" :: "Both",
	}),
	Serializable = table.freeze({
		Nil = descriptor_token("nil"),
		Boolean = descriptor_token("boolean"),
		Buffer = descriptor_token("buffer"),
		Number = descriptor_token("number"),
		String = descriptor_token("string"),
		Table = descriptor_token("table"),
		Instance = descriptor_token("Instance"),
		Vector3 = descriptor_token("Vector3"),
		Vector2 = descriptor_token("Vector2"),
		CFrame = descriptor_token("CFrame"),
		Color3 = descriptor_token("Color3"),
		BrickColor = descriptor_token("BrickColor"),
		Region3 = descriptor_token("Region3"),
		EnumItem = descriptor_token("EnumItem"),
		UDim = descriptor_token("UDim"),
		UDim2 = descriptor_token("UDim2"),
		TweenInfo = descriptor_token("TweenInfo"),
	}),
}) :: any) :: BX41Module
