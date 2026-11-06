public with sharing class StripePaymentQueueable
    implements Queueable, Database.AllowsCallouts {

    private Set<Id> disbursementIds;

    public StripePaymentQueueable(
        Set<Id> disbursementIds
    ) {
        this.disbursementIds = disbursementIds;
    }

    public void execute(
        QueueableContext context
    ) {

        for (Id disbursementId : disbursementIds) {

            try {

                StripePaymentService.processDisbursement(
                    disbursementId
                );

            } catch (Exception ex) {

                System.debug(
                    LoggingLevel.ERROR,
                    'Stripe payment failed for ' +
                    disbursementId +
                    ': ' +
                    ex.getMessage()
                );
            }
        }
    }
}