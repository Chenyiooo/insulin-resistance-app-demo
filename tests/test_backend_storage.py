import os
import tempfile
import unittest

from backend import storage


class BackendStorageTest(unittest.TestCase):
    def setUp(self):
        self.tmpdir = tempfile.TemporaryDirectory()
        self.previous_db_path = os.environ.get("IR_APP_DB_PATH")
        os.environ["IR_APP_DB_PATH"] = os.path.join(self.tmpdir.name, "test.db")
        storage.init_db()

    def tearDown(self):
        if self.previous_db_path is None:
            os.environ.pop("IR_APP_DB_PATH", None)
        else:
            os.environ["IR_APP_DB_PATH"] = self.previous_db_path
        self.tmpdir.cleanup()

    def test_user_session_profile_and_checkin_roundtrip(self):
        user = storage.create_user("Student@example.com", "password123", name="Student")
        self.assertEqual(user["email"], "student@example.com")

        authed = storage.authenticate_user("student@example.com", "password123")
        self.assertIsNotNone(authed)

        token = storage.create_session(user["id"])
        session_user = storage.get_user_for_token(token)
        self.assertEqual(session_user["id"], user["id"])

        profile = storage.save_profile(user["id"], {"age": "34", "sexAtBirth": "Female"})
        self.assertEqual(profile["data"]["age"], "34")
        self.assertEqual(storage.get_profile(user["id"])["data"]["sexAtBirth"], "Female")

        checkin = storage.save_checkin(
            user_id=user["id"],
            checkin_date="2026-08-12",
            data={"sleepHours": "7"},
            model_payload={"features": {"age": 34}},
            risk_result={"percent": 19},
        )
        self.assertEqual(checkin["risk_result"]["percent"], 19)
        self.assertEqual(storage.latest_checkin(user["id"])["data"]["sleepHours"], "7")

        storage.delete_session(token)
        self.assertIsNone(storage.get_user_for_token(token))

    def test_export_and_delete_user_data(self):
        user = storage.create_user("privacy@example.com", "password123", name="Privacy")
        token = storage.create_session(user["id"])
        storage.save_profile(user["id"], {"age": "41"})
        storage.save_checkin(
            user_id=user["id"],
            checkin_date="2026-08-12",
            data={"sleepHours": "7.5"},
        )

        exported = storage.export_user_data(user["id"])
        self.assertEqual(exported["user"]["email"], "privacy@example.com")
        self.assertEqual(exported["profile"]["data"]["age"], "41")
        self.assertEqual(len(exported["checkins"]), 1)
        self.assertIn("exported_at", exported)

        storage.delete_user(user["id"])
        self.assertIsNone(storage.get_user_for_token(token))
        self.assertIsNone(storage.get_profile(user["id"]))
        self.assertEqual(storage.list_checkins(user["id"]), [])

    def test_duplicate_email_is_rejected(self):
        storage.create_user("same@example.com", "password123")
        with self.assertRaises(ValueError):
            storage.create_user("same@example.com", "password123")

    def test_invalid_email_is_rejected(self):
        with self.assertRaises(ValueError):
            storage.create_user("not-an-email", "password123")


if __name__ == "__main__":
    unittest.main()
