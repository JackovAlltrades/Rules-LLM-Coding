**2. Security (Non-Negotiable Foundations)**

*   **2.1. Input Validation & Sanitization:**
    *   2.1.1. **Trust Nothing:** Validate all external input (API requests, user forms, files, DB results, inter-service calls) for type, length, format, and range.
    *   2.1.2. **Contextual Output Encoding:** Encode data appropriately for the output context (HTML, SQL, LDAP, OS commands) to prevent injection attacks (XSS, SQLi, etc.). Use library functions (e.g., `htmlspecialchars`, parameterized queries).
    *   2.1.3. **Prefer Allow-lists:** Validate against known-good patterns/values rather than block-listing bad ones.

*   **2.2. Authentication & Authorization:**
    *   2.2.1. **Standard Frameworks:** Use robust, vetted libraries/frameworks for authentication (e.g., OAuth2, OpenID Connect, JWT with strong signing). Avoid rolling your own.
    *   2.2.2. **Strong Credentials:** Enforce strong password policies. Use secure hashing (e.g., Argon2, bcrypt). Implement MFA.
    *   2.2.3. **Principle of Least Privilege:** Grant users/services only the minimum permissions necessary. Implement role-based access control (RBAC).
    *   2.2.4. **Authorization Checks:** Verify authorization on *every* sensitive request, not just after login.

*   **2.3. Session Management:**
    *   2.3.1. **Secure Session Tokens:** Generate cryptographically strong, random session IDs. Store securely (e.g., HttpOnly, Secure cookies).
    *   2.3.2. **Session Timeouts:** Implement reasonable inactivity and absolute session timeouts. Provide logout functionality that invalidates sessions server-side.

*   **2.4. Cryptography & Data Privacy:**
    *   2.4.1. **Use Vetted Libraries:** Employ standard, well-maintained cryptographic libraries. Avoid custom crypto.
    *   2.4.2. **Strong Algorithms & Parameters:** Use current, recommended algorithms and key lengths (e.g., AES-GCM 256, RSA 3072+, SHA-256+).
    *   2.4.3. **Data Minimization:** Collect and retain only the minimum data necessary.
    *   2.4.4. **Encryption at Rest & Transit:** Encrypt sensitive data in databases/files (at rest) and over the network (HTTPS/TLS mandatory).
    *   2.4.5. **Key Management:** Use secure key management solutions (KMS, HSM). Do not hardcode keys. Rotate keys regularly.
    *   2.4.6. **Compliance:** Adhere to relevant data privacy regulations (GDPR, CCPA, HIPAA, etc.).

*   **2.5. Error Handling & Logging:**
    *   2.5.1. **Generic Error Messages:** Do not reveal sensitive system details (stack traces, internal paths, queries) to end-users. Show generic error pages/messages.
    *   2.5.2. **Detailed Server Logs:** Log detailed error information securely on the server side for debugging, including timestamps, user context (if safe), and event details.
    *   2.5.3. **Audit Logs:** Log security-sensitive events (logins, failed logins, access changes, high-value transactions). Protect log integrity.

*   **2.6. Dependency Management:**
    *   2.6.1. **Scan for Vulnerabilities:** Regularly scan dependencies (libraries, packages, containers) for known vulnerabilities using tools (e.g., OWASP Dependency-Check, Snyk, Trivy, GitHub Dependabot).
    *   2.6.2. **Update Promptly:** Update dependencies with security patches quickly. Automate where possible.
    *   2.6.3. **Minimize Dependencies:** Only include necessary libraries to reduce attack surface. Understand transitive dependencies.

*   **2.7. Secrets Management:**
    *   2.7.1. **Never Hardcode Secrets:** Do not commit API keys, passwords, certificates, or other secrets directly into source code or config files.
    *   2.7.2. **Use Secrets Management Tools:** Employ dedicated solutions (e.g., HashiCorp Vault, AWS Secrets Manager, Azure Key Vault, Infisical) or secure environment variable injection.
    *   2.7.3. **Least Privilege Access:** Grant access to secrets on a need-to-know basis. Rotate secrets periodically.

*   **2.8. API Security:**
    *   2.8.1. **Authentication/Authorization:** Secure all API endpoints (see 2.2).
    *   2.8.2. **Input Validation:** Validate all incoming data rigorously (see 2.1).
    *   2.8.3. **Rate Limiting:** Protect against brute-force and DoS attacks.
    *   2.8.4. **Secure Headers:** Use security headers (HSTS, CSP, X-Frame-Options, etc.).
    *   2.8.5. **Resource Consumption:** Limit resource usage per request (e.g., pagination limits, file size limits).

---
