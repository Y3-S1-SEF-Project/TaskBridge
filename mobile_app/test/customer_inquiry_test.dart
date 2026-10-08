import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_app/home/models/inquiry_model.dart';

void main() {
  group('Alwis - Customer Inquiry Model & Verification Tests', () {
    test('InquiryModel correctly handles JSON mapping and role checks', () {
      final jsonMap = {
        'id': 'inq-101',
        'inquiryReference': 'INQ-7788',
        'userId': 'user-99',
        'userName': 'Gayantha Jayawardena',
        'userEmail': 'gayantha@example.com',
        'userPhone': '0779988776',
        'userRole': 'Customer',
        'subject': 'Quotation question',
        'category': 'General Inquiry',
        'message': 'Can I request multiple revisions for a job plan?',
        'attachmentUrls': ['https://example.com/doc1.pdf'],
        'priority': 'Normal',
        'status': 'Open',
        'adminResponse': null,
        'respondedByAdminName': null,
        'respondedAt': null,
        'createdAt': '2026-10-02T14:30:00Z',
        'updatedAt': null,
      };

      final inquiry = InquiryModel.fromJson(jsonMap);

      expect(inquiry.id, 'inq-101');
      expect(inquiry.inquiryReference, 'INQ-7788');
      expect(inquiry.isOpen, isTrue);
      expect(inquiry.isResponded, isFalse);
      expect(inquiry.attachmentUrls.isNotEmpty, isTrue);
      expect(inquiry.priority, 'Normal');
    });
  });
}
