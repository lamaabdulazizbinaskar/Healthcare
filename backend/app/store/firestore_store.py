"""Firestore store. Enabled with KHUTWA_STORE=firestore.

Requires `pip install firebase-admin` and GOOGLE_APPLICATION_CREDENTIALS pointing at a
service-account JSON. Layout: users/{uid} holds profile+plan+adaptations; BP readings and
check-ins are kept in the same document for the MVP (small per-user volumes). Move them
to sub-collections when data grows.
"""
from ..models import UserData
from .base import Repository


class FirestoreRepository(Repository):
    def __init__(self):
        import firebase_admin  # imported lazily so local mode needs no Firebase install
        from firebase_admin import firestore

        if not firebase_admin._apps:
            firebase_admin.initialize_app()
        self._db = firestore.client()

    def _doc(self, user_id: str):
        return self._db.collection("users").document(user_id)

    def load(self, user_id: str) -> UserData:
        snap = self._doc(user_id).get()
        if not snap.exists:
            return UserData()
        return UserData.model_validate(snap.to_dict())

    def save(self, user_id: str, data: UserData) -> None:
        self._doc(user_id).set(data.model_dump(mode="json"))

    def delete(self, user_id: str) -> None:
        self._doc(user_id).delete()
