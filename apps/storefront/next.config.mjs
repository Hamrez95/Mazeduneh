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
  poweredByHeader: false,
};

export default nextConfig;
