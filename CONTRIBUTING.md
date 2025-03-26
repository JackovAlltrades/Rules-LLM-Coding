# Contributing to Rules-LLM-Coding

Thank you for your interest in contributing to the Master List of Rules (MLR) project! We welcome contributions that help improve the quality, clarity, and usefulness of these guidelines and the supporting tools.

## How to Contribute

There are several ways you can contribute:

*   **Reporting Issues:** If you find errors, inconsistencies, or areas for improvement in the rules, checklists, scripts, or documentation, please [open an issue](https://github.com/JackovAlltrades/Rules-LLM-Coding/issues). Please check existing issues first to avoid duplicates. Use descriptive titles and provide as much detail as possible. Consider using labels like `bug`, `enhancement`, `documentation`, or `question`.
*   **Suggesting New Rules or Changes:** To propose new rules, significant changes to existing ones, or modifications to the structure, please [open an issue](https://github.com/JackovAlltrades/Rules-LLM-Coding/issues) first to discuss the proposal. This allows for discussion before significant work is done.
*   **Submitting Pull Requests:** For fixes (like typos, broken links), improvements to existing rules/checklists, adding examples, or developing scripts/tools, please submit a Pull Request (PR).

## Pull Request Process

1.  **Fork the Repository:** Create your own copy of the repository on GitHub.
2.  **Create a Branch:** Create a new branch in your fork for your changes. Use a descriptive name (e.g., `fix/typo-in-rule-2-1`, `feat/add-python-example-3-5`, `docs/clarify-readme`).
    ```bash
    git checkout -b your-branch-name
    ```
3.  **Make Changes:** Edit or add files. Ensure your changes align with the project's goals and structure.
    *   If editing rules (`rules/`), ensure clarity and actionability.
    *   If adding examples (`examples/`), make them concise and relevant.
    *   If modifying checklists (`checklists/`), ensure they match the rules.
    *   If working on scripts (`scripts/`) or tools (`tools/`), follow general best practices for the language (PowerShell, Bash, Python).
4.  **Commit Changes:** Commit your changes with clear and concise commit messages. Consider using [Conventional Commits](https://www.conventionalcommits.org/) prefixes (e.g., `fix:`, `feat:`, `docs:`, `style:`, `refactor:`, `test:`).
    ```bash
    git add .
    git commit -m "feat: Add example for secure file handling (Rule 5.6.1)"
    ```
5.  **Push Branch:** Push your branch to your fork on GitHub.
    ```bash
    git push origin your-branch-name
    ```
6.  **Open a Pull Request:** Go to the original [Rules-LLM-Coding repository](https://github.com/JackovAlltrades/Rules-LLM-Coding) and open a Pull Request from your branch to the `main` branch.
7.  **Describe Your PR:** Provide a clear description of the changes you've made and why. Reference any relevant issues (e.g., "Closes #12").
8.  **Review:** Respond to any feedback or review comments.

## Code of Conduct

All contributors are expected to adhere to the [Contributor Covenant Code of Conduct](CODE_OF_CONDUCT.md). *(Note: You'll need to create this separate file later if you want one)*. Please be respectful and constructive in all interactions.

*(Optional: Add sections on Style Guides if scripts/tools become complex)*
## Documentation File Naming Convention

When creating new significant documentation files or rule documents within this repository (especially in the `docs/` or `rules/` directories), please follow this naming convention to help with organization and versioning:

`NNN-[category]-[short-description][-vX].md`

Where:
- `NNN`: A three-digit sequential number (e.g., `001-`, `002-`). Find the next available number.
- `[category]`: A short code indicating the type of document:
    - `arch`: Architecture or high-level design documents.
    - `rule`: Specific rule sets or detailed guidelines (primarily under `rules/`).
    - `doc`: General documentation or explanatory files (primarily under `docs/`).
    - `plan`: Planning documents (roadmaps, etc.).
    - `script`: Documentation related to scripts in `scripts/`.
    - `tpl`: Documentation related to templates in `templates/`.
- `[short-description]`: A brief, hyphenated description of the file's content.
- `[-vX]`: (Optional) A version suffix like `-v2`, `-v3` if this is a significant revision replacing an older document.

**Examples:**

