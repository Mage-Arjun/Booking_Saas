from contextlib import asynccontextmanager

from fastapi import FastAPI
from fastapi.exceptions import RequestValidationError
from fastapi.middleware.cors import CORSMiddleware

from app.core.config import settings
from app.core.exceptions import (
    AppError,
    AppValidationError,
    app_error_handler,
    http_exception_handler,
    validation_error_handler,
)
from app.core.logging import logger
from app.routers import auth, health, organizations, providers


@asynccontextmanager
async def lifespan(app: FastAPI):
    logger.info("app.startup", app_name=settings.app_name, version=settings.app_version)
    yield
    logger.error("app.shutdown")


def create_app() -> FastAPI:
    app = FastAPI(
        title=settings.app_name,
        version=settings.app_version,
        debug=settings.debug,
        lifespan=lifespan,
    )

    app.add_middleware(
        CORSMiddleware,
        allow_origins=settings.allowed_origins,
        allow_credentials=True,
        allow_methods=["*"],
        allow_headers=["*"],
    )

    app.add_exception_handler(AppError, app_error_handler)  # type: ignore[arg-type]
    app.add_exception_handler(AppValidationError, app_error_handler)  # type: ignore[arg-type]
    app.add_exception_handler(Exception, http_exception_handler)  # type: ignore[arg-type]
    app.add_exception_handler(RequestValidationError, validation_error_handler)  # type: ignore[arg-type]

    app.include_router(health.router)
    app.include_router(auth.router)
    app.include_router(organizations.router)
    app.include_router(providers.router)

    return app


app = create_app()
