**6. Architecture & System Design**

*   **6.1. Scalability:**
    *   6.1.1. **Stateless Services:** Design services to be stateless where possible, allowing easier horizontal scaling. Store state externally (DB, cache).
    *   6.1.2. **Horizontal vs. Vertical Scaling:** Understand when to add more instances (horizontal) vs. increasing resources of existing instances (vertical). Design for horizontal scaling primarily.
    *   6.1.3. **Load Balancing:** Use load balancers to distribute traffic across multiple instances.

*   **6.2. Reliability & Fault Tolerance:**
    *   6.2.1. **Redundancy:** Implement redundancy at critical points (servers, databases, network paths).
    *   6.2.2. **Health Checks:** Implement health check endpoints for services so load balancers/orchestrators can manage instances.
    *   6.2.3. **Graceful Degradation:** Design systems to handle partial failures gracefully (e.g., fallback mechanisms, circuit breakers).
    *   6.2.4. **Idempotency:** Design operations (especially API endpoints or message handlers) to be idempotent where possible (multiple identical requests have the same effect as one).

*   **6.3. API Design:**
    *   6.3.1. **Consistency:** Follow consistent naming conventions, data formats (e.g., JSON), and error handling across APIs.
    *   6.3.2. **RESTful Principles / GraphQL Best Practices:** Adhere to standard practices for the chosen API paradigm.
    *   6.3.3. **Versioning:** Implement an API versioning strategy (e.g., URL path, header).
    *   6.3.4. **Documentation:** Provide clear, interactive API documentation (e.g., OpenAPI/Swagger, Postman).

*   **6.4. Microservices vs. Monolith (Contextual Choice):**
    *   6.4.1. **Understand Trade-offs:** Be aware of the complexities of microservices (deployment, monitoring, distributed transactions) vs. the challenges of scaling/maintaining large monoliths. Choose based on team size, project complexity, and scalability needs.
    *   6.4.2. **Bounded Contexts:** If using microservices, define clear boundaries based on business domains.

*   **6.5. Inter-Service Communication:**
    *   6.5.1. **Choose Appropriate Mechanism:** Select suitable communication patterns (synchronous REST/gRPC, asynchronous messaging via queues/streams).
    *   6.5.2. **Handle Failures:** Implement retries, circuit breakers, and timeouts for inter-service calls.

*   **6.6. Project Structure & Scaffolding:**
    *   6.6.1. **Standardized Layout:** Follow language/framework conventions or establish a clear, consistent project structure.
    *   6.6.2. **Separation of Concerns:** Organize code by feature or layer (e.g., controllers, services, repositories/DAL).
    *   6.6.3. **Scaffolding Tools:** Use templates or tools (e.g., Yeoman, `create-react-app`, `dotnet new`) for initial project setup if appropriate, but understand the generated structure.

---
