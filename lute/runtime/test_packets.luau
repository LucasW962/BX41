const BX41 = require("../../src/BX41")
const Channel = BX41.Channel
const Serializables = BX41.Serializable

const Packets = {
    ServerPacket = BX41.defineEvent(Channel.Server, Serializables.Boolean, Serializables.Number),
    ClientPacket = BX41.defineEvent(Channel.Client, Serializables.CFrame, Serializables.EnumItem),
    BothPacket = BX41.defineEvent(Channel.Server, Serializables.String, Serializables.UDim2),
    ServerFunction = BX41.defineFunction(Channel.Server, {
        Args = {Serializables.Boolean, Serializables.Buffer},
        Return = {Serializables.String}
    }) :: BX41.ServerFunctionChannel,
}

Packets

return table.freeze(Packets)