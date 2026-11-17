import Core
import Foundation

/// The single JSON object `claude -p --output-format json` prints. Unknown fields are ignored.
struct CLIResult: Decodable, Sendable, Hashable {
    /// Must be `result`.
    var type: String
    var subtype: String?
    /// Wins over everything else: true is an error even when `structuredOutput` is present.
    var isError: Bool
    var apiErrorStatus: Int?
    /// The reply as text.
    var result: String?
    /// The reply that matched `--json-schema`.
    var structuredOutput: JSONValue?
    var modelUsage: [String: ModelUsage]?

    struct ModelUsage: Decodable, Sendable, Hashable {
        var outputTokens: Int?
    }

    enum CodingKeys: String, CodingKey {
        case type, subtype, result, modelUsage
        case isError = "is_error"
        case apiErrorStatus = "api_error_status"
        case structuredOutput = "structured_output"
    }

    init(
        type: String = "result", subtype: String? = "success", isError: Bool = false, apiErrorStatus: Int? = nil,
        result: String? = nil, structuredOutput: JSONValue? = nil, modelUsage: [String: ModelUsage]? = nil
    ) {
        self.type = type
        self.subtype = subtype
        self.isError = isError
        self.apiErrorStatus = apiErrorStatus
        self.result = result
        self.structuredOutput = structuredOutput
        self.modelUsage = modelUsage
    }

    init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        type = try container.decode(String.self, forKey: .type)
        subtype = try container.decodeIfPresent(String.self, forKey: .subtype)
        isError = try container.decodeIfPresent(Bool.self, forKey: .isError) ?? false
        apiErrorStatus =
            Self.optional(Int.self, .apiErrorStatus, in: container)
            ?? Self.optional(String.self, .apiErrorStatus, in: container).flatMap { Int($0) }
        result = Self.optional(String.self, .result, in: container)
        structuredOutput = try container.decodeIfPresent(JSONValue.self, forKey: .structuredOutput)
        modelUsage = Self.optional([String: ModelUsage].self, .modelUsage, in: container)
    }

    /// Reads a field the call can do without. A value of another type becomes nil, but never silently:
    /// the field name goes to the log, so a CLI format change shows up.
    private static func optional<T: Decodable>(
        _ type: T.Type, _ key: CodingKeys, in container: KeyedDecodingContainer<CodingKeys>
    ) -> T? {
        do {
            return try container.decodeIfPresent(type, forKey: key)
        } catch {
            Log.bridge.warning("claude result field \(key.stringValue, privacy: .public) has an unexpected type")
            return nil
        }
    }

    enum DecodeFailure: Error, CustomStringConvertible {
        case notOneObject(String)
        case wrongType(String)

        var description: String {
            switch self {
            case .notOneObject(let detail): "stdout is not one JSON object: \(detail)"
            case .wrongType(let type): "stdout JSON has type \(type), not result"
            }
        }
    }

    /// Decodes stdout after trimming surrounding whitespace. Anything before or after the object fails.
    static func decode(stdout: Data) throws(DecodeFailure) -> CLIResult {
        let whitespace: Set<UInt8> = [0x20, 0x09, 0x0A, 0x0D]
        let trimmed = stdout.drop { whitespace.contains($0) }.reversed().drop { whitespace.contains($0) }.reversed()
        let data = Data(trimmed)
        guard data.first == UInt8(ascii: "{") else { throw .notOneObject("does not start with {") }
        let decoded: CLIResult
        do {
            decoded = try JSONDecoder().decode(CLIResult.self, from: data)
        } catch {
            throw .notOneObject(String(describing: error))
        }
        guard decoded.type == "result" else { throw .wrongType(decoded.type) }
        return decoded
    }

    /// The model with the most output tokens; ties go to the alphabetically first name; nil when none.
    var model: String? {
        guard let modelUsage, !modelUsage.isEmpty else { return nil }
        return modelUsage.min { lhs, rhs in
            let left = lhs.value.outputTokens ?? 0
            let right = rhs.value.outputTokens ?? 0
            return left != right ? left > right : lhs.key < rhs.key
        }?.key
    }

    /// AC-10: a 429, or error text that mentions a usage or rate limit.
    func isUsageLimit(exitStatus: Int32) -> Bool {
        if apiErrorStatus == 429 { return true }
        guard isError || exitStatus != 0, let text = result?.lowercased() else { return false }
        return text.contains("usage limit") || text.contains("rate limit")
    }

    /// The reply to save: the `result` text when not empty, else `structured_output` with sorted keys.
    var rawReply: String {
        if let result, !result.isEmpty { return result }
        guard let structuredOutput else { return "" }
        return structuredOutput.sortedJSONString
    }
}

/// Any JSON value, kept so `structured_output` can be decoded into a reply type or saved again.
enum JSONValue: Codable, Sendable, Hashable {
    case null
    case bool(Bool)
    case number(Double)
    case string(String)
    case array([JSONValue])
    case object([String: JSONValue])

    init(from decoder: any Decoder) throws {
        let container = try decoder.singleValueContainer()
        if container.decodeNil() {
            self = .null
        } else if let value = try? container.decode(Bool.self) {
            self = .bool(value)
        } else if let value = try? container.decode(Double.self) {
            self = .number(value)
        } else if let value = try? container.decode(String.self) {
            self = .string(value)
        } else if let value = try? container.decode([JSONValue].self) {
            self = .array(value)
        } else {
            self = .object(try container.decode([String: JSONValue].self))
        }
    }

    func encode(to encoder: any Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case .null: try container.encodeNil()
        case .bool(let value): try container.encode(value)
        case .number(let value): try container.encode(value)
        case .string(let value): try container.encode(value)
        case .array(let value): try container.encode(value)
        case .object(let value): try container.encode(value)
        }
    }

    /// Decodes this value into a reply type.
    func decode<T: Decodable>(_ type: T.Type) throws -> T {
        try JSONDecoder().decode(type, from: JSONEncoder().encode(self))
    }

    /// The value as compact JSON with sorted keys. Only a non finite number can fail to encode, and decoded
    /// JSON never holds one; if it ever does, the failure is logged and the text is empty.
    var sortedJSONString: String {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys, .withoutEscapingSlashes]
        do {
            // JSONEncoder always writes UTF-8, so the conversion cannot fail.
            return String(bytes: try encoder.encode(self), encoding: .utf8) ?? ""
        } catch {
            Log.bridge.error(
                "structured_output could not be encoded again: \(String(describing: error), privacy: .private)")
            return ""
        }
    }
}
