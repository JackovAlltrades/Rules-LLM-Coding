import os
import subprocess
import sys
import argparse
import shutil
from pathlib import Path

# --- Configuration ---
# No longer need source_guide path here

# Define the chapters based on your file names for TOC generation
CHAPTER_FILES = [
    "00-Introduction.md",
    "1-Using-LLMs-Effectively-Safely-The-Core-Interaction-Loop.md",
    "2-Security-Non-Negotiable-Foundations.md",
    "3-Code-Quality-Maintainability.md",
    "4-Testing-Validation.md",
    "5-Performance-Efficiency.md",
    "6-Architecture-System-Design.md",
    "7-Frontend-UIUX-Accessibility.md",
    "8-DevOps-Infrastructure.md",
    "9-Specific-Technologies-Advanced-Topics.md",
]

# --- File Contents ---
# (GITIGNORE_CONTENT, GITATTRIBUTES_CONTENT, VSCODE_SETTINGS_CONTENT,
#  MARKDOWNLINT_CONFIG_CONTENT, README_CONTENT_TEMPLATE, SETUP_GUIDE_CONTENT
#  remain the *same* as in the V2 script - include them fully here)
# --- [PREVIOUS FILE CONTENTS GO HERE] ---
GITIGNORE_CONTENT = """
# Byte-compiled / optimized / DLL files
__pycache__/
*.py[cod]
*$py.class

# C extensions
*.so

# Distribution / packaging
.Python
build/
develop-eggs/
dist/
downloads/
eggs/
.eggs/
lib/
lib64/
parts/
sdist/
var/
wheels/
pip-wheel-metadata/
share/python-wheels/
*.egg-info/
.installed.cfg
*.egg
MANIFEST

# PyInstaller
#  Usually these files are written by a python script from a template
#  before PyInstaller builds the exe, so as to inject date/version info into it.
*.manifest
*.spec

# Installer logs
pip-log.txt
pip-delete-this-directory.txt

# Unit test / coverage reports
htmlcov/
.tox/
.nox/
.coverage
.coverage.*
.cache
nosetests.xml
coverage.xml
*.cover
*.py,cover
.hypothesis/
.pytest_cache/
cover/

# Translations
*.mo
*.pot

# Django stuff:
*.log
local_settings.py
db.sqlite3
db.sqlite3-journal

# Flask stuff:
instance/
.webassets-cache

# Scrapy stuff:
.scrapy

# Sphix documentation
docs/_build/

# Environments
.env
.venv
env/
venv/
ENV/
env.bak/
venv.bak/

# Spyder project settings
.spyderproject
.spyproject

# Rope project settings
.ropeproject

# mkdocs documentation
/site

# mypy
.mypy_cache/
.dmypy.json
dmypy.json

# Pyre type checker
.pyre/

# pytype static analysis results
.pytype/

# Cython debug symbols
cython_debug/

# VS Code
.vscode/*
!.vscode/settings.json
!.vscode/tasks.json
!.vscode/launch.json
!.vscode/extensions.json
*.code-workspace

# IDE specific files
.idea/
*.iml
*.ipr
*.iws

# OS generated files
.DS_Store
Thumbs.db

# Node modules (for linters etc)
node_modules/
npm-debug.log*
yarn-debug.log*
yarn-error.log*
package-lock.json # Often committed, but can ignore if desired
yarn.lock # Often committed, but can ignore if desired

# Markdown Lint
*.result.json
"""

GITATTRIBUTES_CONTENT = """
# Set default behavior for all files
* text=auto eol=lf

# Explicitly declare text files you want to always normalize and convert to LF
*.txt text eol=lf
*.md text eol=lf
*.py text eol=lf
*.js text eol=lf
*.json text eol=lf
*.jsonc text eol=lf
*.yaml text eol=lf
*.yml text eol=lf
*.sh text eol=lf
*.gitignore text eol=lf
*.gitattributes text eol=lf

# Declare files that will always have LF line endings on checkout
*.sh eol=lf

# Denote all files that are truly binary and should not be modified
*.png binary
*.jpg binary
*.jpeg binary
*.gif binary
*.pdf binary
"""

VSCODE_SETTINGS_CONTENT = """
{
  "editor.formatOnSave": true,
  "editor.defaultFormatter": "esbenp.prettier-vscode", // General purpose, works well for md
  "[markdown]": {
    "editor.defaultFormatter": "DavidAnson.vscode-markdownlint", // Specific Markdown formatter/linter
    "editor.wordWrap": "on",
    "editor.quickSuggestions": {
      "other": true,
      "comments": true,
      "strings": true
    }
  },
  "[python]": {
    "editor.defaultFormatter": "ms-python.black-formatter", // Or ruff, etc.
    "editor.formatOnSave": true,
    "editor.codeActionsOnSave": {
        "source.organizeImports": "explicit" // Consider using Ruff for this
    }
  },
  "files.eol": "\\n", // Ensure LF line endings
  "files.insertFinalNewline": true,
  "files.trimTrailingWhitespace": true,
  "search.exclude": {
    "**/node_modules": true,
    "**/bower_components": true,
    "**/*.code-search": true,
    "**/__pycache__": true,
    "**/.venv": true,
    "**/venv": true
  },
  "workbench.editor.untitled.hint": "hidden",
  "python.analysis.typeCheckingMode": "basic", // Or "strict"
  "python.linting.enabled": true, // General Python linting
  "python.linting.pylintEnabled": false, // Example: disable pylint if using ruff/flake8
  "python.linting.flake8Enabled": true, // Example: enable flake8
   // Consider adding Ruff settings if using ruff
  // "ruff.lint.args": [],
  // "ruff.format.args": [],
  // "[python]": {
  //   "editor.defaultFormatter": "charliermarsh.ruff",
  //   "editor.codeActionsOnSave": {
  //      "source.fixAll": true,
  //      "source.organizeImports": true
  //   }
  // },

  // Recommendations tie into settings
  "recommendations": [
    "ms-python.python",
    "ms-python.vscode-pylance", // Language server
    "ms-python.black-formatter", // Formatter
    "ms-python.flake8", // Linter (or use Ruff)
    // "charliermarsh.ruff", // Alternative Linter/Formatter
    "DavidAnson.vscode-markdownlint", // Markdown linting
    "yzhang.markdown-all-in-one", // Markdown utilities
    "bierner.markdown-preview-github-styles", // Preview
    "esbenp.prettier-vscode", // General formatter
    "gitHub.vscode-pull-request-github", // GitHub integration
    "eamodio.gitlens" // Git supercharger
  ]
}
"""

MARKDOWNLINT_CONFIG_CONTENT = """
{
  // Default markdownlint configuration
  "default": true,
  // Example: Disable line length rule (often debated)
  "MD013": false,
  // Example: Allow inline HTML (use with caution)
  "MD033": false,
  // Example: Allow duplicate headings in different sections
  "MD024": {
    "allow_different_nesting": true
  },
  // Enforce code block language specification
  "MD040": true,
  // No hard tabs
  "MD010": true,
  // Add other rules overrides as needed based on your style preferences
  // See https://github.com/DavidAnson/markdownlint/blob/main/schema/.markdownlint.jsonc
}
"""

README_CONTENT_TEMPLATE = """
# Rules-LLM-Coding Project

This repository serves as the central hub for the Master List of Rules (MLR) system designed to guide and automate best practices in LLM-assisted software development.

## Purpose

- **Centralize:** Provides a single source of truth for coding rules, broken down by topic.
- **Maintain:** Ensures the guide is version-controlled, reviewable, consistently formatted, and easy to navigate.
- **Automate:** Includes setup scripts and CI checks (Markdown linting) for maintainability.
- **Evolve:** Establishes a foundation to potentially add checklists, templates, and more complex tooling later.

## Structure (Current)

- `rules/`: Contains the core Master List Rule chapters as individual Markdown files (v1.0.7+).
- `docs/LLM_CODING_GUIDE.md`: An entry point/Table of Contents linking to the chapters in `rules/`.
- `docs/SETUP_GUIDE.md`: Instructions on setting up this repository locally and using the automation script.
- `scripts/setup_project.py`: Python script to automate local setup and standardization.
- `.vscode/`: Recommended VS Code settings (linting, formatting).
- `.github/workflows/`: GitHub Actions workflows (e.g., Markdown linting).
- `.markdownlint.jsonc`: Configuration for the Markdown linter.
- `.gitignore`, `.gitattributes`: Standard Git configuration files.
- `README.md`: This file - overview of the repository.
- `.venv/`: Python virtual environment directory (created locally, ignored by Git).

## Getting Started (for Maintainers)

1.  **Prerequisites:** Ensure Git, Python 3.8+, and Node.js (with npm) are installed. Using WSL on Windows is highly recommended.
2.  **Clone:** `git clone https://github.com/JackovAlltrades/Rules-LLM-Coding.git`
3.  **Navigate:** `cd Rules-LLM-Coding`
4.  **Run Setup Script (First Time / Updates):**
    *   Place the `setup_project.py` script in this directory (if not already present).
    *   Run it:
        ```bash
        python ./setup_project.py
        ```
    *   This sets up/updates `.venv`, config files, directories, and the Table of Contents file.
5.  **Activate Environment:** `source .venv/bin/activate`
6.  **Review & Commit:** Review the changes made by the script (`git status`, `git diff`), then stage and commit:
    ```bash
    git status
    git add .
    git commit -m "Initialize/Update project structure via setup script"
    ```
7.  **Push Branches:** Push `main` and `develop` (if newly created): `git push -u origin main develop`
8.  **Set Default Branch:** On GitHub, set the default branch to `develop`.
9.  **Work on `develop`:** `git checkout develop` for making changes (usually on feature branches).

## Navigating the Guide

Start with `docs/LLM_CODING_GUIDE.md` which links to each chapter in the `rules/` directory.

## Maintenance and Updates

*   **Guide Content:** Edit the individual `.md` files within the `rules/` directory.
*   **Workflow:** Use feature branches -> Pull Requests -> `develop` -> merge to `main` for releases.
*   **Automation:** The GitHub Action lints Markdown files in `rules/` and `docs/` on pushes/PRs.

## Future Expansions (Potential)

This structure can be expanded later to include:
- `checklists/`
- `templates/`
- `tools/` (Python utilities)
- `examples/`
"""

SETUP_GUIDE_CONTENT = """
# Project Setup Guide (for Maintainers)

This guide explains how to use the `setup_project.py` script to initialize or update the standard structure and configuration files within your local clone of the `Rules-LLM-Coding` repository.

**Run this script from the root directory of your cloned repository.**

## Prerequisites

1.  **Git:** Ensure Git is installed.
2.  **Python:** Ensure Python 3.8 or higher is installed.
3.  **Node.js & npm:** Ensure Node.js (includes npm) is installed (for Markdown linting setup).
4.  **WSL (Recommended):** Using Windows Subsystem for Linux (Ubuntu) is highly recommended.
5.  **Local Clone:** You must have already cloned the `https://github.com/JackovAlltrades/Rules-LLM-Coding.git` repository.
6.  **Guide Files:** The core guide content should exist as individual `.md` files inside a `rules/` subdirectory within your clone.

## Running the Setup Script

1.  **Place Script:** Make sure `setup_project.py` is in the root of your cloned `Rules-LLM-Coding` directory (e.g., `/mnt/c/MyProjects-25/Rules-LLM-Coding/`).
2.  **Open Terminal:** Open your terminal (WSL recommended) **inside** the `Rules-LLM-Coding` directory.
3.  **Run the Script:** Execute the script using Python. It no longer takes a `--source_guide` argument.

    ```bash
    # Make sure you are INSIDE the Rules-LLM-Coding directory
    python ./setup_project.py
    ```

## What the Script Does (Automation)

*   **Checks Prerequisites:** Verifies Git, Python, and npm.
*   **Validates Location:** Ensures it's running inside a Git repository and that the `rules/` directory exists.
*   **Creates Structure:** Creates missing directories (`docs`, `.vscode`, `scripts`, `.github/workflows`).
*   **Writes/Overwrites Configs:** Creates or **overwrites** common config/docs files (`.gitignore`, `.gitattributes`, `README.md`, `docs/SETUP_GUIDE.md`, `.vscode/settings.json`, `.markdownlint.jsonc`, `.github/workflows/markdown-lint.yml`) with standard versions. **Existing files *will* be replaced.**
*   **Generates TOC:** Creates/overwrites `docs/LLM_CODING_GUIDE.md` to act as a Table of Contents, linking to the files found in the `rules/` directory.
*   **Copies Itself:** Copies `setup_project.py` into the `scripts/` directory.
*   **Creates Virtual Env:** Creates `./.venv` if needed.
*   **Installs Lint Tool:** Attempts global install of `markdownlint-cli`.
*   **Creates `develop` Branch:** Creates the branch locally if it doesn't exist.

## Manual Steps After Running the Script

1.  **Activate Environment:** `source .venv/bin/activate`
2.  **Review Changes:** Use `git status` and `git diff` to see modified files. Verify the Table of Contents (`docs/LLM_CODING_GUIDE.md`) looks correct.
3.  **Stage and Commit:** `git add .` then `git commit -m "Apply standard project setup/update"`
4.  **Push Branches:** `git push -u origin main` and `git push -u origin develop`
5.  **Set Default Branch on GitHub:** Change default to `develop` via repository Settings > Branches.
6.  **Switch Locally:** `git checkout develop`

Now you are set up to maintain the guide chapters in the `rules/` directory using the recommended workflow.
"""

GITHUB_WORKFLOW_CONTENT = """
name: Lint Markdown Files

on:
  push:
    branches:
      - main
      - develop # Check pushes to develop
  pull_request:
    branches:
      - main
      - develop # Check PRs targeting main or develop

jobs:
  markdownlint:
    name: Run Markdownlint
    runs-on: ubuntu-latest
    steps:
      - name: Checkout code
        uses: actions/checkout@v4

      - name: Setup Node.js
        uses: actions/setup-node@v4
        with:
          node-version: '20' # Use a current LTS version

      - name: Install markdownlint-cli
        run: npm install -g markdownlint-cli # Install globally in the runner

      - name: Run linter on Guide Chapters and Docs
        # Check all .md files in rules/ and docs/ directories
        # Use glob pattern. ** matches directories recursively.
        run: markdownlint --config .markdownlint.jsonc "rules/**/*.md" "docs/**/*.md"
"""

# --- Helper Functions (Keep from previous version) ---
# run_command, check_prereq, create_file
def run_command(command, cwd=None, check=True):
    """Runs a command in the shell."""
    print(f"Running command: {' '.join(command)}")
    try:
        process = subprocess.run(command, cwd=cwd, check=check, capture_output=True, text=True, shell=sys.platform == "win32")
        # Only print stdout if it's not empty
        if process.stdout and process.stdout.strip():
            print(process.stdout)
        if process.stderr and "npm WARN" not in process.stderr and process.stderr.strip():
             print(f"Stderr: {process.stderr}", file=sys.stderr)
        return process.returncode == 0, process.stdout, process.stderr
    except subprocess.CalledProcessError as e:
        print(f"Error running command: {' '.join(command)}", file=sys.stderr)
        print(f"Return code: {e.returncode}", file=sys.stderr)
        if e.stdout and e.stdout.strip(): print(f"Output: {e.stdout}", file=sys.stderr)
        if e.stderr and e.stderr.strip(): print(f"Stderr: {e.stderr}", file=sys.stderr)
        if check: raise
        return False, e.stdout, e.stderr
    except FileNotFoundError:
        print(f"Error: Command not found - ensure '{command[0]}' is installed and in PATH.", file=sys.stderr)
        if check: raise
        return False, "", f"{command[0]} not found"
    except Exception as e: # Catch other potential errors
        print(f"Unexpected error running command {' '.join(command)}: {e}", file=sys.stderr)
        if check: raise
        return False, "", str(e)

def check_prereq(command):
    """Checks if a command exists."""
    print(f"Checking for {command[0]}...")
    try:
        subprocess.run(command, check=True, timeout=5, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL, shell=sys.platform == "win32")
        print(f"[OK] {command[0]} found.")
        return True
    except (subprocess.CalledProcessError, FileNotFoundError, subprocess.TimeoutExpired):
        print(f"[FAILED] {command[0]} not found or not executable. Please install it and ensure it's in your PATH.", file=sys.stderr)
        return False

def create_file(path, content=""):
    """Creates/Overwrites a file with given content."""
    try:
        path.parent.mkdir(parents=True, exist_ok=True)
        with open(path, 'w', encoding='utf-8', newline='\n') as f:
            f.write(content)
        print(f"Created/Updated: {path}")
    except OSError as e:
        print(f"Error creating/writing file {path}: {e}", file=sys.stderr)
        raise # Re-raise error to stop script
# --- [END OF HELPER FUNCTIONS] ---

# --- New Helper Function for TOC ---
def generate_toc_content(rules_dir: Path) -> str:
    """Generates Markdown Table of Contents linking to files in rules_dir."""
    toc = ["# LLM Coding Guide - Master Rules (v1.0.7+)", ""]
    toc.append("This document serves as the entry point and Table of Contents for the Master List of Rules (MLR) for LLM-Assisted Coding.")
    toc.append("The rules are broken down into chapters, located in the `../rules/` directory.")
    toc.append("")
    toc.append("## Chapters")
    toc.append("")

    found_files = []
    # Use the predefined order if files exist
    for filename in CHAPTER_FILES:
        file_path = rules_dir / filename
        if file_path.is_file():
            # Extract title-like part from filename
            title = filename.replace('.md', '').replace('-', ' ').replace('00', '').replace('0', '').replace('1', '1.').replace('2', '2.').replace('3', '3.').replace('4', '4.').replace('5', '5.').replace('6', '6.').replace('7', '7.').replace('8', '8.').replace('9', '9.').strip()
            # Create relative link for Markdown
            relative_link = f"../rules/{filename}"
            toc.append(f"*   [{title}]({relative_link})")
            found_files.append(filename)
        else:
            print(f"Warning: Expected chapter file not found: {file_path}", file=sys.stderr)

    # Optionally, list any other .md files found but not in the predefined list
    other_files = sorted([f.name for f in rules_dir.glob('*.md') if f.name not in found_files])
    if other_files:
        toc.append("")
        toc.append("### Other Files")
        for filename in other_files:
             title = filename.replace('.md', '').replace('-', ' ')
             relative_link = f"../rules/{filename}"
             toc.append(f"*   [{title}]({relative_link})")


    toc.append("")
    return "\n".join(toc)

# --- Main Setup Logic ---

def main():
    # Assume script is run from the root of the cloned repository
    project_path = Path.cwd()
    rules_dir = project_path / "rules" # Define rules directory path

    print("--- LLM Coding Guide Project Setup/Update (v3 - Chapter Files) ---")
    print(f"Running in: {project_path}")
    # Removed source_guide print

    # 1. Prerequisite Checks (Same as V2)
    print("\n--- Checking Prerequisites ---")
    python_ok = check_prereq([sys.executable, "--version"])
    git_ok = check_prereq(["git", "--version"])
    npm_ok = check_prereq(["npm", "--version"]) # For markdownlint-cli

    if not python_ok: sys.exit(1)
    if not git_ok:
        print("Error: Git command not found. Exiting.", file=sys.stderr)
        sys.exit(1)
    if not npm_ok:
        print("Warning: npm not found. Markdownlint checks/install will be skipped.", file=sys.stderr)


    # 2. Verify Running in a Git Repo & Rules Dir Exists
    print("\n--- Verifying Repository and 'rules/' Directory ---")
    if not (project_path / ".git").is_dir():
        print(f"Error: No '.git' directory found in {project_path}. Run script from repo root.", file=sys.stderr)
        sys.exit(1)
    if not rules_dir.is_dir():
        print(f"Error: 'rules/' directory not found in {project_path}. Ensure your chapter files are in a 'rules' subdirectory.", file=sys.stderr)
        sys.exit(1)
    print("[OK] Running inside a Git repository with 'rules/' directory present.")

    # 3. Create/Update Project Structure & Files (Same as V2, but ensures rules/ exists)
    print(f"\n--- Creating/Updating Project Structure & Files ---")
    (project_path / "docs").mkdir(exist_ok=True)
    (project_path / "scripts").mkdir(exist_ok=True)
    (project_path / ".vscode").mkdir(exist_ok=True)
    (project_path / ".github" / "workflows").mkdir(parents=True, exist_ok=True)
    print("Directory structure created/verified.")

    print("Creating/Overwriting standard configuration files...")
    create_file(project_path / ".gitignore", GITIGNORE_CONTENT)
    create_file(project_path / ".gitattributes", GITATTRIBUTES_CONTENT)
    create_file(project_path / ".vscode" / "settings.json", VSCODE_SETTINGS_CONTENT)
    create_file(project_path / ".markdownlint.jsonc", MARKDOWNLINT_CONFIG_CONTENT)
    create_file(project_path / "README.md", README_CONTENT_TEMPLATE) # Overwrites existing!
    create_file(project_path / "docs" / "SETUP_GUIDE.md", SETUP_GUIDE_CONTENT)
    create_file(project_path / ".github" / "workflows" / "markdown-lint.yml", GITHUB_WORKFLOW_CONTENT)

    # Copy this script into the project 'scripts' directory (Same as v2)
    try:
         self_script_path = Path(__file__).resolve()
         target_script_path = project_path / "scripts" / self_script_path.name
         # Only copy if it doesn't exist or is different (basic check)
         if not target_script_path.exists() or self_script_path.read_text() != target_script_path.read_text():
             shutil.copy2(self_script_path, target_script_path)
             print(f"Copied/Updated setup script to {target_script_path}")
    except Exception as e:
         print(f"Warning: Could not copy setup script: {e}", file=sys.stderr)


    # 4. Generate Table of Contents MD file
    print("\n--- Generating Table of Contents (docs/LLM_CODING_GUIDE.md) ---")
    guide_toc_path = project_path / "docs" / "LLM_CODING_GUIDE.md"
    try:
        toc_markdown = generate_toc_content(rules_dir)
        create_file(guide_toc_path, toc_markdown)
    except Exception as e:
        print(f"Error generating Table of Contents: {e}", file=sys.stderr)
        print("Warning: Failed to create/update docs/LLM_CODING_GUIDE.md", file=sys.stderr)

    # 5. Setup Python Virtual Environment (Same as V2)
    print("\n--- Setting up Python Virtual Environment (.venv) ---")
    venv_path = project_path / ".venv"
    if not venv_path.is_dir():
        print("'.venv' directory not found, creating...")
        success, _, _ = run_command([sys.executable, "-m", "venv", ".venv"], cwd=project_path)
        if success:
            print("[OK] Virtual environment '.venv' created.")
            print("--> Remember to activate it: source .venv/bin/activate ")
        else:
            print("Error: Failed to create virtual environment.", file=sys.stderr)
    else:
        print("[OK] Virtual environment '.venv' already exists.")
        print("--> Activate it if not already active: source .venv/bin/activate")


    # 6. Install Tools (MarkdownLint CLI) (Same as V2)
    if npm_ok:
        print("\n--- Attempting to Install/Update markdownlint-cli (Requires Node.js/npm) ---")
        success, _, stderr = run_command(["npm", "install", "-g", "markdownlint-cli"], check=False)
        if not success:
            if "checkPermissions" in stderr or "EACCES" in stderr :
                 print("Warning: Failed to install markdownlint-cli globally due to permissions. Try 'sudo npm install -g markdownlint-cli'.", file=sys.stderr)
            else:
                 print("Warning: Failed to install markdownlint-cli globally. Run 'npm install -g markdownlint-cli' manually.", file=sys.stderr)
        else:
            print("[OK] markdownlint-cli installed/updated globally.")
    else:
        print("\nSkipping markdownlint-cli installation (npm not found).")

    # 7. Ensure 'develop' Branch Exists (Same as V2)
    print("\n--- Ensuring 'develop' Branch Exists ---")
    success, stdout, _ = run_command(["git", "branch", "--list", "develop"], cwd=project_path, check=False)
    develop_exists = "develop" in stdout.strip()
    if not develop_exists:
        print("'develop' branch not found locally, creating...")
        success, _, _ = run_command(["git", "branch", "develop"], cwd=project_path)
        if success: print("[OK] 'develop' branch created.")
        else: print("Error: Failed to create 'develop' branch.", file=sys.stderr)
    else:
        print("[OK] 'develop' branch already exists locally.")

    print("\n--- Automated Setup Complete ---")
    print("\n>>> IMPORTANT MANUAL NEXT STEPS <<<")
    print(f"1. ACTIVATE VIRTUAL ENV: Run 'source .venv/bin/activate' in your terminal.")
    print(f"2. REVIEW CHANGES: Use 'git status' and 'git diff'. Verify 'docs/LLM_CODING_GUIDE.md' links correctly.")
    print(f"3. COMMIT CHANGES: Run 'git add .' then 'git commit -m \"Apply standard project setup/update (chapter structure)\"'")
    print(f"4. PUSH BRANCHES: Run 'git push -u origin main' AND 'git push -u origin develop'")
    print(f"5. SET DEFAULT BRANCH on GitHub to 'develop' (Settings -> Branches).")
    print(f"6. CHECKOUT DEVELOP LOCALLY: Run 'git checkout develop' to start working on guide chapters in 'rules/'.")

if __name__ == "__main__":
    # Remove argument parsing as source_guide is no longer needed
    # parser = argparse.ArgumentParser(...)
    # args = parser.parse_args()
    # main(args.source_guide.resolve()) # Old call

    main() # New call, doesn't need arguments