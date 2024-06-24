/**
 * @description       : This js is used to display records for parent and selected duplicate record 
 *                      as well as to merge the record
 * @author            : Kapil Arora
 * @group             : 
 * @last modified on  : 22-06-2024
 * @last modified by  : Kapil Arora
 * Modifications Log 
 * Ver   Date         Author                               Modification
 * 1.0   22-06-2024   Kapil Arora                          Initial Version
**/
import { LightningElement, api, wire } from 'lwc';
import { ShowToastEvent} from 'lightning/platformShowToastEvent';
import getMergeRecordsData from '@salesforce/apex/DuplicateRecordsHandler.getMergeRecordsData';
import { updateRecord } from "lightning/uiRecordApi";
import doReparenting from '@salesforce/apex/DuplicateRecordsHandler.doReparenting';
import { refreshApex } from '@salesforce/apex';

export default class MergeDuplicatesChild extends LightningElement {

    @api
    recordIds;

    value
    mergedRecords
    wiredValues
    fieldsDataToMerge = {}
    @api
    ifRecordSelected = false
    @wire(getMergeRecordsData, {
        records: '$recordIds'
    })wiredData(response) {
        this.wiredValues = response
        const {data,error} = response
        if(data){
            this.mergedRecords = []
            this.fieldsDataToMerge = {}
            this.mergedRecords = Object.values(data).filter(result=>{
                return result.val1 && result.val2 && result.val1 !== result.val2
            })
        }
        if(error){
            this.showNotification('Error',error.body.message,'error')
        }
    }


    handleMerge(){

        if(JSON.stringify(this.fieldsDataToMerge) === "{}"){
            this.showNotification('Error','Please select fields to merge','error')
        }else{
            console.log(JSON.stringify(this.fieldsDataToMerge,null,2))
            let fields = {...this.fieldsDataToMerge, ['Id']:this.recordIds.split('--')[1]}
            console.log(JSON.stringify(fields,null,2))
            const recordInput = { fields }
            updateRecord(recordInput).then(result=>{
                refreshApex(this.wiredValues)
                doReparenting({records : this.recordIds})
                this.showNotification('Success','Successfully Merged')
                this.dispatchEvent(new CustomEvent("close"))
            }).catch(error=>{
                this.showNotification('Error',error.body.message,'error')
            })
        }
        
    }

    handleCancel(){
        this.refreshData()
        this.dispatchEvent(new CustomEvent("close"))
    }

    handlePrev(){
        this.refreshData()
        this.dispatchEvent(new CustomEvent("previous"));
    }

    @api
    showNotification(title,message,variant){
        this.dispatchEvent(
            new ShowToastEvent({
                title:title,
                message:message,
                variant: variant || 'success' 
            })
        )
    }

    handleChange(event){
        const {name,value} = event.target
        this.fieldsDataToMerge = {...this.fieldsDataToMerge, [name]:value}
        console.log(JSON.stringify(this.fieldsDataToMerge,null,2))
    }

    handleSelectAll(event){
        const {name,value} = event.target
        if(value=='Master'){
            this.mergedRecords.map(result=>{
                const fieldname = result.fieldName
                this.template.querySelectorAll(`input[name="${fieldname}"]`)[0].click()
            })
        }else{
            this.mergedRecords.map(result=>{
                const fieldname = result.fieldName
                this.template.querySelectorAll(`input[name="${fieldname}"]`)[1].click()
            })
        }
    }

    @api
    refreshData(){
        refreshApex(this.wiredValues)
    }
    
}