public class SF2070_SV2_Account_Export_800_1599 implements TxnSecurity.PolicyCondition{
	public boolean evaluate(TxnSecurity.Event e) {
    	
        Integer numberOfRecords = Integer.valueOf(e.data.get('NumberOfRecords'));
    	
        String entityName = e.data.get('EntityName');
   		
        if ('Account'.equals(entityName) && numberOfRecords >= 800 && numberOfRecords >= 1599) {
      		return true;
    	}
   		 return false;
  	}
}