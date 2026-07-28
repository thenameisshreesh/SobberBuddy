import { useMutation, useQuery, useQueryClient } from '@tanstack/react-query';
import api from '../api/client';

export default function ScheduledPage() {
  const qc = useQueryClient();
  const { data, isLoading } = useQuery({
    queryKey: ['scheduled'],
    queryFn: async () => (await api.get('/scheduled')).data.trips as any[],
  });

  const dispatch = useMutation({
    mutationFn: () => api.post('/scheduled/dispatch'),
    onSuccess: () => qc.invalidateQueries({ queryKey: ['scheduled'] }),
  });

  if (isLoading) return <p>Loading scheduled trips...</p>;

  return (
    <div>
      <h1 className="page-title">Scheduled Bookings</h1>
      <button className="btn btn-primary" style={{ marginBottom: 16 }} onClick={() => dispatch.mutate()}>Trigger Dispatch</button>
      <div className="card">
        <table className="table">
          <thead><tr><th>ID</th><th>Status</th><th>Scheduled At</th><th>Pickup</th><th>Dropoff</th></tr></thead>
          <tbody>
            {(data || []).map((t) => (
              <tr key={t.id}>
                <td>{t.id.slice(0, 8)}</td>
                <td>{t.status}</td>
                <td>{t.scheduledAt}</td>
                <td>{t.pickup}</td>
                <td>{t.dropoff}</td>
              </tr>
            ))}
          </tbody>
        </table>
      </div>
    </div>
  );
}
