class ApiConstants {
    static const String baseUrl = String.fromEnvironment(
        "API_BASE_URL",
        defaultValue: "http://localhost:8000",
    );
    
    static const String chatEndpoint = "/api/v1/chat";
    static const String healthEndpoint = "/health";
    static const String landSuitabilityEndpoint = "/api/v1/land-suitability";
    static const String soilInfoEndpoint = "/api/v1/land-suitability/soil-info";
    static const String cropsEndpoint = "/api/v1/land-suitability/crops";
    static const String layersEndpoint = "/api/v1/layers";
    static const String geocodeEndpoint = "/api/v1/geocode";
}