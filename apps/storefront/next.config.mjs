/** @type {import('next').NextConfig} */
const nextConfig = {
  output: process.env.MAZEDUNEH_STATIC_EXPORT === 'true' ? 'export' : undefined,
  images: {
    unoptimized: process.env.MAZEDUNEH_STATIC_EXPORT === 'true',
  },
  poweredByHeader: false,
};

export default nextConfig;
