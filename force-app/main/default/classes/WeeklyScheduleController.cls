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
    public WeeklyScheduleData(
      List<project_cloud__Resource_Assignment__c> assignments,
      Map<String, Decimal> actualHours
    ) {
      this.assignments = assignments;
      this.actualHours = actualHours;
    }
  }

  @AuraEnabled(cacheable=true)
  public static WeeklyScheduleData getResourceAssignments(Id recordId) {
    System.debug('getResourceAssignments called with recordId: ' + recordId);
    List<project_cloud__Resource_Assignment__c> assignments = [
      SELECT
        Id,
        Name,
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
        (
          SELECT
            Id,
            Week_Start_Date__c,
            Planned_Hours__c,
            Planned_Cost__c,
            Planned_Revenue__c
          FROM Weekly_Schedules__r
        )
      FROM project_cloud__Resource_Assignment__c
      WHERE
        project_cloud__Resource_Summary__r.project_cloud__Project_Task__r.project_cloud__Project_Phase__r.project_cloud__Project__c = :recordId
        AND project_cloud__IsInactive__c = FALSE
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

  @AuraEnabled(cacheable=true)
  public static Map<String, Object> getMonthlyActuals(
    Id projectId,
    Date monthStart,
    Date monthEnd,
    List<Id> userIds,
    List<Id> taskIds
  ) {
    Map<String, Object> response = new Map<String, Object>();
    List<String> monthLabels = new List<String>();
    Map<String, Map<String, Decimal>> actualsByKey = new Map<String, Map<String, Decimal>>();

    if (projectId == null || monthStart == null || monthEnd == null) {
      response.put('months', monthLabels);
      response.put('actuals', actualsByKey);
      return response;
    }

    Date normalizedStart = Date.newInstance(
      monthStart.year(),
      monthStart.month(),
      1
    );
    Date normalizedEnd = Date.newInstance(monthEnd.year(), monthEnd.month(), 1);

    if (normalizedStart > normalizedEnd) {
      response.put('months', monthLabels);
      response.put('actuals', actualsByKey);
      return response;
    }

    Date currentMonth = normalizedStart;
    while (currentMonth <= normalizedEnd) {
      monthLabels.add(
        formatYearMonth(currentMonth.year(), currentMonth.month())
      );
      currentMonth = currentMonth.addMonths(1);
    }

    String query = buildMonthlyActualsQuery(
      projectId,
      monthStart,
      monthEnd,
      userIds,
      taskIds
    );
    List<AggregateResult> aggregates = Database.query(query);

    for (AggregateResult aggregate : aggregates) {
      String resourceId = (String) aggregate.get('resourceId');
      String taskId = (String) aggregate.get('taskId');
      Integer yearValue = (Integer) aggregate.get('yearValue');
      Integer monthValue = (Integer) aggregate.get('monthValue');
      Decimal totalHours = (Decimal) aggregate.get('totalHours');

      String key = buildResourceTaskKey(resourceId, taskId);
      Map<String, Decimal> monthTotals = actualsByKey.get(key);
      if (monthTotals == null) {
        monthTotals = new Map<String, Decimal>();
        for (String monthLabel : monthLabels) {
          monthTotals.put(monthLabel, 0);
        }
        actualsByKey.put(key, monthTotals);
      }

      String monthLabel = formatYearMonth(yearValue, monthValue);
      Decimal existingValue = monthTotals.get(monthLabel);
      if (existingValue == null) {
        existingValue = 0;
      }
      monthTotals.put(
        monthLabel,
        existingValue + (totalHours == null ? 0 : totalHours)
      );
    }

    response.put('months', monthLabels);
    response.put('actuals', actualsByKey);
    return response;
  }

  public static Map<String, Decimal> getApprovedHours(
    Set<Id> resourceIds,
    Date projectStartDate,
    Date projectEndDate
  ) {
    Map<String, Decimal> actualsMap = new Map<String, Decimal>();
    // Query for the aggregated work records
    List<project_cloud__Work__c> approvedWork = [
      SELECT OwnerId, project_cloud__Date__c, project_cloud__Hours__c
      FROM project_cloud__Work__c
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

  private static String buildMonthlyActualsQuery(
    Id projectId,
    Date monthStart,
    Date monthEnd,
    List<Id> userIds,
    List<Id> taskIds
  ) {
    StringBuilder queryBuilder = new StringBuilder();
    queryBuilder.append('SELECT ');
    queryBuilder.append('project_cloud__Resource__c resourceId, ');
    queryBuilder.append('project_cloud__Project_Task__c taskId, ');
    queryBuilder.append('CALENDAR_YEAR(project_cloud__Date__c) yearValue, ');
    queryBuilder.append('CALENDAR_MONTH(project_cloud__Date__c) monthValue, ');
    queryBuilder.append('SUM(project_cloud__Hours__c) totalHours ');
    queryBuilder.append('FROM project_cloud__Work__c ');
    queryBuilder.append(
      'WHERE project_cloud__Status__c = ' + quoteLiteral('Approved') + ' '
    );
    queryBuilder.append(
      'AND project_cloud__Project__c = ' +
        quoteLiteral(String.valueOf(projectId)) +
        ' '
    );
    queryBuilder.append(
      'AND project_cloud__Date__c >= ' + buildDateLiteral(monthStart) + ' '
    );
    queryBuilder.append(
      'AND project_cloud__Date__c <= ' + buildDateLiteral(monthEnd) + ' '
    );

    if (userIds != null && !userIds.isEmpty()) {
      String userIdList = buildIdList(userIds);
      if (!String.isBlank(userIdList)) {
        queryBuilder.append(
          'AND project_cloud__Resource__c IN (' + userIdList + ') '
        );
      }
    }
    if (taskIds != null && !taskIds.isEmpty()) {
      String taskIdList = buildIdList(taskIds);
      if (!String.isBlank(taskIdList)) {
        queryBuilder.append(
          'AND project_cloud__Project_Task__c IN (' + taskIdList + ') '
        );
      }
    }

    queryBuilder.append(
      'GROUP BY project_cloud__Resource__c, project_cloud__Project_Task__c, '
    );
    queryBuilder.append(
      'CALENDAR_YEAR(project_cloud__Date__c), CALENDAR_MONTH(project_cloud__Date__c)'
    );
    return queryBuilder.toString();
  }

  private static String buildResourceTaskKey(String resourceId, String taskId) {
    String safeResourceId = resourceId == null ? '' : resourceId;
    String safeTaskId = taskId == null ? '' : taskId;
    return safeResourceId + '|' + safeTaskId;
  }

  private static String formatYearMonth(Integer yearValue, Integer monthValue) {
    if (yearValue == null || monthValue == null) {
      return '';
    }
    String monthString = String.valueOf(monthValue);
    if (monthValue < 10) {
      monthString = '0' + monthString;
    }
    return String.valueOf(yearValue) + '-' + monthString;
  }

  private static String buildDateLiteral(Date inputDate) {
    if (inputDate == null) {
      throw new AuraHandledException('Month dates are required.');
    }
    Datetime dateTimeValue = Datetime.newInstance(
      inputDate,
      Time.newInstance(0, 0, 0, 0)
    );
    return dateTimeValue.formatGmt('yyyy-MM-dd');
  }

  private static String buildIdList(List<Id> ids) {
    List<String> quotedIds = new List<String>();
    for (Id idValue : ids) {
      if (idValue != null) {
        quotedIds.add(quoteLiteral(String.valueOf(idValue)));
      }
    }
    return String.join(quotedIds, ',');
  }

  private static String quoteLiteral(String value) {
    String quote = getSingleQuote();
    String safeValue = value == null ? '' : String.escapeSingleQuotes(value);
    return quote + safeValue + quote;
  }

  private static String getSingleQuote() {
    return String.fromCharArray(new List<Integer>{ 39 });
  }

  @AuraEnabled
  public static void saveWeeklySchedules(
    List<Weekly_Schedule__c> weeklySchedules
  ) {
    upsert weeklySchedules;
  }
}
