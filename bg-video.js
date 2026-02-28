/* bg-video.js - FreshTomato Video Background Injector
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

    // -- AUTOPLAY + AUDIO UNLOCK ----------------------------
    // Default: muted=true (sampai user aktifkan)
    // Popup "click anywhere to unmute" muncul jika audio pernah ON
    // dan hilang saat user klik atau setelah 5 detik

    var MUTE_KEY  = 'ft_bg_muted';
    var PANEL_KEY = 'ft_panel_hidden';

    // Pertama kali install -> null -> default muted
    var isMuted       = localStorage.getItem(MUTE_KEY)  !== 'false';
    var isPanelHidden = localStorage.getItem(PANEL_KEY) === 'true';

    function startVideo(){
        vid.muted = true; // selalu start muted agar autoplay tidak diblokir
        vid.play().catch(function(){
            // Benar-benar diblokir - tunggu interaksi apapun
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
                // Set flag hanya di router page - di login page tidak perlu
                var isLoginPage = window.location.pathname.indexOf('login') !== -1;
                if(!isLoginPage) sessionStorage.setItem('ft_session_unmuted', '1');
                // Sync tombol mute jika sudah ada
                var btn = document.getElementById('ft-btn-mute');
                if(btn && typeof applyMute === 'function') applyMute(false);
            }
        }

        // Klik popup sendiri -> unmute
        popup.addEventListener('click', function(e){
            e.stopPropagation();
            dismissPopup(true);
        });

        // Klik di mana saja -> unmute
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
            // Popup muncul jika audio pernah di-unmute (localStorage) DAN:
            // - Di login page: selalu muncul (setiap refresh)
            // - Di router page: hanya muncul sekali per session (tidak muncul saat ganti menu)
            var isLoginPage = window.location.pathname.indexOf('login') !== -1;
            if(localStorage.getItem(MUTE_KEY) === 'false' &&
               (isLoginPage || !sessionStorage.getItem('ft_session_unmuted'))){
                setTimeout(showUnmutePopup, 600);
            }
        }
        if(document.body) doInsert();
        else document.addEventListener('DOMContentLoaded', doInsert);
    }
    insertVideo();

    // -- CONTROLS (proximity 80px, pojok kanan bawah) -------
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
            // Reset flag saat mute agar popup bisa muncul lagi jika unmute lagi
            sessionStorage.removeItem('ft_session_unmuted');
            var p = document.getElementById('ft-unmute-popup');
            if(p && p.parentNode){
                p.classList.add('ft-popup-out');
                setTimeout(function(){ if(p.parentNode) p.parentNode.removeChild(p); }, 300);
            }
        } else {
            // Set flag hanya di router page
            var isLoginPage = window.location.pathname.indexOf('login') !== -1;
            if(!isLoginPage) sessionStorage.setItem('ft_session_unmuted', '1');
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

    // -- ONBOARDING TIP: HIDE PANEL (pertama kali login) -----
    // Login.html set sessionStorage 'ft_show_panel_tip' saat first login
    if(sessionStorage.getItem('ft_show_panel_tip')){
        sessionStorage.removeItem('ft_show_panel_tip');
        setTimeout(function(){
            // Pastikan controls sudah ada di DOM
            var ctrl = document.getElementById('ft-controls');
            var bPanel = document.getElementById('ft-controls') &&
                         document.getElementById('ft-controls').querySelector('button:first-child');
            if(!ctrl) return;

            // Buat tooltip
            var tipStyle = document.createElement('style');
            tipStyle.textContent =
                '#ft-panel-tip{position:fixed;bottom:60px;right:16px;z-index:10000;' +
                'background:rgba(10,10,10,0.90);backdrop-filter:blur(12px);' +
                '-webkit-backdrop-filter:blur(12px);color:#fff;font-size:12px;' +
                'font-family:sans-serif;padding:10px 14px;border-radius:12px;' +
                'box-shadow:0 4px 20px rgba(0,0,0,0.5);max-width:200px;' +
                'line-height:1.6;pointer-events:auto;cursor:pointer;' +
                'animation:ftTipIn 0.3s ease;}' +
                '#ft-panel-tip::after{content:"";position:absolute;bottom:-4px;right:18px;' +
                'width:8px;height:8px;background:rgba(10,10,10,0.90);transform:rotate(45deg);}' +
                '@keyframes ftTipIn{from{opacity:0;transform:translateY(6px);}to{opacity:1;transform:translateY(0);}}' +
                '.ft-tip-pulse{animation:ftPulse 1.2s ease infinite!important;}' +
                '@keyframes ftPulse{0%,100%{box-shadow:0 2px 8px rgba(0,0,0,0.4);}' +
                '50%{box-shadow:0 0 0 4px rgba(255,255,255,0.25),0 2px 8px rgba(0,0,0,0.4);}}';
            document.head.appendChild(tipStyle);

            var tip = document.createElement('div');
            tip.id = 'ft-panel-tip';
            tip.innerHTML = '👁 <b>Tip:</b> Move cursor to the<br>bottom-right corner to show<br>controls. Click <b>hide</b> to toggle<br>the navigation panel.';
            document.body.appendChild(tip);

            // Highlight tombol panel
            ctrl.classList.add('visible');
            var bFirst = ctrl.querySelector('button:first-child');
            if(bFirst) bFirst.classList.add('ft-tip-pulse');

            function removeTip(){
                tip.style.transition = 'opacity 0.3s ease';
                tip.style.opacity = '0';
                setTimeout(function(){
                    tip.parentNode && tip.parentNode.removeChild(tip);
                    tipStyle.parentNode && tipStyle.parentNode.removeChild(tipStyle);
                }, 320);
                ctrl.classList.remove('visible');
                if(bFirst) bFirst.classList.remove('ft-tip-pulse');
            }
            tip.addEventListener('click', removeTip);
            setTimeout(removeTip, 8000);
        }, 1200);
    }


    // -- REBOOT CONFIRM + REBOOT PAGE ----------------------------
    // Strategy: override window.confirm SESEGERA MUNGKIN (sebelum DOM),
    // lalu patch semua onclick yang memanggil reboot via MutationObserver.
    // Karena FreshTomato: onclick="if(confirm('Reboot?'))reboot()"
    // kita intercept confirm() → return false (blok native) → tampilkan
    // dialog kita → jika user OK, panggil doReboot() langsung.

    var _ftRebootPending = false; // flag untuk trigger doReboot dari dialog

    // Override window.confirm SEKARANG (sync, sebelum apapun)
    var _origConfirm = window.confirm;
    window.confirm = function(msg) {
        var m = (msg || '').toString().toLowerCase();
        if(m.indexOf('reboot') === -1 && m.indexOf('restart') === -1) {
            return _origConfirm ? _origConfirm.call(window, msg) : true;
        }
        // Tampilkan dialog kita async
        // Return false agar caller (if confirm(...)) tidak lanjut
        setTimeout(function(){ showRebootDialog(); }, 0);
        return false;
    };

    // Ambil accent color dari --accent CSS var ATAU dari video frame
    function getAccentNow() {
        var root = document.documentElement;
        var acc = (getComputedStyle(root).getPropertyValue('--accent') || '').trim();
        if(acc) return acc;
        // Fallback: sample dari video bg yang sudah ada di halaman
        var vid = document.getElementById('bg-video') ||
                  document.querySelector('video');
        if(vid && vid.readyState >= 2) {
            try {
                var cv = document.createElement('canvas');
                cv.width = 8; cv.height = 8;
                var cx = cv.getContext('2d');
                cx.drawImage(vid, 0, 0, 8, 8);
                var px = cx.getImageData(0,0,8,8).data,
                    r=0,g=0,b=0,n=0;
                for(var i=0;i<px.length;i+=4){
                    var br=(px[i]+px[i+1]+px[i+2])/3;
                    if(br<20||br>235) continue;
                    r+=px[i];g+=px[i+1];b+=px[i+2];n++;
                }
                if(n>0) return 'rgb('+~~(r/n)+','+~~(g/n)+','+~~(b/n)+')';
            } catch(e){}
        }
        return '#e8a86e';
    }

    // Dialog reboot custom (fully async, zero busy-wait)
    function showRebootDialog() {
        if(document.getElementById('ft-dlg')) return;

        var acc = getAccentNow();

        var s = document.createElement('style');
        s.id = 'ft-dlg-style';
        s.textContent =
            '#ft-dlg-bd{position:fixed;inset:0;z-index:99998;' +
                'background:rgba(0,0,0,0.55);backdrop-filter:blur(4px);' +
                '-webkit-backdrop-filter:blur(4px);' +
                'animation:ftBdIn .2s ease;}' +
            '@keyframes ftBdIn{from{opacity:0}to{opacity:1}}' +
            '#ft-dlg{position:fixed;top:50%;left:50%;' +
                'transform:translate(-50%,-50%);' +
                'z-index:99999;background:rgba(8,6,10,.80);' +
                'border:1px solid rgba(255,255,255,.10);border-radius:18px;' +
                'padding:32px 36px 24px;min-width:280px;max-width:340px;' +
                'backdrop-filter:blur(28px);-webkit-backdrop-filter:blur(28px);' +
                'box-shadow:0 16px 56px rgba(0,0,0,.7);text-align:center;' +
                'font-family:Outfit,sans-serif;' +
                'opacity:0;transform:translate(-50%,-46%) scale(.94);' +
                'animation:ftDlgIn .25s cubic-bezier(.22,1,.36,1) forwards;}' +
            '@keyframes ftDlgIn{' +
                'to{opacity:1;transform:translate(-50%,-50%) scale(1)}}' +
            '#ft-dlg.out{' +
                'animation:ftDlgOut .18s ease forwards!important;}' +
            '@keyframes ftDlgOut{' +
                'to{opacity:0;transform:translate(-50%,-46%) scale(.95)}}' +
            '#ft-dlg svg{display:block;margin:0 auto 16px;' +
                'width:40px;height:40px;}' +
            '#ft-dlg h3{font-size:17px;font-weight:700;color:#f0ece8;' +
                'margin:0 0 6px;}' +
            '#ft-dlg p{font-size:12px;color:rgba(240,236,232,.45);' +
                'margin:0 0 24px;line-height:1.5;}' +
            '#ft-dlg-row{display:flex;gap:10px;}' +
            '#ft-dlg-no{flex:1;padding:11px;' +
                'border:1px solid rgba(255,255,255,.12);border-radius:10px;' +
                'background:rgba(255,255,255,.06);' +
                'color:rgba(240,236,232,.7);font-size:13px;' +
                'font-family:Outfit,sans-serif;cursor:pointer;' +
                'transition:opacity .15s,transform .15s;}' +
            '#ft-dlg-no:hover{opacity:.75;transform:translateY(-1px)}' +
            '#ft-dlg-yes{flex:1;padding:11px;border:none;border-radius:10px;' +
                'font-size:13px;font-weight:700;font-family:Outfit,sans-serif;' +
                'cursor:pointer;color:#0e0810;' +
                'transition:opacity .15s,transform .15s;}' +
            '#ft-dlg-yes:hover{opacity:.85;transform:translateY(-1px)}';

        var bd = document.createElement('div'); bd.id = 'ft-dlg-bd';
        var dlg = document.createElement('div'); dlg.id = 'ft-dlg';
        dlg.innerHTML =
            '<svg viewBox="0 0 24 24" fill="none" id="ft-dlg-ico"' +
            ' stroke-width="1.5" stroke-linecap="round"' +
            ' stroke-linejoin="round">' +
            '<path d="M21 2v6h-6"/>' +
            '<path d="M3 12a9 9 0 0 1 15-6.7L21 8"/>' +
            '<path d="M3 22v-6h6"/>' +
            '<path d="M21 12a9 9 0 0 1-15 6.7L3 16"/>' +
            '</svg>' +
            '<h3>Reboot Router?</h3>' +
            '<p>The router will restart.<br>' +
            'You will be disconnected briefly.</p>' +
            '<div id="ft-dlg-row">' +
            '<button id="ft-dlg-no">Cancel</button>' +
            '<button id="ft-dlg-yes">Reboot</button>' +
            '</div>';

        document.head.appendChild(s);
        document.body.appendChild(bd);
        document.body.appendChild(dlg);

        // Set initial accent color
        function applyAccent(c) {
            var yes = document.getElementById('ft-dlg-yes');
            var ico = document.getElementById('ft-dlg-ico');
            if(yes) yes.style.background = c;
            if(ico) ico.setAttribute('stroke', c);
        }
        applyAccent(acc);

        // Watch --accent changes (live sync dengan adaptive)
        var mo = new MutationObserver(function() {
            var c = (getComputedStyle(document.documentElement)
                        .getPropertyValue('--accent') || '').trim();
            if(c) applyAccent(c);
        });
        mo.observe(document.documentElement, {
            attributes: true, attributeFilter: ['style']
        });

        // Juga poll setiap 200ms untuk catch perubahan awal
        var syncTimer = setInterval(function() {
            var c = (getComputedStyle(document.documentElement)
                        .getPropertyValue('--accent') || '').trim();
            if(c && c !== acc) { acc = c; applyAccent(c); }
        }, 200);

        function close() {
            mo.disconnect();
            clearInterval(syncTimer);
            dlg.classList.add('out');
            bd.style.transition = 'opacity .18s ease';
            bd.style.opacity = '0';
            setTimeout(function() {
                [dlg, bd, s].forEach(function(el) {
                    el.parentNode && el.parentNode.removeChild(el);
                });
            }, 200);
        }

        document.getElementById('ft-dlg-yes').addEventListener('click',
            function() { close(); setTimeout(doReboot, 220); });
        document.getElementById('ft-dlg-no').addEventListener('click', close);
        bd.addEventListener('click', close);
    }

    // Jalankan reboot via form POST langsung (bypass confirm)
    function doReboot() {
        var form = document.createElement('form');
        form.method = 'post'; form.action = '/tomato.cgi';
        [['_nextpage','admin-reboot.asp'],
         ['_action','reboot'],
         ['submit_button','status-overview']
        ].forEach(function(kv) {
            var inp = document.createElement('input');
            inp.type='hidden'; inp.name=kv[0]; inp.value=kv[1];
            form.appendChild(inp);
        });
        document.body.appendChild(form);
        form.submit();
    }

    // Patch semua existing & future onclick="...reboot..." elements
    function patchRebootLinks(root) {
        (root || document).querySelectorAll(
            '[onclick*="reboot"],[href*="reboot"]'
        ).forEach(function(el) {
            if(el.dataset.ftPatched) return;
            el.dataset.ftPatched = '1';
            // Ganti onclick
            var oc = el.getAttribute('onclick') || '';
            if(oc.indexOf('reboot') !== -1) {
                el.setAttribute('onclick', 'return false;');
                el.addEventListener('click', function(e) {
                    e.preventDefault(); e.stopPropagation();
                    showRebootDialog();
                });
            }
            // Ganti href="javascript:reboot()"
            var href = el.getAttribute('href') || '';
            if(href.indexOf('reboot') !== -1) {
                el.setAttribute('href', 'javascript:void(0)');
                el.addEventListener('click', function(e) {
                    e.preventDefault(); e.stopPropagation();
                    showRebootDialog();
                });
            }
        });
    }

    // Patch saat DOM ready dan watch mutasi baru
    function installPatcher() {
        patchRebootLinks(document);
        var pmo = new MutationObserver(function(muts) {
            muts.forEach(function(m) {
                m.addedNodes.forEach(function(n) {
                    if(n.nodeType === 1) patchRebootLinks(n);
                });
            });
        });
        pmo.observe(document.body || document.documentElement,
            {childList: true, subtree: true});
    }
    if(document.body) installPatcher();
    else document.addEventListener('DOMContentLoaded', installPatcher);

    // --- REBOOT WAITING PAGE ---
    function initRebootUI() {
        var allElems = document.querySelectorAll('*');
        var found = false;
        for(var i = 0; i < allElems.length; i++) {
            if(allElems[i].children.length === 0 &&
               allElems[i].textContent.indexOf(
                   'Please wait while the router reboots') !== -1) {
                found = true; break;
            }
        }
        if(!found) return;

        document.body.style.cssText =
            'margin:0;padding:0;overflow:hidden;background:#080610;';
        for(var c = 0; c < document.body.children.length; c++) {
            document.body.children[c].style.display = 'none';
        }

        var vidStyle = document.createElement('style');
        vidStyle.textContent =
            '#ft-rb-video{position:fixed;inset:0;width:100vw;height:100vh;' +
            'object-fit:cover;z-index:0;pointer-events:none;}' +
            '#ft-rb-overlay{position:fixed;inset:0;z-index:1;' +
            'background:rgba(8,6,10,0.50);transition:background 1.2s ease;}' +
            '#ft-rb-wrap{position:fixed;inset:0;z-index:2;display:flex;' +
            'align-items:center;justify-content:center;}' +
            '#ft-rb-card{background:rgba(8,6,10,0.52);' +
            'border:1px solid rgba(255,255,255,0.10);border-radius:20px;' +
            'padding:44px 52px;backdrop-filter:blur(24px);' +
            '-webkit-backdrop-filter:blur(24px);' +
            'box-shadow:0 8px 48px rgba(0,0,0,0.6);text-align:center;' +
            'min-width:300px;' +
            'transition:background 1.2s ease,border-color 1.2s ease;' +
            'animation:ftCardIn 0.5s cubic-bezier(0.22,1,0.36,1);}' +
            '@keyframes ftCardIn{' +
            'from{opacity:0;transform:translateY(20px) scale(0.97);}' +
            'to{opacity:1;transform:translateY(0) scale(1);}}' +
            '#ft-rb-icon{width:48px;height:48px;margin:0 auto 20px;' +
            'display:block;animation:ftRbSpin 1.8s linear infinite;}' +
            '@keyframes ftRbSpin{from{transform:rotate(0deg);}' +
            'to{transform:rotate(360deg);}}' +
            '#ft-rb-title{font-size:18px;font-weight:700;color:#f0ece8;' +
            'letter-spacing:-.01em;margin-bottom:6px;' +
            'font-family:Outfit,sans-serif;}' +
            '#ft-rb-sub{font-size:11px;color:rgba(240,236,232,0.40);' +
            'letter-spacing:.14em;text-transform:uppercase;' +
            'font-family:"Space Mono",monospace;margin-bottom:28px;}' +
            '#ft-rb-bar-wrap{width:100%;height:3px;' +
            'background:rgba(255,255,255,0.08);border-radius:4px;' +
            'overflow:hidden;margin-bottom:14px;}' +
            '#ft-rb-bar{height:100%;width:0%;border-radius:4px;' +
            'background:linear-gradient(90deg,' +
            'var(--accent,#e8a86e),var(--accent2,#7ec8e3));' +
            'transition:width 1s linear;' +
            'box-shadow:0 0 10px rgba(232,168,110,.4);}' +
            '#ft-rb-count{font-size:12px;color:rgba(240,236,232,.45);' +
            'font-family:Outfit,sans-serif;letter-spacing:.04em;}' +
            '#ft-rb-count b{color:var(--accent,#e8a86e);font-size:14px;}';
        document.head.appendChild(vidStyle);

        var vid = document.createElement('video');
        vid.id = 'ft-rb-video'; vid.autoplay = true;
        vid.loop = true; vid.muted = true; vid.playsInline = true;
        var src = document.createElement('source');
        src.src = '/bgmp4.gif'; src.type = 'video/mp4';
        vid.appendChild(src);

        var overlay = document.createElement('div');
        overlay.id = 'ft-rb-overlay';
        var wrap = document.createElement('div');
        wrap.id = 'ft-rb-wrap';

        var total = 120;
        var countEl = document.querySelector(
            '[id*="count"],[name*="count"],input[type=text]');
        if(countEl) {
            var v = parseInt(countEl.value || countEl.textContent);
            if(v > 0 && v < 300) total = v;
        }

        var card = document.createElement('div'); card.id = 'ft-rb-card';
        card.innerHTML =
            '<svg id="ft-rb-icon" viewBox="0 0 24 24" fill="none"' +
            ' stroke="var(--accent,#e8a86e)" stroke-width="1.5"' +
            ' stroke-linecap="round" stroke-linejoin="round">' +
            '<path d="M21 2v6h-6"/>' +
            '<path d="M3 12a9 9 0 0 1 15-6.7L21 8"/>' +
            '<path d="M3 22v-6h6"/>' +
            '<path d="M21 12a9 9 0 0 1-15 6.7L3 16"/>' +
            '</svg>' +
            '<div id="ft-rb-title">Rebooting Router</div>' +
            '<div id="ft-rb-sub">Please Wait</div>' +
            '<div id="ft-rb-bar-wrap"><div id="ft-rb-bar"></div></div>' +
            '<div id="ft-rb-count">Redirecting in ' +
            '<b id="ft-rb-num">' + total + '</b>s</div>';

        wrap.appendChild(card);
        document.body.insertBefore(vid, document.body.firstChild);
        document.body.insertBefore(overlay, vid.nextSibling);
        document.body.appendChild(wrap);
        [vid, overlay, wrap].forEach(function(el){ el.style.display=''; });

        // Adaptive color
        var cv = document.createElement('canvas');
        cv.width = 64; cv.height = 36;
        var ctx = cv.getContext('2d');
        var lastHue = -1;

        function H(h,s,l){h/=360;s/=100;l/=100;var q=l<.5?l*(1+s):l+s-l*s,p=2*l-q;function f(t){t<0&&(t+=1);t>1&&(t-=1);return t<1/6?p+(q-p)*6*t:t<.5?q:t<2/3?p+(q-p)*(2/3-t)*6:p;}return[~~(f(h+1/3)*255),~~(f(h)*255),~~(f(h-1/3)*255)];}
        function toHsl(r,g,b){r/=255;g/=255;b/=255;var mx=Math.max(r,g,b),mn=Math.min(r,g,b),h,s,l=(mx+mn)/2;if(mx===mn){h=s=0;}else{var d=mx-mn;s=l>.5?d/(2-mx-mn):d/(mx+mn);h=mx===r?((g-b)/d+(g<b?6:0))/6:mx===g?((b-r)/d+2)/6:((r-g)/d+4)/6;}return[h*360,s*100,l*100];}

        function adaptColor() {
            if(vid.readyState < 2){ setTimeout(adaptColor, 500); return; }
            try {
                ctx.drawImage(vid, 0, 0, 64, 36);
                var px=ctx.getImageData(0,0,64,36).data, r=0,g=0,b=0,n=0;
                for(var i=0;i<px.length;i+=4){
                    var br=(px[i]+px[i+1]+px[i+2])/3;
                    if(br<15||br>240) continue;
                    r+=px[i];g+=px[i+1];b+=px[i+2];n++;
                }
                if(!n) return;
                r=~~(r/n); g=~~(g/n); b=~~(b/n);
                var hsl=toHsl(r,g,b),hue=hsl[0],sat=hsl[1],lum=hsl[2];
                var d=Math.abs(hue-lastHue); if(d>180)d=360-d;
                if(lastHue<0||d>=5){
                    lastHue=hue;
                    var dark=lum<50, s2=Math.max(sat,50);
                    var acc =H(hue,Math.max(s2,65),dark?68:42);
                    var ac2 =H((hue+40)%360,Math.max(s2,55),dark?72:40);
                    var pan =H(hue,Math.min(s2,40),
                               dark?Math.min(lum+8,20):Math.max(lum-8,80));
                    var ov=Math.max(pan[0]-30,0)+','+
                           Math.max(pan[1]-30,0)+','+
                           Math.max(pan[2]-30,0);
                    overlay.style.background='rgba('+ov+',0.50)';
                    card.style.background=
                        'rgba('+pan[0]+','+pan[1]+','+pan[2]+',0.48)';
                    card.style.borderColor=
                        'rgba('+acc[0]+','+acc[1]+','+acc[2]+',0.20)';
                    document.documentElement.style.setProperty('--accent',
                        'rgb('+acc[0]+','+acc[1]+','+acc[2]+')');
                    document.documentElement.style.setProperty('--accent2',
                        'rgb('+ac2[0]+','+ac2[1]+','+ac2[2]+')');
                }
            } catch(e){}
            setTimeout(adaptColor, 500);
        }
        vid.addEventListener('canplay', adaptColor, {once:true});
        vid.play().catch(function(){});

        // Countdown
        var elapsed=0, bar=document.getElementById('ft-rb-bar'),
            num=document.getElementById('ft-rb-num');
        var timer = setInterval(function(){
            elapsed++;
            if(bar) bar.style.width=Math.min((elapsed/total)*100,100)+'%';
            if(num) num.textContent=Math.max(total-elapsed,0);
            if(elapsed>=total) clearInterval(timer);
        }, 1000);
    }

    if(document.body) initRebootUI();
    else document.addEventListener('DOMContentLoaded', initRebootUI);



})();
