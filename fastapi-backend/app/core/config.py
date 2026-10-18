from pydantic_settings import BaseSettings
from typing import Optional


class Settings(BaseSettings):
    APP_NAME: str = "Smart College"
    APP_ENV: str = "local"
    APP_DEBUG: bool = True
    APP_URL: str = "http://127.0.0.1:8000"
    SECRET_KEY: str = "change-this-to-a-random-secret-key"
    ALGORITHM: str = "HS256"
    ACCESS_TOKEN_EXPIRE_MINUTES: int = 10080  # 7 days

    DB_CONNECTION: str = "mysql"
    DB_HOST: str = "127.0.0.1"
    DB_PORT: int = 3306
    DB_DATABASE: str = "sms_college"
    DB_USERNAME: str = "root"
    DB_PASSWORD: str = ""

    STORAGE_PATH: str = "storage/app/public"
    FACE_SERVICE_URL: str = "http://127.0.0.1:8001"
    DEFAULT_LOCALE: str = "en"
    PASSWORD_MIN: int = 8
    DEFAULT_LEAVE_ALLOWANCE: int = 20
    GRACE_DAYS: int = 3

    @property
    def DATABASE_URL(self) -> str:
        if self.DB_CONNECTION == "sqlite":
            return f"sqlite:///{self.DB_DATABASE}.sqlite3"
        return (
            f"mysql+pymysql://{self.DB_USERNAME}:{self.DB_PASSWORD}"
            f"@{self.DB_HOST}:{self.DB_PORT}/{self.DB_DATABASE}"
            f"?charset=utf8mb4"
        )

    model_config = {"env_file": ".env", "extra": "ignore"}


settings = Settings()
