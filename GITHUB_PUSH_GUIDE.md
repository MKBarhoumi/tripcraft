# 🚀 Publishing to GitHub - Instructions

Follow these steps to push your TripCraft project to GitHub:

---

## ✅ Prerequisites Check

Before pushing to GitHub, ensure:

- [x] Git is installed on your system
- [x] You have a GitHub account
- [x] All sensitive files are properly excluded (.env files)
- [x] Project is ready to share

---

## 📝 Step 1: Install Git (if not already installed)

### Windows
Download and install Git from: https://git-scm.com/download/win

Or use winget:
```powershell
winget install --id Git.Git -e --source winget
```

### Verify Installation
After installing, restart VS Code and run:
```bash
git --version
```

---

## 🔐 Step 2: Configure Git

Set your name and email (used in commits):

```bash
git config --global user.name "Your Name"
git config --global user.email "your.email@example.com"
```

---

## 📦 Step 3: Initialize Git Repository

```bash
# Navigate to your project root
cd "E:\EPI\3eme\Sem 1\Mobile Development\final_project"

# Initialize git repository
git init

# Add all files to git
git add .

# Create initial commit
git commit -m "Initial commit: TripCraft - AI-Powered Travel App"
```

---

## 🌐 Step 4: Create GitHub Repository

1. Go to https://github.com
2. Click the **"+"** icon → **"New repository"**
3. Fill in:
   - **Repository name**: `tripcraft` (or your preferred name)
   - **Description**: "AI-Powered Travel Itinerary App - Flutter & FastAPI"
   - **Visibility**: Public (so others can clone and run)
   - **DO NOT** check "Initialize with README" (we already have one)
4. Click **"Create repository"**

---

## 🔗 Step 5: Connect and Push to GitHub

GitHub will show you commands. Use these:

```bash
# Add remote repository (replace YOUR_USERNAME with your GitHub username)
git remote add origin https://github.com/YOUR_USERNAME/tripcraft.git

# Verify remote is added
git remote -v

# Push to GitHub
git branch -M main
git push -u origin main
```

**Enter your GitHub credentials when prompted.**

---

## 🔑 Step 6: Setup GitHub Authentication (if needed)

If you encounter authentication issues, use a **Personal Access Token**:

1. Go to GitHub → **Settings** → **Developer settings** → **Personal access tokens** → **Tokens (classic)**
2. Click **"Generate new token"** → **"Generate new token (classic)"**
3. Set:
   - **Note**: "TripCraft Git Access"
   - **Expiration**: 90 days (or as needed)
   - **Scopes**: Check `repo` (all sub-options)
4. Click **"Generate token"**
5. **Copy the token** (you won't see it again!)
6. When pushing, use the token as your password

---

## ✨ Step 7: Verify Everything is Pushed

Visit your GitHub repository:
```
https://github.com/YOUR_USERNAME/tripcraft
```

You should see:
- ✅ All project files
- ✅ README.md displayed on the homepage
- ✅ SETUP_GUIDE.md visible
- ✅ Both `tripcraft_app/` and `tripcraft-backend/` folders
- ✅ `.env.example` files (but NOT `.env` files)

---

## 🎯 Step 8: Test the Setup Instructions

To ensure others can run your project:

1. Clone your repo in a different location:
   ```bash
   git clone https://github.com/YOUR_USERNAME/tripcraft.git test-clone
   cd test-clone
   ```

2. Follow the [SETUP_GUIDE.md](./SETUP_GUIDE.md) instructions

3. Verify everything works

---

## 📋 Future Updates

When you make changes to your project:

```bash
# Check what changed
git status

# Add specific files
git add path/to/file

# Or add all changes
git add .

# Commit with a descriptive message
git commit -m "Description of changes"

# Push to GitHub
git push
```

---

## 🔒 Security Checklist

Before pushing, ensure these files are **NOT** in your repository:

- ❌ `.env` files with real credentials
- ❌ API keys or secrets
- ❌ Database passwords
- ❌ Private keys or certificates

These should be in your repository:

- ✅ `.env.example` (template with placeholders)
- ✅ `.gitignore` (excluding sensitive files)
- ✅ README.md
- ✅ SETUP_GUIDE.md
- ✅ All source code

You can verify with:
```bash
# Check what will be pushed
git ls-files

# Ensure .env is NOT listed
git ls-files | grep "\.env$"
# Should return nothing (or only .env.example)
```

---

## 📢 Share Your Project

Once pushed, share your repository URL:
```
https://github.com/YOUR_USERNAME/tripcraft
```

Add it to:
- Your portfolio
- LinkedIn projects
- Resume
- School submissions

---

## 🎉 You're Done!

Your project is now:
- ✅ Published on GitHub
- ✅ Accessible to anyone
- ✅ Ready to be cloned and run by others
- ✅ Portfolio-ready

Anyone can now:
1. Clone your repository
2. Follow SETUP_GUIDE.md
3. Run the full application

---

**Questions?** Check the troubleshooting section in [SETUP_GUIDE.md](./SETUP_GUIDE.md)
