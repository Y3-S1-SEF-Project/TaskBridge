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

  // Kavindu: Providers Management & Search Logic
  describe('Kavindu - Provider Verification & Search Flow', () => {
    test('filters providers by verified status and category', () => {
      const providers = [
        { id: 'p1', name: 'Kamal Perera', category: 'Gardening', isVerified: true, rating: 4.8 },
        { id: 'p2', name: 'Nimal Silva', category: 'Plumbing', isVerified: false, rating: 3.5 },
        { id: 'p3', name: 'Sunil Shantha', category: 'Gardening', isVerified: true, rating: 4.9 },
      ];

      const verifiedGardening = providers.filter(p => p.isVerified && p.category === 'Gardening');
      assert.equal(verifiedGardening.length, 2);
      assert.ok(verifiedGardening.every(p => p.isVerified));
    });

    test('sorts matched providers by highest rating descending', () => {
      const providers = [
        { name: 'Provider A', rating: 4.2 },
        { name: 'Provider B', rating: 4.9 },
        { name: 'Provider C', rating: 4.7 }
      ];

      const sorted = [...providers].sort((a, b) => b.rating - a.rating);
      assert.equal(sorted[0].name, 'Provider B');
      assert.equal(sorted[1].name, 'Provider C');
      assert.equal(sorted[2].name, 'Provider A');
    });
  });

  // Dadallage: Disputes & Bookings Mediation Flow
  describe('Dadallage - Disputes Mediation & Lifecycle Flow', () => {
    test('computes total dispute claim amount across open cases', () => {
      const disputes = [
        { id: 'd1', ref: 'DSP-01', claimAmount: 5000, status: 'Open' },
        { id: 'd2', ref: 'DSP-02', claimAmount: 3500, status: 'Open' },
        { id: 'd3', ref: 'DSP-03', claimAmount: 8000, status: 'Resolved' }
      ];

      const totalOpenClaims = disputes
        .filter(d => d.status === 'Open')
        .reduce((sum, d) => sum + d.claimAmount, 0);

      assert.equal(totalOpenClaims, 8500);
    });

    test('validates resolution transition triggers required admin notes', () => {
      const resolveDispute = (dispute, resolutionSummary, action) => {
        if (!resolutionSummary || resolutionSummary.trim().length < 5) {
          throw new Error('Resolution summary is mandatory (min 5 chars).');
        }
        return {
          ...dispute,
          status: 'Resolved',
          resolutionSummary,
          resolutionAction: action,
          resolvedAt: new Date().toISOString()
        };
      };

      const base = { id: 'd1', status: 'Open' };
      const resolved = resolveDispute(base, 'Refund processed after provider agreement', 'Refund');
      assert.equal(resolved.status, 'Resolved');
      assert.equal(resolved.resolutionAction, 'Refund');

      assert.throws(() => resolveDispute(base, '   ', 'Refund'), /Resolution summary is mandatory/);
    });
  });

  // Alwis: Inquiries & Review Quality Management
  describe('Alwis - Inquiries & Customer Feedback Management', () => {
    test('categorizes urgent support inquiries correctly', () => {
      const inquiries = [
        { id: 'i1', subject: 'App crashed during payment', priority: 'Urgent', status: 'Open' },
        { id: 'i2', subject: 'General inquiry on rates', priority: 'Normal', status: 'Open' },
        { id: 'i3', subject: 'Incorrect invoice amount', priority: 'Urgent', status: 'Responded' }
      ];

      const urgentPending = inquiries.filter(i => i.priority === 'Urgent' && i.status === 'Open');
      assert.equal(urgentPending.length, 1);
      assert.equal(urgentPending[0].id, 'i1');
    });

    test('validates admin response submission updates status to Responded', () => {
      const inquiry = { id: 'i1', status: 'Open', adminResponse: null };
      const respond = (item, responseText) => {
        if (!responseText || !responseText.trim()) throw new Error('Response cannot be empty');
        return { ...item, status: 'Responded', adminResponse: responseText, respondedAt: new Date().toISOString() };
      };

      const updated = respond(inquiry, 'Your invoice was adjusted successfully.');
      assert.equal(updated.status, 'Responded');
      assert.equal(updated.adminResponse, 'Your invoice was adjusted successfully.');
    });
  });
});
