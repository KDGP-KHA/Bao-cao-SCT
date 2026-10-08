# Báo cáo Sở Công Thương

Classic ASP.NET MVC reporting application with industry-scoped dashboards and
authenticated chatbot tools.

- [SQL and IIS deployment guide](docs/deployment-guide.md): build, runtime/library
  requirements, SQL installation, permission setup, acceptance and rollback.
- [Performance changes and validation](docs/report-performance-deployment.md).
- [Dashboard behavior and metric rules](docs/dashboard-implementation.md).
- [Chatbot integration](docs/chatbot/README.md), [tool contracts](docs/chatbot/business-tools.md)
  and [authorization rules](docs/chatbot/security-scope.md).

Deploy the generated SCT SQL scripts before switching to the matching code.
Existing user industry grants are preserved. Root `httpRuntime` stays at 4.5.2;
the existing application project targets require .NET Framework 4.8.
