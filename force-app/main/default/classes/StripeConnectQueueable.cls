public with sharing class StripeConnectQueueable
    implements Queueable, Database.AllowsCallouts {

    private Id grantApplicantId;

    public StripeConnectQueueable(
        Id grantApplicantId
    ) {
        this.grantApplicantId = grantApplicantId;
    }


    public void execute(
        QueueableContext context
    ) {

        try {
            String stripeAccountId =
                StripeConnectService.createStripeAccount(
                    grantApplicantId
                );

            String onboardingUrl =
                StripeConnectService.createStripeOnboardingLink(
                    grantApplicantId
                );


            /*
             * We can't redirect the browser directly
             * from Queueable Apex.
             *
             * Therefore this version stores/logs
             * the URL for the next UI step.
             */
            System.debug(
                LoggingLevel.INFO,
                'Stripe onboarding URL: ' +
                onboardingUrl
            );

        } catch (Exception ex) {

            System.debug(
                LoggingLevel.ERROR,
                'Stripe Connect failed: ' +
                ex.getMessage()
            );
        }
    }
}