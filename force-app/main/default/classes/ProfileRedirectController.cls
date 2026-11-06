public with sharing class ProfileRedirectController {

    @TestVisible private static String testProfileName;

    public PageReference redirectUser(){
        String profileName;
        if (Test.isRunningTest() && String.isNotBlank(testProfileName)) {
            profileName = testProfileName;
        } else {
            User u = [
                SELECT Profile.Name
                FROM User
                WHERE Id = :UserInfo.getUserId()
            ];
            profileName = u.Profile.Name;
        }

        if(profileName == 'System Administrator'){
            return new PageReference('/s/admin-dashboard');
        }

        if(profileName == 'Reviewer'){
            return new PageReference('/s/homereviewer');
        }

        if(profileName == 'Program Officer'){
            return new PageReference('/s/homePO');
        }

        if(profileName == 'Finance'){
            return new PageReference('/s/homefinancer');
        }

        return new PageReference('/s');
    }
}