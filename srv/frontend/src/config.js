export const CONFIG = {
    // Donation Settings
    PAYPAL_EMAIL: import.meta.env.VITE_PAYPAL_EMAIL || 'quinnfazigu@gmail.com',

    // Feature Toggles
    STRIPE_ENABLED: import.meta.env.VITE_STRIPE_ENABLED === 'true',

    // Runtime Configuration
    LOG_LEVEL: window.WORDWANK_CONFIG?.LOG_LEVEL || import.meta.env.VITE_LOG_LEVEL || 'info',
};

export default CONFIG;
