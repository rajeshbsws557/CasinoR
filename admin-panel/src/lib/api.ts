const API_URL = process.env.NEXT_PUBLIC_API_URL || 'http://4.240.88.100/api/admin';

export class ApiError extends Error {
  constructor(public status: number, message: string) {
    super(message);
    this.name = 'ApiError';
  }
}

function getHeaders(): HeadersInit {
  const token = typeof window !== 'undefined' ? localStorage.getItem('admin_key') : null;
  return {
    'Content-Type': 'application/json',
    ...(token ? { 'X-Admin-Key': token } : {}),
  };
}

async function handleResponse(response: Response) {
  const data = await response.json();
  if (!response.ok || !data.success) {
    if (response.status === 401 || response.status === 403) {
      if (typeof window !== 'undefined') {
        localStorage.removeItem('admin_key');
        window.location.href = '/login';
      }
    }
    throw new ApiError(response.status, data.error || 'API Request Failed');
  }
  return data.data;
}

export const api = {
  // Dashboard
  getStats: async () => {
    const res = await fetch(`${API_URL}/stats`, { headers: getHeaders() });
    return handleResponse(res);
  },

  // Users
  getUsers: async (page = 1, limit = 50, search = '') => {
    const url = new URL(`${API_URL}/users`);
    url.searchParams.set('page', page.toString());
    url.searchParams.set('limit', limit.toString());
    if (search) url.searchParams.set('search', search);
    
    const res = await fetch(url.toString(), { headers: getHeaders() });
    return handleResponse(res);
  },
  updateUserBalance: async (userId: string, amount: number, reason: string) => {
    const res = await fetch(`${API_URL}/users/${userId}/balance`, {
      method: 'POST',
      headers: getHeaders(),
      body: JSON.stringify({ amount, reason }),
    });
    return handleResponse(res);
  },

  // Deposits
  getPendingDeposits: async (page = 1, limit = 50) => {
    const url = new URL(`${API_URL}/deposits/pending`);
    url.searchParams.set('page', page.toString());
    url.searchParams.set('limit', limit.toString());
    const res = await fetch(url.toString(), { headers: getHeaders() });
    return handleResponse(res);
  },
  approveDeposit: async (id: string) => {
    const res = await fetch(`${API_URL}/deposits/${id}/approve`, {
      method: 'POST',
      headers: getHeaders(),
    });
    return handleResponse(res);
  },
  rejectDeposit: async (id: string, reason: string) => {
    const res = await fetch(`${API_URL}/deposits/${id}/reject`, {
      method: 'POST',
      headers: getHeaders(),
      body: JSON.stringify({ reason }),
    });
    return handleResponse(res);
  },

  // Withdrawals
  getPendingWithdrawals: async (page = 1, limit = 50) => {
    const url = new URL(`${API_URL}/withdrawals/pending`);
    url.searchParams.set('page', page.toString());
    url.searchParams.set('limit', limit.toString());
    const res = await fetch(url.toString(), { headers: getHeaders() });
    return handleResponse(res);
  },
  completeWithdrawal: async (id: string) => {
    const res = await fetch(`${API_URL}/withdrawals/${id}/complete`, {
      method: 'POST',
      headers: getHeaders(),
    });
    return handleResponse(res);
  },
  rejectWithdrawal: async (id: string, reason: string) => {
    const res = await fetch(`${API_URL}/withdrawals/${id}/reject`, {
      method: 'POST',
      headers: getHeaders(),
      body: JSON.stringify({ reason }),
    });
    return handleResponse(res);
  },
};
