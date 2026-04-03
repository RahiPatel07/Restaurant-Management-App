@IsTest
private class TableControllerTest {

    @IsTest
    static void testAllocateBestTableAndTransitions() {
        Restaurant__c rest = new Restaurant__c(Name = 'Test Restaurant');
        insert rest;

        Table__c t1 = new Table__c(Name = 'T1', Restaurant__c = rest.Id, Seats__c = 2, Status__c = 'Available');
        Table__c t2 = new Table__c(Name = 'T2', Restaurant__c = rest.Id, Seats__c = 4, Status__c = 'Available');
        Table__c t3 = new Table__c(Name = 'T3', Restaurant__c = rest.Id, Seats__c = 6, Status__c = 'Cleaning');
        insert new List<Table__c>{ t1, t2, t3 };

        // Allocate best table for 3 guests => should pick 4-seat table (T2)
        Id allocatedTableId;
        Test.startTest();
        allocatedTableId = TableController.allocateBestTable(rest.Id, 3);
        Test.stopTest();

        Table__c allocated = [
            SELECT Id, Status__c
            FROM Table__c
            WHERE Id = :allocatedTableId
        ];
        System.assertEquals('Occupied', allocated.Status__c, 'Allocated table should be occupied');

        // Open order should exist for this table
        Order__c ord = [
            SELECT Id, Status__c
            FROM Order__c
            WHERE Table__c = :allocatedTableId
              AND Status__c = 'Open'
            LIMIT 1
        ];
        System.assertNotEquals(null, ord, 'Open order should be created for allocated table');

        // Transition Occupied -> Cleaning -> Available
        TableController.setTableStatus(allocatedTableId, 'Cleaning');
        Table__c cleaned = [SELECT Id, Status__c FROM Table__c WHERE Id = :allocatedTableId];
        System.assertEquals('Cleaning', cleaned.Status__c, 'Table should be cleaning');

        TableController.setTableStatus(allocatedTableId, 'Available');
        Table__c avail = [SELECT Id, Status__c FROM Table__c WHERE Id = :allocatedTableId];
        System.assertEquals('Available', avail.Status__c, 'Table should be available');
    }
}

