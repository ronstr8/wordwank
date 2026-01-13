export const CONFIG = {
    // Donation Settings
    PAYPAL_EMAIL: import.meta.env.VITE_PAYPAL_EMAIL || 'quinnfazigu@gmail.com',

    // Feature Toggles
    STRIPE_ENABLED: import.meta.env.VITE_STRIPE_ENABLED === 'true',
};

export default CONFIG;
