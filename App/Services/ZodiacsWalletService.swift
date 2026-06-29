import Foundation

nonisolated enum ZodiacsWalletServiceError: LocalizedError {
    case unsupportedAddress
    case registryUnavailable
    case rpcUnavailable

    var errorDescription: String? {
        switch self {
        case .unsupportedAddress:
            return "Unsupported wallet address."
        case .registryUnavailable:
            return "The official Zodiacs registry could not be loaded."
        case .rpcUnavailable:
            return "The wallet balance lookup is unavailable right now."
        }
    }
}

actor ZodiacsWalletService {
    static let shared = ZodiacsWalletService()

    private let registryURL = URL(string: "https://raw.githubusercontent.com/ZodiacsOfficial/sdk/main/packages/sdk/registry/zodiacs.registry.json")!
    private let solanaRPCURL = URL(string: "https://api.mainnet-beta.solana.com")!
    private let baseRPCURL = URL(string: "https://mainnet.base.org")!
    private var cachedRegistry: ZodiacsRegistry?

    func fetchHoldings(for address: String) async throws -> AuraWalletHoldings {
        let trimmed = address.trimmingCharacters(in: .whitespacesAndNewlines)
        guard AuraWalletHoldings.isSupportedPublicWalletAddress(trimmed) else {
            throw ZodiacsWalletServiceError.unsupportedAddress
        }

        let registry = try await loadRegistry()
        let counts: [ZodiacSign: Int]
        if trimmed.hasPrefix("0x") {
            counts = try await fetchBaseHoldings(ownerAddress: trimmed, registry: registry)
        } else {
            counts = try await fetchSolanaHoldings(ownerAddress: trimmed, registry: registry)
        }

        return AuraWalletHoldings(publicAddress: trimmed, zodiacCounts: counts)
    }

    private func loadRegistry() async throws -> ZodiacsRegistry {
        if let cachedRegistry {
            return cachedRegistry
        }

        var request = URLRequest(url: registryURL)
        request.timeoutInterval = 12
        let data: Data
        do {
            let response: URLResponse
            (data, response) = try await URLSession.shared.data(for: request)
            guard (response as? HTTPURLResponse)?.statusCode == 200 else {
                throw ZodiacsWalletServiceError.registryUnavailable
            }
        } catch {
            throw ZodiacsWalletServiceError.registryUnavailable
        }

        do {
            let registry = try JSONDecoder().decode(ZodiacsRegistry.self, from: data)
            cachedRegistry = registry
            return registry
        } catch {
            throw ZodiacsWalletServiceError.registryUnavailable
        }
    }

    private func fetchSolanaHoldings(ownerAddress: String, registry: ZodiacsRegistry) async throws -> [ZodiacSign: Int] {
        let officialMints = registry.solanaRepresentations.reduce(into: [String: ZodiacsTokenRepresentation]()) { partial, token in
            partial[token.address] = token
        }

        let payload: [String: Any] = [
            "jsonrpc": "2.0",
            "id": 1,
            "method": "getTokenAccountsByOwner",
            "params": [
                ownerAddress,
                ["programId": "TokenkegQfeZyiNwAJbNbGKPFXCWuBvf9Ss623VQ5DA"],
                ["encoding": "jsonParsed"],
            ],
        ]

        let data = try await postJSON(payload, to: solanaRPCURL)
        let response: SolanaTokenAccountsResponse
        do {
            response = try JSONDecoder().decode(SolanaTokenAccountsResponse.self, from: data)
        } catch {
            throw ZodiacsWalletServiceError.rpcUnavailable
        }

        return response.result.value.reduce(into: [ZodiacSign: Int]()) { partial, account in
            guard let representation = officialMints[account.account.data.parsed.info.mint] else { return }
            let amount = account.account.data.parsed.info.tokenAmount.displayAmount
            let count = Self.auraCount(from: amount)
            if count > 0 {
                partial[representation.sign, default: 0] += count
            }
        }
    }

    private func fetchBaseHoldings(ownerAddress: String, registry: ZodiacsRegistry) async throws -> [ZodiacSign: Int] {
        let tokens = registry.baseRepresentations
        guard !tokens.isEmpty else {
            throw ZodiacsWalletServiceError.registryUnavailable
        }

        let paddedOwner = String(ownerAddress.dropFirst(2)).lowercased().leftPadded(toLength: 64, with: "0")
        let batchPayload = tokens.enumerated().map { index, token -> [String: Any] in
            [
                "jsonrpc": "2.0",
                "id": "\(index)",
                "method": "eth_call",
                "params": [
                    [
                        "to": token.address,
                        "data": "0x70a08231\(paddedOwner)",
                    ],
                    "latest",
                ],
            ]
        }

        let data = try await postJSON(batchPayload, to: baseRPCURL)
        let responses: [EthereumCallResponse]
        do {
            responses = try JSONDecoder().decode([EthereumCallResponse].self, from: data)
        } catch {
            throw ZodiacsWalletServiceError.rpcUnavailable
        }

        let responsesById = Dictionary(uniqueKeysWithValues: responses.compactMap { response -> (String, EthereumCallResponse)? in
            guard let id = response.id else { return nil }
            return (id, response)
        })

        return tokens.enumerated().reduce(into: [ZodiacSign: Int]()) { partial, pair in
            let (index, token) = pair
            guard let result = responsesById["\(index)"]?.result else { return }
            let minorUnits = Self.doubleFromHexQuantity(result)
            let amount = minorUnits / pow(10, Double(token.decimals))
            let count = Self.auraCount(from: amount)
            if count > 0 {
                partial[token.sign, default: 0] += count
            }
        }
    }

    private func postJSON(_ payload: Any, to url: URL) async throws -> Data {
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.timeoutInterval = 14
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONSerialization.data(withJSONObject: payload, options: [])

        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            guard (response as? HTTPURLResponse)?.statusCode == 200 else {
                throw ZodiacsWalletServiceError.rpcUnavailable
            }
            return data
        } catch {
            throw ZodiacsWalletServiceError.rpcUnavailable
        }
    }

    private static func auraCount(from amount: Double) -> Int {
        guard amount > 0 else { return 0 }
        return max(1, Int(amount.rounded(.down)))
    }

    private static func doubleFromHexQuantity(_ hexQuantity: String) -> Double {
        let hex = hexQuantity
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "0x", with: "")

        return hex.reduce(0) { partial, character in
            guard let value = character.hexDigitValue else { return partial }
            return partial * 16 + Double(value)
        }
    }
}

private struct ZodiacsRegistry: Decodable {
    let assets: [ZodiacsAsset]

    var solanaRepresentations: [ZodiacsTokenRepresentation] {
        officialRepresentations(for: "solana")
    }

    var baseRepresentations: [ZodiacsTokenRepresentation] {
        officialRepresentations(for: "base")
    }

    private func officialRepresentations(for chain: String) -> [ZodiacsTokenRepresentation] {
        assets.flatMap { asset in
            asset.representations.compactMap { representation in
                guard representation.chain == chain,
                      representation.isOfficialRepresentation,
                      let sign = ZodiacSign(rawValue: representation.sign.lowercased()) else {
                    return nil
                }
                return ZodiacsTokenRepresentation(
                    sign: sign,
                    address: representation.address,
                    decimals: representation.decimals
                )
            }
        }
    }
}

private struct ZodiacsAsset: Decodable {
    let representations: [ZodiacsRegistryRepresentation]
}

private struct ZodiacsRegistryRepresentation: Decodable {
    let sign: String
    let chain: String
    let address: String
    let decimals: Int
    let isOfficialRepresentation: Bool
}

private struct ZodiacsTokenRepresentation {
    let sign: ZodiacSign
    let address: String
    let decimals: Int
}

private struct SolanaTokenAccountsResponse: Decodable {
    let result: ResultValue

    struct ResultValue: Decodable {
        let value: [TokenAccount]
    }

    struct TokenAccount: Decodable {
        let account: Account
    }

    struct Account: Decodable {
        let data: AccountData
    }

    struct AccountData: Decodable {
        let parsed: ParsedData
    }

    struct ParsedData: Decodable {
        let info: TokenInfo
    }

    struct TokenInfo: Decodable {
        let mint: String
        let tokenAmount: TokenAmount
    }

    struct TokenAmount: Decodable {
        let amount: String
        let decimals: Int
        let uiAmount: Double?
        let uiAmountString: String?

        var displayAmount: Double {
            if let uiAmount {
                return uiAmount
            }
            if let uiAmountString, let parsed = Double(uiAmountString) {
                return parsed
            }
            guard let raw = Double(amount) else { return 0 }
            return raw / pow(10, Double(decimals))
        }
    }
}

private struct EthereumCallResponse: Decodable {
    let id: String?
    let result: String?
}

private extension String {
    func leftPadded(toLength length: Int, with character: Character) -> String {
        guard count < length else { return self }
        return String(repeating: String(character), count: length - count) + self
    }
}
