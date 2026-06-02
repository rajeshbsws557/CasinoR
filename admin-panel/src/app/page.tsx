'use client';

import { useEffect, useState } from 'react';
import { api } from '@/lib/api';
import { Card, CardContent, CardHeader, CardTitle } from '@/components/ui/card';
import { Users, ArrowDownToLine, ArrowUpFromLine, Activity } from 'lucide-react';
import { useAuth } from '@/components/AuthProvider';

interface Stats {
  totalUsers: number;
  totalDeposits: number;
  totalWithdrawals: number;
  pendingDeposits: number;
  pendingWithdrawals: number;
  formattedTotalDeposits: string;
  formattedTotalWithdrawals: string;
}

export default function DashboardPage() {
  const [stats, setStats] = useState<Stats | null>(null);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState('');
  const { isAdmin } = useAuth();

  useEffect(() => {
    if (!isAdmin) return;
    
    const loadData = () => {
      api.getStats()
        .then(setStats)
        .catch((err) => setError(err.message))
        .finally(() => setLoading(false));
    };

    loadData();
    const interval = setInterval(loadData, 5000);
    return () => clearInterval(interval);
  }, [isAdmin]);

  if (!isAdmin) return null;

  if (loading) return <div className="p-8">Loading stats...</div>;
  if (error) return <div className="p-8 text-red-500">Error: {error}</div>;
  if (!stats) return null;

  return (
    <div className="p-8 space-y-6">
      <h1 className="text-3xl font-bold">Dashboard Overview</h1>
      
      <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-4 gap-6">
        <StatCard
          title="Total Users"
          value={stats.totalUsers.toString()}
          icon={Users}
          description="Registered players"
        />
        <StatCard
          title="Total Deposits"
          value={stats.formattedTotalDeposits}
          icon={ArrowDownToLine}
          description="Approved deposits"
        />
        <StatCard
          title="Total Withdrawals"
          value={stats.formattedTotalWithdrawals}
          icon={ArrowUpFromLine}
          description="Processed withdrawals"
        />
        <StatCard
          title="Pending Actions"
          value={(stats.pendingDeposits + stats.pendingWithdrawals).toString()}
          icon={Activity}
          description={`${stats.pendingDeposits} deps, ${stats.pendingWithdrawals} wds`}
          alert={stats.pendingDeposits + stats.pendingWithdrawals > 0}
        />
      </div>
      
      <div className="grid grid-cols-1 lg:grid-cols-2 gap-6 mt-8">
        <Card className="bg-card">
          <CardHeader>
            <CardTitle>System Status</CardTitle>
          </CardHeader>
          <CardContent>
            <div className="space-y-4">
              <div className="flex items-center justify-between border-b border-border pb-4">
                <span className="text-muted-foreground">API Connection</span>
                <span className="text-green-500 font-medium flex items-center gap-2">
                  <div className="w-2 h-2 rounded-full bg-green-500 animate-pulse" />
                  Online
                </span>
              </div>
              <div className="flex items-center justify-between border-b border-border pb-4">
                <span className="text-muted-foreground">Database</span>
                <span className="text-green-500 font-medium">Connected</span>
              </div>
            </div>
          </CardContent>
        </Card>
      </div>
    </div>
  );
}

function StatCard({ title, value, icon: Icon, description, alert }: any) {
  return (
    <Card className={`bg-card ${alert ? 'border-amber-500/50 shadow-[0_0_15px_rgba(245,158,11,0.1)]' : ''}`}>
      <CardHeader className="flex flex-row items-center justify-between pb-2">
        <CardTitle className="text-sm font-medium text-muted-foreground">{title}</CardTitle>
        <Icon className={`w-4 h-4 ${alert ? 'text-amber-500' : 'text-muted-foreground'}`} />
      </CardHeader>
      <CardContent>
        <div className={`text-2xl font-bold ${alert ? 'text-amber-500' : ''}`}>{value}</div>
        <p className="text-xs text-muted-foreground mt-1">{description}</p>
      </CardContent>
    </Card>
  );
}
