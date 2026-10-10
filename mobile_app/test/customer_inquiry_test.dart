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

    test(
      'InquiryModel handles null attachment arrays safely without crashing',
      () {
        final jsonMap = {
          'id': 'inq-102',
          'inquiryReference': 'INQ-9900',
          'userName': 'Kusum Silva',
          'userRole': 'Customer',
          'subject': 'App Feedback',
          'category': 'Feedback / Suggestion',
          'message': 'Great app experience so far!',
          'priority': 'Normal',
          'status': 'Responded',
          'adminResponse': 'Thank you for your valuable feedback!',
          'createdAt': '2026-10-03T09:00:00Z',
        };

        final inquiry = InquiryModel.fromJson(jsonMap);

        expect(inquiry.attachmentUrls, isEmpty);
        expect(inquiry.attachmentUrls.isEmpty, isTrue);
        expect(inquiry.isResponded, isTrue);
        expect(inquiry.adminResponse, isNotNull);
      },
    );
  });
}
