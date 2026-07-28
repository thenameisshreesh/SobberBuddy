import { FormEvent, useState } from 'react';
import { QRCodeSVG } from 'qrcode.react';
import { useMutation, useQuery, useQueryClient } from '@tanstack/react-query';
import api from '../api/client';

export default function PartnersPage() {
  const qc = useQueryClient();
  const [form, setForm] = useState({ name: '', contact: '', commissionRate: '10' });
  const [selectedQr, setSelectedQr] = useState('');
  const { data } = useQuery({
    queryKey: ['partners'],
    queryFn: async () => (await api.get('/partners')).data.partners as any[],
  });

  const create = useMutation({
    mutationFn: () => api.post('/partners', {
      name: form.name,
      contact: form.contact,
      commissionRate: Number(form.commissionRate),
    }),
    onSuccess: () => qc.invalidateQueries({ queryKey: ['partners'] }),
  });

  const onSubmit = (e: FormEvent) => {
    e.preventDefault();
    create.mutate();
  };

  return (
    <div>
      <h1 className="page-title">Partners & QR</h1>
      <form className="card" onSubmit={onSubmit} style={{ display: 'grid', gap: 12, marginBottom: 16 }}>
        <input className="input" placeholder="Venue name" value={form.name} onChange={(e) => setForm({ ...form, name: e.target.value })} required />
        <input className="input" placeholder="Contact" value={form.contact} onChange={(e) => setForm({ ...form, contact: e.target.value })} />
        <input className="input" placeholder="Commission %" value={form.commissionRate} onChange={(e) => setForm({ ...form, commissionRate: e.target.value })} />
        <button className="btn btn-primary">Add Partner</button>
      </form>
      <div className="card">
        <table className="table">
          <thead><tr><th>Name</th><th>Contact</th><th>Commission</th><th>QR</th></tr></thead>
          <tbody>
            {(data || []).map((p) => {
              const qr = `soberbuddy://partner/${p.id}`;
              return (
                <tr key={p.id}>
                  <td>{p.name}</td>
                  <td>{p.contact}</td>
                  <td>{p.commissionRate}%</td>
                  <td><button className="btn btn-secondary" onClick={() => setSelectedQr(qr)}>Show QR</button></td>
                </tr>
              );
            })}
          </tbody>
        </table>
      </div>
      {selectedQr && (
        <div className="card" style={{ marginTop: 16, textAlign: 'center' }}>
          <QRCodeSVG value={selectedQr} size={180} />
          <p className="muted">{selectedQr}</p>
        </div>
      )}
    </div>
  );
}
