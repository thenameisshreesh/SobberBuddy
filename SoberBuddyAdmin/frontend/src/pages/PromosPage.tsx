import { FormEvent, useState } from 'react';
import { useMutation, useQuery, useQueryClient } from '@tanstack/react-query';
import api from '../api/client';

export default function PromosPage() {
  const qc = useQueryClient();
  const [form, setForm] = useState({ code: '', type: 'flat', value: '50', maxUses: '100' });
  const { data } = useQuery({
    queryKey: ['promos'],
    queryFn: async () => (await api.get('/promos')).data.promos as any[],
  });

  const create = useMutation({
    mutationFn: () => api.post('/promos', {
      code: form.code,
      type: form.type,
      value: Number(form.value),
      maxUses: Number(form.maxUses),
      isActive: true,
    }),
    onSuccess: () => qc.invalidateQueries({ queryKey: ['promos'] }),
  });

  const onSubmit = (e: FormEvent) => {
    e.preventDefault();
    create.mutate();
  };

  return (
    <div>
      <h1 className="page-title">Promo Codes</h1>
      <form className="card" onSubmit={onSubmit} style={{ display: 'grid', gap: 12, marginBottom: 16 }}>
        <input className="input" placeholder="Code" value={form.code} onChange={(e) => setForm({ ...form, code: e.target.value })} required />
        <select className="input" value={form.type} onChange={(e) => setForm({ ...form, type: e.target.value })}>
          <option value="flat">Flat</option>
          <option value="percentage">Percentage</option>
          <option value="first_ride">First Ride</option>
        </select>
        <input className="input" placeholder="Value" value={form.value} onChange={(e) => setForm({ ...form, value: e.target.value })} />
        <input className="input" placeholder="Max uses" value={form.maxUses} onChange={(e) => setForm({ ...form, maxUses: e.target.value })} />
        <button className="btn btn-primary">Create Promo</button>
      </form>
      <div className="card">
        <table className="table">
          <thead><tr><th>Code</th><th>Type</th><th>Value</th><th>Used</th><th>Active</th></tr></thead>
          <tbody>
            {(data || []).map((p) => (
              <tr key={p.id}>
                <td>{p.id || p.code}</td>
                <td>{p.type}</td>
                <td>{p.value}</td>
                <td>{p.usedCount ?? 0}/{p.maxUses ?? '-'}</td>
                <td>{p.isActive ? 'Yes' : 'No'}</td>
              </tr>
            ))}
          </tbody>
        </table>
      </div>
    </div>
  );
}
