"""Convert pinned CalorAI PyTorch checkpoints to CPU ONNX models at build time."""

from __future__ import annotations

import json
import shutil
import sys
from pathlib import Path

import timm
import torch
from torch import nn
from torchvision import models


class PortionRegressor(nn.Module):
    def __init__(self, class_count: int):
        super().__init__()
        self.backbone = timm.create_model("resnet34", pretrained=False, num_classes=16)
        self.vector_embed = nn.Linear(class_count, 16)
        self.fc = nn.Sequential(
            nn.Linear(32, 256), nn.ReLU(), nn.Linear(256, 32), nn.ReLU(),
            nn.Linear(32, class_count), nn.ReLU(),
        )

    def forward(self, image, food_vector):
        return self.fc(torch.cat((self.backbone(image), self.vector_embed(food_vector)), dim=1))


def export(source: Path, destination: Path) -> None:
    destination.mkdir(parents=True, exist_ok=True)
    shutil.copy2(source / "data/calories_database.json", destination / "calories_database.json")
    shutil.copy2(source / "LICENSE", destination / "LICENSE")
    labels = sorted(json.loads((destination / "calories_database.json").read_text()))
    image = torch.zeros(1, 3, 400, 400)

    classifier = models.resnet50(weights=None)
    classifier.fc = nn.Linear(classifier.fc.in_features, len(labels))
    checkpoint = torch.load(source / "model/food_classifier.pth", map_location="cpu", weights_only=True)
    classifier.load_state_dict({key.removeprefix("model."): value for key, value in checkpoint["model_state_dict"].items()})
    classifier.eval()
    torch.onnx.export(
        classifier, image, destination / "food_classifier.onnx", opset_version=17,
        input_names=["image"], output_names=["logits"],
    )
    del classifier, checkpoint

    regressor = PortionRegressor(len(labels))
    checkpoint = torch.load(source / "model/portion_regressor.pth", map_location="cpu", weights_only=True)
    regressor.load_state_dict(checkpoint["model_state_dict"])
    regressor.eval()
    torch.onnx.export(
        regressor, (image, torch.zeros(1, len(labels))), destination / "portion_regressor.onnx",
        opset_version=17, input_names=["image", "food_vector"], output_names=["grams"],
    )


if __name__ == "__main__":
    export(Path(sys.argv[1]), Path(sys.argv[2]))
