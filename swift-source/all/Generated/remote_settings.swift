// This file was autogenerated by some hot garbage in the `uniffi` crate.
// Trust me, you don't want to mess with it!
import Foundation

// Depending on the consumer's build setup, the low-level FFI code
// might be in a separate module, or it might be compiled inline into
// this module. This is a bit of light hackery to work with both.
#if canImport(MozillaRustComponents)
    import MozillaRustComponents
#endif

private extension RustBuffer {
    // Allocate a new buffer, copying the contents of a `UInt8` array.
    init(bytes: [UInt8]) {
        let rbuf = bytes.withUnsafeBufferPointer { ptr in
            RustBuffer.from(ptr)
        }
        self.init(capacity: rbuf.capacity, len: rbuf.len, data: rbuf.data)
    }

    static func from(_ ptr: UnsafeBufferPointer<UInt8>) -> RustBuffer {
        try! rustCall { ffi_remote_settings_rustbuffer_from_bytes(ForeignBytes(bufferPointer: ptr), $0) }
    }

    // Frees the buffer in place.
    // The buffer must not be used after this is called.
    func deallocate() {
        try! rustCall { ffi_remote_settings_rustbuffer_free(self, $0) }
    }
}

private extension ForeignBytes {
    init(bufferPointer: UnsafeBufferPointer<UInt8>) {
        self.init(len: Int32(bufferPointer.count), data: bufferPointer.baseAddress)
    }
}

// For every type used in the interface, we provide helper methods for conveniently
// lifting and lowering that type from C-compatible data, and for reading and writing
// values of that type in a buffer.

// Helper classes/extensions that don't change.
// Someday, this will be in a library of its own.

private extension Data {
    init(rustBuffer: RustBuffer) {
        // TODO: This copies the buffer. Can we read directly from a
        // Rust buffer?
        self.init(bytes: rustBuffer.data!, count: Int(rustBuffer.len))
    }
}

// Define reader functionality.  Normally this would be defined in a class or
// struct, but we use standalone functions instead in order to make external
// types work.
//
// With external types, one swift source file needs to be able to call the read
// method on another source file's FfiConverter, but then what visibility
// should Reader have?
// - If Reader is fileprivate, then this means the read() must also
//   be fileprivate, which doesn't work with external types.
// - If Reader is internal/public, we'll get compile errors since both source
//   files will try define the same type.
//
// Instead, the read() method and these helper functions input a tuple of data

private func createReader(data: Data) -> (data: Data, offset: Data.Index) {
    (data: data, offset: 0)
}

// Reads an integer at the current offset, in big-endian order, and advances
// the offset on success. Throws if reading the integer would move the
// offset past the end of the buffer.
private func readInt<T: FixedWidthInteger>(_ reader: inout (data: Data, offset: Data.Index)) throws -> T {
    let range = reader.offset ..< reader.offset + MemoryLayout<T>.size
    guard reader.data.count >= range.upperBound else {
        throw UniffiInternalError.bufferOverflow
    }
    if T.self == UInt8.self {
        let value = reader.data[reader.offset]
        reader.offset += 1
        return value as! T
    }
    var value: T = 0
    let _ = withUnsafeMutableBytes(of: &value) { reader.data.copyBytes(to: $0, from: range) }
    reader.offset = range.upperBound
    return value.bigEndian
}

// Reads an arbitrary number of bytes, to be used to read
// raw bytes, this is useful when lifting strings
private func readBytes(_ reader: inout (data: Data, offset: Data.Index), count: Int) throws -> [UInt8] {
    let range = reader.offset ..< (reader.offset + count)
    guard reader.data.count >= range.upperBound else {
        throw UniffiInternalError.bufferOverflow
    }
    var value = [UInt8](repeating: 0, count: count)
    value.withUnsafeMutableBufferPointer { buffer in
        reader.data.copyBytes(to: buffer, from: range)
    }
    reader.offset = range.upperBound
    return value
}

// Reads a float at the current offset.
private func readFloat(_ reader: inout (data: Data, offset: Data.Index)) throws -> Float {
    return try Float(bitPattern: readInt(&reader))
}

// Reads a float at the current offset.
private func readDouble(_ reader: inout (data: Data, offset: Data.Index)) throws -> Double {
    return try Double(bitPattern: readInt(&reader))
}

// Indicates if the offset has reached the end of the buffer.
private func hasRemaining(_ reader: (data: Data, offset: Data.Index)) -> Bool {
    return reader.offset < reader.data.count
}

// Define writer functionality.  Normally this would be defined in a class or
// struct, but we use standalone functions instead in order to make external
// types work.  See the above discussion on Readers for details.

private func createWriter() -> [UInt8] {
    return []
}

private func writeBytes<S>(_ writer: inout [UInt8], _ byteArr: S) where S: Sequence, S.Element == UInt8 {
    writer.append(contentsOf: byteArr)
}

// Writes an integer in big-endian order.
//
// Warning: make sure what you are trying to write
// is in the correct type!
private func writeInt<T: FixedWidthInteger>(_ writer: inout [UInt8], _ value: T) {
    var value = value.bigEndian
    withUnsafeBytes(of: &value) { writer.append(contentsOf: $0) }
}

private func writeFloat(_ writer: inout [UInt8], _ value: Float) {
    writeInt(&writer, value.bitPattern)
}

private func writeDouble(_ writer: inout [UInt8], _ value: Double) {
    writeInt(&writer, value.bitPattern)
}

// Protocol for types that transfer other types across the FFI. This is
// analogous go the Rust trait of the same name.
private protocol FfiConverter {
    associatedtype FfiType
    associatedtype SwiftType

    static func lift(_ value: FfiType) throws -> SwiftType
    static func lower(_ value: SwiftType) -> FfiType
    static func read(from buf: inout (data: Data, offset: Data.Index)) throws -> SwiftType
    static func write(_ value: SwiftType, into buf: inout [UInt8])
}

// Types conforming to `Primitive` pass themselves directly over the FFI.
private protocol FfiConverterPrimitive: FfiConverter where FfiType == SwiftType {}

extension FfiConverterPrimitive {
    public static func lift(_ value: FfiType) throws -> SwiftType {
        return value
    }

    public static func lower(_ value: SwiftType) -> FfiType {
        return value
    }
}

// Types conforming to `FfiConverterRustBuffer` lift and lower into a `RustBuffer`.
// Used for complex types where it's hard to write a custom lift/lower.
private protocol FfiConverterRustBuffer: FfiConverter where FfiType == RustBuffer {}

extension FfiConverterRustBuffer {
    public static func lift(_ buf: RustBuffer) throws -> SwiftType {
        var reader = createReader(data: Data(rustBuffer: buf))
        let value = try read(from: &reader)
        if hasRemaining(reader) {
            throw UniffiInternalError.incompleteData
        }
        buf.deallocate()
        return value
    }

    public static func lower(_ value: SwiftType) -> RustBuffer {
        var writer = createWriter()
        write(value, into: &writer)
        return RustBuffer(bytes: writer)
    }
}

// An error type for FFI errors. These errors occur at the UniFFI level, not
// the library level.
private enum UniffiInternalError: LocalizedError {
    case bufferOverflow
    case incompleteData
    case unexpectedOptionalTag
    case unexpectedEnumCase
    case unexpectedNullPointer
    case unexpectedRustCallStatusCode
    case unexpectedRustCallError
    case unexpectedStaleHandle
    case rustPanic(_ message: String)

    public var errorDescription: String? {
        switch self {
        case .bufferOverflow: return "Reading the requested value would read past the end of the buffer"
        case .incompleteData: return "The buffer still has data after lifting its containing value"
        case .unexpectedOptionalTag: return "Unexpected optional tag; should be 0 or 1"
        case .unexpectedEnumCase: return "Raw enum value doesn't match any cases"
        case .unexpectedNullPointer: return "Raw pointer value was null"
        case .unexpectedRustCallStatusCode: return "Unexpected RustCallStatus code"
        case .unexpectedRustCallError: return "CALL_ERROR but no errorClass specified"
        case .unexpectedStaleHandle: return "The object in the handle map has been dropped already"
        case let .rustPanic(message): return message
        }
    }
}

private let CALL_SUCCESS: Int8 = 0
private let CALL_ERROR: Int8 = 1
private let CALL_PANIC: Int8 = 2

private extension RustCallStatus {
    init() {
        self.init(
            code: CALL_SUCCESS,
            errorBuf: RustBuffer(
                capacity: 0,
                len: 0,
                data: nil
            )
        )
    }
}

private func rustCall<T>(_ callback: (UnsafeMutablePointer<RustCallStatus>) -> T) throws -> T {
    try makeRustCall(callback, errorHandler: nil)
}

private func rustCallWithError<T>(
    _ errorHandler: @escaping (RustBuffer) throws -> Error,
    _ callback: (UnsafeMutablePointer<RustCallStatus>) -> T
) throws -> T {
    try makeRustCall(callback, errorHandler: errorHandler)
}

private func makeRustCall<T>(
    _ callback: (UnsafeMutablePointer<RustCallStatus>) -> T,
    errorHandler: ((RustBuffer) throws -> Error)?
) throws -> T {
    uniffiEnsureInitialized()
    var callStatus = RustCallStatus()
    let returnedVal = callback(&callStatus)
    try uniffiCheckCallStatus(callStatus: callStatus, errorHandler: errorHandler)
    return returnedVal
}

private func uniffiCheckCallStatus(
    callStatus: RustCallStatus,
    errorHandler: ((RustBuffer) throws -> Error)?
) throws {
    switch callStatus.code {
    case CALL_SUCCESS:
        return

    case CALL_ERROR:
        if let errorHandler = errorHandler {
            throw try errorHandler(callStatus.errorBuf)
        } else {
            callStatus.errorBuf.deallocate()
            throw UniffiInternalError.unexpectedRustCallError
        }

    case CALL_PANIC:
        // When the rust code sees a panic, it tries to construct a RustBuffer
        // with the message.  But if that code panics, then it just sends back
        // an empty buffer.
        if callStatus.errorBuf.len > 0 {
            throw try UniffiInternalError.rustPanic(FfiConverterString.lift(callStatus.errorBuf))
        } else {
            callStatus.errorBuf.deallocate()
            throw UniffiInternalError.rustPanic("Rust panic")
        }

    default:
        throw UniffiInternalError.unexpectedRustCallStatusCode
    }
}

// Public interface members begin here.

private struct FfiConverterUInt64: FfiConverterPrimitive {
    typealias FfiType = UInt64
    typealias SwiftType = UInt64

    public static func read(from buf: inout (data: Data, offset: Data.Index)) throws -> UInt64 {
        return try lift(readInt(&buf))
    }

    public static func write(_ value: SwiftType, into buf: inout [UInt8]) {
        writeInt(&buf, lower(value))
    }
}

private struct FfiConverterBool: FfiConverter {
    typealias FfiType = Int8
    typealias SwiftType = Bool

    public static func lift(_ value: Int8) throws -> Bool {
        return value != 0
    }

    public static func lower(_ value: Bool) -> Int8 {
        return value ? 1 : 0
    }

    public static func read(from buf: inout (data: Data, offset: Data.Index)) throws -> Bool {
        return try lift(readInt(&buf))
    }

    public static func write(_ value: Bool, into buf: inout [UInt8]) {
        writeInt(&buf, lower(value))
    }
}

private struct FfiConverterString: FfiConverter {
    typealias SwiftType = String
    typealias FfiType = RustBuffer

    public static func lift(_ value: RustBuffer) throws -> String {
        defer {
            value.deallocate()
        }
        if value.data == nil {
            return String()
        }
        let bytes = UnsafeBufferPointer<UInt8>(start: value.data!, count: Int(value.len))
        return String(bytes: bytes, encoding: String.Encoding.utf8)!
    }

    public static func lower(_ value: String) -> RustBuffer {
        return value.utf8CString.withUnsafeBufferPointer { ptr in
            // The swift string gives us int8_t, we want uint8_t.
            ptr.withMemoryRebound(to: UInt8.self) { ptr in
                // The swift string gives us a trailing null byte, we don't want it.
                let buf = UnsafeBufferPointer(rebasing: ptr.prefix(upTo: ptr.count - 1))
                return RustBuffer.from(buf)
            }
        }
    }

    public static func read(from buf: inout (data: Data, offset: Data.Index)) throws -> String {
        let len: Int32 = try readInt(&buf)
        return try String(bytes: readBytes(&buf, count: Int(len)), encoding: String.Encoding.utf8)!
    }

    public static func write(_ value: String, into buf: inout [UInt8]) {
        let len = Int32(value.utf8.count)
        writeInt(&buf, len)
        writeBytes(&buf, value.utf8)
    }
}

public protocol RemoteSettingsProtocol {
    func getRecords() throws -> RemoteSettingsResponse
    func getRecordsSince(timestamp: UInt64) throws -> RemoteSettingsResponse
    func downloadAttachmentToPath(attachmentId: String, path: String) throws
}

public class RemoteSettings: RemoteSettingsProtocol {
    fileprivate let pointer: UnsafeMutableRawPointer

    // TODO: We'd like this to be `private` but for Swifty reasons,
    // we can't implement `FfiConverter` without making this `required` and we can't
    // make it `required` without making it `public`.
    required init(unsafeFromRawPointer pointer: UnsafeMutableRawPointer) {
        self.pointer = pointer
    }

    public convenience init(remoteSettingsConfig: RemoteSettingsConfig) throws {
        try self.init(unsafeFromRawPointer: rustCallWithError(FfiConverterTypeRemoteSettingsError.lift) {
            uniffi_remote_settings_fn_constructor_remotesettings_new(
                FfiConverterTypeRemoteSettingsConfig.lower(remoteSettingsConfig), $0
            )
        })
    }

    deinit {
        try! rustCall { uniffi_remote_settings_fn_free_remotesettings(pointer, $0) }
    }

    public func getRecords() throws -> RemoteSettingsResponse {
        return try FfiConverterTypeRemoteSettingsResponse.lift(
            rustCallWithError(FfiConverterTypeRemoteSettingsError.lift) {
                uniffi_remote_settings_fn_method_remotesettings_get_records(self.pointer, $0)
            }
        )
    }

    public func getRecordsSince(timestamp: UInt64) throws -> RemoteSettingsResponse {
        return try FfiConverterTypeRemoteSettingsResponse.lift(
            rustCallWithError(FfiConverterTypeRemoteSettingsError.lift) {
                uniffi_remote_settings_fn_method_remotesettings_get_records_since(self.pointer,
                                                                                  FfiConverterUInt64.lower(timestamp), $0)
            }
        )
    }

    public func downloadAttachmentToPath(attachmentId: String, path: String) throws {
        try
            rustCallWithError(FfiConverterTypeRemoteSettingsError.lift) {
                uniffi_remote_settings_fn_method_remotesettings_download_attachment_to_path(self.pointer,
                                                                                            FfiConverterString.lower(attachmentId),
                                                                                            FfiConverterString.lower(path), $0)
            }
    }
}

public struct FfiConverterTypeRemoteSettings: FfiConverter {
    typealias FfiType = UnsafeMutableRawPointer
    typealias SwiftType = RemoteSettings

    public static func read(from buf: inout (data: Data, offset: Data.Index)) throws -> RemoteSettings {
        let v: UInt64 = try readInt(&buf)
        // The Rust code won't compile if a pointer won't fit in a UInt64.
        // We have to go via `UInt` because that's the thing that's the size of a pointer.
        let ptr = UnsafeMutableRawPointer(bitPattern: UInt(truncatingIfNeeded: v))
        if ptr == nil {
            throw UniffiInternalError.unexpectedNullPointer
        }
        return try lift(ptr!)
    }

    public static func write(_ value: RemoteSettings, into buf: inout [UInt8]) {
        // This fiddling is because `Int` is the thing that's the same size as a pointer.
        // The Rust code won't compile if a pointer won't fit in a `UInt64`.
        writeInt(&buf, UInt64(bitPattern: Int64(Int(bitPattern: lower(value)))))
    }

    public static func lift(_ pointer: UnsafeMutableRawPointer) throws -> RemoteSettings {
        return RemoteSettings(unsafeFromRawPointer: pointer)
    }

    public static func lower(_ value: RemoteSettings) -> UnsafeMutableRawPointer {
        return value.pointer
    }
}

public func FfiConverterTypeRemoteSettings_lift(_ pointer: UnsafeMutableRawPointer) throws -> RemoteSettings {
    return try FfiConverterTypeRemoteSettings.lift(pointer)
}

public func FfiConverterTypeRemoteSettings_lower(_ value: RemoteSettings) -> UnsafeMutableRawPointer {
    return FfiConverterTypeRemoteSettings.lower(value)
}

public struct Attachment {
    public var filename: String
    public var mimetype: String
    public var location: String
    public var hash: String
    public var size: UInt64

    // Default memberwise initializers are never public by default, so we
    // declare one manually.
    public init(filename: String, mimetype: String, location: String, hash: String, size: UInt64) {
        self.filename = filename
        self.mimetype = mimetype
        self.location = location
        self.hash = hash
        self.size = size
    }
}

extension Attachment: Equatable, Hashable {
    public static func == (lhs: Attachment, rhs: Attachment) -> Bool {
        if lhs.filename != rhs.filename {
            return false
        }
        if lhs.mimetype != rhs.mimetype {
            return false
        }
        if lhs.location != rhs.location {
            return false
        }
        if lhs.hash != rhs.hash {
            return false
        }
        if lhs.size != rhs.size {
            return false
        }
        return true
    }

    public func hash(into hasher: inout Hasher) {
        hasher.combine(filename)
        hasher.combine(mimetype)
        hasher.combine(location)
        hasher.combine(hash)
        hasher.combine(size)
    }
}

public struct FfiConverterTypeAttachment: FfiConverterRustBuffer {
    public static func read(from buf: inout (data: Data, offset: Data.Index)) throws -> Attachment {
        return try Attachment(
            filename: FfiConverterString.read(from: &buf),
            mimetype: FfiConverterString.read(from: &buf),
            location: FfiConverterString.read(from: &buf),
            hash: FfiConverterString.read(from: &buf),
            size: FfiConverterUInt64.read(from: &buf)
        )
    }

    public static func write(_ value: Attachment, into buf: inout [UInt8]) {
        FfiConverterString.write(value.filename, into: &buf)
        FfiConverterString.write(value.mimetype, into: &buf)
        FfiConverterString.write(value.location, into: &buf)
        FfiConverterString.write(value.hash, into: &buf)
        FfiConverterUInt64.write(value.size, into: &buf)
    }
}

public func FfiConverterTypeAttachment_lift(_ buf: RustBuffer) throws -> Attachment {
    return try FfiConverterTypeAttachment.lift(buf)
}

public func FfiConverterTypeAttachment_lower(_ value: Attachment) -> RustBuffer {
    return FfiConverterTypeAttachment.lower(value)
}

public struct RemoteSettingsConfig {
    public var serverUrl: String?
    public var bucketName: String?
    public var collectionName: String

    // Default memberwise initializers are never public by default, so we
    // declare one manually.
    public init(serverUrl: String? = nil, bucketName: String? = nil, collectionName: String) {
        self.serverUrl = serverUrl
        self.bucketName = bucketName
        self.collectionName = collectionName
    }
}

extension RemoteSettingsConfig: Equatable, Hashable {
    public static func == (lhs: RemoteSettingsConfig, rhs: RemoteSettingsConfig) -> Bool {
        if lhs.serverUrl != rhs.serverUrl {
            return false
        }
        if lhs.bucketName != rhs.bucketName {
            return false
        }
        if lhs.collectionName != rhs.collectionName {
            return false
        }
        return true
    }

    public func hash(into hasher: inout Hasher) {
        hasher.combine(serverUrl)
        hasher.combine(bucketName)
        hasher.combine(collectionName)
    }
}

public struct FfiConverterTypeRemoteSettingsConfig: FfiConverterRustBuffer {
    public static func read(from buf: inout (data: Data, offset: Data.Index)) throws -> RemoteSettingsConfig {
        return try RemoteSettingsConfig(
            serverUrl: FfiConverterOptionString.read(from: &buf),
            bucketName: FfiConverterOptionString.read(from: &buf),
            collectionName: FfiConverterString.read(from: &buf)
        )
    }

    public static func write(_ value: RemoteSettingsConfig, into buf: inout [UInt8]) {
        FfiConverterOptionString.write(value.serverUrl, into: &buf)
        FfiConverterOptionString.write(value.bucketName, into: &buf)
        FfiConverterString.write(value.collectionName, into: &buf)
    }
}

public func FfiConverterTypeRemoteSettingsConfig_lift(_ buf: RustBuffer) throws -> RemoteSettingsConfig {
    return try FfiConverterTypeRemoteSettingsConfig.lift(buf)
}

public func FfiConverterTypeRemoteSettingsConfig_lower(_ value: RemoteSettingsConfig) -> RustBuffer {
    return FfiConverterTypeRemoteSettingsConfig.lower(value)
}

public struct RemoteSettingsRecord {
    public var id: String
    public var lastModified: UInt64
    public var deleted: Bool
    public var attachment: Attachment?
    public var fields: RsJsonObject

    // Default memberwise initializers are never public by default, so we
    // declare one manually.
    public init(id: String, lastModified: UInt64, deleted: Bool, attachment: Attachment?, fields: RsJsonObject) {
        self.id = id
        self.lastModified = lastModified
        self.deleted = deleted
        self.attachment = attachment
        self.fields = fields
    }
}

extension RemoteSettingsRecord: Equatable, Hashable {
    public static func == (lhs: RemoteSettingsRecord, rhs: RemoteSettingsRecord) -> Bool {
        if lhs.id != rhs.id {
            return false
        }
        if lhs.lastModified != rhs.lastModified {
            return false
        }
        if lhs.deleted != rhs.deleted {
            return false
        }
        if lhs.attachment != rhs.attachment {
            return false
        }
        if lhs.fields != rhs.fields {
            return false
        }
        return true
    }

    public func hash(into hasher: inout Hasher) {
        hasher.combine(id)
        hasher.combine(lastModified)
        hasher.combine(deleted)
        hasher.combine(attachment)
        hasher.combine(fields)
    }
}

public struct FfiConverterTypeRemoteSettingsRecord: FfiConverterRustBuffer {
    public static func read(from buf: inout (data: Data, offset: Data.Index)) throws -> RemoteSettingsRecord {
        return try RemoteSettingsRecord(
            id: FfiConverterString.read(from: &buf),
            lastModified: FfiConverterUInt64.read(from: &buf),
            deleted: FfiConverterBool.read(from: &buf),
            attachment: FfiConverterOptionTypeAttachment.read(from: &buf),
            fields: FfiConverterTypeRsJsonObject.read(from: &buf)
        )
    }

    public static func write(_ value: RemoteSettingsRecord, into buf: inout [UInt8]) {
        FfiConverterString.write(value.id, into: &buf)
        FfiConverterUInt64.write(value.lastModified, into: &buf)
        FfiConverterBool.write(value.deleted, into: &buf)
        FfiConverterOptionTypeAttachment.write(value.attachment, into: &buf)
        FfiConverterTypeRsJsonObject.write(value.fields, into: &buf)
    }
}

public func FfiConverterTypeRemoteSettingsRecord_lift(_ buf: RustBuffer) throws -> RemoteSettingsRecord {
    return try FfiConverterTypeRemoteSettingsRecord.lift(buf)
}

public func FfiConverterTypeRemoteSettingsRecord_lower(_ value: RemoteSettingsRecord) -> RustBuffer {
    return FfiConverterTypeRemoteSettingsRecord.lower(value)
}

public struct RemoteSettingsResponse {
    public var records: [RemoteSettingsRecord]
    public var lastModified: UInt64

    // Default memberwise initializers are never public by default, so we
    // declare one manually.
    public init(records: [RemoteSettingsRecord], lastModified: UInt64) {
        self.records = records
        self.lastModified = lastModified
    }
}

extension RemoteSettingsResponse: Equatable, Hashable {
    public static func == (lhs: RemoteSettingsResponse, rhs: RemoteSettingsResponse) -> Bool {
        if lhs.records != rhs.records {
            return false
        }
        if lhs.lastModified != rhs.lastModified {
            return false
        }
        return true
    }

    public func hash(into hasher: inout Hasher) {
        hasher.combine(records)
        hasher.combine(lastModified)
    }
}

public struct FfiConverterTypeRemoteSettingsResponse: FfiConverterRustBuffer {
    public static func read(from buf: inout (data: Data, offset: Data.Index)) throws -> RemoteSettingsResponse {
        return try RemoteSettingsResponse(
            records: FfiConverterSequenceTypeRemoteSettingsRecord.read(from: &buf),
            lastModified: FfiConverterUInt64.read(from: &buf)
        )
    }

    public static func write(_ value: RemoteSettingsResponse, into buf: inout [UInt8]) {
        FfiConverterSequenceTypeRemoteSettingsRecord.write(value.records, into: &buf)
        FfiConverterUInt64.write(value.lastModified, into: &buf)
    }
}

public func FfiConverterTypeRemoteSettingsResponse_lift(_ buf: RustBuffer) throws -> RemoteSettingsResponse {
    return try FfiConverterTypeRemoteSettingsResponse.lift(buf)
}

public func FfiConverterTypeRemoteSettingsResponse_lower(_ value: RemoteSettingsResponse) -> RustBuffer {
    return FfiConverterTypeRemoteSettingsResponse.lower(value)
}

public enum RemoteSettingsError {
    // Simple error enums only carry a message
    case JsonError(message: String)

    // Simple error enums only carry a message
    case FileError(message: String)

    // Simple error enums only carry a message
    case RequestError(message: String)

    // Simple error enums only carry a message
    case UrlParsingError(message: String)

    // Simple error enums only carry a message
    case BackoffError(message: String)

    // Simple error enums only carry a message
    case ResponseError(message: String)

    // Simple error enums only carry a message
    case AttachmentsUnsupportedError(message: String)

    fileprivate static func uniffiErrorHandler(_ error: RustBuffer) throws -> Error {
        return try FfiConverterTypeRemoteSettingsError.lift(error)
    }
}

public struct FfiConverterTypeRemoteSettingsError: FfiConverterRustBuffer {
    typealias SwiftType = RemoteSettingsError

    public static func read(from buf: inout (data: Data, offset: Data.Index)) throws -> RemoteSettingsError {
        let variant: Int32 = try readInt(&buf)
        switch variant {
        case 1: return try .JsonError(
                message: FfiConverterString.read(from: &buf)
            )

        case 2: return try .FileError(
                message: FfiConverterString.read(from: &buf)
            )

        case 3: return try .RequestError(
                message: FfiConverterString.read(from: &buf)
            )

        case 4: return try .UrlParsingError(
                message: FfiConverterString.read(from: &buf)
            )

        case 5: return try .BackoffError(
                message: FfiConverterString.read(from: &buf)
            )

        case 6: return try .ResponseError(
                message: FfiConverterString.read(from: &buf)
            )

        case 7: return try .AttachmentsUnsupportedError(
                message: FfiConverterString.read(from: &buf)
            )

        default: throw UniffiInternalError.unexpectedEnumCase
        }
    }

    public static func write(_ value: RemoteSettingsError, into buf: inout [UInt8]) {
        switch value {
        case let .JsonError(message):
            writeInt(&buf, Int32(1))
        case let .FileError(message):
            writeInt(&buf, Int32(2))
        case let .RequestError(message):
            writeInt(&buf, Int32(3))
        case let .UrlParsingError(message):
            writeInt(&buf, Int32(4))
        case let .BackoffError(message):
            writeInt(&buf, Int32(5))
        case let .ResponseError(message):
            writeInt(&buf, Int32(6))
        case let .AttachmentsUnsupportedError(message):
            writeInt(&buf, Int32(7))
        }
    }
}

extension RemoteSettingsError: Equatable, Hashable {}

extension RemoteSettingsError: Error {}

private struct FfiConverterOptionString: FfiConverterRustBuffer {
    typealias SwiftType = String?

    public static func write(_ value: SwiftType, into buf: inout [UInt8]) {
        guard let value = value else {
            writeInt(&buf, Int8(0))
            return
        }
        writeInt(&buf, Int8(1))
        FfiConverterString.write(value, into: &buf)
    }

    public static func read(from buf: inout (data: Data, offset: Data.Index)) throws -> SwiftType {
        switch try readInt(&buf) as Int8 {
        case 0: return nil
        case 1: return try FfiConverterString.read(from: &buf)
        default: throw UniffiInternalError.unexpectedOptionalTag
        }
    }
}

private struct FfiConverterOptionTypeAttachment: FfiConverterRustBuffer {
    typealias SwiftType = Attachment?

    public static func write(_ value: SwiftType, into buf: inout [UInt8]) {
        guard let value = value else {
            writeInt(&buf, Int8(0))
            return
        }
        writeInt(&buf, Int8(1))
        FfiConverterTypeAttachment.write(value, into: &buf)
    }

    public static func read(from buf: inout (data: Data, offset: Data.Index)) throws -> SwiftType {
        switch try readInt(&buf) as Int8 {
        case 0: return nil
        case 1: return try FfiConverterTypeAttachment.read(from: &buf)
        default: throw UniffiInternalError.unexpectedOptionalTag
        }
    }
}

private struct FfiConverterSequenceTypeRemoteSettingsRecord: FfiConverterRustBuffer {
    typealias SwiftType = [RemoteSettingsRecord]

    public static func write(_ value: [RemoteSettingsRecord], into buf: inout [UInt8]) {
        let len = Int32(value.count)
        writeInt(&buf, len)
        for item in value {
            FfiConverterTypeRemoteSettingsRecord.write(item, into: &buf)
        }
    }

    public static func read(from buf: inout (data: Data, offset: Data.Index)) throws -> [RemoteSettingsRecord] {
        let len: Int32 = try readInt(&buf)
        var seq = [RemoteSettingsRecord]()
        seq.reserveCapacity(Int(len))
        for _ in 0 ..< len {
            try seq.append(FfiConverterTypeRemoteSettingsRecord.read(from: &buf))
        }
        return seq
    }
}

/**
 * Typealias from the type name used in the UDL file to the builtin type.  This
 * is needed because the UDL type name is used in function/method signatures.
 */
public typealias RsJsonObject = String
public struct FfiConverterTypeRsJsonObject: FfiConverter {
    public static func read(from buf: inout (data: Data, offset: Data.Index)) throws -> RsJsonObject {
        return try FfiConverterString.read(from: &buf)
    }

    public static func write(_ value: RsJsonObject, into buf: inout [UInt8]) {
        return FfiConverterString.write(value, into: &buf)
    }

    public static func lift(_ value: RustBuffer) throws -> RsJsonObject {
        return try FfiConverterString.lift(value)
    }

    public static func lower(_ value: RsJsonObject) -> RustBuffer {
        return FfiConverterString.lower(value)
    }
}

private enum InitializationResult {
    case ok
    case contractVersionMismatch
    case apiChecksumMismatch
}

// Use a global variables to perform the versioning checks. Swift ensures that
// the code inside is only computed once.
private var initializationResult: InitializationResult {
    // Get the bindings contract version from our ComponentInterface
    let bindings_contract_version = 22
    // Get the scaffolding contract version by calling the into the dylib
    let scaffolding_contract_version = ffi_remote_settings_uniffi_contract_version()
    if bindings_contract_version != scaffolding_contract_version {
        return InitializationResult.contractVersionMismatch
    }
    if uniffi_remote_settings_checksum_method_remotesettings_get_records() != 15844 {
        return InitializationResult.apiChecksumMismatch
    }
    if uniffi_remote_settings_checksum_method_remotesettings_get_records_since() != 44273 {
        return InitializationResult.apiChecksumMismatch
    }
    if uniffi_remote_settings_checksum_method_remotesettings_download_attachment_to_path() != 21493 {
        return InitializationResult.apiChecksumMismatch
    }
    if uniffi_remote_settings_checksum_constructor_remotesettings_new() != 53609 {
        return InitializationResult.apiChecksumMismatch
    }

    return InitializationResult.ok
}

private func uniffiEnsureInitialized() {
    switch initializationResult {
    case .ok:
        break
    case .contractVersionMismatch:
        fatalError("UniFFI contract version mismatch: try cleaning and rebuilding your project")
    case .apiChecksumMismatch:
        fatalError("UniFFI API checksum mismatch: try cleaning and rebuilding your project")
    }
}
