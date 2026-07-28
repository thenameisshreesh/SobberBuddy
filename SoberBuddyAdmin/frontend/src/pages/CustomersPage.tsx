import { useMutation, useQuery, useQueryClient } from '@tanstack/react-query';
import api from '../api/client';

export default function CustomersPage() {
  const qc = useQueryClient();
  const { data, isLoading } = useQuery({
    queryKey: ['customers'],
    queryFn: async () => (await api.get('/customers')).data.customers as any[],
  });

  const unblock = useMutation({
    mutationFn: (id: string) => api.post(`/customers/${id}/unblock`),
    onSuccess: () => qc.invalidateQueries({ queryKey: ['customers'] }),
  });

  if (isLoading) return <p>Loading customers...</p>;

  return (
    <div>
      <h1 className="page-title">Customers</h1>
      <div className="card">
        <table className="table">
          <thead>
            <tr><th>Name</th><th>Mobile</th><th>Blocked</th><th>Cancellations</th><th>Actions</th></tr>
          </thead>
          <tbody>
            {(data || []).map((c) => (
              <tr key={c.id}>
                <td>{c.name}</td>
                <td>{c.mobile || c.phone}</td>
                <td>{c.isBlocked ? <span className="badge badge-error">Blocked</span> : 'No'}</td>
                <td>{c.cancellationCount ?? 0}</td>
                <td>
                  {c.isBlocked && (
                    <button className="btn btn-success" onClick={() => unblock.mutate(c.id)}>Unblock</button>
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
