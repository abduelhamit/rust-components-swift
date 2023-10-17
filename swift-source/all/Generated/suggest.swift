// This file was autogenerated by some hot garbage in the `uniffi` crate.
// Trust me, you don't want to mess with it!
import Foundation

// Depending on the consumer's build setup, the low-level FFI code
// might be in a separate module, or it might be compiled inline into
// this module. This is a bit of light hackery to work with both.
#if canImport(MozillaRustComponents)
import MozillaRustComponents
#endif

fileprivate extension RustBuffer {
    // Allocate a new buffer, copying the contents of a `UInt8` array.
    init(bytes: [UInt8]) {
        let rbuf = bytes.withUnsafeBufferPointer { ptr in
            RustBuffer.from(ptr)
        }
        self.init(capacity: rbuf.capacity, len: rbuf.len, data: rbuf.data)
    }

    static func from(_ ptr: UnsafeBufferPointer<UInt8>) -> RustBuffer {
        try! rustCall { ffi_suggest_rustbuffer_from_bytes(ForeignBytes(bufferPointer: ptr), $0) }
    }

    // Frees the buffer in place.
    // The buffer must not be used after this is called.
    func deallocate() {
        try! rustCall { ffi_suggest_rustbuffer_free(self, $0) }
    }
}

fileprivate extension ForeignBytes {
    init(bufferPointer: UnsafeBufferPointer<UInt8>) {
        self.init(len: Int32(bufferPointer.count), data: bufferPointer.baseAddress)
    }
}

// For every type used in the interface, we provide helper methods for conveniently
// lifting and lowering that type from C-compatible data, and for reading and writing
// values of that type in a buffer.

// Helper classes/extensions that don't change.
// Someday, this will be in a library of its own.

fileprivate extension Data {
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

fileprivate func createReader(data: Data) -> (data: Data, offset: Data.Index) {
    (data: data, offset: 0)
}

// Reads an integer at the current offset, in big-endian order, and advances
// the offset on success. Throws if reading the integer would move the
// offset past the end of the buffer.
fileprivate func readInt<T: FixedWidthInteger>(_ reader: inout (data: Data, offset: Data.Index)) throws -> T {
    let range = reader.offset..<reader.offset + MemoryLayout<T>.size
    guard reader.data.count >= range.upperBound else {
        throw UniffiInternalError.bufferOverflow
    }
    if T.self == UInt8.self {
        let value = reader.data[reader.offset]
        reader.offset += 1
        return value as! T
    }
    var value: T = 0
    let _ = withUnsafeMutableBytes(of: &value, { reader.data.copyBytes(to: $0, from: range)})
    reader.offset = range.upperBound
    return value.bigEndian
}

// Reads an arbitrary number of bytes, to be used to read
// raw bytes, this is useful when lifting strings
fileprivate func readBytes(_ reader: inout (data: Data, offset: Data.Index), count: Int) throws -> Array<UInt8> {
    let range = reader.offset..<(reader.offset+count)
    guard reader.data.count >= range.upperBound else {
        throw UniffiInternalError.bufferOverflow
    }
    var value = [UInt8](repeating: 0, count: count)
    value.withUnsafeMutableBufferPointer({ buffer in
        reader.data.copyBytes(to: buffer, from: range)
    })
    reader.offset = range.upperBound
    return value
}

// Reads a float at the current offset.
fileprivate func readFloat(_ reader: inout (data: Data, offset: Data.Index)) throws -> Float {
    return Float(bitPattern: try readInt(&reader))
}

// Reads a float at the current offset.
fileprivate func readDouble(_ reader: inout (data: Data, offset: Data.Index)) throws -> Double {
    return Double(bitPattern: try readInt(&reader))
}

// Indicates if the offset has reached the end of the buffer.
fileprivate func hasRemaining(_ reader: (data: Data, offset: Data.Index)) -> Bool {
    return reader.offset < reader.data.count
}

// Define writer functionality.  Normally this would be defined in a class or
// struct, but we use standalone functions instead in order to make external
// types work.  See the above discussion on Readers for details.

fileprivate func createWriter() -> [UInt8] {
    return []
}

fileprivate func writeBytes<S>(_ writer: inout [UInt8], _ byteArr: S) where S: Sequence, S.Element == UInt8 {
    writer.append(contentsOf: byteArr)
}

// Writes an integer in big-endian order.
//
// Warning: make sure what you are trying to write
// is in the correct type!
fileprivate func writeInt<T: FixedWidthInteger>(_ writer: inout [UInt8], _ value: T) {
    var value = value.bigEndian
    withUnsafeBytes(of: &value) { writer.append(contentsOf: $0) }
}

fileprivate func writeFloat(_ writer: inout [UInt8], _ value: Float) {
    writeInt(&writer, value.bitPattern)
}

fileprivate func writeDouble(_ writer: inout [UInt8], _ value: Double) {
    writeInt(&writer, value.bitPattern)
}

// Protocol for types that transfer other types across the FFI. This is
// analogous go the Rust trait of the same name.
fileprivate protocol FfiConverter {
    associatedtype FfiType
    associatedtype SwiftType

    static func lift(_ value: FfiType) throws -> SwiftType
    static func lower(_ value: SwiftType) -> FfiType
    static func read(from buf: inout (data: Data, offset: Data.Index)) throws -> SwiftType
    static func write(_ value: SwiftType, into buf: inout [UInt8])
}

// Types conforming to `Primitive` pass themselves directly over the FFI.
fileprivate protocol FfiConverterPrimitive: FfiConverter where FfiType == SwiftType { }

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
fileprivate protocol FfiConverterRustBuffer: FfiConverter where FfiType == RustBuffer {}

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
fileprivate enum UniffiInternalError: LocalizedError {
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

fileprivate let CALL_SUCCESS: Int8 = 0
fileprivate let CALL_ERROR: Int8 = 1
fileprivate let CALL_PANIC: Int8 = 2

fileprivate extension RustCallStatus {
    init() {
        self.init(
            code: CALL_SUCCESS,
            errorBuf: RustBuffer.init(
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
    _ callback: (UnsafeMutablePointer<RustCallStatus>) -> T) throws -> T {
    try makeRustCall(callback, errorHandler: errorHandler)
}

private func makeRustCall<T>(
    _ callback: (UnsafeMutablePointer<RustCallStatus>) -> T,
    errorHandler: ((RustBuffer) throws -> Error)?
) throws -> T {
    uniffiEnsureInitialized()
    var callStatus = RustCallStatus.init()
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
                throw UniffiInternalError.rustPanic(try FfiConverterString.lift(callStatus.errorBuf))
            } else {
                callStatus.errorBuf.deallocate()
                throw UniffiInternalError.rustPanic("Rust panic")
            }

        default:
            throw UniffiInternalError.unexpectedRustCallStatusCode
    }
}

// Public interface members begin here.


fileprivate struct FfiConverterUInt8: FfiConverterPrimitive {
    typealias FfiType = UInt8
    typealias SwiftType = UInt8

    public static func read(from buf: inout (data: Data, offset: Data.Index)) throws -> UInt8 {
        return try lift(readInt(&buf))
    }

    public static func write(_ value: UInt8, into buf: inout [UInt8]) {
        writeInt(&buf, lower(value))
    }
}

fileprivate struct FfiConverterInt32: FfiConverterPrimitive {
    typealias FfiType = Int32
    typealias SwiftType = Int32

    public static func read(from buf: inout (data: Data, offset: Data.Index)) throws -> Int32 {
        return try lift(readInt(&buf))
    }

    public static func write(_ value: Int32, into buf: inout [UInt8]) {
        writeInt(&buf, lower(value))
    }
}

fileprivate struct FfiConverterUInt64: FfiConverterPrimitive {
    typealias FfiType = UInt64
    typealias SwiftType = UInt64

    public static func read(from buf: inout (data: Data, offset: Data.Index)) throws -> UInt64 {
        return try lift(readInt(&buf))
    }

    public static func write(_ value: SwiftType, into buf: inout [UInt8]) {
        writeInt(&buf, lower(value))
    }
}

fileprivate struct FfiConverterInt64: FfiConverterPrimitive {
    typealias FfiType = Int64
    typealias SwiftType = Int64

    public static func read(from buf: inout (data: Data, offset: Data.Index)) throws -> Int64 {
        return try lift(readInt(&buf))
    }

    public static func write(_ value: Int64, into buf: inout [UInt8]) {
        writeInt(&buf, lower(value))
    }
}

fileprivate struct FfiConverterDouble: FfiConverterPrimitive {
    typealias FfiType = Double
    typealias SwiftType = Double

    public static func read(from buf: inout (data: Data, offset: Data.Index)) throws -> Double {
        return try lift(readDouble(&buf))
    }

    public static func write(_ value: Double, into buf: inout [UInt8]) {
        writeDouble(&buf, lower(value))
    }
}

fileprivate struct FfiConverterBool : FfiConverter {
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

fileprivate struct FfiConverterString: FfiConverter {
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
        return String(bytes: try readBytes(&buf, count: Int(len)), encoding: String.Encoding.utf8)!
    }

    public static func write(_ value: String, into buf: inout [UInt8]) {
        let len = Int32(value.utf8.count)
        writeInt(&buf, len)
        writeBytes(&buf, value.utf8)
    }
}


public protocol SuggestStoreProtocol {
    func `query`(`query`: SuggestionQuery)  throws -> [Suggestion]
    func `interrupt`()  
    func `ingest`(`constraints`: SuggestIngestionConstraints)  throws
    func `clear`()  throws
    
}

public class SuggestStore: SuggestStoreProtocol {
    fileprivate let pointer: UnsafeMutableRawPointer

    // TODO: We'd like this to be `private` but for Swifty reasons,
    // we can't implement `FfiConverter` without making this `required` and we can't
    // make it `required` without making it `public`.
    required init(unsafeFromRawPointer pointer: UnsafeMutableRawPointer) {
        self.pointer = pointer
    }
    public convenience init(`path`: String, `settingsConfig`: RemoteSettingsConfig? = nil) throws {
        self.init(unsafeFromRawPointer: try rustCallWithError(FfiConverterTypeSuggestApiError.lift) {
    uniffi_suggest_fn_constructor_suggeststore_new(
        FfiConverterString.lower(`path`),
        FfiConverterOptionTypeRemoteSettingsConfig.lower(`settingsConfig`),$0)
})
    }

    deinit {
        try! rustCall { uniffi_suggest_fn_free_suggeststore(pointer, $0) }
    }

    

    
    

    public func `query`(`query`: SuggestionQuery) throws -> [Suggestion] {
        return try  FfiConverterSequenceTypeSuggestion.lift(
            try 
    rustCallWithError(FfiConverterTypeSuggestApiError.lift) {
    uniffi_suggest_fn_method_suggeststore_query(self.pointer, 
        FfiConverterTypeSuggestionQuery.lower(`query`),$0
    )
}
        )
    }

    public func `interrupt`()  {
        try! 
    rustCall() {
    
    uniffi_suggest_fn_method_suggeststore_interrupt(self.pointer, $0
    )
}
    }

    public func `ingest`(`constraints`: SuggestIngestionConstraints) throws {
        try 
    rustCallWithError(FfiConverterTypeSuggestApiError.lift) {
    uniffi_suggest_fn_method_suggeststore_ingest(self.pointer, 
        FfiConverterTypeSuggestIngestionConstraints.lower(`constraints`),$0
    )
}
    }

    public func `clear`() throws {
        try 
    rustCallWithError(FfiConverterTypeSuggestApiError.lift) {
    uniffi_suggest_fn_method_suggeststore_clear(self.pointer, $0
    )
}
    }
}

public struct FfiConverterTypeSuggestStore: FfiConverter {
    typealias FfiType = UnsafeMutableRawPointer
    typealias SwiftType = SuggestStore

    public static func read(from buf: inout (data: Data, offset: Data.Index)) throws -> SuggestStore {
        let v: UInt64 = try readInt(&buf)
        // The Rust code won't compile if a pointer won't fit in a UInt64.
        // We have to go via `UInt` because that's the thing that's the size of a pointer.
        let ptr = UnsafeMutableRawPointer(bitPattern: UInt(truncatingIfNeeded: v))
        if (ptr == nil) {
            throw UniffiInternalError.unexpectedNullPointer
        }
        return try lift(ptr!)
    }

    public static func write(_ value: SuggestStore, into buf: inout [UInt8]) {
        // This fiddling is because `Int` is the thing that's the same size as a pointer.
        // The Rust code won't compile if a pointer won't fit in a `UInt64`.
        writeInt(&buf, UInt64(bitPattern: Int64(Int(bitPattern: lower(value)))))
    }

    public static func lift(_ pointer: UnsafeMutableRawPointer) throws -> SuggestStore {
        return SuggestStore(unsafeFromRawPointer: pointer)
    }

    public static func lower(_ value: SuggestStore) -> UnsafeMutableRawPointer {
        return value.pointer
    }
}


public func FfiConverterTypeSuggestStore_lift(_ pointer: UnsafeMutableRawPointer) throws -> SuggestStore {
    return try FfiConverterTypeSuggestStore.lift(pointer)
}

public func FfiConverterTypeSuggestStore_lower(_ value: SuggestStore) -> UnsafeMutableRawPointer {
    return FfiConverterTypeSuggestStore.lower(value)
}


public struct SuggestIngestionConstraints {
    public var `maxSuggestions`: UInt64?

    // Default memberwise initializers are never public by default, so we
    // declare one manually.
    public init(`maxSuggestions`: UInt64? = nil) {
        self.`maxSuggestions` = `maxSuggestions`
    }
}


extension SuggestIngestionConstraints: Equatable, Hashable {
    public static func ==(lhs: SuggestIngestionConstraints, rhs: SuggestIngestionConstraints) -> Bool {
        if lhs.`maxSuggestions` != rhs.`maxSuggestions` {
            return false
        }
        return true
    }

    public func hash(into hasher: inout Hasher) {
        hasher.combine(`maxSuggestions`)
    }
}


public struct FfiConverterTypeSuggestIngestionConstraints: FfiConverterRustBuffer {
    public static func read(from buf: inout (data: Data, offset: Data.Index)) throws -> SuggestIngestionConstraints {
        return try SuggestIngestionConstraints(
            `maxSuggestions`: FfiConverterOptionUInt64.read(from: &buf)
        )
    }

    public static func write(_ value: SuggestIngestionConstraints, into buf: inout [UInt8]) {
        FfiConverterOptionUInt64.write(value.`maxSuggestions`, into: &buf)
    }
}


public func FfiConverterTypeSuggestIngestionConstraints_lift(_ buf: RustBuffer) throws -> SuggestIngestionConstraints {
    return try FfiConverterTypeSuggestIngestionConstraints.lift(buf)
}

public func FfiConverterTypeSuggestIngestionConstraints_lower(_ value: SuggestIngestionConstraints) -> RustBuffer {
    return FfiConverterTypeSuggestIngestionConstraints.lower(value)
}


public struct SuggestionQuery {
    public var `keyword`: String
    public var `providers`: [SuggestionProvider]
    public var `limit`: Int32?

    // Default memberwise initializers are never public by default, so we
    // declare one manually.
    public init(`keyword`: String, `providers`: [SuggestionProvider], `limit`: Int32? = nil) {
        self.`keyword` = `keyword`
        self.`providers` = `providers`
        self.`limit` = `limit`
    }
}


extension SuggestionQuery: Equatable, Hashable {
    public static func ==(lhs: SuggestionQuery, rhs: SuggestionQuery) -> Bool {
        if lhs.`keyword` != rhs.`keyword` {
            return false
        }
        if lhs.`providers` != rhs.`providers` {
            return false
        }
        if lhs.`limit` != rhs.`limit` {
            return false
        }
        return true
    }

    public func hash(into hasher: inout Hasher) {
        hasher.combine(`keyword`)
        hasher.combine(`providers`)
        hasher.combine(`limit`)
    }
}


public struct FfiConverterTypeSuggestionQuery: FfiConverterRustBuffer {
    public static func read(from buf: inout (data: Data, offset: Data.Index)) throws -> SuggestionQuery {
        return try SuggestionQuery(
            `keyword`: FfiConverterString.read(from: &buf), 
            `providers`: FfiConverterSequenceTypeSuggestionProvider.read(from: &buf), 
            `limit`: FfiConverterOptionInt32.read(from: &buf)
        )
    }

    public static func write(_ value: SuggestionQuery, into buf: inout [UInt8]) {
        FfiConverterString.write(value.`keyword`, into: &buf)
        FfiConverterSequenceTypeSuggestionProvider.write(value.`providers`, into: &buf)
        FfiConverterOptionInt32.write(value.`limit`, into: &buf)
    }
}


public func FfiConverterTypeSuggestionQuery_lift(_ buf: RustBuffer) throws -> SuggestionQuery {
    return try FfiConverterTypeSuggestionQuery.lift(buf)
}

public func FfiConverterTypeSuggestionQuery_lower(_ value: SuggestionQuery) -> RustBuffer {
    return FfiConverterTypeSuggestionQuery.lower(value)
}

public enum SuggestApiError {

    
    
    case Other(`reason`: String)

    fileprivate static func uniffiErrorHandler(_ error: RustBuffer) throws -> Error {
        return try FfiConverterTypeSuggestApiError.lift(error)
    }
}


public struct FfiConverterTypeSuggestApiError: FfiConverterRustBuffer {
    typealias SwiftType = SuggestApiError

    public static func read(from buf: inout (data: Data, offset: Data.Index)) throws -> SuggestApiError {
        let variant: Int32 = try readInt(&buf)
        switch variant {

        

        
        case 1: return .Other(
            `reason`: try FfiConverterString.read(from: &buf)
            )

         default: throw UniffiInternalError.unexpectedEnumCase
        }
    }

    public static func write(_ value: SuggestApiError, into buf: inout [UInt8]) {
        switch value {

        

        
        
        case let .Other(`reason`):
            writeInt(&buf, Int32(1))
            FfiConverterString.write(`reason`, into: &buf)
            
        }
    }
}


extension SuggestApiError: Equatable, Hashable {}

extension SuggestApiError: Error { }

// Note that we don't yet support `indirect` for enums.
// See https://github.com/mozilla/uniffi-rs/issues/396 for further discussion.
public enum Suggestion {
    
    case `amp`(`title`: String, `url`: String, `rawUrl`: String, `icon`: [UInt8]?, `fullKeyword`: String, `blockId`: Int64, `advertiser`: String, `iabCategory`: String, `impressionUrl`: String, `clickUrl`: String, `rawClickUrl`: String)
    case `pocket`(`title`: String, `url`: String, `score`: Double, `isTopPick`: Bool)
    case `wikipedia`(`title`: String, `url`: String, `icon`: [UInt8]?, `fullKeyword`: String)
    case `amo`(`title`: String, `url`: String, `iconUrl`: String, `description`: String, `rating`: String?, `numberOfRatings`: Int64, `guid`: String, `score`: Double)
}

public struct FfiConverterTypeSuggestion: FfiConverterRustBuffer {
    typealias SwiftType = Suggestion

    public static func read(from buf: inout (data: Data, offset: Data.Index)) throws -> Suggestion {
        let variant: Int32 = try readInt(&buf)
        switch variant {
        
        case 1: return .`amp`(
            `title`: try FfiConverterString.read(from: &buf), 
            `url`: try FfiConverterString.read(from: &buf), 
            `rawUrl`: try FfiConverterString.read(from: &buf), 
            `icon`: try FfiConverterOptionSequenceUInt8.read(from: &buf), 
            `fullKeyword`: try FfiConverterString.read(from: &buf), 
            `blockId`: try FfiConverterInt64.read(from: &buf), 
            `advertiser`: try FfiConverterString.read(from: &buf), 
            `iabCategory`: try FfiConverterString.read(from: &buf), 
            `impressionUrl`: try FfiConverterString.read(from: &buf), 
            `clickUrl`: try FfiConverterString.read(from: &buf), 
            `rawClickUrl`: try FfiConverterString.read(from: &buf)
        )
        
        case 2: return .`pocket`(
            `title`: try FfiConverterString.read(from: &buf), 
            `url`: try FfiConverterString.read(from: &buf), 
            `score`: try FfiConverterDouble.read(from: &buf), 
            `isTopPick`: try FfiConverterBool.read(from: &buf)
        )
        
        case 3: return .`wikipedia`(
            `title`: try FfiConverterString.read(from: &buf), 
            `url`: try FfiConverterString.read(from: &buf), 
            `icon`: try FfiConverterOptionSequenceUInt8.read(from: &buf), 
            `fullKeyword`: try FfiConverterString.read(from: &buf)
        )
        
        case 4: return .`amo`(
            `title`: try FfiConverterString.read(from: &buf), 
            `url`: try FfiConverterString.read(from: &buf), 
            `iconUrl`: try FfiConverterString.read(from: &buf), 
            `description`: try FfiConverterString.read(from: &buf), 
            `rating`: try FfiConverterOptionString.read(from: &buf), 
            `numberOfRatings`: try FfiConverterInt64.read(from: &buf), 
            `guid`: try FfiConverterString.read(from: &buf), 
            `score`: try FfiConverterDouble.read(from: &buf)
        )
        
        default: throw UniffiInternalError.unexpectedEnumCase
        }
    }

    public static func write(_ value: Suggestion, into buf: inout [UInt8]) {
        switch value {
        
        
        case let .`amp`(`title`,`url`,`rawUrl`,`icon`,`fullKeyword`,`blockId`,`advertiser`,`iabCategory`,`impressionUrl`,`clickUrl`,`rawClickUrl`):
            writeInt(&buf, Int32(1))
            FfiConverterString.write(`title`, into: &buf)
            FfiConverterString.write(`url`, into: &buf)
            FfiConverterString.write(`rawUrl`, into: &buf)
            FfiConverterOptionSequenceUInt8.write(`icon`, into: &buf)
            FfiConverterString.write(`fullKeyword`, into: &buf)
            FfiConverterInt64.write(`blockId`, into: &buf)
            FfiConverterString.write(`advertiser`, into: &buf)
            FfiConverterString.write(`iabCategory`, into: &buf)
            FfiConverterString.write(`impressionUrl`, into: &buf)
            FfiConverterString.write(`clickUrl`, into: &buf)
            FfiConverterString.write(`rawClickUrl`, into: &buf)
            
        
        case let .`pocket`(`title`,`url`,`score`,`isTopPick`):
            writeInt(&buf, Int32(2))
            FfiConverterString.write(`title`, into: &buf)
            FfiConverterString.write(`url`, into: &buf)
            FfiConverterDouble.write(`score`, into: &buf)
            FfiConverterBool.write(`isTopPick`, into: &buf)
            
        
        case let .`wikipedia`(`title`,`url`,`icon`,`fullKeyword`):
            writeInt(&buf, Int32(3))
            FfiConverterString.write(`title`, into: &buf)
            FfiConverterString.write(`url`, into: &buf)
            FfiConverterOptionSequenceUInt8.write(`icon`, into: &buf)
            FfiConverterString.write(`fullKeyword`, into: &buf)
            
        
        case let .`amo`(`title`,`url`,`iconUrl`,`description`,`rating`,`numberOfRatings`,`guid`,`score`):
            writeInt(&buf, Int32(4))
            FfiConverterString.write(`title`, into: &buf)
            FfiConverterString.write(`url`, into: &buf)
            FfiConverterString.write(`iconUrl`, into: &buf)
            FfiConverterString.write(`description`, into: &buf)
            FfiConverterOptionString.write(`rating`, into: &buf)
            FfiConverterInt64.write(`numberOfRatings`, into: &buf)
            FfiConverterString.write(`guid`, into: &buf)
            FfiConverterDouble.write(`score`, into: &buf)
            
        }
    }
}


public func FfiConverterTypeSuggestion_lift(_ buf: RustBuffer) throws -> Suggestion {
    return try FfiConverterTypeSuggestion.lift(buf)
}

public func FfiConverterTypeSuggestion_lower(_ value: Suggestion) -> RustBuffer {
    return FfiConverterTypeSuggestion.lower(value)
}


extension Suggestion: Equatable, Hashable {}



// Note that we don't yet support `indirect` for enums.
// See https://github.com/mozilla/uniffi-rs/issues/396 for further discussion.
public enum SuggestionProvider {
    
    case `amp`
    case `pocket`
    case `wikipedia`
    case `amo`
}

public struct FfiConverterTypeSuggestionProvider: FfiConverterRustBuffer {
    typealias SwiftType = SuggestionProvider

    public static func read(from buf: inout (data: Data, offset: Data.Index)) throws -> SuggestionProvider {
        let variant: Int32 = try readInt(&buf)
        switch variant {
        
        case 1: return .`amp`
        
        case 2: return .`pocket`
        
        case 3: return .`wikipedia`
        
        case 4: return .`amo`
        
        default: throw UniffiInternalError.unexpectedEnumCase
        }
    }

    public static func write(_ value: SuggestionProvider, into buf: inout [UInt8]) {
        switch value {
        
        
        case .`amp`:
            writeInt(&buf, Int32(1))
        
        
        case .`pocket`:
            writeInt(&buf, Int32(2))
        
        
        case .`wikipedia`:
            writeInt(&buf, Int32(3))
        
        
        case .`amo`:
            writeInt(&buf, Int32(4))
        
        }
    }
}


public func FfiConverterTypeSuggestionProvider_lift(_ buf: RustBuffer) throws -> SuggestionProvider {
    return try FfiConverterTypeSuggestionProvider.lift(buf)
}

public func FfiConverterTypeSuggestionProvider_lower(_ value: SuggestionProvider) -> RustBuffer {
    return FfiConverterTypeSuggestionProvider.lower(value)
}


extension SuggestionProvider: Equatable, Hashable {}



fileprivate struct FfiConverterOptionInt32: FfiConverterRustBuffer {
    typealias SwiftType = Int32?

    public static func write(_ value: SwiftType, into buf: inout [UInt8]) {
        guard let value = value else {
            writeInt(&buf, Int8(0))
            return
        }
        writeInt(&buf, Int8(1))
        FfiConverterInt32.write(value, into: &buf)
    }

    public static func read(from buf: inout (data: Data, offset: Data.Index)) throws -> SwiftType {
        switch try readInt(&buf) as Int8 {
        case 0: return nil
        case 1: return try FfiConverterInt32.read(from: &buf)
        default: throw UniffiInternalError.unexpectedOptionalTag
        }
    }
}

fileprivate struct FfiConverterOptionUInt64: FfiConverterRustBuffer {
    typealias SwiftType = UInt64?

    public static func write(_ value: SwiftType, into buf: inout [UInt8]) {
        guard let value = value else {
            writeInt(&buf, Int8(0))
            return
        }
        writeInt(&buf, Int8(1))
        FfiConverterUInt64.write(value, into: &buf)
    }

    public static func read(from buf: inout (data: Data, offset: Data.Index)) throws -> SwiftType {
        switch try readInt(&buf) as Int8 {
        case 0: return nil
        case 1: return try FfiConverterUInt64.read(from: &buf)
        default: throw UniffiInternalError.unexpectedOptionalTag
        }
    }
}

fileprivate struct FfiConverterOptionString: FfiConverterRustBuffer {
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

fileprivate struct FfiConverterOptionSequenceUInt8: FfiConverterRustBuffer {
    typealias SwiftType = [UInt8]?

    public static func write(_ value: SwiftType, into buf: inout [UInt8]) {
        guard let value = value else {
            writeInt(&buf, Int8(0))
            return
        }
        writeInt(&buf, Int8(1))
        FfiConverterSequenceUInt8.write(value, into: &buf)
    }

    public static func read(from buf: inout (data: Data, offset: Data.Index)) throws -> SwiftType {
        switch try readInt(&buf) as Int8 {
        case 0: return nil
        case 1: return try FfiConverterSequenceUInt8.read(from: &buf)
        default: throw UniffiInternalError.unexpectedOptionalTag
        }
    }
}

fileprivate struct FfiConverterOptionTypeRemoteSettingsConfig: FfiConverterRustBuffer {
    typealias SwiftType = RemoteSettingsConfig?

    public static func write(_ value: SwiftType, into buf: inout [UInt8]) {
        guard let value = value else {
            writeInt(&buf, Int8(0))
            return
        }
        writeInt(&buf, Int8(1))
        FfiConverterTypeRemoteSettingsConfig.write(value, into: &buf)
    }

    public static func read(from buf: inout (data: Data, offset: Data.Index)) throws -> SwiftType {
        switch try readInt(&buf) as Int8 {
        case 0: return nil
        case 1: return try FfiConverterTypeRemoteSettingsConfig.read(from: &buf)
        default: throw UniffiInternalError.unexpectedOptionalTag
        }
    }
}

fileprivate struct FfiConverterSequenceUInt8: FfiConverterRustBuffer {
    typealias SwiftType = [UInt8]

    public static func write(_ value: [UInt8], into buf: inout [UInt8]) {
        let len = Int32(value.count)
        writeInt(&buf, len)
        for item in value {
            FfiConverterUInt8.write(item, into: &buf)
        }
    }

    public static func read(from buf: inout (data: Data, offset: Data.Index)) throws -> [UInt8] {
        let len: Int32 = try readInt(&buf)
        var seq = [UInt8]()
        seq.reserveCapacity(Int(len))
        for _ in 0 ..< len {
            seq.append(try FfiConverterUInt8.read(from: &buf))
        }
        return seq
    }
}

fileprivate struct FfiConverterSequenceTypeSuggestion: FfiConverterRustBuffer {
    typealias SwiftType = [Suggestion]

    public static func write(_ value: [Suggestion], into buf: inout [UInt8]) {
        let len = Int32(value.count)
        writeInt(&buf, len)
        for item in value {
            FfiConverterTypeSuggestion.write(item, into: &buf)
        }
    }

    public static func read(from buf: inout (data: Data, offset: Data.Index)) throws -> [Suggestion] {
        let len: Int32 = try readInt(&buf)
        var seq = [Suggestion]()
        seq.reserveCapacity(Int(len))
        for _ in 0 ..< len {
            seq.append(try FfiConverterTypeSuggestion.read(from: &buf))
        }
        return seq
    }
}

fileprivate struct FfiConverterSequenceTypeSuggestionProvider: FfiConverterRustBuffer {
    typealias SwiftType = [SuggestionProvider]

    public static func write(_ value: [SuggestionProvider], into buf: inout [UInt8]) {
        let len = Int32(value.count)
        writeInt(&buf, len)
        for item in value {
            FfiConverterTypeSuggestionProvider.write(item, into: &buf)
        }
    }

    public static func read(from buf: inout (data: Data, offset: Data.Index)) throws -> [SuggestionProvider] {
        let len: Int32 = try readInt(&buf)
        var seq = [SuggestionProvider]()
        seq.reserveCapacity(Int(len))
        for _ in 0 ..< len {
            seq.append(try FfiConverterTypeSuggestionProvider.read(from: &buf))
        }
        return seq
    }
}



public func `rawSuggestionUrlMatches`(`rawUrl`: String, `url`: String)  -> Bool {
    return try!  FfiConverterBool.lift(
        try! rustCall() {
    uniffi_suggest_fn_func_raw_suggestion_url_matches(
        FfiConverterString.lower(`rawUrl`),
        FfiConverterString.lower(`url`),$0)
}
    )
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
    let scaffolding_contract_version = ffi_suggest_uniffi_contract_version()
    if bindings_contract_version != scaffolding_contract_version {
        return InitializationResult.contractVersionMismatch
    }
    if (uniffi_suggest_checksum_func_raw_suggestion_url_matches() != 44114) {
        return InitializationResult.apiChecksumMismatch
    }
    if (uniffi_suggest_checksum_method_suggeststore_query() != 27030) {
        return InitializationResult.apiChecksumMismatch
    }
    if (uniffi_suggest_checksum_method_suggeststore_interrupt() != 60992) {
        return InitializationResult.apiChecksumMismatch
    }
    if (uniffi_suggest_checksum_method_suggeststore_ingest() != 27338) {
        return InitializationResult.apiChecksumMismatch
    }
    if (uniffi_suggest_checksum_method_suggeststore_clear() != 42658) {
        return InitializationResult.apiChecksumMismatch
    }
    if (uniffi_suggest_checksum_constructor_suggeststore_new() != 2220) {
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