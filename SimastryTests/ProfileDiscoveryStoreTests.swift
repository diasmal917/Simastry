import Foundation
import Testing
@testable import Simastry

@MainActor
struct ProfileDiscoveryStoreTests {
    @Test func searchFiltersCurrentPrivateAndBlockedProfiles() async throws {
        let currentUserId = UUID()
        let visible = makeProfile(username: "maya", name: "Maya")
        let privateProfile = makeProfile(username: "nova", name: "Nova", isDiscoverable: false)
        let blocked = makeProfile(username: "luna", name: "Luna")
        let currentUserProfile = makeProfile(id: currentUserId, username: "me", name: "Me")
        let service = MockProfileDiscoveryService(
            searchProfiles: [visible, privateProfile, blocked, currentUserProfile],
            blocks: [DiscoveryBlockData(blockerId: currentUserId, blockedId: blocked.id)]
        )
        let store = ProfileDiscoveryStore(service: service)

        try await store.search(query: "m", currentUserId: currentUserId)

        #expect(store.searchState == .loaded)
        #expect(store.discoveredProfiles == [visible])
    }

    @Test func addAndRemoveConnectionUpdatesConnectedProfiles() async throws {
        let profile = makeProfile(username: "maya", name: "Maya")
        let service = MockProfileDiscoveryService()
        let store = ProfileDiscoveryStore(service: service)

        try await store.addConnection(profile)
        #expect(store.connectedProfiles == [profile])
        #expect(service.addedProfileIds == [profile.id])

        try await store.removeConnection(profile)
        #expect(store.connectedProfiles.isEmpty)
        #expect(service.removedProfileIds == [profile.id])
    }

    @Test func uploadAvatarDelegatesAndReportsUploadState() async throws {
        let service = MockProfileDiscoveryService(uploadURL: "https://cdn.simastry.test/avatar.jpg")
        let store = ProfileDiscoveryStore(service: service)

        let url = try await store.uploadAvatar(data: Data([1, 2, 3]), fileExtension: "jpg", contentType: "image/jpeg")

        #expect(url == "https://cdn.simastry.test/avatar.jpg")
        #expect(service.uploadedAvatarBytes == Data([1, 2, 3]))
        #expect(!store.isUploadingAvatar)
    }

    @Test func todayStorePersistsNewestSavedPrompt() throws {
        let suiteName = "TodayStoreTests.\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suiteName))
        defaults.removePersistentDomain(forName: suiteName)
        defer { defaults.removePersistentDomain(forName: suiteName) }

        let store = TodayStore(promptStore: DailyPromptStore(defaults: defaults))
        let prompt = SavedDailyPrompt(text: "Ask Nadia what timing wants.", guideId: "nadia")

        store.savePrompt(prompt)

        #expect(store.savedDailyPrompts.map(\.text) == ["Ask Nadia what timing wants."])
        store.clearSavedPrompts()
        #expect(store.savedDailyPrompts.isEmpty)
    }

    @Test func avatarStoragePathUsesUserFolderAndSanitizedExtension() {
        let userId = UUID(uuidString: "11111111-2222-3333-4444-555555555555")!

        #expect(SupabaseService.avatarStoragePath(userId: userId, fileExtension: ".JPG") == "11111111-2222-3333-4444-555555555555/profile.jpg")
        #expect(SupabaseService.avatarStoragePath(userId: userId, fileExtension: "") == "11111111-2222-3333-4444-555555555555/profile.jpg")
    }
}

private func makeProfile(
    id: UUID = UUID(),
    username: String,
    name: String,
    isDiscoverable: Bool = true
) -> PublicProfile {
    PublicProfile(
        id: id,
        username: username,
        displayName: name,
        sunSign: "sagittarius",
        communicationHint: "Start warm.",
        iceBreakers: ["What feels easy today?"],
        isDiscoverable: isDiscoverable,
        createdAt: Date(timeIntervalSince1970: 0)
    )
}

private final class MockProfileDiscoveryService: ProfileDiscoveryServicing, @unchecked Sendable {
    var searchProfiles: [PublicProfile]
    var connectedProfiles: [PublicProfile]
    var blocks: [DiscoveryBlockData]
    var addedProfileIds: [UUID] = []
    var removedProfileIds: [UUID] = []
    var uploadedAvatarBytes: Data?
    var uploadURL: String

    init(
        searchProfiles: [PublicProfile] = [],
        connectedProfiles: [PublicProfile] = [],
        blocks: [DiscoveryBlockData] = [],
        uploadURL: String = "https://cdn.simastry.test/profile.jpg"
    ) {
        self.searchProfiles = searchProfiles
        self.connectedProfiles = connectedProfiles
        self.blocks = blocks
        self.uploadURL = uploadURL
    }

    func searchPublicProfiles(query: String) async throws -> [PublicProfile] {
        searchProfiles
    }

    func fetchConnectedProfiles() async throws -> [PublicProfile] {
        connectedProfiles
    }

    func fetchDiscoveryBlocks() async throws -> [DiscoveryBlockData] {
        blocks
    }

    func upsertSocialProfile(_ profile: SocialProfile) async throws {}

    func addUserConnection(profileId: UUID) async throws {
        addedProfileIds.append(profileId)
    }

    func removeUserConnection(profileId: UUID) async throws {
        removedProfileIds.append(profileId)
    }

    func uploadAvatar(data: Data, fileExtension: String, contentType: String) async throws -> String {
        uploadedAvatarBytes = data
        return uploadURL
    }
}
