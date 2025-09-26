public class SF2010_SV2_Contact_Export_3000_5999 implements TxnSecurity.PolicyCondition {
	public boolean evaluate(TxnSecurity.Event e) {
   
        Integer numberOfRecords = Integer.valueOf(e.data.get('NumberOfRecords'));
   
        String entityName = e.data.get('EntityName');
   
        if ('Contact'.equals(entityName) && numberOfRecords >= 3000 && numberOfRecords <= 5999) {
            
            return true;
        }
        	return false;
    }
}