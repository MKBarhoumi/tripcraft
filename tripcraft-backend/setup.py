"""
Setup script for TripCraft Backend
Helps with initial configuration and database setup
"""

import subprocess
import sys
import os
from pathlib import Path


def check_python_version():
    """Check if Python version is 3.11+"""
    version = sys.version_info
    if version.major < 3 or (version.major == 3 and version.minor < 11):
        print(f"❌ Python 3.11+ required. Current version: {version.major}.{version.minor}")
        return False
    print(f"✅ Python {version.major}.{version.minor}.{version.micro}")
    return True


def check_env_file():
    """Check if .env file exists"""
    env_path = Path(__file__).parent / ".env"
    if not env_path.exists():
        print("❌ .env file not found")
        print("   Copy .env.example to .env and fill in your credentials:")
        print("   cp .env.example .env")
        return False
    print("✅ .env file exists")
    return True


def install_dependencies():
    """Install Python dependencies"""
    print("\n📦 Installing dependencies...")
    try:
        subprocess.run(
            [sys.executable, "-m", "pip", "install", "-r", "requirements.txt"],
            check=True,
            capture_output=True
        )
        print("✅ Dependencies installed")
        return True
    except subprocess.CalledProcessError as e:
        print(f"❌ Failed to install dependencies: {e}")
        return False


def check_alembic():
    """Check if alembic is available"""
    try:
        subprocess.run(
            ["alembic", "--version"],
            check=True,
            capture_output=True
        )
        print("✅ Alembic available")
        return True
    except (subprocess.CalledProcessError, FileNotFoundError):
        print("❌ Alembic not available")
        return False


def create_migration():
    """Create initial database migration"""
    print("\n🔄 Creating initial migration...")
    try:
        # Create migration
        subprocess.run(
            ["alembic", "revision", "--autogenerate", "-m", "Initial schema"],
            check=True
        )
        print("✅ Migration created")
        return True
    except subprocess.CalledProcessError as e:
        print(f"❌ Failed to create migration: {e}")
        return False


def apply_migration():
    """Apply database migrations"""
    print("\n🔄 Applying migrations...")
    try:
        subprocess.run(
            ["alembic", "upgrade", "head"],
            check=True
        )
        print("✅ Migrations applied")
        return True
    except subprocess.CalledProcessError as e:
        print(f"❌ Failed to apply migrations: {e}")
        print("   Make sure your DATABASE_URL in .env is correct")
        return False


def main():
    """Main setup function"""
    print("=" * 50)
    print("🌍 TripCraft Backend Setup")
    print("=" * 50)
    
    # Check Python version
    if not check_python_version():
        sys.exit(1)
    
    # Check .env file
    if not check_env_file():
        sys.exit(1)
    
    # Install dependencies
    print("\nDo you want to install dependencies? (y/n): ", end="")
    if input().lower() == 'y':
        if not install_dependencies():
            sys.exit(1)
    
    # Check alembic
    if not check_alembic():
        print("   Try installing with: pip install alembic")
        sys.exit(1)
    
    # Create and apply migrations
    print("\nDo you want to create and apply database migrations? (y/n): ", end="")
    if input().lower() == 'y':
        if not create_migration():
            sys.exit(1)
        if not apply_migration():
            sys.exit(1)
    
    print("\n" + "=" * 50)
    print("✅ Setup complete!")
    print("=" * 50)
    print("\n🚀 Start the server with:")
    print("   uvicorn app.main:app --reload")
    print("\n📚 API docs will be available at:")
    print("   http://localhost:8000/docs")


if __name__ == "__main__":
    main()
