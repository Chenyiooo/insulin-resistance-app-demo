# Backend API

This backend serves accounts, cloud-synced app data, and the reduced 18-feature LightGBM insulin resistance screening model.

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

### `GET /me/checkins/latest`

Loads the latest saved check-in.

## Development Database

By default the API stores account and app data in:

```text
backend/app.db
```

This is a local SQLite development database that behaves like the cloud database from the app's point of view. It is ignored by Git. For deployment, set `IR_APP_DB_PATH` to a persistent path, or replace `backend/storage.py` with a hosted database implementation.

## Security And Privacy Controls

Implemented in this prototype:

- Passwords are salted and hashed with PBKDF2-HMAC-SHA256.
- Session bearer tokens are randomly generated and only token hashes are stored in SQLite.
- Login and registration have a simple in-memory rate limit.
- Request bodies are capped with `IR_MAX_BODY_BYTES` to reduce accidental oversized uploads.
- CORS origins are configurable with `IR_ALLOWED_ORIGINS`; the default is local development only.
- Responses include basic no-store and browser hardening headers.
- Users can export and delete their stored backend data.

Configuration:

```bash
export IR_ALLOWED_ORIGINS="http://127.0.0.1:8000,http://localhost:8000"
export IR_MAX_BODY_BYTES=524288
export IR_APP_DB_PATH="/path/to/app.db"
```

Deployment still needs production hardening: HTTPS termination, managed database backups, server-side secret management, audit logging, environment-specific CORS values, database encryption policies, and formal privacy/compliance review.

## Important Notes

- This API is for screening and reflection, not diagnosis.
- Blood pressure inputs are optional. If omitted, they are imputed by the trained model imputer.
- Other model inputs are required and should be prepared by the iOS `ModelInputMapper`.
- The model bundle is loaded from:

```text
results/models/reduced_lightgbm_bundle.joblib
```
