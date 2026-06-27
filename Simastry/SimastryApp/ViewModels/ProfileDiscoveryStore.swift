import Foundation

nonisolated enum ProfileDiscoveryLoadState: Equatable, Sendable {
    case idle
    case loading
    case loaded
    case failed(String)
}

protocol ProfileDiscoveryServicing {
    func searchPublicProfiles(query: String) async throws -> [PublicProfile]
    func fetchConnectedProfiles() async throws -> [PublicProfile]
    func fetchDiscoveryBlocks() async throws -> [DiscoveryBlockData]
    func upsertSocialProfile(_ profile: SocialProfile) async throws
    func addUserConnection(profileId: UUID) async throws
    func removeUserConnection(profileId: UUID) async throws
    func uploadAvatar(data: Data, fileExtension: String, contentType: String) async throws -> String
}

extension SupabaseService: ProfileDiscoveryServicing {}

@MainActor
@Observable
final class ProfileDiscoveryStore {
    var discoveredProfiles: [SocialProfile] = []
    var connectedProfiles: [SocialProfile] = []
    var searchState: ProfileDiscoveryLoadState = .idle
    var connectionState: ProfileDiscoveryLoadState = .idle
    var isSavingProfile: Bool = false
    var isUploadingAvatar: Bool = false

    private let service: any ProfileDiscoveryServicing

    init(service: any ProfileDiscoveryServicing) {
        self.service = service
    }

    func search(query: String, currentUserId: UUID?) async throws {
        searchState = .loading
        do {
            async let profileResults = service.searchPublicProfiles(query: query)
            async let connectionResults = service.fetchConnectedProfiles()
            async let blockResults = service.fetchDiscoveryBlocks()

            let profiles = try await profileResults
            connectedProfiles = try await connectionResults
            let blocks = try await blockResults
            let blockedProfileIds = blockedProfileIds(from: blocks, currentUserId: currentUserId)

            discoveredProfiles = profiles
                .filter { profile in
                    profile.isDiscoverable &&
                    profile.id != currentUserId &&
                    !blockedProfileIds.contains(profile.id)
                }
            searchState = .loaded
        } catch {
            discoveredProfiles = []
            searchState = .failed("Check your connection or try again later.")
            throw error
        }
    }

    func refreshConnections() async throws {
        connectionState = .loading
        do {
            connectedProfiles = try await service.fetchConnectedProfiles()
            connectionState = .loaded
        } catch {
            connectedProfiles = []
            connectionState = .failed("Try again in a moment.")
            throw error
        }
    }

    func saveProfile(_ profile: SocialProfile) async throws {
        isSavingProfile = true
        defer { isSavingProfile = false }
        try await service.upsertSocialProfile(profile)
    }

    func addConnection(_ profile: SocialProfile) async throws {
        try await service.addUserConnection(profileId: profile.id)
        if !connectedProfiles.contains(where: { $0.id == profile.id }) {
            connectedProfiles.append(profile)
        }
    }

    func removeConnection(_ profile: SocialProfile) async throws {
        try await service.removeUserConnection(profileId: profile.id)
        connectedProfiles.removeAll { $0.id == profile.id }
    }

    func uploadAvatar(data: Data, fileExtension: String = "jpg", contentType: String = "image/jpeg") async throws -> String {
        isUploadingAvatar = true
        defer { isUploadingAvatar = false }
        return try await service.uploadAvatar(data: data, fileExtension: fileExtension, contentType: contentType)
    }

    func publicProfile(for id: UUID) -> SocialProfile? {
        connectedProfiles.first { $0.id == id } ?? discoveredProfiles.first { $0.id == id }
    }

    private func blockedProfileIds(from blocks: [DiscoveryBlockData], currentUserId: UUID?) -> Set<UUID> {
        Set(blocks.compactMap { block -> UUID? in
            guard let currentUserId else { return nil }
            if block.blockerId == currentUserId { return block.blockedId }
            if block.blockedId == currentUserId { return block.blockerId }
            return nil
        })
    }
}
