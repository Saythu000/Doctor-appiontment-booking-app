class ApiConstants {
  // DrGodly Next.js REST App Base URL (Intake record storage & DB)
  static const String appBaseUrl = 'https://app.drgodly.com';

  // DrGodly IAM Base URL (Authentication & Session)
  static const String iamBaseUrl = 'https://iam.drgodly.com';

  // DrGodly FHIR Middleware URL
  static const String fhirGqlUrl = 'https://fhirgql.drgodly.com';

  // DrGodly Default Tenant Organization ID
  static const String defaultOrganizationId = '0fb41e50-82a4-461e-96c7-bd11359d892d';

  // Python AI Agent Service URLs
  // Configured with standard environment defaults, overridable at runtime
  static const String defaultIntakeAgentUrl = 'https://agents.drgodly.com/api/agent/intake';
  static const String defaultAssessmentPlanAgentUrl = 'https://agents.drgodly.com/api/agent/assessment';

  // Intake REST Endpoints on appBaseUrl
  static const String intakeCreatePath = '/api/intake/create';
  static const String intakeUpdatePath = '/api/intake/update';
  static const String intakeAbandonPath = '/api/intake/abandon';
  static const String intakeLinkPath = '/api/intake/link';
  static const String intakeGetByIdPath = '/api/intake/get-by-id';
  static const String intakeListPath = '/api/intake/list';
}
