public with sharing class ReviewClassicApprovalWorkItem {

    public class Request {
        @InvocableVariable(required=true)
        public Id workItemId;

        @InvocableVariable(required=true)
        public String action;

        @InvocableVariable
        public String comments;
    }

    public class Response {
        @InvocableVariable
        public Boolean success;

        @InvocableVariable
        public String message;
    }

    @InvocableMethod(
        label='Review Classic Approval Work Item'
        description='Approve or reject a Classic Salesforce Approval Process work item.'
    )
    public static List<Response> reviewWorkItem(List<Request> requests) {

        List<Response> responses = new List<Response>();

        for (Request req : requests) {

            Response response = new Response();

            try {

                if (req.workItemId == null) {
                    throw new AuraHandledException(
                        'Approval Work Item ID is required.'
                    );
                }

                if (String.isBlank(req.action)) {
                    throw new AuraHandledException(
                        'Approval action is required.'
                    );
                }

                String normalizedAction = req.action.trim();

                if (
                    normalizedAction != 'Approve' &&
                    normalizedAction != 'Reject'
                ) {
                    throw new AuraHandledException(
                        'Action must be Approve or Reject.'
                    );
                }

                Approval.ProcessWorkitemRequest approvalRequest =
                    new Approval.ProcessWorkitemRequest();

                approvalRequest.setWorkitemId(req.workItemId);
                approvalRequest.setAction(normalizedAction);

                if (!String.isBlank(req.comments)) {
                    approvalRequest.setComments(req.comments);
                }

                Approval.ProcessResult result =
                    Approval.process(approvalRequest);

                if (result.isSuccess()) {

                    response.success = true;
                    response.message =
                        'Approval work item was successfully ' +
                        normalizedAction.toLowerCase() +
                        'd.';

                } else {

                    response.success = false;

                    if (result.getErrors() != null &&
                        !result.getErrors().isEmpty()) {

                        List<String> errors = new List<String>();

                        for (Database.Error err : result.getErrors()) {
                            errors.add(err.getStatusCode() + ': ' + err.getMessage());
                        }

                        response.message = String.join(errors, ' | ');

                    } else {

                        response.message =
                            'Salesforce could not process the approval work item.';
                    }
                }

            } catch (Exception e) {

                response.success = false;
                response.message = e.getMessage();
            }

            responses.add(response);
        }

        return responses;
    }
}