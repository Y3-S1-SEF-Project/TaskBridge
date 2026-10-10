# Performance & Load Testing (Lead: Ravindu)

## Objective
To evaluate the system's performance, latency, concurrency handling, and responsiveness under synthetic user loads using **k6**.

## Target Metrics / SLAs (Service Level Agreements)
- **Response Time (p95):** < 500ms
- **Throughput:** ~50 Requests Per Second (RPS)
- **Error Rate:** < 1% (Zero unhandled 500 server crashes)
- **Concurrent Users:** 50 Virtual Users (VUs)

## How to Run the k6 Performance Test:
```bash
# Install k6 (if not already installed via winget/choco/brew)
winget install k6 --source winget

# Execute the Load Test
k6 run tests/performance/k6_load_test.js

# Or generate an HTML/JSON performance report:
k6 run --out json=tests/performance/summary.json tests/performance/k6_load_test.js
```

## Viva Demonstration Highlights:
1. Explain the **stages** configured in `k6_load_test.js` (Ramp-up, peak load, ramp-down).
2. Explain **Thresholds** (`p(95) < 500ms` and `rate < 0.01`).
3. Show that AI planning and provider matching API endpoints remain resilient under concurrent load.
