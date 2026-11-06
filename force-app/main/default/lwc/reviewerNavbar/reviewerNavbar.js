import { LightningElement, wire, track } from 'lwc';
import { NavigationMixin } from 'lightning/navigation';
import USER_ID from '@salesforce/user/Id';

import getUserName from '@salesforce/apex/NavbarController.getUserName';
import getLoggedInUserProfile from '@salesforce/apex/ProfileFieldSetController.getLoggedInUserProfile';
/**
 * Temporarily disabled until Apex ReviewerNotificationController.getReviewerNotifications exists.
 * TODO: Re-enable once Apex is implemented.
 */
import getReviewerNotifications
    from '@salesforce/apex/ReviewerNotificationController.getReviewerNotifications';
import InvoiceLogo from '@salesforce/resourceUrl/CSMLogo';

export default class ReviewerNavbar extends NavigationMixin(LightningElement) {

    logoUrl = InvoiceLogo;

    @track showDropdown = false;
    @track showNotifications = false;

    @track notifications = [];

    notificationCount = 0;

    userId = USER_ID;

    userName;
    profileName;

    @wire(getUserName)
    wiredUser({ data }) {

        if (data) {
            this.userName = data;
        }

    }

    @wire(getLoggedInUserProfile)
    wiredProfile({ data }) {

        if (data) {
            this.profileName = data.Profile.Name;
        }

    }

    /**
     * Notifications wire disabled because Apex method is missing.
     * Keeping a safe default to prevent compile-time errors.
     */
    @wire(getReviewerNotifications)
    wiredNotifications({ data,error }) {

        if (data && Array.isArray(data)) {
            this.notifications = data;
            this.notificationCount = data.length;
        } else if (error) {
            this.notifications = [];
            this.notificationCount = 0;
        } else {
            this.notifications = [];
            this.notificationCount = 0;
        }
    }

    get userInitials() {

        if (!this.userName) return '';

        return this.userName
            .split(' ')
            .map(word => word.charAt(0))
            .join('')
            .toUpperCase();

    }

    toggleDropdown() {

        this.showDropdown = !this.showDropdown;

    }

    toggleNotifications() {

        this.showNotifications = !this.showNotifications;

    }

    navigateHome() {

        this.navigate('/reviewer-dashboard');

    }

    navigatePrograms() {

        this.navigate('/grantprogramlist');

    }

    openApplication(event) {

        const applicationId = event.currentTarget.dataset.id;

        this.navigate('/application-details?id=' + applicationId);

    }

    navigateProfile() {

        this.navigate('/profile-details');

    }

    navigate(url) {

        this[NavigationMixin.Navigate]({

            type: 'standard__webPage',

            attributes: {
                url: url
            }

        });

    }

    handleLogout() {
        const pathParts = window.location.pathname.split('/').filter(Boolean);
        const sitePrefix = pathParts.length > 0 ? '/' + pathParts[0] : '';
        const customLoginUrl = window.location.origin + sitePrefix + '/LoginCustom';

        window.location.href = sitePrefix + '/secur/logout.jsp?retUrl=' + encodeURIComponent(customLoginUrl);
    }

}