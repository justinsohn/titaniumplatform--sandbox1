/********************************************
 * @author          Von Alvin Pernicia
 * @Date            08-03-22
 * @description     trigger for CPQ Quote Line
 * 
 *             No.    Date(dd-mm-yy)  Author         Description
 *            -----  -------------   -------        ---------------
 * @version     1     08-03-2022      Von Pernicia   To total maintenance product
 ********************************************/

trigger CPQQuoteLineTrigger on SBQQ__QuoteLine__c (before insert, before update) {

    if (Trigger.isInsert ) {
        CPQQuoteLineTriggerHandler.beforeInsert(trigger.new);
    }

    if ( Trigger.isUpdate) {
        CPQQuoteLineTriggerHandler.beforeUpdate(trigger.new);
    }
}