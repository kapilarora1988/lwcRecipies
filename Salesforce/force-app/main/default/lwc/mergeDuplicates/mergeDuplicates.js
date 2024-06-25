/**
 * @description       : This js is used to display the duplicate records for a given record type
 * @author            : Kapil Arora
 * @group             : 
 * @last modified on  : 22-06-2024
 * @last modified by  : Kapil Arora
 * Modifications Log 
 * Ver   Date         Author                               Modification
 * 1.0   22-06-2024   Kapil Arora                          Initial Version
**/
import { LightningElement, api, wire } from 'lwc';
import getDuplicateRecords from '@salesforce/apex/DuplicateRecordsHandler.getDuplicateRecords';
import { CloseActionScreenEvent } from 'lightning/actions';
import { refreshApex } from '@salesforce/apex';
const actions = [
    { label: 'Merge', name: 'merge_record', iconName: 'utility:merge_field' }
];
export default class MergeDuplicates extends LightningElement {
    @api
    recordId;
    wiredDataResult
    columns
    showDupRecords
    mergeRecords
    ifRecordSelected
    wiredValues

    @wire(getDuplicateRecords, {
        record: '$recordId',
        offset: 0,
        limitSize: 150
        
    })
    wiredData(response) {
        this.wiredValues = response
        const {data,error} = response
        if(data){
            this.wiredDataResult = []
            this.columns = [
                {  
                    label: "Record Link",  
                    fieldName: "recordLink",  
                    type: "url",  
                    typeAttributes: { label: { fieldName: "Name" }, tooltip:"Name", target: "_blank" }  
                } 
            ];
            this.wiredDataResult = data.data;
            this.wiredDataResult = this.wiredDataResult.map(item=>{
                item = {...item, ['recordLink']:'/'+item.Id}
                return item
            })
            let columnsData = Array.from(data.columns)
            this.columns.splice(this.columns.length, 0, ...columnsData);
            this.columns.push({ type: 'action', typeAttributes: { rowActions: actions, menuAlignment: 'auto' } })
            this.showDupRecords = true
        }
        if(error){
            this.template.querySelector("c-merge-duplicates-child").showNotification('Error',error.body.message,'error')
            this.handleClose()
        }
    }

    handleRowAction(event) {
        const action = event.detail.action;
        const row = event.detail.row;
        this.mergeRecords = row.Id+'--'+ this.recordId;
        this.template.querySelector("c-merge-duplicates-child").clearData()
        this.template.querySelector("c-merge-duplicates-child").refreshData()
        this.ifRecordSelected = true
        this.showDupRecords = false
    }

    handlePrev(){
        refreshApex(this.wiredValues)
        this.ifRecordSelected = false
        this.showDupRecords = true
    }
    handleClose(){
        refreshApex(this.wiredValues)
        this.dispatchEvent(new CloseActionScreenEvent());
    }
    
}