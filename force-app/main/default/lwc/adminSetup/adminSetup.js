import { LightningElement, track } from 'lwc';
import getRestaurants from '@salesforce/apex/RestaurantContextController.getRestaurants';

export default class AdminSetup extends LightningElement {
    @track restaurantOptions = [];
    selectedRestaurantId;
    message;

    connectedCallback() {
        this.loadRestaurants();
    }

    loadRestaurants() {
        return getRestaurants()
            .then(opts => {
                this.restaurantOptions = opts || [];
                if (!this.selectedRestaurantId && this.restaurantOptions.length > 0) {
                    this.selectedRestaurantId = this.restaurantOptions[0].value;
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
    }

    async handleSuccess(event) {
        // This runs for any lightning-record-edit-form in the tabset.
        // Keep the message short-lived and reset the just-saved form.
        this.message = 'Record saved.';

        const form = event && event.target;
        // lightning-record-edit-form supports `reset()`; do it via event.target when possible.
        if (form && typeof form.reset === 'function') {
            form.reset();
        } else {
            // Fallback: reset all record edit forms in the component.
            this.template.querySelectorAll('lightning-record-edit-form').forEach(f => {
                if (f && typeof f.reset === 'function') f.reset();
            });
        }

        // Keep the dropdown selection on the newly created Restaurant record.
        // onsuccess.detail.id is the created record Id for lightning-record-edit-form.
        const createdId = event && event.detail ? event.detail.id : null;
        if (createdId) {
            this.selectedRestaurantId = createdId;
        }

        // Avoid the “message persists when switching tabs” bug.
        window.setTimeout(() => {
            this.message = null;
        }, 1500);

        // Ensure dropdown options are refreshed immediately after create/save.
        // This avoids the "newly created restaurant appears only after refresh" issue.
        await this.loadRestaurants();
    }
}

