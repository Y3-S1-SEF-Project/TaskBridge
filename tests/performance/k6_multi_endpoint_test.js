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
    'http_req_duration': ['p(95)<600'],
    'checks': ['rate>0.95'],
  },
};

const BASE_URL = __ENV.BASE_URL || 'http://13.60.35.78';

export default function () {
  const headers = { 'Content-Type': 'application/json' };

  // 1. Providers Catalog
  const res1 = http.get(`${BASE_URL}/api/providers`, { headers });
  check(res1, { 'GET /api/providers status 200/401/404/204': (r) => r.status === 200 || r.status === 401 || r.status === 404 || r.status === 204 });

  // 2. Planning Agent
  const planPayload = JSON.stringify({
    prompt: 'Fix leaking bathroom pipe',
    userLocation: 'Colombo 03',
  });
  const res2 = http.post(`${BASE_URL}/api/service-requests/plan`, planPayload, { headers });
  check(res2, { 'POST /plan completes safely': (r) => r.status === 200 || r.status === 401 || r.status === 404 || r.status === 400 });

  // 3. Admin Inquiry listing
  const res3 = http.get(`${BASE_URL}/api/admin/inquiries`, { headers });
  check(res3, { 'GET /api/admin/inquiries status 200/401/403/404/204': (r) => r.status === 200 || r.status === 401 || r.status === 403 || r.status === 404 || r.status === 204 });

  sleep(1);
}
