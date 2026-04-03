import { LightningElement, api, track } from 'lwc';
import getReadyItems from '@salesforce/apex/WaiterListController.getReadyItems';
import markItemsDelivered from '@salesforce/apex/WaiterListController.markItemsDelivered';
import completeOrderAndStartCleaning from '@salesforce/apex/WaiterListController.completeOrderAndStartCleaning';
import getRestaurants from '@salesforce/apex/RestaurantContextController.getRestaurants';

export default class WaiterPendingOrders extends LightningElement {
    @api restaurantId;
    @track queueItems = [];
    @track restaurantOptions = [];
    selectedRestaurantId;
    message;

    connectedCallback() {
        this.loadRestaurants();
    }

    loadRestaurants() {
        getRestaurants()
            .then(opts => {
                this.restaurantOptions = opts || [];
                const preferred = this.restaurantId || (this.restaurantOptions[0] && this.restaurantOptions[0].value);
                if (preferred) {
                    this.selectedRestaurantId = preferred;
                    this.restaurantId = preferred;
                    this.refreshQueue();
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
        this.refreshQueue();
    }

    refreshQueue() {
        if (!this.restaurantId) return;
        getReadyItems({ restaurantId: this.restaurantId })
            .then(result => {
                this.queueItems = result || [];
            })
            .catch(error => {
                // eslint-disable-next-line no-console
                console.error('Error loading waiter queue', error);
                this.queueItems = [];
            });
    }

    handleDelivered(event) {
        const orderItemId = event.currentTarget.dataset.id;
        if (!orderItemId) return;
        markItemsDelivered({ orderItemIds: [orderItemId] })
            .then(() => {
                this.message = 'Item marked as delivered.';
                this.refreshQueue();
            })
            .catch(error => {
                // eslint-disable-next-line no-console
                console.error('Error marking item delivered', error);
                this.message = 'Failed to mark item delivered.';
            });
    }

    handleCompleteOrder(event) {
        const orderId = event.currentTarget.dataset.id;
        if (!orderId) return;
        completeOrderAndStartCleaning({ orderId })
            .then(() => {
                this.message = 'Order completion attempted; table may now be cleaning.';
                this.refreshQueue();
            })
            .catch(error => {
                // eslint-disable-next-line no-console
                console.error('Error completing order', error);
                this.message = 'Failed to complete order.';
            });
    }
}

