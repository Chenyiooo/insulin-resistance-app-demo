"""Optional local CalorAI inference. Weights are not fetched during requests."""

from __future__ import annotations

import base64
import io
import json
import os
from functools import lru_cache
from pathlib import Path


MODEL_NAME = "MiaoE/CalorAI"


@lru_cache(maxsize=1)
def _load_classifier():
    import torch
    import torch.nn as nn
    from torchvision import models, transforms

    torch.set_num_threads(1)
    model_dir = Path(os.environ["FOOD_VISION_MODEL_DIR"])
    labels = sorted(json.loads((model_dir / "calories_database.json").read_text()))
    classifier = models.resnet50(weights=None)
    classifier.fc = nn.Linear(classifier.fc.in_features, len(labels))
    classifier_state = torch.load(model_dir / "food_classifier.pth", map_location="cpu", weights_only=True)
    classifier.load_state_dict({key.removeprefix("model."): value for key, value in classifier_state["model_state_dict"].items()})
    classifier.eval()

    transform = transforms.Compose([
        transforms.Resize((400, 400)),
        transforms.ToTensor(),
        transforms.Normalize(mean=[0.5] * 3, std=[0.5] * 3),
    ])
    return labels, classifier, transform


@lru_cache(maxsize=1)
def _load_regressor(labels: tuple[str, ...]):
    import torch
    import torch.nn as nn
    import timm

    model_dir = Path(os.environ["FOOD_VISION_MODEL_DIR"])

    class PortionRegressor(nn.Module):
        def __init__(self):
            super().__init__()
            self.backbone = timm.create_model("resnet34", pretrained=False, num_classes=16)
            self.vector_embed = nn.Linear(len(labels), 16)
            self.fc = nn.Sequential(nn.Linear(32, 256), nn.ReLU(), nn.Linear(256, 32), nn.ReLU(), nn.Linear(32, len(labels)), nn.ReLU())

        def forward(self, image, food_vector):
            return self.fc(torch.cat((self.backbone(image), self.vector_embed(food_vector)), dim=1))

    regressor = PortionRegressor()
    portion_state = torch.load(model_dir / "portion_regressor.pth", map_location="cpu", weights_only=True)
    regressor.load_state_dict(portion_state["model_state_dict"])
    regressor.eval()
    return regressor


def recognize_foods(image_base64: list[str]) -> list[tuple[str, float]]:
    import torch
    from PIL import Image

    labels, classifier, transform = _load_classifier()
    results: list[tuple[str, float]] = []
    for encoded in image_base64[:4]:
        image = Image.open(io.BytesIO(base64.b64decode(encoded))).convert("RGB")
        tensor = transform(image).unsqueeze(0)
        with torch.inference_mode():
            probabilities = torch.sigmoid(classifier(tensor))[0]
            detected = (probabilities >= 0.7).float()
            if not detected.any():
                continue
            regressor = _load_regressor(tuple(labels))
            portions = regressor(tensor, detected.unsqueeze(0))[0]
        for index in detected.nonzero().flatten().tolist():
            grams = float(portions[index])
            if 5 <= grams <= 2000:
                results.append((labels[index], grams))
    return results


def model_available() -> bool:
    directory = os.getenv("FOOD_VISION_MODEL_DIR")
    return bool(directory and all((Path(directory) / name).is_file() for name in (
        "calories_database.json", "food_classifier.pth", "portion_regressor.pth"
    )))
