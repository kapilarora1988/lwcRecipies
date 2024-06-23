/**********************************************************
Apex Class Name    : MergeChildRecordsToMaster
Created Date       : June 22, 2024
@description       : This is class is used for reparenting all the custom and standard related 
                     objects with master record Id post merge
@author            : Kapil Arora
Modification Log:
Ver   Date         Author                               Modification
1.0   22-06-2024   Kapil Arora                          Initial Version
*********************************************************
*/
public without sharing class MergeChildRecordsToMaster {

    /**********************************************************
    @Method Name    : mergeChildRecords
    @author         : Kapil Arora
    @description    : This method  is used for reparenting all the custom and standard related 
                      objects with master record Id post merge
    @param          : Id masterId, Id slaveId
    @return         : void
    ********************************************************
    */
    public static void mergeChildRecords(Id masterId, Id slaveId){
        List<SObject> sObjectList = new List<SObject>();
        Map<Id, SObject> sObjectMap = new Map<Id, SObject>();
        Schema.DescribeSObjectResult sObjectResult = slaveId.getSObjectType().getDescribe();
        for(Schema.ChildRelationship childRelation : sObjectResult.getChildRelationships()){
            String queryString = 'SELECT Id';
            boolean relationExists = false;
            if(childRelation.getChildSObject().getDescribe().getName().contains('__c') || Label.Merge_Duplicates_Objects_For_Reparenting.containsIgnoreCase(childRelation.getChildSObject().getDescribe().getName())){
                for(Schema.SobjectField strFld : childRelation.getChildSObject().getDescribe().fields.getMap().Values()){
                    if(strFld.getDescribe().getType() == Schema.DisplayType.Reference){
                        if(slaveId.getSObjectType() == strFld.getDescribe().getReferenceTo()[0]){
                            relationExists = true;
                            queryString = queryString + ', ' + strFld.getDescribe().getName();
                        }
                    }
                }
            }
            if(relationExists){
                queryString = queryString + ' FROM ' + childRelation.getChildSObject().getDescribe().getName() + ' WHERE';
                integer n = 0;
                for(Schema.SobjectField strFld : childRelation.getChildSObject().getDescribe().fields.getMap().Values()){
                    if(strFld.getDescribe().getType() == Schema.DisplayType.Reference){
                        if(slaveId.getSObjectType() == strFld.getDescribe().getReferenceTo()[0]){
                            if(n == 0){
                                queryString = queryString + ' ' + strFld.getDescribe().getName() + ' =: slaveId';
                            } else {
                                queryString = queryString + ' OR ' + strFld.getDescribe().getName() + ' =: slaveId';
                            }
                            n++;
                        }
                    }
                }
                for(SObject obj : Database.query(queryString)){
                    Id objId = (Id)obj.get('Id');
                    for(Schema.SobjectField strFld : objId.getSObjectType().getDescribe().fields.getMap().Values()){
                        if(strFld.getDescribe().isUpdateable()){
                            if(strFld.getDescribe().getType() == Schema.DisplayType.Reference){
                                if(slaveId.getSObjectType() == strFld.getDescribe().getReferenceTo()[0]){
                                    if((Id)obj.get(strFld.getDescribe().getName()) == slaveId){
                                        obj.put(strFld.getDescribe().getName(), masterId);
                                        sObjectMap.put((Id)obj.get('Id'), obj);
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
        if(sObjectMap.size()>0){
            UPDATE sObjectMap.values();
        }
        SObject obj = slaveId.getSObjectType().newSObject();
        obj.put('Id',slaveId);
        DELETE obj;
        sObjectMap.clear();
        mergeGenericChildRecords(masterId,slaveId);
    }

    /**********************************************************
    @Method Name    : mergeGenericChildRecords
    @author         : Kapil Arora
    @description    : This method  is used for reparenting all the generic related 
                      objects with master record Id post merge
    @param          : Id masterId, Id slaveId
    @return         : void
    ********************************************************
    */
    private static void mergeGenericChildRecords(Id masterId, Id slaveId){
        List<Task> toBeMergedTasks = new List<Task>();
        List<Task> oldTasks = [Select Id,WhatId,WhoId,Subject, Status, Priority, Description from Task where WhatId =: slaveId];
        for(Task objTask : oldTasks){
            toBeMergedTasks.add(new Task(WhatId = masterId,WhoId=objTask.WhoId,Subject=objTask.Subject, Status=objTask.Status, Priority=objTask.Priority, Description=objTask.Description));
        }
        if(oldTasks.size()>0){
            INSERT toBeMergedTasks;
            DELETE oldTasks;
        }
        toBeMergedTasks.clear();
        oldTasks.clear();

        List<Event> toBeMergedEvents = new List<Event>();
        List<Event> oldEvents = [Select Id,WhoId, WhatId, Subject, Location, StartDateTime, EndDateTime, DurationInMinutes, Description, EndDate, IsAllDayEvent, ActivityDateTime, ActivityDate from Event where WhatId =: slaveId];
        for(Event objEvent : oldEvents){
            toBeMergedEvents.add(new Event(WhatId = masterId,WhoId=objEvent.WhoId,Subject=objEvent.Subject,Location=objEvent.Location, StartDateTime=objEvent.StartDateTime, 
            EndDateTime=objEvent.EndDateTime, DurationInMinutes=objEvent.DurationInMinutes, Description=objEvent.Description, IsAllDayEvent=objEvent.IsAllDayEvent, ActivityDateTime=objEvent.ActivityDateTime, ActivityDate=objEvent.ActivityDate));
        }
        if(oldEvents.size()>0){
            INSERT toBeMergedEvents;
            DELETE oldEvents;
        }
        toBeMergedEvents.clear();
        oldEvents.clear();

        List<ContentDocumentLink> toBeMergedContents = new List<ContentDocumentLink>();
        List<ContentDocumentLink> oldContents = [Select Id,LinkedEntityId,ContentDocumentId,ShareType, Visibility From ContentDocumentLink where LinkedEntityId =: slaveId];
        for(ContentDocumentLink objContentDocumentLink : oldContents){
            toBeMergedContents.add(new ContentDocumentLink(LinkedEntityId=masterId,ContentDocumentId=objContentDocumentLink.ContentDocumentId,ShareType=objContentDocumentLink.ShareType, Visibility=objContentDocumentLink.Visibility));
        }
        if(oldContents.size()>0){
            INSERT toBeMergedContents;
            DELETE oldContents;
        }
    }
}