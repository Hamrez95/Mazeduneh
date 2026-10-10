import type { Metadata } from "next";
import { InfoPage } from "../commerce-pages";
export const metadata: Metadata = { title: "دربارهٔ مزه‌دونه" };
export default function AboutRoute() { return <InfoPage page="about" />; }
