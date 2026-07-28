import { useMutation, useQuery, useQueryClient } from '@tanstack/react-query';
import api from '../api/client';

export default function TicketsPage() {
  const qc = useQueryClient();
  const { data, isLoading } = useQuery({
    queryKey: ['tickets'],
    queryFn: async () => (await api.get('/tickets?status=open')).data.tickets as any[],
  });

  const close = useMutation({
    mutationFn: (id: string) => api.patch(`/tickets/${id}`, { status: 'closed', adminReply: 'Resolved by admin' }),
    onSuccess: () => qc.invalidateQueries({ queryKey: ['tickets'] }),
  });

  if (isLoading) return <p>Loading tickets...</p>;

  return (
    <div>
      <h1 className="page-title">Support Tickets</h1>
      <div className="card">
        <table className="table">
          <thead><tr><th>User</th><th>Category</th><th>Description</th><th>Status</th><th>Actions</th></tr></thead>
          <tbody>
            {(data || []).map((t) => (
              <tr key={t.id}>
                <td>{t.userId?.slice(0, 8)}</td>
                <td>{t.category}</td>
                <td>{t.description}</td>
                <td>{t.status}</td>
                <td><button className="btn btn-success" onClick={() => close.mutate(t.id)}>Close</button></td>
              </tr>
            ))}
          </tbody>
        </table>
      </div>
    </div>
  );
}
