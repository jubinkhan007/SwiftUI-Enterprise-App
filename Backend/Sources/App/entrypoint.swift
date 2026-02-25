import Vapor

@main
enum Entrypoint {
    static func main() async throws {
        DotEnv.loadIfPresent()
        var env = try Environment.detect()
        try LoggingSystem.bootstrap(from: &env)

        let app = Application(env)
        defer { app.shutdown() }

        try configure(app)
        try await app.execute()
    }
}
