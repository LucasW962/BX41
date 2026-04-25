--!strict

export type Channel = "Server" | "Client" | "Both"

export type Disconnectable = RBXScriptConnection | {
	Disconnect: (self: Disconnectable) -> (),
}

export type Serializable =
	nil
	| boolean
	| buffer
	| number
	| string
	| Instance
	| Vector3
	| Vector2
	| CFrame
	| Color3
	| BrickColor
	| Region3
	| EnumItem
	| UDim
	| UDim2
	| TweenInfo
	| { [Serializable]: Serializable }
	| { Serializable }

export type SerializableDescriptor =
	"nil"
	| "boolean"
	| "buffer"
	| "number"
	| "string"
	| "table"
	| "Instance"
	| "Vector3"
	| "Vector2"
	| "CFrame"
	| "Color3"
	| "BrickColor"
	| "Region3"
	| "EnumItem"
	| "UDim"
	| "UDim2"
	| "TweenInfo"

export type DescriptorToken<T = unknown> = {
	_descriptor: SerializableDescriptor,
	_value: T,
}

export type FunctionSchema = {
	Args: { DescriptorToken<any> }?,
	Return: { DescriptorToken<any> }?,
}

type function fn_prepend_parameter(sig: type, first_param: type)
	if sig.tag ~= "function" then
		return types.never
	end

	local params = sig:parameters()
	local returns = sig:returns()
	local generics = sig:generics()
	local head = { first_param }

	if params.head ~= nil then
		for _, param in params.head do
			table.insert(head, param)
		end
	end

	return types.newfunction(
		{ head = head, tail = params.tail },
		{ head = returns.head, tail = returns.tail },
		generics
	)
end

export type IntegrityClockMode = "system" | "synced"

export type IntegrityOptions = {
	includeTimestamp: boolean?,
	replayWindowSeconds: number?,
	clockMode: IntegrityClockMode?,
	syncIntervalSeconds: number?,
}

export type IntegrityConfig = {
	enabled: boolean,
	tagBytes: number,
	includeTimestamp: boolean,
	replayWindowSeconds: number?,
	clockMode: IntegrityClockMode,
	syncIntervalSeconds: number,
}

export type ClockState = {
	mode: IntegrityClockMode,
	synced: boolean,
	offsetSeconds: number,
	rttSeconds: number?,
	lastSyncLocalSeconds: number?,
	sampleCount: number,
}

export type ServerEventChannel<Args... = ()> = {
	offset: number,
	fireClient: (player: Player, Args...) -> (),
	fireAllClients: (Args...) -> (),
	onClient: (handler: (Args...) -> ()) -> Disconnectable,
}

export type ClientEventChannel<Args...> = {
	offset: number,
	fireServer: (Args...) -> (),
	onServer: (handler: (player: Player, Args...) -> ()) -> Disconnectable,
}

export type BothEventChannel<Args... = ()> = {
	offset: number,
	fireServer: (Args...) -> (),
	fireClient: (player: Player, Args...) -> (),
	fireAllClients: (Args...) -> (),
	onServer: (handler: (player: Player, Args...) -> ()) -> Disconnectable,
	onClient: (handler: (Args...) -> ()) -> Disconnectable,
}

export type ServerFunctionChannel<Sig = (...Serializable) -> ...Serializable> = {
	offset: number,
	invokeClient: fn_prepend_parameter<Sig, Player>,
	onClient: (handler: Sig) -> (),
}

export type ClientFunctionChannel<Sig = (...Serializable) -> ...Serializable> = {
	offset: number,
	invokeServer: Sig,
	onServer: (handler: fn_prepend_parameter<Sig, Player>) -> (),
}

export type BothFunctionChannel<Sig = (...Serializable) -> ...Serializable> = {
	offset: number,
	invokeServer: Sig,
	invokeClient: fn_prepend_parameter<Sig, Player>,
	onServer: (handler: fn_prepend_parameter<Sig, Player>) -> (),
	onClient: (handler: Sig) -> (),
}

export type TypedServerFunctionChannel<R...> = ServerFunctionChannel<(...Serializable) -> R...>
export type TypedClientFunctionChannel<R...> = ClientFunctionChannel<(...Serializable) -> R...>
export type TypedBothFunctionChannel<R...> = BothFunctionChannel<(...Serializable) -> R...>

export type BX41 = {
	setIntegrity: (secret: string | buffer?, tagBytes: number?, options: IntegrityOptions?) -> (),
	getIntegrityConfig: () -> IntegrityConfig,
	getClockState: () -> ClockState,
	defineEvent: ((channel: "Server") -> ServerEventChannel<>)
		& (<A>(channel: "Server", a: DescriptorToken<A>) -> ServerEventChannel<A>)
		& (<A, B>(
			channel: "Server",
			a: DescriptorToken<A>,
			b: DescriptorToken<B>
		) -> ServerEventChannel<A, B>)
		& (<A, B, C>(
			channel: "Server",
			a: DescriptorToken<A>,
			b: DescriptorToken<B>,
			c: DescriptorToken<C>
		) -> ServerEventChannel<A, B, C>)
		& (<A, B, C, D>(
			channel: "Server",
			a: DescriptorToken<A>,
			b: DescriptorToken<B>,
			c: DescriptorToken<C>,
			d: DescriptorToken<D>
		) -> ServerEventChannel<A, B, C, D>)
		& ((channel: "Client") -> ClientEventChannel<>)
		& (<A>(channel: "Client", a: DescriptorToken<A>) -> ClientEventChannel<A>)
		& (<A, B>(
			channel: "Client",
			a: DescriptorToken<A>,
			b: DescriptorToken<B>
		) -> ClientEventChannel<A, B>)
		& (<A, B, C>(
			channel: "Client",
			a: DescriptorToken<A>,
			b: DescriptorToken<B>,
			c: DescriptorToken<C>
		) -> ClientEventChannel<A, B, C>)
		& (<A, B, C, D>(
			channel: "Client",
			a: DescriptorToken<A>,
			b: DescriptorToken<B>,
			c: DescriptorToken<C>,
			d: DescriptorToken<D>
		) -> ClientEventChannel<A, B, C, D>)
		& ((channel: "Both") -> BothEventChannel<>)
		& (<A>(channel: "Both", a: DescriptorToken<A>) -> BothEventChannel<A>)
		& (<A, B>(channel: "Both", a: DescriptorToken<A>, b: DescriptorToken<B>) -> BothEventChannel<A, B>)
		& (<A, B, C>(
			channel: "Both",
			a: DescriptorToken<A>,
			b: DescriptorToken<B>,
			c: DescriptorToken<C>
		) -> BothEventChannel<A, B, C>)
		& (<A, B, C, D>(
			channel: "Both",
			a: DescriptorToken<A>,
			b: DescriptorToken<B>,
			c: DescriptorToken<C>,
			d: DescriptorToken<D>
		) -> BothEventChannel<A, B, C, D>)
		& ((channel: Channel, ...DescriptorToken<any>) -> BothEventChannel<Serializable>),
	defineFunction: ((channel: "Server", ...DescriptorToken<any>) -> ServerFunctionChannel)
		& ((channel: "Client", ...DescriptorToken<any>) -> ClientFunctionChannel)
		& ((channel: "Both", ...DescriptorToken<any>) -> BothFunctionChannel)
		& (<Sig>(channel: "Server", schema: FunctionSchema) -> ServerFunctionChannel<Sig>)
		& (<Sig>(channel: "Client", schema: FunctionSchema) -> ClientFunctionChannel<Sig>)
		& (<Sig>(channel: "Both", schema: FunctionSchema) -> BothFunctionChannel<Sig>)
		& (<R...>(channel: "Server", ...DescriptorToken<any>) -> TypedServerFunctionChannel<R...>)
		& (<R...>(channel: "Client", ...DescriptorToken<any>) -> TypedClientFunctionChannel<R...>)
		& (<R...>(channel: "Both", ...DescriptorToken<any>) -> TypedBothFunctionChannel<R...>)
		& (<R...>(channel: "Server", schema: FunctionSchema) -> TypedServerFunctionChannel<R...>)
		& (<R...>(channel: "Client", schema: FunctionSchema) -> TypedClientFunctionChannel<R...>)
		& (<R...>(channel: "Both", schema: FunctionSchema) -> TypedBothFunctionChannel<R...>)
		& ((channel: Channel, schema: FunctionSchema) -> BothFunctionChannel)
		& ((channel: Channel, ...DescriptorToken<any>) -> BothFunctionChannel),
}

export type BX41Module = BX41 & {
	Channel: {
		Server: "Server",
		Client: "Client",
		Both: "Both",
	},
	Serializable: {
		Nil: DescriptorToken<nil>,
		Boolean: DescriptorToken<boolean>,
		Buffer: DescriptorToken<buffer>,
		Number: DescriptorToken<number>,
		String: DescriptorToken<string>,
		Table: DescriptorToken<{ [Serializable]: Serializable } | { Serializable }>,
		Instance: DescriptorToken<Instance>,
		Vector3: DescriptorToken<Vector3>,
		Vector2: DescriptorToken<Vector2>,
		CFrame: DescriptorToken<CFrame>,
		Color3: DescriptorToken<Color3>,
		BrickColor: DescriptorToken<BrickColor>,
		Region3: DescriptorToken<Region3>,
		EnumItem: DescriptorToken<EnumItem>,
		UDim: DescriptorToken<UDim>,
		UDim2: DescriptorToken<UDim2>,
		TweenInfo: DescriptorToken<TweenInfo>,
	},
}

return {}
