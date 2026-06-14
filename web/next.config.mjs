/** @type {import('next').NextConfig} */
const nextConfig = {
  typescript: {
    ignoreBuildErrors: true,
  },
  images: {
    // Allow <Image> component to optimize Firebase Storage images via Vercel CDN.
    // Auto-converts to WebP/AVIF, resizes to requested dimensions, and caches at edge.
    formats: ['image/webp', 'image/avif'],
    minimumCacheTTL: 86400, // 24-hour CDN cache for optimized images
    remotePatterns: [
      {
        protocol: 'https',
        hostname: 'firebasestorage.googleapis.com',
        pathname: '/v0/b/**',
      },
      {
        protocol: 'https',
        hostname: 'storage.googleapis.com',
        pathname: '/**',
      },
    ],
  },
  // Compress all API responses with gzip/brotli at the edge
  compress: true,
}

export default nextConfig
