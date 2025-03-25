public with sharing class ApprovalPreviewControllerLWC {
    public Id objectId { get; set; }
    public String apEmpty { get; set; }
    public String pendingPI { get; set; }
    public Id theApprovalUserId { get; set; }
    public String theObjectType { get; set; }
    public ApprovalProcess ap { get; set; }
    public Approval.ProcessResult submitResult { get; set; }
    public List<ApprovalStep> stepsForComments = new List<ApprovalStep>();
    public Boolean alreadySubmitted { get; set; }  // New flag to indicate record already in approval process

    public ApprovalPreviewControllerLWC(Id objectId) {
        this.objectId = objectId;
        this.alreadySubmitted = false;
    }

    @AuraEnabled
    public static ApprovalPreviewResponse runPreview(Id objectId) {
        ApprovalPreviewControllerLWC controller = new ApprovalPreviewControllerLWC(objectId);
        controller.runPreview();
        return new ApprovalPreviewResponse(controller.ap, controller.apEmpty, controller.pendingPI, controller.stepsForComments, controller.alreadySubmitted);
    }

    @AuraEnabled
    public static Boolean submitForApproval(Id objectId, String stepsForComments) {
        ApprovalPreviewControllerLWC controller = new ApprovalPreviewControllerLWC(objectId);
        try {
            controller.submitForApproval(stepsForComments);
            return true;
        } catch (Exception e) {
            throw new AuraHandledException(e.getMessage());
        }
    }

    public void runPreview() {
        theObjectType = objectId.getSObjectType().getDescribe().getName();
        theApprovalUserId = UserInfo.getUserId();
        System.Savepoint sp1 = Database.setSavepoint();

        try {
            Approval.ProcessSubmitRequest req1 = new Approval.ProcessSubmitRequest();
            req1.setComments('Submitting request for approval.');
            req1.setObjectId(objectId);
            req1.setSubmitterId(theApprovalUserId);
            Approval.ProcessResult result = Approval.process(req1);
            Id newInstanceID = goThroughSteps(result);

            List<ProcessInstance> newInstanceList = [
                SELECT Id, ProcessDefinition.Name, ProcessDefinition.Description, 
                       (SELECT Id, ProcessInstanceID, OriginalActorId, OriginalActor.Name, ProcessNodeID, ProcessNode.Name 
                        FROM StepsAndWorkItems 
                        WHERE StepStatus = 'Approved' 
                        ORDER BY Id)
                FROM ProcessInstance
                WHERE Id = :newInstanceID 
                LIMIT 1
            ];
            ProcessInstance newInstance = newInstanceList[0];
            ap = new ApprovalProcess();
            ap.processName = newInstance.ProcessDefinition.Name;
            ap.processDescription = newInstance.ProcessDefinition.Description;

            for (ProcessInstanceHistory pih : newInstance.StepsAndWorkitems) {
                ApprovalStep aStep = new ApprovalStep();
                aStep.stepNumber = ap.approvalSteps.size() + 1;
                aStep.stepName = pih.ProcessNode.Name;
                aStep.approver = pih.OriginalActor.Name;
                ap.approvalSteps.add(aStep);
                stepsForComments.add(aStep);
            }
        } 
        catch (DmlException e) {
            System.debug('Exception: ' + e.getMessage());
            if (e.getMessage().contains('NO_APPLICABLE_PROCESS')) {
                apEmpty = 'This record does not meet the entry criteria for any approval processes. Please reach out to your System Administrator for assistance.';
            } else if (e.getMessage().contains('ALREADY_IN_PROCESS')) {
                // Instead of just setting an error message, query the existing process instance details.
                alreadySubmitted = true;
                List<ProcessInstance> existingPIList = [
                    SELECT Id, ProcessDefinition.Name, ProcessDefinition.Description,
                           (SELECT Id, ProcessInstanceID, OriginalActorId, OriginalActor.Name, ProcessNodeID, ProcessNode.Name, StepStatus
                            FROM StepsAndWorkItems
                            ORDER BY CreatedDate)
                    FROM ProcessInstance
                    WHERE TargetObjectId = :objectId
                    ORDER BY CreatedDate DESC
                    LIMIT 1
                ];
                if(existingPIList.isEmpty()){
                    pendingPI = 'Record is already submitted for approval but details could not be retrieved.';
                } else {
                    ProcessInstance existingPI = existingPIList[0];
                    ap = new ApprovalProcess();
                    ap.processName = existingPI.ProcessDefinition.Name;
                    ap.processDescription = existingPI.ProcessDefinition.Description;
                    // Loop through steps and include the status in the step name.
                    for (ProcessInstanceHistory pih : existingPI.StepsAndWorkItems) {
                        ApprovalStep aStep = new ApprovalStep();
                        aStep.stepNumber = ap.approvalSteps.size() + 1;
                        String stepName = (pih.ProcessNode.Name == null || pih.ProcessNode.Name.trim() == '') ? 'Started' : pih.ProcessNode.Name;
                        aStep.stepName = stepName + ' (' + pih.StepStatus + ')';
                        aStep.approver = pih.OriginalActor.Name;
                        ap.approvalSteps.add(aStep);
                        stepsForComments.add(aStep);
                    }
                }
            }
        }
        
        Database.rollback(sp1);
    }

    public Id goThroughSteps(Approval.ProcessResult result) {
        List<Id> newWorkItemIds = result.getNewWorkitemIds();
        ProcessInstanceWorkitem piw = [SELECT Id, ActorId, Actor.Name, ProcessInstanceId 
                                       FROM ProcessInstanceWorkitem 
                                       WHERE Id = :newWorkItemIds[0]];
        Approval.ProcessWorkitemRequest req2 = new Approval.ProcessWorkitemRequest();
        req2.setComments('Approving request.');
        req2.setAction('Approve');
        req2.setWorkitemId(newWorkItemIds.get(0));
        Approval.ProcessResult result2 = Approval.process(req2);

        if (!result2.getNewWorkitemIds().isEmpty()) {
            goThroughSteps(result2);
        }
        return result2.getInstanceId();
    }

    public void submitForApproval(String stepsForComments) {
        Id currentUserId = UserInfo.getUserId();
        List<String> asStrings = new List<String>();
        try {
            List<ApprovalStep> steps = (List<ApprovalStep>) JSON.deserialize(stepsForComments, List<ApprovalStep>.class);
            for (ApprovalStep aStep : steps) {
                String approvalStepString = aStep.stepNumber + '. ' + aStep.stepName + ' - ' + aStep.approver;
                asStrings.add(approvalStepString);
            }
        } catch (Exception e) {
            throw new AuraHandledException('Invalid stepsForComments JSON: ' + e.getMessage());
        }
        String joined = String.join(asStrings, '\n' + ' ');

        Approval.ProcessSubmitRequest req = new Approval.ProcessSubmitRequest();
        req.setObjectId(objectId);
        req.setComments('Submitting request for approval - assigned approvers: \n' + joined);
        req.setSubmitterId(currentUserId);
        submitResult = Approval.process(req);
    }

    public class ApprovalProcess {
        @AuraEnabled public String processName { get; set; }
        @AuraEnabled public String processDescription { get; set; }
        @AuraEnabled public List<ApprovalStep> approvalSteps {
            get {
                if (approvalSteps == null) approvalSteps = new List<ApprovalStep>();
                return approvalSteps;
            }
            set;
        }
    }

    public class ApprovalStep {
        @AuraEnabled public Integer stepNumber { get; set; }
        @AuraEnabled public String stepName { get; set; }
        @AuraEnabled public String approver { get; set; }
    }

    public class ApprovalPreviewResponse {
        @AuraEnabled public ApprovalProcess ap { get; set; }
        @AuraEnabled public String apEmpty { get; set; }
        @AuraEnabled public String pendingPI { get; set; }
        @AuraEnabled public List<ApprovalStep> stepsForComments { get; set; }
        @AuraEnabled public Boolean alreadySubmitted { get; set; }  // New flag for UI control

        public ApprovalPreviewResponse(ApprovalProcess ap, String apEmpty, String pendingPI, List<ApprovalStep> stepsForComments, Boolean alreadySubmitted) {
            this.ap = ap;
            this.apEmpty = apEmpty;
            this.pendingPI = pendingPI;
            this.stepsForComments = stepsForComments;
            this.alreadySubmitted = alreadySubmitted;
        }
    }
}