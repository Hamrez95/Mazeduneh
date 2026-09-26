import ProfessionalStorefront from "./demo/ProfessionalStorefront";
import StorefrontApp from "./StorefrontApp";

const apiBaseUrl = process.env.NEXT_PUBLIC_MAZEDUNEH_API_URL?.trim()
  || process.env.NEXT_PUBLIC_MAZEDUNEH_API_BASE_URL?.trim()
  || "";
const explicitDemoMode = process.env.NEXT_PUBLIC_MAZEDUNEH_DEMO_MODE?.trim().toLowerCase();

export default function HomePage() {
  // Keep the public preview safe by default, but automatically use the API-backed
  // storefront once a public API origin is configured in the build environment.
  const demoMode = explicitDemoMode === "true"
    || (explicitDemoMode !== "false" && !apiBaseUrl);
  return demoMode ? <ProfessionalStorefront /> : <StorefrontApp />;
}
