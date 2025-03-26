**3. Code Quality & Maintainability**

*   **3.1. Readability & Style:**
    *   3.1.1. **Consistent Style:** Adhere to established project/language style guides (e.g., PEP 8 for Python, `gofmt` for Go). Use linters and formatters automatically.
    *   3.1.2. **Meaningful Naming:** Use clear, descriptive names for variables, functions, classes, etc. Avoid ambiguity or overly short names.
    *   3.1.3. **Code Structure:** Organize code logically (modules, packages, SOLID principles). Keep functions/methods focused and reasonably short.

*   **3.2. Comments & Documentation:**
    *   3.2.1. **Explain the "Why", Not the "How":** Comment complex logic, assumptions, workarounds, or the reasoning behind non-obvious code. Don't just restate the code.
    *   3.2.2. **Keep Comments Updated:** Ensure comments stay synchronized with code changes. Remove outdated comments.
    *   3.2.3. **API/Function Documentation:** Document public APIs and complex functions clearly (parameters, return values, exceptions/errors, usage). Use standard formats (e.g., Docstrings, Javadoc, GoDoc).

*   **3.3. Error Handling:**
    *   3.3.1. **Handle Expected Errors:** Gracefully handle foreseeable errors (e.g., file not found, network issues, invalid input) without crashing.
    *   3.3.2. **Avoid Swallowing Exceptions:** Don't silently ignore errors unless explicitly intended and justified. Log appropriately (see 2.5).
    *   3.3.3. **Use Specific Exceptions/Errors:** Throw or return specific error types where possible to allow targeted handling.

*   **3.4. Modularity & Reusability:**
    *   3.4.1. **DRY Principle (Don't Repeat Yourself):** Encapsulate reusable logic into functions, classes, or modules.
    *   3.4.2. **Loose Coupling, High Cohesion:** Design components that are independent and focused on a single responsibility. Minimize dependencies between modules.
    *   3.4.3. **Clear Interfaces:** Define stable and well-documented interfaces between components/modules.

*   **3.5. Configuration Management:**
    *   3.5.1. **Externalize Configuration:** Keep configuration (database URLs, API keys, feature flags) separate from code (e.g., environment variables, config files, config services).
    *   3.5.2. **Environment-Specific Config:** Provide mechanisms for different configurations per environment (dev, staging, prod).

---
