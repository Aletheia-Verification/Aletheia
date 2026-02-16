"""
seed_db.py — Database Seeder for Aletheia Beyond
================================================

Creates the pre-approved admin account and optionally demo data.

Usage:
    python seed_db.py              # Seed admin only
    python seed_db.py --demo       # Seed admin + demo users
    python seed_db.py --reset      # Drop all, recreate, seed
"""

from __future__ import annotations

import asyncio
import argparse
import sys

from passlib.context import CryptContext

# Password hashing — same configuration as core_logic.py
password_hasher = CryptContext(schemes=["pbkdf2_sha256"], deprecated="auto")


async def seed_admin(session_factory, User, select) -> None:
    """Create the pre-approved admin account."""
    async with session_factory() as session:
        # Check if admin exists
        result = await session.execute(
            select(User).where(User.username == "admin")
        )
        existing = result.scalar_one_or_none()

        if existing:
            print("  Admin account already exists.")
            return

        admin = User(
            username="admin",
            password_hash=password_hasher.hash("admin123"),
            institution="Aletheia Global",
            city="London",
            country="UK",
            role="Chief Architect",
            is_approved=True,
        )
        session.add(admin)
        await session.commit()
        print("  [OK] Admin account created (admin / admin123)")


async def seed_demo_users(session_factory, User, select) -> None:
    """Create demo users for testing."""
    demo_users = [
        {
            "username": "analyst",
            "password": "analyst123",
            "institution": "Demo Bank",
            "city": "New York",
            "country": "US",
            "role": "COBOL Analyst",
            "is_approved": True,
        },
        {
            "username": "pending",
            "password": "pending123",
            "institution": "Test Corp",
            "city": "Berlin",
            "country": "DE",
            "role": "Developer",
            "is_approved": False,
        },
    ]

    async with session_factory() as session:
        for user_data in demo_users:
            result = await session.execute(
                select(User).where(User.username == user_data["username"])
            )
            if result.scalar_one_or_none():
                print(f"  {user_data['username']} already exists, skipping.")
                continue

            user = User(
                username=user_data["username"],
                password_hash=password_hasher.hash(user_data["password"]),
                institution=user_data["institution"],
                city=user_data["city"],
                country=user_data["country"],
                role=user_data["role"],
                is_approved=user_data["is_approved"],
            )
            session.add(user)
            print(f"  [OK] Created {user_data['username']}")

        await session.commit()


async def reset_database(engine, Base) -> None:
    """Drop all tables and recreate."""
    async with engine.begin() as conn:
        await conn.run_sync(Base.metadata.drop_all)
        await conn.run_sync(Base.metadata.create_all)
    print("  [OK] Database reset complete.")


async def init_tables(engine, Base) -> None:
    """Create all tables if they don't exist."""
    async with engine.begin() as conn:
        await conn.run_sync(Base.metadata.create_all)
    print("  [OK] Tables created/verified.")


async def main() -> None:
    parser = argparse.ArgumentParser(
        description="Seed the Aletheia database",
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog="""
Examples:
    python seed_db.py              # Create admin account only
    python seed_db.py --demo       # Create admin + demo users
    python seed_db.py --reset      # Reset DB and seed admin
    python seed_db.py --reset --demo   # Reset DB and seed all
        """,
    )
    parser.add_argument(
        "--demo",
        action="store_true",
        help="Include demo users (analyst, pending)",
    )
    parser.add_argument(
        "--reset",
        action="store_true",
        help="Drop all tables and recreate before seeding",
    )
    args = parser.parse_args()

    # Import database components
    try:
        from database import engine, Base, AsyncSessionLocal
        from models import User
        from sqlalchemy import select
    except ImportError as e:
        print(f"Error: Could not import database modules: {e}")
        print("Make sure you have installed the required dependencies:")
        print("    pip install -r requirements.txt")
        sys.exit(1)

    print("\n" + "=" * 60)
    print("  ALETHEIA BEYOND — Database Seeder")
    print("=" * 60 + "\n")

    if args.reset:
        print("[1/3] Resetting database...")
        await reset_database(engine, Base)
    else:
        print("[1/3] Initializing tables...")
        await init_tables(engine, Base)

    print("[2/3] Seeding admin account...")
    await seed_admin(AsyncSessionLocal, User, select)

    if args.demo:
        print("[3/3] Seeding demo users...")
        await seed_demo_users(AsyncSessionLocal, User, select)
    else:
        print("[3/3] Demo users skipped (use --demo to include)")

    # Cleanup
    await engine.dispose()

    print("\n" + "-" * 60)
    print("  Database seeding complete.")
    print("-" * 60 + "\n")


if __name__ == "__main__":
    asyncio.run(main())
