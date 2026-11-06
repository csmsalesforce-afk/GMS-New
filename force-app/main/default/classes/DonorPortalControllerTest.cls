@IsTest
public class DonorPortalControllerTest {

    @TestSetup
    static void setupTestData() {
        // Create Program
        Program__c prog = new Program__c(
            Name = 'Donor Test Program',
            Program_Fund__c = 500000,
            Max_Amount__c = 10000000000.0,
            Status__c = 'Open'
        );
        insert prog;

        // Create Donor Campaign
        Donor_Campaign__c camp = new Donor_Campaign__c(
            Name = 'Test Clean Water Campaign',
            Program__c = prog.Id,
            Active__c = true,
            Expected_Revenue_in_Campaign__c = 50000,
            Status__c = 'In Progress'
        );
        insert camp;

        // Create Donor record for current user
        Donor__c d = new Donor__c(
            Donor_Name__c = 'Current Test Donor',
            Donor_Type__c = 'Corporate',
            Email__c = UserInfo.getUserEmail(),
            Status__c = 'Active',
            User__c = UserInfo.getUserId(),
            Compliance_Status__c = 'Pending',
            KYC_Verified__c = false
        );
        insert d;
    }

    @IsTest
    static void testGetActiveCampaignsAndStats() {
        Test.startTest();
        List<Map<String, Object>> campaigns = DonorPortalController.getActiveCampaigns();
        Map<String, Object> stats = DonorPortalController.getDonorPlatformStats();
        Test.stopTest();

        System.assertNotEquals(0, campaigns.size(), 'Should return active campaigns');
        System.assertNotEquals(null, stats.get('activeCampaigns'), 'Should return stats');
    }

    @IsTest
    static void testSubmitDonationAndTrigger() {
        Donor_Campaign__c camp = [SELECT Id FROM Donor_Campaign__c LIMIT 1];

        Map<String, Object> payload = new Map<String, Object>{
            'campaignId' => camp.Id,
            'amount' => 150.00,
            'donorName' => 'Alice Donor',
            'donorEmail' => 'alice@example.com',
            'donorPhone' => '555-1234',
            'donorMessage' => 'Happy to support!',
            'stripeSessionId' => 'sess_123',
            'stripePaymentIntentId' => 'pi_123'
        };

        Test.startTest();
        Map<String, Object> result = DonorPortalController.submitDonation(payload);
        Map<String, Object> details = DonorPortalController.getCampaignDetails(camp.Id);
        Test.stopTest();

        System.assertEquals(true, result.get('success'), 'Donation should be successful');
        System.assertNotEquals(null, result.get('receiptNumber'), 'Receipt number must be generated');

        // Verify donation record was created
        Donations__c createdDonation = [SELECT Id, Donation_Amount__c FROM Donations__c WHERE Receipt_Number__c = :(String)result.get('receiptNumber') LIMIT 1];
        System.assertEquals(150.00, createdDonation.Donation_Amount__c);
    }

    @IsTest
    static void testSubmitLeadInquiry() {
        Donor_Campaign__c camp = [SELECT Id FROM Donor_Campaign__c LIMIT 1];

        Map<String, Object> payload = new Map<String, Object>{
            'campaignId' => camp.Id,
            'firstName' => 'Bob',
            'lastName' => 'Inquirer',
            'email' => 'bob@example.com',
            'phone' => '555-4321',
            'company' => 'Inquiry Corp',
            'estimatedAmount' => 5000,
            'message' => 'Interested in corporate partnership'
        };

        Test.startTest();
        Map<String, Object> result = DonorPortalController.submitLeadInquiry(payload);
        Test.stopTest();

        System.assertEquals(true, result.get('success'), 'Lead submission should succeed');
        System.assertNotEquals(null, result.get('leadId'), 'Lead ID must be returned');

        Lead createdLead = [SELECT Id, FirstName, LastName, LeadSource FROM Lead WHERE Email = 'bob@example.com' LIMIT 1];
        System.assertEquals('Bob', createdLead.FirstName);
        System.assertEquals('Inquirer', createdLead.LastName);
    }

    @IsTest
    static void testGetDonorProfileStatusAndSubmit() {
        Donor__c d = [SELECT Id, Compliance_Status__c, KYC_Verified__c FROM Donor__c WHERE User__c = :UserInfo.getUserId() LIMIT 1];
        d.Compliance_Status__c = 'Approved';
        d.KYC_Verified__c = true;
        update d;

        Test.startTest();
        Map<String, Object> statusMap = DonorPortalController.getDonorProfileStatus();
        System.assertEquals('Approved', statusMap.get('status'), 'Should be Approved for active donor record');
        System.assertEquals(true, statusMap.get('kycVerified'), 'KYC should be verified');
        System.assertEquals(d.Id, statusMap.get('donorId'), 'Should return correct donor record Id');

        d.Compliance_Status__c = 'Pending';
        d.KYC_Verified__c = false;
        update d;

        Map<String, Object> profilePayload = new Map<String, Object>{
            'donorName' => 'Updated Donor Org',
            'donorType' => 'Corporate',
            'email' => UserInfo.getUserEmail(),
            'phone' => '1234567890',
            'address' => '123 Test Ave',
            'preferredFundingType' => 'Mixed',
            'fundingCapacity' => 10000
        };
        Map<String, Object> submitResult = DonorPortalController.submitDonorProfile(profilePayload);
        Test.stopTest();

        System.assertEquals(true, submitResult.get('success'), 'Profile submission should succeed');
        System.assertEquals(d.Id, submitResult.get('donorId'), 'Should update existing donor record rather than duplicate');
    }

    @IsTest
    static void testCampaignDetailsAndRequirements() {
        Donor_Campaign__c camp = [SELECT Id, Program__c FROM Donor_Campaign__c LIMIT 1];

        Test.startTest();
        Map<String, Object> details = DonorPortalController.getCampaignDetails(camp.Id);
        List<Map<String, Object>> reqs = DonorPortalController.getDonorRequirementsForCampaign(camp.Id, camp.Program__c);
        Map<String, Object> accessRes = DonorPortalController.requestCampaignAccess(camp.Id, 'Special Access Needed');
        Test.stopTest();

        System.assertNotEquals(null, details);
        System.assertNotEquals(null, reqs);
        System.assertNotEquals(null, accessRes);
    }

    @IsTest
    static void testStripeCheckoutSessionAndConfirmation() {
        Donor_Campaign__c camp = [SELECT Id FROM Donor_Campaign__c LIMIT 1];
        Donor__c d = [SELECT Id FROM Donor__c WHERE User__c = :UserInfo.getUserId() LIMIT 1];
        GMSMockHttpResponseGenerator.campaignIdOverride = camp.Id;
        GMSMockHttpResponseGenerator.donorIdOverride = d.Id;
        Test.setMock(HttpCalloutMock.class, new GMSMockHttpResponseGenerator());

        Map<String, Object> payload = new Map<String, Object>{
            'campaignId' => camp.Id,
            'amount' => 50.00,
            'frequency' => 'Monthly',
            'donorName' => 'Test Supporter',
            'donorEmail' => UserInfo.getUserEmail(),
            'donorPhone' => '555-0100',
            'designation' => 'General'
        };

        Test.startTest();
        Map<String, Object> sessionResult = DonorPortalController.createStripeCheckoutSession(payload);
        Map<String, Object> confirmResult = DonorPortalController.confirmStripeDonation('cs_test_123');
        // Test alreadyProcessed branch
        Map<String, Object> reconfirmResult = DonorPortalController.confirmStripeDonation('cs_test_123');
        // Negative test cases
        DonorPortalController.confirmStripeDonation('');
        DonorPortalController.createStripeCheckoutSession(null);
        Test.stopTest();

        System.assertNotEquals(null, sessionResult);
        System.assertEquals(true, confirmResult.get('success'));
        System.assertEquals(true, reconfirmResult.get('alreadyProcessed'));
    }

    @IsTest
    static void testDonorGivingHistoryAndCancelRecurring() {
        Donor_Campaign__c camp = [SELECT Id, Program__c FROM Donor_Campaign__c LIMIT 1];
        Donor__c d = [SELECT Id FROM Donor__c WHERE User__c = :UserInfo.getUserId() LIMIT 1];

        Donations__c don = new Donations__c(
            Donor__c = d.Id,
            Donor_Campaign__c = camp.Id,
            Donation_Amount__c = 100,
            Payment_Status__c = 'Paid',
            Frequency__c = 'Monthly',
            Auto_Pay_Status__c = 'Active',
            Stripe_Payment_Intent_ID__c = 'sub_test123'
        );
        insert don;

        Test.setMock(HttpCalloutMock.class, new GMSMockHttpResponseGenerator());

        Test.startTest();
        Map<String, Object> history = DonorPortalController.getDonorGivingHistory();
        Map<String, Object> cancelResult = DonorPortalController.cancelRecurringDonation(don.Id);
        Test.stopTest();

        System.assertNotEquals(null, history);
        System.assertNotEquals(null, cancelResult);
    }

    @IsTest
    static void testDonorDocumentsFlow() {
        Donor__c d = [SELECT Id FROM Donor__c WHERE User__c = :UserInfo.getUserId() LIMIT 1];

        Test.startTest();
        Map<String, Object> reqDocs = DonorPortalController.getRequiredDonorDocuments();
        Map<String, Object> uploadRes = DonorPortalController.uploadDonorKYCDocument('org_registration', 'TestDoc.pdf', EncodingUtil.base64Encode(Blob.valueOf('Test Content')));
        DonorPortalController.deleteDonorKYCDocument(null);
        Map<String, Object> submitDocs = DonorPortalController.submitDonorDocumentsForReview();
        Test.stopTest();

        System.assertNotEquals(null, reqDocs);
        System.assertNotEquals(null, uploadRes);
        System.assertNotEquals(null, submitDocs);
    }
}
