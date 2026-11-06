global without sharing class GEMSGoogleRegistrationHandler
    implements Auth.RegistrationHandler {

    global User createUser(
        Id portalId,
        Auth.UserData data
    ) {

        // 1. Check whether a Salesforce User already exists
        List<User> existingUsers = [
            SELECT Id, Username, Email, IsActive, ContactId
            FROM User
            WHERE Email = :data.email
            LIMIT 1
        ];

        if (!existingUsers.isEmpty()) {
            return existingUsers[0];
        }

        // 2. Get the external-user profile
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

        // 3. Get the Account that will own the Contact
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

        // 4. Find an existing Contact for this Google email
        List<Contact> existingContacts = [
            SELECT Id, FirstName, LastName, Email, AccountId
            FROM Contact
            WHERE Email = :data.email
            LIMIT 1
        ];

        Contact contactRecord;

        // 5. Reuse existing Contact or create one
        if (!existingContacts.isEmpty()) {

            contactRecord = existingContacts[0];

        } else {

            contactRecord = new Contact();

            contactRecord.FirstName =
                String.isBlank(data.firstName)
                ? 'Google'
                : data.firstName;

            contactRecord.LastName =
                String.isBlank(data.lastName)
                ? 'User'
                : data.lastName;

            contactRecord.Email = data.email;
            contactRecord.AccountId = applicantAccount.Id;

            insert contactRecord;
        }

        // 6. Create the Experience Cloud User
        User u = new User();

        u.Username = data.email + '.google';
        u.Email = data.email;

        u.FirstName =
            String.isBlank(data.firstName)
            ? 'Google'
            : data.firstName;

        u.LastName =
            String.isBlank(data.lastName)
            ? 'User'
            : data.lastName;

        u.Alias = (
            (String.isBlank(data.firstName)
                ? 'G'
                : data.firstName.left(1))
            +
            (String.isBlank(data.lastName)
                ? 'User'
                : data.lastName)
        ).left(8);

        u.CommunityNickname =
            (
                'GEMS' +
                String.valueOf(Crypto.getRandomInteger())
                    .replace('-', '')
            ).left(40);

        u.ProfileId = applicantProfile.Id;

        // IMPORTANT
        u.ContactId = contactRecord.Id;

        u.TimeZoneSidKey = 'Asia/Kolkata';
        u.LocaleSidKey = 'en_US';
        u.EmailEncodingKey = 'UTF-8';
        u.LanguageLocaleKey = 'en_US';

        return u;
    }


    global void updateUser(
        Id userId,
        Id portalId,
        Auth.UserData data
    ) {

        User u = [
            SELECT Id, FirstName, LastName, Email
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