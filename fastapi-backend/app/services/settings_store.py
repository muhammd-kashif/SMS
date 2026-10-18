import json
from typing import Any, Optional

from sqlalchemy.orm import Session

from app.models.misc import Setting


DEFAULTS = {
    "college_name": "Smart College",
    "college_address": "",
    "college_phone": "",
    "college_email": "",
    "logo_path": None,
    "default_locale": "en",
    "password_min": "8",
    "grace_days": "3",
    "default_leave_allowance": "20",
    "late_fee_amount": "0",
    "payment_methods": ["cash", "bank", "online", "other"],
    "currency": "PKR",
    "currency_symbol": "Rs.",
    "academic_year": "",
    "result_pass_percentage": "40",
    "primary_color": "#1B4F9C",
    "secondary_color": "#F39200",
    "accent_color": "#F5A623",
    "sidebar_color": "#0E2A4A",
    "header_color": "#FFFDF8",
    "button_style": "rounded",
    "theme": "light",
}


class SettingsStore:
    def __init__(self, db: Session):
        self._db = db
        self._cache: Optional[dict] = None

    def _load(self) -> dict:
        if self._cache is None:
            rows = self._db.query(Setting).all()
            self._cache = {}
            for row in rows:
                try:
                    self._cache[row.key] = json.loads(row.value) if row.value else None
                except (json.JSONDecodeError, TypeError):
                    self._cache[row.key] = row.value
        return self._cache

    def get(self, key: str, default: Any = None) -> Any:
        data = self._load()
        if key in data and data[key] is not None:
            return data[key]
        return DEFAULTS.get(key, default)

    def merged(self) -> dict:
        data = self._load()
        result = dict(DEFAULTS)
        result.update({k: v for k, v in data.items() if v is not None})
        return result

    def branding(self) -> dict:
        m = self.merged()
        return {
            "college_name": m.get("college_name"),
            "college_address": m.get("college_address"),
            "college_phone": m.get("college_phone"),
            "college_email": m.get("college_email"),
            "logo_path": m.get("logo_path"),
            "logo_url": self._logo_url(m.get("logo_path")),
            "default_locale": m.get("default_locale", "en"),
            "currency": m.get("currency", "PKR"),
            "currency_symbol": m.get("currency_symbol", "Rs."),
            "academic_year": m.get("academic_year", ""),
            "primary_color": m.get("primary_color", "#1B4F9C"),
            "secondary_color": m.get("secondary_color", "#F39200"),
            "accent_color": m.get("accent_color", "#F5A623"),
            "sidebar_color": m.get("sidebar_color", "#0E2A4A"),
            "header_color": m.get("header_color", "#FFFDF8"),
            "button_style": m.get("button_style", "rounded"),
            "theme": m.get("theme", "light"),
            "favicon_url": self._logo_url(m.get("favicon_path")),
        }

    def _logo_url(self, path: Optional[str]) -> Optional[str]:
        if not path:
            return None
        from app.core.config import settings
        return f"{settings.APP_URL}/storage/{path}"

    def set(self, key: str, value: Any) -> None:
        serialized = json.dumps(value) if not isinstance(value, str) else value
        row = self._db.query(Setting).filter(Setting.key == key).first()
        if row:
            row.value = serialized
        else:
            self._db.add(Setting(key=key, value=serialized))
        self._db.commit()
        self._cache = None  # invalidate cache

    def bulk_update(self, data: dict) -> None:
        for key, value in data.items():
            self.set(key, value)
