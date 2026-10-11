import http from 'k6/http';
import { check, sleep } from 'k6';

// k6 Performance & Concurrency Load Test Configuration
export const options = {
  stages: [
    { duration: '5s', target: 10 },  // Ramp-up to 10 VUs
    { duration: '15s', target: 50 }, // Steady load at 50 VUs
    { duration: '5s', target: 0 },   // Ramp-down
  ],
  thresholds: {
    // 95% of successful requests over cloud network complete below 3000ms
    'http_req_duration': ['p(95)<3000'],
    // Checks success rate >= 90%
    'checks': ['rate>0.90'],
  },
};

const BASE_URL = __ENV.BASE_URL || 'http://localhost:5298';

export default function () {
  const headers = {
    'Content-Type': 'application/json',
  };

  // Test 1: Providers Catalog Search / Latency
  const resProviders = http.get(`${BASE_URL}/api/providers`, { headers });
  check(resProviders, {
    'GET /api/providers responds with valid HTTP status (200, 401, 204)': (r) => 
      r.status === 200 || r.status === 401 || r.status === 204,
  });

  // Test 2: AI Planning Agent / Service Requests Endpoint Latency
  const planPayload = JSON.stringify({
    description: 'Kitchen sink pipe repair and faucet installation',
    location: 'Colombo 05',
    estimatedBudget: 5000,
  });

  const resPlan = http.post(`${BASE_URL}/api/requests`, planPayload, { headers });
  check(resPlan, {
    'POST /api/requests completes safely (201, 200, 400, 401)': (r) => 
      r.status === 201 || r.status === 200 || r.status === 400 || r.status === 401,
  });

  sleep(1);
}
