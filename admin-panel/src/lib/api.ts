const API_URL = '/api/admin';

export class ApiError extends Error {
  constructor(public status: number, message: string) {
    super(message);
    this.name = 'ApiError';
  }
}

function getHeaders(): HeadersInit {
  return {
    'Content-Type': 'application/json',
  };
}

async function handleResponse(response: Response) {
  const data = await response.json();
  if (!response.ok || !data.success) {
    if (response.status === 401 || response.status === 403) {
      if (typeof window !== 'undefined') {
        if (window.location.pathname !== '/login') {
          window.location.href = '/login';
        }
      }
    }
    throw new ApiError(response.status, data.error || 'API Request Failed');
  }
  return data.data;
}

export const api = {
  // Auth
  login: async (key: string) => {
    const res = await fetch(`${API_URL}/login`, {
      method: 'POST',
      headers: getHeaders(),
      body: JSON.stringify({ key }),
      credentials: 'include',
    });
    return handleResponse(res);
  },
  logout: async () => {
    const res = await fetch(`${API_URL}/logout`, {
      method: 'POST',
      headers: getHeaders(),
      credentials: 'include',
    });
    return handleResponse(res);
  },

  // Dashboard
  getStats: async () => {
    const res = await fetch(`${API_URL}/stats`, { 
      headers: getHeaders(),
      credentials: 'include',
    });
    return handleResponse(res);
  },

  // Users
  getUsers: async (page = 1, limit = 50, search = '') => {
    const query = new URLSearchParams();
    query.set('page', page.toString());
    query.set('limit', limit.toString());
    if (search) query.set('search', search);
    
    const res = await fetch(`${API_URL}/users?${query.toString()}`, { 
      headers: getHeaders(),
      credentials: 'include',
    });
    return handleResponse(res);
  },
  updateUserBalance: async (userId: string, amount: number, reason: string) => {
    const res = await fetch(`${API_URL}/users/${userId}/balance`, {
      method: 'POST',
      headers: getHeaders(),
      body: JSON.stringify({ amount, reason }),
      credentials: 'include',
    });
    return handleResponse(res);
  },

  // Deposits
  getPendingDeposits: async (page = 1, limit = 50) => {
    const query = new URLSearchParams();
    query.set('page', page.toString());
    query.set('limit', limit.toString());
    const res = await fetch(`${API_URL}/deposits/pending?${query.toString()}`, { 
      headers: getHeaders(),
      credentials: 'include',
    });
    return handleResponse(res);
  },
  approveDeposit: async (id: string) => {
    const res = await fetch(`${API_URL}/deposits/${id}/approve`, {
      method: 'POST',
      headers: getHeaders(),
      credentials: 'include',
    });
    return handleResponse(res);
  },
  rejectDeposit: async (id: string, reason: string) => {
    const res = await fetch(`${API_URL}/deposits/${id}/reject`, {
      method: 'POST',
      headers: getHeaders(),
      body: JSON.stringify({ reason }),
      credentials: 'include',
    });
    return handleResponse(res);
  },

  // Withdrawals
  getPendingWithdrawals: async (page = 1, limit = 50) => {
    const query = new URLSearchParams();
    query.set('page', page.toString());
    query.set('limit', limit.toString());
    const res = await fetch(`${API_URL}/withdrawals/pending?${query.toString()}`, { 
      headers: getHeaders(),
      credentials: 'include',
    });
    return handleResponse(res);
  },
  completeWithdrawal: async (id: string) => {
    const res = await fetch(`${API_URL}/withdrawals/${id}/complete`, {
      method: 'POST',
      headers: getHeaders(),
      credentials: 'include',
    });
    return handleResponse(res);
  },
  rejectWithdrawal: async (id: string, reason: string) => {
    const res = await fetch(`${API_URL}/withdrawals/${id}/reject`, {
      method: 'POST',
      headers: getHeaders(),
      body: JSON.stringify({ reason }),
      credentials: 'include',
    });
    return handleResponse(res);
  },
};
