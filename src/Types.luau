--!strict

export type Channel = "Server" | "Client" | "Both"

export type Disconnectable = RBXScriptConnection | {
	Disconnect: (self: any) -> (),
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

export type DescriptorToken<T> = {
	_descriptor: SerializableDescriptor,
	_value: T,
}

-- Server channel: server fires to clients.
-- Available: fireClient, fireAllClients, onClient
export type ServerEventChannel<Args...> = {
	offset: number,
	fireClient: (player: Player, Args...) -> (),
	fireAllClients: (Args...) -> (),
	onClient: (handler: (Args...) -> ()) -> Disconnectable,
}

-- Client channel: client fires to server.
-- Available: fireServer, onServer
export type ClientEventChannel<Args...> = {
	offset: number,
	fireServer: (Args...) -> (),
	onServer: (handler: (player: Player, Args...) -> ()) -> Disconnectable,
}

-- Both channel: bidirectional.
export type BothEventChannel<Args...> = {
	offset: number,
	fireServer: (Args...) -> (),
	fireClient: (player: Player, Args...) -> (),
	fireAllClients: (Args...) -> (),
	onServer: (handler: (player: Player, Args...) -> ()) -> Disconnectable,
	onClient: (handler: (Args...) -> ()) -> Disconnectable,
}

-- Server channel: server invokes a specific client.
export type ServerFunctionChannel<Args...> = {
	offset: number,
	invokeClient: (player: Player, Args...) -> ...Serializable,
	onClient: (handler: (Args...) -> ...Serializable) -> (),
}

-- Client channel: client invokes the server.
export type ClientFunctionChannel<Args...> = {
	offset: number,
	invokeServer: (Args...) -> ...Serializable,
	onServer: (handler: (player: Player, Args...) -> ...Serializable) -> (),
}

-- Both channel: bidirectional invocations.
export type BothFunctionChannel<Args...> = {
	offset: number,
	invokeServer: (Args...) -> ...Serializable,
	invokeClient: (player: Player, Args...) -> ...Serializable,
	onServer: (handler: (player: Player, Args...) -> ...Serializable) -> (),
	onClient: (handler: (Args...) -> ...Serializable) -> (),
}

export type BX41 = {
	setIntegrity: (secret: string | buffer?, tagBytes: number?) -> (),
	defineEvent: ((channel: "Server") -> ServerEventChannel<>)
		& (<A>(channel: "Server", a: DescriptorToken<A>) -> ServerEventChannel<A>)
		& (<A, B>(
			channel: "Server",
			a: DescriptorToken<A>,
			b: DescriptorToken<B>
		) -> ServerEventChannel<A, B>)
		& ((channel: "Client") -> ClientEventChannel<>)
		& (<A>(channel: "Client", a: DescriptorToken<A>) -> ClientEventChannel<A>)
		& (<A, B>(
			channel: "Client",
			a: DescriptorToken<A>,
			b: DescriptorToken<B>
		) -> ClientEventChannel<A, B>)
		& ((channel: "Both") -> BothEventChannel<>)
		& (<A>(channel: "Both", a: DescriptorToken<A>) -> BothEventChannel<A>)
		& (<A, B>(channel: "Both", a: DescriptorToken<A>, b: DescriptorToken<B>) -> BothEventChannel<A, B>)
		& ((channel: Channel, ...DescriptorToken<any>) -> BothEventChannel<Serializable>),
	defineFunction: ((channel: "Server") -> ServerFunctionChannel<>)
		& (<A>(channel: "Server", a: DescriptorToken<A>) -> ServerFunctionChannel<A>)
		& (<A, B>(
			channel: "Server",
			a: DescriptorToken<A>,
			b: DescriptorToken<B>
		) -> ServerFunctionChannel<A, B>)
		& ((channel: "Client") -> ClientFunctionChannel<>)
		& (<A>(channel: "Client", a: DescriptorToken<A>) -> ClientFunctionChannel<A>)
		& (<A, B>(
			channel: "Client",
			a: DescriptorToken<A>,
			b: DescriptorToken<B>
		) -> ClientFunctionChannel<A, B>)
		& ((channel: "Both") -> BothFunctionChannel<>)
		& (<A>(channel: "Both", a: DescriptorToken<A>) -> BothFunctionChannel<A>)
		& (<A, B>(
			channel: "Both",
			a: DescriptorToken<A>,
			b: DescriptorToken<B>
		) -> BothFunctionChannel<A, B>)
		& ((channel: Channel, ...DescriptorToken<any>) -> BothFunctionChannel<Serializable>),
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
