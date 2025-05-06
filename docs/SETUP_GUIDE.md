
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
