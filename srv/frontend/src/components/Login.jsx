import { useState, useEffect } from 'react';
import { useTranslation } from 'react-i18next';
import './Login.css';

const Login = ({ onLoginSuccess }) => {
    const { t } = useTranslation();
    const [loading, setLoading] = useState(false);
    const [error, setError] = useState(null);
    const [lastMethod, setLastMethod] = useState(localStorage.getItem('ww_last_login'));

    const handleGoogleLogin = () => {
        window.location.href = '/auth/google';
    };

    const handleDiscordLogin = () => {
        window.location.href = '/auth/discord';
    };

    const handlePasskeyLogin = async () => {
        setLoading(true);
        setError(null);
        try {
            const resp = await fetch('/auth/passkey/challenge');
            const options = await resp.json();

            // Convert challenge and user.id from base64 to ArrayBuffer
            options.challenge = Uint8Array.from(atob(options.challenge), c => c.charCodeAt(0)).buffer;
            if (options.user && options.user.id) {
                options.user.id = Uint8Array.from(options.user.id, c => c.charCodeAt(0)).buffer;
            }

            const credential = await navigator.credentials.get({
                publicKey: {
                    challenge: options.challenge,
                    rpId: options.rp.id,
                    userVerification: 'preferred',
                }
            });

            // Send back to server
            const verifyResp = await fetch('/auth/passkey/verify', {
                method: 'POST',
                headers: { 'Content-Type': 'application/json' },
                body: JSON.stringify({
                    id: credential.id,
                    type: 'assertion',
                    rawId: btoa(String.fromCharCode(...new Uint8Array(credential.rawId))),
                    response: {
                        authenticatorData: btoa(String.fromCharCode(...new Uint8Array(credential.response.authenticatorData))),
                        clientDataJSON: btoa(String.fromCharCode(...new Uint8Array(credential.response.clientDataJSON))),
                        signature: btoa(String.fromCharCode(...new Uint8Array(credential.response.signature))),
                        userHandle: credential.response.userHandle ? btoa(String.fromCharCode(...new Uint8Array(credential.response.userHandle))) : null,
                    }
                })
            });

            if (verifyResp.ok) {
                localStorage.setItem('ww_last_login', 'passkey');
                onLoginSuccess();
            } else {
                setError(t('auth.passkey_failed'));
            }
        } catch (err) {
            console.error(err);
            setError(err.message);
        } finally {
            setLoading(false);
        }
    };

    const handleAnonymousLogin = async () => {
        setLoading(true);
        setError(null);
        try {
            const resp = await fetch('/auth/anonymous', { method: 'POST' });
            if (resp.ok) {
                localStorage.setItem('ww_last_login', 'anonymous');
                onLoginSuccess();
            } else {
                setError(t('auth.anonymous_failed', 'Anonymous login failed.'));
            }
        } catch (err) {
            console.error(err);
            setError(err.message);
        } finally {
            setLoading(false);
        }
    };

    return (
        <div className="login-overlay">
            <div className="login-card">
                <h1>wordw<span className="splat">💥</span>nk</h1>
                <p className="login-subtitle">{t('auth.welcome_back')}</p>

                {lastMethod && (
                    <div className="last-login-hint">
                        {t('auth.last_used')}: <strong>{lastMethod}</strong>
                    </div>
                )}

                <div className="auth-buttons">
                    <p className="anonymous-disclaimer">{t('auth.anonymous_disclaimer')}</p>

                    <button className="auth-btn google" onClick={handleGoogleLogin} disabled={loading}>
                        <img src="/icons/google.svg" alt="" />
                        {t('auth.continue_with_google')}
                    </button>

                    <button className="auth-btn discord" onClick={handleDiscordLogin} disabled={loading}>
                        <span className="icon">🎮</span>
                        {t('auth.continue_with_discord', 'Continue with Discord')}
                    </button>

                    <button className="auth-btn passkey" onClick={handlePasskeyLogin} disabled={loading}>
                        <span className="icon">🔑</span>
                        {t('auth.sign_in_with_passkey')}
                    </button>

                    <div className="auth-divider">
                        <span>{t('app.donate_or', 'OR')}</span>
                    </div>

                    <button className="auth-btn anonymous" onClick={handleAnonymousLogin} disabled={loading}>
                        <span className="icon">👤</span>
                        {t('auth.play_anonymously')}
                    </button>
                </div>

                {error && <div className="auth-error">{error}</div>}

                <div className="auth-footer">
                    <p>{t('auth.privacy_hint')}</p>
                </div>
            </div>
        </div>
    );
};

export default Login;
