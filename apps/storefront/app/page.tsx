import ProfessionalStorefront from "./demo/ProfessionalStorefront";
import StorefrontApp from "./StorefrontApp";

export default function HomePage() {
  const demoMode = process.env.NEXT_PUBLIC_MAZEDUNEH_DEMO_MODE !== "false";
  return demoMode ? <ProfessionalStorefront /> : <StorefrontApp />;
}
