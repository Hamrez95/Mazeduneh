import ProfessionalStorefront from "./demo/ProfessionalStorefront";
import { pageMetadata } from "./seo";

export const metadata = pageMetadata("/", "مزه‌دونه؛ آجیل و هدیه‌های خوش‌طعم", "آجیل، میان‌وعده و ایده‌های هدیهٔ مزه‌دونه را کشف کن؛ انتخاب بسته برای خودت، پذیرایی و هدیهٔ سازمانی.");

export default function HomePage() {
  return <ProfessionalStorefront />;
}
