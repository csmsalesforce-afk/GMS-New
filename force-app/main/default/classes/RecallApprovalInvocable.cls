public class RecallApprovalInvocable {
    @InvocableMethod(label='Recall Approval')
    public static void recallApproval(List<Id> recordIds) {
        for (Id recordId : recordIds) {
            List<ProcessInstanceWorkitem> wiList = [
                SELECT Id
                FROM ProcessInstanceWorkitem
                WHERE ProcessInstance.TargetObjectId = :recordId
                LIMIT 1
            ];

            if (!wiList.isEmpty()) {
                Approval.ProcessWorkitemRequest req =
                    new Approval.ProcessWorkitemRequest();
                req.setWorkitemId(wiList[0].Id);
                req.setAction('Removed');
                Approval.process(req);
            }
        }
    }
}