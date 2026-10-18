from typing import Optional

import httpx

from app.core.config import settings


class FaceClient:
    def __init__(self):
        self.base_url = settings.FACE_SERVICE_URL.rstrip("/")

    async def health(self) -> dict:
        async with httpx.AsyncClient(timeout=10.0) as client:
            response = await client.get(f"{self.base_url}/health")
            return response.json()

    async def register(self, person_type: str, person_id: int, image_bytes: bytes) -> dict:
        async with httpx.AsyncClient(timeout=30.0) as client:
            response = await client.post(
                f"{self.base_url}/register",
                files={"image": ("photo.jpg", image_bytes, "image/jpeg")},
                data={"person_type": person_type, "person_id": str(person_id)},
            )
            response.raise_for_status()
            return response.json()

    async def scan(self, image_bytes: bytes) -> dict:
        async with httpx.AsyncClient(timeout=30.0) as client:
            response = await client.post(
                f"{self.base_url}/scan",
                files={"image": ("scan.jpg", image_bytes, "image/jpeg")},
            )
            response.raise_for_status()
            return response.json()

    async def look(self, image_bytes: bytes, person_type: str, person_id: int) -> dict:
        async with httpx.AsyncClient(timeout=30.0) as client:
            response = await client.post(
                f"{self.base_url}/look",
                files={"image": ("look.jpg", image_bytes, "image/jpeg")},
                data={"person_type": person_type, "person_id": str(person_id)},
            )
            response.raise_for_status()
            return response.json()

    async def sync(self) -> dict:
        async with httpx.AsyncClient(timeout=60.0) as client:
            response = await client.post(f"{self.base_url}/sync")
            response.raise_for_status()
            return response.json()
