import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_app/home/models/dispute_model.dart';

void main() {
  group('Dadallage - Customer Dispute Model & Workflow Tests', () {
    test('DisputeItem JSON serialization and deserialization retains data integrity', () {
      final jsonMap = {
        'id': 'disp-001',
        'disputeReference': 'DSP-9988',
        'bookingId': 'book-123',
        'bookingReference': 'PR-4455',
        'customerId': 'cust-01',
        'customerName': 'Saman Kumara',
        'customerPhone': '0771122334',
        'providerId': 'prov-02',
        'providerName': 'Kasun Silva',
        'serviceTitle': 'Bathroom Tile Grouting',
        'category': 'Masonry',
        'feeAmount': 6000.0,
        'reasonCategory': 'Poor Quality',
        'description': 'Tiles became loose after one day.',
        'desiredResolution': 'Free Revision / Rework',
        'beforePhotoUrls': ['https://example.com/b1.jpg'],
        'afterPhotoUrls': ['https://example.com/a1.jpg'],
        'customerEvidencePhotoUrls': ['https://example.com/e1.jpg'],
        'status': 'PendingAdminReview',
        'resolutionSummary': null,
        'resolutionAction': null,
        'resolvedByAdminName': null,
        'resolvedAt': null,
        'createdAt': '2026-10-01T10:00:00Z',
      };

      final dispute = DisputeItem.fromJson(jsonMap);

      expect(dispute.id, 'disp-001');
      expect(dispute.disputeReference, 'DSP-9988');
      expect(dispute.feeAmount, 6000.0);
      expect(dispute.reasonCategory, 'Poor Quality');
      expect(dispute.isPending, isTrue);
      expect(dispute.isResolved, isFalse);
      expect(dispute.beforePhotoUrls.isNotEmpty, isTrue);
    });

    test('Dispute status helper getters report correct lifecycle states', () {
      final baseItem = DisputeItem(
        id: 'disp-002',
        disputeReference: 'DSP-5544',
        bookingReference: 'PR-1122',
        customerName: 'Nimali Fonseka',
        providerName: 'Anura Bandara',
        serviceTitle: 'Pipe Fix',
        category: 'Plumbing',
        feeAmount: 3500.0,
        reasonCategory: 'Work Incomplete',
        description: 'Main pipe was not sealed properly.',
        desiredResolution: 'Refund Full Amount',
        beforePhotoUrls: const [],
        afterPhotoUrls: const [],
        customerEvidencePhotoUrls: const [],
        status: 'Resolved',
        createdAt: DateTime.now(),
      );

      expect(baseItem.isResolved, isTrue);
      expect(baseItem.isPending, isFalse);
      expect(baseItem.beforePhotoUrls.isEmpty, isTrue);
    });
  });
}
