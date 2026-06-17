/** @type {import('next').NextConfig} */
const nextConfig = {
  typescript: {
    ignoreBuildErrors: true,
  },
  images: {
    // Allow <Image> component to optimize Firebase Storage images via Vercel CDN.
    // Auto-converts to AVIF/WebP, resizes to requested dimensions, and caches at edge.
    // AVIF first — ~20-50% smaller than WebP, so less bandwidth served to customers.
    formats: ['image/avif', 'image/webp'],
    // 31-day cache. Product images are static per URL (Firebase tokenises the URL,
    // so an updated image gets a NEW url) — caching long means each image is fetched
    // from Firebase + optimised by Vercel ONCE, then served from the edge cache.
    // Cuts both Firebase egress and Vercel image-optimisation cost dramatically.
    minimumCacheTTL: 2678400, // 31 days (was 24h)
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
