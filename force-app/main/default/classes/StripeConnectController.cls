public without sharing class StripeConnectController {

    @AuraEnabled
    public static String connectStripe(
        Id grantApplicantId
    ) {

        if (grantApplicantId == null) {

            throw new AuraHandledException(
                'Grant Applicant Id is required.'
            );
        }


        try {
            String stripeAccountId =
                StripeConnectService.createStripeAccount(
                    grantApplicantId
                );

            String onboardingUrl =
                StripeConnectService.createStripeOnboardingLink(
                    grantApplicantId
                );


            return onboardingUrl;

        } catch (Exception ex) {

            throw new AuraHandledException(
                ex.getMessage()
            );
        }
    }
}