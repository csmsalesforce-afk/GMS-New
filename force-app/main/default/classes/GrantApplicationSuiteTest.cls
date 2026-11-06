@IsTest
public class GrantApplicationSuiteTest {

    @TestSetup
    static void setupTestData() {
        Region__c reg = new Region__c(
            Name = 'East Region',
            Active__c = true
        );
        insert reg;

        Country__c country = new Country__c(
            Name = 'Canada',
            ISO_Code__c = 'CA',
            Region__c = reg.Id,
            Active__c = true
        );
        insert country;

        Program__c prog = new Program__c(
            Name = 'Education Program',
            Program_Fund__c = 1000000,
            Max_Amount__c = 10000000000.0,
            Status__c = 'Open'
        );
        insert prog;

        Account acc = new Account(
            Name = 'Applicant Organization'
        );
        insert acc;

        Grant_Program__c profile = new Grant_Program__c(
            Country__c = country.Id,
            Account__c = acc.Id,
            Primary_Contact_Name__c = 'Applicant Lead',
            Primary_Contact_Email__c = 'applicant.lead@example.com',
            Stripe_Onboarding_Status__c = 'Not Connected',
            OwnerId = UserInfo.getUserId(),
            User__c = UserInfo.getUserId()
        );
        insert profile;

        Grant_Applicant__c app = new Grant_Applicant__c(
            Program__c = prog.Id,
            Grant_Program__c = profile.Id,
            Account__c = acc.Id,
            Applicant_Name__c = 'Applicant Lead',
            Project_Title__c = 'Community Classroom Initiative',
            Project_Description__c = 'Building classrooms for underserved communities',
            Requested_Amount__c = 15000,
            Submission_Date__c = Date.today(),
            Stage_Entry_Date__c = Date.today(),
            Application_Status__c = 'Submitted',
            PDF_Generated__c = false,
            OwnerId = UserInfo.getUserId()
        );
        insert app;
    }

    @IsTest
    static void testControllersListAndReview() {
        Grant_Applicant__c app = [SELECT Id FROM Grant_Applicant__c LIMIT 1];

        Test.startTest();
        List<Grant_Applicant__c> apps = GrantApplicationController.getApplications();
        List<Grant_Applicant__c> myApps = MyApplicationsController.getMyApplications();
        Map<String, Object> reviewData = GrantApplicationReviewController.getApplicationData(app.Id);
        ApplicationReviewController.AppDetailsWrapper details = ApplicationReviewController.getApplicationDetails(app.Id);
        List<ContentDocumentLink> files = ApplicationReviewController.getFiles(app.Id);

        try {
            ApplicationReviewController.saveReviewerData(app.Id, 'Approve', 85, 'Solid project proposal');
        } catch (Exception e) {}
        try {
            ApplicationReviewController.saveReviewerData(app.Id, 'Reject', 30, 'Ineligible proposal');
        } catch (Exception e) {}
        try {
            ApplicationReviewController.saveProgramOfficerData(app.Id, 'Approve', 80, 4, 90, 'High', 'Full Approval', 'Endorsed for award');
        } catch (Exception e) {}
        try {
            ApplicationReviewController.saveProgramOfficerData(app.Id, 'Reject', 30, 1, 20, 'High', 'Conditional Approval', 'Not approved');
        } catch (Exception e) {}
        Test.stopTest();

        System.assertNotEquals(0, apps.size());
        System.assertNotEquals(0, myApps.size());
        System.assertNotEquals(null, reviewData.get('application'));
        System.assertNotEquals(null, details.appRecord);
    }

    @IsTest
    static void testGrantApplicationController1Operations() {
        Grant_Applicant__c app = [SELECT Id, Project_Title__c, Applicant_Name__c, Requested_Amount__c, Program__c, Submission_Date__c FROM Grant_Applicant__c LIMIT 1];

        Test.startTest();
        Map<String, Object> appData = GrantApplicationController1.getApplication(app.Id);
        System.assertNotEquals(null, appData);
        System.assertEquals(app.Id, (Id)appData.get('Id'));

        Grant_Applicant__c app1 = GrantApplicationController1.getApplication1(app.Id);
        System.assertNotEquals(null, app1);

        app.OwnerId = UserInfo.getUserId();
        app.Project_Title__c = 'Updated Title';
        Id savedId = GrantApplicationController1.saveApplication(app);
        System.assertEquals(app.Id, savedId);

        Grant_Applicant__c newDraft = new Grant_Applicant__c(
            Program__c = app.Program__c,
            Project_Title__c = 'Second Draft',
            Requested_Amount__c = 5000
        );
        Id newDraftId = GrantApplicationController1.saveApplication(newDraft);
        System.assertNotEquals(null, newDraftId);

        String fileId = GrantApplicationController1.uploadFile('testfile.txt', EncodingUtil.base64Encode(Blob.valueOf('Sample Content')), app.Id);
        System.assertNotEquals(null, fileId);

        List<Map<String, Object>> appFiles = GrantApplicationController1.getApplicationFiles(app.Id);
        System.assertNotEquals(0, appFiles.size());

        List<Project_Budget__c> savedBudgets = GrantApplicationController1.saveProjectBudgets(app.Id, '[{"Expense_Category__c":"Materials & Supplies","Estimated_Amount__c":1200,"Description__c":"Textbooks"}]');
        System.assertNotEquals(0, savedBudgets.size());

        List<Project_Budget__c> retrievedBudgets = GrantApplicationController1.getProjectBudgets(app.Id);
        System.assertEquals(1, retrievedBudgets.size());

        // Test delete on saveProjectBudgets
        GrantApplicationController1.saveProjectBudgets(app.Id, '[]');
        try {
            GrantApplicationController1.saveProjectBudgets(null, '[]');
        } catch (Exception e) {}

        GrantApplicationController1.getApplicantInfo();
        GrantApplicationController1.getProgramInfo(app.Program__c);
        GrantApplicationController1.getUserContext();
        GrantApplicationController1.getProfileStatus();
        GrantApplicationController1.getUploadedFiles(app.Id);

        try {
            GrantApplicationController1.generateApplicantPdf(app.Id);
        } catch (Exception e) {}

        try {
            GrantApplicationController1.generatePdfAndSubmit(app.Id);
        } catch (Exception e) {}

        try {
            GrantApplicationController1.submitApplication(app.Id);
        } catch (Exception e) {}

        ContentVersion testCv = new ContentVersion(
            Title = 'DocToFix',
            PathOnClient = 'doc.pdf',
            VersionData = Blob.valueOf('data')
        );
        insert testCv;
        Id docId = [SELECT ContentDocumentId FROM ContentVersion WHERE Id = :testCv.Id].ContentDocumentId;
        GrantApplicationController1.fixFileVisibility(docId);
        GrantApplicationController1.deleteFile(docId);

        GrantApplicationController1.submitForApproval(app.Id);
        GrantApplicationController1.withdrawApplicationWithReason(app.Id, 'Scope changed');
        GrantApplicationController1.withdrawApplicationWithNotification(app.Id, 'Alternative funding found');
        Test.stopTest();
    }

    @IsTest
    static void testGrantApplicationCreatorInvocable() {
        Account acc = [SELECT Id FROM Account LIMIT 1];
        Grant_Program__c profile = [SELECT Id FROM Grant_Program__c LIMIT 1];
        Program__c prog = [SELECT Id FROM Program__c LIMIT 1];

        GrantApplicationCreator.InputWrapper input = new GrantApplicationCreator.InputWrapper();
        input.accountId = acc.Id;
        input.profileId = profile.Id;
        input.organizationType = 'Academic Institution';
        input.Program = prog.Id;
        input.programCategory = 'Education Program';
        input.applicantName = 'Professor Smith';
        input.requestedAmount = 10000;
        input.submissionDate = Date.today();
        input.projectTitle = 'Research Project';
        input.projectDescription = 'Advanced academic research';
        input.startDate = Date.today();

        Test.startTest();
        List<GrantApplicationCreator.OutputWrapper> outputs = GrantApplicationCreator.createGrantApplication(
            new List<GrantApplicationCreator.InputWrapper>{ input }
        );
        Test.stopTest();

        System.assertEquals(1, outputs.size());
    }

    @IsTest
    static void testGrantApplicationPDFGeneratorsAndBatch() {
        Grant_Applicant__c app = [SELECT Id FROM Grant_Applicant__c LIMIT 1];

        Grant_Applicant__c ungeneratedApp = new Grant_Applicant__c(
            Program__c = [SELECT Id FROM Program__c LIMIT 1].Id,
            Grant_Program__c = [SELECT Id FROM Grant_Program__c LIMIT 1].Id,
            Account__c = [SELECT Id FROM Account LIMIT 1].Id,
            Project_Title__c = 'New Submission',
            Application_Status__c = 'Submitted',
            PDF_Generated__c = false,
            Requested_Amount__c = 10000
        );
        insert ungeneratedApp;

        Test.startTest();
        // PDF Invocable and Queueable
        GrantApplicationPDFInvocable.generatePDF(new List<Id>{ app.Id });
        System.enqueueJob(new GrantApplicationPDFQueueable(new List<Id>{ ungeneratedApp.Id }));

        // Batch & Scheduler
        Database.executeBatch(new GrantApplicationPDFBatch(), 5);
        new GrantApplicationPDFBatch().execute(null, new List<Grant_Applicant__c>{ ungeneratedApp });
        new GrantApplicationPDFScheduler().execute(null);

        // VF Controller & Saver
        ApexPages.currentPage().getParameters().put('id', app.Id);
        GrantApplicationPDFController pdfCtrl = new GrantApplicationPDFController();
        System.assertNotEquals(null, pdfCtrl.app);

        GrantAppPDFSaver saver = new GrantAppPDFSaver(new ApexPages.StandardController(app));
        saver.savePDF();

        // Handler & Delete
        GrantApplicationPDFHandler.attachPDFToRecord(new Set<Id>{ app.Id });
        DeleteGrantApplicationPDF.deletePDF(new List<Id>{ app.Id });
        Test.stopTest();
    }
}
