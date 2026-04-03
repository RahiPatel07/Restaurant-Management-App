public with sharing class TableController {

    public class TableDTO {
        @AuraEnabled public Id id;
        @AuraEnabled public String name;
        @AuraEnabled public Integer seats;
        @AuraEnabled public String status;
    }

    @AuraEnabled(cacheable=true)
    public static List<TableDTO> getTables(Id restaurantId) {
        if (restaurantId == null) {
            return new List<TableDTO>();
        }

        List<Table__c> tables = [
            SELECT Id, Name, Seats__c, Status__c
            FROM Table__c
            WHERE Restaurant__c = :restaurantId
            ORDER BY Name
        ];

        List<TableDTO> result = new List<TableDTO>();
        for (Table__c t : tables) {
            TableDTO dto = new TableDTO();
            dto.id = t.Id;
            dto.name = t.Name;
            dto.seats = Integer.valueOf(t.Seats__c);
            dto.status = t.Status__c;
            result.add(dto);
        }
        return result;
    }

    /**
     * Allocates the "best" available table for the given guest count:
     * the smallest Available/Reserved table with Seats__c >= guestCount.
     */
    @AuraEnabled
    public static Id allocateBestTable(Id restaurantId, Integer guestCount) {
        if (restaurantId == null) {
            throw new AuraHandledException('Restaurant Id is required.');
        }
        if (guestCount == null || guestCount <= 0) {
            throw new AuraHandledException('Guest count must be positive.');
        }

        List<Table__c> chosenList = [
            SELECT Id, Status__c, Restaurant__c
            FROM Table__c
            WHERE Restaurant__c = :restaurantId
              AND Seats__c >= :guestCount
              AND (Status__c = 'Available' OR Status__c = 'Reserved')
            ORDER BY Seats__c ASC, CreatedDate ASC
            LIMIT 1
        ];
        Table__c chosen = chosenList.isEmpty() ? null : chosenList[0];

        if (chosen == null) {
            return null;
        }

        setTableStatusInternal(chosen.Id, 'Occupied');

        // Ensure there's an open order for this table
        List<Order__c> openOrders = [
            SELECT Id
            FROM Order__c
            WHERE Table__c = :chosen.Id
              AND Status__c = 'Open'
            LIMIT 1
        ];
        Order__c openOrder = openOrders.isEmpty() ? null : openOrders[0];

        // If the query found none, create one.
        if (openOrder == null) {
            Table__c t = [
                SELECT Id, Restaurant__c
                FROM Table__c
                WHERE Id = :chosen.Id
                LIMIT 1
            ];
            openOrder = new Order__c(
                Restaurant__c = t.Restaurant__c,
                Table__c = t.Id,
                Status__c = 'Open',
                Order_Start_Time__c = System.now()
            );
            insert openOrder;
        }

        return chosen.Id;
    }

    @AuraEnabled
    public static void setTableStatus(Id tableId, String newStatus) {
        if (tableId == null || String.isBlank(newStatus)) {
            throw new AuraHandledException('Table Id and new status are required.');
        }
        setTableStatusInternal(tableId, newStatus.trim());
    }

    private static void setTableStatusInternal(Id tableId, String newStatus) {
        Table__c t = [
            SELECT Id, Status__c
            FROM Table__c
            WHERE Id = :tableId
            FOR UPDATE
        ];

        String oldStatus = t.Status__c;

        // Basic workflow validation aligned to the spec.
        if (oldStatus == 'Available' && newStatus == 'Occupied') {
            // ok
        } else if (oldStatus == 'Reserved' && newStatus == 'Occupied') {
            // ok
        } else if (oldStatus == 'Occupied' && newStatus == 'Cleaning') {
            // ok
        } else if (oldStatus == 'Cleaning' && newStatus == 'Available') {
            // ok
        } else if (oldStatus == newStatus) {
            // ok no-op
        } else {
            throw new AuraHandledException('Invalid table status transition: ' + oldStatus + ' -> ' + newStatus);
        }

        t.Status__c = newStatus;
        update t;
    }
}

