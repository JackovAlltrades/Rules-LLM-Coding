**1. Using LLMs Effectively & Safely (The Core Interaction Loop)**

*   *(Added Scope Clarification)* **Note:** This section focuses primarily on the process of *using* LLMs as coding assistants. Guidelines for *integrating* LLM capabilities *as application features* are touched upon where relevant (e.g., Section 9.3 MLOps/AI Integration), but the primary focus here is the developer's interaction with the LLM during development.

*   **1.1. Guiding the LLM:**
    *   1.1.1. **Be Specific & Contextual:** Provide clear, detailed instructions. Include language, frameworks, patterns desired, relevant existing code snippets (if safe), and constraints. *Bad: `"Write a function."` Good: `"Write a Python function using FastAPI that takes a user ID (int) and returns their profile data (dict) from a PostgreSQL database (use psycopg2), handling potential `NotFound` errors."`*
    *   1.1.2. **Define Personas/Roles:** `"Act as a senior Go developer specializing in secure microservices..."` Helps set expectations.
    *   1.1.3. **Few-Shot Prompting:** Provide examples of desired input/output or code style.
    *   1.1.4. **Chain of Thought / Step-by-Step:** Ask the LLM to `"think step by step"` to break down complex problems.
    *   1.1.5. **Iterative Refinement:** Don't expect perfection first try. Use follow-up prompts to correct, refactor, or add features. `"Refactor the previous function to use dependency injection for the database connection."` `"Add logging for error conditions."`
    *   1.1.6. **Constraint Setting:** Explicitly state what *not* to do. `"Do not use external libraries for this task."` `"Ensure the function is pure and has no side effects."`
    *   1.1.7. **Feedback Loops:** Actively provide feedback to the LLM (if the tool allows) or refine prompts based on output quality. Note which types of prompts or constraints yield better (more secure, performant, maintainable) results for specific tasks and share insights if collaborating. *(New - Missing Topic)*

*   **1.2. Validating LLM Output (CRITICAL):**
    *   1.2.1. **Treat as Untrusted Junior Dev:** Assume LLM output *may* contain errors, security flaws, inefficiencies, or subtly incorrect logic. **You are responsible for the code you commit.**
    *   1.2.2. **Functional Correctness:** Does it work? Does it solve the *intended* problem? Test rigorously with edge cases.
    *   1.2.3. **Security Vulnerabilities:** Actively check for common flaws (Injection, XSS, auth bypass, insecure defaults, etc.). Use SAST tools and manual review. **Do not trust the LLM's claims of security.**
    *   1.2.4. **Performance Issues:** Look for inefficient algorithms, unnecessary loops, resource leaks, or non-optimal queries. Profile if necessary.
    *   1.2.5. **Maintainability & Readability:** Does it adhere to project style guides? Is it overly complex? Can others understand it? Refactor for clarity. Add comments where LLM logic is non-obvious.
    *   1.2.6. **Dependency Check:** Did the LLM introduce new libraries? Are they approved, secure, and necessary?

*   **1.3. Security Risks with LLMs:**
    *   1.3.1. **Prompt Injection:** Be cautious if LLM interactions incorporate external or user-provided data directly into prompts. Sanitize inputs.
    *   1.3.2. **IP/Data Leakage Risk:** **Do not paste sensitive code, proprietary algorithms, PII, secrets, API keys, or internal configuration details into prompts for public/third-party LLMs.** Understand and comply with your organization's specific policies regarding AI tool usage and data privacy. Use local, private, or approved enterprise models if available for tasks involving sensitive data. *(Enhanced from v1.0.6)*
    *   1.3.3. **Insecure Code Generation:** LLMs learn from vast datasets, including insecure code. Always validate security (see 1.2.3). Specify security requirements in prompts (e.g., `"using parameterized queries"`).
    *   1.3.4. **Over-Reliance / Automation Bias:** Do not blindly accept LLM suggestions, especially for security-critical or complex logic. Maintain critical thinking.

*   **1.4. Performance & Cost Considerations:**
    *   1.4.1. **Cost of Tokens:** Be mindful of API costs for cloud-based LLMs, especially with large contexts or frequent iterations.
    *   1.4.2. **Inferred Performance:** LLMs don't truly understand runtime performance. Profile generated code (see 1.2.4, Section 5).
    *   1.4.3. **LLM Tool Selection:** Choose LLM tools (IDE plugins, standalone models, APIs) based on:
        *   **Task Suitability:** Some models excel at code generation, others at explanation or review.
        *   **Security & Privacy:** Prioritize tools meeting organizational security/privacy requirements (e.g., enterprise licenses, local models). Understand data handling policies.
        *   **Cost:** Be aware of token usage costs for API-based models.
        *   **Context Window:** Consider the amount of code/context the LLM can handle.
        *   **Integration:** How well does it fit into your existing workflow? *(New - Missing Topic)*

*   **1.5. Ethical & Responsible Use:**
    *   1.5.1. **Ethical AI Practices:** Be mindful of potential biases (e.g., generating stereotypical code examples, reinforcing existing societal biases) in LLM outputs. Strive for fairness and equity. Review generated code for potentially discriminatory or unfair logic, especially if it involves user categorization or resource allocation. Actively test for bias in AI-driven features. **Human oversight is critical, as automated detection is limited.** *(Refined Actionability)*
    *   1.5.2. **Code Ownership & Licensing:** Be aware of the licensing implications of code generated by LLMs. Some models are trained on licensed code. Prefer permissive outputs; verify compliance. Check tool's terms of service.
    *   1.5.3. **Transparency:** Document where LLMs were significantly used in the development process, especially for complex or critical components.
    *   1.5.4. **Developer Training & Awareness:** Continuously learn about effective prompting, the limitations and risks of LLMs, and these guidelines. Understand that proficiency with LLMs as tools requires developing new skills and critical judgment. *(New - Missing Topic)*

---
