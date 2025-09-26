public class SF2060_SV1_Account_Export_1600 implements TxnSecurity.PolicyCondition{
	public boolean evaluate(TxnSecurity.Event e) {
    	
        Integer numberOfRecords = Integer.valueOf(e.data.get('NumberOfRecords'));
    	
        String entityName = e.data.get('EntityName');
   		
        if ('Account'.equals(entityName) && numberOfRecords >= 1600) {
      		return true;
    	}
   		 return false;
  	}
}