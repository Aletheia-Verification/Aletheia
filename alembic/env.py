"""
env.py — Alembic Environment Configuration for Aletheia Beyond
==============================================================

Supports both sync and async migration execution.
Reads DATABASE_URL from environment variables.
"""

import asyncio
import os
from logging.config import fileConfig

from alembic import context
from dotenv import load_dotenv
from sqlalchemy import pool
from sqlalchemy.engine import Connection
from sqlalchemy.ext.asyncio import async_engine_from_config

# Load environment variables
load_dotenv()

# Alembic Config object
config = context.config

# Interpret the config file for Python logging
if config.config_file_name is not None:
    fileConfig(config.config_file_name)

# Import models for autogenerate support
from database import Base
from models import User, SecurityEvent, AnalysisSession, ChatMessage

target_metadata = Base.metadata

# ──────────────────────────────────────────────────────────────────────
# DATABASE URL CONFIGURATION
# ──────────────────────────────────────────────────────────────────────

def get_url() -> str:
    """Get database URL from environment."""
    return os.getenv(
        "DATABASE_URL",
        "postgresql+asyncpg://postgres:postgres@localhost:5432/aletheia"
    )


# ──────────────────────────────────────────────────────────────────────
# OFFLINE MIGRATIONS (Generate SQL scripts)
# ──────────────────────────────────────────────────────────────────────

def run_migrations_offline() -> None:
    """
    Run migrations in 'offline' mode.

    Generates SQL script instead of executing against the database.
    Useful for reviewing changes before applying.
    """
    url = get_url()
    context.configure(
        url=url,
        target_metadata=target_metadata,
        literal_binds=True,
        dialect_opts={"paramstyle": "named"},
    )

    with context.begin_transaction():
        context.run_migrations()


# ──────────────────────────────────────────────────────────────────────
# ONLINE MIGRATIONS (Execute against database)
# ──────────────────────────────────────────────────────────────────────

def do_run_migrations(connection: Connection) -> None:
    """Execute migrations against a connection."""
    context.configure(
        connection=connection,
        target_metadata=target_metadata,
    )

    with context.begin_transaction():
        context.run_migrations()


async def run_async_migrations() -> None:
    """
    Run migrations using async engine.

    Creates async engine, runs migrations, then disposes.
    """
    configuration = config.get_section(config.config_ini_section) or {}
    configuration["sqlalchemy.url"] = get_url()

    connectable = async_engine_from_config(
        configuration,
        prefix="sqlalchemy.",
        poolclass=pool.NullPool,
    )

    async with connectable.connect() as connection:
        await connection.run_sync(do_run_migrations)

    await connectable.dispose()


def run_migrations_online() -> None:
    """
    Run migrations in 'online' mode.

    Executes migrations directly against the database.
    """
    asyncio.run(run_async_migrations())


# ──────────────────────────────────────────────────────────────────────
# ENTRY POINT
# ──────────────────────────────────────────────────────────────────────

if context.is_offline_mode():
    run_migrations_offline()
else:
    run_migrations_online()
