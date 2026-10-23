import type { Metadata } from "next";
import { InfoPage } from "../commerce-pages";

export const metadata: Metadata = { robots: { index: false, follow: true }, title: "پیگیری سفارش" };

export default function ProfileRoute() {
  return <InfoPage page="profile" />;
}
