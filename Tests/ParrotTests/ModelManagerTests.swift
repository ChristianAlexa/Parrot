@testable import Parrot
import XCTest

final class ModelManagerTests: XCTestCase {

    private let manager = ModelManager()

    func testModelDisplayNameStripsExtensionAndFormatsSeparators() {
        let url = URL(fileURLWithPath: "/models/ggml-large-v3-turbo.bin")
        XCTAssertEqual(manager.modelDisplayName(url), "ggml large v3 turbo")
    }

    func testModelDisplayNameHandlesUnderscores() {
        let url = URL(fileURLWithPath: "/models/Llama-3.1-8B-Instruct-Q8_0.gguf")
        XCTAssertEqual(manager.modelDisplayName(url), "Llama 3.1 8B Instruct Q8 0")
    }

    func testModelDisplayNameHandlesSimpleName() {
        let url = URL(fileURLWithPath: "/models/base.bin")
        XCTAssertEqual(manager.modelDisplayName(url), "base")
    }

    func testModelsDirectoryIsInAppSupport() {
        let path = ModelManager.modelsDirectory.path
        XCTAssertTrue(path.contains("Application Support"))
        XCTAssertTrue(path.contains("Parrot/Models"))
    }
}
