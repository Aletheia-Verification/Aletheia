"""
database.py — Async SQLAlchemy Database Connection Manager
==========================================================

Provides:
    - Async engine configuration
    - Session factory
    - Dependency injection for FastAPI
    - Connection pooling (5 min, 20 max)
"""

from __future__ import annotations

import os
from typing import AsyncGenerator

from sqlalchemy.ext.asyncio import (
    AsyncSession,
    async_sessionmaker,
    create_async_engine,
)
from sqlalchemy.orm import declarative_base

# ──────────────────────────────────────────────────────────────────────
# DATABASE URL CONFIGURATION
# ──────────────────────────────────────────────────────────────────────

DATABASE_URL = os.getenv(
    "DATABASE_URL",
    "postgresql+asyncpg://postgres:postgres@localhost:5432/aletheia"
)

# Detect SQLite for development fallback
IS_SQLITE = DATABASE_URL.startswith("sqlite")

# ──────────────────────────────────────────────────────────────────────
# ENGINE CONFIGURATION
# ──────────────────────────────────────────────────────────────────────

if IS_SQLITE:
    # SQLite async requires check_same_thread=False
    engine = create_async_engine(
        DATABASE_URL,
        echo=False,
        connect_args={"check_same_thread": False},
    )
else:
    # PostgreSQL with connection pooling
    engine = create_async_engine(
        DATABASE_URL,
        echo=False,
        pool_size=5,
        max_overflow=20,
        pool_pre_ping=True,
    )

# ──────────────────────────────────────────────────────────────────────
# SESSION FACTORY
# ──────────────────────────────────────────────────────────────────────

AsyncSessionLocal = async_sessionmaker(
    engine,
    class_=AsyncSession,
    expire_on_commit=False,
)

# ──────────────────────────────────────────────────────────────────────
# BASE CLASS FOR MODELS
# ──────────────────────────────────────────────────────────────────────

Base = declarative_base()


# ──────────────────────────────────────────────────────────────────────
# DEPENDENCY INJECTION
# ──────────────────────────────────────────────────────────────────────

async def get_db() -> AsyncGenerator[AsyncSession, None]:
    """
    FastAPI dependency that provides a database session.

    Usage:
        @app.get("/endpoint")
        async def endpoint(db: AsyncSession = Depends(get_db)):
            ...
    """
    async with AsyncSessionLocal() as session:
        try:
            yield session
            await session.commit()
        except Exception:
            await session.rollback()
            raise


# ──────────────────────────────────────────────────────────────────────
# LIFECYCLE FUNCTIONS
# ──────────────────────────────────────────────────────────────────────

async def init_db() -> None:
    """
    Create all tables. Call once at startup.

    Note: In production, use Alembic migrations instead.
    """
    async with engine.begin() as conn:
        await conn.run_sync(Base.metadata.create_all)


async def close_db() -> None:
    """Close connection pool. Call at shutdown."""
    await engine.dispose()
