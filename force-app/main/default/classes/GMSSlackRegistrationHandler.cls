global without sharing class GMSSlackRegistrationHandler
    implements Auth.RegistrationHandler {

    global User createUser(
        Id portalId,
        Auth.UserData data
    ) {

        // --------------------------------------------------
        // 1. Get the Applicant Demo Experience Cloud profile
        // --------------------------------------------------
        List<Profile> profList = [
            SELECT Id
            FROM Profile
            WHERE Name = 'Applicant Demo'
            LIMIT 1
        ];
        if (profList.isEmpty()) {
            profList = [SELECT Id FROM Profile WHERE UserType = 'Standard' OR Name = 'Standard User' LIMIT 1];
        }
        if (profList.isEmpty()) {
            profList = [SELECT Id FROM Profile LIMIT 1];
        }
        Profile applicantProfile = profList[0];


        // --------------------------------------------------
        // 2. Get the Account used by portal applicants
        // --------------------------------------------------
        List<Account> accList = [
            SELECT Id
            FROM Account
            WHERE Name = 'Account-001'
            LIMIT 1
        ];
        if (accList.isEmpty()) {
            accList = [SELECT Id FROM Account LIMIT 1];
        }
        if (accList.isEmpty()) {
            Account acc = new Account(Name = 'Default Portal Account');
            insert acc;
            accList.add(acc);
        }
        Account applicantAccount = accList[0];


        // --------------------------------------------------
        // 3. Find an existing Contact using Slack email
        // --------------------------------------------------
        List<Contact> existingContacts = [
            SELECT Id,
                   FirstName,
                   LastName,
                   Email,
                   AccountId
            FROM Contact
            WHERE Email = :data.email
            LIMIT 1
        ];

        Contact contactRecord;


        // --------------------------------------------------
        // 4. Reuse existing Contact if available
        // --------------------------------------------------
        if (!existingContacts.isEmpty()) {

            contactRecord = existingContacts[0];

        } else {

            contactRecord = new Contact();

            contactRecord.FirstName =
                String.isBlank(data.firstName)
                ? 'Slack'
                : data.firstName;

            contactRecord.LastName =
                String.isBlank(data.lastName)
                ? 'User'
                : data.lastName;

            contactRecord.Email = data.email;

            contactRecord.AccountId = applicantAccount.Id;

            insert contactRecord;
        }


        // --------------------------------------------------
        // 5. Check for an EXISTING EXTERNAL USER
        //    using ContactId, NOT email
        // --------------------------------------------------
        List<User> existingPortalUsers = [
            SELECT Id,
                   Username,
                   Email,
                   IsActive,
                   ContactId
            FROM User
            WHERE ContactId = :contactRecord.Id
            LIMIT 1
        ];


        if (!existingPortalUsers.isEmpty()) {

            return existingPortalUsers[0];

        }


        // --------------------------------------------------
        // 6. Create new Experience Cloud User
        // --------------------------------------------------
        User u = new User();


        // Username must be globally unique
        u.Username = data.email + '.slack';


        u.Email = data.email;


        u.FirstName =
            String.isBlank(data.firstName)
            ? 'Slack'
            : data.firstName;


        u.LastName =
            String.isBlank(data.lastName)
            ? 'User'
            : data.lastName;


        // --------------------------------------------------
        // 7. Generate Alias
        // --------------------------------------------------
        String firstInitial =
            String.isBlank(data.firstName)
            ? 'S'
            : data.firstName.left(1);

        String lastPart =
            String.isBlank(data.lastName)
            ? 'User'
            : data.lastName;

        u.Alias =
            (firstInitial + lastPart).left(8);


        // --------------------------------------------------
        // 8. Generate Community Nickname
        // --------------------------------------------------
        u.CommunityNickname =
            ('GEMS' +
             String.valueOf(Crypto.getRandomInteger())
                .replace('-', '')
            ).left(40);


        // --------------------------------------------------
        // 9. Experience Cloud profile
        // --------------------------------------------------
        u.ProfileId = applicantProfile.Id;


        // --------------------------------------------------
        // 10. IMPORTANT:
        //     Link User to Contact
        // --------------------------------------------------
        u.ContactId = contactRecord.Id;


        // --------------------------------------------------
        // 11. Locale / Language
        // --------------------------------------------------
        u.TimeZoneSidKey = 'Asia/Kolkata';

        u.LocaleSidKey = 'en_US';

        u.EmailEncodingKey = 'UTF-8';

        u.LanguageLocaleKey = 'en_US';


        // Salesforce inserts the User
        return u;
    }


    // ------------------------------------------------------
    // Update existing Slack user
    // ------------------------------------------------------

    global void updateUser(
        Id userId,
        Id portalId,
        Auth.UserData data
    ) {

        User u = [
            SELECT Id,
                   FirstName,
                   LastName,
                   Email
            FROM User
            WHERE Id = :userId
            LIMIT 1
        ];


        u.FirstName = data.firstName;

        u.LastName = data.lastName;

        u.Email = data.email;


        update u;
    }
}