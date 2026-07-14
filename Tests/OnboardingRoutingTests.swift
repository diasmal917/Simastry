import XCTest
@testable import Simastry

@MainActor
final class OnboardingRoutingTests: XCTestCase {
    func testAgeGatePreservesGuestCompassIntent() {
        let viewModel = AppViewModel()
        viewModel.firstReadOnboardingIntent = .predict

        viewModel.completeAgeVerification()

        guard case .firstPrediction = viewModel.currentScreen else {
            return XCTFail("Guest Compass should continue to the local first reading")
        }
    }

    func testAgeGatePreservesExplicitChartFirstIntent() {
        let viewModel = AppViewModel()
        viewModel.firstReadOnboardingIntent = .astrologer

        viewModel.completeAgeVerification()

        guard case .birthDetails = viewModel.currentScreen else {
            return XCTFail("Chart-first should continue to birth details")
        }
    }

    func testAgeGatePreservesDecodeIntentIntoGuestCompass() {
        let viewModel = AppViewModel()
        viewModel.firstReadOnboardingIntent = .decode

        viewModel.completeAgeVerification()

        guard case .firstPrediction = viewModel.currentScreen else {
            return XCTFail("Decode should land on the guest Compass first read")
        }
    }
}
