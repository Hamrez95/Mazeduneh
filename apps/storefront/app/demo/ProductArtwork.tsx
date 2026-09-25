import type { DemoProduct, ProductArt } from "./catalog";
import styles from "./professional-storefront.module.css";

const palettes: Record<ProductArt, [string, string, string]> = {
  pistachio: ["#c7d8a3", "#7f9558", "#f0dfbf"],
  almond: ["#d1a36d", "#9b6c3f", "#f1d7ae"],
  walnut: ["#b8895c", "#7f593d", "#dfbd91"],
  fruit: ["#e98954", "#d0a43c", "#84a963"],
  seed: ["#b9c77d", "#758345", "#e7e1b0"],
  cookie: ["#b67b58", "#6e4937", "#e7bd8e"],
  gift: ["#c9827e", "#7f5150", "#f0cbc2"],
};

export function ProductArtwork({
  product,
  hero = false,
}: {
  product: DemoProduct;
  hero?: boolean;
}) {
  const id = product.id.replace(/[^a-z0-9]/gi, "");
  const colors = palettes[product.art];
  const pieceCount = product.art === "fruit" ? 7 : product.art === "seed" ? 12 : 8;

  return (
    <svg
      className={hero ? styles.heroProductSvg : styles.productSvg}
      viewBox="0 0 420 320"
      role="img"
      aria-label={`تصویرسازی ${product.title}`}
    >
      <defs>
        <linearGradient id={`pack-${id}`} x1="0" x2="1" y1="0" y2="1">
          <stop offset="0" stopColor="#fffdf7" />
          <stop offset="1" stopColor="#eee9dd" />
        </linearGradient>
        <linearGradient id={`label-${id}`} x1="0" x2="1">
          <stop offset="0" stopColor={colors[1]} />
          <stop offset="1" stopColor={colors[0]} />
        </linearGradient>
        <filter id={`shadow-${id}`} x="-40%" y="-40%" width="180%" height="180%">
          <feDropShadow dx="0" dy="18" stdDeviation="17" floodColor="#26372b" floodOpacity=".18" />
        </filter>
      </defs>

      <ellipse cx="214" cy="279" rx="134" ry="23" fill="rgba(37,55,42,.12)" />
      <g filter={`url(#shadow-${id})`}>
        {product.art === "gift" ? (
          <>
            <rect x="102" y="75" width="216" height="187" rx="28" fill={`url(#pack-${id})`} />
            <rect x="94" y="67" width="232" height="58" rx="18" fill="#f9f2e8" />
            <path d="M210 68v194" stroke={colors[0]} strokeWidth="26" />
            <path d="M94 111h232" stroke={colors[0]} strokeWidth="22" />
            <path d="M210 68c-42-51-89-22-49 18 22 21 49 25 49 25s27-4 49-25c40-40-7-69-49-18Z" fill={colors[1]} />
          </>
        ) : (
          <>
            <path
              d="M110 76c0-20 16-36 36-36h136c20 0 36 16 36 36l-10 183c-1 18-16 32-34 32H154c-18 0-33-14-34-32L110 76Z"
              fill={`url(#pack-${id})`}
            />
            <path d="M121 86h186" stroke="#d9d2c5" strokeWidth="5" strokeLinecap="round" />
            <rect x="137" y="119" width="154" height="92" rx="24" fill={`url(#label-${id})`} />
            <circle cx="214" cy="150" r="18" fill="#fff8e8" opacity=".95" />
            <text x="214" y="158" textAnchor="middle" fontSize="22" fontWeight="900" fill={colors[1]}>م</text>
            <text x="214" y="186" textAnchor="middle" fontSize="13" fontWeight="700" fill="#fff">MAZEDOONE</text>
            <rect x="165" y="225" width="98" height="23" rx="11" fill="#e8e1d5" />
          </>
        )}
      </g>

      {Array.from({ length: pieceCount }).map((_, index) => {
        const x = 48 + ((index * 47) % 325);
        const y = 52 + ((index * 73) % 225);
        const rotate = (index * 31) % 120;

        if (product.art === "fruit") {
          return (
            <g key={index} transform={`translate(${x} ${y}) rotate(${rotate})`}>
              <circle r="18" fill={colors[index % colors.length]} opacity=".95" />
              <circle r="9" fill="none" stroke="#fff8e9" strokeWidth="3" opacity=".85" />
            </g>
          );
        }

        if (product.art === "cookie") {
          return (
            <g key={index} transform={`translate(${x} ${y}) rotate(${rotate})`}>
              <circle r="16" fill={colors[2]} stroke={colors[0]} strokeWidth="3" />
              <circle cx="-5" cy="-3" r="2.5" fill={colors[1]} />
              <circle cx="6" cy="4" r="2.5" fill={colors[1]} />
            </g>
          );
        }

        return (
          <ellipse
            key={index}
            cx={x}
            cy={y}
            rx={product.art === "seed" ? 6 : 10}
            ry={product.art === "seed" ? 13 : 18}
            fill={colors[index % colors.length]}
            stroke="#fff7e8"
            strokeWidth="2"
            transform={`rotate(${rotate} ${x} ${y})`}
            opacity=".96"
          />
        );
      })}
    </svg>
  );
}
