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

export default function DepositsPage() {
  const [deposits, setDeposits] = useState<any[]>([]);
  const [loading, setLoading] = useState(true);
  const [selectedDeposit, setSelectedDeposit] = useState<any>(null);
  const [rejectReason, setRejectReason] = useState('');
  const { isAdmin } = useAuth();

  const loadDeposits = async () => {
    setLoading(true);
    try {
      const data = await api.getPendingDeposits();
      setDeposits(data.deposits);
    } catch (e) {
      console.error(e);
    }
    setLoading(false);
  };

  useEffect(() => {
    if (isAdmin) {
      loadDeposits();
      const interval = setInterval(loadDeposits, 5000);
      return () => clearInterval(interval);
    }
  }, [isAdmin]);

  const handleApprove = async (id: string) => {
    if (!confirm('Approve this deposit? This will credit the user\'s balance.')) return;
    try {
      await api.approveDeposit(id);
      loadDeposits();
    } catch (e: any) {
      alert(e.message);
    }
  };

  const handleReject = async () => {
    if (!selectedDeposit || !rejectReason) return;
    try {
      await api.rejectDeposit(selectedDeposit.id, rejectReason);
      setSelectedDeposit(null);
      setRejectReason('');
      loadDeposits();
    } catch (e: any) {
      alert(e.message);
    }
  };

  if (!isAdmin) return null;

  return (
    <div className="p-8 space-y-6">
      <h1 className="text-3xl font-bold">Pending Deposits</h1>

      <div className="border border-border rounded-lg bg-card">
        <Table>
          <TableHeader>
            <TableRow>
              <TableHead>User</TableHead>
              <TableHead>Method</TableHead>
              <TableHead>TrxID</TableHead>
              <TableHead>Amount</TableHead>
              <TableHead>Time</TableHead>
              <TableHead className="text-right">Actions</TableHead>
            </TableRow>
          </TableHeader>
          <TableBody>
            {loading ? (
              <TableRow><TableCell colSpan={6} className="text-center py-8">Loading...</TableCell></TableRow>
            ) : deposits.length === 0 ? (
              <TableRow><TableCell colSpan={6} className="text-center py-8">No pending deposits</TableCell></TableRow>
            ) : (
              deposits.map((dep) => (
                <TableRow key={dep.id}>
                  <TableCell>
                    <div className="font-medium">{dep.username}</div>
                    <div className="text-xs text-muted-foreground">{dep.email}</div>
                  </TableCell>
                  <TableCell><Badge variant="outline">{dep.method}</Badge></TableCell>
                  <TableCell className="font-mono text-xs">{dep.transactionId}</TableCell>
                  <TableCell className="text-green-500 font-bold">{dep.formattedAmount}</TableCell>
                  <TableCell>{new Date(dep.submittedAt).toLocaleString()}</TableCell>
                  <TableCell className="text-right space-x-2">
                    <Button variant="outline" size="icon" className="text-red-500 hover:text-red-600" onClick={() => setSelectedDeposit(dep)}>
                      <XCircle className="w-5 h-5" />
                    </Button>
                    <Button variant="outline" size="icon" className="text-green-500 hover:text-green-600" onClick={() => handleApprove(dep.id)}>
                      <CheckCircle className="w-5 h-5" />
                    </Button>
                  </TableCell>
                </TableRow>
              ))
            )}
          </TableBody>
        </Table>
      </div>

      <Dialog open={!!selectedDeposit} onOpenChange={() => setSelectedDeposit(null)}>
        <DialogContent>
          <DialogHeader>
            <DialogTitle>Reject Deposit</DialogTitle>
          </DialogHeader>
          <div className="py-4">
            <label className="text-sm font-medium mb-2 block">Reason for Rejection</label>
            <Input
              placeholder="e.g. Invalid Transaction ID, Funds not received"
              value={rejectReason}
              onChange={(e) => setRejectReason(e.target.value)}
            />
          </div>
          <DialogFooter>
            <Button variant="outline" onClick={() => setSelectedDeposit(null)}>Cancel</Button>
            <Button variant="destructive" onClick={handleReject}>Reject Deposit</Button>
          </DialogFooter>
        </DialogContent>
      </Dialog>
    </div>
  );
}
