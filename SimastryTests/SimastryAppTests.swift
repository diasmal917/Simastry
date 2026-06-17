import Testing
@testable import Simastry

struct SimastryAppTests {
    @Test func emailAuthModesUseDistinctActions() {
        #expect(EmailAuthMode.signIn.buttonTitle != EmailAuthMode.createAccount.buttonTitle)
    }
}
