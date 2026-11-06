trigger DisbursementTrigger
on Disbursement__c (after insert, after update) {

    Set<Id> disbursementIds = new Set<Id>();

    for (Disbursement__c record : Trigger.new) {

        // New record created directly as Approved
        if (Trigger.isInsert) {

            if (record.Status__c == 'Approved') {
                disbursementIds.add(record.Id);
            }
        }

        // Existing record changed to Approved
        if (Trigger.isUpdate) {

            Disbursement__c oldRecord =
                Trigger.oldMap.get(record.Id);

            if (
                record.Status__c == 'Approved' &&
                oldRecord.Status__c != 'Approved'
            ) {
                disbursementIds.add(record.Id);
            }
        }
    }

    if (!disbursementIds.isEmpty()) {

        System.enqueueJob(
            new StripePaymentQueueable(disbursementIds)
        );
    }
}