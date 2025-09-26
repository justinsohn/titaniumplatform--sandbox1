@isTest(SeeAllData=true)
public class QuoteLinesControllerTest {
    static testMethod void quoteLineTableDetailsTest() {
        
        //create quote
        SBQQ__Quote__c quote = new SBQQ__Quote__c(
            //SBQQ__Opportunity2__c = opp.Id,
            //SBQQ__Account__c = acctRec.Id,
            SBQQ__Type__c = 'Quote',
            SBQQ__Status__c = 'Draft'
        );
        insert quote;

        SBQQ__QuoteLineGroup__c quoteLineGroup = new SBQQ__QuoteLineGroup__c(
            //SBQQ__Account__c = acctRec.Id,
            SBQQ__Quote__c = quote.Id,
            SBQQ__Number__c = 1
        );

        insert quoteLineGroup;

        List<SBQQ__QuoteLine__c> quoteLineList = new List<SBQQ__QuoteLine__c>();
        for (Product2 prod: [
            SELECT id, ProductCode, nAME
            FROM Product2
            WHERE ProductCode in ('PS-SD-SDE', 'PS-SD-PMO') and IsActive = true]) {

            SBQQ__QuoteLine__c quoteLine = new SBQQ__QuoteLine__c();
            quoteLine.SBQQ__Product__c = prod.id;
            //quoteLine.CPQ_Maintenance_Type__c = (prod.ProductCode == 'MT-TITAN-PLATFORM'? 'Gold': '');
            //quoteLine.CPQ_Product_Category_Report2__c = (prod.ProductCode == 'MT-TITAN-PLATFORM'? '': 'TITAN PLATFORM-Titan Platform');
            quoteLine.SBQQ__Group__c = quoteLineGroup.Id;
            quoteLine.SBQQ__Quote__c = quote.id;

            quoteLineList.add(quoteLine);
        }

        insert quoteLineList;

        Id approvalRuleId = [SELECT Id FROM sbaa__ApprovalRule__c where name like '%Professional Services Level 1: Disc of 21-25% Marc Fouquet%' limit 1].id;
        Id approverId = [SELECT id FROM sbaa__Approver__c limit 1].id;

        sbaa__Approval__c approval = new sbaa__Approval__c(
            sbaa__Status__c = 'Requested',
            Quote__c = quote.id,
            sbaa__Rule__c = approvalRuleId,
            sbaa__ApprovalStep__c = 1,
            sbaa__RecordField__c = 'Quote__c',
            sbaa__AssignedTo__c = UserInfo.getUserId(),
            sbaa__Approver__c = approverId
        );

        insert approval;

        Test.startTest();
        QuoteLinesController quoteLine = new QuoteLinesController();
        quoteLine.approvalId = approval.Id;
        quoteLine.test1();
        Test.stopTest();  
    }
    
}