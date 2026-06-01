import type { NextConfig } from "next";

const nextConfig: NextConfig = {
  async rewrites() {
    return [
      {
        source: '/api/:path*',
        destination: 'http://4.240.88.100/api/:path*',
      },
    ];
  },
};

export default nextConfig;
