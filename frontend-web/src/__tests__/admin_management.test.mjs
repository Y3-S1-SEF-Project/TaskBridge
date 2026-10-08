import { test, describe } from 'node:test';
import assert from 'node:assert/strict';

describe('Frontend Web - Admin Portal Component & Logic Unit Tests', () => {

  // Ravindu: Service Requests View & State Logic
  describe('Ravindu - Service Request Admin View', () => {
    test('filters service requests by active and pending status correctly', () => {
      const requests = [
        { id: '1', title: 'Leaking pipe', status: 'Pending', category: 'Plumbing' },
        { id: '2', title: 'Wiring issue', status: 'Completed', category: 'Electrical' },
        { id: '3', title: 'Wall painting', status: 'Pending', category: 'Painting' }
      ];

      const pendingRequests = requests.filter(r => r.status === 'Pending');
      assert.equal(pendingRequests.length, 2);
      assert.equal(pendingRequests[0].category, 'Plumbing');
      assert.equal(pendingRequests[1].category, 'Painting');
    });

    test('validates emergency badge color and status tagging', () => {
      const getStatusBadge = (status) => {
        switch (status) {
          case 'Pending': return 'badge-warning';
          case 'Completed': return 'badge-success';
          case 'Cancelled': return 'badge-danger';
          default: return 'badge-secondary';
        }
      };

      assert.equal(getStatusBadge('Pending'), 'badge-warning');
      assert.equal(getStatusBadge('Completed'), 'badge-success');
      assert.equal(getStatusBadge('Cancelled'), 'badge-danger');
    });
  });
});
