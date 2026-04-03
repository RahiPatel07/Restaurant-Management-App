import { LightningElement, api, track } from 'lwc';
import getTables from '@salesforce/apex/TableController.getTables';
import allocateBestTable from '@salesforce/apex/TableController.allocateBestTable';
import setTableStatus from '@salesforce/apex/TableController.setTableStatus';
import getRestaurants from '@salesforce/apex/RestaurantContextController.getRestaurants';

export default class TestTables extends LightningElement {
    @api restaurantId;

    @track tables;
    @track restaurantOptions = [];
    selectedRestaurantId;
    guestCount = 2;
    message;

    connectedCallback() {
        this.loadRestaurants();
        this.refreshTables();
    }

    loadRestaurants() {
        getRestaurants()
            .then(opts => {
                this.restaurantOptions = opts || [];
                if (!this.restaurantId && this.restaurantOptions.length > 0) {
                    this.selectedRestaurantId = this.restaurantOptions[0].value;
                    this.restaurantId = this.selectedRestaurantId;
                    this.refreshTables();
                }
            })
            .catch(error => {
                // eslint-disable-next-line no-console
                console.error('Error loading restaurants', error);
                this.restaurantOptions = [];
            });
    }

    handleRestaurantChange(event) {
        this.selectedRestaurantId = event.detail.value;
        this.restaurantId = this.selectedRestaurantId;
        this.refreshTables();
    }

    refreshTables() {
        if (!this.restaurantId) return;
        getTables({ restaurantId: this.restaurantId })
            .then(result => {
                this.tables = (result || []).map(t => ({
                    ...t,
                    isAvailable: t.status === 'Available',
                    isOccupied: t.status === 'Occupied',
                    isCleaning: t.status === 'Cleaning',
                    isReserved: t.status === 'Reserved'
                }));
            })
            .catch(error => {
                // eslint-disable-next-line no-console
                console.error('Error loading tables', error);
                this.tables = [];
            });
    }

    get hasTables() {
        return this.tables && this.tables.length > 0;
    }

    get disableActions() {
        return !this.restaurantId;
    }

    handleGuestCountChange(event) {
        this.guestCount = event.target.value;
    }

    handleAllocateBestTable() {
        this.message = null;
        allocateBestTable({
            restaurantId: this.restaurantId,
            guestCount: parseInt(this.guestCount, 10)
        })
            .then(tableId => {
                if (!tableId) {
                    this.message = 'No suitable table available.';
                    this.refreshTables();
                    return;
                }
                this.message = `Allocated table ${tableId}.`;
                this.refreshTables();
            })
            .catch(error => {
                // eslint-disable-next-line no-console
                console.error('Error allocating table', error);
                this.message = 'Failed to allocate table.';
            });
    }

    handleSetOccupied(event) {
        const tableId = event.currentTarget.dataset.id;
        this.setStatus(tableId, 'Occupied');
    }

    handleSetCleaning(event) {
        const tableId = event.currentTarget.dataset.id;
        this.setStatus(tableId, 'Cleaning');
    }

    handleSetAvailable(event) {
        const tableId = event.currentTarget.dataset.id;
        this.setStatus(tableId, 'Available');
    }

    setStatus(tableId, status) {
        this.message = null;
        setTableStatus({ tableId, newStatus: status })
            .then(() => {
                this.message = `Table updated to ${status}.`;
                this.refreshTables();
            })
            .catch(error => {
                // eslint-disable-next-line no-console
                console.error('Error updating table status', error);
                this.message = 'Failed to update table status.';
                this.refreshTables();
            });
    }

}

