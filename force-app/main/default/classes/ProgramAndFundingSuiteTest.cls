@IsTest
private class ProgramAndFundingSuiteTest {

    @TestSetup
    static void setupTestData() {
        // 1. Region & Country
        Region__c reg = new Region__c(Name = 'Global Region');
        insert reg;

        Country__c country = new Country__c(Name = 'Global Country', ISO_Code__c = 'US', Region__c = reg.Id);
        insert country;

        // 2. Account & Contact
        Account acc = new Account(Name = 'Test Organization');
        insert acc;

        Contact con = new Contact(FirstName = 'Test', LastName = 'Donor', Email = 'testdonor@example.com', AccountId = acc.Id);
        insert con;

        // 3. Program
        Program__c prog = new Program__c(
            Name = 'Education Program 2026',
            Program_Type__c = 'Education Program',
            Status__c = 'Open',
            Program_Fund__c = 500000,
            Max_Amount__c = 10000000000.0,
            Start_Date__c = Date.today(),
            End_Date__c = Date.today().addDays(90),
            Overview__c = 'Test Overview',
            Requirements__c = 'Test Requirements'
        );
        insert prog;

        // 4. Program Eligibility & Document
        Program_Eligibility__c pe = new Program_Eligibility__c(
            Name = 'Eligibility Criteria 1',
            Program__c = prog.Id
        );
        insert pe;

        Program_Document__c pd1 = new Program_Document__c(
            Name = 'Tax Exemption',
            Program__c = prog.Id,
            Applies_To__c = 'Applicant',
            Is_Mandatory__c = true,
            Description__c = 'Upload tax doc'
        );
        Program_Document__c pd2 = new Program_Document__c(
            Name = 'Annual Report',
            Program__c = prog.Id,
            Applies_To__c = 'Both',
            Is_Mandatory__c = false,
            Description__c = 'Upload report'
        );
        insert new List<Program_Document__c>{ pd1, pd2 };

        // 5. Grant Applicant
        Grant_Applicant__c app = new Grant_Applicant__c(
            Program__c = prog.Id,
            Account__c = acc.Id,
            Application_Status__c = 'Approved',
            Requested_Amount__c = 50000,
            Total_Funding_Request__c = 2,
            Approved_Requests__c = 0,
            Rejected_Requests__c = 0
        );
        insert app;

        // 6. Donor linked to running user
        Donor__c donor = new Donor__c(
            Donor_Name__c = 'Test Donor User',
            Email__c = 'testdonor@example.com',
            Donor_Type__c = 'Individual',
            User__c = UserInfo.getUserId(),
            Contact__c = con.Id,
            Country__c = country.Id,
            Region__c = reg.Id
        );
        insert donor;

        // 7. Donor Agreement
        Donor_Agreement__c da = new Donor_Agreement__c(
            Agreement_Name__c = 'Education Fund Agreement',
            Donor__c = donor.Id,
            Program__c = prog.Id,
            Agreement_Amount__c = 100000,
            Status__c = 'Draft',
            Funding_Purpose__c = 'Education Support',
            Start_Date__c = Date.today(),
            End_Date__c = Date.today().addDays(365)
        );
        insert da;

        // 8. Funding Requests
        Funding_Request__c fr1 = new Funding_Request__c(
            Donor__c = donor.Id,
            Donor_Agreement__c = da.Id,
            Grant_Applicant__c = app.Id,
            Requested_Amount_FR__c = 20000,
            Status__c = 'Pending',
            Justification__c = 'First Tranche'
        );
        Funding_Request__c fr2 = new Funding_Request__c(
            Donor__c = donor.Id,
            Donor_Agreement__c = da.Id,
            Grant_Applicant__c = app.Id,
            Requested_Amount_FR__c = 30000,
            Status__c = 'Pending',
            Justification__c = 'Second Tranche'
        );
        insert new List<Funding_Request__c>{ fr1, fr2 };

        // 9. Funding Allocation, Installment, and Disbursement
        Funding_Allocation__c fa = new Funding_Allocation__c(
            Grant_Applicant__c = app.Id,
            Donor__c = donor.Id,
            Donor_Agreement__c = da.Id,
            Approved_Amount__c = 50000,
            Percentage__c = 100,
            Status__c = 'Approved'
        );
        insert fa;

        Installment__c inst = new Installment__c(
            Grant_Applicant__c = app.Id,
            Funding_Allocation__c = fa.Id,
            Amount__c = 25000,
            Percentage__c = 50,
            Due_Date__c = Date.today().addDays(30),
            Status__c = 'Pending'
        );
        insert inst;

        Disbursement__c disb = new Disbursement__c(
            Installment__c = inst.Id,
            Total_Amount__c = 25000,
            Status__c = 'Pending',
            Payment_Type__c = 'Installment',
            Disbursement_Date__c = Date.today()
        );
        insert disb;
    }

    /* ------------------------------------------------------------
       1. GrantProgramController Tests
       ------------------------------------------------------------ */
    @IsTest
    static void testGrantProgramController() {
        Program__c prog = [SELECT Id FROM Program__c LIMIT 1];

        Test.startTest();
        List<GrantProgramController.ProgramWrapper> programs = GrantProgramController.getPrograms();
        List<Grant_Applicant__c> apps = GrantProgramController.getApplicationsByProgram(prog.Id);

        // Run as Reviewer, Program Officer, Finance to cover pending status mappings
        List<Profile> roleProfiles = [SELECT Id, Name FROM Profile WHERE Name IN ('Reviewer', 'Program Officer', 'Finance')];
        Integer idx = 1;
        for (Profile p : roleProfiles) {
            User roleUser = new User(
                Username = 'grant_prog_user' + idx + '@grant360test.org',
                Email = 'grantprog' + idx + '@example.com',
                LastName = 'RoleUser' + idx,
                Alias = 'gprog' + idx,
                ProfileId = p.Id,
                TimeZoneSidKey = 'America/New_York',
                LocaleSidKey = 'en_US',
                EmailEncodingKey = 'UTF-8',
                LanguageLocaleKey = 'en_US'
            );
            insert roleUser;
            System.runAs(roleUser) {
                GrantProgramController.getPrograms();
                GrantProgramController.getApplicationsByProgram(prog.Id);
            }
            idx++;
        }
        Test.stopTest();

        System.assertNotEquals(null, programs, 'Programs list should not be null');
        System.assert(programs.size() > 0, 'Should return at least one program wrapper');
        System.assertEquals(1, programs[0].approved, 'Approved count should match aggregate');
        System.assertNotEquals(null, apps, 'Applications list should not be null');
    }

    /* ------------------------------------------------------------
       2. GrantProgramsController & ProgramListController Tests
       ------------------------------------------------------------ */
    @IsTest
    static void testGrantProgramsAndListControllers() {
        Program__c prog = [SELECT Id FROM Program__c LIMIT 1];

        Test.startTest();
        List<Program__c> openPrograms = GrantProgramsController.getPrograms();
        Map<String, Object> progDetails = GrantProgramsController.getProgramById(prog.Id);
        List<Program_Document__c> docs = GrantProgramsController.getProgramDocuments(prog.Id);

        List<Program__c> allList = ProgramListController.getPrograms('All');
        List<Program__c> eduList = ProgramListController.getPrograms('Education Program');
        List<Program__c> blankList = ProgramListController.getPrograms('');
        Test.stopTest();

        System.assert(openPrograms.size() > 0, 'Open programs should not be empty');
        System.assertNotEquals(null, progDetails.get('program'), 'Program details should contain program');
        System.assertEquals(2, docs.size(), 'Should find 2 program documents');
        System.assert(allList.size() > 0, 'ProgramListController All should return programs');
        System.assert(eduList.size() > 0, 'ProgramListController filter should return programs');
        System.assert(blankList.size() > 0, 'ProgramListController blank should return programs');
    }

    /* ------------------------------------------------------------
       3. ProgramAPI REST Service Tests
       ------------------------------------------------------------ */
    @IsTest
    static void testProgramAPI() {
        // Case 1: All programs
        RestRequest req1 = new RestRequest();
        RestResponse res1 = new RestResponse();
        req1.requestURI = '/services/apexrest/programs/';
        req1.httpMethod = 'GET';
        req1.params.put('type', 'All');
        RestContext.request = req1;
        RestContext.response = res1;

        Test.startTest();
        ProgramAPI.getPrograms();
        String json1 = res1.responseBody.toString();

        // Case 2: Specific type
        RestRequest req2 = new RestRequest();
        RestResponse res2 = new RestResponse();
        req2.requestURI = '/services/apexrest/programs/';
        req2.httpMethod = 'GET';
        req2.params.put('type', 'Education Program');
        RestContext.request = req2;
        RestContext.response = res2;
        ProgramAPI.getPrograms();
        String json2 = res2.responseBody.toString();
        Test.stopTest();

        System.assert(json1.contains('Education Program 2026'), 'Response should contain program name');
        System.assert(json2.contains('Education Program 2026'), 'Response should contain program name');
    }

    /* ------------------------------------------------------------
       4. FundingRequestAction & DonorDashboardController Funding Tests
       ------------------------------------------------------------ */
    @IsTest
    static void testFundingRequestActions() {
        List<Funding_Request__c> frList = [
            SELECT Id, Status__c, Grant_Applicant__c 
            FROM Funding_Request__c 
            ORDER BY Requested_Amount_FR__c ASC
        ];
        Funding_Request__c fr1 = frList[0];
        Funding_Request__c fr2 = frList[1];

        // 1. REST GET with missing parameters
        RestRequest reqMissing = new RestRequest();
        RestResponse resMissing = new RestResponse();
        reqMissing.requestURI = '/services/apexrest/fundingAction/';
        reqMissing.httpMethod = 'GET';
        RestContext.request = reqMissing;
        RestContext.response = resMissing;
        FundingRequestAction.handleAction();
        System.assert(resMissing.responseBody.toString().contains('Missing parameters'), 'Should report missing parameters');

        // 2. Process first request via handleAction REST
        RestRequest reqValid = new RestRequest();
        RestResponse resValid = new RestResponse();
        reqValid.requestURI = '/services/apexrest/fundingAction/';
        reqValid.httpMethod = 'GET';
        reqValid.params.put('id', fr1.Id);
        reqValid.params.put('action', 'approve');
        RestContext.request = reqValid;
        RestContext.response = resValid;

        Test.startTest();
        FundingRequestAction.handleAction();
        System.assert(resValid.responseBody.toString().contains('Success'), 'Action should succeed');

        // 3. Process second request via DonorDashboardController to test delegation and completion
        DonorDashboardController.updateFundingRequest(fr2.Id, 'reject');
        Test.stopTest();

        Funding_Request__c updatedFr1 = [SELECT Status__c FROM Funding_Request__c WHERE Id = :fr1.Id];
        Funding_Request__c updatedFr2 = [SELECT Status__c FROM Funding_Request__c WHERE Id = :fr2.Id];
        System.assertEquals('Approved', updatedFr1.Status__c, 'First request should be approved');
        System.assertEquals('Rejected', updatedFr2.Status__c, 'Second request should be rejected');

        Grant_Applicant__c app = [SELECT Application_Status__c, Approved_Amount__c FROM Grant_Applicant__c WHERE Id = :fr1.Grant_Applicant__c];
        System.assertEquals('Revision Requested', app.Application_Status__c, 'Status should be Revision Requested when all processed');
        System.assertEquals(20000, app.Approved_Amount__c, 'Approved amount should match approved request');

        // 4. Test error handling on already processed
        try {
            FundingRequestAction.processFundingRequestAction((String)fr1.Id, 'approve');
            System.assert(false, 'Should throw exception for already processed request');
        } catch (Exception ex) {
            System.assert(ex.getMessage().contains('Already processed'), 'Expected Already processed exception');
        }

        // 5. Test invalid action error
        Funding_Request__c frNew = new Funding_Request__c(
            Donor__c = [SELECT Id FROM Donor__c LIMIT 1].Id,
            Donor_Agreement__c = [SELECT Id FROM Donor_Agreement__c LIMIT 1].Id,
            Grant_Applicant__c = app.Id,
            Requested_Amount_FR__c = 1000,
            Status__c = 'Pending'
        );
        insert frNew;
        try {
            FundingRequestAction.processFundingRequestAction((String)frNew.Id, 'invalidAction');
            System.assert(false, 'Should throw exception for invalid action');
        } catch (Exception ex) {
            System.assert(ex.getMessage().contains('Invalid action'), 'Expected Invalid action exception');
        }
    }

    /* ------------------------------------------------------------
       5. FundUtilizationController Tests
       ------------------------------------------------------------ */
    @IsTest
    static void testFundUtilizationController() {
        Grant_Applicant__c app = [SELECT Id FROM Grant_Applicant__c LIMIT 1];
        Disbursement__c disb = [SELECT Id, Status__c FROM Disbursement__c LIMIT 1];
        disb.Status__c = 'Paid';
        update disb;

        // Create ContentVersion
        ContentVersion cv = new ContentVersion(
            Title = 'Test Receipt',
            PathOnClient = 'receipt.pdf',
            VersionData = Blob.valueOf('Test receipt file content'),
            IsMajorVersion = true
        );
        insert cv;
        Id docId = [SELECT ContentDocumentId FROM ContentVersion WHERE Id = :cv.Id].ContentDocumentId;

        Test.startTest();
        // 1. getApplicantAndDisbursement
        Map<String, Object> disbInfo = FundUtilizationController.getApplicantAndDisbursement(app.Id);
        System.assertEquals(true, disbInfo.get('hasDisbursement'), 'Disbursement should be found');

        // Negative check
        Map<String, Object> emptyDisb = FundUtilizationController.getApplicantAndDisbursement(UserInfo.getUserId());
        System.assertEquals(false, emptyDisb.get('hasDisbursement'), 'Disbursement should not be found');

        // 2. createFundUtilization
        Id fuId = FundUtilizationController.createFundUtilization(app.Id, disb.Id, new List<Id>{ docId });
        System.assertNotEquals(null, fuId, 'Fund utilization record should be created');

        // 3. linkFilesToRecord
        FundUtilizationController.linkFilesToRecord(disb.Id, new List<Id>{ docId });

        // 4. getApplicationDisbrustmentFiles
        List<Map<String, Object>> files = FundUtilizationController.getApplicationDisbrustmentFiles(app.Id);
        System.assert(files.size() > 0, 'Should find files for applicant fund utilization');

        // 5. getInstallmentsAndDisbursements
        Map<String, Object> overview = FundUtilizationController.getInstallmentsAndDisbursements(app.Id);
        System.assertEquals(true, overview.get('hasData'), 'Should return installment and disbursement data');

        // 6. uploadUtilizationCertificate
        String base64Data = EncodingUtil.base64Encode(Blob.valueOf('Certificate content'));
        Map<String, Object> uploadRes = FundUtilizationController.uploadUtilizationCertificate(
            app.Id,
            disb.Id,
            'cert.pdf',
            base64Data,
            'Utilization Certificate'
        );
        Test.stopTest();

        System.assertNotEquals(null, uploadRes.get('id'), 'Certificate milestone should be created');
    }

    /* ------------------------------------------------------------
       6. DonorDashboardController & REST Controller Tests
       ------------------------------------------------------------ */
    @IsTest
    static void testDonorDashboard() {
        Donor_Agreement__c da = [SELECT Id FROM Donor_Agreement__c LIMIT 1];
        Funding_Request__c fr = [SELECT Id FROM Funding_Request__c LIMIT 1];

        Test.startTest();
        // 1. Controller queries
        List<Donor_Agreement__c> agreements = DonorDashboardController.getDonorAgreements();
        List<Funding_Request__c> reqs = DonorDashboardController.getFundingRequests();
        String updateStatus = DonorDashboardController.updateAgreementStatus(da.Id, 'Approved');
        DonorDashboardController.updateFundingRequest(fr.Id, 'Approved');

        System.assert(agreements.size() > 0, 'Agreements should be found for donor user');
        System.assert(reqs.size() > 0, 'Funding requests should be found for donor user');
        System.assertEquals('NOT_IN_APPROVAL', updateStatus, 'Agreement not in approval should return NOT_IN_APPROVAL');

        // 2. REST GET - whoami, agreements, fundingrequests, 404
        RestRequest reqGet = new RestRequest();
        RestResponse resGet = new RestResponse();
        reqGet.requestURI = '/services/apexrest/DonorDashboard/whoami';
        reqGet.httpMethod = 'GET';
        RestContext.request = reqGet;
        RestContext.response = resGet;
        DonorDashboardRestController.handleGet();
        System.assert(resGet.responseBody.toString().contains('userId'), 'whoami should return user details');

        reqGet.requestURI = '/services/apexrest/DonorDashboard/agreements';
        DonorDashboardRestController.handleGet();
        System.assert(resGet.responseBody.toString().contains('Education Fund Agreement'), 'agreements should return agreements');

        reqGet.requestURI = '/services/apexrest/DonorDashboard/fundingrequests';
        DonorDashboardRestController.handleGet();
        System.assert(resGet.responseBody.toString().contains('First Tranche'), 'fundingrequests should return requests');

        reqGet.requestURI = '/services/apexrest/DonorDashboard/invalidEndpoint';
        DonorDashboardRestController.handleGet();
        System.assertEquals(404, resGet.statusCode, 'Invalid endpoint should return 404');

        // 3. REST POST - agreements, fundingrequests, 404
        RestRequest reqPost = new RestRequest();
        RestResponse resPost = new RestResponse();
        reqPost.httpMethod = 'POST';
        RestContext.request = reqPost;
        RestContext.response = resPost;

        reqPost.requestURI = '/services/apexrest/DonorDashboard/agreements';
        reqPost.requestBody = Blob.valueOf(JSON.serialize(new Map<String, Object>{
            'agreementId' => da.Id,
            'action' => 'Approved'
        }));
        DonorDashboardRestController.handlePost();
        System.assert(resPost.responseBody.toString().contains('NOT_IN_APPROVAL'), 'POST agreement should process');

        reqPost.requestURI = '/services/apexrest/DonorDashboard/fundingrequests';
        reqPost.requestBody = Blob.valueOf(JSON.serialize(new Map<String, Object>{
            'requestId' => fr.Id,
            'action' => 'Approved'
        }));
        DonorDashboardRestController.handlePost();
        System.assert(resPost.responseBody.toString().contains('OK'), 'POST funding request should succeed');

        reqPost.requestURI = '/services/apexrest/DonorDashboard/unknownAction';
        reqPost.requestBody = Blob.valueOf('{}');
        DonorDashboardRestController.handlePost();
        System.assertEquals(404, resPost.statusCode, 'Unknown action should return 404');
        Test.stopTest();
    }

    /* ------------------------------------------------------------
       7. DonorAgreementEmailService Invocable Test
       ------------------------------------------------------------ */
    @IsTest
    static void testDonorAgreementEmailService() {
        Donor_Agreement__c da = [SELECT Id FROM Donor_Agreement__c LIMIT 1];

        DonorAgreementEmailService.Request req = new DonorAgreementEmailService.Request();
        req.agreementId = da.Id;

        Test.startTest();
        DonorAgreementEmailService.sendAgreementEmail(new List<DonorAgreementEmailService.Request>{ req });
        // Call again to test the duplicate prevention (agreement.Status__c == 'Sent to Donor')
        DonorAgreementEmailService.sendAgreementEmail(new List<DonorAgreementEmailService.Request>{ req });
        Test.stopTest();

        Donor_Agreement__c updatedDa = [SELECT Status__c FROM Donor_Agreement__c WHERE Id = :da.Id];
        System.assertEquals('Sent to Donor', updatedDa.Status__c, 'Status should be updated to Sent to Donor');
    }
}
