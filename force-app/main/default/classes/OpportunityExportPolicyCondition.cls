global class OpportunityExportPolicyCondition implements TxnSecurity.PolicyCondition {
  public boolean evaluate(TxnSecurity.Event e) {
    Integer numberOfRecords = Integer.valueOf(e.data.get('NumberOfRecords'));
    String entityName = e.data.get('EntityName');
    if ('Opportunity'.equals(entityName) && numberOfRecords > 50) {
      return true;
    }
    return false;
  }
}