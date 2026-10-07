"""Storage interface. The rest of the app only talks to `Repository`."""
from abc import ABC, abstractmethod

from ..models import UserData


class Repository(ABC):
    @abstractmethod
    def load(self, user_id: str) -> UserData:
        """Return the user's data (an empty UserData if the user is new)."""

    @abstractmethod
    def save(self, user_id: str, data: UserData) -> None:
        ...

    @abstractmethod
    def delete(self, user_id: str) -> None:
        ...
