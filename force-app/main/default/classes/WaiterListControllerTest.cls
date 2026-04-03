@IsTest
private class WaiterListControllerTest {

    @IsTest
    static void testReadyItemsAndDeliveryFlow() {
        Restaurant__c rest = new Restaurant__c(Name = 'Waiter Test Restaurant');
        insert rest;

        Table__c tableRec = new Table__c(
            Name = 'Waiter-T1',
            Restaurant__c = rest.Id,
            Seats__c = 4,
            Status__c = 'Occupied'
        );
        insert tableRec;

        Menu_Item__c menu1 = new Menu_Item__c(
            Name = 'Burger',
            Restaurant__c = rest.Id,
            Category__c = 'Entree',
            Food_Type__c = 'Non-Vegetarian',
            Price__c = 12
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
            Quantity__c = 1,
            Unit_Price__c = 12,
            Line_Total__c = 12,
            Status__c = 'Ready'
        );
        insert line;

        Test.startTest();
        // Ready items should include this line
        List<WaiterListController.WaiterOrderItemDTO> queue =
            WaiterListController.getReadyItems(rest.Id);
        System.assertEquals(1, queue.size(), 'There should be one ready item');

        // Mark delivered
        WaiterListController.markItemsDelivered(new List<Id>{ line.Id });
        line = [SELECT Id, Status__c FROM Order_Item__c WHERE Id = :line.Id];
        System.assertEquals('Delivered', line.Status__c, 'Item should be delivered');

        // Complete order and start cleaning
        WaiterListController.completeOrderAndStartCleaning(ord.Id);
        ord = [SELECT Id, Status__c, Table__c FROM Order__c WHERE Id = :ord.Id];
        System.assertEquals('Completed', ord.Status__c, 'Order should be completed');

        Table__c tableAfter = [SELECT Id, Status__c FROM Table__c WHERE Id = :tableRec.Id];
        System.assertEquals('Cleaning', tableAfter.Status__c, 'Table should be cleaning after order completion');
        Test.stopTest();
    }
}

