// Lateinische Spracherkennung im Browser (Texte auswendig lernen).
//
// Läuft als Web Worker, damit die Oberfläche während der Erkennung nicht
// stehen bleibt. Erkannt wird vollständig im Browser: Das Gesprochene
// verlässt das Gerät nicht. Nur das Sprachmodell wird einmalig von
// Hugging Face geladen und danach im Browser-Cache gehalten.
//
// Bibliotheken (in diesem Ordner, siehe THIRD_PARTY.md):
//   transformers.min.js            Transformers.js (Apache-2.0)
//   ort-wasm-simd-threaded.{mjs,wasm}  ONNX Runtime Web (MIT)
//
// Protokoll (postMessage):
//   → {type: "status"}                       ← {type: "status", cached}
//   → {type: "load"}                         ← {type: "progress", fraction}* dann {type: "ready"}
//   → {type: "transcribe", id, audio}        ← {type: "result", id, text}
//   Fehler:                                  ← {type: "error", id?, message}
// `audio` ist ein Float32Array, mono, 16 kHz.

import { pipeline, env } from "./transformers.min.js";

// Whisper „small“, mehrsprachig, 8-Bit-quantisiert (ca. 250 MB). Kleinere
// Modelle verstehen Latein deutlich schlechter. Die Revision ist
// festgeschrieben, damit sich das Modell nicht unbemerkt ändert.
const MODEL = "Xenova/whisper-small";
const REVISION = "2d67713f236afa48a18992566e7647f6ca848e13";
const DTYPE = { encoder_model: "q8", decoder_model_merged: "q8" };

// Die großen Dateien des Modells; an ihnen wird der Ladefortschritt gemessen
// und erkannt, ob das Modell schon im Cache liegt.
const WEIGHTS = [
  "onnx/encoder_model_quantized.onnx",
  "onnx/decoder_model_merged_quantized.onnx",
];

env.allowLocalModels = false;
env.useBrowserCache = true;

// ONNX Runtime aus diesem Ordner statt von einem CDN.
const here = new URL("./", import.meta.url).href;
env.backends.onnx.wasm.wasmPaths = {
  mjs: here + "ort-wasm-simd-threaded.mjs",
  wasm: here + "ort-wasm-simd-threaded.wasm",
};

let recognizer = null;
let loading = null;

function weightUrl(file) {
  return `${env.remoteHost}${MODEL}/resolve/${REVISION}/${file}`;
}

async function isCached() {
  try {
    const cache = await caches.open("transformers-cache");

    for (const file of WEIGHTS) {
      if (!(await cache.match(weightUrl(file)))) return false;
    }

    return true;
  } catch (_) {
    return false;
  }
}

function load() {
  loading ??= (async () => {
    const loaded = {};
    const total = {};

    recognizer = await pipeline("automatic-speech-recognition", MODEL, {
      revision: REVISION,
      dtype: DTYPE,
      device: "wasm",
      progress_callback: (event) => {
        if (event.status !== "progress" || !WEIGHTS.includes(event.file)) return;

        loaded[event.file] = event.loaded;
        total[event.file] = event.total;

        // Erst melden, wenn die Größe beider Dateien bekannt ist; sonst
        // spränge die Anzeige zurück.
        if (Object.keys(total).length < WEIGHTS.length) return;

        const sum = (values) => Object.values(values).reduce((a, b) => a + b, 0);
        const all = sum(total);

        if (all > 0) {
          self.postMessage({ type: "progress", fraction: sum(loaded) / all });
        }
      },
    });
  })().catch((error) => {
    loading = null;
    throw error;
  });

  return loading;
}

self.onmessage = async (event) => {
  const message = event.data;

  try {
    switch (message.type) {
      case "status":
        self.postMessage({ type: "status", cached: await isCached() });
        break;

      case "load":
        await load();
        self.postMessage({ type: "ready" });
        break;

      case "transcribe": {
        await load();

        const output = await recognizer(message.audio, {
          language: "la",
          task: "transcribe",
          chunk_length_s: 30,
        });

        self.postMessage({
          type: "result",
          id: message.id,
          text: (output.text ?? "").trim(),
        });
        break;
      }
    }
  } catch (error) {
    self.postMessage({
      type: "error",
      id: message.id,
      message: String(error?.message ?? error),
    });
  }
};
