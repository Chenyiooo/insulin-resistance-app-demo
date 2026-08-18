# Backend API

This backend serves accounts, cloud-synced app data, and the reduced 18-feature LightGBM insulin resistance screening model.

The API is deployable as a Docker service and can run without the iOS app being connected to a local development machine. For a TestFlight demo, point the iOS app at the deployed HTTPS base URL.

## Install

From the repository root:

```bash
pip install -r requirements.txt
```

## Run Locally

```bash
python -m uvicorn backend.main:app --reload --host 127.0.0.1 --port 8000
```

Open the interactive API docs:

```text
http://127.0.0.1:8000/docs
```

## Endpoints

### `GET /health`

Checks whether the API and model are loaded.

### `GET /ready`

Checks whether the API can reach its database and model. Use this as the deployment health check.

### `GET /model/schema`

Returns the model feature order, profile inputs, check-in inputs, optional inputs, units, and saved model metrics.

### `POST /predict`

Accepts the iOS `ModelInputPayload` shape. The most important field is `features`.

Example:

```bash
curl -X POST http://127.0.0.1:8000/predict \
  -H "Content-Type: application/json" \
  -d '{
    "features": {
      "age": 34,
      "sex": 2,
      "race": 5,
      "bmi": 23.9,
      "waist_circumference": 83.8,
      "weight": 67.1,
      "height": 167.6,
      "systolic_bp": 122,
      "diastolic_bp": 78,
      "family_diabetes": 1,
      "hypertension_history": 0,
      "hypertension_med": 0,
      "high_cholesterol": 0,
      "smoking_status": 0,
      "alcohol_frequency": 0,
      "sleep_hours": 7,
      "gestational_diabetes": 0,
      "waist_height_ratio": 0.50
    }
  }'
```

The response includes:

- `probability`: model probability for lab-defined insulin resistance
- `percent`: rounded percentage
- `band`: `Lower Risk`, `Moderate Risk`, or `High Risk`
- `imputed_features`: optional or missing values filled by the model imputer
- `increasing_factors` and `decreasing_factors`: rule-based explanation labels
- `suggestions`: non-diagnostic lifestyle suggestions

### `POST /nutrition/estimate`

Estimates calories and macronutrients from a typed food description, uploaded food photos, or both:

```bash
curl -X POST http://127.0.0.1:8000/nutrition/estimate \
  -H "Content-Type: application/json" \
  -d '{
    "text": "chicken, rice, and an apple",
    "image_base64": []
  }'
```

The response includes estimated `calories`, `carbohydrates`, `protein`, `fat`, detected or matched foods, confidence, explanation, and a disclaimer.

If `OPENAI_API_KEY` is configured, the endpoint uses a vision/language model for photo and text estimation:

```bash
export OPENAI_API_KEY="..."
export OPENAI_NUTRITION_MODEL="gpt-5-mini"
export OPENAI_NUTRITION_IMAGE_DETAIL="high"
```

On Render, set `OPENAI_API_KEY` in **Environment** as a secret value. Do not commit the key to GitHub. `OPENAI_NUTRITION_MODEL` and `OPENAI_NUTRITION_IMAGE_DETAIL` can stay in `render.yaml`.

Without an API key, typed descriptions fall back to local common-serving nutrition rules. Photo-only inputs return a low-confidence generic meal estimate so the app remains usable during development. Nutrition values are estimates for reflection only, not medical or dietary advice.

## Account And Cloud Data Endpoints

### `POST /auth/register`

Creates an account and returns a bearer token.

```json
{
  "email": "student@example.com",
  "password": "password123",
  "name": "Chenyi"
}
```

### `POST /auth/login`

Logs in and returns a bearer token.

### `GET /me`

Returns the signed-in user. Requires:

```text
Authorization: Bearer <token>
```

### `GET /me/export`

Exports the signed-in user's account record, profile JSON, and recent check-ins. This is the development API hook for user data access requests.

### `DELETE /me`

Deletes the signed-in user's account, profile, check-ins, and sessions from the development database.

### `PUT /me/profile`

Saves the user's profile JSON:

```json
{
  "data": {
    "age": "34",
    "sexAtBirth": "Female"
  }
}
```

### `GET /me/profile`

Loads the user's saved profile.

### `POST /me/checkins`

Saves one check-in, plus optional model payload and risk result:

```json
{
  "checkin_date": "2026-08-12",
  "source": "apple_health_confirmed",
  "provenance": {
    "source": "apple_health",
    "confirmation": "user_confirmed",
    "imported_fields": "sleep_hours,physical_activity",
    "confirmed_at": "2026-08-18T10:00:00Z"
  },
  "data": {
    "sleepHours": "7"
  },
  "model_payload": {
    "features": {
      "age": 34
    }
  },
  "risk_result": {
    "percent": 19
  }
}
```

Use `source: "manual_entry"` for regular form entry. Use `source: "apple_health_confirmed"` only after the user reviews HealthKit values and taps the confirmation button in the iOS app. The backend stores `provenance` separately from the check-in body so data origin can be audited without changing the form model.

### `GET /me/checkins/latest`

Loads the latest saved check-in.

## Development Database

By default the API stores account and app data in:

```text
backend/app.db
```

This is a local SQLite development database that behaves like the cloud database from the app's point of view. It is ignored by Git.

For the free Render demo, `IR_APP_DB_PATH` is set to `/tmp/app.db`. This avoids paid persistent disk setup, but data can be lost when the service restarts or redeploys.

For a larger production rollout, replace SQLite with a managed Postgres database and keep the same endpoint contracts.

## Deployment

The repo includes:

- `Dockerfile`: container image for the FastAPI service.
- `render.yaml`: free Render Blueprint for a demo API.
- `.env.example`: environment variables to copy into your deployment settings.

Important environment variables:

```bash
export IR_ENV=production
export IR_API_VERSION=0.2.0
export IR_APP_DB_PATH=/tmp/app.db
export IR_MODEL_PATH=/app/backend/model_artifacts/reduced_lightgbm_bundle.joblib
export IR_ALLOWED_ORIGINS="https://your-app.example.com"
export IR_ENABLE_DOCS=false
```

The demo deployment model is stored at `backend/model_artifacts/reduced_lightgbm_bundle.joblib` so Git-backed cloud builds can include it in the Docker image. If you replace the model later, update that artifact or set `IR_MODEL_PATH` to another runtime path.

Run production-style locally:

```bash
IR_ENV=production \
IR_APP_DB_PATH=/tmp/ir-prod-demo.db \
IR_ENABLE_DOCS=false \
python -m uvicorn backend.main:app --host 0.0.0.0 --port 8000
```

Then check:

```bash
curl http://127.0.0.1:8000/ready
```

## Security And Privacy Controls

Implemented in this prototype:

- Passwords are salted and hashed with PBKDF2-HMAC-SHA256.
- Session bearer tokens are randomly generated and only token hashes are stored in SQLite.
- Expired sessions are cleaned up when the database initializes and when tokens are checked.
- Login and registration have a simple in-memory rate limit.
- Request bodies are capped with `IR_MAX_BODY_BYTES` to reduce accidental oversized uploads.
- CORS origins are configurable with `IR_ALLOWED_ORIGINS`; the default is local development only.
- Responses include basic no-store and browser hardening headers.
- Users can export and delete their stored backend data.
- Backend audit events record account/profile/check-in/export/delete actions without storing passwords, tokens, or health payloads in audit metadata.

Configuration:

```bash
export IR_ALLOWED_ORIGINS="http://127.0.0.1:8000,http://localhost:8000"
export IR_MAX_BODY_BYTES=5242880
export IR_APP_DB_PATH="/path/to/app.db"
export IR_MODEL_PATH="/path/to/reduced_lightgbm_bundle.joblib"
```

Deployment still needs platform-specific operations: HTTPS domain setup, managed database backups if you move beyond SQLite, server-side secret management, environment-specific CORS values, database encryption policies, and formal privacy/compliance review.

## Important Notes

- This API is for screening and reflection, not diagnosis.
- Blood pressure inputs are optional. If omitted, they are imputed by the trained model imputer.
- Other model inputs are required and should be prepared by the iOS `ModelInputMapper`.
- The model bundle is loaded from:

```text
backend/model_artifacts/reduced_lightgbm_bundle.joblib
```
