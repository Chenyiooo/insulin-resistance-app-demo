from __future__ import annotations

from typing import Any

from datetime import date

from fastapi import Depends, FastAPI, Header, HTTPException
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel, Field

from backend.config import settings
from backend.service import ModelInputError, RiskPredictionService, prediction_to_dict
from backend import storage
from backend.nutrition import estimate_nutrition, validate_base64_images
from backend.security import InMemoryAuthRateLimitMiddleware, SecurityHeadersMiddleware, allowed_origins


app = FastAPI(
    title="Insulin Resistance Screening API",
    version=settings.api_version,
    description=(
        "Backend API for the reduced 18-feature LightGBM insulin resistance "
        "screening model. Estimates are for screening and reflection only."
    ),
    docs_url="/docs" if settings.enable_docs else None,
    redoc_url="/redoc" if settings.enable_docs else None,
)

app.add_middleware(
    CORSMiddleware,
    allow_origins=allowed_origins(),
    allow_credentials=False,
    allow_methods=["*"],
    allow_headers=["*"],
)
app.add_middleware(SecurityHeadersMiddleware)
app.add_middleware(InMemoryAuthRateLimitMiddleware)

service = RiskPredictionService()
storage.init_db()


class MissingDataItemRequest(BaseModel):
    field: str
    label: str | None = None
    code: str | None = None


class PredictRequest(BaseModel):
    modelName: str | None = None
    modelVersion: str | None = None
    featureOrder: list[str] | None = None
    features: dict[str, float | None] = Field(default_factory=dict)
    profileInputs: dict[str, float | None] = Field(default_factory=dict)
    checkInInputs: dict[str, float | None] = Field(default_factory=dict)
    derivedInputs: dict[str, float | None] = Field(default_factory=dict)
    missingRequiredInputs: list[MissingDataItemRequest] = Field(default_factory=list)
    omittedOptionalInputs: list[str] = Field(default_factory=list)
    recentCheckIns: list[dict[str, Any]] | None = None


class PredictResponse(BaseModel):
    model_name: str
    model_version: str
    probability: float
    percent: int
    band: str
    threshold: float
    features_used: list[str]
    imputed_features: list[str]
    increasing_factors: list[str]
    decreasing_factors: list[str]
    suggestions: list[dict[str, Any]]
    disclaimer: str


class AuthRequest(BaseModel):
    email: str = Field(min_length=3, max_length=254)
    password: str = Field(min_length=8, max_length=128)
    name: str | None = Field(default=None, max_length=80)


class UserResponse(BaseModel):
    id: str
    email: str
    name: str
    created_at: str
    updated_at: str


class AuthResponse(BaseModel):
    token: str
    user: UserResponse


class ProfileRequest(BaseModel):
    data: dict[str, Any]


class ProfileResponse(BaseModel):
    data: dict[str, Any]
    updated_at: str


class CheckInRequest(BaseModel):
    checkin_date: str | None = None
    source: str = "manual_entry"
    provenance: dict[str, Any] | None = None
    data: dict[str, Any]
    model_payload: dict[str, Any] | None = None
    risk_result: dict[str, Any] | None = None


class CheckInResponse(BaseModel):
    id: str
    checkin_date: str
    source: str
    provenance: dict[str, Any] | None = None
    data: dict[str, Any]
    model_payload: dict[str, Any] | None = None
    risk_result: dict[str, Any] | None = None
    created_at: str
    updated_at: str


class NutritionEstimateRequest(BaseModel):
    text: str = Field(default="", max_length=4000)
    image_base64: list[str] = Field(default_factory=list, max_length=4)


class NutritionEstimateResponse(BaseModel):
    calories: int
    carbohydrates: float
    protein: float
    fat: float
    matched_foods: list[str]
    source: str
    confidence: str
    explanation: str
    disclaimer: str


@app.get("/health")
def health() -> dict[str, Any]:
    return {
        "status": "ok",
        "environment": settings.environment,
        "model_loaded": True,
        "model_name": service.model_name,
        "model_version": service.model_version,
        "feature_count": len(service.features),
    }


@app.get("/ready")
def ready() -> dict[str, Any]:
    db = storage.readiness()
    if not db["ok"]:
        raise HTTPException(status_code=503, detail=db)
    return {
        "status": "ready",
        "database": db,
        "model_loaded": True,
        "api_version": settings.api_version,
    }


@app.get("/model/schema")
def model_schema() -> dict[str, Any]:
    return service.schema()


def require_user(authorization: str | None) -> dict[str, Any]:
    if not authorization or not authorization.startswith("Bearer "):
        raise HTTPException(status_code=401, detail="Missing bearer token.")
    token = authorization.removeprefix("Bearer ").strip()
    user = storage.get_user_for_token(token)
    if user is None:
        raise HTTPException(status_code=401, detail="Invalid or expired token.")
    user["_token"] = token
    return user


def current_user(authorization: str | None = Header(default=None)) -> dict[str, Any]:
    return require_user(authorization)


@app.post("/auth/register", response_model=AuthResponse)
def register(request: AuthRequest) -> dict[str, Any]:
    try:
        user = storage.create_user(
            email=request.email,
            password=request.password,
            name=request.name or "",
        )
    except ValueError as exc:
        storage.log_event(None, "auth.register_failed", {"reason": str(exc)})
        raise HTTPException(status_code=400, detail=str(exc)) from exc
    token = storage.create_session(user["id"])
    storage.log_event(user["id"], "auth.registered")
    return {"token": token, "user": user}


@app.post("/auth/login", response_model=AuthResponse)
def login(request: AuthRequest) -> dict[str, Any]:
    user = storage.authenticate_user(request.email, request.password)
    if user is None:
        storage.log_event(None, "auth.login_failed")
        raise HTTPException(status_code=401, detail="Invalid email or password.")
    token = storage.create_session(user["id"])
    storage.log_event(user["id"], "auth.logged_in")
    return {"token": token, "user": user}


@app.post("/auth/logout")
def logout(current: dict[str, Any] = Depends(current_user)) -> dict[str, str]:
    token = current["_token"]
    storage.delete_session(token)
    storage.log_event(current["id"], "auth.logged_out")
    return {"status": "ok"}


@app.get("/me", response_model=UserResponse)
def me(current: dict[str, Any] = Depends(current_user)) -> dict[str, Any]:
    return {key: value for key, value in current.items() if key != "_token"}


@app.get("/me/export")
def export_my_data(current: dict[str, Any] = Depends(current_user)) -> dict[str, Any]:
    storage.log_event(current["id"], "privacy.export_requested")
    return storage.export_user_data(current["id"])


@app.delete("/me")
def delete_my_account(current: dict[str, Any] = Depends(current_user)) -> dict[str, str]:
    storage.log_event(current["id"], "privacy.delete_requested")
    storage.delete_user(current["id"])
    return {"status": "deleted"}


@app.get("/me/profile", response_model=ProfileResponse | None)
def get_my_profile(current: dict[str, Any] = Depends(current_user)) -> dict[str, Any] | None:
    return storage.get_profile(current["id"])


@app.put("/me/profile", response_model=ProfileResponse)
def save_my_profile(
    request: ProfileRequest,
    current: dict[str, Any] = Depends(current_user),
) -> dict[str, Any]:
    response = storage.save_profile(current["id"], request.data)
    storage.log_event(current["id"], "profile.saved")
    return response


@app.post("/me/checkins", response_model=CheckInResponse)
def save_my_checkin(
    request: CheckInRequest,
    current: dict[str, Any] = Depends(current_user),
) -> dict[str, Any]:
    response = storage.save_checkin(
        user_id=current["id"],
        checkin_date=request.checkin_date or date.today().isoformat(),
        data=request.data,
        model_payload=request.model_payload,
        risk_result=request.risk_result,
        source=request.source,
        provenance=request.provenance,
    )
    storage.log_event(
        current["id"],
        "checkin.saved",
        {"source": response["source"], "checkin_date": response["checkin_date"]},
    )
    return response


@app.get("/me/checkins", response_model=list[CheckInResponse])
def get_my_checkins(
    limit: int = 30,
    current: dict[str, Any] = Depends(current_user),
) -> list[dict[str, Any]]:
    return storage.list_checkins(current["id"], limit=max(1, min(limit, 100)))


@app.get("/me/checkins/latest", response_model=CheckInResponse | None)
def get_latest_checkin(current: dict[str, Any] = Depends(current_user)) -> dict[str, Any] | None:
    return storage.latest_checkin(current["id"])


@app.post("/nutrition/estimate", response_model=NutritionEstimateResponse)
def estimate_food_nutrition(request: NutritionEstimateRequest) -> dict[str, Any]:
    try:
        validate_base64_images(request.image_base64)
    except ValueError as exc:
        raise HTTPException(status_code=400, detail=str(exc)) from exc
    return estimate_nutrition(text=request.text, image_base64=request.image_base64)


@app.post("/predict", response_model=PredictResponse)
def predict(request: PredictRequest) -> dict[str, Any]:
    if request.modelName and request.modelName != service.model_name:
        raise HTTPException(
            status_code=422,
            detail={
                "message": "The requested model name does not match the loaded backend model.",
                "expected": service.model_name,
                "received": request.modelName,
            },
        )
    if request.modelVersion and request.modelVersion != service.model_version:
        raise HTTPException(
            status_code=422,
            detail={
                "message": "The requested model version does not match the loaded backend model.",
                "expected": service.model_version,
                "received": request.modelVersion,
            },
        )
    if request.featureOrder and request.featureOrder != service.features:
        raise HTTPException(
            status_code=422,
            detail={
                "message": "The submitted feature order does not match the loaded backend model.",
                "expected_features": service.features,
                "received_features": request.featureOrder,
            },
        )

    if request.missingRequiredInputs:
        missing = [item.field for item in request.missingRequiredInputs]
        raise HTTPException(
            status_code=422,
            detail={
                "message": "The app reported missing required inputs.",
                "missing_features": missing,
            },
        )

    try:
        result = service.predict(
            request.model_dump(),
            recent_checkins=request.recentCheckIns,
        )
    except ModelInputError as exc:
        raise HTTPException(
            status_code=422,
            detail={
                "message": str(exc),
                "missing_features": exc.missing_features,
            },
        ) from exc
    except Exception as exc:
        raise HTTPException(
            status_code=500,
            detail={
                "message": "Prediction failed while running the loaded model.",
                "error_type": exc.__class__.__name__,
            },
        ) from exc

    return prediction_to_dict(result)
