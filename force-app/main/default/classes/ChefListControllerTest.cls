@IsTest
private class ChefListControllerTest {

    @IsTest
    static void testChefQueueAndStateTransitions() {
        Restaurant__c rest = new Restaurant__c(Name = 'Chef Test Restaurant');
        insert rest;

        Table__c tableRec = new Table__c(
            Name = 'Chef-T1',
            Restaurant__c = rest.Id,
            Seats__c = 4,
            Status__c = 'Occupied'
        );
        insert tableRec;

        Menu_Item__c menu1 = new Menu_Item__c(
            Name = 'Soup',
            Restaurant__c = rest.Id,
            Category__c = 'Appetizer',
            Food_Type__c = 'Vegetarian',
            Price__c = 8
        );
        insert menu1;

        Order__c ord = new Order__c(
            Restaurant__c = rest.Id,
            Table__c = tableRec.Id,
            Status__c = 'Open',
            Order_Start_Time__c = System.now()
        );
        insert ord;

        Order_Item__c line = new Order_Item__c(
            Order__c = ord.Id,
            Menu_Item__c = menu1.Id,
            Quantity__c = 2,
            Unit_Price__c = 8,
            Line_Total__c = 16,
            Status__c = 'Confirmed'
        );
        insert line;

        Test.startTest();
        ChefListController.setActiveChefCount(rest.Id, 3);
        Integer chefCount = ChefListController.getActiveChefCount(rest.Id);
        System.assertEquals(3, chefCount, 'Chef count should be updated');

        List<ChefListController.ChefOrderItemDTO> queue =
            ChefListController.getPendingAndPreparingItems(rest.Id);
        System.assertEquals(1, queue.size(), 'Queue should include the confirmed item');
        System.assertEquals('Confirmed', queue[0].status, 'Item should start as confirmed');

        ChefListController.acceptItems(new List<Id>{ line.Id });
        line = [SELECT Id, Status__c FROM Order_Item__c WHERE Id = :line.Id];
        System.assertEquals('Preparing', line.Status__c, 'After accept it should be preparing');

        ChefListController.markItemsReady(new List<Id>{ line.Id });
        line = [SELECT Id, Status__c FROM Order_Item__c WHERE Id = :line.Id];
        System.assertEquals('Ready', line.Status__c, 'After ready action it should be ready');
        Test.stopTest();
    }
}

