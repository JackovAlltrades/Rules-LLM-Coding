# Rules-LLM-Coding Project

This repository serves as the central hub for the Master List of Rules (MLR)
system designed to guide and automate best practices in LLM-assisted software
development.

## Purpose

- **Centralize:** Provides a single source of truth for coding rules, checklists, templates, and automation scripts.
- **Automate:** Includes scripts for setting up new projects and integrating MLR assets.
- **Validate:** Aims to incorporate automated checks for compliance via CI/CD workflows.
- **Integrate:** Facilitates consistent LLM usage and validation across projects.

## Structure

(See the directory structure within the repository)

- `rules/`: Contains the core Master List Rules (v1.0.7+) in Markdown.
- `checklists/`: Validation checklists (YAML).
- `templates/`: LLM prompts and project scaffolding templates.
- `workflows/`: CI/CD workflow templates.
- `scripts/`: Core automation scripts (`setup.ps1`, `setup.sh`, `update_mlr.*`).
- `tools/`: Utility scripts (LLM wrappers, cost tracking - Python recommended).
- `tests/`: Tests for the automation scripts and tools *themselves*.
- `configs/`: Centralized configurations for linters, scanners, LLM tools.
- `docs/`: Detailed documentation *about* this MLR system.
- `examples/`: Code examples demonstrating MLR adherence.

## Getting Started

(Instructions for using `scripts/setup.sh` or `scripts/setup.ps1` in a target project will go here eventually.)

## Contributing

(See `CONTRIBUTING.md` - To be created)

