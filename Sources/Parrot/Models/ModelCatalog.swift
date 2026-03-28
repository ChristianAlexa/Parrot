import Foundation

struct RecommendedModel: Identifiable {
    let id: String
    let displayName: String
    let fileName: String
    let downloadURL: URL
    let expectedSizeBytes: Int64
    let description: String
    let category: ModelCategory
    let minRAMGB: Int

    enum ModelCategory {
        case whisper
        case llm
    }

    var expectedSizeDescription: String {
        let gb = Double(expectedSizeBytes) / 1_073_741_824
        if gb < 0.1 {
            return String(format: "%.0f MB", Double(expectedSizeBytes) / 1_048_576)
        }
        return String(format: "%.1f GB", gb)
    }
}

enum ModelCatalog {
    static let whisperModels: [RecommendedModel] = [
        RecommendedModel(
            id: "whisper-large-v3-turbo",
            displayName: "Large V3 Turbo",
            fileName: "ggml-large-v3-turbo.bin",
            downloadURL: URL(string: "https://huggingface.co/ggerganov/whisper.cpp/resolve/main/ggml-large-v3-turbo.bin")!,
            expectedSizeBytes: 1_624_457_216,
            description: "Best balance of speed and accuracy. Recommended.",
            category: .whisper,
            minRAMGB: 8
        ),
        RecommendedModel(
            id: "whisper-base-en",
            displayName: "Base (English)",
            fileName: "ggml-base.en.bin",
            downloadURL: URL(string: "https://huggingface.co/ggerganov/whisper.cpp/resolve/main/ggml-base.en.bin")!,
            expectedSizeBytes: 148_897_792,
            description: "Lightweight, English-only. For constrained setups.",
            category: .whisper,
            minRAMGB: 4
        ),
    ]

    static let llmModels: [RecommendedModel] = [
        RecommendedModel(
            id: "llama-3.1-70b-q4km",
            displayName: "Llama 3.1 70B (Q4_K_M)",
            fileName: "Llama-3.1-70B-Instruct-Q4_K_M.gguf",
            downloadURL: URL(string: "https://huggingface.co/bartowski/Meta-Llama-3.1-70B-Instruct-GGUF/resolve/main/Meta-Llama-3.1-70B-Instruct-Q4_K_M.gguf")!,
            expectedSizeBytes: 42_530_000_000,
            description: "Best cleanup quality. Requires 128 GB+ RAM.",
            category: .llm,
            minRAMGB: 128
        ),
        RecommendedModel(
            id: "llama-3.1-8b-q8",
            displayName: "Llama 3.1 8B (Q8_0)",
            fileName: "Llama-3.1-8B-Instruct-Q8_0.gguf",
            downloadURL: URL(string: "https://huggingface.co/bartowski/Meta-Llama-3.1-8B-Instruct-GGUF/resolve/main/Meta-Llama-3.1-8B-Instruct-Q8_0.gguf")!,
            expectedSizeBytes: 8_540_000_000,
            description: "Good for 16-32 GB Macs. Handles most cleanup well.",
            category: .llm,
            minRAMGB: 16
        ),
    ]

    static var systemRAMGB: Int {
        Int(ProcessInfo.processInfo.physicalMemory / 1_073_741_824)
    }

    /// Returns the best LLM model for this system's RAM, or the smallest if none fit well.
    static func bestLLMForSystem() -> RecommendedModel? {
        llmModels.first { $0.minRAMGB <= systemRAMGB } ?? llmModels.last
    }
}
