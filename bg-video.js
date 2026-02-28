/* bg-video.js — FreshTomato Video Background Injector
   - Default: muted sampai user aktifkan
   - Popup "click anywhere to unmute" saat audio pernah ON
   - Controls proximity 80px pojok kanan bawah
*/
(function () {

    var vidStyle = document.createElement('style');
    vidStyle.textContent = '#bg-video{position:fixed;top:0;left:0;width:100vw;height:100vh;z-index:-1;object-fit:cover;object-position:center center;pointer-events:none;}';
    document.head.appendChild(vidStyle);

    var vid = document.createElement('video');
    vid.id='bg-video'; vid.autoplay=vid.loop=vid.muted=vid.playsInline=true;
    vid.setAttribute('playsinline','');
    var src = document.createElement('source');
    src.src='/bgmp4.gif'; src.type='video/mp4';
    vid.appendChild(src);

    // ── AUTOPLAY + AUDIO UNLOCK ────────────────────────────
    // Default: muted=true (sampai user aktifkan)
    // Popup "click anywhere to unmute" muncul jika audio pernah ON
    // dan hilang saat user klik atau setelah 5 detik

    var MUTE_KEY  = 'ft_bg_muted';
    var PANEL_KEY = 'ft_panel_hidden';

    // Pertama kali install → null → default muted
    var isMuted       = localStorage.getItem(MUTE_KEY)  !== 'false';
    var isPanelHidden = localStorage.getItem(PANEL_KEY) === 'true';

    function startVideo(){
        vid.muted = true; // selalu start muted agar autoplay tidak diblokir
        vid.play().catch(function(){
            // Benar-benar diblokir — tunggu interaksi apapun
            ['click','touchstart','keydown'].forEach(function(e){
                document.addEventListener(e, function once(){
                    document.removeEventListener(e, once);
                    vid.play().catch(function(){});
                }, {once:true});
            });
        });
    }

    function showUnmutePopup(){
        // Jangan tampilkan jika user memang pilih mute
        if(localStorage.getItem(MUTE_KEY) === 'true') return;
        // Jangan tampilkan jika sudah ada
        if(document.getElementById('ft-unmute-popup')) return;

        var pStyle = document.createElement('style');
        pStyle.textContent =
            '#ft-unmute-popup{' +
                'position:fixed;bottom:24px;left:50%;transform:translateX(-50%) translateY(0);' +
                'z-index:99999;' +
                'background:rgba(10,10,10,0.82);' +
                'backdrop-filter:blur(10px);-webkit-backdrop-filter:blur(10px);' +
                'color:#fff;font-size:13px;font-family:sans-serif;' +
                'padding:10px 22px;border-radius:24px;' +
                'box-shadow:0 4px 16px rgba(0,0,0,0.5);' +
                'cursor:pointer;white-space:nowrap;' +
                'display:flex;align-items:center;gap:8px;' +
                'animation:ft-popup-in 0.3s ease;' +
            '}' +
            '@keyframes ft-popup-in{' +
                'from{opacity:0;transform:translateX(-50%) translateY(12px);}' +
                'to{opacity:1;transform:translateX(-50%) translateY(0);}' +
            '}' +
            '#ft-unmute-popup.ft-popup-out{' +
                'animation:ft-popup-out 0.3s ease forwards;' +
            '}' +
            '@keyframes ft-popup-out{' +
                'from{opacity:1;transform:translateX(-50%) translateY(0);}' +
                'to{opacity:0;transform:translateX(-50%) translateY(12px);}' +
            '}';
        document.head.appendChild(pStyle);

        var popup = document.createElement('div');
        popup.id = 'ft-unmute-popup';
        popup.innerHTML =
            '<svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="#fff" stroke-width="2" stroke-linecap="round" stroke-linejoin="round">' +
                '<path d="M11 5L6 9H2v6h4l5 4V5z"/>' +
                '<path d="M15.54 8.46a5 5 0 0 1 0 7.07"/>' +
                '<path d="M19.07 4.93a10 10 0 0 1 0 14.14"/>' +
            '</svg>' +
            'Click anywhere to unmute';

        function dismissPopup(unmute){
            if(!popup.parentNode) return;
            popup.classList.add('ft-popup-out');
            setTimeout(function(){
                if(popup.parentNode) popup.parentNode.removeChild(popup);
                if(pStyle.parentNode) pStyle.parentNode.removeChild(pStyle);
            }, 300);
            if(unmute){
                vid.muted = false;
                isMuted = false;
                localStorage.setItem(MUTE_KEY, 'false');
                // Tandai sudah unmute di session ini → popup tidak muncul lagi saat navigasi
                sessionStorage.setItem('ft_session_unmuted', '1');
                // Sync tombol mute jika sudah ada
                var btn = document.getElementById('ft-btn-mute');
                if(btn && typeof applyMute === 'function') applyMute(false);
            }
        }

        // Klik popup sendiri → unmute
        popup.addEventListener('click', function(e){
            e.stopPropagation();
            dismissPopup(true);
        });

        // Klik di mana saja → unmute
        document.addEventListener('click', function onAnyClick(){
            document.removeEventListener('click', onAnyClick);
            dismissPopup(true);
        }, {once:true});

        // Auto hide setelah 5 detik tanpa unmute
        var autoHide = setTimeout(function(){ dismissPopup(false); }, 5000);
        popup.addEventListener('click', function(){ clearTimeout(autoHide); });

        document.body.appendChild(popup);
    }

    function insertVideo(){
        function doInsert(){
            document.body.insertBefore(vid, document.body.firstChild);
            startVideo();
            // Popup hanya muncul jika audio pernah di-unmute (localStorage)
            // DAN belum pernah muncul di session ini (sessionStorage).
            // Mencegah popup muncul terus saat navigasi antar halaman
            // selama audio masih berjalan.
            if(localStorage.getItem(MUTE_KEY) === 'false' &&
               !sessionStorage.getItem('ft_session_unmuted')){
                setTimeout(showUnmutePopup, 600);
            }
        }
        if(document.body) doInsert();
        else document.addEventListener('DOMContentLoaded', doInsert);
    }
    insertVideo();

    // ── CONTROLS (proximity 80px, pojok kanan bawah) ───────
    var TRIGGER_RADIUS = 80;

    var cStyle = document.createElement('style');
    cStyle.textContent = [
        '#ft-controls{position:fixed;bottom:16px;right:16px;z-index:9999;display:flex;gap:8px;opacity:0;transform:translateY(6px);transition:opacity 0.25s ease,transform 0.25s ease;pointer-events:none;}',
        '#ft-controls.visible{opacity:1;transform:translateY(0);pointer-events:auto;}',
        '#ft-controls button{width:34px;height:34px;border-radius:50%;border:none;background:rgba(15,15,15,0.6);backdrop-filter:blur(8px);-webkit-backdrop-filter:blur(8px);color:#fff;cursor:pointer;display:flex;align-items:center;justify-content:center;padding:0;transition:background 0.2s,transform 0.15s;box-shadow:0 2px 8px rgba(0,0,0,0.4);}',
        '#ft-controls button:hover{background:rgba(40,40,40,0.85);transform:scale(1.1);}',
        '#ft-controls button svg{width:16px;height:16px;fill:none;stroke:#fff;stroke-width:2;stroke-linecap:round;stroke-linejoin:round;}',
        'body.ft-panel-hidden #container,body.ft-panel-hidden #navi,body.ft-panel-hidden #footer{opacity:0!important;pointer-events:none!important;transition:opacity 0.3s ease;}',
        'body:not(.ft-panel-hidden) #container,body:not(.ft-panel-hidden) #navi,body:not(.ft-panel-hidden) #footer{opacity:1;transition:opacity 0.3s ease;}'
    ].join('');
    document.head.appendChild(cStyle);

    var icons = {
        muted:  '<svg viewBox="0 0 24 24"><path d="M11 5L6 9H2v6h4l5 4V5z"/><line x1="23" y1="9" x2="17" y2="15"/><line x1="17" y1="9" x2="23" y2="15"/></svg>',
        unmuted:'<svg viewBox="0 0 24 24"><path d="M11 5L6 9H2v6h4l5 4V5z"/><path d="M15.54 8.46a5 5 0 0 1 0 7.07"/><path d="M19.07 4.93a10 10 0 0 1 0 14.14"/></svg>',
        hide:   '<svg viewBox="0 0 24 24"><path d="M17.94 17.94A10.07 10.07 0 0 1 12 20c-7 0-11-8-11-8a18.45 18.45 0 0 1 5.06-5.94"/><path d="M9.9 4.24A9.12 9.12 0 0 1 12 4c7 0 11 8 11 8a18.5 18.5 0 0 1-2.16 3.19"/><line x1="1" y1="1" x2="23" y2="23"/></svg>',
        show:   '<svg viewBox="0 0 24 24"><path d="M1 12s4-8 11-8 11 8 11 8-4 8-11 8-11-8-11-8z"/><circle cx="12" cy="12" r="3"/></svg>'
    };

    var controls = document.createElement('div');
    controls.id = 'ft-controls';

    var btnPanel = document.createElement('button');
    function applyPanel(hidden){
        isPanelHidden = hidden;
        localStorage.setItem(PANEL_KEY, hidden ? 'true' : 'false');
        btnPanel.innerHTML = hidden ? icons.show : icons.hide;
        btnPanel.title     = hidden ? 'Show panels' : 'Hide panels';
        hidden ? document.body.classList.add('ft-panel-hidden')
               : document.body.classList.remove('ft-panel-hidden');
    }
    btnPanel.addEventListener('click', function(){ applyPanel(!isPanelHidden); });

    var btnMute = document.createElement('button');
    btnMute.id = 'ft-btn-mute';
    function applyMute(muted){
        isMuted   = muted;
        vid.muted = muted;
        localStorage.setItem(MUTE_KEY, muted ? 'true' : 'false');
        btnMute.innerHTML = muted ? icons.muted : icons.unmuted;
        btnMute.title     = muted ? 'Unmute' : 'Mute';
        if(muted){
            // Reset session flag saat mute — popup boleh muncul lagi jika user unmute lagi
            sessionStorage.removeItem('ft_session_unmuted');
            var p = document.getElementById('ft-unmute-popup');
            if(p && p.parentNode){
                p.classList.add('ft-popup-out');
                setTimeout(function(){ if(p.parentNode) p.parentNode.removeChild(p); }, 300);
            }
        } else {
            // Tandai sudah unmute di session ini
            sessionStorage.setItem('ft_session_unmuted', '1');
        }
    }
    btnMute.addEventListener('click', function(){ applyMute(!isMuted); });

    controls.appendChild(btnPanel);
    controls.appendChild(btnMute);

    function attachControls(){
        document.body.appendChild(controls);
        applyMute(isMuted);
        applyPanel(isPanelHidden);
        document.addEventListener('mousemove', function(e){
            var rect = controls.getBoundingClientRect();
            var cx = rect.left + rect.width/2, cy = rect.top + rect.height/2;
            var dist = Math.sqrt(Math.pow(e.clientX-cx,2)+Math.pow(e.clientY-cy,2));
            dist < TRIGGER_RADIUS ? controls.classList.add('visible') : controls.classList.remove('visible');
        });
    }
    if(document.body) attachControls();
    else document.addEventListener('DOMContentLoaded', attachControls);

})();
