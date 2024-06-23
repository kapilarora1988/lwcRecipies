public without sharing class MergeChildRecordsToMaster {

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
                queryString += ' LIMIT '+(Limits.getLimitQueryRows() - Limits.getQueryRows());
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
        if(sObjectMap.size()>0 && sObjectMap.size() < Limits.getLimitDMLRows()-Integer.valueOf(Label.Merge_Duplicates_Threshold_For_Reparenting)){
            UPDATE sObjectMap.values();
        }
        if(sObjectMap.size() < Limits.getLimitDMLRows()-Integer.valueOf(Label.Merge_Duplicates_Threshold_For_Reparenting)){
            SObject obj = slaveId.getSObjectType().newSObject();
            obj.put('Id',slaveId);
            DELETE obj;
        }
    }
}