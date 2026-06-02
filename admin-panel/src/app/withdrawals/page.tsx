'use client';

import { useEffect, useState } from 'react';
import { api } from '@/lib/api';
import { Table, TableBody, TableCell, TableHead, TableHeader, TableRow } from '@/components/ui/table';
import { Button } from '@/components/ui/button';
import { Badge } from '@/components/ui/badge';
import { Dialog, DialogContent, DialogHeader, DialogTitle, DialogFooter } from '@/components/ui/dialog';
import { Input } from '@/components/ui/input';
import { CheckCircle, XCircle } from 'lucide-react';
import { useAuth } from '@/components/AuthProvider';

export default function WithdrawalsPage() {
  const [withdrawals, setWithdrawals] = useState<any[]>([]);
  const [loading, setLoading] = useState(true);
  const [selectedWithdrawal, setSelectedWithdrawal] = useState<any>(null);
  const [rejectReason, setRejectReason] = useState('');
  const { isAdmin } = useAuth();

  const loadWithdrawals = async () => {
    setLoading(true);
    try {
      const data = await api.getPendingWithdrawals();
      setWithdrawals(data.withdrawals);
    } catch (e) {
      console.error(e);
    }
    setLoading(false);
  };

  useEffect(() => {
    if (isAdmin) {
      loadWithdrawals();
      const interval = setInterval(loadWithdrawals, 5000);
      return () => clearInterval(interval);
    }
  }, [isAdmin]);

  const handleComplete = async (id: string) => {
    if (!confirm('Mark this withdrawal as completed? (Make sure you sent the money first!)')) return;
    try {
      await api.completeWithdrawal(id);
      loadWithdrawals();
    } catch (e: any) {
      alert(e.message);
    }
  };

  const handleReject = async () => {
    if (!selectedWithdrawal || !rejectReason) return;
    try {
      await api.rejectWithdrawal(selectedWithdrawal.id, rejectReason);
      setSelectedWithdrawal(null);
      setRejectReason('');
      loadWithdrawals();
    } catch (e: any) {
      alert(e.message);
    }
  };

  if (!isAdmin) return null;

  return (
    <div className="p-8 space-y-6">
      <h1 className="text-3xl font-bold">Pending Withdrawals</h1>

      <div className="border border-border rounded-lg bg-card">
        <Table>
          <TableHeader>
            <TableRow>
              <TableHead>User</TableHead>
              <TableHead>Method</TableHead>
              <TableHead>Phone Number</TableHead>
              <TableHead>Amount</TableHead>
              <TableHead>Requested Time</TableHead>
              <TableHead className="text-right">Actions</TableHead>
            </TableRow>
          </TableHeader>
          <TableBody>
            {loading ? (
              <TableRow><TableCell colSpan={6} className="text-center py-8">Loading...</TableCell></TableRow>
            ) : withdrawals.length === 0 ? (
              <TableRow><TableCell colSpan={6} className="text-center py-8">No pending withdrawals</TableCell></TableRow>
            ) : (
              withdrawals.map((w) => (
                <TableRow key={w.id}>
                  <TableCell>
                    <div className="font-medium">{w.username}</div>
                    <div className="text-xs text-muted-foreground">{w.email}</div>
                  </TableCell>
                  <TableCell><Badge variant="outline">{w.method}</Badge></TableCell>
                  <TableCell className="font-mono">{w.phoneNumber}</TableCell>
                  <TableCell className="text-amber-500 font-bold">{w.formattedAmount}</TableCell>
                  <TableCell>{new Date(w.requestedAt).toLocaleString()}</TableCell>
                  <TableCell className="text-right space-x-2">
                    <Button variant="outline" size="icon" className="text-red-500 hover:text-red-600" onClick={() => setSelectedWithdrawal(w)}>
                      <XCircle className="w-5 h-5" />
                    </Button>
                    <Button variant="outline" size="icon" className="text-green-500 hover:text-green-600" onClick={() => handleComplete(w.id)}>
                      <CheckCircle className="w-5 h-5" />
                    </Button>
                  </TableCell>
                </TableRow>
              ))
            )}
          </TableBody>
        </Table>
      </div>

      <Dialog open={!!selectedWithdrawal} onOpenChange={() => setSelectedWithdrawal(null)}>
        <DialogContent>
          <DialogHeader>
            <DialogTitle>Reject Withdrawal</DialogTitle>
          </DialogHeader>
          <div className="py-4">
            <label className="text-sm font-medium mb-2 block">Reason for Rejection</label>
            <Input
              placeholder="e.g. Invalid account, Suspected fraud"
              value={rejectReason}
              onChange={(e) => setRejectReason(e.target.value)}
            />
            <p className="text-xs text-muted-foreground mt-2">Rejecting will automatically refund the user's balance.</p>
          </div>
          <DialogFooter>
            <Button variant="outline" onClick={() => setSelectedWithdrawal(null)}>Cancel</Button>
            <Button variant="destructive" onClick={handleReject}>Reject & Refund</Button>
          </DialogFooter>
        </DialogContent>
      </Dialog>
    </div>
  );
}
