**4. Testing & Validation**

*   **4.1. Unit Testing:**
    *   4.1.1. **Test Individual Units:** Write tests for small, isolated pieces of code (functions, methods, classes).
    *   4.1.2. **Mock Dependencies:** Use mocks, stubs, or fakes to isolate the unit under test from external dependencies (database, network, etc.).
    *   4.1.3. **Cover Edge Cases:** Test boundary conditions, error paths, and typical usage scenarios. Aim for high code coverage where practical and meaningful.

*   **4.2. Integration Testing:**
    *   4.2.1. **Test Component Interactions:** Verify that different units/modules/services work together correctly.
    *   4.2.2. **Test Against Real Dependencies (Selectively):** May involve testing against actual databases, APIs (in test environments), or other services to ensure integration points are valid. Use test containers where feasible.

*(Note: End-to-End testing, while crucial, often falls under QA/separate testing processes but should be considered)*

---
