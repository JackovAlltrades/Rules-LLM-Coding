**5. Performance & Efficiency**

*   **5.1. Performance Standards:**
    *   5.1.1. **Sub-section: Performance Standards:** *(Added Nuance)* The following values represent **target goals** for a highly performant system. Real-world implementations may involve trade-offs; deviations should be justified based on specific use cases, cost constraints, or technical limitations, and documented. Strive to meet or exceed these where feasible.
        *   **API Response Time (p95):** < 200ms for typical requests, < 1s for complex operations.
        *   **Database Queries:** Avoid N+1 queries. Optimize complex queries (< 50ms target). Use indexing.
        *   **File Uploads/Downloads:** Optimize for speed and reliability. Use streaming for large files.
        *   **Throughput:** Define target requests per second/minute based on expected load.
        *   **Error Rate:** Aim for < 0.1% error rate under normal load.
        *   **Resource Utilization:** Monitor CPU, memory, network, disk I/O. Avoid excessive consumption (< 80% sustained usage target).
        *   **Time to First Byte (TTFB):** Optimize server-side processing for fast initial response (< 500ms target).
    *   5.1.2. **Profiling:** Use profiling tools to identify bottlenecks in CPU, memory, I/O, or network usage. Optimize critical code paths.

*   **5.2. Algorithmic Efficiency:**
    *   5.2.1. **Choose Appropriate Algorithms:** Be mindful of Big O notation. Avoid unnecessarily complex or inefficient algorithms (e.g., O(n^2) where O(n log n) or O(n) is feasible) for large datasets.
    *   5.2.2. **Optimize Loops and Data Structures:** Use efficient data structures and optimize critical loops.

*   **5.3. Database Performance:**
    *   5.3.1. **Efficient Queries:** Write optimized SQL/NoSQL queries. Use `EXPLAIN` or equivalent to analyze query plans.
    *   5.3.2. **Proper Indexing:** Create indexes on frequently queried columns, especially in `WHERE` clauses and `JOIN` conditions. Avoid over-indexing.
    *   5.3.3. **Connection Pooling:** Use database connection pooling to reduce connection overhead.

*   **5.4. Caching:**
    *   5.4.1. **Identify Cacheable Data:** Cache frequently accessed, rarely changing data (e.g., config, static lists, results of expensive queries).
    *   5.4.2. **Choose Caching Strategy:** Implement appropriate caching mechanisms (in-memory, distributed cache like Redis/Memcached). Define cache invalidation strategies.

*   **5.5. Asynchronous Processing:**
    *   5.5.1. **Offload Long Tasks:** Use background jobs or message queues (e.g., Celery, RabbitMQ, Kafka, SQS) for time-consuming tasks (sending emails, processing images, generating reports) that don't need immediate results.

*   **5.6. Resource Management:**
    *   5.6.1. **Release Resources:** Ensure files, network connections, database connections, etc., are properly closed/released. Use context managers (`try-with-resources`, `using`, `defer`) where available.
    *   5.6.2. **Memory Management:** Be mindful of memory allocation, especially in long-running processes or when handling large datasets. Avoid memory leaks.

---
