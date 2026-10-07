from functools import lru_cache

from .. import config
from .base import Repository


@lru_cache(maxsize=1)
def get_repository() -> Repository:
    if config.STORE == "firestore":
        from .firestore_store import FirestoreRepository

        return FirestoreRepository()
    from .local_store import LocalJsonRepository

    return LocalJsonRepository(config.DATA_DIR)
