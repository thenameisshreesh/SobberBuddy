import { useMutation, useQuery, useQueryClient } from '@tanstack/react-query';
import api from '../api/client';

export default function DriversPage() {
  const qc = useQueryClient();
  const { data, isLoading } = useQuery({
    queryKey: ['drivers'],
    queryFn: async () => (await api.get('/drivers')).data.drivers as any[],
  });

  const approve = useMutation({
    mutationFn: (id: string) => api.post(`/drivers/${id}/approve-docs`, { notes: 'Approved by admin' }),
    onSuccess: () => qc.invalidateQueries({ queryKey: ['drivers'] }),
  });
  const reject = useMutation({
    mutationFn: (id: string) => api.post(`/drivers/${id}/reject-docs`, { notes: 'Rejected by admin' }),
    onSuccess: () => qc.invalidateQueries({ queryKey: ['drivers'] }),
  });
  const offline = useMutation({
    mutationFn: (id: string) => api.post(`/drivers/${id}/force-offline`),
    onSuccess: () => qc.invalidateQueries({ queryKey: ['drivers'] }),
  });

  if (isLoading) return <p>Loading drivers...</p>;

  return (
    <div>
      <h1 className="page-title">Drivers</h1>
      <div className="card">
        <table className="table">
          <thead>
            <tr>
              <th>Name</th>
              <th>Phone</th>
              <th>Status</th>
              <th>Docs</th>
              <th>Online</th>
              <th>Actions</th>
            </tr>
          </thead>
          <tbody>
            {(data || []).map((d) => (
              <tr key={d.id}>
                <td>{d.name}</td>
                <td>{d.phone}</td>
                <td>{d.documentStatus || 'pending'}</td>
                <td>
                  {d.documents ? (
                    <div style={{ display: 'flex', gap: 8, flexWrap: 'wrap' }}>
                      {Object.entries(d.documents).map(([k, url]) => (
                        <a key={k} href={String(url)} target="_blank" rel="noreferrer">{k}</a>
                      ))}
                    </div>
                  ) : '-'}
                </td>
                <td>{d.isAvailable ? 'Yes' : 'No'}</td>
                <td style={{ display: 'flex', gap: 8, flexWrap: 'wrap' }}>
                  {d.documentStatus !== 'approved' && (
                    <button className="btn btn-success" onClick={() => approve.mutate(d.id)}>Approve</button>
                  )}
                  {d.documentStatus !== 'rejected' && (
                    <button className="btn btn-danger" onClick={() => reject.mutate(d.id)}>Reject</button>
                  )}
                  {d.isAvailable && (
                    <button className="btn btn-secondary" onClick={() => offline.mutate(d.id)}>Force Offline</button>
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
