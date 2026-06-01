'use client';

import { useState } from 'react';
import { useAuth } from '@/components/AuthProvider';
import { Card, CardContent, CardDescription, CardHeader, CardTitle } from '@/components/ui/card';
import { Input } from '@/components/ui/input';
import { Button } from '@/components/ui/button';
import { KeyRound } from 'lucide-react';

export default function LoginPage() {
  const [key, setKey] = useState('');
  const { login } = useAuth();

  const handleLogin = (e: React.FormEvent) => {
    e.preventDefault();
    if (key.trim()) {
      login(key.trim());
    }
  };

  return (
    <div className="min-h-screen flex items-center justify-center bg-black relative overflow-hidden">
      {/* Background decoration */}
      <div className="absolute top-1/2 left-1/2 -translate-x-1/2 -translate-y-1/2 w-[800px] h-[800px] bg-purple-600/20 rounded-full blur-[120px] pointer-events-none" />
      
      <Card className="w-full max-w-md border-border/50 bg-card/50 backdrop-blur-xl relative z-10">
        <CardHeader className="space-y-3 pb-6">
          <div className="w-12 h-12 bg-primary/20 rounded-xl flex items-center justify-center mb-2 border border-primary/30 shadow-[0_0_15px_rgba(168,85,247,0.5)]">
            <KeyRound className="w-6 h-6 text-primary" />
          </div>
          <CardTitle className="text-3xl font-black tracking-tight">Admin Access</CardTitle>
          <CardDescription className="text-base">
            Enter your X-Admin-Key to access the CasinoR control panel.
          </CardDescription>
        </CardHeader>
        <CardContent>
          <form onSubmit={handleLogin} className="space-y-4">
            <div className="space-y-2">
              <Input
                type="password"
                placeholder="ADMIN_API_KEY"
                value={key}
                onChange={(e) => setKey(e.target.value)}
                className="bg-background/50 border-border/50 text-lg h-12 focus-visible:ring-primary/50"
                autoFocus
              />
            </div>
            <Button type="submit" className="w-full h-12 text-base font-bold bg-primary hover:bg-primary/90">
              Authenticate
            </Button>
          </form>
        </CardContent>
      </Card>
    </div>
  );
}
