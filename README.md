
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
