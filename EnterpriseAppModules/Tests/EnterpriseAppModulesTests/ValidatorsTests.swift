import Domain
import Testing

@Test func validators_email() async throws {
    #expect(Validators.isValidEmail("name@company.com"))
    #expect(!Validators.isValidEmail("not-an-email"))
}

@Test func validators_password() async throws {
    #expect(Validators.isValidPassword("12345678"))
    #expect(!Validators.isValidPassword("1234567"))
}

