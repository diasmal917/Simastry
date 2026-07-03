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

    func fetchHoldings(for address: String, service: SupabaseService) async throws -> AuraWalletHoldings {
        try await service.fetchZodiacsWalletHoldings(for: address)
    }
}
