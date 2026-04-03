import { LightningElement, api, track } from 'lwc';
import getActiveChefCount from '@salesforce/apex/ChefListController.getActiveChefCount';
import setActiveChefCount from '@salesforce/apex/ChefListController.setActiveChefCount';
import getPendingAndPreparingItems from '@salesforce/apex/ChefListController.getPendingAndPreparingItems';
import acceptItems from '@salesforce/apex/ChefListController.acceptItems';
import markItemsReady from '@salesforce/apex/ChefListController.markItemsReady';
import getRestaurants from '@salesforce/apex/RestaurantContextController.getRestaurants';

export default class ChefPendingOrders extends LightningElement {
    @api restaurantId;

    @track queueItems = [];
    @track restaurantOptions = [];
    selectedRestaurantId;
    chefCount = 1;
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
                    this.loadChefCount();
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
        this.loadChefCount();
        this.refreshQueue();
    }

    loadChefCount() {
        if (!this.restaurantId) return;
        getActiveChefCount({ restaurantId: this.restaurantId })
            .then(result => {
                this.chefCount = result || 1;
            })
            .catch(error => {
                // eslint-disable-next-line no-console
                console.error('Error loading chef count', error);
            });
    }

    refreshQueue() {
        if (!this.restaurantId) return;
        getPendingAndPreparingItems({ restaurantId: this.restaurantId })
            .then(result => {
                this.queueItems = (result || []).map(item => ({
                    ...item,
                    isPending: item.status === 'Pending' || item.status === 'Confirmed',
                    isPreparing: item.status === 'Preparing'
                }));
            })
            .catch(error => {
                // eslint-disable-next-line no-console
                console.error('Error loading chef queue', error);
                this.queueItems = [];
            });
    }

    handleChefCountChange(event) {
        this.chefCount = parseInt(event.target.value, 10) || 1;
    }

    handleSaveChefCount() {
        if (!this.restaurantId) return;
        setActiveChefCount({
            restaurantId: this.restaurantId,
            chefCount: this.chefCount
        })
            .then(() => {
                this.message = 'Chef count saved.';
                this.refreshQueue();
            })
            .catch(error => {
                // eslint-disable-next-line no-console
                console.error('Error saving chef count', error);
                this.message = 'Failed to save chef count.';
            });
    }

    handleAccept(event) {
        const orderItemId = event.currentTarget.dataset.id;
        acceptItems({ orderItemIds: [orderItemId] })
            .then(() => {
                this.message = 'Item accepted for preparation.';
                this.refreshQueue();
            })
            .catch(error => {
                // eslint-disable-next-line no-console
                console.error('Error accepting item', error);
                this.message = 'Failed to accept item.';
            });
    }

    handleReady(event) {
        const orderItemId = event.currentTarget.dataset.id;
        markItemsReady({ orderItemIds: [orderItemId] })
            .then(() => {
                this.message = 'Item marked as ready.';
                this.refreshQueue();
            })
            .catch(error => {
                // eslint-disable-next-line no-console
                console.error('Error marking item ready', error);
                this.message = 'Failed to mark item ready.';
            });
    }

    get hasQueueItems() {
        return this.queueItems && this.queueItems.length > 0;
    }
}

