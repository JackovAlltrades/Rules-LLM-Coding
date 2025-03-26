# LLM Code Review and Quality Assurance Summary

## Table of Contents
- [Overview](#overview)
- [Code Quality Standards](#code-quality-standards)
  - [Clarity and Readability](#clarity-and-readability)
  - [Correctness and Robustness](#correctness-and-robustness)
  - [Security Best Practices](#security-best-practices)
  - [Performance Optimization](#performance-optimization)
- [System Integration](#system-integration)
- [Documentation Requirements](#documentation-requirements)
- [Language-Specific Guidelines](#language-specific-guidelines)
- [Project Structure Best Practices](#project-structure-best-practices)
- [Design Pattern Implementation](#design-pattern-implementation)
- [Testing Requirements](#testing-requirements)

## Overview

This document summarizes standards for evaluating and generating high-quality code across various languages with a focus on backend development. It serves as a high-level guide and potential input for LLM-assisted code review and generation, complementing the detailed Master List of Rules (MLR). It emphasizes consistency, security, and performance across software projects.

*(Note: For detailed rules and actionable checklist items, refer to the main `rules/` and `checklists/` directories.)*

## Code Quality Standards

### Clarity and Readability (Ref MLR Section 3.1)

- **Naming Conventions**: Use semantic naming for all variables, functions, and classes.
- **Formatting**: Follow language-specific formatting standards (`rustfmt`, `gofmt`, Python linters).
- **Comments**: Include clear, concise comments explaining complex logic and design decisions (MLR 3.2).
- **Organization**: Apply Single Function Principle and DRY (Don't Repeat Yourself) principles (MLR 3.4).

### Correctness and Robustness (Ref MLR Section 3.3, 4)

- **Edge Cases**: Handle edge cases and potential error conditions (MLR 4.1.3).
- **Error Handling**: Implement robust error handling appropriate to the language (e.g., Rust's Result, Go's explicit error returns) (MLR 3.3).
- **Input Validation**: Validate all inputs at appropriate application layers (MLR 2.1).
- **Type Safety**: Leverage language type systems to prevent runtime errors.

### Security Best Practices (Ref MLR Section 2)

- **Input Sanitization/Validation**: Implement defense-in-depth validation at all application layers (MLR 2.1).
- **Authentication/Authorization**: Use industry-standard mechanisms and enforce correctly (MLR 2.2).
- **Secrets Management**: Store credentials securely (env vars, vaults), never in code (MLR 2.7).
- **Rate Limiting**: Implement throttling for public API endpoints (MLR 2.8.2).
- **CORS Configuration**: Configure CORS correctly for browser-facing APIs (MLR 2.8.3).
- **Dependency Security**: Use vetted dependencies and scan for vulnerabilities (MLR 2.6).
- **Least Privilege**: Restrict permissions to minimum required access (MLR 2.2.6).

### Performance Optimization (Ref MLR Section 5)

- **Algorithm Efficiency**: Select appropriate algorithms with optimal time/space complexity (MLR 5.1).
- **Database Optimization**: Generate optimized queries with proper indexing (MLR 5.3).
- **Caching Strategy**: Implement caching where appropriate (MLR 5.4).
- **Concurrency**: Leverage language-specific concurrency features effectively (MLR 5.5).
- **Resource Management**: Efficiently manage connections, memory, file handles (MLR 5.6).

## System Integration (Ref MLR Section 8)

- Ensure code aligns with existing architecture patterns.
- Update dependency management files correctly.
- Include integration points with existing services.
- Consider deployment environment requirements (MLR 8.3).

## Documentation Requirements (Ref MLR Section 6)

- **Code Documentation**: Use language-appropriate documentation styles (docstrings, etc.) (MLR 3.2.3).
- **API Documentation**: Include clear interface descriptions (e.g., OpenAPI) (MLR 6.3.4).
- **Project Documentation**: Maintain README files with usage examples (MLR 6.1).
- **Design Decisions**: Document rationale for architectural choices (MLR 6.2).

## Language-Specific Guidelines

*(These guidelines complement the general rules)*

### Rust
- Leverage Rust's type system, ownership, and borrowing model for safety.
- Use `Result` and `Option` consistently for error handling.
- Apply standard Rust idioms and patterns (Clippy lints are helpful).
- Pay attention to lifetimes.
- Utilize crates thoughtfully.

### Go
- Follow Go's emphasis on simplicity and readability.
- Use explicit `if err != nil` error handling patterns.
- Leverage goroutines and channels for concurrency where appropriate.
- Define and use clear interfaces.
- Keep packages focused.

### Python
- Follow PEP 8 style guidelines rigorously (use Black, Flake8/Ruff).
- Use type hints (introduced in Python 3.5+) for clarity and tooling support.
- Implement specific exception handling rather than broad `except Exception:`.
- Be mindful of the Global Interpreter Lock (GIL) for CPU-bound concurrency.
- Use virtual environments.

### JavaScript/TypeScript
- Strongly prefer TypeScript for type safety, especially in larger projects.
- Follow modern ES6+ syntax and best practices (use ESLint, Prettier).
- Implement proper asynchronous patterns (`async/await`, Promises).
- Handle errors explicitly in Promises and `async` functions.
- Be aware of browser/Node.js environment differences.
- Manage dependencies carefully using npm/yarn.

## Project Structure Best Practices (Ref MLR Section 8.1)

- Organize code into logical modules or packages based on functionality (features or layers).
- Follow language ecosystem conventions for directory structure (e.g., Go workspace, Python packages).
- Separate concerns (e.g., API handlers, business logic services, data access layers).
- Centralize configuration management (MLR 3.5).
- Create clear application entry points (`main.go`, `app.py`, `server.js`).

## Design Pattern Implementation

### When to Use Design Patterns
- Apply established patterns (GoF, etc.) where they solve a specific, recurring problem clearly.
- Favor simplicity; avoid over-engineering by forcing patterns where they aren't needed.
- Document the use of significant patterns and the reasoning behind the choice.

### Common Patterns Examples
- **Creational**: Factory Method, Abstract Factory, Builder, Singleton (use judiciously).
- **Structural**: Adapter, Facade, Decorator, Proxy, Composite.
- **Behavioral**: Strategy, Observer, Command, Template Method, State.
- **Language Specific**: Consider idiomatic patterns (e.g., Go interfaces, Rust traits).

## Testing Requirements (Ref MLR Section 4)

- **Unit Tests**: Test individual functions, methods, and classes in isolation.
- **Integration Tests**: Verify interactions between components or modules.
- **Security Tests**: Specifically test input validation, authZ/N checks, error message content.
- **Performance Tests**: Benchmark critical code paths or endpoints under load.
- **Coverage**: Aim for meaningful test coverage, focusing on logic branches and critical paths.

### Key Areas to Test
- API endpoint request/response cycles.
- Authentication and authorization logic.
- Database interaction logic (CRUD operations).
- Business logic rules and calculations.
- Error handling paths.
- Edge cases and boundary conditions.
- Potentially vulnerable areas identified during review.
