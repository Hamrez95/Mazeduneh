(() => {
  let googleScriptPromise;

  function loadGoogleIdentityServices() {
    if (window.google?.accounts?.id) return Promise.resolve();
    if (!googleScriptPromise) {
      googleScriptPromise = new Promise((resolve, reject) => {
        const script = document.createElement('script');
        script.src = 'https://accounts.google.com/gsi/client';
        script.async = true;
        script.defer = true;
        script.onload = () => window.google?.accounts?.id
          ? resolve()
          : reject(new Error('Google Identity Services did not initialize.'));
        script.onerror = () => reject(new Error('Google Identity Services could not load.'));
        document.head.appendChild(script);
        window.setTimeout(() => reject(new Error('Google Identity Services timed out.')), 15000);
      });
    }
    return googleScriptPromise.catch((error) => {
      googleScriptPromise = null;
      throw error;
    });
  }

  window.mazedunehGoogle = {
    async render(element, clientId, nonce, onCredential) {
      await loadGoogleIdentityServices();
      element.replaceChildren();
      window.google.accounts.id.initialize({
        client_id: clientId,
        nonce,
        auto_select: false,
        cancel_on_tap_outside: true,
        callback(response) {
          if (typeof response?.credential === 'string') onCredential(response.credential);
        },
      });
      window.google.accounts.id.renderButton(element, {
        type: 'standard',
        theme: 'outline',
        size: 'large',
        text: 'continue_with',
        shape: 'pill',
        logo_alignment: 'left',
        locale: 'fa',
        width: Math.min(360, Math.max(220, Math.floor(element.getBoundingClientRect().width))),
      });
    },
  };
})();
