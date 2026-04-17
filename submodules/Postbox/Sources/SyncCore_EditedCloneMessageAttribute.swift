import Foundation

public class EditedCloneMessageAttribute: MessageAttribute {
    public let originalPeerIdInt64: Int64
    public let originalNamespace: Int32
    public let originalMessageId: Int32
    public let date: Int32

    public init(originalPeerIdInt64: Int64, originalNamespace: Int32, originalMessageId: Int32, date: Int32) {
        self.originalPeerIdInt64 = originalPeerIdInt64
        self.originalNamespace = originalNamespace
        self.originalMessageId = originalMessageId
        self.date = date
    }

    required public init(decoder: PostboxDecoder) {
        self.originalPeerIdInt64 = decoder.decodeInt64ForKey("op", orElse: 0)
        self.originalNamespace = decoder.decodeInt32ForKey("on", orElse: 0)
        self.originalMessageId = decoder.decodeInt32ForKey("om", orElse: 0)
        self.date = decoder.decodeInt32ForKey("d", orElse: 0)
    }

    public func encode(_ encoder: PostboxEncoder) {
        encoder.encodeInt64(self.originalPeerIdInt64, forKey: "op")
        encoder.encodeInt32(self.originalNamespace, forKey: "on")
        encoder.encodeInt32(self.originalMessageId, forKey: "om")
        encoder.encodeInt32(self.date, forKey: "d")
    }
}

public let molteagramEditedCloneNamespace: MessageId.Namespace = 100

public func molteagramEditedCloneCustomTag(
    originalPeerId: PeerId,
    originalNamespace: MessageId.Namespace,
    originalMessageId: MessageId.Id
) -> MemoryBuffer {
    var data = Data(capacity: 16)

    var peerIdValue = originalPeerId.toInt64().littleEndian
    var namespaceValue = originalNamespace.littleEndian
    var messageIdValue = originalMessageId.littleEndian

    withUnsafeBytes(of: &peerIdValue) { data.append(contentsOf: $0) }
    withUnsafeBytes(of: &namespaceValue) { data.append(contentsOf: $0) }
    withUnsafeBytes(of: &messageIdValue) { data.append(contentsOf: $0) }

    return MemoryBuffer(data: data)
}
