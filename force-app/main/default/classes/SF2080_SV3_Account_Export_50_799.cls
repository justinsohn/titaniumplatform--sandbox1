public class SF2080_SV3_Account_Export_50_799 implements TxnSecurity.PolicyCondition{
	public boolean evaluate(TxnSecurity.Event e) {
    	
        Integer numberOfRecords = Integer.valueOf(e.data.get('NumberOfRecords'));
    	
        String entityName = e.data.get('EntityName');
   		
        if ('Account'.equals(entityName) && numberOfRecords >= 50 && numberOfRecords >= 799) {
      		return true;
    	}
   		 return false;
  	}
}