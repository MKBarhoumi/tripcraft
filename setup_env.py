"""
TripCraft - Environment Setup Helper Script
Generates secure secrets and helps configure environment variables
"""

import secrets
import string
import os
from pathlib import Path


def generate_jwt_secret(length=64):
    """Generate a secure random hex string for JWT secret"""
    return secrets.token_hex(length)


def generate_random_password(length=32):
    """Generate a secure random password"""
    alphabet = string.ascii_letters + string.digits + "!@#$%^&*"
    return ''.join(secrets.choice(alphabet) for _ in range(length))


def create_env_file():
    """Create .env file from template with generated secrets"""
    
    print("🔧 TripCraft Environment Setup Helper\n")
    print("=" * 60)
    
    # Generate secrets
    jwt_secret = generate_jwt_secret()
    
    print("\n✅ Generated Secrets:")
    print("-" * 60)
    print(f"JWT_SECRET: {jwt_secret}")
    print("-" * 60)
    
    # Get user inputs
    print("\n📝 Please provide the following information:")
    print("(Press Enter to use default values where applicable)\n")
    
    supabase_url = input("Supabase URL (https://xyz.supabase.co): ").strip()
    supabase_key = input("Supabase Service Key: ").strip()
    database_url = input("Database URL (postgresql://...): ").strip()
    groq_api_key = input("Groq API Key (gsk_...): ").strip()
    
    # Optional settings
    print("\n⚙️  Optional Settings (press Enter for defaults):")
    environment = input("Environment (development/staging/production) [development]: ").strip() or "development"
    port = input("Server Port [8000]: ").strip() or "8000"
    
    # Create .env content
    env_content = f"""# ===========================
# TripCraft Backend - Environment Variables
# ===========================
# Generated: {os.popen('date').read().strip()}
# KEEP THIS FILE SECRET - DO NOT COMMIT TO GIT!

# ===========================
# Database Configuration
# ===========================
DATABASE_URL={database_url}

# ===========================
# Supabase Configuration
# ===========================
SUPABASE_URL={supabase_url}
SUPABASE_SERVICE_KEY={supabase_key}

# ===========================
# JWT Configuration
# ===========================
JWT_SECRET={jwt_secret}
JWT_ALGORITHM=HS256
JWT_EXPIRATION_HOURS=24

# ===========================
# Groq AI Configuration
# ===========================
GROQ_API_KEY={groq_api_key}
GROQ_MODEL=mixtral-8x7b-32768
GROQ_MAX_TOKENS=4096
GROQ_TEMPERATURE=0.7

# ===========================
# PDF Export Configuration
# ===========================
PDF_TEMP_PATH=/tmp
PDF_STORAGE_BUCKET=trip-pdfs

# ===========================
# Rate Limiting
# ===========================
RATE_LIMIT_GENERATE_PER_DAY=30
RATE_LIMIT_REFINE_PER_DAY=100
RATE_LIMIT_EXPORT_PER_DAY=50

# ===========================
# Caching Configuration
# ===========================
CACHE_ENABLED=true
CACHE_TTL_SECONDS=1800
CACHE_MAX_SIZE=1000

# ===========================
# Optional: Vector Search
# ===========================
PGVECTOR_ENABLED=false

# ===========================
# Server Configuration
# ===========================
HOST=0.0.0.0
PORT={port}
WORKERS=4
RELOAD=true

# ===========================
# CORS Configuration
# ===========================
ALLOWED_ORIGINS=http://localhost:3000,http://localhost:8080
CORS_ALLOW_CREDENTIALS=true

# ===========================
# Environment
# ===========================
ENVIRONMENT={environment}
DEBUG={"true" if environment == "development" else "false"}
LOG_LEVEL=INFO
"""
    
    # Write to file
    backend_dir = Path(__file__).parent / "tripcraft-backend"
    backend_dir.mkdir(exist_ok=True)
    
    env_file = backend_dir / ".env"
    
    if env_file.exists():
        overwrite = input(f"\n⚠️  .env file already exists. Overwrite? (y/N): ").strip().lower()
        if overwrite != 'y':
            print("\n❌ Setup cancelled. Existing .env file preserved.")
            return
    
    with open(env_file, 'w') as f:
        f.write(env_content)
    
    print(f"\n✅ Environment file created: {env_file}")
    print("\n" + "=" * 60)
    print("🎉 Setup Complete!")
    print("=" * 60)
    print("\n📋 Next Steps:")
    print("1. Review and verify your .env file")
    print("2. Ensure Supabase database schema is deployed")
    print("3. Create storage bucket 'trip-pdfs' in Supabase")
    print("4. Start the backend: uvicorn app.main:app --reload")
    print("\n⚠️  IMPORTANT: Never commit .env to version control!")
    print("=" * 60)


def validate_env_file():
    """Validate existing .env file"""
    
    backend_dir = Path(__file__).parent / "tripcraft-backend"
    env_file = backend_dir / ".env"
    
    if not env_file.exists():
        print("❌ .env file not found!")
        print(f"Expected location: {env_file}")
        return False
    
    print("🔍 Validating .env file...\n")
    
    required_vars = [
        'DATABASE_URL',
        'SUPABASE_URL',
        'SUPABASE_SERVICE_KEY',
        'JWT_SECRET',
        'GROQ_API_KEY'
    ]
    
    missing = []
    found = []
    
    with open(env_file, 'r') as f:
        content = f.read()
        for var in required_vars:
            if f"{var}=" in content:
                # Check if it has a value (not just the template placeholder)
                line = [l for l in content.split('\n') if l.startswith(f"{var}=")]
                if line and '=' in line[0]:
                    value = line[0].split('=', 1)[1].strip()
                    if value and not value.startswith('your-') and not value.startswith('generate-'):
                        found.append(var)
                    else:
                        missing.append(var)
                else:
                    missing.append(var)
            else:
                missing.append(var)
    
    print("✅ Found:")
    for var in found:
        print(f"  - {var}")
    
    if missing:
        print("\n⚠️  Missing or not configured:")
        for var in missing:
            print(f"  - {var}")
        print("\nPlease update these values in your .env file.")
        return False
    
    print("\n✅ All required environment variables are configured!")
    return True


def main():
    """Main entry point"""
    
    print("\n" + "=" * 60)
    print("  TripCraft Environment Setup Helper")
    print("=" * 60)
    print("\nChoose an option:")
    print("1. Create new .env file with generated secrets")
    print("2. Validate existing .env file")
    print("3. Just generate a JWT secret")
    print("4. Exit")
    
    choice = input("\nEnter your choice (1-4): ").strip()
    
    if choice == '1':
        create_env_file()
    elif choice == '2':
        validate_env_file()
    elif choice == '3':
        secret = generate_jwt_secret()
        print(f"\n🔑 Generated JWT Secret:\n{secret}")
        print("\nAdd this to your .env file as JWT_SECRET")
    elif choice == '4':
        print("\n👋 Goodbye!")
    else:
        print("\n❌ Invalid choice!")


if __name__ == "__main__":
    main()
