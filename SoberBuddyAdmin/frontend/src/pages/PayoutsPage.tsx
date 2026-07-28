import { FormEvent, useState } from 'react';
import { useMutation, useQuery, useQueryClient } from '@tanstack/react-query';
import api from '../api/client';

export default function PayoutsPage() {
  const qc = useQueryClient();
  const [form, setForm] = useState({ driverId: '', amount: '', period: 'weekly' });
  const { data } = useQuery({
    queryKey: ['payouts'],
    queryFn: async () => (await api.get('/payouts')).data.payouts as any[],
  });

  const create = useMutation({
    mutationFn: () => api.post('/payouts', {
      driverId: form.driverId,
      amount: Number(form.amount),
      period: form.period,
    }),
    onSuccess: () => qc.invalidateQueries({ queryKey: ['payouts'] }),
  });

  const markPaid = useMutation({
    mutationFn: (id: string) => api.post(`/payouts/${id}/mark-paid`),
    onSuccess: () => qc.invalidateQueries({ queryKey: ['payouts'] }),
  });

  const onSubmit = (e: FormEvent) => {
    e.preventDefault();
    create.mutate();
  };

  return (
    <div>
      <h1 className="page-title">Driver Payouts</h1>
      <form className="card" onSubmit={onSubmit} style={{ display: 'grid', gap: 12, marginBottom: 16 }}>
        <input className="input" placeholder="Driver UID" value={form.driverId} onChange={(e) => setForm({ ...form, driverId: e.target.value })} required />
        <input className="input" placeholder="Amount INR" value={form.amount} onChange={(e) => setForm({ ...form, amount: e.target.value })} required />
        <input className="input" placeholder="Period" value={form.period} onChange={(e) => setForm({ ...form, period: e.target.value })} />
        <button className="btn btn-primary">Create Payout</button>
      </form>
      <div className="card">
        <table className="table">
          <thead><tr><th>Driver</th><th>Amount</th><th>Period</th><th>Status</th><th>Actions</th></tr></thead>
          <tbody>
            {(data || []).map((p) => (
              <tr key={p.id}>
                <td>{p.driverId?.slice(0, 8)}</td>
                <td>₹{p.amount}</td>
                <td>{p.period}</td>
                <td>{p.status}</td>
                <td>
                  {p.status !== 'completed' && (
                    <button className="btn btn-success" onClick={() => markPaid.mutate(p.id)}>Mark Paid</button>
                  )}
                </td>
              </tr>
            ))}
          </tbody>
        </table>
      </div>
    </div>
  );
}
