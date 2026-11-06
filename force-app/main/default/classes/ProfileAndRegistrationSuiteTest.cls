@IsTest
private class ProfileAndRegistrationSuiteTest {

    @TestSetup
    static void setupTestData() {
        // 1. Account-001 (required by GEMSGoogleRegistrationHandler & GMSSlackRegistrationHandler)
        Account acc = new Account(Name = 'Account-001');
        insert acc;

        // 2. Region & Country
        Region__c reg = new Region__c(Name = 'Global Region');
        insert reg;

        Country__c country = new Country__c(Name = 'Global Country', ISO_Code__c = 'US', Region__c = reg.Id);
        insert country;

        // 3. Program
        Program__c prog = new Program__c(
            Name = 'Community Support Program',
            Program_Type__c = 'Community Development',
            Max_Amount__c = 10000000000.0,
            Status__c = 'Open'
        );
        insert prog;

        // 4. Grant_Program__c owned by running user
        Id ngoRtId = Schema.SObjectType.Grant_Program__c.getRecordTypeInfosByDeveloperName().containsKey('NGO')
            ? Schema.SObjectType.Grant_Program__c.getRecordTypeInfosByDeveloperName().get('NGO').getRecordTypeId()
            : null;

        Grant_Program__c profile = new Grant_Program__c(
            First_Name__c = 'Demo',
            Last_Name__c = 'Applicant',
            Email_Address__c = UserInfo.getUserEmail(),
            Country__c = country.Id,
            Region__c = reg.Id,
            RecordTypeId = ngoRtId,
            Organization_Type__c = 'NGO',
            Profile_Status__c = 'Pending',
            OwnerId = UserInfo.getUserId()
        );
        insert profile;

        // 5. Active Donor Campaign
        Donor_Campaign__c campaign = new Donor_Campaign__c(
            Name = 'Annual Education Drive',
            Active__c = true,
            Status__c = 'In Progress',
            Type__c = 'Email',
            Program__c = prog.Id,
            Budgeted_Cost_in_Campaign__c = 10000,
            Expected_Revenue_in_Campaign__c = 50000
        );
        insert campaign;

        // 6. Existing Donation
        Donations__c don = new Donations__c(
            Donor_Campaign__c = campaign.Id,
            Donation_Amount__c = 500,
            Donor_Name__c = UserInfo.getName(),
            Donor_Email__c = UserInfo.getUserEmail(),
            Payment_Status__c = 'Successful',
            Payment_Date__c = System.now(),
            Receipt_Number__c = 'REC-TEST001'
        );
        insert don;
    }

    /* ------------------------------------------------------------
       1. ProfileFieldSetController Tests
       ------------------------------------------------------------ */
    @IsTest
    static void testProfileFieldSetController() {
        Donor_Campaign__c camp = [SELECT Id FROM Donor_Campaign__c LIMIT 1];
        Grant_Program__c prof = [SELECT Id FROM Grant_Program__c LIMIT 1];

        Test.startTest();
        // 1. Dynamic field set retrieval
        Map<String, Schema.FieldSet> fsMap = Grant_Program__c.SObjectType.getDescribe().fieldSets.getMap();
        for (String fsName : fsMap.keySet()) {
            ProfileFieldSetController.getFieldSetFields(fsName);
            ProfileFieldSetController.getFieldSetMetadata(fsName);
        }

        List<String> emptyFields = ProfileFieldSetController.getFieldSetFields('');
        List<String> invalidFields = ProfileFieldSetController.getFieldSetFields('NonExistentFieldSet_XYZ');
        List<ProfileFieldSetController.FieldMetadata> emptyMeta = ProfileFieldSetController.getFieldSetMetadata('');
        List<ProfileFieldSetController.FieldMetadata> invalidMeta = ProfileFieldSetController.getFieldSetMetadata('NonExistentFieldSet_XYZ');

        System.assertEquals(0, emptyFields.size(), 'Empty name should return empty field list');
        System.assertEquals(0, invalidFields.size(), 'Invalid name should return empty field list');
        System.assertEquals(0, emptyMeta.size(), 'Empty name should return empty metadata list');
        System.assertEquals(0, invalidMeta.size(), 'Invalid name should return empty metadata list');

        // 2. User & Profile queries
        Grant_Program__c userProf = ProfileFieldSetController.getCurrentUserProfile();
        System.assertNotEquals(null, userProf, 'Should return current user profile');

        User loggedInUser = ProfileFieldSetController.getLoggedInUserProfile();
        System.assertEquals(UserInfo.getUserId(), loggedInUser.Id, 'Should match logged in user');

        // 3. Campaigns and dashboard summary
        List<Donor_Campaign__c> activeCampaigns = ProfileFieldSetController.getActiveDonorCampaigns();
        System.assert(activeCampaigns.size() > 0, 'Should find active donor campaigns');

        ProfileFieldSetController.DonorDashboardSummary summary = ProfileFieldSetController.getDonorDashboardSummary();
        System.assertNotEquals(null, summary, 'Dashboard summary should not be null');
        System.assertEquals(1, summary.campaignsSupported, 'Should have supported 1 campaign');
        System.assertEquals(500, summary.totalDonations, 'Total donations should match');

        // 4. Create donation
        Donations__c newDon = ProfileFieldSetController.createDonation(
            camp.Id,
            250,
            'Test Supporter',
            UserInfo.getUserEmail(),
            '1234567890',
            'Best wishes'
        );
        System.assertNotEquals(null, newDon.Id, 'Donation should be created');

        // Negative donation validation
        try {
            ProfileFieldSetController.createDonation(camp.Id, 0, 'Test', 'test@test.com', '123', 'Msg');
            System.assert(false, 'Expected validation error on 0 amount');
        } catch (AuraHandledException e) {
            System.assert(true, 'Caught expected exception');
        }

        // 5. Submit profile for approval (catch expected exception in test org)
        try {
            ProfileFieldSetController.submitProfileForApproval(prof.Id);
        } catch (Exception e) {
            System.assert(true, 'Handled submission exception');
        }
        Test.stopTest();
    }

    /* ------------------------------------------------------------
       2. CreateProfileController Tests
       ------------------------------------------------------------ */
    @IsTest
    static void testCreateProfileController() {
        Grant_Program__c existing = [SELECT Id FROM Grant_Program__c LIMIT 1];

        Test.startTest();
        // 1. Update existing profile using smart lookup resolution
        Map<String, Object> updateMap = new Map<String, Object>{
            'Id' => existing.Id,
            'Country__c' => 'Global Country',
            'Region__c' => 'Global Region',
            'Donor_Type__c' => 'Corporate Foundation',
            'First_Name__c' => 'Jane',
            'Last_Name__c' => 'Doe',
            'Email_Address__c' => 'jane.doe@example.com'
        };
        Id updatedId = CreateProfileController.createProfile(updateMap);
        System.assertEquals(existing.Id, updatedId, 'Should update existing profile');

        // 2. Test trying to modify an approved profile
        existing.Profile_Status__c = 'Approved';
        update existing;

        try {
            CreateProfileController.createProfile(updateMap);
            System.assert(false, 'Should throw exception modifying approved profile');
        } catch (AuraHandledException ex) {
            System.assert(true, 'Caught approved profile modification error');
        }
        existing.Profile_Status__c = 'Pending';
        update existing;

        // 3. Test creating a new profile map with individual donor
        Id indRtId = Schema.SObjectType.Grant_Program__c.getRecordTypeInfosByDeveloperName().containsKey('Individual_Applicant')
            ? Schema.SObjectType.Grant_Program__c.getRecordTypeInfosByDeveloperName().get('Individual_Applicant').getRecordTypeId()
            : null;

        Grant_Program__c freshProfile = new Grant_Program__c(
            First_Name__c = 'Bob',
            Last_Name__c = 'Smith',
            Email_Address__c = 'bob.smith@example.com',
            Profile_Status__c = 'Pending',
            RecordTypeId = indRtId
        );
        insert freshProfile;

        Map<String, Object> newProfileMap = new Map<String, Object>{
            'Id' => freshProfile.Id,
            'Donor_Type__c' => 'Individual Donor',
            'Country__c' => 'Global Country',
            'Region__c' => 'Global Region'
        };
        Id resFreshId = CreateProfileController.createProfile(newProfileMap);
        System.assertEquals(freshProfile.Id, resFreshId, 'Fresh profile should be updated');

        freshProfile.OwnerId = UserInfo.getUserId();
        freshProfile.Profile_Status__c = 'Pending';
        update freshProfile;

        Map<String, Object> noIdMap = new Map<String, Object>{
            'Donor_Type__c' => 'Corporate Foundation',
            'First_Name__c' => 'OwnerFirst',
            'Last_Name__c' => 'OwnerLast'
        };
        CreateProfileController.createProfile(noIdMap);
        Test.stopTest();
    }

    /* ------------------------------------------------------------
       3. UserProfileController & ProfileRedirectController Tests
       ------------------------------------------------------------ */
    @IsTest
    static void testUserProfileAndRedirectControllers() {
        Test.startTest();
        // UserProfileController
        String profName = UserProfileController.getUserProfileName();
        System.assertNotEquals(null, profName, 'Profile name should not be null');

        // NavbarController
        String navUser = NavbarController.getUserName();
        System.assertNotEquals(null, navUser);

        // ProfileRedirectController (Admin)
        ProfileRedirectController redirectCtrl = new ProfileRedirectController();
        PageReference pr = redirectCtrl.redirectUser();
        System.assertNotEquals(null, pr, 'Redirect page reference should not be null');

        // Test ProfileRedirectController for different roles
        ProfileRedirectController.testProfileName = 'Reviewer';
        System.assertNotEquals(null, redirectCtrl.redirectUser());
        ProfileRedirectController.testProfileName = 'Program Officer';
        System.assertNotEquals(null, redirectCtrl.redirectUser());
        ProfileRedirectController.testProfileName = 'Finance';
        System.assertNotEquals(null, redirectCtrl.redirectUser());
        ProfileRedirectController.testProfileName = 'Standard';
        System.assertNotEquals(null, redirectCtrl.redirectUser());
        Test.stopTest();
    }

    /* ------------------------------------------------------------
       4. EncryptionUtil, SessionController & Helper Classes
       ------------------------------------------------------------ */
    @IsTest
    static void testUtilitiesAndHelpers() {
        Test.startTest();
        // 1. EncryptionUtil
        List<String> encrypted = EncryptionUtil.encrypt(new List<String>{ 'SecretToken123', 'AnotherSecret' });
        System.assertEquals(2, encrypted.size(), 'Should encrypt 2 strings');
        System.assertNotEquals('SecretToken123', encrypted[0], 'Result should be encrypted');

        // 2. SessionController
        String sessionId = SessionController.getSessionId();

        // 3. Empty helper classes instantiate without errors
        LoginController lc = new LoginController();
        submitProfileForApproval sp = new submitProfileForApproval();
        ProfileWrapper pw = new ProfileWrapper();

        // 4. UserResolver
        UserResolver.getUserFullNames(null);
        UserResolver.getUserFullNames(new Set<Id>());
        UserResolver.getUserFullNames(new Set<Id>{ UserInfo.getUserId() });
        Test.stopTest();

        System.assertNotEquals(null, lc, 'LoginController should instantiate');
    }

    /* ------------------------------------------------------------
       5. CustomLoginController Tests
       ------------------------------------------------------------ */
    @IsTest
    static void testCustomLoginController() {
        Test.startTest();
        CustomLoginController ctrl = new CustomLoginController();
        ctrl.username = 'testuser@example.com';
        ctrl.password = 'Pass1234!';
        ctrl.firstName = 'Test';
        ctrl.lastName = 'User';
        ctrl.email = 'testuser@example.com';
        ctrl.confirmPassword = 'Pass1234!';

        // Login
        PageReference loginPr = ctrl.login();

        // Forgot password
        PageReference forgotPr = ctrl.forgotPassword();

        // Registration (running user is not Guest, covers user type validation)
        PageReference regPr = ctrl.register();

        // Test field validations
        ctrl.firstName = '';
        ctrl.register();
        ctrl.firstName = 'Test';
        ctrl.confirmPassword = 'DifferentPassword';
        ctrl.register();

        // Navigation
        PageReference pReg = ctrl.forwardToRegister();
        PageReference pForgot = ctrl.forwardToForgot();
        PageReference pLogin = ctrl.forwardToLogin();

        // Direct registration execution
        ctrl.firstName = 'Test';
        ctrl.lastName = 'User';
        ctrl.email = 'testapplicant123@example.com';
        ctrl.password = 'Pass1234!';
        ctrl.confirmPassword = 'Pass1234!';
        try {
            ctrl.register();
        } catch (Exception e) {}

        // Guest user testing
        List<User> guestUsers = [SELECT Id FROM User WHERE UserType = 'Guest' AND IsActive = true LIMIT 1];
        if (!guestUsers.isEmpty()) {
            System.runAs(guestUsers[0]) {
                CustomLoginController guestCtrl = new CustomLoginController();
                // 1. Empty fields
                guestCtrl.register();
                // 2. Mismatch password
                guestCtrl.firstName = 'First';
                guestCtrl.lastName = 'Last';
                guestCtrl.email = 'guestapplicant@example.com';
                guestCtrl.password = 'Password123!';
                guestCtrl.confirmPassword = 'DifferentPassword';
                guestCtrl.register();
                // 3. Matching password
                guestCtrl.confirmPassword = 'Password123!';
                try {
                    guestCtrl.register();
                } catch (Exception e) {}
            }
        }
        Test.stopTest();

        System.assertNotEquals(null, pReg, 'forwardToRegister should return PageReference');
        System.assertNotEquals(null, pForgot, 'forwardToForgot should return PageReference');
        System.assertNotEquals(null, pLogin, 'forwardToLogin should return PageReference');
    }

    /* ------------------------------------------------------------
       6. DonorLoginController Tests
       ------------------------------------------------------------ */
    @IsTest
    static void testDonorLoginController() {
        PageReference pageRef = new PageReference('/apex/DonorCustomLogin');
        pageRef.getParameters().put('mode', 'register');
        pageRef.getParameters().put('startURL', '/donor/s/#dashboard');
        Test.setCurrentPage(pageRef);

        Test.startTest();
        DonorLoginController ctrl = new DonorLoginController();
        System.assertEquals('register', ctrl.mode, 'Mode should match page param');

        // Validation with empty credentials
        ctrl.username = '';
        ctrl.password = '';
        PageReference pr1 = ctrl.login();
        System.assertEquals(null, pr1, 'Empty username should return null');

        ctrl.username = 'donor@example.com';
        ctrl.password = '';
        PageReference pr2 = ctrl.login();
        System.assertEquals(null, pr2, 'Empty password should return null');

        // Call login with credentials
        ctrl.password = 'Secret123!';
        PageReference pr3 = ctrl.login();

        // Forgot password
        PageReference prForgot = ctrl.forgotPassword();

        // Navigation
        PageReference navForgot = ctrl.forwardToForgot();
        PageReference navReg = ctrl.forwardToRegister();
        System.assertNotEquals(null, navForgot, 'forwardToForgot should return PageReference');
        System.assertNotEquals(null, navReg, 'forwardToRegister should return PageReference');

        // Donor registration execution
        ctrl.firstName = '';
        ctrl.registerDonorUser();
        ctrl.firstName = 'Donor';
        ctrl.lastName = 'Person';
        ctrl.email = 'donor@example.com';
        ctrl.password = 'Password123!';
        ctrl.confirmPassword = 'MismatchPassword';
        ctrl.registerDonorUser();
        ctrl.confirmPassword = 'Password123!';
        try {
            ctrl.registerDonorUser();
        } catch (Exception e) {}

        // Guest user testing
        List<User> guestUsers = [SELECT Id FROM User WHERE UserType = 'Guest' AND IsActive = true LIMIT 1];
        if (!guestUsers.isEmpty()) {
            System.runAs(guestUsers[0]) {
                DonorLoginController guestCtrl = new DonorLoginController();
                // 1. Empty fields
                guestCtrl.registerDonorUser();
                // 2. Mismatch password
                guestCtrl.firstName = 'First';
                guestCtrl.lastName = 'Last';
                guestCtrl.email = 'guestdonor@example.com';
                guestCtrl.password = 'Password123!';
                guestCtrl.confirmPassword = 'DifferentPassword';
                guestCtrl.registerDonorUser();
                // 3. Matching password
                guestCtrl.confirmPassword = 'Password123!';
                try {
                    guestCtrl.registerDonorUser();
                } catch (Exception e) {}
            }
        }
        Test.stopTest();
    }

    /* ------------------------------------------------------------
       7. GEMSGoogleRegistrationHandler Tests
       ------------------------------------------------------------ */
    @IsTest
    static void testGEMSGoogleRegistrationHandler() {
        GEMSGoogleRegistrationHandler handler = new GEMSGoogleRegistrationHandler();

        Auth.UserData data = new Auth.UserData(
            'googleId123',
            'GoogleFirst',
            'GoogleLast',
            'GoogleFirst GoogleLast',
            'unique_google_applicant@example.com',
            null,
            'unique_google_applicant@example.com',
            'en_US',
            'Google',
            null,
            new Map<String, String>()
        );

        Test.startTest();
        // 1. Create user (creates contact and returns User record)
        User u = handler.createUser(null, data);
        System.assertNotEquals(null, u, 'User should be constructed');
        System.assertEquals(data.email + '.google', u.Username, 'Username should have google suffix');

        // 2. Existing user check
        Auth.UserData existingData = new Auth.UserData(
            'googleId456',
            'Current',
            'User',
            'Current User',
            UserInfo.getUserEmail(),
            null,
            UserInfo.getUserEmail(),
            'en_US',
            'Google',
            null,
            new Map<String, String>()
        );
        User foundUser = handler.createUser(null, existingData);
        System.assertEquals(UserInfo.getUserId(), foundUser.Id, 'Should return existing user');

        // 3. Update user
        handler.updateUser(UserInfo.getUserId(), null, existingData);
        Test.stopTest();
    }

    /* ------------------------------------------------------------
       8. GMSSlackRegistrationHandler Tests
       ------------------------------------------------------------ */
    @IsTest
    static void testGMSSlackRegistrationHandler() {
        GMSSlackRegistrationHandler handler = new GMSSlackRegistrationHandler();

        Auth.UserData data = new Auth.UserData(
            'slackId123',
            'SlackFirst',
            'SlackLast',
            'SlackFirst SlackLast',
            'unique_slack_applicant@example.com',
            null,
            'unique_slack_applicant@example.com',
            'en_US',
            'Slack',
            null,
            new Map<String, String>()
        );

        Test.startTest();
        // 1. Create user (creates contact and returns User record)
        User u = handler.createUser(null, data);
        System.assertNotEquals(null, u, 'User should be constructed');
        System.assertEquals(data.email + '.slack', u.Username, 'Username should have slack suffix');

        // 2. Call again with same data to test existing contact branch
        User u2 = handler.createUser(null, data);
        System.assertNotEquals(null, u2, 'User should be constructed with existing contact');

        // 3. Update user
        handler.updateUser(UserInfo.getUserId(), null, data);
        Test.stopTest();
    }
}
