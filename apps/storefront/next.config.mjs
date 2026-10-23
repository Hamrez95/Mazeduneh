/** @type {import('next').NextConfig} */
const nextConfig = {
  output: process.env.MAZEDUNEH_STATIC_EXPORT === 'true'
    ? 'export'
    : process.env.MAZEDUNEH_DOCKER_STANDALONE === 'true'
      ? 'standalone'
      : undefined,
  images: {
    unoptimized: process.env.MAZEDUNEH_STATIC_EXPORT === 'true',
  },
  // Keep Next.js development status indicators out of the storefront UI.
  // Build and runtime errors remain visible in the browser overlay.
  devIndicators: false,
  poweredByHeader: false,
};

export default nextConfig;
