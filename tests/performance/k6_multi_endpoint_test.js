import http from 'k6/http';
import { check, sleep } from 'k6';

// TC-PERF-03: Multi-Endpoint Concurrency Test (50 VUs across Catalog, AI Planning, Inquiries)
export const options = {
  stages: [
    { duration: '5s', target: 20 },
    { duration: '20s', target: 50 },
    { duration: '5s', target: 0 },
  ],
  thresholds: {
    'http_req_duration': ['p(95)<3500'],
    'checks': ['rate>0.95'],
  },
};

const BASE_URL = __ENV.BASE_URL || 'http://localhost:5298';

export default function () {
  const headers = { 'Content-Type': 'application/json' };

  // 1. Providers Catalog
  const res1 = http.get(`${BASE_URL}/api/providers`, { headers });
  check(res1, { 'GET /api/providers status 200/401/204': (r) => r.status === 200 || r.status === 401 || r.status === 204 });

  // 2. Planning Agent / Service Requests
  const planPayload = JSON.stringify({
    description: 'Fix leaking bathroom pipe',
    location: 'Colombo 03',
  });
  const res2 = http.post(`${BASE_URL}/api/requests`, planPayload, { headers });
  check(res2, { 'POST /api/requests completes safely (201, 200, 400, 401)': (r) => 
    r.status === 201 || r.status === 200 || r.status === 401 || r.status === 400 
  });

  // 3. Admin Inquiry listing
  const res3 = http.get(`${BASE_URL}/api/admin/inquiries`, { headers });
  check(res3, { 'GET /api/admin/inquiries status 200/401/403/204': (r) => r.status === 200 || r.status === 401 || r.status === 403 || r.status === 204 });

  sleep(1);
}
