import http from 'k6/http';
import { check, sleep } from 'k6';

// TC-PERF-02: Stress Test to Peak Concurrency (Ramp up to 100 VUs)
export const options = {
  stages: [
    { duration: '5s', target: 30 },   // Warm-up to 30 VUs
    { duration: '15s', target: 100 }, // Peak stress at 100 VUs
    { duration: '5s', target: 0 },    // Cooldown ramp-down
  ],
  thresholds: {
    // Under peak load over cloud network, checks must pass and p95 under 3.5s
    'http_req_duration': ['p(95)<3500'],
    'checks': ['rate>0.90'],
  },
};

const BASE_URL = __ENV.BASE_URL || 'http://localhost:5298';

export default function () {
  const headers = { 'Content-Type': 'application/json' };

  // Hit the Providers endpoint under heavy load
  const res = http.get(`${BASE_URL}/api/providers`, { headers });
  
  check(res, {
    'Providers API responds safely': (r) => 
      r.status === 200 || r.status === 401 || r.status === 204,
  });

  sleep(0.5);
}
