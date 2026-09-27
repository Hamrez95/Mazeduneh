import type { Metadata } from "next";
import { InfoPage } from "../commerce-pages";

export const metadata: Metadata = { title: "پروفایل" };

export default function ProfileRoute() {
  return <InfoPage page="profile" />;
}
