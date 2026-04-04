@testable import Parrot
import XCTest

final class ModelCatalogTests: XCTestCase {

    func testExpectedSizeDescriptionFormatsGB() {
        let model = RecommendedModel(
            id: "test", displayName: "Test", fileName: "test.gguf",
            downloadURL: URL(string: "https://example.com")!,
            expectedSizeBytes: 1_624_457_216,
            description: "Test model", category: .llm, minRAMGB: 8
        )
        XCTAssertEqual(model.expectedSizeDescription, "1.5 GB")
    }

    func testExpectedSizeDescriptionFormatsMB() {
        let model = RecommendedModel(
            id: "test", displayName: "Test", fileName: "test.bin",
            downloadURL: URL(string: "https://example.com")!,
            expectedSizeBytes: 50_000_000,
            description: "Tiny model", category: .whisper, minRAMGB: 4
        )
        XCTAssertEqual(model.expectedSizeDescription, "48 MB")
    }

    func testWhisperModelsAreNotEmpty() {
        XCTAssertFalse(ModelCatalog.whisperModels.isEmpty)
    }

    func testLLMModelsAreNotEmpty() {
        XCTAssertFalse(ModelCatalog.llmModels.isEmpty)
    }

    func testAllModelsHaveRequiredFields() {
        let all = ModelCatalog.whisperModels + ModelCatalog.llmModels
        for model in all {
            XCTAssertFalse(model.displayName.isEmpty, "\(model.id) missing displayName")
            XCTAssertFalse(model.fileName.isEmpty, "\(model.id) missing fileName")
            XCTAssertFalse(model.description.isEmpty, "\(model.id) missing description")
            XCTAssertGreaterThan(model.expectedSizeBytes, 0, "\(model.id) has zero size")
            XCTAssertGreaterThan(model.minRAMGB, 0, "\(model.id) has zero minRAM")
        }
    }

    func testBestLLMForSystemReturnsModel() {
        XCTAssertNotNil(ModelCatalog.bestLLMForSystem())
    }

    func testSystemRAMIsPositive() {
        XCTAssertGreaterThan(ModelCatalog.systemRAMGB, 0)
    }
}
