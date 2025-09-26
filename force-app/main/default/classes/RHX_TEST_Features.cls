@isTest(SeeAllData=true)
public class RHX_TEST_Features {
    static testMethod void RHX_Testmethod() {
        List<sObject> sourceList = [SELECT Id 
            FROM Features__c order by lastmodifieddate desc LIMIT 1];
        if(sourceList.size() == 0) {
            sourceList.add(
                    new Features__c()
            );
        }
        rh2.ParentUtil.UpsertRollupTestRecords( sourceList );
    }
}