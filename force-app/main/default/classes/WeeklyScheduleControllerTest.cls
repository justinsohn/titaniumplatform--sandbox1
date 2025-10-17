@isTest
private class WeeklyScheduleControllerTest {
  @isTest
  static void testGetMonthlyActuals() {
    project_cloud__Project__c project = new project_cloud__Project__c(
      Name = 'Test Project'
    );
    insert project;

    project_cloud__Project_Task__c projectTask = new project_cloud__Project_Task__c(
      Name = 'Task 1',
      project_cloud__Project__c = project.Id
    );
    insert projectTask;

    Id userId = UserInfo.getUserId();
    Date julyStart = Date.newInstance(2023, 7, 1);
    Date julyMid = Date.newInstance(2023, 7, 15);

    List<project_cloud__Work__c> workRecords = new List<project_cloud__Work__c>{
      new project_cloud__Work__c(
        Name = 'Work 1',
        project_cloud__Project__c = project.Id,
        project_cloud__Project_Task__c = projectTask.Id,
        project_cloud__Resource__c = userId,
        project_cloud__Date__c = julyStart,
        project_cloud__Hours__c = 10,
        project_cloud__Status__c = 'Approved'
      ),
      new project_cloud__Work__c(
        Name = 'Work 2',
        project_cloud__Project__c = project.Id,
        project_cloud__Project_Task__c = projectTask.Id,
        project_cloud__Resource__c = userId,
        project_cloud__Date__c = julyMid,
        project_cloud__Hours__c = 21,
        project_cloud__Status__c = 'Approved'
      )
    };
    insert workRecords;

    Test.startTest();
    Map<String, Object> response = WeeklyScheduleController.getMonthlyActuals(
      project.Id,
      julyStart,
      Date.newInstance(2023, 7, 31),
      new List<Id>{ userId },
      new List<Id>{ projectTask.Id }
    );
    Test.stopTest();

    List<String> months = (List<String>) response.get('months');
    System.assertEquals(
      1,
      months.size(),
      'Expected a single month in the response'
    );
    System.assertEquals(
      '2023-07',
      months[0],
      'Unexpected month label returned'
    );

    Map<String, Map<String, Decimal>> actuals = (Map<String, Map<String, Decimal>>) response.get(
      'actuals'
    );
    String key = userId + '|' + projectTask.Id;
    System.assert(
      actuals.containsKey(key),
      'Expected resource/task key to be present'
    );

    Map<String, Decimal> monthTotals = actuals.get(key);
    System.assertEquals(
      1,
      monthTotals.size(),
      'Expected totals for a single month'
    );
    System.assertEquals(
      31,
      monthTotals.get('2023-07'),
      'Unexpected total hours for July'
    );
  }
}
