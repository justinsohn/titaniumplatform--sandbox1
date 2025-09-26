/**
 * @description Schedulable Apex class to generate Revenue Recognition records
 * for active projects based on project tasks. Can also be run for a single project.
 */
public class RevenueRecognitionSchedulable implements Schedulable {

    // Define the project statuses to exclude from processing.
    private static final Set<String> EXCLUDED_PROJECT_STATUSES = new Set<String>{
        'Completed', 'Cancelled', 'Closed Duplicate'
    };

    // Member variable to hold a single Project Id if the job is run for a specific project
    private Id singleProjectIdToProcess = null;

    /**
     * @description Default constructor used by the Schedulable framework.
     */
    public RevenueRecognitionSchedulable() {
        // This constructor is used when the class is scheduled.
        // singleProjectIdToProcess will remain null.
    }

    /**
     * @description Constructor to allow running the logic for a single project.
     * @param projectId The Id of the project_cloud__Project__c record to process.
     */
    public RevenueRecognitionSchedulable(Id projectId) {
        this.singleProjectIdToProcess = projectId;
    }

    /**
     * @description Executes the scheduled job or on-demand processing.
     * @param sc SchedulableContext from the platform (can be null for on-demand execution).
     */
    public void execute(SchedulableContext sc) {
        List<project_cloud__Revenue_Recognition__c> revenueRecognitionsToInsert = new List<project_cloud__Revenue_Recognition__c>();
        List<project_cloud__Project_Milestone__c> newMilestonesToCreate = new List<project_cloud__Project_Milestone__c>();
        Map<Id, Map<String, Id>> projectToExistingMilestoneNameMap = new Map<Id, Map<String, Id>>();
        Map<String, project_cloud__Project_Milestone__c> pendingNewMilestonesMap = new Map<String, project_cloud__Project_Milestone__c>();

        // --- Step 1: Query all relevant Project Tasks ---
        List<project_cloud__Project_Task__c> tasksToProcess = new List<project_cloud__Project_Task__c>();
        String baseQuery = 'SELECT Id, Name, project_cloud__Project__c, project_cloud__Project_Milestone__c, Product_Family__c, ' +
                           'Rev_Rec_Actual__c, Rev_Rec_Actual_Prior_Period__c, Opportunity_Product__c, ' +
                           'project_cloud__Project_Phase__r.project_cloud__Project__c ' + // Project Id via Phase
                           'FROM project_cloud__Project_Task__c ';

        String whereClause = 'WHERE project_cloud__Project_Phase__r.project_cloud__Project__r.Status_Custom__c NOT IN :EXCLUDED_PROJECT_STATUSES ' +
                             'AND (Rev_Rec_Actual__c != NULL OR Rev_Rec_Actual_Prior_Period__c != NULL) ' +
                             'AND Opportunity_Product__c != NULL';

        if (this.singleProjectIdToProcess != null) {
            // If a single project ID is provided, add it to the WHERE clause.
            // Also, ensure the specific project itself is not in an excluded status.
            // We query the project status directly here to ensure the single project is valid.
            try {
                project_cloud__Project__c singleProject = [SELECT Status_Custom__c FROM project_cloud__Project__c WHERE Id = :singleProjectIdToProcess LIMIT 1];
                if (EXCLUDED_PROJECT_STATUSES.contains(singleProject.Status_Custom__c)) {
                    System.debug('The specified single project ' + this.singleProjectIdToProcess + ' has an excluded status: ' + singleProject.Status_Custom__c + '. Skipping processing.');
                    return;
                }
            } catch (QueryException e) {
                 System.debug('Error querying the specified single project ' + this.singleProjectIdToProcess + ': ' + e.getMessage() + '. Skipping processing.');
                 return;
            }
            whereClause += ' AND project_cloud__Project_Phase__r.project_cloud__Project__c = :singleProjectIdToProcess';
        }

        String finalQuery = baseQuery + whereClause;

        try {
            tasksToProcess = Database.query(finalQuery);
        } catch (Exception e) {
            System.debug('Error querying Project Tasks: ' + e.getMessage());
            return;
        }

        if (tasksToProcess.isEmpty()) {
            if (this.singleProjectIdToProcess != null) {
                System.debug('No project tasks found for project ' + this.singleProjectIdToProcess + ' meeting the criteria for revenue recognition.');
            } else {
                System.debug('No project tasks found meeting the criteria for revenue recognition across all projects.');
            }
            return;
        }

        // --- Step 2: Collect Project Ids to fetch their existing milestones ---
        Set<Id> projectIdsForMilestoneQuery = new Set<Id>();
        for (project_cloud__Project_Task__c task : tasksToProcess) {
            Id projectIdForTask = task.project_cloud__Project_Phase__r != null ? task.project_cloud__Project_Phase__r.project_cloud__Project__c : task.project_cloud__Project__c;
            if (projectIdForTask != null) {
                projectIdsForMilestoneQuery.add(projectIdForTask);
            }
        }

        // --- Step 3: Query existing Project Milestones for all relevant projects ---
        if (!projectIdsForMilestoneQuery.isEmpty()) {
            for (project_cloud__Project_Milestone__c milestone : [
                SELECT Id, Name, project_cloud__Project__c
                FROM project_cloud__Project_Milestone__c
                WHERE project_cloud__Project__c IN :projectIdsForMilestoneQuery
            ]) {
                if (!projectToExistingMilestoneNameMap.containsKey(milestone.project_cloud__Project__c)) {
                    projectToExistingMilestoneNameMap.put(milestone.project_cloud__Project__c, new Map<String, Id>());
                }
                projectToExistingMilestoneNameMap.get(milestone.project_cloud__Project__c).put(milestone.Name, milestone.Id);
            }
        }

        // --- Step 4: Identify and prepare new milestones for creation ---
        for (project_cloud__Project_Task__c task : tasksToProcess) {
            Id currentProjectId = task.project_cloud__Project_Phase__r != null ? task.project_cloud__Project_Phase__r.project_cloud__Project__c : task.project_cloud__Project__c;
            if (currentProjectId == null) continue;

            if (task.project_cloud__Project_Milestone__c == null && String.isNotBlank(task.Product_Family__c)) {
                String newMilestoneKey = currentProjectId + '-' + task.Product_Family__c;
                Map<String, Id> existingProjectMilestones = projectToExistingMilestoneNameMap.get(currentProjectId);
                boolean alreadyExistsInDB = existingProjectMilestones != null && existingProjectMilestones.containsKey(task.Product_Family__c);

                if (!alreadyExistsInDB && !pendingNewMilestonesMap.containsKey(newMilestoneKey)) {
                    project_cloud__Project_Milestone__c newMilestone = new project_cloud__Project_Milestone__c(
                        Name = task.Product_Family__c,
                        project_cloud__Project__c = currentProjectId
                    );
                    pendingNewMilestonesMap.put(newMilestoneKey, newMilestone);
                    newMilestonesToCreate.add(newMilestone);
                }
            }
        }

        // --- Step 5: Insert new milestones if any ---
        if (!newMilestonesToCreate.isEmpty()) {
            try {
                Database.SaveResult[] srListMilestones = Database.insert(newMilestonesToCreate, false);
                for (Integer i = 0; i < srListMilestones.size(); i++) {
                    if (srListMilestones[i].isSuccess()) {
                        project_cloud__Project_Milestone__c createdMilestone = newMilestonesToCreate[i];
                         if (!projectToExistingMilestoneNameMap.containsKey(createdMilestone.project_cloud__Project__c)) {
                            projectToExistingMilestoneNameMap.put(createdMilestone.project_cloud__Project__c, new Map<String, Id>());
                        }
                        projectToExistingMilestoneNameMap.get(createdMilestone.project_cloud__Project__c).put(createdMilestone.Name, createdMilestone.Id);
                    } else {
                        for(Database.Error err : srListMilestones[i].getErrors()) {
                            System.debug('Error creating milestone: ' + err.getStatusCode() + ': ' + err.getMessage() + ' Fields: ' + err.getFields());
                        }
                    }
                }
            } catch (Exception e) {
                System.debug('DML Exception on Milestone insert: ' + e.getMessage());
            }
        }

        // --- Step 6: Create Revenue Recognition records ---
        Date recognitionDate = Date.today();
        for (project_cloud__Project_Task__c task : tasksToProcess) {
            Id currentProjectId = task.project_cloud__Project_Phase__r != null ? task.project_cloud__Project_Phase__r.project_cloud__Project__c : task.project_cloud__Project__c;
            if (currentProjectId == null) continue;

            Decimal revRecActual = task.Rev_Rec_Actual__c == null ? 0 : task.Rev_Rec_Actual__c;
            Decimal revRecPrior = task.Rev_Rec_Actual_Prior_Period__c == null ? 0 : task.Rev_Rec_Actual_Prior_Period__c;
            Decimal amount = revRecActual - revRecPrior;

            Id milestoneForRevRecId = task.project_cloud__Project_Milestone__c;
            if (milestoneForRevRecId == null && String.isNotBlank(task.Product_Family__c)) {
                Map<String, Id> projectMilestonesMap = projectToExistingMilestoneNameMap.get(currentProjectId);
                if (projectMilestonesMap != null && projectMilestonesMap.containsKey(task.Product_Family__c)) {
                    milestoneForRevRecId = projectMilestonesMap.get(task.Product_Family__c);
                }
            }

            project_cloud__Revenue_Recognition__c rr = new project_cloud__Revenue_Recognition__c(
                project_cloud__Project__c = currentProjectId,
                Project_Task__c = task.Id,
                project_cloud__Project_Milestone__c = milestoneForRevRecId,
                project_cloud__Amount__c = amount,
                project_cloud__Date__c = recognitionDate,
                project_cloud__Type__c = 'Recognized',
                product_family__c = task.Product_Family__c // *** UPDATED API NAME HERE ***
            );
            revenueRecognitionsToInsert.add(rr);
        }

        // --- Step 7: Insert Revenue Recognition records ---
        if (!revenueRecognitionsToInsert.isEmpty()) {
            try {
                Database.SaveResult[] srListRevRecs = Database.insert(revenueRecognitionsToInsert, false);
                for (Integer i = 0; i < srListRevRecs.size(); i++) {
                    if (!srListRevRecs[i].isSuccess()) {
                         for(Database.Error err : srListRevRecs[i].getErrors()) {
                            System.debug('Error creating Revenue Recognition: ' + err.getStatusCode() + ': ' + err.getMessage() + ' Fields: ' + err.getFields());
                        }
                    }
                }
            } catch (Exception e) {
                System.debug('DML Exception on Revenue Recognition insert: ' + e.getMessage());
            }
        }
        System.debug('RevenueRecognitionSchedulable finished. Created ' + revenueRecognitionsToInsert.size() + ' Revenue Recognition records.');
    }
}