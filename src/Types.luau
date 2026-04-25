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

export type ServerEventChannel<Args...> = {
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

export type BothEventChannel<Args...> = {
	offset: number,
	fireServer: (Args...) -> (),
	fireClient: (player: Player, Args...) -> (),
	fireAllClients: (Args...) -> (),
	onServer: (handler: (player: Player, Args...) -> ()) -> Disconnectable,
	onClient: (handler: (Args...) -> ()) -> Disconnectable,
}

export type ServerFunctionChannel<Args...> = {
	offset: number,
	invokeClient: (player: Player, Args...) -> ...Serializable,
	onClient: (handler: (Args...) -> ...Serializable) -> (),
}

export type ClientFunctionChannel<Args...> = {
	offset: number,
	invokeServer: (Args...) -> ...Serializable,
	onServer: (handler: (player: Player, Args...) -> ...Serializable) -> (),
}

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
	defineFunction: ((channel: "Server") -> ServerFunctionChannel<>)
		& (<A>(channel: "Server", a: DescriptorToken<A>) -> ServerFunctionChannel<A>)
		& (<A, B>(
			channel: "Server",
			a: DescriptorToken<A>,
			b: DescriptorToken<B>
		) -> ServerFunctionChannel<A, B>)
		& (<A, B, C>(
			channel: "Server",
			a: DescriptorToken<A>,
			b: DescriptorToken<B>,
			c: DescriptorToken<C>
		) -> ServerFunctionChannel<A, B, C>)
		& (<A, B, C, D>(
			channel: "Server",
			a: DescriptorToken<A>,
			b: DescriptorToken<B>,
			c: DescriptorToken<C>,
			d: DescriptorToken<D>
		) -> ServerFunctionChannel<A, B, C, D>)
		& ((channel: "Client") -> ClientFunctionChannel<>)
		& (<A>(channel: "Client", a: DescriptorToken<A>) -> ClientFunctionChannel<A>)
		& (<A, B>(
			channel: "Client",
			a: DescriptorToken<A>,
			b: DescriptorToken<B>
		) -> ClientFunctionChannel<A, B>)
		& (<A, B, C>(
			channel: "Client",
			a: DescriptorToken<A>,
			b: DescriptorToken<B>,
			c: DescriptorToken<C>
		) -> ClientFunctionChannel<A, B, C>)
		& (<A, B, C, D>(
			channel: "Client",
			a: DescriptorToken<A>,
			b: DescriptorToken<B>,
			c: DescriptorToken<C>,
			d: DescriptorToken<D>
		) -> ClientFunctionChannel<A, B, C, D>)
		& ((channel: "Both") -> BothFunctionChannel<>)
		& (<A>(channel: "Both", a: DescriptorToken<A>) -> BothFunctionChannel<A>)
		& (<A, B>(
			channel: "Both",
			a: DescriptorToken<A>,
			b: DescriptorToken<B>
		) -> BothFunctionChannel<A, B>)
		& (<A, B, C>(
			channel: "Both",
			a: DescriptorToken<A>,
			b: DescriptorToken<B>,
			c: DescriptorToken<C>
		) -> BothFunctionChannel<A, B, C>)
		& (<A, B, C, D>(
			channel: "Both",
			a: DescriptorToken<A>,
			b: DescriptorToken<B>,
			c: DescriptorToken<C>,
			d: DescriptorToken<D>
		) -> BothFunctionChannel<A, B, C, D>)
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
