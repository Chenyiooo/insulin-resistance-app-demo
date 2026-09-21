"""Local CalorAI inference using CPU-only ONNX models."""

from __future__ import annotations

import base64
import io
import json
import os
from functools import lru_cache
from pathlib import Path


MODEL_NAME = "MiaoE/CalorAI"


def _model_dir() -> Path:
    return Path(os.environ["FOOD_VISION_MODEL_DIR"])


def _session(path: Path):
    import onnxruntime as ort

    options = ort.SessionOptions()
    options.intra_op_num_threads = 1
    options.inter_op_num_threads = 1
    return ort.InferenceSession(str(path), sess_options=options, providers=["CPUExecutionProvider"])


@lru_cache(maxsize=1)
def _load_classifier():
    labels = sorted(json.loads((_model_dir() / "calories_database.json").read_text()))
    return labels, _session(_model_dir() / "food_classifier.onnx")


@lru_cache(maxsize=1)
def _load_regressor():
    return _session(_model_dir() / "portion_regressor.onnx")


def recognize_foods(image_base64: list[str]) -> list[tuple[str, float]]:
    import numpy as np
    from PIL import Image

    labels, classifier = _load_classifier()
    results: list[tuple[str, float]] = []
    for encoded in image_base64[:4]:
        image = Image.open(io.BytesIO(base64.b64decode(encoded))).convert("RGB").resize((400, 400))
        pixels = np.asarray(image, dtype=np.float32) / 127.5 - 1.0
        tensor = np.transpose(pixels, (2, 0, 1))[None, ...]
        logits = classifier.run(None, {"image": tensor})[0][0]
        probabilities = 1.0 / (1.0 + np.exp(-np.clip(logits, -80, 80)))
        detected = (probabilities >= 0.7).astype(np.float32)
        if not detected.any():
            continue
        portions = _load_regressor().run(None, {"image": tensor, "food_vector": detected[None, ...]})[0][0]
        for index in np.flatnonzero(detected):
            grams = float(portions[index])
            if 5 <= grams <= 2000:
                results.append((labels[index], grams))
    return results


def model_available() -> bool:
    directory = os.getenv("FOOD_VISION_MODEL_DIR")
    return bool(directory and all((Path(directory) / name).is_file() for name in (
        "calories_database.json", "food_classifier.onnx", "portion_regressor.onnx"
    )))
