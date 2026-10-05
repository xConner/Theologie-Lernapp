# Lateinische Spracherkennung im Browser – Fremdkomponenten

Die Dateien in diesem Ordner werden mit dem Web-Build ausgeliefert, damit die
Erkennung keine Skripte von fremden Servern lädt. `worker.js` gehört zur App;
alles andere ist unverändert aus den npm-Paketen übernommen.

| Datei | Paket | Version | Lizenz |
| --- | --- | --- | --- |
| `transformers.min.js` | `@huggingface/transformers` (`dist/transformers.min.js`) | 4.3.0 | Apache-2.0 |
| `ort-wasm-simd-threaded.mjs` | `onnxruntime-web` (`dist/`) | 1.31.0-dev.20260914-8d85527a0 (von Transformers.js 4.3.0 vorgegeben) | MIT |
| `ort-wasm-simd-threaded.wasm` | `onnxruntime-web` (`dist/`) | wie oben | MIT |

Die drei Dateien müssen zusammenpassen: beim Aktualisieren von Transformers.js
auch die beiden ONNX-Runtime-Dateien aus der dazu installierten
`onnxruntime-web`-Version übernehmen.

## Modell (wird zur Laufzeit geladen, liegt nicht im Repository)

| Plattform | Modell | Größe | Lizenz |
| --- | --- | --- | --- |
| Web | `Xenova/whisper-small` (Hugging Face), 8-Bit-quantisiert, Revision in `worker.js` | ca. 250 MB | MIT (OpenAI Whisper) |
| Android, iOS, Desktop | `csukuangfj/sherpa-onnx-whisper-small` (Hugging Face), 8-Bit-quantisiert, Revision in `lib/services/speech/latin/latin_transcriber_io.dart` | ca. 375 MB | MIT (OpenAI Whisper) |

Das Modell wird beim ersten Gebrauch nach Rückfrage von `huggingface.co`
geladen und danach auf dem Gerät bzw. im Browser-Cache gehalten. Die
Sprachaufnahme selbst verlässt das Gerät nicht.
