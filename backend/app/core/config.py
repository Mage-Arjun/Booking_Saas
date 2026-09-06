from pydantic_settings import BaseSettings, SettingsConfigDict


class Settings(BaseSettings):
    model_config = SettingsConfigDict(env_file=".env", extra="ignore")

    app_name: str = "Booking SaaS"
    app_version: str = "0.1.0"
    debug: bool = False

    database_url: str
    secret_key: str
    jwt_algorithm: str = "HS256"
    access_token_expire_minutes: int = 30
    refresh_token_expire_days: int = 7
    allowed_origins: list[str] = ["http://localhost:3000"]

    # Email (Phase 1 - configured later)
    smtp_host: str | None = None
    smtp_port: int | None = None
    smtp_user: str | None = None
    smtp_password: str | None = None
    email_from: str = "noreply@booking.example.com"

    # Rate limiting (in-process sliding window initially)
    login_rate_limit_per_minute: int = 5
    register_rate_limit_per_minute: int = 3


settings = Settings()
