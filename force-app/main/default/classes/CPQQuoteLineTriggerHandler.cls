/********************************************
 * @author          Von Alvin Pernicia
 * @Date            08-03-22
 * @description     trigger for CPQ Quote Line
 * 
 *             No.    Date(dd-mm-yy)  Author         Description
 *            -----  -------------   -------        ---------------
 * @version     1     08-03-2022      Von Pernicia   To total maintenance product
 ********************************************/
public with sharing class CPQQuoteLineTriggerHandler {

    public static void beforeUpdate(List<SBQQ__QuoteLine__c> triggerNew) {

        total3PCalculation(triggerNew);
        totalMaintenanceCalculation(triggerNew);
    }

    public static void beforeInsert(List<SBQQ__QuoteLine__c> triggerNew) {

        total3PCalculation(triggerNew);
        totalMaintenanceCalculation(triggerNew);
    }

    public static void total3PCalculation(List<SBQQ__QuoteLine__c> triggerNew) {
        
        Map<String, Decimal> total3pPerGroupMap = new Map<String, Decimal>();

        // compute multiplier and sum the result per group
        for (SBQQ__QuoteLine__c quoteLine: triggerNew) {

            if (!String.isEmpty(quoteLine.CPQ_3rd_Party_Category__c) && !quoteLine.CPQ_3rd_Party_Quantity__c) {

                String thirdPartyproduct = quoteLine.SBQQ__ProductCode__c;
                if (!thirdPartyproduct.contains('3P')) {
                    quoteLine.CPQ_Sum_of_RTU_Multiplier__c = quoteLine.CPQ_RTU_Multiplier__c * quoteLine.SBQQ__Quantity__c;
                    
                    if (total3pPerGroupMap.containsKey(quoteLine.CPQ_3rd_Party_Group_Label__c)) {

                        Decimal currentTotal = total3pPerGroupMap.get(quoteLine.CPQ_3rd_Party_Group_Label__c) + quoteLine.CPQ_Sum_of_RTU_Multiplier__c;
                        total3pPerGroupMap.put(quoteLine.CPQ_3rd_Party_Group_Label__c, currentTotal);
                    } else {
                        total3pPerGroupMap.put(quoteLine.CPQ_3rd_Party_Group_Label__c, quoteLine.CPQ_Sum_of_RTU_Multiplier__c);
                    }
                }
            }
        }

        // update 3P quantity base on CPQ_3rd_Party_Group_Label__c
        if (!total3pPerGroupMap.isEmpty()) {
            for (SBQQ__QuoteLine__c quoteLine: triggerNew) {

                String thirdPartyproduct = quoteLine.SBQQ__ProductCode__c;
                if (thirdPartyproduct.contains('3P') && !quoteLine.CPQ_3rd_Party_Quantity__c) {
                    quoteLine.SBQQ__Quantity__c = total3pPerGroupMap.get(quoteLine.CPQ_3rd_Party_Group_Label__c);
                    quoteLine.CPQ_3rd_Party_Quantity__c = true;
                }
            }
        }
    }

    public static void totalMaintenanceCalculation(List<SBQQ__QuoteLine__c> triggerNew) {

        Map<String, String> lookupMap = new Map<String, String>();
        Map<String, Boolean> lookupNetPriceMap = new Map<String, Boolean>();
        Map<String, Decimal> titanPlatformTotalMap = new Map<String, Decimal>();
        Set<Id> quoteLineIDSet = new Set<Id>();
        Set<String> quoteNameSet = new Set<String>();

        // to pull product where we put the total 
        for (SBQQ__LookupData__c lookup : [SELECT CPQ_Product_Code__c, Product_Category_Level_5__c, CPQ_Is_NetPrice__c
                                        FROM SBQQ__LookupData__c 
                                        WHERE CPQ_Type_of_Data__c = 'Maintenance Percent'])
        {
            if (lookup.Product_Category_Level_5__c != null) {
                lookupMap.put(lookup.Product_Category_Level_5__c, lookup.CPQ_Product_Code__c);
                lookupNetPriceMap.put(lookup.Product_Category_Level_5__c, lookup.CPQ_Is_NetPrice__c);
            }
        }

        // to sum product SBQQ__NetPrice__c or SBQQ__PackageTotal__c base on CPQ_Product_Category_Level_5__c and group
        for (SBQQ__QuoteLine__c quoteLine: triggerNew) {
            
            if (quoteLine.SBQQ__Group__c != null && lookupMap.containsKey(quoteLine.CPQ_Product_Category_Level_5__c)) {
                
                Decimal packageTotal = (lookupNetPriceMap.get(quoteLine.CPQ_Product_Category_Level_5__c) ? quoteLine.SBQQ__NetPrice__c: quoteLine.SBQQ__PackageTotal__c);
                String key = quoteLine.SBQQ__Quote__c +'~'+ quoteLine.CPQ_Product_Category_Level_5__c +'~'+ quoteLine.CPQ_Group_Label_Number__c;
                
                if (titanPlatformTotalMap.containsKey(key)) {
                    
                    Decimal currentPackageTotal = titanPlatformTotalMap.get(key);
                    titanPlatformTotalMap.put(key, currentPackageTotal + packageTotal);
                } else {
                    
                    titanPlatformTotalMap.put(key, packageTotal);
                }
            }
        }

        // to update product
        for (SBQQ__QuoteLine__c quoteLine: triggerNew) {
                
            for (String mapKey: titanPlatformTotalMap.KeySet()) {
                
                List<String> arraySplit = mapKey.split('~');
                if (arraySplit[2] == quoteLine.CPQ_Group_Label_Number__c && lookupMap.get(arraySplit[1]) == quoteLine.SBQQ__ProductCode__c && arraySplit[0] == quoteLine.SBQQ__Quote__c) {
                    
                    
                    quoteLine.CPQ_Bare_Total_Package__c = titanPlatformTotalMap.get(mapKey);
                }
            }
        } 
    }
}