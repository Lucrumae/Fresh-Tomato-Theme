/* adaptiverealtime.js - FreshTomato Realtime Adaptive Theme
   - Default: muted sampai user aktifkan
   - Popup "click anywhere to unmute" saat audio pernah ON
   - requestAnimationFrame + throttle 100ms
   - sessionStorage cache anti-flicker
   - Controls proximity 80px pojok kanan bawah
*/
(function () {

    var vidStyle = document.createElement('style');
    vidStyle.textContent =
        '#bg-video{position:fixed;top:0;left:0;width:100vw;height:100vh;z-index:-1;object-fit:cover;object-position:center center;pointer-events:none;}' +
        '*{transition:background-color 0.8s ease,border-color 0.8s ease,color 0.8s ease!important;}' +
        'a,input,select,textarea,button{transition-duration:0.15s!important;}';
    document.head.appendChild(vidStyle);

    var vid = document.createElement('video');
    vid.id='bg-video'; vid.autoplay=vid.loop=vid.muted=vid.playsInline=true;
    vid.setAttribute('playsinline',''); vid.crossOrigin='anonymous';
    var src = document.createElement('source');
    src.src='/bgmp4.gif'; src.type='video/mp4';
    vid.appendChild(src);

    function rgbToHsl(r,g,b){r/=255;g/=255;b/=255;var max=Math.max(r,g,b),min=Math.min(r,g,b),h,s,l=(max+min)/2;if(max===min){h=s=0;}else{var d=max-min;s=l>0.5?d/(2-max-min):d/(max+min);switch(max){case r:h=((g-b)/d+(g<b?6:0))/6;break;case g:h=((b-r)/d+2)/6;break;case b:h=((r-g)/d+4)/6;break;}}return[h*360,s*100,l*100];}
    function hslToRgb(h,s,l){h/=360;s/=100;l/=100;var r,g,b;if(s===0){r=g=b=l;}else{var q=l<0.5?l*(1+s):l+s-l*s,p=2*l-q;function hue2rgb(t){if(t<0)t+=1;if(t>1)t-=1;if(t<1/6)return p+(q-p)*6*t;if(t<0.5)return q;if(t<2/3)return p+(q-p)*(2/3-t)*6;return p;}r=hue2rgb(h+1/3);g=hue2rgb(h);b=hue2rgb(h-1/3);}return[Math.round(r*255),Math.round(g*255),Math.round(b*255)];}
    function relLum(r,g,b){function lin(c){c/=255;return c<=0.03928?c/12.92:Math.pow((c+0.055)/1.055,2.4);}return 0.2126*lin(r)+0.7152*lin(g)+0.0722*lin(b);}
    function cr(l1,l2){var a=Math.max(l1,l2),b=Math.min(l1,l2);return(a+0.05)/(b+0.05);}
    function bestText(r,g,b){return cr(1.0,relLum(r,g,b))>=cr(0.0,relLum(r,g,b))?[255,255,255]:[0,0,0];}
    function ensureContrast(fr,fg,fb,br,bg,bb,min){min=min||4.5;var bl=relLum(br,bg,bb);if(cr(relLum(fr,fg,fb),bl)>=min)return[fr,fg,fb];var hsl=rgbToHsl(fr,fg,fb),h=hsl[0],s=hsl[1],l=hsl[2],rgb;for(var li=l;li<=98;li+=2){rgb=hslToRgb(h,s,li);if(cr(relLum(rgb[0],rgb[1],rgb[2]),bl)>=min)return rgb;}for(var ld=l;ld>=2;ld-=2){rgb=hslToRgb(h,s,ld);if(cr(relLum(rgb[0],rgb[1],rgb[2]),bl)>=min)return rgb;}return bestText(br,bg,bb);}
    function rgb(c){return"rgb("+c[0]+","+c[1]+","+c[2]+")";}
    function rgba(c,a){return"rgba("+c[0]+","+c[1]+","+c[2]+","+a+")";}
    function set(k,v){document.documentElement.style.setProperty(k,v);}
    function applyPalette(r,g,b){var hsl=rgbToHsl(r,g,b),hue=hsl[0],sat=hsl[1],lum=hsl[2];var isDark=lum<50;var sat2=Math.max(sat,50);var pL=isDark?Math.min(lum+10,25):Math.max(lum-10,75);var hL=isDark?Math.min(lum+5,18):Math.max(lum-5,82);var panelRgb=hslToRgb(hue,Math.min(sat2,45),pL);var headerRgb=hslToRgb(hue,Math.min(sat2,50),hL);var accentRgb=hslToRgb(hue,Math.max(sat2,60),isDark?70:40);var accent2=hslToRgb((hue+30)%360,Math.max(sat2,55),isDark?75:35);var accentHl=hslToRgb(hue,Math.max(sat2,50),isDark?88:25);var bgFb=hslToRgb(hue,Math.min(sat,35),isDark?8:92);var eBgR=Math.round(panelRgb[0]*0.28+bgFb[0]*0.72);var eBgG=Math.round(panelRgb[1]*0.28+bgFb[1]*0.72);var eBgB=Math.round(panelRgb[2]*0.28+bgFb[2]*0.72);var tP=ensureContrast(isDark?250:15,isDark?245:10,isDark?235:8,eBgR,eBgG,eBgB,5.0);var tS=ensureContrast(accentRgb[0],accentRgb[1],accentRgb[2],eBgR,eBgG,eBgB,4.5);var tV=ensureContrast(accent2[0],accent2[1],accent2[2],eBgR,eBgG,eBgB,4.5);var aSec=ensureContrast(accent2[0],accent2[1],accent2[2],eBgR,eBgG,eBgB,4.5);var aHl=ensureContrast(accentHl[0],accentHl[1],accentHl[2],eBgR,eBgG,eBgB,3.5);var logB=isDark?[255,250,235]:[10,6,3];var logC=bestText(logB[0],logB[1],logB[2]);var inpB=hslToRgb(hue,Math.min(sat*0.25,12),isDark?94:10);var inpC=bestText(inpB[0],inpB[1],inpB[2]);var prog=hslToRgb((hue+15)%360,Math.max(sat2,65),isDark?72:38);var svgT=ensureContrast(accentRgb[0],accentRgb[1],accentRgb[2],eBgR,eBgG,eBgB,4.5);set("--bg-fallback",rgb(bgFb));set("--panel-bg",rgba(panelRgb,0.28));set("--header-bg",rgba(headerRgb,0.60));set("--log-bg",rgb(logB));set("--bwm-bg",rgba(panelRgb,0.07));set("--tab-bg",rgba(headerRgb,0.35));set("--text-primary",rgb(tP));set("--text-secondary",rgb(tS));set("--text-value",rgb(tV));set("--log-color",rgb(logC));set("--tab-text",rgb(tP));set("--accent-primary",rgba(accentRgb,0.22));set("--accent-secondary",rgb(aSec));set("--accent-highlight",rgb(aHl));set("--link-color",rgb(tS));set("--link-hover-color",rgb(aHl));set("--btn-bg",rgba(accentRgb,0.22));set("--btn-color",rgb(tP));set("--progress-color",rgb(prog));set("--input-bg",rgba(inpB,0.85));set("--input-color",rgb(inpC));set("--input-border",rgba(accentRgb,0.25));set("--svg-text-color",rgb(svgT));set("--svg-grid-stroke",rgba(accentRgb,0.15));set("--bwm-border",rgba(accentRgb,0.18));set("--svg-bg",rgba(headerRgb,0.30));set("--tab-active-bg",rgba(accentRgb,0.20));set("--row-even",rgba(accentRgb,0.06));set("--row-odd",rgba(accentRgb,0.02));set("--scrollbar-track",rgba(accentRgb,0.05));set("--scrollbar-thumb",rgba(accentRgb,0.40));set("--scrollbar-hover",rgba(accentRgb,0.65));document.documentElement.style.backgroundColor=rgb(bgFb);}

    var CACHE_KEY_RT="ft_palette_rt";
    try{var cached=sessionStorage.getItem(CACHE_KEY_RT);if(cached){var c=cached.split(",");applyPalette(parseInt(c[0]),parseInt(c[1]),parseInt(c[2]));}}catch(e){}
    var canvas=document.createElement("canvas");canvas.width=64;canvas.height=36;
    var ctx=canvas.getContext("2d");
    var lastHue=-1,lastSample=0,THROTTLE=100,HUE_THRESHOLD=5;
    function sample(){if(vid.readyState<2)return;try{ctx.drawImage(vid,0,0,64,36);var px=ctx.getImageData(0,0,64,36).data,r=0,g=0,b=0,n=0;for(var i=0;i<px.length;i+=4){var pr=px[i],pg=px[i+1],pb=px[i+2],br=(pr+pg+pb)/3;if(br<15||br>240)continue;r+=pr;g+=pg;b+=pb;n++;}if(n===0)return;r=Math.round(r/n);g=Math.round(g/n);b=Math.round(b/n);var hsl=rgbToHsl(r,g,b),hue=hsl[0];if(lastHue>=0){var diff=Math.abs(hue-lastHue);if(diff>180)diff=360-diff;if(diff<HUE_THRESHOLD)return;}lastHue=hue;applyPalette(r,g,b);try{sessionStorage.setItem(CACHE_KEY_RT,r+","+g+","+b);}catch(e){}}catch(e){}}
    function loop(ts){if(ts-lastSample>=THROTTLE){lastSample=ts;sample();}requestAnimationFrame(loop);}
    function startLoop(){requestAnimationFrame(loop);}
    if(vid.readyState>=2){startLoop();}
    else{vid.addEventListener("loadeddata",startLoop,{once:true});vid.addEventListener("canplay",startLoop,{once:true});vid.addEventListener("playing",startLoop,{once:true});}

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
        // Throttle mousemove via requestAnimationFrame — cegah UI freeze
        var _rafPending = false;
        document.addEventListener('mousemove', function(e){
            if(_rafPending) return;
            _rafPending = true;
            var _mx = e.clientX, _my = e.clientY;
            requestAnimationFrame(function(){
                _rafPending = false;
                var rect = controls.getBoundingClientRect();
                var cx = rect.left + rect.width/2, cy = rect.top + rect.height/2;
                var dist = Math.sqrt(Math.pow(_mx-cx,2)+Math.pow(_my-cy,2));
                dist < TRIGGER_RADIUS ? controls.classList.add('visible') : controls.classList.remove('visible');
            });
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
    // Dialog konfirmasi reboot. Jika user klik OK → redirect ke
    // /reboot-wait.html yang handle reboot + video background sendiri.

    var _origConfirm = window.confirm;
    // Simpan confirmed msgs di sessionStorage agar survive page navigation
    function _ftGetConfirmed(){
        try{
            return JSON.parse(sessionStorage.getItem('_ftConfirmed')||'{}');
        }catch(e){ return {}; }
    }
    function _ftSetConfirmed(key, ttl){
        try{
            var d = _ftGetConfirmed();
            d[key] = Date.now() + ttl;
            sessionStorage.setItem('_ftConfirmed', JSON.stringify(d));
        }catch(e){}
    }
    function _ftIsConfirmed(key){
        try{
            var d = _ftGetConfirmed();
            return d[key] && Date.now() < d[key];
        }catch(e){ return false; }
    }

    window.confirm = function(msg){
        var m = (msg||'').toString().toLowerCase();
        if(m.indexOf('reboot')!==-1 || m.indexOf('restart')!==-1){
            setTimeout(showRebootDialog, 0);
            return false;
        }
        if(m.indexOf('halt')!==-1){
            setTimeout(function(){ showGenericDialog(msg,'halt'); }, 0);
            return false;
        }
        // Jika pesan ini sudah dikonfirmasi user, bypass sampai TTL habis
        var key = msg||'';
        if(_ftIsConfirmed(key)) return true;
        var caller = null;
        try { caller = document.activeElement; } catch(e){}
        setTimeout(function(){ showGenericDialog(msg,'generic',caller); }, 0);
        return false;
    };

    function getAccentNow(){
        var a = (getComputedStyle(document.documentElement)
                    .getPropertyValue('--accent')||'').trim();
        if(a) return a;
        var vid = document.querySelector('video');
        if(vid && vid.readyState>=2){
            try{
                var cv=document.createElement('canvas');cv.width=8;cv.height=8;
                var cx=cv.getContext('2d');cx.drawImage(vid,0,0,8,8);
                var px=cx.getImageData(0,0,8,8).data,r=0,g=0,b=0,n=0;
                for(var i=0;i<px.length;i+=4){var br=(px[i]+px[i+1]+px[i+2])/3;if(br<20||br>235)continue;r+=px[i];g+=px[i+1];b+=px[i+2];n++;}
                if(n>0) return 'rgb('+~~(r/n)+','+~~(g/n)+','+~~(b/n)+')';
            }catch(e){}
        }
        return '#e8a86e';
    }

    // Intercept window.alert — tampilkan custom dialog
    var _origAlert = window.alert;
    window.alert = function(msg){
        setTimeout(function(){ showAlertDialog((msg||'').toString()); }, 0);
    };

    function showAlertDialog(msg){
        if(document.getElementById('ft-alert')) return;
        var acc = getAccentNow();
        var ml = msg.toLowerCase();
        var icon, title;
        if(ml.indexOf('error')!==-1||ml.indexOf('invalid')!==-1||ml.indexOf('fail')!==-1){
            icon  = '<circle cx="12" cy="12" r="10"/><line x1="12" y1="8" x2="12" y2="12"/><line x1="12" y1="16" x2="12.01" y2="16"/>';
            title = 'Error';
        } else if(ml.indexOf('warn')!==-1||ml.indexOf('caution')!==-1){
            icon  = '<path d="M10.29 3.86L1.82 18a2 2 0 0 0 1.71 3h16.94a2 2 0 0 0 1.71-3L13.71 3.86a2 2 0 0 0-3.42 0z"/><line x1="12" y1="9" x2="12" y2="13"/><line x1="12" y1="17" x2="12.01" y2="17"/>';
            title = 'Warning';
        } else {
            icon  = '<path d="M12 22c5.523 0 10-4.477 10-10S17.523 2 12 2 2 6.477 2 12s4.477 10 10 10z"/><line x1="12" y1="8" x2="12" y2="12"/><line x1="12" y1="16" x2="12.01" y2="16"/>';
            title = 'Notice';
        }
        function escHtml(s){
            return (s||'').replace(/[&<>"]/g,function(x){
                return{'&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;'}[x];
            });
        }
        var s = document.createElement('style');
        s.id = 'ft-alert-s';
        s.textContent =
            '#ft-alert-bd{position:fixed;inset:0;z-index:99998;' +
                'background:rgba(0,0,0,0);backdrop-filter:blur(0px);-webkit-backdrop-filter:blur(0px);' +
                'transition:background .32s ease,backdrop-filter .32s ease,-webkit-backdrop-filter .32s ease}' +
            '#ft-alert-bd.ft-in{background:rgba(0,0,0,.52);backdrop-filter:blur(6px);-webkit-backdrop-filter:blur(6px)}' +
            '#ft-alert{position:fixed;top:50%;left:50%;z-index:99999;' +
                'background:rgba(12,10,16,.82);border:1px solid rgba(255,255,255,.08);border-radius:20px;' +
                'padding:36px 40px 28px;min-width:288px;max-width:360px;' +
                'backdrop-filter:blur(32px);-webkit-backdrop-filter:blur(32px);' +
                'box-shadow:0 24px 64px rgba(0,0,0,.75),0 1px 0 rgba(255,255,255,.05) inset;' +
                'text-align:center;font-family:Outfit,sans-serif;' +
                'opacity:0;transform:translate(-50%,-50%) scale(.88) translateY(12px);' +
                'transition:opacity .38s cubic-bezier(.22,1,.36,1),transform .38s cubic-bezier(.22,1,.36,1)}' +
            '#ft-alert.ft-in{opacity:1;transform:translate(-50%,-50%) scale(1) translateY(0)}' +
            '#ft-alert.ft-out{opacity:0;transform:translate(-50%,-50%) scale(.94) translateY(6px);' +
                'transition:opacity .2s ease,transform .2s ease}' +
            '#ft-alert-icon{width:44px;height:44px;display:block;margin:0 auto 18px;' +
                'opacity:0;transform:scale(.7) rotate(-8deg);' +
                'transition:opacity .35s cubic-bezier(.22,1,.36,1) .08s,transform .35s cubic-bezier(.22,1,.36,1) .08s}' +
            '#ft-alert.ft-in #ft-alert-icon{opacity:1;transform:scale(1) rotate(0deg)}' +
            '#ft-alert h3{font-size:17px;font-weight:700;color:#f0ece8;margin:0 0 7px;letter-spacing:-.01em;' +
                'opacity:0;transform:translateY(6px);transition:opacity .3s ease .14s,transform .3s ease .14s}' +
            '#ft-alert.ft-in h3{opacity:1;transform:translateY(0)}' +
            '#ft-alert p{font-size:12px;color:rgba(240,236,232,.55);margin:0 0 26px;line-height:1.6;' +
                'opacity:0;transform:translateY(6px);transition:opacity .3s ease .2s,transform .3s ease .2s;' +
                'word-break:break-word}' +
            '#ft-alert.ft-in p{opacity:1;transform:translateY(0)}' +
            '#ft-alert-ok{width:100%;padding:12px;border:none;border-radius:12px;' +
                'font-size:13px;font-weight:700;font-family:Outfit,sans-serif;cursor:pointer;color:#0e0810;' +
                'opacity:0;transform:translateY(8px);' +
                'transition:opacity .3s ease .26s,transform .3s ease .26s,filter .18s;outline:none}' +
            '#ft-alert.ft-in #ft-alert-ok{opacity:1;transform:translateY(0)}' +
            '#ft-alert-ok:hover{filter:brightness(1.08)}' +
            '#ft-alert-ok:active{transform:scale(.97)}';

        var bd  = document.createElement('div'); bd.id='ft-alert-bd';
        var dlg = document.createElement('div'); dlg.id='ft-alert';
        dlg.innerHTML =
            '<svg id="ft-alert-icon" viewBox="0 0 24 24" fill="none" stroke-width="1.5"' +
            ' stroke-linecap="round" stroke-linejoin="round">' + icon + '</svg>' +
            '<h3>' + escHtml(title) + '</h3><p>' + escHtml(msg) + '</p>' +
            '<button id="ft-alert-ok">OK</button>';

        document.head.appendChild(s);
        document.body.appendChild(bd);
        document.body.appendChild(dlg);

        function applyAccent(col){
            var ok=document.getElementById('ft-alert-ok');
            var ico=document.getElementById('ft-alert-icon');
            if(ok) ok.style.background=col;
            if(ico) ico.setAttribute('stroke',col);
        }
        applyAccent(acc);
        requestAnimationFrame(function(){ requestAnimationFrame(function(){
            bd.classList.add('ft-in'); dlg.classList.add('ft-in');
        }); });
        var mo=new MutationObserver(function(){
            var col=(getComputedStyle(document.documentElement).getPropertyValue('--accent')||'').trim();
            if(col) applyAccent(col);
        });
        mo.observe(document.documentElement,{attributes:true,attributeFilter:['style']});
        var syncT=setInterval(function(){
            var col=(getComputedStyle(document.documentElement).getPropertyValue('--accent')||'').trim();
            if(col) applyAccent(col);
        },200);

        function closeAlert(){
            mo.disconnect(); clearInterval(syncT);
            dlg.classList.remove('ft-in'); dlg.classList.add('ft-out');
            bd.classList.remove('ft-in');
            setTimeout(function(){
                [dlg,bd,s].forEach(function(el){ el.parentNode&&el.parentNode.removeChild(el); });
            },220);
        }
        document.getElementById('ft-alert-ok').addEventListener('click',closeAlert);
        bd.addEventListener('click',closeAlert);
        function onKey(e){ if(e.key==='Escape'||e.keyCode===27){ closeAlert(); document.removeEventListener('keydown',onKey); } }
        document.addEventListener('keydown',onKey);
    }

    function showRebootDialog(){
        if(document.getElementById('ft-dlg')) return;
        var acc = getAccentNow();

        var s = document.createElement('style');
        s.id = 'ft-dlg-s';
        s.textContent =
            '#ft-dlg-bd{position:fixed;inset:0;z-index:99998;' +
                'background:rgba(0,0,0,0);backdrop-filter:blur(0px);' +
                '-webkit-backdrop-filter:blur(0px);' +
                'transition:background .32s ease,backdrop-filter .32s ease,-webkit-backdrop-filter .32s ease}' +
            '#ft-dlg-bd.ft-in{background:rgba(0,0,0,.52);backdrop-filter:blur(6px);-webkit-backdrop-filter:blur(6px)}' +
            '#ft-dlg{position:fixed;top:50%;left:50%;' +
                'z-index:99999;' +
                'background:rgba(12,10,16,.82);' +
                'border:1px solid rgba(255,255,255,.08);border-radius:20px;' +
                'padding:36px 40px 28px;min-width:288px;max-width:340px;' +
                'backdrop-filter:blur(32px);-webkit-backdrop-filter:blur(32px);' +
                'box-shadow:0 24px 64px rgba(0,0,0,.75),0 1px 0 rgba(255,255,255,.05) inset;' +
                'text-align:center;font-family:Outfit,sans-serif;' +
                'opacity:0;transform:translate(-50%,-50%) scale(.88) translateY(12px);' +
                'transition:opacity .38s cubic-bezier(.22,1,.36,1),transform .38s cubic-bezier(.22,1,.36,1)}' +
            '#ft-dlg.ft-in{opacity:1;transform:translate(-50%,-50%) scale(1) translateY(0)}' +
            '#ft-dlg.ft-out{opacity:0;transform:translate(-50%,-50%) scale(.94) translateY(6px);' +
                'transition:opacity .2s ease,transform .2s ease}' +
            '#ft-dlg-icon{width:44px;height:44px;display:block;margin:0 auto 18px;' +
                'opacity:0;transform:scale(.7) rotate(-8deg);' +
                'transition:opacity .35s cubic-bezier(.22,1,.36,1) .08s,transform .35s cubic-bezier(.22,1,.36,1) .08s}' +
            '#ft-dlg.ft-in #ft-dlg-icon{opacity:1;transform:scale(1) rotate(0deg)}' +
            '#ft-dlg h3{font-size:17px;font-weight:700;color:#f0ece8;margin:0 0 7px;' +
                'letter-spacing:-.01em;' +
                'opacity:0;transform:translateY(6px);' +
                'transition:opacity .3s ease .14s,transform .3s ease .14s}' +
            '#ft-dlg.ft-in h3{opacity:1;transform:translateY(0)}' +
            '#ft-dlg p{font-size:12px;color:rgba(240,236,232,.38);' +
                'margin:0 0 26px;line-height:1.6;' +
                'opacity:0;transform:translateY(6px);' +
                'transition:opacity .3s ease .2s,transform .3s ease .2s}' +
            '#ft-dlg.ft-in p{opacity:1;transform:translateY(0)}' +
            '#ft-dlg-row{display:flex;gap:8px;' +
                'opacity:0;transform:translateY(8px);' +
                'transition:opacity .3s ease .26s,transform .3s ease .26s}' +
            '#ft-dlg.ft-in #ft-dlg-row{opacity:1;transform:translateY(0)}' +
            '#ft-dlg-no{flex:1;padding:12px;' +
                'border:1px solid rgba(255,255,255,.10);border-radius:12px;' +
                'background:rgba(255,255,255,.05);color:rgba(240,236,232,.6);' +
                'font-size:13px;font-family:Outfit,sans-serif;cursor:pointer;' +
                'transition:background .18s,color .18s,transform .18s,box-shadow .18s;outline:none}' +
            '#ft-dlg-no:hover{background:rgba(255,255,255,.10);color:rgba(240,236,232,.9);transform:translateY(-1px)}' +
            '#ft-dlg-no:active{transform:translateY(0) scale(.97)}' +
            '#ft-dlg-yes{flex:1;padding:12px;border:none;border-radius:12px;' +
                'font-size:13px;font-weight:700;font-family:Outfit,sans-serif;' +
                'cursor:pointer;color:#0e0810;' +
                'transition:opacity .18s,transform .18s,box-shadow .18s,filter .18s;outline:none}' +
            '#ft-dlg-yes:hover{opacity:.88;transform:translateY(-1px);filter:brightness(1.08)}' +
            '#ft-dlg-yes:active{transform:translateY(0) scale(.97);opacity:.95}';

        var bd  = document.createElement('div'); bd.id  = 'ft-dlg-bd';
        var dlg = document.createElement('div'); dlg.id = 'ft-dlg';
        dlg.innerHTML =
            '<svg id="ft-dlg-icon" viewBox="0 0 24 24" fill="none" stroke-width="1.5"' +
            ' stroke-linecap="round" stroke-linejoin="round">' +
            '<path d="M21 2v6h-6"/>' +
            '<path d="M3 12a9 9 0 0 1 15-6.7L21 8"/>' +
            '<path d="M3 22v-6h6"/>' +
            '<path d="M21 12a9 9 0 0 1-15 6.7L3 16"/></svg>' +
            '<h3>Reboot Router?</h3>' +
            '<p>The router will restart.<br>You will be disconnected briefly.</p>' +
            '<div id="ft-dlg-row">' +
            '<button id="ft-dlg-no">Cancel</button>' +
            '<button id="ft-dlg-yes">Reboot</button></div>';

        document.head.appendChild(s);
        document.body.appendChild(bd);
        document.body.appendChild(dlg);

        function applyAccent(col){
            var yes=document.getElementById('ft-dlg-yes');
            var ico=document.getElementById('ft-dlg-icon');
            if(yes) yes.style.background=col;
            if(ico) ico.setAttribute('stroke',col);
        }
        applyAccent(acc);

        // Trigger animasi masuk setelah DOM terpasang
        requestAnimationFrame(function(){
            requestAnimationFrame(function(){
                bd.classList.add('ft-in');
                dlg.classList.add('ft-in');
            });
        });

        // Live sync accent
        var mo=new MutationObserver(function(){
            var col=(getComputedStyle(document.documentElement)
                        .getPropertyValue('--accent')||'').trim();
            if(col) applyAccent(col);
        });
        mo.observe(document.documentElement,{attributes:true,attributeFilter:['style']});
        var syncT=setInterval(function(){
            var col=(getComputedStyle(document.documentElement)
                        .getPropertyValue('--accent')||'').trim();
            if(col) applyAccent(col);
        },200);

        function close(){
            mo.disconnect(); clearInterval(syncT);
            dlg.classList.remove('ft-in');
            dlg.classList.add('ft-out');
            bd.classList.remove('ft-in');
            setTimeout(function(){
                [dlg,bd,s].forEach(function(el){
                    el.parentNode && el.parentNode.removeChild(el);
                });
            },220);
        }

        // OK → redirect ke halaman reboot custom kita
        document.getElementById('ft-dlg-yes').addEventListener('click',function(){
            close();
            setTimeout(function(){
                window.location.href = '/reboot-wait.html';
            }, 220);
        });
        document.getElementById('ft-dlg-no').addEventListener('click',close);
        bd.addEventListener('click',close);
    }


    function showGenericDialog(msg, type, caller){
        if(document.getElementById('ft-dlg')) return;
        var acc = getAccentNow();
        var m = (msg||'').toString().toLowerCase();

        // Tentukan icon, title, label berdasarkan konteks
        function escHtml(s){
            return (s||'').replace(/[&<>"'`]/g,function(x){
                return{'&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;',"'":'&#x27;','`':'&#x60;'}[x];
            });
        }
        var icon, title, sub, yesLabel;
        if(type==='halt'){
            icon     = '<path d="M18.36 6.64a9 9 0 1 1-12.73 0"/><line x1="12" y1="2" x2="12" y2="12"/>';
            title    = 'Halt Router?';
            sub      = 'The router will shut down completely.<br>Manual power cycle required to restart.';
            yesLabel = 'Halt';
        } else if(m.indexOf('delete')!==-1||m.indexOf('remove')!==-1){
            icon     = '<polyline points="3 6 5 6 21 6"/><path d="M19 6l-1 14H6L5 6"/><path d="M10 11v6"/><path d="M14 11v6"/><path d="M9 6V4h6v2"/>';
            title    = 'Delete?';
            sub      = escHtml(msg);
            yesLabel = 'Delete';
        } else if(m.indexOf('nvram')!==-1||m.indexOf('add ')===0||m.indexOf('save')!==-1){
            icon     = '<path d="M19 21H5a2 2 0 0 1-2-2V5a2 2 0 0 1 2-2h11l5 5v11a2 2 0 0 1-2 2z"/><polyline points="17 21 17 13 7 13 7 21"/><polyline points="7 3 7 8 15 8"/>';
            title    = 'Save to NVRAM?';
            sub      = escHtml(msg);
            yesLabel = 'Save';
        } else {
            icon     = '<circle cx="12" cy="12" r="10"/><line x1="12" y1="8" x2="12" y2="12"/><line x1="12" y1="16" x2="12.01" y2="16"/>';
            title    = 'Confirm';
            sub      = escHtml(msg);
            yesLabel = 'OK';
        }

        var s = document.createElement('style');
        s.id = 'ft-dlg-s';
        s.textContent =
            '#ft-dlg-bd{position:fixed;inset:0;z-index:99998;' +
                'background:rgba(0,0,0,0);backdrop-filter:blur(0px);' +
                '-webkit-backdrop-filter:blur(0px);' +
                'transition:background .32s ease,backdrop-filter .32s ease,-webkit-backdrop-filter .32s ease}' +
            '#ft-dlg-bd.ft-in{background:rgba(0,0,0,.52);backdrop-filter:blur(6px);-webkit-backdrop-filter:blur(6px)}' +
            '#ft-dlg{position:fixed;top:50%;left:50%;z-index:99999;' +
                'background:rgba(12,10,16,.82);' +
                'border:1px solid rgba(255,255,255,.08);border-radius:20px;' +
                'padding:36px 40px 28px;min-width:288px;max-width:340px;' +
                'backdrop-filter:blur(32px);-webkit-backdrop-filter:blur(32px);' +
                'box-shadow:0 24px 64px rgba(0,0,0,.75),0 1px 0 rgba(255,255,255,.05) inset;' +
                'text-align:center;font-family:Outfit,sans-serif;' +
                'opacity:0;transform:translate(-50%,-50%) scale(.88) translateY(12px);' +
                'transition:opacity .38s cubic-bezier(.22,1,.36,1),transform .38s cubic-bezier(.22,1,.36,1)}' +
            '#ft-dlg.ft-in{opacity:1;transform:translate(-50%,-50%) scale(1) translateY(0)}' +
            '#ft-dlg.ft-out{opacity:0;transform:translate(-50%,-50%) scale(.94) translateY(6px);' +
                'transition:opacity .2s ease,transform .2s ease}' +
            '#ft-dlg-icon{width:44px;height:44px;display:block;margin:0 auto 18px;' +
                'opacity:0;transform:scale(.7) rotate(-8deg);' +
                'transition:opacity .35s cubic-bezier(.22,1,.36,1) .08s,transform .35s cubic-bezier(.22,1,.36,1) .08s}' +
            '#ft-dlg.ft-in #ft-dlg-icon{opacity:1;transform:scale(1) rotate(0deg)}' +
            '#ft-dlg h3{font-size:17px;font-weight:700;color:#f0ece8;margin:0 0 7px;' +
                'letter-spacing:-.01em;opacity:0;transform:translateY(6px);' +
                'transition:opacity .3s ease .14s,transform .3s ease .14s}' +
            '#ft-dlg.ft-in h3{opacity:1;transform:translateY(0)}' +
            '#ft-dlg p{font-size:12px;color:rgba(240,236,232,.38);' +
                'margin:0 0 26px;line-height:1.6;opacity:0;transform:translateY(6px);' +
                'transition:opacity .3s ease .2s,transform .3s ease .2s}' +
            '#ft-dlg.ft-in p{opacity:1;transform:translateY(0)}' +
            '#ft-dlg-row{display:flex;gap:8px;opacity:0;transform:translateY(8px);' +
                'transition:opacity .3s ease .26s,transform .3s ease .26s}' +
            '#ft-dlg.ft-in #ft-dlg-row{opacity:1;transform:translateY(0)}' +
            '#ft-dlg-no{flex:1;padding:12px;border:1px solid rgba(255,255,255,.10);border-radius:12px;' +
                'background:rgba(255,255,255,.05);color:rgba(240,236,232,.6);' +
                'font-size:13px;font-family:Outfit,sans-serif;cursor:pointer;' +
                'transition:background .18s,color .18s,transform .18s;outline:none}' +
            '#ft-dlg-no:hover{background:rgba(255,255,255,.10);color:rgba(240,236,232,.9);transform:translateY(-1px)}' +
            '#ft-dlg-no:active{transform:scale(.97)}' +
            '#ft-dlg-yes{flex:1;padding:12px;border:none;border-radius:12px;' +
                'font-size:13px;font-weight:700;font-family:Outfit,sans-serif;' +
                'cursor:pointer;color:#0e0810;' +
                'transition:opacity .18s,transform .18s,filter .18s;outline:none}' +
            '#ft-dlg-yes:hover{opacity:.88;transform:translateY(-1px);filter:brightness(1.08)}' +
            '#ft-dlg-yes:active{transform:scale(.97)}';

        var bd  = document.createElement('div'); bd.id='ft-dlg-bd';
        var dlg = document.createElement('div'); dlg.id='ft-dlg';
        dlg.innerHTML =
            '<svg id="ft-dlg-icon" viewBox="0 0 24 24" fill="none" stroke-width="1.5"' +
            ' stroke-linecap="round" stroke-linejoin="round">' + icon + '</svg>' +
            '<h3>' + escHtml(title) + '</h3><p>' + sub + '</p>' +
            '<div id="ft-dlg-row">' +
            '<button id="ft-dlg-no">Cancel</button>' +
            '<button id="ft-dlg-yes">' + escHtml(yesLabel) + '</button></div>';

        document.head.appendChild(s);
        document.body.appendChild(bd);
        document.body.appendChild(dlg);

        function applyAccent(col){
            var yes=document.getElementById('ft-dlg-yes');
            var ico=document.getElementById('ft-dlg-icon');
            if(yes) yes.style.background=col;
            if(ico) ico.setAttribute('stroke',col);
        }
        applyAccent(acc);
        requestAnimationFrame(function(){
            requestAnimationFrame(function(){
                bd.classList.add('ft-in');
                dlg.classList.add('ft-in');
            });
        });
        var mo=new MutationObserver(function(){
            var col=(getComputedStyle(document.documentElement).getPropertyValue('--accent')||'').trim();
            if(col) applyAccent(col);
        });
        mo.observe(document.documentElement,{attributes:true,attributeFilter:['style']});
        var syncT=setInterval(function(){
            var col=(getComputedStyle(document.documentElement).getPropertyValue('--accent')||'').trim();
            if(col) applyAccent(col);
        },200);

        function closeDlg(){
            mo.disconnect(); clearInterval(syncT);
            dlg.classList.remove('ft-in');
            dlg.classList.add('ft-out');
            bd.classList.remove('ft-in');
            setTimeout(function(){
                [dlg,bd,s].forEach(function(el){
                    el.parentNode && el.parentNode.removeChild(el);
                });
            },220);
        }

        document.getElementById('ft-dlg-yes').addEventListener('click',function(){
            closeDlg();
            setTimeout(function(){
                if(type==='halt'){
                    // Redirect ke halt-wait.html dulu
                    window.location.href = '/halt-wait.html';
                    // shutdown.cgi butuh http_id sama seperti tomato.cgi
                    var httpId = (typeof nvram !== 'undefined' && nvram.http_id) ? nvram.http_id : 'FT_HTTP_ID';
                    var xs = new XMLHttpRequest();
                    xs.open('POST', '/shutdown.cgi', true);
                    xs.setRequestHeader('Content-Type', 'application/x-www-form-urlencoded');
                    xs.timeout = 5000;
                    xs.send('_http_id=' + encodeURIComponent(httpId));
                } else {
                    // Set bypass untuk pesan ini (3 detik)
                    _ftSetConfirmed(msg, 10000);
                    // Re-trigger: cari elemen dengan onclick yang relevan
                    var triggered = false;
                    if(caller && caller.tagName && caller.tagName !== 'BODY'
                       && caller !== document.body && caller.click){
                        try{ caller.click(); triggered = true; }catch(e){}
                    }
                    // Fallback: cari tombol/link dengan onclick yang mengandung
                    // fungsi yang kemungkinan memanggil confirm ini
                    if(!triggered){
                        var allBtns = document.querySelectorAll(
                            'input[type=button],input[type=submit],button,a');
                        for(var bi=0; bi<allBtns.length; bi++){
                            var oc = (allBtns[bi].getAttribute('onclick')||'') +
                                     (allBtns[bi].href||'');
                            // Klik tombol Save jika ada dan msg mengandung nvram/save
                            var ml = msg.toLowerCase();
                            if((ml.indexOf('nvram')!==-1||ml.indexOf('add')!==-1)
                               && (allBtns[bi].id==='save-button'||oc.indexOf('save')!==-1)){
                                try{ allBtns[bi].click(); triggered = true; }catch(e){}
                                break;
                            }
                        }
                    }
                    // Last resort: re-run fungsi yang mungkin trigger confirm
                    if(!triggered){
                        // Cari fungsi global yang namanya cocok dengan konteks
                        var ml2 = msg.toLowerCase();
                        if(ml2.indexOf('nvram')!==-1 || ml2.indexOf('add')!==-1){
                            // FreshTomato pattern: ftpNvramAdd, dnsmasqNvramAdd, dll
                            var fns = Object.keys(window).filter(function(k){
                                return typeof window[k]==='function' &&
                                       k.toLowerCase().indexOf('nvramadd')!==-1;
                            });
                            if(fns.length > 0){
                                // Perpanjang TTL sebelum jalankan fungsi
                                _ftSetConfirmed(msg, 10000);
                                try{ window[fns[0]](); }catch(e){}
                            }
                        }
                    }
                }
            },220);
        });
        document.getElementById('ft-dlg-no').addEventListener('click',closeDlg);
        bd.addEventListener('click',closeDlg);
    }

    // Patch semua link/onclick reboot di DOM
    function patchLinks(){
        // Patch reboot links
        document.querySelectorAll('[href*="reboot"],[onclick*="reboot"]')
            .forEach(function(el){
                if(el.dataset.ftP) return; el.dataset.ftP='1';
                var oc=el.getAttribute('onclick')||'';
                if(oc.indexOf('reboot')!==-1){
                    el.setAttribute('onclick','return false;');
                    el.addEventListener('click',function(e){
                        e.preventDefault();e.stopPropagation();
                        showRebootDialog();
                    });
                }
                var hr=el.getAttribute('href')||'';
                if(hr.indexOf('reboot')!==-1){
                    el.setAttribute('href','javascript:void(0)');
                    el.addEventListener('click',function(e){
                        e.preventDefault();e.stopPropagation();
                        showRebootDialog();
                    });
                }
            });

        // Patch logout links
        document.querySelectorAll('[href*="logout"],[onclick*="logout"],[href*="logout.asp"]')
            .forEach(function(el){
                if(el.dataset.ftLo) return; el.dataset.ftLo='1';
                el.setAttribute('onclick','return false;');
                el.addEventListener('click',function(e){
                    e.preventDefault();e.stopPropagation();
                    showLogoutDialog();
                });
            });

        // Patch halt links
        document.querySelectorAll('[onclick*="halt"]')
            .forEach(function(el){
                if(el.dataset.ftH) return; el.dataset.ftH='1';
                el.setAttribute('onclick','return false;');
                el.addEventListener('click',function(e){
                    e.preventDefault();e.stopPropagation();
                    showGenericDialog('Halt?','halt');
                });
            });
    }

    function showLogoutDialog(){
        if(document.getElementById('ft-dlg')) return;
        var acc = getAccentNow();

        var s = document.createElement('style');
        s.id = 'ft-dlg-s';
        s.textContent =
            '#ft-dlg-bd{position:fixed;inset:0;z-index:99998;' +
                'background:rgba(0,0,0,0);backdrop-filter:blur(0px);' +
                '-webkit-backdrop-filter:blur(0px);' +
                'transition:background .32s ease,backdrop-filter .32s ease,-webkit-backdrop-filter .32s ease}' +
            '#ft-dlg-bd.ft-in{background:rgba(0,0,0,.52);backdrop-filter:blur(6px);-webkit-backdrop-filter:blur(6px)}' +
            '#ft-dlg{position:fixed;top:50%;left:50%;z-index:99999;' +
                'background:rgba(12,10,16,.82);' +
                'border:1px solid rgba(255,255,255,.08);border-radius:20px;' +
                'padding:36px 40px 28px;min-width:288px;max-width:340px;' +
                'backdrop-filter:blur(32px);-webkit-backdrop-filter:blur(32px);' +
                'box-shadow:0 24px 64px rgba(0,0,0,.75),0 1px 0 rgba(255,255,255,.05) inset;' +
                'text-align:center;font-family:Outfit,sans-serif;' +
                'opacity:0;transform:translate(-50%,-50%) scale(.88) translateY(12px);' +
                'transition:opacity .38s cubic-bezier(.22,1,.36,1),transform .38s cubic-bezier(.22,1,.36,1)}' +
            '#ft-dlg.ft-in{opacity:1;transform:translate(-50%,-50%) scale(1) translateY(0)}' +
            '#ft-dlg.ft-out{opacity:0;transform:translate(-50%,-50%) scale(.94) translateY(6px);' +
                'transition:opacity .2s ease,transform .2s ease}' +
            '#ft-dlg-icon{width:44px;height:44px;display:block;margin:0 auto 18px;' +
                'opacity:0;transform:scale(.7) rotate(-8deg);' +
                'transition:opacity .35s cubic-bezier(.22,1,.36,1) .08s,transform .35s cubic-bezier(.22,1,.36,1) .08s}' +
            '#ft-dlg.ft-in #ft-dlg-icon{opacity:1;transform:scale(1) rotate(0deg)}' +
            '#ft-dlg h3{font-size:17px;font-weight:700;color:#f0ece8;margin:0 0 7px;' +
                'letter-spacing:-.01em;opacity:0;transform:translateY(6px);' +
                'transition:opacity .3s ease .14s,transform .3s ease .14s}' +
            '#ft-dlg.ft-in h3{opacity:1;transform:translateY(0)}' +
            '#ft-dlg p{font-size:12px;color:rgba(240,236,232,.38);' +
                'margin:0 0 26px;line-height:1.6;opacity:0;transform:translateY(6px);' +
                'transition:opacity .3s ease .2s,transform .3s ease .2s}' +
            '#ft-dlg.ft-in p{opacity:1;transform:translateY(0)}' +
            '#ft-dlg-row{display:flex;gap:8px;opacity:0;transform:translateY(8px);' +
                'transition:opacity .3s ease .26s,transform .3s ease .26s}' +
            '#ft-dlg.ft-in #ft-dlg-row{opacity:1;transform:translateY(0)}' +
            '#ft-dlg-no{flex:1;padding:12px;border:1px solid rgba(255,255,255,.10);border-radius:12px;' +
                'background:rgba(255,255,255,.05);color:rgba(240,236,232,.6);' +
                'font-size:13px;font-family:Outfit,sans-serif;cursor:pointer;' +
                'transition:background .18s,color .18s,transform .18s;outline:none}' +
            '#ft-dlg-no:hover{background:rgba(255,255,255,.10);color:rgba(240,236,232,.9);transform:translateY(-1px)}' +
            '#ft-dlg-no:active{transform:scale(.97)}' +
            '#ft-dlg-yes{flex:1;padding:12px;border:none;border-radius:12px;' +
                'font-size:13px;font-weight:700;font-family:Outfit,sans-serif;' +
                'cursor:pointer;color:#0e0810;' +
                'transition:opacity .18s,transform .18s,filter .18s;outline:none}' +
            '#ft-dlg-yes:hover{opacity:.88;transform:translateY(-1px);filter:brightness(1.08)}' +
            '#ft-dlg-yes:active{transform:scale(.97)}';

        var bd  = document.createElement('div'); bd.id='ft-dlg-bd';
        var dlg = document.createElement('div'); dlg.id='ft-dlg';
        dlg.innerHTML =
            '<svg id="ft-dlg-icon" viewBox="0 0 24 24" fill="none" stroke-width="1.5"' +
            ' stroke-linecap="round" stroke-linejoin="round">' +
            '<path d="M9 21H5a2 2 0 0 1-2-2V5a2 2 0 0 1 2-2h4"/>' +
            '<polyline points="16 17 21 12 16 7"/>' +
            '<line x1="21" y1="12" x2="9" y2="12"/>' +
            '</svg>' +
            '<h3>Log Out?</h3>' +
            '<p>You will be returned to the login page.</p>' +
            '<div id="ft-dlg-row">' +
            '<button id="ft-dlg-no">Cancel</button>' +
            '<button id="ft-dlg-yes">Log Out</button></div>';

        document.head.appendChild(s);
        document.body.appendChild(bd);
        document.body.appendChild(dlg);

        function applyAccent(col){
            var yes=document.getElementById('ft-dlg-yes');
            var ico=document.getElementById('ft-dlg-icon');
            if(yes) yes.style.background=col;
            if(ico) ico.setAttribute('stroke',col);
        }
        applyAccent(acc);
        requestAnimationFrame(function(){
            requestAnimationFrame(function(){
                bd.classList.add('ft-in');
                dlg.classList.add('ft-in');
            });
        });
        var mo=new MutationObserver(function(){
            var col=(getComputedStyle(document.documentElement).getPropertyValue('--accent')||'').trim();
            if(col) applyAccent(col);
        });
        mo.observe(document.documentElement,{attributes:true,attributeFilter:['style']});
        var syncT=setInterval(function(){
            var col=(getComputedStyle(document.documentElement).getPropertyValue('--accent')||'').trim();
            if(col) applyAccent(col);
        },200);

        function closeDlg(){
            mo.disconnect(); clearInterval(syncT);
            dlg.classList.remove('ft-in');
            dlg.classList.add('ft-out');
            bd.classList.remove('ft-in');
            setTimeout(function(){
                [dlg,bd,s].forEach(function(el){
                    el.parentNode && el.parentNode.removeChild(el);
                });
            },220);
        }

        document.getElementById('ft-dlg-yes').addEventListener('click',function(){
            closeDlg();
            setTimeout(function(){
                // Logout via FreshTomato native
                if(typeof form!=='undefined'&&form.submitHidden){
                    form.submitHidden('logout.asp',{});
                } else {
                    window.location.href='/logout.asp';
                }
            },220);
        });
        document.getElementById('ft-dlg-no').addEventListener('click',closeDlg);
        bd.addEventListener('click',closeDlg);
    }

    function installPatcher(){
        patchLinks();
        var pmo=new MutationObserver(function(muts){
            muts.forEach(function(m){
                m.addedNodes.forEach(function(n){
                    if(n.nodeType===1){
                        patchLinks();
                    }
                });
            });
        });
        pmo.observe(document.body||document.documentElement,
            {childList:true,subtree:true});
    }
    if(document.body) installPatcher();
    else document.addEventListener('DOMContentLoaded',installPatcher);



})();
