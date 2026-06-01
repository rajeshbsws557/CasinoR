'use client';

import { createContext, useContext, useEffect, useState } from 'react';
import { useRouter, usePathname } from 'next/navigation';

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
    const key = localStorage.getItem('admin_key');
    if (key) {
      setIsAdmin(true);
    } else {
      setIsAdmin(false);
      if (pathname !== '/login') {
        router.push('/login');
      }
    }
    setLoading(false);
  }, [pathname, router]);

  const login = (key: string) => {
    localStorage.setItem('admin_key', key);
    setIsAdmin(true);
    router.push('/');
  };

  const logout = () => {
    localStorage.removeItem('admin_key');
    setIsAdmin(false);
    router.push('/login');
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
