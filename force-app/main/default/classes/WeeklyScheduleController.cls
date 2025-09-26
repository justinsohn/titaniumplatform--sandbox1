public with sharing class WeeklyScheduleController {

    private static final Map<String, Integer> DAY_OF_WEEK_MAP = new Map<String, Integer>{
        'Sunday' => 1,
        'Monday' => 2,
        'Tuesday' => 3,
        'Wednesday' => 4,
        'Thursday' => 5,
        'Friday' => 6,
        'Saturday' => 7
    };

    public class WeeklyScheduleData {
        @AuraEnabled
        public List<project_cloud__Resource_Assignment__c> assignments { get; set; }

        @AuraEnabled
        public Map<String, Decimal> actualHours { get; set; }

        // Constructor to make it easy to populate
        public WeeklyScheduleData(List<project_cloud__Resource_Assignment__c> assignments, Map<String, Decimal> actualHours) {
            this.assignments = assignments;
            this.actualHours = actualHours;
        }
    }

    @AuraEnabled(cacheable=true)
    public static WeeklyScheduleData getResourceAssignments(Id recordId) {
        System.debug('getResourceAssignments called with recordId: ' + recordId);
        List<project_cloud__Resource_Assignment__c> assignments = [
            SELECT Id, Name, 
                   project_cloud__Calculated_Start__c, 
                   project_cloud__Calculated_End__c, 
                   project_cloud__User__r.Id, 
                   project_cloud__User__r.FirstName, 
                   project_cloud__User__r.LastName,
                   project_cloud__User__r.ccpe_r__Cost__c,
                   project_cloud__Resource_Summary__r.project_cloud__Resource_Assignment_Count__c,
                   project_cloud__Resource_Summary__r.project_cloud__Project_Task__r.Name,
                   project_cloud__Resource_Summary__r.project_cloud__Project_Task__r.Price_Rev_Sold__c,
                   project_cloud__Resource_Summary__r.project_cloud__Project_Task__r.project_cloud__Estimated_Hours__c,
                   (SELECT Id, Week_Start_Date__c, Planned_Hours__c, Planned_Cost__c, Planned_Revenue__c FROM Weekly_Schedules__r) 
            FROM project_cloud__Resource_Assignment__c 
            WHERE project_cloud__Resource_Summary__r.project_cloud__Project_Task__r.project_cloud__Project_Phase__r.project_cloud__Project__c = :recordId
            AND project_cloud__IsInactive__c = false
        ];
        System.debug('Found ' + assignments.size() + ' assignments.');
        // Get actuals data.
        Set<Id> resourceIds = new Set<Id>();
        Date minDate;
        Date maxDate;
        for (project_cloud__Resource_Assignment__c a : assignments) {
            if (a.project_cloud__User__r != null) {
                resourceIds.add(a.project_cloud__User__r.Id);
            }
            Date startDate = a.project_cloud__Calculated_Start__c;
            Date endDate = a.project_cloud__Calculated_End__c;
            if (startDate != null) {
                if (minDate == null || startDate < minDate) {
                    minDate = startDate;
                }
            }
            if (endDate != null) {
                if (maxDate == null || endDate > maxDate) {
                    maxDate = endDate;
                }
            }
        }
        Map<String, Decimal> approvedHoursMap = new Map<String, Decimal>();
        if (!resourceIds.isEmpty()) {
            approvedHoursMap = getApprovedHours(resourceIds, minDate, maxDate);
        }
        return new WeeklyScheduleData(assignments, approvedHoursMap);
    }

    public static Map<String, Decimal> getApprovedHours(Set<Id> resourceIds, Date projectStartDate, Date projectEndDate) {
        Map<String, Decimal> actualsMap = new Map<String, Decimal>();
        // Query for the aggregated work records
        List<project_cloud__Work__c> approvedWork = [
            SELECT 
                OwnerId, 
                project_cloud__Date__c, 
                project_cloud__Hours__c 
            FROM 
                project_cloud__Work__c 
            WHERE 
                project_cloud__Status__c = 'Approved' 
                AND OwnerId IN :resourceIds
                AND project_cloud__Date__c >= :projectStartDate
                AND project_cloud__Date__c <= :projectEndDate
        ];
        // Loop through each record to manually group and sum
        for (project_cloud__Work__c work : approvedWork) {
            Date weekStartDate = getSundayOfDate(work.project_cloud__Date__c);
            String key = work.OwnerId + '-' + String.valueOf(weekStartDate);
            Decimal hours = actualsMap.get(key);
            if (hours == null) {
                hours = 0;
            }
            actualsMap.put(key, hours + work.project_cloud__Hours__c);
        }
        return actualsMap;
    }

    // Helper to find the Sunday for any given date
    private static Date getSundayOfDate(Date inputDate) {
        // 1. Convert the Date into a Datetime object (set to midnight)
        Datetime dt = Datetime.newInstance(inputDate, Time.newInstance(0, 0, 0, 0));
        
        // 2. Call format() on the Datetime object to get the day's name
        String dayName = dt.format('EEEE');
        
        // 3. Look up the corresponding number (1-7) from the map
        Integer day = DAY_OF_WEEK_MAP.get(dayName);
        
        // 4. Return the calculated Sunday Date
        return inputDate.addDays(-(day - 1));
    }

    @AuraEnabled
    public static void saveWeeklySchedules(List<Weekly_Schedule__c> weeklySchedules) {
        upsert weeklySchedules;
    }
}