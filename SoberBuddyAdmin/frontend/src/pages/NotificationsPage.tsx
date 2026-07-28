import { FormEvent, useState } from 'react';
import { useMutation, useQuery } from '@tanstack/react-query';
import api from '../api/client';

export default function NotificationsPage() {
  const [form, setForm] = useState({ title: 'SoberBuddy', body: '', audience: 'all' });
  const { data } = useQuery({
    queryKey: ['notifications-history'],
    queryFn: async () => (await api.get('/notifications/history')).data.campaigns as any[],
  });

  const broadcast = useMutation({
    mutationFn: () => api.post('/notifications/broadcast', form),
  });

  const onSubmit = (e: FormEvent) => {
    e.preventDefault();
    broadcast.mutate();
  };

  return (
    <div>
      <h1 className="page-title">Promotional Notifications</h1>
      <form className="card" onSubmit={onSubmit} style={{ display: 'grid', gap: 12, marginBottom: 16 }}>
        <input className="input" placeholder="Title" value={form.title} onChange={(e) => setForm({ ...form, title: e.target.value })} />
        <textarea className="input" placeholder="Message" value={form.body} onChange={(e) => setForm({ ...form, body: e.target.value })} required />
        <select className="input" value={form.audience} onChange={(e) => setForm({ ...form, audience: e.target.value })}>
          <option value="all">All</option>
          <option value="riders">Riders</option>
          <option value="drivers">Drivers</option>
        </select>
        <button className="btn btn-primary">Send Broadcast</button>
        {broadcast.data && <p className="muted">Sent: {broadcast.data.data.sent}, Errors: {broadcast.data.data.errors}</p>}
      </form>
      <div className="card">
        <table className="table">
          <thead><tr><th>Title</th><th>Audience</th><th>Sent</th><th>Created</th></tr></thead>
          <tbody>
            {(data || []).map((n) => (
              <tr key={n.id}>
                <td>{n.title}</td>
                <td>{n.audience}</td>
                <td>{n.sentCount}</td>
                <td>{n.createdAt}</td>
              </tr>
            ))}
          </tbody>
        </table>
      </div>
    </div>
  );
}
