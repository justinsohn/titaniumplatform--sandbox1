@isTest(SeeAllData=true)
public class CPQQuoteLineTriggerHandlerTest {
    
    static testMethod void totalMaintenanceCalculationTest() {

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
            WHERE ProductCode in ('MT-TITAN-PLATFORM', 'TITAN-PLATFORM') and IsActive = true]) {

            SBQQ__QuoteLine__c quoteLine = new SBQQ__QuoteLine__c();
            quoteLine.SBQQ__Product__c = prod.id;
            quoteLine.CPQ_Maintenance_Type__c = (prod.ProductCode == 'MT-TITAN-PLATFORM'? 'Gold': '');
            quoteLine.CPQ_Product_Category_Report2__c = (prod.ProductCode == 'MT-TITAN-PLATFORM'? '': 'TITAN PLATFORM-Titan Platform');
            quoteLine.SBQQ__Group__c = quoteLineGroup.Id;
            quoteLine.SBQQ__Quote__c = quote.id;

            quoteLineList.add(quoteLine);
        }

        insert quoteLineList;
    }

    static testMethod void total3PCalculationTest() {

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
            WHERE ProductCode in ('CP-TITAN22-S', '3P-RedHat-RTU-NN') and IsActive = true]) {

            SBQQ__QuoteLine__c quoteLine = new SBQQ__QuoteLine__c();
            quoteLine.SBQQ__Product__c = prod.id;
            quoteLine.CPQ_3rd_Party_Category__c = 'TITAN PLATFORM';
            quoteLine.SBQQ__Group__c = quoteLineGroup.Id;
            quoteLine.CPQ_RTU_Multiplier__c = 3;
            quoteLine.SBQQ__Quantity__c = 2;
            quoteLine.SBQQ__Quote__c = quote.id;

            quoteLineList.add(quoteLine);
        }

        insert quoteLineList;
    }
}