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

### `GET /me/weekly-feedback`

Returns account-specific Day 7 or Day 14 feedback, anchored to the first completed check-in date rather than a weekday. The API uses the latest completed submission for each date and requires every date in the first 7 or 14 calendar days to be complete. A missing day returns `incomplete` with no risk percentage. Day 14 uses all 14 days, not just the most recent seven.

The risk model receives mean sleep duration and, where measured, mean weight, waist circumference, and blood pressure for that window. BMI and waist-to-height ratio are recomputed from those means; profile/categorical features come from the last completed day in the window. `measurement_counts` reports how many actual measurements contributed to each mean. The response also includes the period's check-ins for account-specific trends. This is an aggregation of inputs to the existing LightGBM screening model, not a separately trained longitudinal model.

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

Estimates calories and macronutrients from a typed food description, uploaded food photos, or both. The endpoint parses food items and portion cues, then looks up nutrient values in the bundled offline USDA FoodData Central database. It does not call the USDA API or require an API key:

```bash
curl -X POST http://127.0.0.1:8000/nutrition/estimate \
  -H "Content-Type: application/json" \
  -d '{
    "text": "chicken, rice, and an apple",
    "image_base64": []
  }'
```

The response includes estimated `calories`, `carbohydrates`, `protein`, `fat`, matched USDA foods, confidence, explanation, and a disclaimer.

Photo recognition uses the open-source [CalorAI](https://github.com/MiaoE/CalorAI) classifier and portion regressor (MIT license), locally on the server. It supports only 26 food classes. Its published portion accuracy within 10% is about 21%, so photo-derived values are always marked low confidence. For each detected class, predicted grams are multiplied by the offline USDA nutrient values per 100 g. Unsupported foods, missing weights, or missing USDA matches are not assigned invented nutrition values.

The standard `Dockerfile` does not install these large models. The Render Blueprint now uses `Dockerfile.vision` on a 2 GB API service; it installs CPU PyTorch and fetches CalorAI weights from a pinned GitHub commit. Verify the actual build and photo response after deployment; a local test alone does not prove the live service works.

The bundled `backend/data/usda_foods.sqlite` contains 13,535 foods with all four required nutrient values. It was built from USDA's [Foundation Foods April 2026, SR Legacy April 2018, and FNDDS 2021-2023 JSON archives](https://fdc.nal.usda.gov/download-datasets/). To reproduce it, download those three public archives and run `python scripts/build_usda_offline.py foundation.zip sr.zip fndds.zip`. The database is read-only at runtime. Branded products are not included; refresh it when USDA publishes new data.

Use `GET /nutrition/status` to check `food_vision_model_available` and `usda_offline_database_available`. Both must be `true` for the full photo pipeline.

If the offline database is unavailable or no reliable food match is found, the endpoint returns `source: "unable_to_estimate"` and does not invent nutrition values. Nutrition values are estimates for reflection only, not medical or dietary advice.

### `POST /insights/daily`

Generates daily insight cards from the submitted check-in:

```bash
curl -X POST http://127.0.0.1:8000/insights/daily \
  -H "Content-Type: application/json" \
  -d '{
    "check_in": {
      "sleepHours": "5.5",
      "activeToday": true,
      "activityType": "Brisk walking",
      "activityDuration": "18",
      "movementBreaks": "A few times during the day",
      "foodJournal": "Added",
      "foodJournalDescription": "rice bowl with chicken"
    }
  }'
```

The endpoint always builds a structured rule-based plan first. If `OPENAI_API_KEY` is configured, OpenAI rewrites that plan into more natural, supportive language without changing the title, icon, logged facts, or recommendation direction. If OpenAI is unavailable, over quota, or returns unsafe/unparseable output, the endpoint returns the rule-based fallback with `source: "rule_fallback"`.

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

By default the API stores account and app data in local SQLite:

```text
backend/app.db
```

This is a local SQLite development database that behaves like the cloud database from the app's point of view. It is ignored by Git.

For deployed builds, set `DATABASE_URL` or `IR_DATABASE_URL` to a Postgres connection string. When this variable is present, the same account, profile, check-in, audit, export, and delete endpoints use Postgres instead of SQLite.

The Render Blueprint in this repo creates a managed Postgres database and injects its connection string into the API as `DATABASE_URL`, so TestFlight users keep their account data after service restarts and redeploys.

## Deployment

The repo includes:

- `Dockerfile`: container image for the FastAPI service.
- `render.yaml`: free Render Blueprint for a demo API.
- `.env.example`: environment variables to copy into your deployment settings.

Important environment variables:

```bash
export IR_ENV=production
export IR_API_VERSION=0.2.0
export DATABASE_URL="postgresql://user:password@host:5432/database"
export IR_MODEL_PATH=/app/backend/model_artifacts/reduced_lightgbm_bundle.joblib
export IR_ALLOWED_ORIGINS="https://your-app.example.com"
export IR_ENABLE_DOCS=false
```

Leave `DATABASE_URL` unset for local development if you want to use SQLite. You can optionally set `IR_APP_DB_PATH` to choose a different local SQLite file.

The demo deployment model is stored at `backend/model_artifacts/reduced_lightgbm_bundle.joblib` so Git-backed cloud builds can include it in the Docker image. If you replace the model later, update that artifact or set `IR_MODEL_PATH` to another runtime path.

Run production-style locally:

```bash
IR_ENV=production \
DATABASE_URL="postgresql://user:password@localhost:5432/insulin_resistance" \
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
export DATABASE_URL="postgresql://user:password@host:5432/database"
export IR_MODEL_PATH="/path/to/reduced_lightgbm_bundle.joblib"
```

Deployment still needs platform-specific operations: HTTPS domain setup, managed database backups, server-side secret management, environment-specific CORS values, database encryption policies, and formal privacy/compliance review.

## Important Notes

- This API is for screening and reflection, not diagnosis.
- Blood pressure inputs are optional. If omitted, they are imputed by the trained model imputer.
- Other model inputs are required and should be prepared by the iOS `ModelInputMapper`.
- The model bundle is loaded from:

```text
backend/model_artifacts/reduced_lightgbm_bundle.joblib
```
