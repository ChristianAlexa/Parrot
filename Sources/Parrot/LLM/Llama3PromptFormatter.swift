import Foundation

protocol PromptFormatter {
    func format(systemMessage: String, userMessage: String) -> String
}

struct Llama3PromptFormatter: PromptFormatter {
    func format(systemMessage: String, userMessage: String) -> String {
        """
        <|begin_of_text|><|start_header_id|>system<|end_header_id|>

        \(systemMessage)<|eot_id|><|start_header_id|>user<|end_header_id|>

        \(userMessage)<|eot_id|><|start_header_id|>assistant<|end_header_id|>

        """
    }
}
