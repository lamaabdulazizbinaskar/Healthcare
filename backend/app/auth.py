"""Who is calling? Demo mode trusts an X-User-Id header; firebase mode verifies an ID token."""
from typing import Optional

from fastapi import Header, HTTPException

from . import config


def current_user(
    x_user_id: Optional[str] = Header(default=None),
    authorization: Optional[str] = Header(default=None),
) -> str:
    if config.AUTH == "firebase":
        if not authorization or not authorization.startswith("Bearer "):
            raise HTTPException(401, "Missing Firebase ID token")
        import firebase_admin
        from firebase_admin import auth

        if not firebase_admin._apps:
            firebase_admin.initialize_app()
        try:
            return auth.verify_id_token(authorization[7:])["uid"]
        except Exception as e:  # invalid / expired token
            raise HTTPException(401, "Invalid Firebase ID token") from e
    return x_user_id or config.DEMO_USER_ID
