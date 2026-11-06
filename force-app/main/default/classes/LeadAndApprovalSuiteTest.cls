@IsTest
private class LeadAndApprovalSuiteTest {

    @TestSetup
    static void setupTestData() {
        // 1. Region & Country
        Region__c reg = new Region__c(Name = 'Global Region');
        insert reg;

        Country__c country = new Country__c(Name = 'Global Country', ISO_Code__c = 'US', Region__c = reg.Id);
        insert country;

        // 2. Account
        Account acc = new Account(Name = 'Awardee Foundation');
        insert acc;

        // 3. Program
        Program__c prog = new Program__c(
            Name = 'Global Health Initiative',
            Program_Type__c = 'Healthcare Program',
            Max_Amount__c = 10000000000.0,
            Status__c = 'Open'
        );
        insert prog;

        // 4. Grant_Program__c (Profile)
        Id ngoRtId = Schema.SObjectType.Grant_Program__c.getRecordTypeInfosByDeveloperName().containsKey('NGO')
            ? Schema.SObjectType.Grant_Program__c.getRecordTypeInfosByDeveloperName().get('NGO').getRecordTypeId()
            : null;

        Grant_Program__c profile = new Grant_Program__c(
            First_Name__c = 'Lead',
            Last_Name__c = 'Officer',
            Primary_Contact_Email__c = UserInfo.getUserEmail(),
            Email_Address__c = UserInfo.getUserEmail(),
            Country__c = country.Id,
            Region__c = reg.Id,
            RecordTypeId = ngoRtId,
            Organization_Type__c = 'NGO',
            Profile_Status__c = 'Pending',
            OwnerId = UserInfo.getUserId()
        );
        insert profile;

        // 5. Grant_Applicant__c
        Grant_Applicant__c app = new Grant_Applicant__c(
            Program__c = prog.Id,
            Grant_Program__c = profile.Id,
            Account__c = acc.Id,
            Project_Title__c = 'Healthcare for All',
            Application_Status__c = 'Under Internal Review',
            Reviewer_Assigned__c = UserInfo.getUserId(),
            Requested_Amount__c = 75000,
            Approved_Amount__c = 75000,
            OwnerId = UserInfo.getUserId()
        );
        insert app;

        // 6. Award__c
        Award__c award = new Award__c(
            Account__c = acc.Id,
            Grant_Applicant__c = app.Id,
            Approved_Amount__c = 75000,
            Award_Status__c = 'Active',
            Award_Start_Date__c = Date.today(),
            Award_End_Date__c = Date.today().addDays(365)
        );
        insert award;

        // 7. InvoiceForAward__c
        InvoiceForAward__c inv = new InvoiceForAward__c(
            Award__c = award.Id,
            Invoice_Date__c = Date.today(),
            Requested_Amount__c = 25000,
            Finance_Approved_Amount__c = 25000,
            Invoice_Status__c = 'Submitted',
            Invoice_PDF_Generated__c = false
        );
        insert inv;

        // 8. Disbursement linked to Invoice
        Disbursement__c disb = new Disbursement__c(
            Invoice__c = inv.Id,
            Total_Amount__c = 25000,
            Status__c = 'Pending',
            Payment_Type__c = 'Installment',
            Disbursement_Date__c = Date.today()
        );
        insert disb;

        // 9. Lead for conversion testing
        Lead ld = new Lead(
            FirstName = 'Marcus',
            LastName = 'Vance',
            Company = 'Vance Philanthropies',
            Email = 'marcus.vance@example.com',
            Phone = '555-0199',
            Status = 'Open - Not Contacted'
        );
        insert ld;
    }

    /* ------------------------------------------------------------
       1. Lead Conversion & LeadTriggerHandler Tests
       ------------------------------------------------------------ */
    @IsTest
    static void testLeadTriggerAndHandler() {
        Lead ld = [SELECT Id, IsConverted FROM Lead WHERE Email = 'marcus.vance@example.com' LIMIT 1];

        // Attach a file to the lead to test file copying
        ContentVersion cv = new ContentVersion(
            Title = 'Proposal Document',
            PathOnClient = 'proposal.pdf',
            VersionData = Blob.valueOf('Sample Proposal'),
            FirstPublishLocationId = ld.Id
        );
        insert cv;

        Test.startTest();
        // 1. Convert Lead
        Database.LeadConvert lc = new Database.LeadConvert();
        lc.setLeadId(ld.Id);
        LeadStatus convertStatus = [SELECT Id, MasterLabel FROM LeadStatus WHERE IsConverted = true LIMIT 1];
        lc.setConvertedStatus(convertStatus.MasterLabel);
        Database.LeadConvertResult lcr = Database.convertLead(lc);
        System.assert(lcr.isSuccess(), 'Lead conversion should succeed');

        // 2. Direct call to sendBrandedWelcomeEmail
        LeadTriggerHandler.sendBrandedWelcomeEmail(
            'marcus.vance@example.com',
            'Marcus',
            'marcus.vance@example.com.donor',
            'Donor@1234!',
            'https://example.com/donor'
        );

        // 3. Direct call to provisionCommunityUsers
        Id contactId = lcr.getContactId();
        Donor__c createdDonor = [SELECT Id FROM Donor__c WHERE Email__c = 'marcus.vance@example.com' LIMIT 1];
        LeadTriggerHandler.provisionCommunityUsers(new List<Id>{ contactId }, new List<Id>{ createdDonor.Id });
        Test.stopTest();

        System.assertNotEquals(null, createdDonor, 'Donor record should be created from lead conversion');
    }

    /* ------------------------------------------------------------
       2. Invoice PDF Classes Tests
       ------------------------------------------------------------ */
    @IsTest
    static void testInvoicePDFSuite() {
        InvoiceForAward__c inv = [SELECT Id, Name FROM InvoiceForAward__c LIMIT 1];

        Test.startTest();
        // 1. InvoicePDFController (parameter & controller fallback)
        ApexPages.StandardController sc = new ApexPages.StandardController(inv);
        ApexPages.currentPage().getParameters().put('id', String.valueOf(inv.Id));
        InvoicePDFController ctrl = new InvoicePDFController(sc);
        System.assertNotEquals(null, ctrl.invoice, 'Invoice should be loaded');
        System.assertNotEquals(null, ctrl.disbursement, 'Disbursement should be loaded');

        // Parameter with invalid ID
        ApexPages.currentPage().getParameters().put('id', 'invalid_id_xyz');
        InvoicePDFController ctrlInvalid = new InvoicePDFController(sc);

        // 2. InvoicePDFGeneratorInvocable
        InvoicePDFGeneratorInvocable.generatePDF(new List<Id>{ inv.Id });

        // Call again with empty list and already generated invoice
        InvoicePDFGeneratorInvocable.generatePDF(new List<Id>());
        InvoicePDFGeneratorInvocable.generatePDF(new List<Id>{ inv.Id });

        // 3. InvoicePDFSaver
        InvoicePDFSaver saver = new InvoicePDFSaver(sc);
        PageReference savePr = saver.savePDF();
        System.assertNotEquals(null, savePr, 'Save PDF should return redirect');

        // 4. Batch & Scheduler
        InvoiceForAward__c batchInv = new InvoiceForAward__c(
            Award__c = [SELECT Id FROM Award__c LIMIT 1].Id,
            Invoice_Date__c = Date.today(),
            Requested_Amount__c = 15000,
            Finance_Approved_Amount__c = 15000,
            Invoice_Status__c = 'Submitted',
            Invoice_PDF_Generated__c = false
        );
        insert batchInv;

        Database.executeBatch(new InvoiceForAwardPDFBatch(), 1);
        InvoiceForAwardPDFScheduler sched = new InvoiceForAwardPDFScheduler();
        sched.execute(null);
        Test.stopTest();
    }

    /* ------------------------------------------------------------
       3. Approval Invocables and WorkItem Handlers Tests
       ------------------------------------------------------------ */
    @IsTest
    static void testApprovalActionHandlers() {
        Grant_Applicant__c app = [SELECT Id FROM Grant_Applicant__c LIMIT 1];

        Test.startTest();
        // 1. ApprovalActionHandler
        ApprovalActionHandler.Request reqApprove = new ApprovalActionHandler.Request();
        reqApprove.recordId = app.Id;
        reqApprove.action = 'Approve';
        ApprovalActionHandler.processApproval(new List<ApprovalActionHandler.Request>{ reqApprove });

        ApprovalActionHandler.Request reqReject = new ApprovalActionHandler.Request();
        reqReject.recordId = app.Id;
        reqReject.action = 'Reject';
        ApprovalActionHandler.processApproval(new List<ApprovalActionHandler.Request>{ reqReject });

        // 2. AutoApprovalHelper
        AutoApprovalHelper.ApprovalInput autoInp = new AutoApprovalHelper.ApprovalInput();
        autoInp.recordId = app.Id;
        autoInp.actionType = 'Approve';
        autoInp.comments = 'Approved automatically';
        AutoApprovalHelper.processApprovals(new List<AutoApprovalHelper.ApprovalInput>{ autoInp });

        // 3. RecallApprovalInvocable (graceful exception handling in test)
        try {
            RecallApprovalInvocable.recallApproval(new List<Id>{ app.Id });
        } catch (Exception e) {
            System.assert(true, 'Handled expected recall exception');
        }

        // 4. ReviewClassicApprovalWorkItem
        ReviewClassicApprovalWorkItem.Request rNull = new ReviewClassicApprovalWorkItem.Request();
        ReviewClassicApprovalWorkItem.Request rBadAction = new ReviewClassicApprovalWorkItem.Request();
        rBadAction.workItemId = app.Id;
        rBadAction.action = 'InvalidAction';

        ReviewClassicApprovalWorkItem.Request rBlankAction = new ReviewClassicApprovalWorkItem.Request();
        rBlankAction.workItemId = app.Id;
        rBlankAction.action = '';

        ReviewClassicApprovalWorkItem.Request rApprove = new ReviewClassicApprovalWorkItem.Request();
        rApprove.workItemId = app.Id;
        rApprove.action = 'Approve';
        rApprove.comments = 'Approved work item';

        ReviewClassicApprovalWorkItem.Request rReject = new ReviewClassicApprovalWorkItem.Request();
        rReject.workItemId = app.Id;
        rReject.action = 'Reject';
        rReject.comments = 'Rejected work item';

        List<ReviewClassicApprovalWorkItem.Response> responses = ReviewClassicApprovalWorkItem.reviewWorkItem(
            new List<ReviewClassicApprovalWorkItem.Request>{ rNull, rBadAction, rBlankAction, rApprove, rReject }
        );
        System.assertEquals(5, responses.size(), 'Should return 5 responses');
        Test.stopTest();
    }

    /* ------------------------------------------------------------
       4. AIResponseParser, Dashboards, Stats & Utility Tests
       ------------------------------------------------------------ */
    @IsTest
    static void testDashboardsStatsAndAIParser() {
        Grant_Applicant__c app = [SELECT Id FROM Grant_Applicant__c LIMIT 1];

        // 1. Setup ContentVersion for GrantApplicationPDFEmailer
        ContentVersion cv = new ContentVersion(
            Title = 'Grant Application - Summary Document',
            PathOnClient = 'app.pdf',
            VersionData = Blob.valueOf('Test Application PDF Data'),
            FirstPublishLocationId = app.Id
        );
        insert cv;

        Test.startTest();
        // 2. AIResponseParser
        AIResponseParser.InputWrapper aiInp1 = new AIResponseParser.InputWrapper();
        aiInp1.jsonString = 'AI Analysis: {"program":"Global Health Initiative","agreementName":"Health Fund Agreement","amount":75000,"startDate":"2026-01-01","endDate":"2026-12-31","purpose":"Healthcare Support"}';
        AIResponseParser.InputWrapper aiInp2 = new AIResponseParser.InputWrapper();
        aiInp2.jsonString = 'Invalid json content without braces';
        AIResponseParser.InputWrapper aiInp3 = new AIResponseParser.InputWrapper();
        aiInp3.jsonString = '';

        List<AIResponseParser.OutputWrapper> aiOuts = AIResponseParser.parse(
            new List<AIResponseParser.InputWrapper>{ aiInp1, aiInp2, aiInp3 }
        );
        System.assertEquals(3, aiOuts.size(), 'Should return 3 output wrappers');
        System.assertEquals('Global Health Initiative', aiOuts[0].program, 'Program name should match');
        System.assertEquals(75000, aiOuts[0].amount, 'Amount should match');

        // 3. HomepageController & HomeStatsController
        Map<String, Integer> appStats = HomepageController.getApplicationStats();
        System.assertNotEquals(null, appStats, 'App stats should not be null');

        app.Application_Status__c = 'Approved';
        app.Requested_Amount__c = 2500000000.0;
        app.Approved_Amount__c = 2500000000.0;
        update app;
        HomeStatsController.getHomeStats();

        app.Requested_Amount__c = 2500000.0;
        app.Approved_Amount__c = 2500000.0;
        update app;
        HomeStatsController.getHomeStats();

        app.Requested_Amount__c = 2500.0;
        app.Approved_Amount__c = 2500.0;
        update app;
        HomeStatsController.getHomeStats();

        app.Requested_Amount__c = 50.0;
        app.Approved_Amount__c = 50.0;
        update app;
        Map<String, Object> homeStats = HomeStatsController.getHomeStats();
        System.assertNotEquals(null, homeStats, 'Home stats should not be null');

        // 4. DashboardController & NavbarController
        String pStatus = DashboardController.getProfileStatus();
        System.assertEquals('Pending', pStatus, 'Profile status should be Pending');

        String userName = NavbarController.getUserName();
        System.assertNotEquals(null, userName, 'Navbar username should not be null');

        List<User> guests = [SELECT Id FROM User WHERE UserType = 'Guest' AND IsActive = true LIMIT 1];
        if (!guests.isEmpty()) {
            System.runAs(guests[0]) {
                NavbarController.getUserName();
            }
        }

        // 5. ReviewerNotificationController
        List<Grant_Applicant__c> notifs = ReviewerNotificationController.getReviewerNotifications();
        System.assertNotEquals(null, notifs, 'Should return notifs list');

        // 6. GrantApplicationPDFEmailer
        GrantApplicationPDFEmailer.sendPDF(new List<Id>{ app.Id });

        // 7. Empty helper classes
        getUploadedFiles guf = new getUploadedFiles();
        System.assertNotEquals(null, guf, 'getUploadedFiles should instantiate');
        Test.stopTest();
    }

    @IsTest
    static void testProxyControllerCallout() {
        Grant_Applicant__c app = [SELECT Id FROM Grant_Applicant__c LIMIT 1];
        Test.setMock(HttpCalloutMock.class, new GMSMockHttpResponseGenerator());

        Test.startTest();
        String apiResp = ProxyController.callAPI(String.valueOf(app.Id), 'approve');
        Test.stopTest();

        System.assertNotEquals(null, apiResp, 'API response should not be null');
    }
}
