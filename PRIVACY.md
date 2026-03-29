# Privacy Policy

**Last updated:** March 29, 2026

## Overview

Parrot is a local-only macOS dictation application. All processing happens entirely on your device. No data is transmitted to external servers.

## Data Collection

Parrot does **not** collect, store, or transmit any personal data. Specifically:

- **Audio**: Microphone input is captured in memory for transcription and discarded immediately after processing. Audio is never saved to disk or sent over a network.
- **Transcriptions**: Text output from speech-to-text and LLM cleanup is injected directly into the active application and is not retained by Parrot.
- **Analytics**: Parrot does not include any analytics, telemetry, or crash reporting.
- **Network**: The only network requests Parrot makes are to download model files from Hugging Face when you explicitly initiate a download. No other network calls are made.

## Permissions

Parrot requests the following macOS permissions:

| Permission | Purpose |
|---|---|
| **Microphone** | Capturing speech for transcription |
| **Accessibility** | Injecting transcribed text into the active application |

These permissions are used solely for core functionality and can be revoked at any time in System Settings.

## Local Storage

Parrot stores the following data locally on your Mac:

- **Model files** in `~/Library/Application Support/Parrot/Models/` — machine learning models you download for speech-to-text and text cleanup
- **User preferences** — your settings (hotkey, model selections, etc.)

No personal or sensitive data is stored.

## Third-Party Services

Parrot does not integrate with any third-party services. Model downloads are fetched directly from Hugging Face (`huggingface.co`) over HTTPS.

## Contact

If you have questions about this privacy policy, please open an issue on the [GitHub repository](https://github.com/christianalexa/parrot).
