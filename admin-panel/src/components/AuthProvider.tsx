'use client';

import { createContext, useContext, useEffect, useState } from 'react';
import { useRouter, usePathname } from 'next/navigation';
import { api } from '@/lib/api';

interface AuthContextType {
  isAdmin: boolean;
  login: (key: string) => void;
  logout: () => void;
}

const AuthContext = createContext<AuthContextType | undefined>(undefined);

export function AuthProvider({ children }: { children: React.ReactNode }) {
  const [isAdmin, setIsAdmin] = useState(false);
  const [loading, setLoading] = useState(true);
  const router = useRouter();
  const pathname = usePathname();

  useEffect(() => {
    // Check auth status by attempting to fetch stats.
    // If we have a valid HttpOnly cookie session, it will succeed.
    api.getStats()
      .then(() => {
        setIsAdmin(true);
      })
      .catch(() => {
        setIsAdmin(false);
        if (pathname !== '/login') {
          router.push('/login');
        }
      })
      .finally(() => {
        setLoading(false);
      });
  }, [pathname, router]);

  const login = async (key: string) => {
    try {
      await api.login(key);
      setIsAdmin(true);
      router.push('/');
    } catch (err: any) {
      alert(err.message || 'Invalid API key');
    }
  };

  const logout = async () => {
    try {
      await api.logout();
    } catch (err) {
      console.error('Logout error:', err);
    } finally {
      setIsAdmin(false);
      router.push('/login');
    }
  };

  if (loading) {
    return <div className="h-screen w-screen flex items-center justify-center bg-black"><div className="animate-pulse text-white">Loading...</div></div>;
  }

  return (
    <AuthContext.Provider value={{ isAdmin, login, logout }}>
      {children}
    </AuthContext.Provider>
  );
}

export function useAuth() {
  const context = useContext(AuthContext);
  if (context === undefined) {
    throw new Error('useAuth must be used within an AuthProvider');
  }
  return context;
}
