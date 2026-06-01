'use client';

import Link from 'next/link';
import { usePathname } from 'next/navigation';
import { LayoutDashboard, Users, ArrowDownToLine, ArrowUpFromLine, LogOut } from 'lucide-react';
import { useAuth } from './AuthProvider';

const navItems = [
  { href: '/', label: 'Dashboard', icon: LayoutDashboard },
  { href: '/users', label: 'Players', icon: Users },
  { href: '/deposits', label: 'Deposits', icon: ArrowDownToLine },
  { href: '/withdrawals', label: 'Withdrawals', icon: ArrowUpFromLine },
];

export function Sidebar() {
  const pathname = usePathname();
  const { isAdmin, logout } = useAuth();

  if (!isAdmin || pathname === '/login') return null;

  return (
    <div className="w-64 border-r border-border bg-card flex flex-col">
      <div className="p-6">
        <h1 className="text-2xl font-black bg-gradient-to-r from-purple-500 to-indigo-500 bg-clip-text text-transparent">
          CasinoR Admin
        </h1>
        <p className="text-xs text-muted-foreground mt-1">Superuser Access</p>
      </div>

      <nav className="flex-1 px-4 space-y-2 mt-4">
        {navItems.map((item) => {
          const isActive = pathname === item.href;
          const Icon = item.icon;
          return (
            <Link
              key={item.href}
              href={item.href}
              className={`flex items-center space-x-3 px-3 py-2.5 rounded-lg transition-colors ${
                isActive
                  ? 'bg-primary/10 text-primary font-medium'
                  : 'text-muted-foreground hover:bg-muted hover:text-foreground'
              }`}
            >
              <Icon className={`w-5 h-5 ${isActive ? 'text-primary' : ''}`} />
              <span>{item.label}</span>
            </Link>
          );
        })}
      </nav>

      <div className="p-4 border-t border-border">
        <button
          onClick={logout}
          className="flex items-center space-x-3 px-3 py-2.5 w-full rounded-lg text-red-500 hover:bg-red-500/10 transition-colors"
        >
          <LogOut className="w-5 h-5" />
          <span>Logout</span>
        </button>
      </div>
    </div>
  );
}
