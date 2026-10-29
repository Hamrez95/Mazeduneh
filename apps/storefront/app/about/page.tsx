import { pageMetadata } from "../seo";
import { InfoPage } from "../commerce-pages";
export const metadata = pageMetadata("/about", "داستان مزه‌دونه", "با مزه‌دونه و نگاه ما به انتخاب خوراکی و تجربهٔ هدیه آشنا شوید.");
export default function AboutRoute() { return <InfoPage page="about" />; }
