public without sharing class InvoicePDFController {

    public InvoiceForAward__c invoice { get; set; }
    public Disbursement__c disbursement { get; set; }

    public InvoicePDFController(
        ApexPages.StandardController standardController
    ) {

        // Get Invoice Id from URL parameter first
        String invoiceIdParam =
            ApexPages.currentPage().getParameters().get('id');

        Id invoiceId;

        if (!String.isBlank(invoiceIdParam)) {

            try {
                invoiceId = Id.valueOf(invoiceIdParam);
            } catch (Exception e) {
                System.debug(
                    'Invalid Invoice Id: ' + invoiceIdParam
                );
                return;
            }

        } else {

            // Fallback to Standard Controller Id
            invoiceId = standardController.getId();

        }

        if (invoiceId == null) {
            return;
        }

        // =====================================================
        // GET INVOICE
        // =====================================================

        List<InvoiceForAward__c> invoiceList = [
            SELECT
                Id,
                Name,
                Invoice_Date__c,
                Invoice_Status__c,
                Payment_Date__c,
                Requested_Amount__c,
                Finance_Approved_Amount__c,
                Budget_Amendment__c,
                Invoice_Amount__c,
                Payment_Reference__c
            FROM InvoiceForAward__c
            WHERE Id = :invoiceId
            LIMIT 1
        ];

        if (!invoiceList.isEmpty()) {

            invoice = invoiceList[0];

            System.debug(
                'Invoice PDF - Invoice Found: ' +
                invoice.Name
            );
        }

        // =====================================================
        // GET DISBURSEMENT
        // =====================================================

        List<Disbursement__c> disbursementList = [
            SELECT
                Id,
                Name,
                Installment__c,
                Installment__r.Name,
                Disbursement_Date__c,
                Status__c,
                Payment_Date__c,
                Payment_Error__c,
                Payment_Initiated_Date__c,
                Payment_Status__c,
                Payment_Type__c,
                Stripe_Payment_ID__c,
                Total_Amount__c
            FROM Disbursement__c
            WHERE Invoice__c = :invoiceId
            ORDER BY CreatedDate DESC
            LIMIT 1
        ];

        if (!disbursementList.isEmpty()) {

            disbursement = disbursementList[0];

            System.debug(
                'Invoice PDF - Disbursement Found: ' +
                disbursement.Name
            );
        }
    }
}