import { useMutation, useQuery, useQueryClient } from '@tanstack/react-query';
import api from '../api/client';

export default function SosPage() {
  const qc = useQueryClient();
  const { data, isLoading } = useQuery({
    queryKey: ['sos'],
    queryFn: async () => (await api.get('/sos?status=active')).data.events as any[],
  });

  const resolve = useMutation({
    mutationFn: (id: string) => api.post(`/sos/${id}/resolve`),
    onSuccess: () => qc.invalidateQueries({ queryKey: ['sos'] }),
  });

  if (isLoading) return <p>Loading SOS events...</p>;

  return (
    <div>
      <h1 className="page-title">SOS Center</h1>
      <div className="card">
        <table className="table">
          <thead><tr><th>Trip</th><th>User</th><th>Type</th><th>Location</th><th>Actions</th></tr></thead>
          <tbody>
            {(data || []).map((e) => (
              <tr key={e.id}>
                <td>{e.tripId?.slice(0, 8)}</td>
                <td>{e.userId?.slice(0, 8)}</td>
                <td>{e.userType}</td>
                <td>{e.latitude}, {e.longitude}</td>
                <td><button className="btn btn-success" onClick={() => resolve.mutate(e.id)}>Resolve</button></td>
              </tr>
            ))}
          </tbody>
        </table>
      </div>
    </div>
  );
}
