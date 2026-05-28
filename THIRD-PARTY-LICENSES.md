# Third-Party Licenses

Parrot is licensed under the [Apache License 2.0](LICENSE). It bundles and
depends on the third-party components listed below. Each is the property of its
respective authors and is used under the stated license.

> **Model weights are not redistributed with Parrot.** They are downloaded by
> the user from their original sources at runtime and remain governed by their
> own licenses. The most important consequence: **Llama-family weights are not
> "open source"** — they carry Meta's community license with usage restrictions.
> See [Model Weights](#model-weights) below.

---

## Bundled binary frameworks

These are linked into the app via Swift Package Manager `binaryTarget`s
(`Package.swift`).

### whisper.cpp

- **Version:** v1.8.4 (xcframework)
- **Source:** https://github.com/ggml-org/whisper.cpp
- **License:** MIT
- **Use:** On-device speech-to-text inference.

### llama.cpp

- **Version:** b8559 (xcframework)
- **Source:** https://github.com/ggml-org/llama.cpp
- **License:** MIT
- **Use:** On-device large-language-model inference for text cleanup.

### ggml

- **Source:** https://github.com/ggml-org/ggml
- **License:** MIT
- **Use:** Tensor / inference library that underlies both whisper.cpp and
  llama.cpp (vendored within those projects).

---

## Model Weights

Parrot does **not** ship model weights. Users download them and place them in
`~/Library/Application Support/Parrot/Models/`. Each model is subject to its own
license, independent of Parrot's Apache-2.0 license.

### Speech-to-Text (Whisper)

- **Model:** OpenAI Whisper (GGML/GGUF conversions, typically distributed by
  ggml-org / Hugging Face)
- **License:** MIT
- **Source:** https://github.com/openai/whisper ·
  https://huggingface.co/ggerganov/whisper.cpp
- **Notes:** Permissive. No redistribution restrictions on the weights.

### Text cleanup (LLM)

Parrot's in-app catalog recommends **Meta Llama 3.1 Instruct** models:

- **Llama 3.1 8B Instruct** (Q8_0 GGUF) — for 16–32 GB Macs
- **Llama 3.1 70B Instruct** (Q4_K_M GGUF) — for 128 GB+ Macs

- **License:** **Meta Llama 3.1 Community License Agreement** — *not* MIT or
  Apache. These weights are **not open source**.
- **License terms:** https://www.llama.com/llama3_1/license/
- **Acceptable Use Policy:** https://www.llama.com/llama3_1/use-policy/
- **Source (GGUF conversions):**
  https://huggingface.co/bartowski/Meta-Llama-3.1-8B-Instruct-GGUF ·
  https://huggingface.co/bartowski/Meta-Llama-3.1-70B-Instruct-GGUF
- **Key obligations the license places on users:**
  - Comply with Meta's Acceptable Use Policy.
  - Attribution: products built with these models must display "Built with
    Llama" and include "Llama" at the start of any derived model name.
  - The >700M-monthly-active-users clause requires a separate license from Meta.
- Parrot **does not** redistribute or sublicense these weights. The user
  downloads them directly from Hugging Face and is bound by Meta's terms.

If you load a different LLM instead, its own license governs — common
alternatives carry very different terms:

| Model family | Typical license | Restrictions |
|---|---|---|
| Llama 3.x / 3.2 | Meta Llama Community License | Use restrictions, acceptable-use policy, >700M MAU clause, attribution ("Built with Llama") |
| Qwen 2.5 | Apache-2.0 | Permissive |
| Gemma | Gemma Terms of Use | Use restrictions, acceptable-use policy |
| Mistral (Apache builds) | Apache-2.0 | Permissive |

---

## Summary table

| Component | Type | License | Redistributed by Parrot? |
|---|---|---|---|
| Parrot (this app) | Source | Apache-2.0 | — |
| whisper.cpp v1.8.4 | Binary framework | MIT | Yes (via SPM) |
| llama.cpp b8559 | Binary framework | MIT | Yes (via SPM) |
| ggml | Library | MIT | Yes (within above) |
| Whisper weights | Model | MIT | No (user download) |
| LLM weights (Llama/Qwen/etc.) | Model | Per-model (see above) | No (user download) |

---

*This file is informational and is not legal advice. License terms of each
component govern; consult the linked originals.*
