import Foundation

nonisolated enum AuraWalletLookupStatus: String, Codable, Sendable {
    case idle
    case checking
    case found
    case notFound
    case unavailable
    case manualCountsActive
}

nonisolated struct AuraWalletHoldings: Codable, Equatable, Sendable {
    let publicAddress: String
    let zodiacCountsByRawValue: [String: Int]

    init(publicAddress: String = "", zodiacCounts: [ZodiacSign: Int]) {
        self.publicAddress = publicAddress.trimmingCharacters(in: .whitespacesAndNewlines)
        self.zodiacCountsByRawValue = zodiacCounts.reduce(into: [:]) { partial, pair in
            if pair.value > 0 {
                partial[pair.key.rawValue] = pair.value
            }
        }
    }

    var zodiacCounts: [ZodiacSign: Int] {
        zodiacCountsByRawValue.reduce(into: [:]) { partial, pair in
            guard let sign = ZodiacSign(rawValue: pair.key), pair.value > 0 else { return }
            partial[sign] = pair.value
        }
    }

    var totalZodiacs: Int {
        zodiacCounts.values.reduce(0, +)
    }

    var hasZodiacCounts: Bool {
        totalZodiacs > 0
    }

    var hasPublicAddress: Bool {
        !publicAddress.isEmpty
    }

    var displayLabel: String {
        if hasPublicAddress {
            return Self.shortAddress(publicAddress)
        }
        return hasZodiacCounts ? "Manual Zodiac holdings" : ""
    }

    var summaryLine: String {
        guard hasZodiacCounts else {
            return hasPublicAddress ? "Address saved. Paste Zodiac counts when available." : ""
        }

        let topSigns = zodiacCounts
            .sorted {
                if $0.value == $1.value {
                    return $0.key.displayName < $1.key.displayName
                }
                return $0.value > $1.value
            }
            .prefix(3)
            .map { "\($0.key.displayName) x\($0.value)" }
            .joined(separator: ", ")

        return "\(totalZodiacs) Zodiacs detected\(topSigns.isEmpty ? "" : ": \(topSigns)")"
    }

    static func parse(from input: String) -> AuraWalletHoldings? {
        let trimmed = input.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }

        let address = firstSupportedPublicAddress(in: trimmed) ?? ""
        let counts = zodiacCounts(in: trimmed)
        guard !address.isEmpty || counts.values.reduce(0, +) > 0 else { return nil }
        return AuraWalletHoldings(publicAddress: address, zodiacCounts: counts)
    }

    static func canParse(_ input: String) -> Bool {
        parse(from: input) != nil
    }

    static func isSupportedPublicWalletAddress(_ address: String) -> Bool {
        let trimmed = address.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return false }

        let hexCharacters = CharacterSet(charactersIn: "0123456789abcdefABCDEF")
        if trimmed.hasPrefix("0x"), trimmed.count == 42 {
            let hexPart = String(trimmed.dropFirst(2))
            return hexPart.unicodeScalars.allSatisfy { hexCharacters.contains($0) }
        }

        let base58Characters = CharacterSet(charactersIn: "123456789ABCDEFGHJKLMNPQRSTUVWXYZabcdefghijkmnopqrstuvwxyz")
        return (32...60).contains(trimmed.count)
            && trimmed.unicodeScalars.allSatisfy { base58Characters.contains($0) }
    }

    static func shortAddress(_ address: String) -> String {
        let trimmed = address.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.count > 12 else { return trimmed }
        return "\(trimmed.prefix(6))...\(trimmed.suffix(4))"
    }

    private static func firstSupportedPublicAddress(in text: String) -> String? {
        let separators = CharacterSet.whitespacesAndNewlines
            .union(CharacterSet(charactersIn: "<>[]{}(),;\"'/:=|"))
        let edgePunctuation = CharacterSet(charactersIn: ".!?")

        return text
            .components(separatedBy: separators)
            .map { $0.trimmingCharacters(in: edgePunctuation) }
            .first(where: isSupportedPublicWalletAddress)
    }

    private static func zodiacCounts(in text: String) -> [ZodiacSign: Int] {
        ZodiacSign.allCases.reduce(into: [:]) { partial, sign in
            let explicitTotal = explicitCount(for: sign, in: text)
            if explicitTotal > 0 {
                partial[sign] = explicitTotal
            }
        }
    }

    private static func explicitCount(for sign: ZodiacSign, in text: String) -> Int {
        let signPattern = NSRegularExpression.escapedPattern(for: sign.displayName)
        let afterSign = #"\b\#(signPattern)\b\s*(?:x|×|:|=|-|qty\.?|quantity|count)\s*(\d{1,4})\b"#
        let beforeSign = #"\b(\d{1,4})\s*(?:x|×)?\s*\b\#(signPattern)\b"#
        return integerMatches(pattern: afterSign, in: text, captureGroup: 1).reduce(0, +)
            + integerMatches(pattern: beforeSign, in: text, captureGroup: 1).reduce(0, +)
    }

    private static func integerMatches(pattern: String, in text: String, captureGroup: Int) -> [Int] {
        guard let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]) else {
            return []
        }
        let range = NSRange(text.startIndex..<text.endIndex, in: text)
        let nsText = text as NSString
        return regex.matches(in: text, options: [], range: range).compactMap { match in
            guard match.numberOfRanges > captureGroup else { return nil }
            let numberRange = match.range(at: captureGroup)
            guard numberRange.location != NSNotFound else { return nil }
            return Int(nsText.substring(with: numberRange))
        }
    }
}
