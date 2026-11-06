public with sharing class InvoicePDFGeneratorInvocable {

    @InvocableMethod(
        label='Generate Invoice PDF Automatically'
        description='Generates and saves Invoice PDF after Disbursement approval'
    )
    public static void generatePDF(List<Id> invoiceIds) {

        if (invoiceIds == null || invoiceIds.isEmpty()) {
            return;
        }

        List<InvoiceForAward__c> invoices = [
            SELECT Id,
                   Name,
                   Invoice_PDF_Generated__c
            FROM InvoiceForAward__c
            WHERE Id IN :invoiceIds
        ];

        List<ContentVersion> versionsToInsert =
            new List<ContentVersion>();

        Set<Id> generatedInvoiceIds = new Set<Id>();

        for (InvoiceForAward__c invoice : invoices) {
            System.debug(
    '### PDF GENERATION - Invoice Id = ' +
    invoice.Id
);

System.debug(
    '### PDF GENERATION - Invoice Name = ' +
    invoice.Name
);

            if (invoice.Invoice_PDF_Generated__c) {
                continue;
            }

            try {

                PageReference pdfPage = Page.InvoicePDF;

// Pass Invoice Id to Visualforce page
pdfPage.getParameters().clear();
pdfPage.getParameters().put('id', String.valueOf(invoice.Id));
                System.debug(
    '### PDF GENERATION - Visualforce URL = ' +
    pdfPage.getUrl()
);

System.debug(
    'Generating Invoice PDF for Invoice Id: ' +
    invoice.Id
);

Blob pdfBlob;

if (Test.isRunningTest()) {

    pdfBlob = Blob.valueOf('TEST PDF');

} else {

    pdfBlob = pdfPage.getContentAsPDF();

}

                ContentVersion cv = new ContentVersion();

                cv.Title =
                    'Invoice - ' + invoice.Name;

                cv.PathOnClient =
                    'Invoice_' + invoice.Name + '.pdf';

                cv.VersionData =
                    pdfBlob;

                cv.FirstPublishLocationId =
                    invoice.Id;

                versionsToInsert.add(cv);

                generatedInvoiceIds.add(invoice.Id);

            } catch (Exception e) {

                System.debug(
                    'Invoice PDF generation failed for ' +
                    invoice.Id +
                    ': ' +
                    e.getMessage()
                );
            }
        }

        if (!versionsToInsert.isEmpty()) {

            insert versionsToInsert;

            List<InvoiceForAward__c> updates =
                new List<InvoiceForAward__c>();

            for (Id invoiceId : generatedInvoiceIds) {

                updates.add(
                    new InvoiceForAward__c(
                        Id = invoiceId,
                        Invoice_PDF_Generated__c = true
                    )
                );
            }

            if (!updates.isEmpty()) {
                update updates;
            }
        }
    }
}