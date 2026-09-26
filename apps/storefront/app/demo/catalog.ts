export type ProductArt =
  | "pistachio"
  | "almond"
  | "walnut"
  | "fruit"
  | "seed"
  | "cookie"
  | "gift";

export type DemoProduct = {
  id: string;
  /** Server SKU used when this product came from the live catalog. */
  sku?: string;
  variants?: Array<{ sku: string; packageLabel: string; price: number; stock: number }>;
  title: string;
  subtitle: string;
  category: string;
  origin: string;
  art: ProductArt;
  accent: "sage" | "mint" | "sand" | "peach" | "apricot" | "olive" | "lilac" | "rose";
  price: number;
  oldPrice?: number;
  packageLabel: string;
  stock: number;
  badge?: string;
  note: string;
  description?: string;
  seoTitle?: string;
  seoDescription?: string;
  primaryImage?: string;
  galleryImages?: string[];
  specifications?: Record<string, string>;
};

export const categories = [
  "همه",
  "آجیل و مغزها",
  "میوه خشک",
  "لواشک و ترش‌مزه",
  "کوکی و شیرینی",
  "کم‌شکر و پروتئینی",
  "هدیه",
];

export const demoProducts: DemoProduct[] = [
  {
    id: "pistachio-akbari",
    title: "پسته اکبری ممتاز",
    subtitle: "دانه‌های کشیده، خندان و دست‌چین",
    category: "آجیل و مغزها",
    origin: "رفسنجان",
    art: "pistachio",
    accent: "sage",
    price: 465000,
    oldPrice: 495000,
    packageLabel: "بسته ۵۰۰ گرمی",
    stock: 12,
    badge: "پرفروش",
    note: "شور ملایم · سایز یکدست",
  },
  {
    id: "pistachio-ahmad",
    title: "پسته احمدآقایی",
    subtitle: "خوش‌رنگ، کشیده و مناسب پذیرایی",
    category: "آجیل و مغزها",
    origin: "کرمان",
    art: "pistachio",
    accent: "mint",
    price: 445000,
    packageLabel: "بسته ۵۰۰ گرمی",
    stock: 10,
    badge: "انتخاب مهمانی",
    note: "بوداده روز · نمک کنترل‌شده",
  },
  {
    id: "almond",
    title: "بادام درختی خام",
    subtitle: "بدون نمک، ترد و مناسب میان‌وعده",
    category: "آجیل و مغزها",
    origin: "چهارمحال",
    art: "almond",
    accent: "sand",
    price: 330000,
    packageLabel: "بسته ۵۰۰ گرمی",
    stock: 16,
    note: "خام · بدون افزودنی",
  },
  {
    id: "walnut",
    title: "مغز گردوی ایرانی",
    subtitle: "روشن، تازه و مناسب صبحانه",
    category: "آجیل و مغزها",
    origin: "تویسرکان",
    art: "walnut",
    accent: "peach",
    price: 305000,
    packageLabel: "بسته ۵۰۰ گرمی",
    stock: 8,
    note: "شکستگی کم · طعم تازه",
  },
  {
    id: "dried-fruit",
    title: "میکس میوه خشک",
    subtitle: "سیب، پرتقال، کیوی و توت‌فرنگی",
    category: "میوه خشک",
    origin: "تولید روز مزه‌دونه",
    art: "fruit",
    accent: "apricot",
    price: 238000,
    oldPrice: 255000,
    packageLabel: "بسته ۳۰۰ گرمی",
    stock: 21,
    badge: "ترکیب تازه",
    note: "بدون سرخ‌کردن · برش یکدست",
  },
  {
    id: "pumpkin-seeds",
    title: "تخمه کدو گوشتی",
    subtitle: "درشت، تازه و کم‌نمک",
    category: "آجیل و مغزها",
    origin: "ایران",
    art: "seed",
    accent: "olive",
    price: 180000,
    packageLabel: "بسته ۵۰۰ گرمی",
    stock: 14,
    note: "تازه‌برشت · کم‌نمک",
  },
  {
    id: "protein-cookie",
    title: "کوکی پروتئینی",
    subtitle: "جو دوسر، کره بادام‌زمینی و شکلات تلخ",
    category: "کم‌شکر و پروتئینی",
    origin: "تولید روز",
    art: "cookie",
    accent: "lilac",
    price: 360000,
    packageLabel: "پک ۴ عددی",
    stock: 20,
    badge: "کم‌شکر · پروتئینی",
    note: "پخت روز · بافت نرم",
  },
  {
    id: "fruit-leather",
    title: "لواشک آلوچه خونگی",
    subtitle: "ترش و ملس، با میوه‌ی واقعی",
    category: "لواشک و ترش‌مزه",
    origin: "آماده‌سازی روزانه",
    art: "fruit",
    accent: "rose",
    price: 89000,
    packageLabel: "بسته ۱۰۰ گرمی",
    stock: 18,
    badge: "دست‌ساز",
    note: "بدون رنگ مصنوعی · میوه‌محور",
  },
  {
    id: "oat-cookie",
    title: "کوکی جو دوسر و شکلات",
    subtitle: "شیرینی ملایم با شکلات تلخ",
    category: "کوکی و شیرینی",
    origin: "پخت روز",
    art: "cookie",
    accent: "apricot",
    price: 175000,
    packageLabel: "جعبه ۴ عددی",
    stock: 15,
    badge: "کم‌شکر",
    note: "جو دوسر · بدون شیرینی اضافه",
  },
  {
    id: "gift-box",
    title: "جعبه هدیه دورهمی",
    subtitle: "آجیل ممتاز با بسته‌بندی اختصاصی",
    category: "هدیه",
    origin: "بسته‌بندی مزه‌دونه",
    art: "gift",
    accent: "rose",
    price: 1290000,
    oldPrice: 1380000,
    packageLabel: "جعبه ۱٫۲ کیلوگرمی",
    stock: 7,
    badge: "هدیه ویژه",
    note: "کارت تبریک · چیدمان سفارشی",
  },
];

export function toman(value: number) {
  return new Intl.NumberFormat("fa-IR").format(value);
}
