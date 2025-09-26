import { LightningElement, api } from "lwc";

const FLOW_VAR_NAME = "recordId";
const FLOW_TYPE = "String";
const FLOW_API_NAME = "CC_Screen_Invoice_Milestones";

export default class InvoiceMilestoneEmbeddedFlow extends LightningElement {
  @api recordId;

  get inputVariables() {
    const variables = [
      {
        name: FLOW_VAR_NAME,
        type: FLOW_TYPE,
        value: this.recordId
      }
    ];
    console.log("Input Variables: ", variables);
    return variables;
  }

  get flowName() {
    console.log("Flow Name: ", FLOW_API_NAME);
    return FLOW_API_NAME;
  }

  renderedCallback() {
    console.log(
      "Component Rendered Successfully, with RecordId: ",
      this.recordId
    );
  }
}